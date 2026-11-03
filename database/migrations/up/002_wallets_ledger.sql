-- =====================================================================
-- 002_wallets_ledger.sql (UP): cüzdan + değiştirilemez token defteri
-- =====================================================================
-- TASARIM FİKRİ (öğrenmeniz gereken en önemli kısım):
--   Gerçek kaynak = wallet_transactions (defter / ledger).
--   wallets.available_balance / held_balance = defterin ÖNBELLEĞE alınmış toplamı.
--   Bakiyeyi yalnızca "deftere satır eklemek" değiştirir (trigger bakiyeyi günceller).
--   Böylece "bakiye ≠ defter toplamı" durumu yapısal olarak imkânsızlaşır.
-- ---------------------------------------------------------------------

CREATE TABLE wallets (
  wallet_id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid        NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
  available_balance integer     NOT NULL DEFAULT 0,
  held_balance      integer     NOT NULL DEFAULT 0,
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT wallets_user_uq UNIQUE (user_id),
  CONSTRAINT wallets_available_ck CHECK (available_balance >= 0),
  CONSTRAINT wallets_held_ck      CHECK (held_balance >= 0)
);

CREATE TABLE wallet_transactions (
  transaction_id    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id         uuid        NOT NULL REFERENCES wallets(wallet_id) ON DELETE RESTRICT,
  lesson_request_id uuid,       -- FK 003'te eklenir (tablo henüz yok)
  transaction_type  varchar(24) NOT NULL,
  available_delta   integer     NOT NULL,
  held_delta        integer     NOT NULL,
  idempotency_key   varchar(120) NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT wtx_idem_uq UNIQUE (idempotency_key),
  CONSTRAINT wtx_type_ck CHECK (transaction_type IN
    ('WELCOME_BONUS','HOLD','SETTLEMENT_DEBIT','SETTLEMENT_CREDIT')),
  -- G8: sıfır hareket yazılmaz (ücretsiz derste deftere satır eklenmez).
  CONSTRAINT wtx_nonzero_ck CHECK (available_delta <> 0 OR held_delta <> 0),
  -- Her işlem tipinin "şekli" sabittir; yanlış şekilli satır DB'ye girmez.
  CONSTRAINT wtx_shape_ck CHECK (
       (transaction_type = 'WELCOME_BONUS'     AND lesson_request_id IS NULL
            AND available_delta > 0 AND held_delta = 0)
    OR (transaction_type = 'HOLD'              AND lesson_request_id IS NOT NULL
            AND available_delta < 0 AND held_delta = -available_delta)
    OR (transaction_type = 'SETTLEMENT_DEBIT'  AND lesson_request_id IS NOT NULL
            AND available_delta = 0 AND held_delta < 0)
    OR (transaction_type = 'SETTLEMENT_CREDIT' AND lesson_request_id IS NOT NULL
            AND available_delta > 0 AND held_delta = 0)
  )
);
-- G9: Aynı talep + aynı cüzdan + aynı tip ikinci kez yazılamaz (ikinci kez hold/settlement imkânsız).
CREATE UNIQUE INDEX wtx_once_per_request_uq
  ON wallet_transactions (lesson_request_id, wallet_id, transaction_type)
  WHERE lesson_request_id IS NOT NULL;
-- G6: Cüzdan başına en fazla bir hoş geldin bonusu (token farming'e karşı DB seviyesinde sigorta).
CREATE UNIQUE INDEX wtx_one_welcome_per_wallet_uq
  ON wallet_transactions (wallet_id) WHERE transaction_type = 'WELCOME_BONUS';
CREATE INDEX wtx_wallet_created_idx ON wallet_transactions (wallet_id, created_at);

-- ---------------------------------------------------------------------
-- Defter satırı eklenince cüzdan bakiyesini günceller.
-- ---------------------------------------------------------------------
CREATE FUNCTION wtx_apply_to_wallet() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE wallets
     SET available_balance = available_balance + NEW.available_delta,
         held_balance      = held_balance      + NEW.held_delta,
         updated_at        = now()
   WHERE wallet_id = NEW.wallet_id;
  RETURN NULL;
END $$;
CREATE TRIGGER wtx_apply_to_wallet AFTER INSERT ON wallet_transactions
  FOR EACH ROW EXECUTE FUNCTION wtx_apply_to_wallet();

-- G13: Defter append-only: UPDATE / DELETE / TRUNCATE yasak.
CREATE FUNCTION wtx_forbid_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'LEDGER_IS_APPEND_ONLY' USING ERRCODE = 'P0001';
END $$;
CREATE TRIGGER wtx_no_update_delete BEFORE UPDATE OR DELETE ON wallet_transactions
  FOR EACH ROW EXECUTE FUNCTION wtx_forbid_change();
CREATE TRIGGER wtx_no_truncate BEFORE TRUNCATE ON wallet_transactions
  FOR EACH STATEMENT EXECUTE FUNCTION wtx_forbid_change();

-- ---------------------------------------------------------------------
-- Cüzdana doğrudan UPDATE/INSERT/DELETE ile bakiye değiştirmeyi engelle.
-- pg_trigger_depth() >= 2  =>  değişiklik başka bir trigger'dan (wtx_apply_to_wallet) geliyor.
-- pg_trigger_depth() = 1   =>  biri doğrudan "UPDATE wallets SET ..." yazmış -> reddet.
-- ---------------------------------------------------------------------
CREATE FUNCTION wallets_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'WALLET_DELETE_FORBIDDEN' USING ERRCODE = 'P0001';
  ELSIF TG_OP = 'INSERT' THEN
    IF NEW.available_balance <> 0 OR NEW.held_balance <> 0 THEN
      RAISE EXCEPTION 'WALLET_MUST_START_EMPTY' USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
  ELSE
    IF NEW.user_id <> OLD.user_id THEN
      RAISE EXCEPTION 'WALLET_OWNER_IMMUTABLE' USING ERRCODE = 'P0001';
    END IF;
    IF (NEW.available_balance <> OLD.available_balance OR NEW.held_balance <> OLD.held_balance)
       AND pg_trigger_depth() < 2 THEN
      RAISE EXCEPTION 'WALLET_BALANCE_ONLY_VIA_LEDGER' USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
  END IF;
END $$;
CREATE TRIGGER wallets_guard BEFORE INSERT OR UPDATE OR DELETE ON wallets
  FOR EACH ROW EXECUTE FUNCTION wallets_guard();

-- ---------------------------------------------------------------------
-- Yeni kullanıcı => cüzdan + 10 token hoş geldin bonusu (G6: e-posta doğrulaması beklenmez).
-- ---------------------------------------------------------------------
CREATE FUNCTION users_create_wallet() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_wallet uuid;
BEGIN
  INSERT INTO wallets (user_id) VALUES (NEW.user_id) RETURNING wallet_id INTO v_wallet;
  INSERT INTO wallet_transactions
    (wallet_id, transaction_type, available_delta, held_delta, idempotency_key)
  VALUES (v_wallet, 'WELCOME_BONUS', 10, 0, 'WELCOME_BONUS:' || NEW.user_id);
  RETURN NULL;
END $$;
CREATE TRIGGER users_create_wallet AFTER INSERT ON users
  FOR EACH ROW EXECUTE FUNCTION users_create_wallet();
