# StudyCo Asistan entegrasyonu

Bu modül hazır seçenekli ve serbest sorulu Flutter arayüzüdür. AI modeli, kalıcı sohbet geçmişi veya gerçek karar motoru içermez. Mesajlar feature'ından bağımsızdır.

## Kaynak incelemesi

Çalışma dalı `feature/flutter-ui`. Yerel Git nesnelerindeki `origin/feature/backend` ve `origin/integration/backend-flutter` okundu; asistan endpoint'i veya soru-cevap sözleşmesi bulunmadı. Entegrasyon dalında da ana sayfa butonu henüz kullanılamıyor uyarısına bağlıydı. Uzak sunucu güncelliği sorgulanmadı; branch değiştirme/fetch/pull/merge yapılmadı. Backend ve PostgreSQL değişmedi.

## İçerik bağlantısı

`AssistantRepository.load()` bir `Future<AssistantContent>` döndürür. `AssistantContent` greeting, options ve isDemo alanlarını; `AssistantOption` id, title, answer ve isteğe bağlı destination alanlarını taşır. Bunlar yerel Flutter modelidir; backend JSON sözleşmesi değildir. Kimlikleri benzersiz ve başlık/yanıtları dolu verin. Metinler düz metin gösterilir; HTML/Markdown çalıştırılmaz. Alt seçenek ağacı bu görevde eklenmedi.

Gerçek içerik sağlayıcınızı şu noktadan enjekte edin:

```dart
class TeamAssistantRepository extends AssistantRepository {
  @override
  Future<AssistantContent> load() async => AssistantContent(
    greeting: yourGreeting,
    options: yourOptions, // List<AssistantOption>
  );

  @override
  bool get supportsQuestions => true;

  @override
  Future<AssistantReply> ask(String question) async {
    // Gerçek yorumlama/servis bağlantısı ekibin sorumluluğunda.
    return yourAssistantSystem.ask(question);
  }
}

MyApp(assistantRepository: TeamAssistantRepository());
```

Alternatif olarak Navigator üzerinde `AssistantRepositoryScope(repository: ..., child: ...)` kullanın. İzole HomeScreen için scope yoksa açıkça demo işaretli bellek verisi kullanılır. MyApp varsayılanı da aynı örnek kaynaktır. Dört örnek gerçek asistan içeriği değildir; panelde “Örnek içerik • Tasarım önizlemesi” etiketi görünür. Gerçek veride isDemo varsayılan false'dur. Soru-cevaplar widget'lara sabitlenmedi.

Her panel açılışında load çağrılır. Yükleme, hata/tekrar ve boş seçenek durumları desteklenir; kapatılan panelin geç gelen sonucu kullanılmaz. Seçim yalnız panel ömrü boyunca tutulur. Hazır içerik ve soru gönderimi aynı repository üzerinden sunulur. UI token yönetmez veya kullanıcı sohbet geçmişi tutmaz. Kaynağın kendi kaynak temizliği varsa yaşam döngüsünü sahibi yönetir. Bu modül AuthSession/ApiClient oluşturmaz veya değiştirmez; gelecekteki veri adaptörü ekip tarafından gerçek sözleşme belirlendikten sonra hazırlanabilir. Endpoint uydurmayın.

## Yönlendirme anahtarları

`destination`, aşağıdaki enum adlarından biridir; bir URL veya serbest rota adı değildir. Bilinmeyen anahtarlar çalıştırılmaz. `null` yalnız yanıt gösterir.

| Anahtar | Hedef | Kullanılabilirlik |
|---|---|---|
| home | Ana Sayfa | Panel kapanır, mevcut ana sayfa korunur |
| search | Ara | Mevcut ana sayfa navigasyonu |
| createPost | İlan Oluştur | Host onCreatePost sağlıyorsa mevcut callback |
| profile | Profilim | Mevcut ProfileNavigation / host callback |
| myPosts | İlanlarım | Mevcut MyPostsScreen, aynı PostsRepository |
| applications | Başvurularım | applicationsRepository varsa |
| incomingApplications | Gelen Başvurular | applicationsRepository varsa, incoming: true |
| messages | Mesajlar | Kullanıcıyla eşleşen aktif MessagesRepositoryScope varsa |
| notifications | Bildirimler | Kullanıcıyla eşleşen NotificationsRepositoryScope varsa |
| settings | Ayarlar | Mevcut SettingsScreen |

Rota birleştirme `app/routing/assistant_navigation.dart` içindedir. Mevcut ekran sınıfları ve aynı veri kaynakları kullanılır; yeni ekran kopyası veya ayrı veri kaynağı oluşturulmaz. Panel yalnız geçerli ve mevcut hedef için “İlgili Sayfaya Git” gösterir; diğer hedeflerde Türkçe açıklama gösterir. Seçimden sonra ModalBottomSheetRoute.completed beklenir; panel overlay'i kaldırıldıktan sonra hedef tekrar doğrulanır ve açılır. Bu sırada Home kaldırılmışsa yönlendirme yapılmaz; hesap kimliği değişmişse yeniden açma açıklaması gösterilir.

## Arayüz ve kapsam

Klavye kapalıyken yaklaşık %80 yükseklikte modal; kapat düğmesi, sistem geri, dışarı dokunma ve sürükleme ile kapanır. Başlık sabit, içerik kaydırılabilir. Soru kartları uzun başlığı üç satırda kısaltır; seçilen sorunun tam başlığı ve yanıtı ayrıntıda gösterilir. Önceki seçeneklere dönüş yeni rota oluşturmaz. Mint yüzey, beyaz kartlar ve tema renkleri kullanılır. Yeni paket eklenmedi.

Kalan ekip işleri: gerçek soru-cevap/karar mantığını tamamlamak; sağlayıcıyı bağlamak; iş amaçlı metinleri ve hedef anahtarlarını onaylamak. Backend bağlantısı gerekiyorsa önce gerçek sözleşmesini belirlemek. Bu modül cevap üretimi, alt karar ağacı veya oturum servisi yerine geçmez.


## Dosyalar ve doğrulama

Eklenenler: `models/assistant_content.dart`, `domain/assistant_repository.dart`, `data/in_memory_assistant_repository.dart`, `widgets/assistant_repository_scope.dart`, `widgets/assistant_sheet.dart` ve bu belge; ayrıca `lib/app/routing/assistant_navigation.dart`, `test/assistant_test.dart`.

Bu görevde güncellenenler: `lib/app/app.dart` (sağlayıcı enjeksiyonu), `lib/features/home/screens/home_screen.dart` (modal açma/yönlendirme), `test/home_test.dart` (yeni panel beklentisi). Önceki Mesajlar çalışmasının mevcut değişiklikleri korundu.

Önceki hazır seçenek tesliminin sonuçları: değişen Dart dosyaları formatlandı; flutter analyze temiz; tüm testler normal modda 352/352 ve HOME_PREVIEW=true ile 352/352 geçti. 20 yeni asistan testi; seçenek/yanıt/geri, kapanma, çift tıklama, on hedef, geçersiz veya eksik hedef, içerik yükleme hatası/tekrar, geç sonuç ve 320px / 1x–2x metin ölçeği senaryolarını kapsar. git diff --check temiz. Dal feature/flutter-ui olarak kaldı; commit/push/pull/merge/checkout yapılmadı.


## Serbest soru akışı

`supportsQuestions` varsayılan false'dur. Yalnız `load()` sağlayan eski sınıflar `extends AssistantRepository` ile hazır seçenekleri kullanmaya devam eder; alan görünür fakat devre dışıdır ve hizmetin bağlı olmadığı açıklanır. `implements AssistantRepository` kullanan sağlayıcılar yeni üyeleri de açıkça uygulamalıdır. Gerçek servis bağlanınca supportsQuestions=true ve ask(question) uygulayın; aynı MyApp/Scope enjeksiyon noktası korunur.

`ask(String question)` bir `Future<AssistantReply>` döndürür. Yanıt modeli answer, isteğe bağlı destination ve isDemo içerir; hazır sorudaki destination ile aynı izinli anahtarlar kullanılır. Bunlar yerel Flutter arayüzleridir; gerçek backend veya AI yanıt sözleşmesi değildir. Ekibiniz gerçek yanıt türlerini, alanlarını veya renderer'ı gerektiği gibi genişletebilir. Model/HTTP/metin eşleştirme kodu widget'larda bulunmaz.

Gönderim trim sonrasında boş olamaz. Sunucu sözleşmesinde doğrulanmış bir üst sınır bulunmadığı için yapay bir karakter limiti eklenmedi. Buton ve IME gönderimi aynı kilidi kullanır. İşlem sürerken yeni gönderim ve hazır seçenek değiştirme kapalıdır; kapanmaya izin verilir. Yazılan soru ve bekleme durumu aynı panelde gösterilir. Başarı taslağı temizler; hata tam taslağı korur ve Türkçe açıklama gösterir. Otomatik yeniden gönderim yoktur. Geç sonuçlar panel kapandıktan veya repository değiştikten sonra kullanılmaz. Yalnız son soru/yanıt panel ömrü boyunca tutulur; yeni panel temiz açılır. Kalıcı kayıt, sohbet geçmişi, dosya/medya veya yeni sayfa yoktur.

Alt alan klavyenin üzerinde kalır: viewInsets panelin dış boşluğuna uygulanır, klavye açıkken kalan kullanılabilir yükseklik kullanılır. İçerik ayrı kayar, metin alanı iki satırla sınırlı görünür ve kendi içinde kaydırılır. Başlık dar klavye görünümünde kısaltılabilir. Küçük ekranda alt alan da yüksekliğe göre sınırlanır.

### Yalnız geliştirme amaçlı mock

Varsayılan InMemoryAssistantRepository.preview, serbest soruyu yalnız `kDebugMode && HOME_PREVIEW=true` iken kabul eder. Normal/release modunda gerçek soru servisi varmış gibi davranmaz. Test fixture'ları ayrıca enableQuestions ile açıkça etkinleştirebilir. 350ms gecikme yalnız mock yüklenme görünümünü denemek içindir; responseDelay testlerde sıfırlanabilir.

Eşleştirme yalnız mock veri katmanında `trim().toLowerCase()` sonrası soru başlığına eşitliktir. Anahtar kelime çıkarımı, fuzzy arama veya dil modeli yoktur. Eşleşen soru ilgili örnek yanıtı ve hedefi döndürür. Eşleşmeyen soru hata fırlatmaz; hedefi olmayan şu mock yanıtını döndürür:

> Şu anda bu soruya yanıt veremiyorum. Hazır sorulardan birini seçerek devam edebilirsin.

Mock yanıtta isDemo=true'dur ve panelde örnek içerik etiketi gösterilir. Bu davranış gerçek servis sözleşmesi veya üretim soru-cevap mantığı değildir. Gerçek sağlayıcıda yalnız gerçekten demo olan yanıtlara isDemo=true verin. Desteksiz destination mevcut güvenli açıklamayı gösterir; null hedefte yönlendirme butonu görünmez.

Bu genişletmede değişenler: assistant_content.dart, assistant_repository.dart, in_memory_assistant_repository.dart, assistant_sheet.dart, assistant_test.dart ve bu belge. Eklenen: widgets/assistant_question_composer.dart. Mesajlar, backend, PostgreSQL, app oturum ve yönlendirme kodu değiştirilmedi.

Kalan ekip işleri: gerçek soru yorumlama/yanıt sistemini uygulamak, servis yeteneklerini ve hata/yanıt türlerini doğrulamak, ask metodunu bağlamak ve gerekiyorsa sözleşmeye göre metin sınırları eklemek. Frontend'deki mock eşitlik davranışını gerçek asistan sistemi olarak kullanmayın.


### Serbest soru tesliminin doğrulaması

Değişen Dart dosyalarında dart format tamamlandı; flutter analyze temiz. Asistan testleri 31/31 (11 yeni serbest soru testi dahil); tüm Flutter testleri normal modda 363/363 ve HOME_PREVIEW=true ile 363/363 geçti. Testler hazır seçenekleri, bilinen/bilinmeyen mock soruyu, hedefli/hedefsiz yanıtı, boş girdi ve IME/çift tıklama korumasını, bekleme/hata/taslak korumayı, geç yanıtın yok sayılmasını ve 320px klavye açık 1x–2x metin ölçeğini kapsar. git diff --check temiz; dal feature/flutter-ui olarak kaldı. Git commit/push/pull/merge/checkout yapılmadı.
