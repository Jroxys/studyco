# Değerlendirmeler entegrasyonu

## Kapsam ve backend

Mevcut backend bilgisi: Node.js + TypeScript + Fastify, PostgreSQL. Bu checkout'ta backend kaynakları değiştirilmedi; Flutter'da gerçek HTTP/SQL çağrısı yok. Alınan değerlendirmelerin okunması, sayfalanması, görüntülenmesi ve tamamlanmış derslerde mock değerlendirme gönderimi desteklenir. İlan sahibi kartından alınan değerlendirmelerin okunması da aynı kaynakla desteklenir. Tam ilan sahibi profili, ders tamamlanma onayı ve Mesajlar bu kapsamda uygulanmadı.

| Sağlanan endpoint | Kullanım |
| --- | --- |
| GET /api/v1/users/{id}/reviews | Kullanıcı kimliğine göre alınan değerlendirmeler; fetchForUser |
| GET /api/v1/requests/{id}/reviews | İleride ilgili ders başvurusunun değerlendirmeleri |
| POST /api/v1/requests/{id}/reviews | Yetkili katılımcının değerlendirme göndermesi; REST adaptörü bekleniyor |

Bu endpoint'ler JWT gerektirir. Diğer StudyCo kullanıcılarının değerlendirmeleri oturum açmış kullanıcılarca görülebilir; herkese açık profil ifadesi internetten anonim erişim anlamına gelmez. Gerçek REST adaptörü JWT oturumunu kullanmalı ve 401/403, zaman aşımı, iptal ve backend hata sözleşmesini ele almalıdır. UI HTTP bilmez. Bu görevde hayalî auth token, HTTP başarısı veya sunucu yazımı üretilmedi.

## Model ve DTO

ReviewDto.fromJson yalnız verilen alanları eşler: id, requestId, reviewer(id, firstName, lastNameInitial, departmentId), rating, comment, createdAt. UUID metinleri değiştirilmez. Reviewer tam soyadı yoktur; yalnız verilen baş harf gösterilir. DepartmentId tutulur ancak bölüm adı tahmin edilmez. Rating 1–5 arası tam sayı olmalıdır; bozuk kimlik, tarih veya rating sessizce istatistiğe dahil edilmez, eşleme hata üretir. Comment null/boş/yalnız boşluk olduğunda UI yorum alanı oluşturmaz. createdAt tarih olarak saklanır ve görüntülemede cihazın yerel saatine çevrilir.

Yanıtta ders/ilan başlığı ve reviewee nesnesi yoktur. Domain'e bu alanlar eklenmedi. Alıcı kullanıcı kimliği sorgu bağlamıdır; InMemoryReviewsRepository veriyi açık recipient ID anahtarıyla tutar. UI requestId'den ders adı veya başka bir kullanıcı üretmez. İleride ders bilgisi istenirse doğrulanmış request/ilan servisi veya backend response genişletmesi gereklidir.

## Kaynak ve kimlikler

ReviewsRepository ortak okuma ve gönderim domain sınırıdır. InMemoryReviewsRepository gönderim yetkisi için aynı ApplicationsRepository kaynağını kullanır; UI HTTP bilmez. Aynı fetchForUser(userId) başka bir kullanıcının değerlendirmelerini de getirebilir. ReviewCard, RatingSummary ve RatingStars ortak bileşenlerdir. ReviewsRepositoryScope Navigator üzerinde yer alır; Profilim rotası hangi ekrandan açılırsa açılsın aynı kaynağı kullanır. MyApp(reviewsRepository: ...) gerçek adaptörü app katmanından enjekte etmeye hazırdır. Dışarıdan verilen repository'nin yaşam döngüsü sahibine aittir; app yalnız kendi oluşturduğu debug kaynağını dispose eder.

Gerçek kaynak için UserProfile.id doğrulanmış auth kullanıcı UUID'si olmalıdır. Kimlik yoksa Profilim gerçek repository'ye postsOwnerId/session-user anahtarı göndermez. Yalnız isLocal mock kaynağında aynı kullanıcı nesnesine bağlı geçici postsOwnerId kullanılabilir. İsimle alıcı/yazar eşleme yapılmaz. İlan sahibinin değerlendirmeleri aynı repository üzerinden Post.authorId ile sorgulanır; authorName kimlik olarak kullanılmaz.

## Sayfalama

Backend yanıtı items ve nullable nextCursor içerir. limit varsayılan 20, en fazla 50; cursor isteğe bağlı ve opak metindir. Gerçek adaptör bu değerleri URL query parametrelerine doğru kodlayarak aktarmalıdır. ReviewDto.pageFromJson nextCursor anahtarı yoksa bunu listenin sonu varsaymaz, hata üretir. API'de var olmayan total veya average alanları okunmaz.

Ekran ilk sayfayı alır; devam varsa Daha Fazla Göster sunar. Ek sayfa hatasında mevcut kartlar korunur ve aynı cursor ile yeniden deneme yapılır. Çift yükleme kilitlidir; kimlik/repository değişiminde eski cevap yeni kullanıcı ekranına yazılmaz. Aynı review ID tekrar gelirse sayım şişirilmez. Tekrarlayan cursor döngüsü hata olarak durdurulur.

Mock cursor'ları yalnız mock kaynağına ve ilgili userId'ye aittir; diğer kullanıcının cursor'ı reddedilir. Bunlar backend cursor formatı değildir, gerçek REST adaptöründe kullanılmamalıdır. Mock koleksiyonlar snapshot olarak kopyalanır ve en yeni tarih/id sırasıyla sayfalanır. Gerçek sunucunun sıralama ve cursor tutarlılığı ayrıca doğrulanmalıdır.

## Güvenilir genel puan

Ortalama sabit sayı değildir: geçerli kayıtların rating toplamı / benzersiz review sayısıdır; kayıt yoksa ortalama null ve Henüz değerlendirme yok gösterilir. İlk sayfada nextCursor varsa UI bu sayfanın ortalamasını genel puan gibi sunmaz. Genel puan için tüm değerlendirmeler yüklenmeli bilgisi ve yalnız yüklenen kayıt sayısı gösterilir; bu sayı toplam değerlendirme sayısı olarak etiketlenmez.

Tüm sayfalar yüklendiğinde, nextCursor null olduğunda biriken benzersiz kayıtlar üzerinden özet hesaplanabilir. Değişen veri üzerinde çok sayfalı okuma snapshot garantisi sağlamayabilir. Büyük listeler ve tutarlı gerçek genel puan için backend'den tüm kayıtları kapsayan güvenilir toplam sayı ve puan toplamı/ortalaması gerekir; sağlanan API sözleşmesinde böyle bir özet alanı/endpoint'i yoktur. Yeni isim veya endpoint uydurulmadı. Backend ekibi auth, tutarlılık ve response sözleşmesini netleştirmelidir.

ReviewPage.overall opsiyonel DOMAIN metaverisidir; mevcut API response alanı değildir. Mock bütün kullanıcı kayıtlarını bildiği için bunu tamamından hesaplayıp verir; ilk 20 kayıttan hesaplamaz. Gerçek DTO mapper'ı overall üretmez. Gelecekte gerçek adaptör ancak doğrulanmış, bütün veri kümesini kapsayan güvenilir istatistik kaynağı olduğunda bu metaveriyi sağlamalıdır. Başarısız yükleme boş liste/0 puan olarak sunulmaz.

## Debug ve sonraki aşamalar

Sadece kDebugMode && HOME_PREVIEW etkin ve şifre sıfırlama önizlemesi öncelikli değilken app/debug/reviews_preview_data.dart örnekleri ayrı InMemoryReviewsRepository'ye yüklenir. Mock kimlikler ve örnek kullanıcı adları kullanılır; gerçek kullanıcı kaydı, tamamlanma olayı veya API sonucu gibi oluşturulmaz. Normal login/gerçek adaptör otomatik mock veri almaz. Kaynak enjeksiyonunda mock ve REST karıştırılmaz.

Değerlendirme gönderme requestId üzerinden yetkili katılımcıya bağlanır. Sadece ders tarihinin geçmesi veya accepted durumu gönderme hakkını kanıtlamaz. Completion/settlement şartları, kim kime değerlendirme yapabilir, tekil değerlendirme kuralı, izinli süre, POST payload şeması, yorum uzunluğu ve hata kodları backend ile doğrulanmalıdır. Reviewee ders katılımcılarından backend tarafından belirlenmeli; UI isimden çıkarmamalıdır. Mock gönderim vardır; gerçek REST gönderimi ve confirm işlemi henüz bağlı değildir.

## Profil değerlendirme kartı

ProfileScreen ve ReviewsScreen aynı ReviewsRepositoryScope kaynağını veya açıkça enjekte edilen aynı repository'yi kullanır. Profil yalnız ReviewStatistics projeksiyonunu tutar; ayrı review koleksiyonu veya sabit puan/sayı yoktur. fetchSummaryForUser varsayılan olarak ilk sayfayı okur ve ReviewPage.statistics ortak güvenilirlik kuralını uygular: güvenilir overall varsa onu kullanır; nextCursor null ise tam kayıtları hesaplar; kısmi sayfada genel özet null kalır. Profil bu durumda Genel puan bekleniyor. gösterir, ilk sayfanın puanını/sayısını toplam gibi sunmaz. Tüm sayfaları yüklemiş detay ekranında hesaplanabilen özetin profil ilk sayfa sorgusunda bulunamaması, hayalî önbellekle gizlenmez; gerçek backend için güvenilir toplam istatistik ihtiyacı devam eder.

Kart ilk açılışta yüklenme, hatada Puan bilgisi alınamadı., boş tam listede Henüz değerlendirme yok gösterir. Karta veya Değerlendirmelerim menüsüne basınca mevcut detay rotası açılır; geri dönüldüğünde kaynak yeniden okunur. Kaynak/kullanıcı kimliği değişirse eski cevap yeni kullanıcıya yazılmaz. Kartın mevcut ProfileStatCard yerleşimi, renkleri ve padding/minimum yüksekliği korunur; value parametresi token kartı için eski placeholder varsayılanını korur. Bu işlem yeni endpoint veya HTTP çağrısı değildir; gelecekte REST adaptörü yalnız doğrulanmış tüm-veri istatistik kaynağı varsa fetchSummaryForUser metodunu buna göre genişletebilir.

## İlan Detayları → İlan Sahibinin Değerlendirmeleri

PostOwnerCard, PostDetailsScreen içindeki mevcut avatar/ad/İlan Sahibi kartını genişletir. ReviewsRepositoryScope veya açıkça enjekte edilen aynı kaynak üzerinden fetchSummaryForUser(Post.authorId) çağrılır; UI içinde HTTP yoktur. Post.authorId sunucunun gerçek sahip UUID'si olarak taşınmalıdır, değiştirilmez. Adlar eşleştirilmez; boş/eksik kimlikte başka kimlik üretilmez, fetch yapılmaz ve değerlendirme geçişi kapalı kalır. Kart İlan sahibi kimliği mevcut değil. gösterir.

Sıfır kayıt, yüklenme, hata ve güvenilir genel özetin bulunmaması ayrıdır. Sadece güvenilir ve count > 0 özet varsa yıldız, ortalama ve toplam sayı gösterilir. Boş tam kaynak Henüz değerlendirme yok; kısmi kaynak/servis hatası Puan bilgisi şu anda gösterilemiyor. gösterir. Hata durumunda kartta Puanı yenile kontrolü vardır; bilinen kimlik ve kaynak varsa genel puan bilinmese de tam liste açılabilir. İlk sayfa ortalaması genel puan sayılmaz. Büyük listelerde güvenilir sunucu özeti ihtiyacı devam eder.

Kart aynı ReviewsScreen'e aynı repository instance'ını ve hedef authorId'yi iletir. Görüntüleyen kimliği authorId ile aynıysa Değerlendirmelerim, farklıysa Değerlendirmeler ve Bu kullanıcıya verilen puanlar ve yorumlar. gösterilir. RatingSummary başlığı buna göre değişir; ReviewCard ve RatingStars yeniden kullanılır. Geri dönüş aynı ilan detayını ve başvuru durumunu korur; kart özeti yeniden okunur. Sahip/kaynak değişiminde eski özet cevabı yeni sahibin kartına uygulanmaz.

Gerçek bağlantı GET /api/v1/users/{authorId}/reviews yoluna, limit/cursor ve JWT ile yapılmalıdır. Bu endpoint oturum açmış StudyCo kullanıcılarına yöneliktir; kimliği bilinen bir sahibin kartının görünmesi anonim internet erişim yetkisi sağlamaz. DTO aynı id/requestId/reviewer/rating/comment/createdAt alanlarını kullanır; tam soyad, ders adı, reviewee veya toplam istatistik alanı uydurulmaz. Gerçek adaptör hata ve auth cevaplarını ele almalıdır; yeni HTTP isteği eklenmedi.

HOME_PREVIEW'de previewTeacherId ile tanımlı Python Etüdü örnek sahibine ayrı mock değerlendirmeler eklenir. Bu anahtar ilanla ortaktır; isimden türetilmez. Mevcut sampleHomeUser koleksiyonunun kayıtları ve 4.7/3 hesabı korunur. Sahibin ve mevcut kullanıcının puanı UI'a sabit yazılmaz; kendi kayıtlarından hesaplanır. Örnekler yalnız debug mock kaynağına yüklenir, gerçek API kaynağına karıştırılmaz.


## Ders sonrası değerlendirme oluşturma

- `POST /api/v1/requests/{id}/reviews` JWT kimlik doğrulaması gerektirir. Payload ve hata kodlarının kesin şeması backend ile doğrulanmalıdır. Henüz HTTP adaptörü yoktur.
- Yalnızca ACCEPTED ve açıkça `completionStatus: COMPLETED` olan dersler uygundur. Tarihin geçmiş olması, BOOKED ilan veya tamamlanma zamanları tek başına yeterli değildir. Bilinmeyen durumlar kapalıdır.
- Gerçek backend JWT katılımcısını, karşı tarafın gerçek kimliğini, 1–5 integer puanı, isteğe bağlı en fazla 1000 karakter yorumu ve request+reviewer tekilliğini transaction içinde doğrulamalıdır. İstemci recipient seçimi yetki sayılmaz.
- Mock repository güvenilir aktörü composition root üzerinden alır. Katılımcı, karşı taraf ve tekrar gönderim kontrollerini kayıt sırasında yeniden yapar. Aynı bellekteki recipient-ID koleksiyonu güncellenir; farklı kullanıcılar karışmaz.
- Liste DTO alanları değişmez: id, requestId, reviewer (id/firstName/lastNameInitial/departmentId), rating, nullable comment, createdAt. Ders veya reviewee nesnesi üretilmez. Formdaki ders/katılımcı bilgisi mevcut başvuru bağlamından gelir. UUID kimlikleri dönüştürülmez; yeni yerel review ID'si sunucu UUID'si değildir.
- Repository değişim bildirimi ile liste ve güvenilir özetleri yeniler. Değişen kullanıcının eski mock cursor'ları geçersizleşir. Gerçek adaptör de cache yenileme ve tüm kayıtların güvenilir özetini sağlamalıdır; ilk sayfa ortalaması genel puan değildir.
- Ders onayı ortak ApplicationsRepository üzerinden ilerler. `POST /api/v1/requests/{id}/confirm` gerçek JWT ve boş gövdeyle çağrılacak; idempotent yanıtın güncel `completionStatus` ve onay tarihleri başvuru kaynağına yazılacak. İlk onayda form açılmaz; ikinci onay veya 24 saatlik pencere sonunda backend'den gelen açık COMPLETED sonucu mevcut formu açabilir. MANUAL_REVIEW değerlendirmeye kapalıdır. Token blokesi ve aktarımı backend sorumluluğundadır. Yanıt alanları, hata eşlemesi ve henüz bağlanmamış REST adaptörü için [başvuru entegrasyonuna](../applications/APPLICATIONS_INTEGRATION.md#iki-taraflı-ders-onayı) bakın.
- HOME_PREVIEW iki mevcut COMPLETED örneğini ve değerlendirme puanlarını korur. Yeni örnekte öğrenci Başvurularım'dan onay verir; Ana Sayfa'daki “Ders Onayı: Örnek İlan Sahibi” düğmesi ayrı bir debug kimliğiyle aynı kaydı Gelen Başvurular'da açar. İkinci onaydan sonra öğrenci kendi paneline dönüp mevcut Değerlendir formunu açabilir. Bu iki görünüm gerçek oturum oluşturmaz; kayıt yalnız bellektedir ve API'ye gönderilmez.
- Mock başarı yalnızca bellekteki geliştirme verisini değiştirir; yeniden başlatmada silinir. Sunucu kalıcılığı, cüzdan, transaction, mesaj veya bildirim işlemi yapılmaz. REST adaptörü bulunmadan gerçek hesaplar için gönderim desteklenmez.
