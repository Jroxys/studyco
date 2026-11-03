-- Test yardımcıları (yalnızca test veritabanında, "test" şemasında yaşar)
CREATE SCHEMA IF NOT EXISTS test;
CREATE SEQUENCE IF NOT EXISTS test.seq;

-- Beklenen hata gerçekten oluştu mu? (mesajda p_expect geçmeli: kısıt adı veya hata kodu)
CREATE FUNCTION test.expect_error(p_sql text, p_expect text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE v_failed boolean := false; v_msg text := '';
BEGIN
  BEGIN
    EXECUTE p_sql;
  EXCEPTION WHEN OTHERS THEN
    v_failed := true; v_msg := SQLERRM;
  END;
  IF NOT v_failed THEN
    RAISE EXCEPTION 'BEKLENEN HATA OLUŞMADI (beklenen: %) sql: %', p_expect, p_sql;
  END IF;
  IF position(p_expect IN v_msg) = 0 THEN
    RAISE EXCEPTION 'YANLIŞ HATA: beklenen "%", gelen "%"', p_expect, v_msg;
  END IF;
END $$;

CREATE FUNCTION test.eq(p_actual anycompatible, p_expected anycompatible, p_msg text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_actual IS DISTINCT FROM p_expected THEN
    RAISE EXCEPTION 'BAŞARISIZ: % (beklenen=%, gelen=%)', p_msg, p_expected, p_actual;
  END IF;
END $$;

CREATE FUNCTION test.integrity_ok() RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM v_integrity_violations) THEN
    RAISE EXCEPTION 'BÜTÜNLÜK İHLALİ: %',
      (SELECT string_agg(check_name || ' ' || detail, '; ') FROM v_integrity_violations);
  END IF;
END $$;

CREATE FUNCTION test.base_time() RETURNS timestamptz LANGUAGE sql STABLE AS
$$ SELECT date_trunc('hour', now()) + interval '3 days' $$;

CREATE FUNCTION test.raw_user_sql(p_dept uuid, p_email text, p_phone text) RETURNS text
LANGUAGE sql AS $$
  SELECT format($f$INSERT INTO users (department_id, first_name, last_name, birth_date, email, phone,
                    password_hash, terms_accepted_at, terms_version)
                  VALUES (%L, 'Ad', 'Soyad', '2003-05-05', %L, %L, 'argon2id$test', now(), 'v1')$f$,
                p_dept, p_email, p_phone)
$$;

CREATE FUNCTION test.mk_user(p_dept text DEFAULT 'Bilgisayar Mühendisliği') RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE n bigint := nextval('test.seq'); v_id uuid;
BEGIN
  INSERT INTO users (department_id, first_name, last_name, birth_date, email, phone,
                     password_hash, terms_accepted_at, terms_version)
  VALUES ((SELECT department_id FROM departments WHERE name = p_dept),
          'T' || n, 'Kullanici', '2003-05-05', 'u' || n || '@test.local',
          '+90555' || lpad(n::text, 7, '0'), 'argon2id$test', now(), 'v1')
  RETURNING user_id INTO v_id;
  RETURN v_id;
END $$;

CREATE FUNCTION test.fx_course(p_dept text) RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT c.course_id FROM courses c JOIN departments d USING (department_id)
    WHERE d.name = p_dept AND c.course_name = 'TEST_FIXTURE Ders' $$;

CREATE FUNCTION test.ins_listing(p_teacher uuid, p_course uuid, p_start timestamptz,
                                 p_end timestamptz, p_price int) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO listings (teacher_id, course_id, location_id, topic, start_at, end_at, token_price)
  VALUES (p_teacher, p_course, (SELECT location_id FROM locations WHERE name = 'TEST_FIXTURE Kafe A'),
          'Test konusu', p_start, p_end, p_price)
  RETURNING listing_id
$$;

-- Öğretmenin KENDİ bölümündeki fixture dersle ilan açar.
CREATE FUNCTION test.mk_listing(p_teacher uuid, p_start timestamptz, p_minutes int DEFAULT 60,
                                p_price int DEFAULT 1) RETURNS uuid
LANGUAGE sql AS $$
  SELECT test.ins_listing(
    p_teacher,
    (SELECT c.course_id FROM courses c JOIN users u ON u.department_id = c.department_id
      WHERE u.user_id = p_teacher AND c.course_name = 'TEST_FIXTURE Ders'),
    p_start, p_start + make_interval(mins => p_minutes), p_price)
$$;

CREATE FUNCTION test.mk_request(p_listing uuid, p_student uuid) RETURNS uuid LANGUAGE sql AS
$$ INSERT INTO lesson_requests (listing_id, student_id) VALUES (p_listing, p_student) RETURNING request_id $$;

CREATE FUNCTION test.teacher_of(p_request uuid) RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT teacher_id FROM lesson_requests WHERE request_id = p_request $$;

CREATE FUNCTION test.student_of(p_request uuid) RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT student_id FROM lesson_requests WHERE request_id = p_request $$;

CREATE FUNCTION test.accept(p_request uuid) RETURNS void LANGUAGE sql AS
$$ SELECT accept_lesson_request(p_request, test.teacher_of(p_request)) $$;

CREATE FUNCTION test.lesson_end(p_request uuid) RETURNS timestamptz LANGUAGE sql STABLE AS
$$ SELECT upper(time_range) FROM lesson_requests WHERE request_id = p_request $$;

-- Her iki tarafın da ders bitiminden sonra onay vermesi
CREATE FUNCTION test.complete(p_request uuid) RETURNS void LANGUAGE sql AS
$$ SELECT confirm_lesson(p_request, test.student_of(p_request), test.lesson_end(p_request) + interval '1 hour');
   SELECT confirm_lesson(p_request, test.teacher_of(p_request), test.lesson_end(p_request) + interval '2 hours') $$;

-- Fonksiyonu atlayarak DOĞRUDAN UPDATE ile kabul (kısıt/trigger savunmasını sınamak için)
CREATE FUNCTION test.raw_accept(p_request uuid) RETURNS void LANGUAGE sql AS
$$ UPDATE lesson_requests lr
      SET request_status = 'ACCEPTED', completion_status = 'AWAITING_CONFIRMATION',
          agreed_token_amount = (SELECT token_price FROM listings l WHERE l.listing_id = lr.listing_id),
          responded_at = now(), confirmation_deadline_at = upper(lr.time_range) + interval '24 hours'
    WHERE request_id = p_request $$;

CREATE FUNCTION test.avail(p_user uuid) RETURNS int LANGUAGE sql STABLE AS
$$ SELECT available_balance FROM wallets WHERE user_id = p_user $$;
CREATE FUNCTION test.held(p_user uuid) RETURNS int LANGUAGE sql STABLE AS
$$ SELECT held_balance FROM wallets WHERE user_id = p_user $$;

CREATE FUNCTION test.req_status(p_request uuid) RETURNS text LANGUAGE sql STABLE AS
$$ SELECT request_status FROM lesson_requests WHERE request_id = p_request $$;
CREATE FUNCTION test.compl_status(p_request uuid) RETURNS text LANGUAGE sql STABLE AS
$$ SELECT completion_status FROM lesson_requests WHERE request_id = p_request $$;

CREATE FUNCTION test.ledger_rows(p_request uuid, p_type text DEFAULT NULL) RETURNS bigint LANGUAGE sql STABLE AS
$$ SELECT count(*) FROM wallet_transactions
    WHERE lesson_request_id = p_request AND (p_type IS NULL OR transaction_type = p_type) $$;

-- ---- Eşzamanlılık testleri için KALICI (commit edilen) veri kuran fonksiyonlar -------------
-- Aynı ilana n öğrenci talep etmiş. Dönüş: 'öğretmen|talep1,talep2,...|ilan'
CREATE FUNCTION test.race_same_listing(n int) RETURNS text LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); l uuid; rs text[] := '{}'; r uuid;
BEGIN
  l := test.mk_listing(t, test.base_time() + interval '10 days' + (nextval('test.seq') % 500) * interval '1 hour', 60, 1);
  FOR i IN 1..n LOOP rs := rs || test.mk_request(l, test.mk_user())::text; END LOOP;
  RETURN t::text || '|' || array_to_string(rs, ',') || '|' || l::text;
END $$;

-- Tek öğrenci, birbiriyle çakışan n farklı ilana (n farklı öğretmen) talep etmiş.
-- Dönüş: 'öğrenci|öğretmen1:talep1,öğretmen2:talep2,...'
CREATE FUNCTION test.race_student_overlap(n int) RETURNS text LANGUAGE plpgsql AS $$
DECLARE s uuid := test.mk_user(); t uuid; l uuid; r uuid; pairs text[] := '{}';
        base timestamptz := test.base_time() + interval '20 days' + (nextval('test.seq') % 500) * interval '1 hour';
BEGIN
  FOR i IN 1..n LOOP
    t := test.mk_user();
    l := test.mk_listing(t, base + (i * 10) * interval '1 minute', 60, 1);
    r := test.mk_request(l, s);
    pairs := pairs || (t::text || ':' || r::text);
  END LOOP;
  RETURN s::text || '|' || array_to_string(pairs, ',');
END $$;

-- Çapraz rol: U, A ilanının öğretmeni ve B ilanının öğrencisi (A ve B çakışıyor).
-- Dönüş: 'U|talepA|talepB|öğretmenB'
CREATE FUNCTION test.race_cross_role() RETURNS text LANGUAGE plpgsql AS $$
DECLARE u uuid := test.mk_user(); s1 uuid := test.mk_user(); t2 uuid := test.mk_user();
        a uuid; b uuid; ra uuid; rb uuid;
        base timestamptz := test.base_time() + interval '30 days' + (nextval('test.seq') % 500) * interval '1 hour';
BEGIN
  a := test.mk_listing(u,  base, 60, 1);
  b := test.mk_listing(t2, base + interval '20 minutes', 60, 1);
  ra := test.mk_request(a, s1);
  rb := test.mk_request(b, u);
  RETURN u::text || '|' || ra::text || '|' || rb::text || '|' || t2::text;
END $$;

-- Kabul edilmiş ders (kabul edilmiş, onay bekliyor). Dönüş: 'talep|öğrenci|öğretmen|ders_bitişi'
CREATE FUNCTION test.race_accepted_lesson(p_price int DEFAULT 2) RETURNS text LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user(); l uuid; r uuid;
BEGIN
  l := test.mk_listing(t, test.base_time() + interval '40 days' + (nextval('test.seq') % 500) * interval '1 hour', 60, p_price);
  r := test.mk_request(l, s);
  PERFORM accept_lesson_request(r, t);
  RETURN r::text || '|' || s::text || '|' || t::text || '|' || to_char(test.lesson_end(r), 'YYYY-MM-DD HH24:MI:SS.US TZH');
END $$;
