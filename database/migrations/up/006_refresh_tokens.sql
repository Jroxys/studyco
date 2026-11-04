-- =====================================================================
-- 006_refresh_tokens.sql (UP): API oturumları için refresh token'lar
-- =====================================================================
-- Backend (JWT access + döndürülen refresh token) için eklendi. Düz token ASLA saklanmaz;
-- token_hash = SHA-256(32 rastgele bayt). Token 256 bit entropili olduğundan düz SHA-256 yeterlidir
-- (6 haneli OTP'nin aksine kaba kuvvetle kırılamaz); bu yüzden hash UNIQUE olabilir.
-- family_id: aynı oturumun döndürme zinciri. Eski bir token yeniden kullanılırsa tüm aile iptal edilir.
-- ---------------------------------------------------------------------
CREATE TABLE refresh_tokens (
  token_id    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
  family_id   uuid        NOT NULL,
  token_hash  text        NOT NULL,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  replaced_by uuid        REFERENCES refresh_tokens(token_id) ON DELETE RESTRICT,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT refresh_tokens_hash_uq UNIQUE (token_hash),
  CONSTRAINT refresh_tokens_hash_ck CHECK (token_hash <> ''),
  CONSTRAINT refresh_tokens_expiry_ck CHECK (expires_at > created_at)
);
CREATE INDEX refresh_tokens_user_idx   ON refresh_tokens (user_id) WHERE revoked_at IS NULL;
CREATE INDEX refresh_tokens_family_idx ON refresh_tokens (family_id);
