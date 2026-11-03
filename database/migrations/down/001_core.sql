-- 001_core.sql (DOWN) -- YIKICI: tüm kullanıcı/bölüm/ders verisini siler.
-- Eklentiler (citext, btree_gist) başka veritabanı nesneleri kullanıyor olabilir; bilerek bırakılır.
DROP TABLE IF EXISTS auth_tokens;
DROP TABLE IF EXISTS locations;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS departments;
DROP FUNCTION IF EXISTS set_updated_at();
