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

Backend hazır olduğunda PasswordResetRepository için ASP.NET Core istemci implementasyonu ekleyin ve ForgotPasswordScreen'e enjekte edin. Bağlanacak işlemler:

1. requestCode: e-posta gönderimi ve sunucunun challenge kimliği.
2. resendCode: yeniden gönderim, güncel challenge ve sunucu yeniden gönderim sınırları.
3. verifyCode: OTP kontrolü ve kısa ömürlü, yalnızca şifre sıfırlamaya yetkili sunucu token'ı.
4. updatePassword: sunucunun doğruladığı reset token'ı ile yeni şifre kaydı.

Sunucu hata kodları, token süresi ve yeniden gönderim süresi API sözleşmesiyle birlikte ele alınmalıdır. Gerçek süre göstergesi sunucunun süre bilgisine bağlanmalıdır. Mevcut route akışı requestCode başarı vermeden doğrulama ekranını, verifyCode reset yetkisi vermeden yeni şifre ekranını açmaz. Güvenlik yetkisini her zaman backend doğrulamalıdır.

Önizlemeyi kaldırmak için auth/debug/password_reset_preview.dart dosyasını silip app.dart içindeki import ve başlangıç route seçimini kaldırarak yalnızca LoginScreen home'unu bırakın.

## Kontroller

`flutter analyze` ve `flutter test` çalıştırın. Gerçek uygulama başlangıcını her önizleme için ayrıca kontrol etmek için:

```sh
flutter test test/password_reset_preview_launch_test.dart --dart-define=AUTH_PREVIEW=forgot
flutter test test/password_reset_preview_launch_test.dart --dart-define=AUTH_PREVIEW=verify
flutter test test/password_reset_preview_launch_test.dart --dart-define=AUTH_PREVIEW=reset
```
