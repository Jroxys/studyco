# Mesajlar entegrasyonu

Bu feature yalnız Flutter frontend içerir. Gerçek HTTP, token, PostgreSQL, WebSocket veya ücret işlemi yapmaz. `HOME_PREVIEW=true` geliştirme modunda ayrı, oturuma ait bellek kaynağı kullanır. Normal giriş davranışı değiştirilmedi.

## Kaynaklar ve dallar

İnceleme: `feature/flutter-ui` çalışma ağacı; Git nesnelerindeki `origin/feature/backend` (`84059af`) ve `origin/integration/backend-flutter` (`786449e`). Dallara geçilmedi ve Git ağ/senkronizasyon işlemi yapılmadı. Mesaj route/schema/service/repo dosyaları ve database migration'ları iki kaynak dalda aynı. Bu görev canlı sunucuyu doğrulamaz; referanslar yerel Git kopyalarıdır.

Kaynaklar: `backend/src/modules/messages/messages.{routes,schemas,service,repo}.ts`, `backend/src/app.ts`, `backend/openapi.json`, `database/migrations/up/004_messaging_reviews.sql`, `005_functions_views.sql`. Backend testleri `backend/tests/messages-reviews.test.ts` içinde.

## REST sözleşmesi

Prefix `/api/v1`, tüm çağrılarda `Authorization: Bearer <accessToken>`.

| Repository işlemi | Endpoint | Başarı |
|---|---|---|
| fetchConversations | GET /conversations?limit=20&cursor=... | 200 {items,nextCursor} |
| fetchMessages | GET /conversations/{id}/messages?limit=20&cursor=... | 200 {items,nextCursor} |
| sendMessage | POST /conversations/{id}/messages, {body} | 201 Message |
| markRead | POST /conversations/{id}/read, gövdesiz veya {} | 204, JSON ayrıştırılmaz |

`findConversation` bir endpoint değildir. Temel uygulama yetkili konuşma sayfalarını sonuna kadar tarar; tekrar eden cursor'ı reddeder. Adaptör doğrulanmış kendi önbelleğini kullanabilir; bulunamayan ID için yeni endpoint uydurmamalıdır. Bildirimden gelen ID ilk sayfada olmak zorunda değildir. Cache bulunması sunucunun katılımcı kontrolünün yerine geçmez.

`Conversation`: id, requestId, listing:{id,topic}, counterpart:{id,firstName,lastNameInitial,departmentId}, lastMessage:Message?, unreadCount. Flutter'da listingId/topic düz alanlara eşlenir; counterpart mevcut ApplicationPerson projeksiyonunu kullanır. `Message`: id, senderId, body, sentAt, readAt?. fromJson fabrikaları tarihleri UTC'ye çevirir ve kimlik metinlerini değiştirmez. API kimlikleri UUID'dir; adaptör gerçek kimlikleri doğrulamalıdır. Mock kimlikleri yalnız bellekte kullanılan mock-* değerleridir; JWT veya sunucu kimliği değildir.

Avatar baş harflerden çizilir; avatar URL'si, bölüm adı, yazıyor, çevrimiçi, son görülme ve teslim bilgisi üretilmez. Zamanlar ekranda yerel saatle gösterilir.

## Kimlik ve yaşam döngüsü

Repository tek oturuma aittir ve değişmez userId taşır. Scope yalnız eşleşen, aktif kullanıcıya kaynak verir. Kendi mesajı `senderId == userId` karşılaştırmasıyla belirlenir. Gönderim gövdesine senderId eklenmez. Gerçek kullanıcı yalnız JWT sub / AuthSession.user.id üzerinden belirlenmelidir; postsOwnerId yerel fallback'i sunucu için kullanılmaz.

Konuşma kabul SQL işlemi sırasında oluşur, talep başına en fazla birdir. Yeni konuşma oluşturma arayüzü yoktur. Hem öğrenci hem öğretmen erişebilir; kabul etiketi tek başına yetki değildir. Ders bittikten sonra konuşma kapanmaz. Sohbete Git düğmesi yalnız kabul edilmiş, yerel iptali olmayan, kimliği bulunan ve kullanıcı katılımcılığı bilinen başvuruda görünür.

Entegrasyon dalındaki `lib/core/api/api_client.dart`, `core/session/auth_session.dart` ve `app/session/signed_in_services.dart` yeniden yazılmadı veya taşınmadı. Gelecek RemoteMessagesRepository aynı session.api ile kurulmalı; SignedInServices içinde oturum başına yaratılmalı, Navigator üstündeki MessagesRepositoryScope'a enjekte edilmeli ve logout sırasında erişimi iptal edilip kaynak temizlenmelidir. Dışarıdan MyApp(messagesRepository: ...) ile verilen kaynağın dispose/temizleme sorumluluğu onu oluşturan katmana aittir. App yalnız kendi oluşturduğu önizleme kaynağını temizler; logout önce kaynağı pasifleştirir, eski rotalar kaldırıldıktan sonra dispose eder. Hesap değişimindeki eski async ekran sonuçları generation kontrolüyle atılır.

## Sayfalama, sıralama ve yenileme

Varsayılan limit 20, aralık 1–50. nextCursor null son sayfadır. Cursor opaktır, istemci çözmez veya değiştirmez. Konuşmaların backend sırası `created_at DESC, conversation_id DESC`; son mesaj zamanına göre yeniden sıralama yapılmaz. API createdAt döndürmez. Ekran sunucu sırasını korur ve sonraki sayfayı sonuna ekler; ID tekrarları çoğaltılmaz.

Mesajlar `sentAt DESC, id DESC` gelir. UI ters ListView kullanır: yeni mesaj altta, eski sayfalar üstte. mergeMessages kimlik bazında tekrarları giderir ve bu sırayı korur. Yenileme ilk sayfaya döner, eski cursor zinciri yeniden başlar. Eski sayfalar yüklenirken paralel istek engellenir. Gönderim sırasında yükleme/yenileme kapalıdır. Kaynağın yenileme hatası son sağlam listeyi silmez.

Mock cursor'lar repository örneğine ve konuşma/kaynak türüne bağlı yerel biletlerdir. ID anchor kullanır, yeni mesaj eklenmesi eski sayfaları kaydırmaz. Bunlar backend base64url cursor'ları değildir, gerçek adaptöre taşınmaz.

## Gönderim ve belirsiz sonuç

Metin trim sonrasında 1–2000 UTF-16 kod birimi olmalıdır; Dart String.length, backend JavaScript/Zod length davranışıyla eşleşir. Klavye Enter satır ekler, gönderme ayrı düğmeyledir. İşlem sürerken düğme ve metin alanı kilitlidir. Başarı sunucu Message yanıtıyla listeye işlenir, taslak temizlenir. Hata taslağı korur.

Backend idempotency desteklemiyor. Ağ hatası veya timeout sonrasında otomatik POST tekrarı yapılmaz. Kullanıcı sohbeti yenileyerek sonucu kontrol etmeye yönlendirilir; yeniden gönderme bilinçli kullanıcı işlemidir. MessagesFailure.deliveryUncertain adaptörün belirsiz sonucu belirtmesi içindir; UI bilinmeyen gönderim hatalarında da temkinli uyarı gösterir. Mevcut ApiClient 401 sonrası token yenileyip isteği bir kez tekrarlar; adaptör ek ağ/timeout retry mekanizması kurmamalı, ekip 401 yenileme davranışını bu yetkilendirme semantiğiyle doğrulamalıdır.

## Okundu ve rozet

Listeleme otomatik okundu sayılmaz. Sohbet yüklendikten sonra markRead ayrı çağrılır; tüm karşı taraf okunmamış mesajlarını kapsar, yalnız sayfayı değil. Kendi mesajlarını değiştirmez. Başarısız işlemde unreadCount sıfırlanmaz. UI ayrı okuma hatası ve tekrar düğmesi sunar. readAt korunur, sunucu timestamp'i tahmin edilmez. Okuma sonrası ilk mesaj sayfası tekrar okunur; eski sayfalardaki readAt değerleri sonraki sunucu okumalarında doğrulanır, UI bunlarla teslim/çift tik göstermez.

Adaptör başarılı markRead/send sonrası cachedConversation projeksiyonunu ve doğrulanabilen sayacı güncelleyip notifyListeners çağırmalıdır. Liste dönüşte ayrıca yenilenir. Bildirim okundu durumu ayrı repository'dedir; sohbetin okundu çağrısı bildirim okundu yerine geçmez.

confirmedUnreadTotal yalnız eksiksiz, güncel toplam biliniyorsa int döndürür. Varsayılan null: ana sayfa rozeti gizlenir. Yüklenen tek/eksik sayfa toplamı kesin toplam olarak gösterilmez. Mock tüm odalara sahip olduğu için doğru toplam verebilir. Backend'de unread-total endpoint'i yoktur; böyle bir endpoint çağrılmaz.

## Mock sınırları

Önizleme var olan kabul edilmiş başvuru fixture'larını kullanır; üçüne açık mock conversationId eklenmiştir. Kabul düğmesi yeni sahte oda üretmez. Birden fazla sohbet, boş sohbet, uzun mesaj, iki taraflı ve okunmuş/okunmamış mesajlar vardır. Kaynak yalnız verilen kullanıcının iki katılımcılı odalarını alır. Yetkisiz konuşma okuma/gönderme/okundu işlemi reddedilir. Logout belleği ve cursor'ları temizler; yeni önizleme temiz veriyle başlar. Kalıcılık, gerçek hesap oturumu, sunucu başarısı veya başka mock cihazla senkronizasyon iddiası yoktur.

## Hatalar ve kalan entegrasyon

Hata zarfı `{error:{code,message,details?}}`. 400 VALIDATION_ERROR/BAD_CURSOR/BAD_REQUEST, 401 UNAUTHORIZED, 403 NOT_A_PARTICIPANT, 429 RATE_LIMITED, 500 INTERNAL kodları adaptörde anlaşılır Türkçe MessagesFailure'a eşlenmeli. Geçerli UUID biçimindeki bilinmeyen konuşma da katılımcılık kontrolünden 403 alır. Konuşma listesi response şemasında 400 eksik belgelenmiş olsa da service geçersiz cursor için 400 üretebilir. Geçersiz cursor yenilemeyle sıfırlanabilir. Endpoint'e özel hata tablosu global rate-limit/DB hatalarını tam olarak listelemiyor; adaptör bilinmeyen kodlarda güvenli fallback kullanmalıdır.

Entegrasyon arkadaşımızın işleri:

- Mevcut ApiClient/AuthSession üzerinde RemoteMessagesRepository uygulamak; URI, DTO zarfı, JWT kullanıcı kimliği ve gerçek UUID'leri doğrulamak.
- Kullanıcıya ait repository cache, isActive ve logout/dispose yaşam döngüsünü SignedInServices'e bağlamak.
- Başarı sonrası ortak projeksiyonları güncellemek, kısmi toplamda rozeti gizlemek.
- Gerçek iki katılımcılı kabul senaryosuyla sayfalama, send/read, yetkisiz erişim, ağ sonucu belirsizliği ve hata kodlarını doğrulamak.
- Gerektiğinde ekran/uygulama aktifliğine bağlı REST polling eklemek. Bu görevde sürekli timer, push veya gerçek zamanlı bağlantı yok; girişte ve manuel yenilemede veri alınır.

Yeni endpoint, backend/SQL değişikliği, ücret/token veya bildirim sunucu altyapısı bu feature kapsamında eklenmedi.

## Teslim ve doğrulama raporu

Eklenen dosyalar (Flutter proje köküne göre):

- lib/features/messages/models/conversation.dart
- lib/features/messages/domain/messages_repository.dart
- lib/features/messages/data/in_memory_messages_repository.dart
- lib/features/messages/screens/conversations_screen.dart
- lib/features/messages/screens/chat_screen.dart
- lib/features/messages/widgets/messages_repository_scope.dart
- lib/features/messages/widgets/conversation_navigation.dart
- lib/features/messages/widgets/message_widgets.dart
- lib/features/messages/MESSAGES_INTEGRATION.md
- lib/app/debug/messages_preview_data.dart
- test/messages_repository_test.dart
- test/messages_test.dart
- test/support/messages_fixtures.dart
- test/support/login_app.dart

Güncellenen dosyalar:

- lib/app/app.dart — repository enjeksiyonu, preview kaynağı ve logout temizliği.
- lib/app/debug/home_preview_data.dart — mevcut kabul edilmiş örneklere açık mock conversationId.
- lib/app/debug/notifications_preview_data.dart — mesaj bildiriminin konuşma hedefi.
- lib/features/home/screens/home_screen.dart — Mesajlar rotası ve doğrulanmış rozet.
- lib/features/home/widgets/home_header.dart — nullable repository sayacı; sabit profil sayısını kullanmaz.
- lib/features/notifications/screens/notifications_screen.dart — konuşma ID'siyle yönlendirme.
- lib/features/applications/screens/applications_screen.dart — kabul edilmiş katılımcı başvuruda Sohbete Git.
- lib/features/messages/README.md — modül ve entegrasyon belgesi bağlantısı.
- test/home_test.dart ve test/notifications_test.dart — eski kullanılamıyor beklentileri yeni rotaya güncellendi.
- test/widget_test.dart, test/registration_test.dart, test/password_reset_test.dart — gerçek uygulamadaki giriş rotasını açan ortak test hazırlığı. HOME_PREVIEW açıkken login etkileşimlerinin demo ana sayfasında çalıştırılması önlendi; ürün giriş/oturum kodu değiştirilmedi.
- test/password_reset_preview_launch_test.dart — başlangıç ekranı beklentisi HOME_PREVIEW ve AUTH_PREVIEW önceliğini dikkate alır.

13 Kasım 2026 son kontrol sonuçları:

- Değişen Dart dosyalarında dart format tamamlandı.
- flutter analyze: No issues found.
- flutter test --reporter expanded: 332 test geçti, çıkış kodu 0.
- flutter test --dart-define=HOME_PREVIEW=true --reporter expanded: 332 test geçti, çıkış kodu 0.
- Mesajlaşma için 22 yeni repository/widget testi eklendi. Yetkilendirme, kimlik ayrımı, sıralama, cursor kapsamı ve ekleme sonrası kararlılık, tekrarsız birleştirme, boş durum, gönderim doğrulama/çift tıklama/taslak koruma, read başarısızlığı/tekrarı, bildirim ve iki başvuru yönü, rozet, logout ve 320px/klavye/uzun metin senaryoları kapsandı.
- İlgili HOME_PREVIEW regresyon kümesi ayrıca 84/84 geçti.
- git diff --check temiz. Dal feature/flutter-ui olarak kaldı. Backend, PostgreSQL, pubspec ve mevcut ürün oturum kodu değiştirilmedi; branch değiştirme/fetch/pull/merge/commit/push yapılmadı.

Gerçek sunucuya bağlantı veya canlı backend testi yapılmadı. Yukarıdaki REST adaptörü ve ekip entegrasyonu işleri kalmıştır. Bilinen sözleşme farkları: konuşma listesi için 400 hata yanıtının eksik belgelenmesi; toplam unread endpoint'inin ve idempotency desteğinin bulunmaması. Bunlar UI'da yeni endpoint veya kesin olmayan toplam üretilerek aşılmadı.
