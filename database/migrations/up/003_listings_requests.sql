-- =====================================================================
-- 003_listings_requests.sql (UP): ilanlar, talepler, kabul edilmiş zaman dilimleri
-- =====================================================================
-- ÇAKIŞMA TASARIMI (G1 + G2) -- neden ayrı bir accepted_slots tablosu?
--   Kural: "Bir kullanıcı, hangi rolde olursa olsun, kabul edilmiş iki dersle çakışamaz."
--   Bir EXCLUDE kısıtı yalnızca TEK tablodaki TEK sütunu karşılaştırabilir. Oysa aynı
--   kişi bir satırda student_id, başka satırda teacher_id olabilir. Çözüm: kabul edilen
--   her talep için 2 satır yaz (öğretmen + öğrenci); her satırda "user_id" aynı sütun.
--   Sonra:  EXCLUDE (user_id WITH =, time_range WITH &&)  -> rol fark etmez.
--   Bu kısıt, backend kodu hatalı olsa bile veritabanının çakışmayı reddetmesini sağlar.
--   Aralık '[)' olduğu için 14:00-15:00 ile 15:00-16:00 ÇAKIŞMAZ (spec 3.4.7).
-- ---------------------------------------------------------------------

CREATE TABLE listings (
  listing_id  uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id  uuid         NOT NULL REFERENCES users(user_id)       ON DELETE RESTRICT,
  course_id   uuid         NOT NULL REFERENCES courses(course_id)   ON DELETE RESTRICT,
  location_id uuid         NOT NULL REFERENCES locations(location_id) ON DELETE RESTRICT,
  topic       varchar(160) NOT NULL,
  description text,
  start_at    timestamptz  NOT NULL,
  end_at      timestamptz  NOT NULL,
  -- start_at/end_at'ten türeyen aralık. GREATEST: end<start girilirse range kurucusu
  -- "bound" hatası fırlatmasın, bunun yerine asıl CHECK (listings_time_order_ck) çalışsın.
  time_range  tstzrange    GENERATED ALWAYS AS (tstzrange(start_at, GREATEST(end_at, start_at), '[)')) STORED,
  token_price smallint     NOT NULL,
  -- G3: EXPIRED saklanmaz; "tarihi geçmiş mi" start_at'ten TÜRETİLİR (bkz. v_listing_state).
  status      varchar(20)  NOT NULL DEFAULT 'PUBLISHED',
  created_at  timestamptz  NOT NULL DEFAULT now(),
  updated_at  timestamptz  NOT NULL DEFAULT now(),
  CONSTRAINT listings_time_order_ck CHECK (end_at > start_at),
  CONSTRAINT listings_token_price_ck CHECK (token_price IN (0,1,2,3)),
  CONSTRAINT listings_status_ck CHECK (status IN ('PUBLISHED','BOOKED','COMPLETED')),
  CONSTRAINT listings_topic_ck CHECK (btrim(topic) <> '')
);
CREATE INDEX listings_status_start_idx ON listings (status, start_at);   -- ilan listeleme
CREATE INDEX listings_teacher_idx      ON listings (teacher_id);          -- "benim ilanlarım"
CREATE TRIGGER listings_set_updated_at BEFORE UPDATE ON listings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE lesson_requests (
  request_id   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id   uuid        NOT NULL REFERENCES listings(listing_id) ON DELETE RESTRICT,
  student_id   uuid        NOT NULL REFERENCES users(user_id)       ON DELETE RESTRICT,
  -- SNAPSHOT alanları: insert anında trigger ilandan kopyalar, sonra DEĞİŞTİRİLEMEZ.
  -- (EXCLUDE kısıtı ve "öğretmen kendine talep gönderemez" kuralı bunlara dayanır.)
  teacher_id   uuid        NOT NULL REFERENCES users(user_id)       ON DELETE RESTRICT,
  time_range   tstzrange   NOT NULL,
  request_status    varchar(20) NOT NULL DEFAULT 'PENDING',
  completion_status varchar(24) NOT NULL DEFAULT 'NOT_STARTED',
  agreed_token_amount smallint,           -- kabul anında ilandan kopyalanır
  responded_at        timestamptz,        -- öğretmen kabul/ret zamanı
  auto_cancel_reason  varchar(32),
  student_completed_at timestamptz,
  teacher_completed_at timestamptz,
  confirmation_deadline_at timestamptz,   -- = ders bitişi + 24 saat (kabul anında yazılır)
  settled_at        timestamptz,          -- token aktarımı yapıldığı an
  settlement_basis  varchar(30),          -- aktarım neye dayandı (denetim izi)
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),

  -- O-11 kararı: reddedilse de aynı öğrenci aynı ilana ikinci kez talep gönderemez.
  CONSTRAINT lr_one_per_student_listing_uq UNIQUE (listing_id, student_id),
  -- C5 düzeltmesi: engellenmesi gereken şey ÖĞRETMENİN KENDİ İLANINA talep göndermesi.
  CONSTRAINT lr_not_self_ck CHECK (student_id <> teacher_id),

  CONSTRAINT lr_request_status_ck CHECK (request_status IN ('PENDING','ACCEPTED','REJECTED','AUTO_CANCELLED')),
  CONSTRAINT lr_completion_status_ck CHECK (completion_status IN
    ('NOT_STARTED','AWAITING_CONFIRMATION','COMPLETED','MANUAL_REVIEW')),
  CONSTRAINT lr_cancel_reason_values_ck CHECK (auto_cancel_reason IN
    ('TIME_CONFLICT','LISTING_ALREADY_BOOKED','LISTING_EXPIRED')),
  -- sebep VARSA durum AUTO_CANCELLED, YOKSA değil
  CONSTRAINT lr_cancel_reason_iff_ck CHECK ((request_status = 'AUTO_CANCELLED') = (auto_cancel_reason IS NOT NULL)),
  CONSTRAINT lr_responded_ck CHECK (request_status NOT IN ('ACCEPTED','REJECTED') OR responded_at IS NOT NULL),

  -- G11: iki durum alanı arasındaki tutarlılık (DB seviyesinde)
  CONSTRAINT lr_shape_not_accepted_ck CHECK (
    request_status = 'ACCEPTED' OR (
      completion_status = 'NOT_STARTED' AND agreed_token_amount IS NULL
      AND confirmation_deadline_at IS NULL AND student_completed_at IS NULL
      AND teacher_completed_at IS NULL AND settled_at IS NULL AND settlement_basis IS NULL)),
  CONSTRAINT lr_shape_accepted_ck CHECK (
    request_status <> 'ACCEPTED' OR (
      completion_status <> 'NOT_STARTED' AND agreed_token_amount BETWEEN 0 AND 3
      AND confirmation_deadline_at IS NOT NULL)),

  -- G4: onay penceresi = [ders bitişi, ders bitişi + 24 saat]. DB de bunu zorlar.
  CONSTRAINT lr_deadline_formula_ck CHECK (
    confirmation_deadline_at IS NULL OR confirmation_deadline_at = upper(time_range) + interval '24 hours'),
  CONSTRAINT lr_confirm_window_ck CHECK (
    (student_completed_at IS NULL OR (student_completed_at >= upper(time_range) AND student_completed_at <= confirmation_deadline_at))
    AND
    (teacher_completed_at IS NULL OR (teacher_completed_at >= upper(time_range) AND teacher_completed_at <= confirmation_deadline_at))),

  -- Tamamlanma / aktarım tutarlılığı
  CONSTRAINT lr_completed_iff_settled_ck CHECK ((completion_status = 'COMPLETED') = (settled_at IS NOT NULL)),
  CONSTRAINT lr_basis_iff_settled_ck CHECK ((settlement_basis IS NOT NULL) = (settled_at IS NOT NULL)),
  CONSTRAINT lr_basis_values_ck CHECK (settlement_basis IN
    ('BOTH_CONFIRMED','TEACHER_ONLY_AT_DEADLINE','STUDENT_ONLY_AT_DEADLINE')),
  CONSTRAINT lr_basis_matches_confirmations_ck CHECK (
    settlement_basis IS NULL
    OR (settlement_basis = 'BOTH_CONFIRMED'           AND student_completed_at IS NOT NULL AND teacher_completed_at IS NOT NULL)
    OR (settlement_basis = 'TEACHER_ONLY_AT_DEADLINE' AND teacher_completed_at IS NOT NULL AND student_completed_at IS NULL)
    OR (settlement_basis = 'STUDENT_ONLY_AT_DEADLINE' AND student_completed_at IS NOT NULL AND teacher_completed_at IS NULL)),
  -- Süre dolunca EN AZ BİR onay varsa token aktarılır; MANUAL_REVIEW yalnızca HİÇ onay yokken.
  CONSTRAINT lr_manual_review_no_confirmations_ck CHECK (
    completion_status <> 'MANUAL_REVIEW' OR (student_completed_at IS NULL AND teacher_completed_at IS NULL))
);

-- Bir ilan için aynı anda en fazla BİR kabul edilmiş talep.
CREATE UNIQUE INDEX lr_one_accepted_per_listing_uq
  ON lesson_requests (listing_id) WHERE request_status = 'ACCEPTED';
CREATE INDEX lr_student_status_idx ON lesson_requests (student_id, request_status);
CREATE INDEX lr_teacher_status_idx ON lesson_requests (teacher_id, request_status);
-- Zamanlanmış işler (süre dolumu / tarihi geçmiş bekleyenler) için küçük, kısmi indeksler:
CREATE INDEX lr_deadline_idx ON lesson_requests (confirmation_deadline_at)
  WHERE completion_status = 'AWAITING_CONFIRMATION';
CREATE INDEX lr_pending_start_idx ON lesson_requests ((lower(time_range)))
  WHERE request_status = 'PENDING';

ALTER TABLE wallet_transactions
  ADD CONSTRAINT wtx_request_fk FOREIGN KEY (lesson_request_id)
  REFERENCES lesson_requests(request_id) ON DELETE RESTRICT;

-- ---------------------------------------------------------------------
-- accepted_slots: kabul edilmiş derslerin kullanıcı bazlı zaman dilimleri
-- ---------------------------------------------------------------------
CREATE TABLE accepted_slots (
  slot_id    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
  request_id uuid        NOT NULL REFERENCES lesson_requests(request_id) ON DELETE RESTRICT,
  slot_role  varchar(7)  NOT NULL,
  time_range tstzrange   NOT NULL,
  CONSTRAINT accepted_slots_role_ck CHECK (slot_role IN ('TEACHER','STUDENT')),
  CONSTRAINT accepted_slots_request_role_uq UNIQUE (request_id, slot_role),
  -- G1 + G2: aynı kullanıcı, rolü ne olursa olsun, çakışan iki kabul edilmiş derse sahip olamaz
  CONSTRAINT accepted_slots_user_no_overlap
    EXCLUDE USING gist (user_id WITH =, time_range WITH &&)
);

-- ---------------------------------------------------------------------
-- listings trigger'ları
-- ---------------------------------------------------------------------
CREATE FUNCTION listings_before_insert() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_t_dept uuid; v_t_anon timestamptz; v_c_dept uuid; v_c_active boolean; v_l_active boolean;
BEGIN
  SELECT department_id, anonymized_at INTO v_t_dept, v_t_anon FROM users WHERE user_id = NEW.teacher_id;
  IF v_t_anon IS NOT NULL THEN
    RAISE EXCEPTION 'TEACHER_ANONYMIZED' USING ERRCODE = 'P0001';
  END IF;
  SELECT department_id, is_active INTO v_c_dept, v_c_active FROM courses WHERE course_id = NEW.course_id;
  -- O-01 kararı: ders, öğretmenin kendi bölümünün kataloğundan olmalı
  IF v_c_dept IS DISTINCT FROM v_t_dept THEN
    RAISE EXCEPTION 'COURSE_DEPARTMENT_MISMATCH' USING ERRCODE = 'P0001';
  END IF;
  IF NOT v_c_active THEN
    RAISE EXCEPTION 'COURSE_INACTIVE' USING ERRCODE = 'P0001';
  END IF;
  SELECT is_active INTO v_l_active FROM locations WHERE location_id = NEW.location_id;
  IF NOT COALESCE(v_l_active, false) THEN
    RAISE EXCEPTION 'LOCATION_INACTIVE_OR_UNKNOWN' USING ERRCODE = 'P0001';
  END IF;
  IF NEW.status <> 'PUBLISHED' THEN
    RAISE EXCEPTION 'LISTING_MUST_START_PUBLISHED' USING ERRCODE = 'P0001';
  END IF;
  -- CHECK içinde now() kullanılamaz (immutable değil); bu yüzden geçmiş zaman kontrolü trigger'da.
  IF NEW.start_at <= now() THEN
    RAISE EXCEPTION 'LISTING_START_IN_PAST' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER listings_before_insert BEFORE INSERT ON listings
  FOR EACH ROW EXECUTE FUNCTION listings_before_insert();

CREATE FUNCTION listings_before_update() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status <> OLD.status AND NOT (
       (OLD.status = 'PUBLISHED' AND NEW.status = 'BOOKED')
    OR (OLD.status = 'BOOKED'    AND NEW.status = 'COMPLETED')) THEN
    RAISE EXCEPTION 'LISTING_INVALID_STATUS_TRANSITION' USING ERRCODE = 'P0001';
  END IF;
  IF NEW.teacher_id <> OLD.teacher_id THEN
    RAISE EXCEPTION 'LISTING_TEACHER_IMMUTABLE' USING ERRCODE = 'P0001';
  END IF;
  -- O-09 (güvenli varsayım): ilana bir talep geldiği andan itibaren ders/yer/zaman/fiyat
  -- değiştirilemez. Aksi halde öğrenci, görmediği bir saat/fiyata bağlanabilirdi.
  IF (NEW.course_id, NEW.location_id, NEW.start_at, NEW.end_at, NEW.token_price)
     IS DISTINCT FROM (OLD.course_id, OLD.location_id, OLD.start_at, OLD.end_at, OLD.token_price) THEN
    IF OLD.status <> 'PUBLISHED'
       OR EXISTS (SELECT 1 FROM lesson_requests WHERE listing_id = OLD.listing_id) THEN
      RAISE EXCEPTION 'LISTING_CORE_FIELDS_LOCKED' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER listings_before_update BEFORE UPDATE ON listings
  FOR EACH ROW EXECUTE FUNCTION listings_before_update();

-- ---------------------------------------------------------------------
-- lesson_requests trigger'ları
-- ---------------------------------------------------------------------
CREATE FUNCTION lr_before_insert() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE l listings%ROWTYPE;
BEGIN
  -- FOR SHARE: ilan aynı anda kabul işlemiyle (FOR UPDATE) kilitliyse bekler, sonra
  -- GÜNCEL durumu görür. Böylece "BOOKED ilana yeni PENDING talep" yarış durumu oluşmaz.
  SELECT * INTO l FROM listings WHERE listing_id = NEW.listing_id FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'LISTING_NOT_FOUND' USING ERRCODE = 'P0001';
  END IF;
  IF l.status <> 'PUBLISHED' THEN
    RAISE EXCEPTION 'LISTING_NOT_PUBLISHED' USING ERRCODE = 'P0001';
  END IF;
  IF now() >= l.start_at THEN
    RAISE EXCEPTION 'LISTING_EXPIRED' USING ERRCODE = 'P0001';
  END IF;
  IF NEW.request_status <> 'PENDING' OR NEW.completion_status <> 'NOT_STARTED' THEN
    RAISE EXCEPTION 'REQUEST_MUST_START_PENDING' USING ERRCODE = 'P0001';
  END IF;
  NEW.teacher_id := l.teacher_id;
  NEW.time_range := l.time_range;
  RETURN NEW;
END $$;
CREATE TRIGGER lr_before_insert BEFORE INSERT ON lesson_requests
  FOR EACH ROW EXECUTE FUNCTION lr_before_insert();

CREATE FUNCTION lr_before_update() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF (NEW.listing_id, NEW.student_id, NEW.teacher_id, NEW.time_range)
     IS DISTINCT FROM (OLD.listing_id, OLD.student_id, OLD.teacher_id, OLD.time_range) THEN
    RAISE EXCEPTION 'REQUEST_SNAPSHOT_IMMUTABLE' USING ERRCODE = 'P0001';
  END IF;
  -- request_status: PENDING -> {ACCEPTED, REJECTED, AUTO_CANCELLED}; diğerleri sondur.
  IF NEW.request_status <> OLD.request_status AND OLD.request_status <> 'PENDING' THEN
    RAISE EXCEPTION 'REQUEST_STATUS_TERMINAL' USING ERRCODE = 'P0001';
  END IF;
  -- completion_status: NOT_STARTED -> AWAITING -> {COMPLETED, MANUAL_REVIEW}
  IF NEW.completion_status <> OLD.completion_status AND NOT (
       (OLD.completion_status = 'NOT_STARTED' AND NEW.completion_status = 'AWAITING_CONFIRMATION')
    OR (OLD.completion_status = 'AWAITING_CONFIRMATION' AND NEW.completion_status IN ('COMPLETED','MANUAL_REVIEW'))) THEN
    RAISE EXCEPTION 'COMPLETION_INVALID_TRANSITION' USING ERRCODE = 'P0001';
  END IF;
  IF OLD.agreed_token_amount IS NOT NULL
     AND NEW.agreed_token_amount IS DISTINCT FROM OLD.agreed_token_amount THEN
    RAISE EXCEPTION 'AGREED_AMOUNT_IMMUTABLE' USING ERRCODE = 'P0001';
  END IF;
  -- Verilmiş onay geri alınamaz / değiştirilemez; sonuçlanmış talep değişmez.
  IF (OLD.student_completed_at IS NOT NULL AND NEW.student_completed_at IS DISTINCT FROM OLD.student_completed_at)
  OR (OLD.teacher_completed_at IS NOT NULL AND NEW.teacher_completed_at IS DISTINCT FROM OLD.teacher_completed_at) THEN
    RAISE EXCEPTION 'CONFIRMATION_IMMUTABLE' USING ERRCODE = 'P0001';
  END IF;
  IF OLD.completion_status IN ('COMPLETED','MANUAL_REVIEW')
     AND (NEW.student_completed_at, NEW.teacher_completed_at, NEW.settled_at)
         IS DISTINCT FROM (OLD.student_completed_at, OLD.teacher_completed_at, OLD.settled_at) THEN
    RAISE EXCEPTION 'REQUEST_FINALIZED' USING ERRCODE = 'P0001';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END $$;
CREATE TRIGGER lr_before_update BEFORE UPDATE ON lesson_requests
  FOR EACH ROW EXECUTE FUNCTION lr_before_update();

-- Kabul olunca: (1) iki zaman dilimi satırı yaz -> EXCLUDE devreye girer, (2) ilanı BOOKED yap.
-- Tamamlanınca ilanı COMPLETED yap. Bunlar trigger'da olduğu için DOĞRUDAN UPDATE ile
-- kabul edilse bile kurallar atlanamaz.
CREATE FUNCTION lr_after_update() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.request_status <> 'ACCEPTED' AND NEW.request_status = 'ACCEPTED' THEN
    INSERT INTO accepted_slots (user_id, request_id, slot_role, time_range) VALUES
      (NEW.teacher_id, NEW.request_id, 'TEACHER', NEW.time_range),
      (NEW.student_id, NEW.request_id, 'STUDENT', NEW.time_range);
    UPDATE listings SET status = 'BOOKED' WHERE listing_id = NEW.listing_id;
  END IF;
  IF OLD.completion_status <> 'COMPLETED' AND NEW.completion_status = 'COMPLETED' THEN
    UPDATE listings SET status = 'COMPLETED' WHERE listing_id = NEW.listing_id;
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER lr_after_update AFTER UPDATE ON lesson_requests
  FOR EACH ROW EXECUTE FUNCTION lr_after_update();

-- ---------------------------------------------------------------------
-- G3: tarihi geçen ilan görünümü (EXPIRED türetilir, saklanmaz)
-- "Geçti" = ders başladı (start_at <= now): artık talep kabul edilemez.
-- ---------------------------------------------------------------------
CREATE VIEW v_listing_state AS
SELECT l.*,
       CASE WHEN l.status = 'PUBLISHED' AND l.start_at <= now() THEN 'EXPIRED'
            ELSE l.status END AS effective_status
  FROM listings l;
