-- Seed: yalnızca ürün ekibinin verdiği ilk bölüm listesi (şartname 3.1).
-- Bu listenin üniversitenin eksiksiz resmi bölüm kataloğu olduğu iddia EDİLMEZ.
-- "Diğer" arayüzde görünür ama MVP'de işlevsizdir: bilerek BURAYA EKLENMEZ (geçerli bölüm değil).
-- Idempotent: tekrar çalıştırmak çift kayıt oluşturmaz.
INSERT INTO departments (name) VALUES
  ('Bilgisayar Mühendisliği'),
  ('Yazılım Mühendisliği'),
  ('Elektrik-Elektronik Mühendisliği'),
  ('Makine Mühendisliği'),
  ('İşletme'),
  ('İktisat'),
  ('Hukuk'),
  ('Tıp'),
  ('Psikoloji')
ON CONFLICT (name) DO NOTHING;
