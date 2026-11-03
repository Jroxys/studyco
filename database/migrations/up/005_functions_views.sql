-- =====================================================================
-- 005_functions_views.sql (UP): iş akışı fonksiyonları + bütünlük görünümü
-- =====================================================================
-- GENEL KURALLAR
--  * Hata = RAISE EXCEPTION '<KOD>' (SQLSTATE P0001). Backend, hata MESAJINI (kodu) okur.
--  * p_now parametresi: varsayılanı now(). Testlerin zamanı "ilerletebilmesi" için var.
--    Backend ASLA bu parametreyi istemciden gelen değerle doldurmamalı.
--  * KİLİT SIRASI (deadlock'u önler) -- tüm fonksiyonlar aynı sırayı izler:
--      1) users satırları  (user_id sırasıyla, FOR NO KEY UPDATE)   [yalnızca accept]
--      2) listings satırı  (FOR UPDATE)
--      3) lesson_requests satırı (FOR UPDATE)
--      4) wallets satırları (wallet_id sırasıyla, FOR UPDATE)
--    Neden users kilidi? İki farklı ilanın aynı kullanıcı için yarışan kabulleri
--    sıraya girsin (spec 7.1 son paragraf). NO KEY UPDATE: başka tabloların FK
--    kontrollerini (KEY SHARE) engellemez.
-- ---------------------------------------------------------------------

-- ===== Doğrulama kodları ============================================
-- Yeni kod: aynı kullanıcı+amaç için eski aktif kodu iptal eder (tek aktif kod kuralı).
CREATE FUNCTION issue_auth_token(p_user_id uuid, p_purpose text, p_token_hash text, p_ttl interval)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid;
BEGIN
  UPDATE auth_tokens SET revoked_at = clock_timestamp()
   WHERE user_id = p_user_id AND purpose = p_purpose AND used_at IS NULL AND revoked_at IS NULL;
  INSERT INTO auth_tokens (user_id, purpose, token_hash, expires_at)
  VALUES (p_user_id, p_purpose, p_token_hash, clock_timestamp() + p_ttl)
  RETURNING auth_token_id INTO v_id;
  RETURN v_id;
END $$;

-- Sonuç: OK | INVALID | EXPIRED | LOCKED | NOT_FOUND
-- p_max_attempts bilerek varsayılansız: sayı ürün kararıdır (açık karar O-05).
-- NOT: INVALID/LOCKED yolunda attempt_count artar; backend bu çağrıyı COMMIT etmelidir
--      (hata fırlatıp rollback yapılırsa sayaç kaybolur).
CREATE FUNCTION verify_auth_token(p_user_id uuid, p_purpose text, p_token_hash text, p_max_attempts integer)
RETURNS text LANGUAGE plpgsql AS $$
DECLARE t auth_tokens%ROWTYPE;
BEGIN
  SELECT * INTO t FROM auth_tokens
   WHERE user_id = p_user_id AND purpose = p_purpose AND used_at IS NULL AND revoked_at IS NULL
   FOR UPDATE;
  IF NOT FOUND THEN RETURN 'NOT_FOUND'; END IF;
  IF t.expires_at <= clock_timestamp() THEN RETURN 'EXPIRED'; END IF;
  IF t.attempt_count >= p_max_attempts THEN RETURN 'LOCKED'; END IF;
  IF t.token_hash = p_token_hash THEN
    UPDATE auth_tokens SET used_at = clock_timestamp() WHERE auth_token_id = t.auth_token_id;
    IF p_purpose = 'EMAIL_VERIFICATION' THEN
      UPDATE users SET email_verified_at = COALESCE(email_verified_at, clock_timestamp())
       WHERE user_id = p_user_id;
    END IF;
    RETURN 'OK';
  END IF;
  UPDATE auth_tokens SET attempt_count = attempt_count + 1 WHERE auth_token_id = t.auth_token_id;
  RETURN 'INVALID';
END $$;

-- ===== Talep reddi ===================================================
CREATE FUNCTION reject_lesson_request(p_request_id uuid, p_teacher_id uuid, p_now timestamptz DEFAULT now())
RETURNS lesson_requests LANGUAGE plpgsql AS $$
DECLARE v_listing_id uuid; v_req lesson_requests;
BEGIN
  SELECT listing_id INTO v_listing_id FROM lesson_requests WHERE request_id = p_request_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'REQUEST_NOT_FOUND' USING ERRCODE = 'P0001'; END IF;
  PERFORM 1 FROM listings WHERE listing_id = v_listing_id FOR UPDATE;
  SELECT * INTO v_req FROM lesson_requests WHERE request_id = p_request_id FOR UPDATE;
  IF v_req.teacher_id <> p_teacher_id THEN RAISE EXCEPTION 'NOT_LISTING_OWNER' USING ERRCODE = 'P0001'; END IF;
  IF v_req.request_status <> 'PENDING' THEN RAISE EXCEPTION 'REQUEST_NOT_PENDING' USING ERRCODE = 'P0001'; END IF;
  -- Reddedilen talepte token bloke EDİLMEZ: cüzdana/deftere dokunulmaz.
  UPDATE lesson_requests SET request_status = 'REJECTED', responded_at = p_now
   WHERE request_id = p_request_id RETURNING * INTO v_req;
  RETURN v_req;
END $$;

-- ===== Talep kabulü (spec 7.1) =======================================
-- Tek transaction: kontrol + durum + HOLD + konuşma + otomatik iptaller.
CREATE FUNCTION accept_lesson_request(p_request_id uuid, p_teacher_id uuid, p_now timestamptz DEFAULT now())
RETURNS lesson_requests LANGUAGE plpgsql AS $$
DECLARE
  v_listing_id uuid; v_student uuid; v_teacher uuid;
  v_req lesson_requests; v_list listings; v_wallet wallets;
BEGIN
  SELECT listing_id, student_id, teacher_id INTO v_listing_id, v_student, v_teacher
    FROM lesson_requests WHERE request_id = p_request_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'REQUEST_NOT_FOUND' USING ERRCODE = 'P0001'; END IF;
  IF v_teacher <> p_teacher_id THEN RAISE EXCEPTION 'NOT_LISTING_OWNER' USING ERRCODE = 'P0001'; END IF;

  -- (1) iki kullanıcıyı user_id sırasıyla kilitle
  PERFORM 1 FROM users WHERE user_id IN (v_student, v_teacher) ORDER BY user_id FOR NO KEY UPDATE;
  -- (2) ilanı kilitle, (3) talebi kilitle ve kilit SONRASI yeniden doğrula
  SELECT * INTO v_list FROM listings WHERE listing_id = v_listing_id FOR UPDATE;
  SELECT * INTO v_req  FROM lesson_requests WHERE request_id = p_request_id FOR UPDATE;

  IF v_req.request_status <> 'PENDING' THEN
    RAISE EXCEPTION 'REQUEST_NOT_PENDING' USING ERRCODE = 'P0001';
  END IF;
  IF v_list.status = 'BOOKED' THEN
    RAISE EXCEPTION 'LISTING_ALREADY_BOOKED' USING ERRCODE = 'P0001';
  ELSIF v_list.status <> 'PUBLISHED' THEN
    RAISE EXCEPTION 'LISTING_NOT_PUBLISHED' USING ERRCODE = 'P0001';
  END IF;
  -- Kabul, ders BAŞLAMADAN yapılmalı (G3: tarihi geçen ilan kabul edilemez).
  IF p_now >= v_list.start_at THEN
    RAISE EXCEPTION 'LISTING_EXPIRED' USING ERRCODE = 'P0001';
  END IF;
  -- G1: çakışma kontrolü HER İKİ kullanıcı için, HER İKİ rolde (accepted_slots rolden bağımsız)
  IF EXISTS (SELECT 1 FROM accepted_slots s
              WHERE s.user_id IN (v_student, v_teacher) AND s.time_range && v_req.time_range) THEN
    RAISE EXCEPTION 'TIME_CONFLICT' USING ERRCODE = 'P0001';
  END IF;
  -- (4) öğrenci cüzdanını kilitle ve bakiyeyi kontrol et
  SELECT * INTO v_wallet FROM wallets WHERE user_id = v_student FOR UPDATE;
  IF v_wallet.available_balance < v_list.token_price THEN
    RAISE EXCEPTION 'INSUFFICIENT_BALANCE' USING ERRCODE = 'P0001';
  END IF;

  -- Kabul: durum + snapshot + onay penceresi. (Trigger: accepted_slots + ilan BOOKED)
  UPDATE lesson_requests
     SET request_status = 'ACCEPTED',
         completion_status = 'AWAITING_CONFIRMATION',
         agreed_token_amount = v_list.token_price,
         responded_at = p_now,
         confirmation_deadline_at = upper(time_range) + interval '24 hours'
   WHERE request_id = p_request_id
   RETURNING * INTO v_req;

  -- Token bloke: ücretsiz derste (0) deftere satır YAZILMAZ (G8).
  IF v_list.token_price > 0 THEN
    INSERT INTO wallet_transactions
      (wallet_id, lesson_request_id, transaction_type, available_delta, held_delta, idempotency_key)
    VALUES (v_wallet.wallet_id, p_request_id, 'HOLD',
            -v_list.token_price, v_list.token_price, 'HOLD:' || p_request_id);
  END IF;

  INSERT INTO conversations (lesson_request_id) VALUES (p_request_id);

  -- O-02: aynı ilanın diğer bekleyen talepleri
  UPDATE lesson_requests
     SET request_status = 'AUTO_CANCELLED', auto_cancel_reason = 'LISTING_ALREADY_BOOKED'
   WHERE listing_id = v_listing_id AND request_status = 'PENDING' AND request_id <> p_request_id;

  -- G1: iki kullanıcının (hangi rolde olursa olsun) çakışan diğer bekleyen talepleri
  UPDATE lesson_requests
     SET request_status = 'AUTO_CANCELLED', auto_cancel_reason = 'TIME_CONFLICT'
   WHERE request_status = 'PENDING' AND request_id <> p_request_id
     AND time_range && v_req.time_range
     AND (student_id IN (v_student, v_teacher) OR teacher_id IN (v_student, v_teacher));

  RETURN v_req;
EXCEPTION
  -- Kod hatası olsa bile EXCLUDE kısıtı son savunma hattıdır; kullanıcıya aynı kodu ver.
  WHEN exclusion_violation THEN
    RAISE EXCEPTION 'TIME_CONFLICT' USING ERRCODE = 'P0001';
END $$;

-- ===== Token aktarımı (iç fonksiyon; çağıran satır kilitlerini tutuyor olmalı) =====
CREATE FUNCTION settle_request_internal(p_request_id uuid, p_basis text, p_now timestamptz)
RETURNS lesson_requests LANGUAGE plpgsql AS $$
DECLARE v_req lesson_requests; v_s_wallet uuid; v_t_wallet uuid;
BEGIN
  SELECT * INTO v_req FROM lesson_requests WHERE request_id = p_request_id;
  IF v_req.completion_status = 'COMPLETED' THEN
    RETURN v_req;                                        -- idempotent: ikinci çağrı hiçbir şey yapmaz
  END IF;
  IF v_req.request_status <> 'ACCEPTED' OR v_req.completion_status <> 'AWAITING_CONFIRMATION' THEN
    RAISE EXCEPTION 'REQUEST_NOT_SETTLEABLE' USING ERRCODE = 'P0001';
  END IF;
  -- G10: iki cüzdanı HER ZAMAN wallet_id sırasıyla kilitle
  PERFORM 1 FROM wallets WHERE user_id IN (v_req.student_id, v_req.teacher_id) ORDER BY wallet_id FOR UPDATE;
  SELECT wallet_id INTO v_s_wallet FROM wallets WHERE user_id = v_req.student_id;
  SELECT wallet_id INTO v_t_wallet FROM wallets WHERE user_id = v_req.teacher_id;

  IF v_req.agreed_token_amount > 0 THEN
    INSERT INTO wallet_transactions
      (wallet_id, lesson_request_id, transaction_type, available_delta, held_delta, idempotency_key)
    VALUES
      (v_s_wallet, p_request_id, 'SETTLEMENT_DEBIT',  0, -v_req.agreed_token_amount, 'SETTLEMENT_DEBIT:'  || p_request_id),
      (v_t_wallet, p_request_id, 'SETTLEMENT_CREDIT', v_req.agreed_token_amount, 0,  'SETTLEMENT_CREDIT:' || p_request_id);
  END IF;
  UPDATE lesson_requests
     SET completion_status = 'COMPLETED', settled_at = p_now, settlement_basis = p_basis
   WHERE request_id = p_request_id RETURNING * INTO v_req;
  RETURN v_req;
END $$;

-- ===== Ders tamamlama onayı (G4) =====================================
-- Pencere: [ders bitişi, ders bitişi + 24 saat].
CREATE FUNCTION confirm_lesson(p_request_id uuid, p_user_id uuid, p_now timestamptz DEFAULT now())
RETURNS lesson_requests LANGUAGE plpgsql AS $$
DECLARE v_listing_id uuid; v_req lesson_requests;
BEGIN
  SELECT listing_id INTO v_listing_id FROM lesson_requests WHERE request_id = p_request_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'REQUEST_NOT_FOUND' USING ERRCODE = 'P0001'; END IF;
  PERFORM 1 FROM listings WHERE listing_id = v_listing_id FOR UPDATE;
  SELECT * INTO v_req FROM lesson_requests WHERE request_id = p_request_id FOR UPDATE;

  IF p_user_id NOT IN (v_req.student_id, v_req.teacher_id) THEN
    RAISE EXCEPTION 'NOT_A_PARTICIPANT' USING ERRCODE = 'P0001';
  END IF;
  IF v_req.request_status <> 'ACCEPTED' THEN
    RAISE EXCEPTION 'REQUEST_NOT_ACCEPTED' USING ERRCODE = 'P0001';
  END IF;
  -- Aynı kişi ikinci kez onaylarsa: hata değil, sessizce aynı sonuç (istemci tekrar denemesi güvenli)
  IF (p_user_id = v_req.student_id AND v_req.student_completed_at IS NOT NULL)
  OR (p_user_id = v_req.teacher_id AND v_req.teacher_completed_at IS NOT NULL) THEN
    RETURN v_req;
  END IF;
  IF p_now < upper(v_req.time_range) THEN
    RAISE EXCEPTION 'CONFIRMATION_TOO_EARLY' USING ERRCODE = 'P0001';
  END IF;
  -- 24 saatten sonra gelen onay KABUL EDİLMEZ (MANUAL_REVIEW/COMPLETED dahil).
  IF p_now > v_req.confirmation_deadline_at OR v_req.completion_status <> 'AWAITING_CONFIRMATION' THEN
    RAISE EXCEPTION 'CONFIRMATION_WINDOW_CLOSED' USING ERRCODE = 'P0001';
  END IF;

  IF p_user_id = v_req.student_id THEN
    UPDATE lesson_requests SET student_completed_at = p_now WHERE request_id = p_request_id RETURNING * INTO v_req;
  ELSE
    UPDATE lesson_requests SET teacher_completed_at = p_now WHERE request_id = p_request_id RETURNING * INTO v_req;
  END IF;

  IF v_req.student_completed_at IS NOT NULL AND v_req.teacher_completed_at IS NOT NULL THEN
    v_req := settle_request_internal(p_request_id, 'BOTH_CONFIRMED', p_now);
  END IF;
  -- Tek onay: token bloke KALIR; süre dolunca process_expired_confirmations karar verir.
  RETURN v_req;
END $$;

-- ===== Süresi dolan onay penceresi (zamanlanmış iş çağırır) ==========
-- En az bir taraf onayladıysa -> token öğretmene aktarılır.
-- Hiç kimse onaylamadıysa    -> MANUAL_REVIEW, token bloke kalır.
-- Dönüş: 'NOOP' | 'SETTLED' | 'MANUAL_REVIEW'
CREATE FUNCTION finalize_expired_request(p_request_id uuid, p_now timestamptz DEFAULT now())
RETURNS text LANGUAGE plpgsql AS $$
DECLARE v_listing_id uuid; v_req lesson_requests; v_basis text;
BEGIN
  SELECT listing_id INTO v_listing_id FROM lesson_requests WHERE request_id = p_request_id;
  IF NOT FOUND THEN RETURN 'NOOP'; END IF;
  PERFORM 1 FROM listings WHERE listing_id = v_listing_id FOR UPDATE;
  SELECT * INTO v_req FROM lesson_requests WHERE request_id = p_request_id FOR UPDATE;
  IF v_req.request_status <> 'ACCEPTED'
     OR v_req.completion_status <> 'AWAITING_CONFIRMATION'
     OR p_now <= v_req.confirmation_deadline_at THEN
    RETURN 'NOOP';
  END IF;
  v_basis := CASE
    WHEN v_req.teacher_completed_at IS NOT NULL AND v_req.student_completed_at IS NOT NULL THEN 'BOTH_CONFIRMED'
    WHEN v_req.teacher_completed_at IS NOT NULL THEN 'TEACHER_ONLY_AT_DEADLINE'
    WHEN v_req.student_completed_at IS NOT NULL THEN 'STUDENT_ONLY_AT_DEADLINE'
    ELSE NULL END;
  IF v_basis IS NULL THEN
    UPDATE lesson_requests SET completion_status = 'MANUAL_REVIEW' WHERE request_id = p_request_id;
    RETURN 'MANUAL_REVIEW';
  END IF;
  PERFORM settle_request_internal(p_request_id, v_basis, p_now);
  RETURN 'SETTLED';
END $$;

CREATE FUNCTION process_expired_confirmations(p_now timestamptz DEFAULT now())
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE v_id uuid; v_n integer := 0;
BEGIN
  FOR v_id IN
    SELECT request_id FROM lesson_requests
     WHERE request_status = 'ACCEPTED' AND completion_status = 'AWAITING_CONFIRMATION'
       AND confirmation_deadline_at < p_now
     ORDER BY confirmation_deadline_at, request_id
  LOOP
    IF finalize_expired_request(v_id, p_now) <> 'NOOP' THEN v_n := v_n + 1; END IF;
  END LOOP;
  RETURN v_n;
END $$;

-- ===== G3: ders başlamış ama hâlâ PENDING kalan talepleri kapat =======
-- Doğruluk bu işe BAĞLI DEĞİL (accept zaten LISTING_EXPIRED verir); bu yalnızca temizlik.
CREATE FUNCTION expire_stale_requests(p_now timestamptz DEFAULT now())
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE r record; v_n integer := 0;
BEGIN
  FOR r IN
    SELECT request_id, listing_id FROM lesson_requests
     WHERE request_status = 'PENDING' AND lower(time_range) <= p_now
     ORDER BY request_id
  LOOP
    PERFORM 1 FROM listings WHERE listing_id = r.listing_id FOR UPDATE;
    UPDATE lesson_requests
       SET request_status = 'AUTO_CANCELLED', auto_cancel_reason = 'LISTING_EXPIRED'
     WHERE request_id = r.request_id AND request_status = 'PENDING';
    IF FOUND THEN v_n := v_n + 1; END IF;
  END LOOP;
  RETURN v_n;
END $$;

-- ===== G14: KVKK -- silme yerine anonimleştirme ======================
-- Mekanizma burada; NE ZAMAN çağrılacağı (politika) ürün/hukuk kararıdır.
CREATE FUNCTION anonymize_user(p_user_id uuid) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM 1 FROM users WHERE user_id = p_user_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'USER_NOT_FOUND' USING ERRCODE = 'P0001'; END IF;
  PERFORM 1 FROM wallets WHERE user_id = p_user_id FOR UPDATE;
  IF EXISTS (SELECT 1 FROM wallets WHERE user_id = p_user_id AND held_balance > 0)
     OR EXISTS (SELECT 1 FROM lesson_requests
                 WHERE p_user_id IN (student_id, teacher_id) AND request_status = 'ACCEPTED'
                   AND completion_status IN ('AWAITING_CONFIRMATION','MANUAL_REVIEW')) THEN
    RAISE EXCEPTION 'USER_HAS_ACTIVE_OBLIGATIONS' USING ERRCODE = 'P0001';
  END IF;
  UPDATE users
     SET first_name = 'Silinmiş', last_name = 'Kullanıcı', birth_date = DATE '1900-01-01',
         email = 'anon-' || user_id || '@anonymized.invalid',
         phone = 'anon-' || left(replace(user_id::text, '-', ''), 24),
         password_hash = '!', email_verified_at = NULL, anonymized_at = now()
   WHERE user_id = p_user_id AND anonymized_at IS NULL;
  UPDATE auth_tokens SET revoked_at = now()
   WHERE user_id = p_user_id AND used_at IS NULL AND revoked_at IS NULL;
END $$;

-- ===== G13: bütünlük denetim görünümü (boş dönmeli) ==================
CREATE VIEW v_integrity_violations AS
  -- 1) cüzdan = defter toplamı
  SELECT 'WALLET_NE_LEDGER'::text AS check_name, w.wallet_id::text AS entity_id,
         format('wallet(avail=%s, held=%s) ledger(avail=%s, held=%s)',
                w.available_balance, w.held_balance, COALESCE(t.a,0), COALESCE(t.h,0)) AS detail
    FROM wallets w
    LEFT JOIN (SELECT wallet_id, sum(available_delta) a, sum(held_delta) h
                 FROM wallet_transactions GROUP BY wallet_id) t USING (wallet_id)
   WHERE w.available_balance <> COALESCE(t.a,0) OR w.held_balance <> COALESCE(t.h,0)
  UNION ALL
  -- 2) bloke bakiye = öğrencinin sonuçlanmamış kabul edilmiş derslerinin toplam tutarı
  SELECT 'HELD_NE_OPEN_LESSONS', w.wallet_id::text,
         format('held=%s open_sum=%s', w.held_balance, COALESCE(r.s,0))
    FROM wallets w
    LEFT JOIN (SELECT student_id, sum(agreed_token_amount) s FROM lesson_requests
                WHERE request_status = 'ACCEPTED'
                  AND completion_status IN ('AWAITING_CONFIRMATION','MANUAL_REVIEW')
                GROUP BY student_id) r ON r.student_id = w.user_id
   WHERE w.held_balance <> COALESCE(r.s,0)
  UNION ALL
  -- 3) kabul edilmiş ücretli ders için HOLD satırı yok
  SELECT 'ACCEPTED_WITHOUT_HOLD', lr.request_id::text, 'HOLD ledger row missing'
    FROM lesson_requests lr
   WHERE lr.request_status = 'ACCEPTED' AND lr.agreed_token_amount > 0
     AND NOT EXISTS (SELECT 1 FROM wallet_transactions x
                      WHERE x.lesson_request_id = lr.request_id AND x.transaction_type = 'HOLD')
  UNION ALL
  -- 4) tamamlanmış ücretli ders için tam 2 settlement satırı olmalı
  SELECT 'COMPLETED_WITHOUT_SETTLEMENT', lr.request_id::text, 'expected 2 settlement rows'
    FROM lesson_requests lr
   WHERE lr.completion_status = 'COMPLETED' AND lr.agreed_token_amount > 0
     AND (SELECT count(*) FROM wallet_transactions x
           WHERE x.lesson_request_id = lr.request_id
             AND x.transaction_type IN ('SETTLEMENT_DEBIT','SETTLEMENT_CREDIT')) <> 2
  UNION ALL
  -- 5) kabul edilmiş talebin 2 zaman dilimi ve 1 konuşması olmalı
  SELECT 'ACCEPTED_WITHOUT_SLOTS_OR_CONVERSATION', lr.request_id::text, 'slots/conversation missing'
    FROM lesson_requests lr
   WHERE lr.request_status = 'ACCEPTED'
     AND ((SELECT count(*) FROM accepted_slots s WHERE s.request_id = lr.request_id) <> 2
          OR NOT EXISTS (SELECT 1 FROM conversations c WHERE c.lesson_request_id = lr.request_id))
  UNION ALL
  -- 6) ilan durumu ile talep durumu tutarlı mı
  SELECT 'LISTING_STATUS_MISMATCH', l.listing_id::text, 'listing=' || l.status
    FROM listings l
    LEFT JOIN lesson_requests a ON a.listing_id = l.listing_id AND a.request_status = 'ACCEPTED'
   WHERE (l.status = 'PUBLISHED' AND a.request_id IS NOT NULL)
      OR (l.status = 'BOOKED'    AND (a.request_id IS NULL OR a.completion_status = 'COMPLETED'))
      OR (l.status = 'COMPLETED' AND (a.request_id IS NULL OR a.completion_status <> 'COMPLETED'));
