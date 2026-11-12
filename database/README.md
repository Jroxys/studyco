# StudyCo veritabanı (PostgreSQL)

MVP veritabanı: tek üniversite, token ekonomili birebir ders pazarı. Flutter veritabanına bağlanmaz; yalnızca
Node.js backend bağlanır. **Önce `docs/RAPOR.md` dosyasını okuyun** (kararlar, varsayımlar, açık noktalar).

## Gereksinimler

- PostgreSQL **13 veya üstü** (16'da test edildi) ve `contrib` paketi (`citext`, `btree_gist`). Homebrew ve Postgres.app bunları içerir.
- `psql`, `createdb` komutları terminalde çalışmalı. Kontrol: `psql --version`

## Kurulum (kendi makinenizde)

```bash
cd database   # repo kökünden
bash scripts/setup_db.sh        # 'studyco' veritabanını oluşturur, migration'ları uygular, bölümleri yükler
bash scripts/run_tests.sh       # testleri GEÇİCİ bir veritabanında çalıştırır, sonra o geçici veritabanını siler
```

- `setup_db.sh` var olan hiçbir veritabanını silmez; `studyco` zaten varsa yalnızca eksik migration'ları uygular.
- Bağlantı için libpq ortam değişkenleri kullanılır: `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`. Parola dosyalara **yazılmaz**.
  Postgres.app/Homebrew kurulumlarında genellikle ek ayar gerekmez (kullanıcı adınız süper kullanıcıdır).
  Parola isterse: `PGPASSWORD='...' bash scripts/setup_db.sh` (komut geçmişinde kalabilir; `~/.pgpass` daha güvenlidir).
- Başka ad istiyorsanız: `STUDYCO_DB=baska_ad bash scripts/setup_db.sh`
- Migration durumu: `bash scripts/migrate.sh status`. Geri alma veri **siler**:
  `CONFIRM_DESTRUCTIVE=yes bash scripts/migrate.sh down 1`

### Gerçek ders ve kafe verisi

`courses` ve `locations` tabloları migration'larla boş gelir. Ders (~617) ve kafe (9) listesi `seeds/data/courses.csv` ve
`seeds/data/locations.csv` dosyalarında hazırdır; `database/` klasöründeyken yükleyin: `psql -d studyco -f seeds/load_catalog.sql`.
Yüklenene kadar uygulamada ilan açılamaz. Test sahte verisi (`tests/fixtures.sql`) yalnızca geçici test veritabanına girer.

## Klasör yapısı ve okuma sırası (öğrenmek için)

| Sıra | Dosya | Ne öğretir |
|---|---|---|
| 1 | `docs/er_diagram.md` | Büyük resim: tablolar ve durum makineleri |
| 2 | `migrations/up/001_core.sql` | Tipler, kısıtlar; neden `citext`, neden hash UNIQUE değil |
| 3 | `migrations/up/002_wallets_ledger.sql` | Defter (ledger) tasarımı: bakiye bir *önbellektir*, gerçek kaynak defter |
| 4 | `migrations/up/003_listings_requests.sql` | Çakışmanın DB seviyesinde çözümü (`accepted_slots` + EXCLUDE), durum kısıtları |
| 5 | `migrations/up/004_messaging_reviews.sql` | Trigger ile bütünlük |
| 6 | `migrations/up/005_functions_views.sql` | Kabul/onay/aktarım akışı, kilit sırası, `v_integrity_violations` |
| 7 | `tests/tests.sql`, `tests/concurrency.sh` | Her kuralın nasıl *kanıtlandığı*, yarış durumu testi |
| 8 | `docs/data_dictionary.md` | Backend'in çağıracağı fonksiyonlar ve hata kodları |

Önerilen alıştırma: `tests/tests.sql` içinde bir kısıtı (örneğin `lr_confirm_window_ck`) geçici olarak kaldırıp
hangi testin kırıldığını izleyin; sonra geri koyun. Kuralın neden orada olduğunu en iyi böyle görürsünüz.

## Backend için üç kritik not

1. Kritik akışları (`accept_lesson_request`, `confirm_lesson`...) bu SQL fonksiyonlarıyla çağırın, tabloları elle güncellemeyin.
   Her çağrı kendi içinde atomiktir. `p_now` parametresini **istemciden gelen değerle doldurmayın**.
2. İki zamanlanmış iş şart: `SELECT process_expired_confirmations();` ve `SELECT expire_stale_requests();`
   (öneri: 5-15 dakikada bir; Node cron veya `pg_cron`). Onay süresi dolan dersler bu işle sonuçlanır.
3. Sorguları her zaman **parametreli** yazın (string birleştirme yok). Parola için argon2id; doğrulama kodu için
   `HMAC-SHA256(sunucu_sırrı, kod)` hash'i saklayın.
