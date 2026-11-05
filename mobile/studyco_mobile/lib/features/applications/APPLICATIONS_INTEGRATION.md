# Başvurular ve Gelen Başvurular entegrasyonu

## Kaynak ve kapsam

Yerel çalışma alanında backend kodu, SQL fonksiyonları ve OpenAPI belgesi bulunamadı. Aşağıdaki Node.js + TypeScript + Fastify sözleşmesi görevde verilen backend bilgileridir; bu checkout içinde canlı sunucuya bağlanılmadı. UI HTTP/SQL içermez. Mesajlar, Değerlendirmeler ve ders onaylama akışı bu görevin dışındadır.

Tek ApplicationsRepository hem gönderilen hem gelen başvuruları yönetir. PostsRepository.applicationsRepository bütün rotalara aynı kaynağı verir. InMemoryPostsRepository bu kaynağı ve yaşam döngüsünü yönetir; gerçek adaptörler varsayılan null kaynağa sessizce mock eklememelidir. ApplicationsScreen(incoming: true) farklı rolün listesini açar; filtre, kart, boş durum, detay paneli ve karar düğmeleri ortak bileşenlerdir.

## Endpoint eşlemesi

| İşlem | Backend | Flutter sınırı |
| --- | --- | --- |
| Başvurularım | GET /api/v1/me/requests?role=student | refresh(applicantId), forApplicant |
| Gelen Başvurular | GET /api/v1/me/requests?role=teacher | refreshIncoming(ownerId), forOwner |
| Kabul | POST /api/v1/requests/{id}/accept; accept_lesson_request | accept(id, ownerId) |
| Ret | POST /api/v1/requests/{id}/reject; reject_lesson_request | reject(id, ownerId) |
| Tamamlanma onayı | POST /api/v1/requests/{id}/confirm | Henüz uygulanmadı |

student ve teacher bu işlemdeki rollerdir; kalıcı hesap tipi değildir. Başvuru oluşturma, kullanıcı iptali, tek request detayı ve tam ilan verisini getiren endpoint sözleşmeleri hâlâ doğrulanmalıdır. getForUser mevcut snapshot'tan iki rol için yetkili detayı döndürür; hayalî GET endpoint'i eklenmedi. Sayfalama zarfı, cursor, hata kodları ve mutasyon cevap şemaları doğrulanmadan REST adaptörü tamamlanmamalıdır.

## DTO ve kimlik eşlemesi

RequestDto tek response satırını domain'e dönüştürür, HTTP çağırmaz ve sayfalama zarfı varsaymaz. Alanlar: id, status, completionStatus, agreedTokenAmount, createdAt, respondedAt, listing(id, topic, startAt, endAt, tokenPrice), counterpart(id, firstName, lastNameInitial, departmentId), conversationId. Varsa studentCompletedAt, teacherCompletedAt, confirmationDeadlineAt, settledAt de korunur. Kimlik metinleri/UUID'ler değiştirilmez; isimlerden kimlik türetilmez. Eksik zorunlu kimlik veya geçersiz tarih/miktar FormatException üretir; sessizce sahte veri oluşturulmaz.

Teacher rolünde counterpart öğrenciye eşlenir; teacherId doğrulanmış auth kullanıcısıdır. Student rolünde counterpart ilan sahibidir; applicantId doğrulanmış auth kullanıcısıdır. Bu currentUserId parametresi gerçek entegrasyonda token/session'dan gelmelidir; kullanıcı girdisi yetki kaynağı değildir. UserProfile.postsOwnerId, gerçek id yoksa yalnız aynı kullanıcı nesnesine bağlı oturum anahtarı sağlar; sunucuya gerçek UUID gibi gönderilmez.

ApplicationPerson yalnız gönderilen ad, soyadı baş harfi ve departmentId'yi taşır. Tam soyad/bölüm adı türetilmez. ApplicationListing kısmi ilan verisidir; Post'un zorunlu title/location/tarih alanlarını doldurmak için sahte Post oluşturulmaz. UI ortak PostsRepository'den tam ilanı bulabiliyorsa kullanır; aksi hâlde gelen topic, startAt/endAt, tokenPrice ile gösterir. Bilinmeyen tam ders adı, konum veya açıklama uygun boş metinle belirtilir. Tam ilan ve bölüm adı gerekiyorsa backend response genişletmesi veya doğrulanmış katalog/ilan servisi gereklidir. agreedTokenAmount tercih edilir; yoksa listing.tokenPrice veya mevcut Post.offerLabel gösterilir.

## Durumlar ve filtreler

PENDING → pending/Beklemede; ACCEPTED → accepted/Kabul Edildi; REJECTED → rejected/Reddedildi; AUTO_CANCELLED → autoCancelled/Otomatik İptal Edildi. Bilinmeyen değer rawServerStatus içinde aynen korunur, unknown olarak sunulur; reddedilmiş sayılmaz. Tümü bütün kayıtları; diğer filtreler yalnız kendi domain durumunu gösterir. Otomatik iptal, bilinmeyen durum ve yerel iptal yalnız Tümü'ndedir.

Kullanıcı iptali endpoint'i/durum kodu hâlâ bilinmiyor. Mock iptal locallyCancelledAt ile ayrı tutulur; UI İptal Edildi gösterir. Bu bilgi CANCELLED gibi doğrulanmamış bir API durumuna çevrilmez. Mock'ta yalnız kullanıcıya ait, süresi dolmamış ve iptal edilmemiş pending kayıtlar iptal edilebilir. Kabul edilmiş ders için iptal hakkı varsayılmaz.

PostStatus PUBLISHED/published ve BOOKED/booked durumlarını taşır. Gerçek ilanın diğer durumları doğrulanana kadar unknown olarak kapalı kabul edilmelidir. İlan düzenleme kendi başına status değiştiremez; kabul sonrası booked kaydı düzenleme/silme ile tekrar published yapılamaz. Rezerve edilen ilan İlanlarım'da korunur ve Rezerve Edildi gösterir; tarih geçince Tamamlandı varsayılmaz.

## Kabul ve ret: mock ile sunucunun farkları

Mock accept işlem anında şu koşulları yeniden denetler: kaydın varlığı, başvuran/ilan sahibi kimlikleri, ilgili ilan sahipliği, yerel iptal edilmemiş pending başvuru, published ilan, gelecekteki ders başlangıcı ve geçerli saat aralığı. Bilinen accepted derslerde öğrencinin veya ilan sahibinin iki rolden herhangi birinde saat çakışması engellenir. Uç uca bitiş/başlangıç çakışma değildir. İlgili kabul edilmiş kaydın saatleri eksikse doğrulama yapılamadığı için kabul reddedilir. İstemcinin bildiği program tüm sunucu programı olmayabilir.

Başarıda seçilen request accepted, aynı ilan için diğer gerçekten pending kayıtlar autoCancelled olur; yerel iptal edilmiş pending kayıtlar yeniden değiştirilmez. Diğer ilanların, daha önce reddedilmiş veya kabul edilmiş kayıtların durumu korunur. respondedAt güncellenir. İlan booked olur. Mock iki snapshot'ı aynı senkron commit içinde değiştirir ve gözlemcilere ardından haber verir. Bu yalnız tek Dart isolate'ı içinde tutarlı bellek davranışıdır; gerçek transaction/lock değildir. posts ve applications dinleyicileri birbirine aykırı ara durum görmez.

Ret yalnız güncel ilan sahibi ve pending kayıt için uygulanır. SQL sözleşmesinde ret için dersin başlamamış olması şartı verilmediğinden geçmiş pending kaydı reddetmek mümkündür; kabul ise kapalıdır. Ret başka request'i veya ilan durumunu değiştirmez. Hata durumunda snapshot değişmez, kullanıcı Türkçe mesaj görür. Çift dokunma ve açık onay sırasında başka işlemin durumu değiştirmesi UI kilidi ve repository'nin son doğrulamasıyla ele alınır.

Gerçek backend accept_lesson_request içinde PUBLISHED/PENDING, sahiplik, başlamamış ders, iki tarafın programı, yeterli token bakiyesi, token blokajı ve eşzamanlılık kurallarını atomik olarak uygulamalıdır. Flutter mock'unda gerçek cüzdan/bakiye sorgusu, token rezervasyonu/aktarımı/iadesi veya veritabanı kilidi yoktur. Ücretli mock kaydı kabul edilebilmesi gerçek bakiye yeterliliği anlamına gelmez. Gerçek accept/reject adaptörü sunucu başarısından sonra hem request hem ilan snapshot'larını yenilemeli; hata/çatışma cevabında başarı göstermemelidir. İlgili öğrenci/öğretmen ekranları, başvuru sayıları ve bildirimler sunucu cevabı veya olaylarıyla yenilenmelidir; Post.applicationCount yapay artırılmaz.

## Konuşma ve tamamlanma

Verilen backend kuralına göre gerçek kabul sırasında konuşma kaydı oluşur. Sunucunun conversationId değeri DTO ve bütün kopyalama/iptal/kabul işlemlerinde korunur. Mock konuşma kaydı veya sahte conversationId üretmez; Mesajlar rotası açılmaz. Gerçek konuşma erişimi yine backend yetkisine bağlıdır; accepted etiketi tek başına yazma yetkisi sağlamaz.

completionStatus ham değer olarak korunur; enum değerleri verilmediği için Türkçe tamamlanma durumu uydurulmaz. studentCompletedAt/teacherCompletedAt mevcutsa ayrı taraf onayları gösterilir; confirmationDeadlineAt ve settledAt varsa tarihleri gösterilir. Tarihin geçmesi veya tek tarafın onayı dersin tamamlandığını ispatlamaz. confirm endpoint'inin izinleri, completionStatus değerleri, iki taraflı onay/son tarih/otomatik sonuçlandırma ve token settlement kuralları doğrulanınca onay işlemi eklenebilir. Bu görevde confirm çağrısı ve Tamamlandı işareti üretilmez.

## Keşif, oluşturma ve debug

PostsRepository.discoverablePosts yalnız isPostOpenForApplications tarafından uygun bulunan kayıtları gösterir. Ana Sayfa/Arama booked, başlamış/geçmiş veya kapalı kayıtları keşiften çıkarır; kişisel geçmiş raw posts snapshot'ında kalır. Gerçek backend geldiğinde açık/kapalı/zaman ve yetki filtreleri sunucuda da zorunludur; Flutter savunma amaçlı ek denetimdir, asıl yetki kontrolü değildir. Cursor sayfalamasında sadece yüklenen sayfayı istemcide filtrelemek yeterli değildir.

Mock oluşturma bilinen yazar kimliği, farklı başvuran ve açık ilan ister; aynı (applicantId, postId) için yeniden başvuru oturum boyunca engellenir. İptalden sonra yeniden başvuru kuralı sunucuda doğrulanmalıdır. PostDetailsScreen mevcut UserProfile kimliği/adını ApplicationPerson'a geçirir; ad eşlemesi yapılmaz.

HOME_PREVIEW yalnız kDebugMode ile açıkken farklı sahibin gelecekteki başvuru örneğine ek olarak mevcut mock kullanıcıya ait ücretsiz bir ilan ve üç mock öğrenciden pending başvuru ekler. Kayıtlar açıkça örnek ad ve mock kimlikleri kullanır; normal login/API verisine karışmaz. Aynı ApplicationsRepository üzerinde ret, kabul ve kalan pending kayıtların otomatik iptali denenebilir. Veriler oturumluk bellektedir; arayüzde teknik uyarı eklenmez. Filtreler dört/iki/tek sütuna uyarlanır; otomatik iptal yanlışlıkla ret filtresine girmez.


## Ders sonrası değerlendirme oluşturma

- `POST /api/v1/requests/{id}/reviews` JWT kimlik doğrulaması gerektirir. Payload ve hata kodlarının kesin şeması backend ile doğrulanmalıdır. Henüz HTTP adaptörü yoktur.
- Yalnızca ACCEPTED ve açıkça `completionStatus: COMPLETED` olan dersler uygundur. Tarihin geçmiş olması, BOOKED ilan veya tamamlanma zamanları tek başına yeterli değildir. Bilinmeyen durumlar kapalıdır.
- Gerçek backend JWT katılımcısını, karşı tarafın gerçek kimliğini, 1–5 integer puanı, isteğe bağlı en fazla 1000 karakter yorumu ve request+reviewer tekilliğini transaction içinde doğrulamalıdır. İstemci recipient seçimi yetki sayılmaz.
- Mock repository güvenilir aktörü composition root üzerinden alır. Katılımcı, karşı taraf ve tekrar gönderim kontrollerini kayıt sırasında yeniden yapar. Aynı bellekteki recipient-ID koleksiyonu güncellenir; farklı kullanıcılar karışmaz.
- Liste DTO alanları değişmez: id, requestId, reviewer (id/firstName/lastNameInitial/departmentId), rating, nullable comment, createdAt. Ders veya reviewee nesnesi üretilmez. Formdaki ders/katılımcı bilgisi mevcut başvuru bağlamından gelir. UUID kimlikleri dönüştürülmez; yeni yerel review ID'si sunucu UUID'si değildir.
- Repository değişim bildirimi ile liste ve güvenilir özetleri yeniler. Değişen kullanıcının eski mock cursor'ları geçersizleşir. Gerçek adaptör de cache yenileme ve tüm kayıtların güvenilir özetini sağlamalıdır; ilk sayfa ortalaması genel puan değildir.
- `POST /api/v1/requests/{id}/confirm` Flutter'a bağlı değildir. Otomatik tamamlama eklenmedi. İleride taraf onayları, deadline/settlement ve completionStatus yenilemesi bağlanmalıdır.
- HOME_PREVIEW içinde iki açıkça COMPLETED kabul edilmiş örnek başvuru vardır; bunlar debug verisidir. Mevcut 4.7/3 ve Deniz örnek değerlendirmeleri korunur. Normal başvurular yaşlanınca COMPLETED üretilmez.
- Mock başarı yalnızca bellekteki geliştirme verisini değiştirir; yeniden başlatmada silinir. Sunucu kalıcılığı, cüzdan, transaction, mesaj veya bildirim işlemi yapılmaz. REST adaptörü bulunmadan gerçek hesaplar için gönderim desteklenmez.
