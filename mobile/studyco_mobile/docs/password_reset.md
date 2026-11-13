# Şifre sıfırlama ve tasarım önizlemesi

Mevcut auth ekranlarının ortak arka planı, kartı, şifre alanı ve uygulama teması kullanılır. Stitch dosyaları bu çalışma alanında bulunmadığından birebir tasarım karşılaştırması yapılmadı.

## Android Studio

Device Manager üzerinden emülatörü başlatın. Run > Edit Configurations > Flutter yapılandırmasının Additional run args alanına aşağıdaki seçeneklerden birini yazın ve Debug ile çalıştırın:

- `--dart-define=AUTH_PREVIEW=forgot`: Şifremi Unuttum
- `--dart-define=AUTH_PREVIEW=verify`: E-posta Doğrulama
- `--dart-define=AUTH_PREVIEW=reset`: Yeni Şifre Oluştur

Ekran değiştirmek için çalıştırmayı durdurup seçeneği değiştirerek yeniden başlatın; hot reload yeterli değildir. Geri oku ve Giriş Ekranına Dön bağlantısı giriş ekranını açar. Normal akışa dönmek için argümanı kaldırın.

Terminal alternatifi (cihaz kimliğini `flutter devices` ile kontrol edin):

```sh
flutter run --debug -d emulator-5554 --dart-define=AUTH_PREVIEW=forgot
flutter run --debug -d emulator-5554 --dart-define=AUTH_PREVIEW=verify
flutter run --debug -d emulator-5554 --dart-define=AUTH_PREVIEW=reset
```

Her komutu önceki çalıştırmayı durdurduktan sonra kullanın.

## Güvenlik ve backend sınırı

Önizleme seçimi `kDebugMode` ile korunur. Profile/release sürümlerinde AUTH_PREVIEW verilse bile giriş ekranı açılır. Önizlemelerde form doğrulamaları ve yerel düzenleme çalışır; servis çağrısı veya başarılı doğrulama yapılmaz. Yeni şifre önizlemesinde reset yetkisi/token üretilmez.

Normal akıştaki UnavailablePasswordResetRepository hiçbir işlem için başarı dönmez; ilk ekranda açık bir kullanılamıyor mesajı gösterilir. Altı haneli herhangi bir değer başarılı OTP kabul edilmez. `01:00` yalnızca pasif tasarım göstergesidir ve yanında aktif olmadığı belirtilir.

Teslim denetiminde yerel origin/integration/backend-flutter (786449e) kaynakları salt okunur incelendi. Gerçek backend Node.js + TypeScript + Fastify’dır; ASP.NET Core değildir. Aktif Flutter dalında PasswordResetRepository hâlâ UnavailablePasswordResetRepository ile çalışır; gerçek adaptör bağlı değildir.

Doğrulanan backend işlemleri:

1. POST /api/v1/auth/forgot-password: {email}, 202. Sunucu challenge kimliği veya reset grant token’ı döndürmez; yanıt e-posta varlığını da kanıtlamaz. Yeniden gönderim aynı endpoint’i kullanır.
2. POST /api/v1/auth/reset-password: {email, code, newPassword}, başarı 204. OTP geçerliliğini ve yeni parolayı birlikte bu işlem doğrular. Ayrı verify-reset-code veya reset-grant endpoint’i yoktur.

Flutter’ın requestCode/resendCode/verifyCode/updatePassword yöntemleri yerel UI soyutlamalarıdır, dört gerçek endpoint anlamına gelmez. Entegrasyon dalındaki RemotePasswordResetRepository, verifyCode adımında yalnız biçimi kontrol eder; bu adım sunucu tarafından doğrulanmış OTP veya sunucu grant’i gibi sunulmamalıdır. Gerçek yetki kontrolü reset-password çağrısındadır. Yerel ResetChallenge/ResetGrant modellerinin bu sözleşmeye nasıl eşleneceği entegrasyon ekibine aittir; hayalî sunucu token’ı veya endpoint eklenmez.

Backend hata kodları ve süre politikaları adaptörde ele alınmalı; geçersiz/süresi dolan kodla şifre değişmiş gibi gösterilmemelidir. Başarılı sıfırlama sonrasındaki oturum iptali ve girişe dönüş ayrıca bağlanmalıdır. Bu denetimde gerçek e-posta, OTP veya parola değiştirme işlemi yapılmadı.

Önizlemeyi kaldırmak için auth/debug/password_reset_preview.dart dosyasını silip app.dart içindeki import ve başlangıç route seçimini kaldırarak yalnızca LoginScreen home'unu bırakın.

## Kontroller

`flutter analyze` ve `flutter test` çalıştırın. Gerçek uygulama başlangıcını her önizleme için ayrıca kontrol etmek için:

```sh
flutter test test/password_reset_preview_launch_test.dart --dart-define=AUTH_PREVIEW=forgot
flutter test test/password_reset_preview_launch_test.dart --dart-define=AUTH_PREVIEW=verify
flutter test test/password_reset_preview_launch_test.dart --dart-define=AUTH_PREVIEW=reset
```
