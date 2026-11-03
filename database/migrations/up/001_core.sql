-- =====================================================================
-- 001_core.sql (UP): eklentiler, bölümler, kullanıcılar, dersler,
--                    lokasyonlar, doğrulama kodları
-- =====================================================================
-- NEDEN bu eklentiler?
--  * citext     : e-postayı büyük/küçük harf duyarsız ve UNIQUE tutmak için
--                 (a@x.com ile A@X.com aynı kişidir).
--  * btree_gist : "aynı kullanıcı + çakışan zaman aralığı" kısıtını (EXCLUDE)
--                 kurabilmek için. GiST indeksi normalde uuid eşitliğini
--                 bilmez; bu eklenti bilgi verir.
-- Minimum PostgreSQL sürümü: 13 (gen_random_uuid() yerleşik). 16'da test edildi.
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Ortak yardımcı: updated_at alanını otomatik günceller.
CREATE FUNCTION set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

-- ---------------------------------------------------------------------
-- departments
-- ---------------------------------------------------------------------
CREATE TABLE departments (
  department_id uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name          varchar(120) NOT NULL,
  is_active     boolean     NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT departments_name_uq UNIQUE (name),
  CONSTRAINT departments_name_nonblank_ck CHECK (btrim(name) <> '')
);

-- ---------------------------------------------------------------------
-- users  (rol alanı YOK: aynı kişi bir derste öğretmen, başkasında öğrenci)
-- ---------------------------------------------------------------------
CREATE TABLE users (
  user_id           uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id     uuid         NOT NULL REFERENCES departments(department_id) ON DELETE RESTRICT,
  first_name        varchar(80)  NOT NULL,
  last_name         varchar(80)  NOT NULL,
  birth_date        date         NOT NULL,
  email             citext       NOT NULL,
  phone             varchar(30)  NOT NULL,
  password_hash     text         NOT NULL,   -- argon2id çıktısı; düz parola ASLA
  email_verified_at timestamptz,
  terms_accepted_at timestamptz  NOT NULL,
  terms_version     varchar(32)  NOT NULL,
  anonymized_at     timestamptz,             -- KVKK: silme yerine anonimleştirme
  created_at        timestamptz  NOT NULL DEFAULT now(),
  updated_at        timestamptz  NOT NULL DEFAULT now(),
  CONSTRAINT users_email_uq UNIQUE (email),
  CONSTRAINT users_phone_uq UNIQUE (phone),
  CONSTRAINT users_names_ck CHECK (btrim(first_name) <> '' AND btrim(last_name) <> ''),
  CONSTRAINT users_email_format_ck CHECK (position('@' IN email::text) > 1),
  -- Telefon normalize edilmiş E.164 olmalı (+905xxxxxxxxx). Anonimleşmiş kayıt hariç.
  CONSTRAINT users_phone_format_ck CHECK (anonymized_at IS NOT NULL OR phone ~ '^\+[1-9][0-9]{7,14}$'),
  CONSTRAINT users_password_hash_ck CHECK (password_hash <> '')
);
CREATE TRIGGER users_set_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------
-- courses
-- ---------------------------------------------------------------------
CREATE TABLE courses (
  course_id     uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id uuid         NOT NULL REFERENCES departments(department_id) ON DELETE RESTRICT,
  course_name   varchar(150) NOT NULL,
  is_active     boolean      NOT NULL DEFAULT true,
  created_at    timestamptz  NOT NULL DEFAULT now(),
  -- Aynı ders adı farklı bölümlerde olabilir; bölüm içinde tekrarlanamaz.
  CONSTRAINT courses_dept_name_uq UNIQUE (department_id, course_name),
  CONSTRAINT courses_name_nonblank_ck CHECK (btrim(course_name) <> '')
);

-- ---------------------------------------------------------------------
-- locations (kampüs kafeleri; kullanıcı ekleyemez -> uygulama rolüne INSERT verilmez)
-- ---------------------------------------------------------------------
CREATE TABLE locations (
  location_id uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  name        varchar(150) NOT NULL,
  description text,
  latitude    numeric(9,6),
  longitude   numeric(9,6),
  is_active   boolean      NOT NULL DEFAULT true,
  CONSTRAINT locations_name_uq UNIQUE (name),
  CONSTRAINT locations_name_nonblank_ck CHECK (btrim(name) <> ''),
  CONSTRAINT locations_lat_ck CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
  CONSTRAINT locations_lng_ck CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
  CONSTRAINT locations_latlng_pair_ck CHECK ((latitude IS NULL) = (longitude IS NULL))
);

-- ---------------------------------------------------------------------
-- auth_tokens (e-posta doğrulama / parola sıfırlama kodları)
-- ---------------------------------------------------------------------
-- NEDEN token_hash UNIQUE DEĞİL? 6 haneli kodun yalnızca 10^6 olasılığı var.
-- İki kullanıcıda aynı kod çıkarsa UNIQUE hata verir ve başkasının kodu hakkında
-- bilgi sızar. Bunun yerine "kullanıcı+amaç başına tek AKTİF kod" kuralı var.
-- token_hash = HMAC-SHA256(sunucu_sırrı, kod) olmalı (backend hesaplar).
-- Düz SHA-256 yetmez: 10^6 olasılık çalınan DB'de saniyeler içinde kırılır.
CREATE TABLE auth_tokens (
  auth_token_id uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid        NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
  purpose       varchar(30) NOT NULL,
  token_hash    text        NOT NULL,
  attempt_count smallint    NOT NULL DEFAULT 0,
  expires_at    timestamptz NOT NULL,
  used_at       timestamptz,
  revoked_at    timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT auth_tokens_purpose_ck CHECK (purpose IN ('EMAIL_VERIFICATION','PASSWORD_RESET')),
  CONSTRAINT auth_tokens_attempt_ck CHECK (attempt_count >= 0),
  CONSTRAINT auth_tokens_hash_ck CHECK (token_hash <> ''),
  CONSTRAINT auth_tokens_expiry_ck CHECK (expires_at > created_at)
);
-- Aynı kullanıcı+amaç için aynı anda en fazla bir aktif (kullanılmamış, iptal edilmemiş) kod.
CREATE UNIQUE INDEX auth_tokens_one_active_uq
  ON auth_tokens (user_id, purpose)
  WHERE used_at IS NULL AND revoked_at IS NULL;
