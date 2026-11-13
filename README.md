# StudyCo

Üniversite içi, token (kahve) ekonomili birebir ders eşleştirme uygulaması.

| Klasör | İçerik |
| --- | --- |
| [`database/`](database/README.md) | PostgreSQL şeması, migration'lar, katalog verisi ve SQL testleri |
| [`backend/`](backend/README.md) | Node.js + TypeScript + Fastify REST API (`/api/v1`) |
| [`mobile/studyco_mobile/`](mobile/studyco_mobile/README.md) | Flutter istemcisi |

Akış: **Flutter → REST API → PostgreSQL.** Mobil uygulama veritabanına doğrudan bağlanmaz.

## Gereksinimler

- PostgreSQL 16 (`brew install postgresql@16 && brew services start postgresql@16`)
- Node.js 22 veya üstü
- Flutter 3.x (iOS için Xcode, Android için Android Studio)

## Yerelde çalıştırma

```bash
# 1) Veritabanı: oluştur, migration'ları uygula, ders ve kafe listesini yükle
cd database
bash scripts/setup_db.sh
psql -d studyco -f seeds/load_catalog.sql

# 2) Backend
cd ../backend
npm ci
cp .env.example .env   # DATABASE_URL, JWT_SECRET ve OTP_HMAC_SECRET değerlerini doldur
npm run dev            # http://127.0.0.1:3000

# 3) Mobil uygulama
cd ../mobile/studyco_mobile
flutter pub get
flutter run            # iOS simülatörü 127.0.0.1'e, Android emülatörü 10.0.2.2'ye bağlanır
```

### Web sürümü (sunum için en kolayı)

```bash
cd backend && HOST=0.0.0.0 npm run dev                     # 1. terminal
cd mobile/studyco_mobile && flutter build web --release   # kod değişince bir kez
cd build/web && python3 -m http.server 8080 --bind 0.0.0.0 # 2. terminal
```

Bilgisayarda `http://127.0.0.1:8080` adresini aç. Aynı Wi-Fi'deki bir telefondan açmak için
`http://BILGISAYARIN_IP_ADRESI:8080` kullan (IP: `ipconfig getifaddr en0`). Web sürümü API'yi
sayfanın geldiği makinenin 3000 portunda arar. Geliştirme modunda backend her tarayıcı adresinden gelen isteği kabul eder.

- Gerçek bir telefonda çalıştırırken backend'i `HOST=0.0.0.0` ile başlat ve uygulamaya bilgisayarın IP adresini ver:
  `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000`
- Geliştirmede `SMTP_URL` boş bırakılırsa doğrulama ve şifre sıfırlama kodları backend log'una yazılır.
  Production ortamında `SMTP_URL` zorunludur.

## Testler

```bash
cd database && bash scripts/run_tests.sh                        # SQL + eşzamanlılık testleri
cd backend && echo "TEST_PG_ADMIN_URL=postgresql://$USER@127.0.0.1:5432/postgres" > .env.test && npm test
cd mobile/studyco_mobile && flutter analyze && flutter test
```

## Bilinen sınırlar

- **Mesajlaşma:** Backend'de `/conversations` uçları var ama Flutter'da henüz mesaj ekranı yok.
- **Bildirimler:** Backend'de bildirim ucu yok. Uygulama bildirimleri başvuru durumlarından türetiyor, okundu bilgisi yalnızca o oturumda tutuluyor.
- **İlan düzenleme ve silme:** Backend yalnızca konu ve açıklama güncellemeyi destekliyor, silme ucu yok. Bu yüzden uygulamada düzenleme ve silme kapalı.
- **E-posta doğrulama ekranı:** `REQUIRE_VERIFIED_EMAIL=false` (varsayılan) iken gerekmiyor. Açılırsa uygulamaya doğrulama ekranı eklenmeli.
- **iCloud Masaüstü:** Proje iCloud ile eşitlenen bir klasördeyse (ör. Masaüstü) iOS derlemesi
  `resource fork, Finder information, or similar detritus not allowed` hatası verebilir. Projeyi iCloud dışındaki bir klasöre taşıyın.
