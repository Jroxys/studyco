-- Gerçek ders ve kafe listesini CSV'den yükler. Çalıştırma (proje kök dizininden):
--     psql -d studyco -f seeds/load_catalog.sql
--
-- CSV dosyaları (UTF-8, ilk satır başlık):
--   seeds/data/courses.csv   : department_name,course_name
--                              department_name, departments tablosundaki adla BİREBİR aynı olmalı.
--   seeds/data/locations.csv : name,description,latitude,longitude   (description/lat/lng boş olabilir;
--                              lat ve lng ya ikisi de dolu ya ikisi de boş)
-- Bu dosyalara yalnızca DOĞRULANMIŞ gerçek veri girin; veri uydurmayın.
-- İdempotent: aynı satırı tekrar yüklemek çift kayıt oluşturmaz.
\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE stg_courses   (department_name text, course_name text);
CREATE TEMP TABLE stg_locations (name text, description text, latitude numeric(9,6), longitude numeric(9,6));

\copy stg_courses FROM 'seeds/data/courses.csv' WITH (FORMAT csv, HEADER true)
\copy stg_locations FROM 'seeds/data/locations.csv' WITH (FORMAT csv, HEADER true)

-- Bilinmeyen bölüm adı varsa HİÇBİR ŞEY yüklenmesin (sessizce atlama yok).
DO $$
DECLARE v_bad text;
BEGIN
  SELECT string_agg(DISTINCT s.department_name, ', ') INTO v_bad
    FROM stg_courses s LEFT JOIN departments d ON d.name = s.department_name
   WHERE d.department_id IS NULL;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'courses.csv: tanımsız bölüm adı: %', v_bad;
  END IF;
END $$;

INSERT INTO courses (department_id, course_name)
SELECT d.department_id, btrim(s.course_name)
  FROM stg_courses s JOIN departments d ON d.name = s.department_name
ON CONFLICT (department_id, course_name) DO NOTHING;

INSERT INTO locations (name, description, latitude, longitude)
SELECT btrim(name), NULLIF(btrim(description), ''), latitude, longitude FROM stg_locations
ON CONFLICT (name) DO NOTHING;

COMMIT;

SELECT (SELECT count(*) FROM courses)   AS courses_total,
       (SELECT count(*) FROM locations) AS locations_total;
