# StudyCo Mobile

Üniversite içi ders çalışma eşleştirme uygulamasının Flutter istemcisi.
Mevcut başlangıç sayaç ekranı korunmuştur. Backend ve veritabanı henüz seçilmemiştir.

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
      screens/counter_screen.dart
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
- test/widget_test.dart mevcut sayacın artış davranışını doğrular.

## Modül geliştirme kuralları

İhtiyaç oldukça ilgili feature içinde screens/, widgets/, models/ ve data/
klasörleri açılır. Boş katmanlar veya kullanılmayan sınıflar önceden oluşturulmaz.
Ekranlar kullanıcı etkileşimini ve görünümü, modeller veriyi,
data/ ise veri erişimi ve ileride JSON dönüşümlerini yönetir.

REST API entegrasyonu gerektiğinde ilgili feature'ın data/ klasörüne eklenir.
Ekranlar HTTP veya veritabanı ayrıntılarına bağlanmaz; gerektiğinde veri erişimi
küçük bir arayüz üzerinden constructor ile enjekte edilir.
Repository arayüzleri, ortak HTTP istemcisi ve durum yönetimi ancak gerçek
ihtiyaç oluşunca eklenir. Şimdilik API çağrısı, sahte veri kaynağı,
veritabanı veya ek paket yoktur. Basit sayaç durumu setState ile yönetilir.

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
