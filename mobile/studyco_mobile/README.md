# StudyCo Mobile

Üniversite içi ders çalışma eşleştirme uygulamasının Flutter istemcisi.
`../../backend` içindeki REST API'ye bağlanır. Kurulum için kök dizindeki README'ye bakın.

## Backend bağlantısı

- Adres: `--dart-define=API_BASE_URL=...`. Verilmezse iOS ve masaüstü `http://127.0.0.1:3000`,
  Android emülatörü `http://10.0.2.2:3000` kullanır.
- `lib/core/api/api_client.dart`: JSON istemcisi. 401 alınca token'ı bir kez yeniler ve isteği tekrarlar.
- `lib/core/session/auth_session.dart`: giriş, kayıt ve çıkış. Refresh token cihazın güvenli deposunda
  (Keychain/Keystore) saklanır, access token yalnızca bellekte tutulur.
- `lib/app/session/`: giriş yapan kullanıcı için uzak repository'leri bir araya getirir.
- Uzak repository'ler: `features/*/data/remote_*_repository.dart`.
  Bildirimler `request_notifications_repository.dart` içinde başvurulardan türetilir.
- Bellekteki örnek veriler (`in_memory_*`) yalnızca testlerde ve `--dart-define=HOME_PREVIEW=true` önizlemesinde kullanılır.

## Klasör yapısı

```text
lib/
  main.dart
  app/
    app.dart
    theme/app_theme.dart
    routing/README.md
  core/
    widgets/README.md
    constants/README.md
    utils/README.md
  features/
    auth/README.md
    home/
      README.md
      screens/home_screen.dart
    posts/README.md
    messages/README.md
    search/README.md
    profile/README.md
test/
  widget_test.dart
```

## Sorumluluklar

- main.dart uygulamayı başlatır; app/app.dart uygulama kökünü birleştirir.
- app/theme görsel temayı, app/routing gelecekteki yönlendirme tanımlarını barındırır.
- core yalnızca gerçekten ortak widget, sabit ve yardımcı yapılar içindir.
- features işlevlere göre ayrılır; her modül kendi ekran ve davranışından sorumludur.
- test/session_flow_test.dart giriş, token yenileme ve uzak repository'leri sahte bir backend ile doğrular.

## Modül geliştirme kuralları

İhtiyaç oldukça ilgili feature içinde screens/, widgets/, models/ ve data/
klasörleri açılır. Boş katmanlar veya kullanılmayan sınıflar önceden oluşturulmaz.
Ekranlar kullanıcı etkileşimini ve görünümü, modeller veriyi,
data/ ise veri erişimi ve ileride JSON dönüşümlerini yönetir.

REST API entegrasyonu gerektiğinde ilgili feature'ın data/ klasörüne eklenir.
Ekranlar HTTP veya veritabanı ayrıntılarına bağlanmaz; gerektiğinde veri erişimi
küçük bir arayüz üzerinden constructor ile enjekte edilir.
Ortak HTTP istemcisi `core/api`, oturum yönetimi `core/session` altındadır.

Bir feature başka bir feature'ın ekranını veya data/ uygulamasını doğrudan
kullanmaz. Modüllerin birleştirilmesi app katmanında yapılır. Ortak kod core'a
ancak birden fazla modülün somut ihtiyacı olduğunda taşınır.

## Takım çalışması

İş dağılımı feature klasörlerine göre yapılabilir. Ortak app, core ve pubspec.yaml
değişiklikleri ekip içinde koordine edilmelidir. Backend sözleşmesi
kesinleştiğinde alanlar, hata yanıtları ve kimlik doğrulama akışı birlikte
kararlaştırılır; ardından gerekli model ve veri erişim kodu eklenir.

## Kontrol

```sh
flutter analyze
flutter test
```
