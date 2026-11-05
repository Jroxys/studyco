# posts

- models/post.dart: immutable ilan modeli.
- domain/posts_repository.dart: ortak reaktif repository sözleşmesi.
- data/in_memory_posts_repository.dart: geçici bellek kaynağı.
- data/sample_posts.dart: tasarım örnekleri.
- widgets/post_card.dart: ortak ilan kartı; kart gövdesi ve ok aynı onOpen callback'ini çağırır; ilk sürümde kaydet düğmesi yoktur.
- screens/post_details_screen.dart: seçilen Post nesnesini doğrudan alan, salt okunur ve başka kaynaklardan da açılabilen detay ekranı.

İlan Oluştur, Ana Sayfa ve ileride diğer ilan ekranları aynı repository instance'ını app katmanından almalıdır. addPost değişiklik bildirir; UI listenebilir snapshot üzerinden güncellenir. Kalıcı kayıt veya API yoktur. Gerçek servis data/ altında ayrı implementasyon olarak eklenebilir.

Ayrıntılar: ../../../docs/home.md

İlan Detayları, HomePreview içindeki mevcut HomeScreen.onOpenPost callback'iyle açılır. Arama ileride aynı `PostDetailsScreen(post: selectedPost, repository: sharedRepository)` rotasını kullanabilir. Detay ekranı repository oluşturmaz; ilan bilgilerini değiştirmez. İlk sürümde favoriler desteklenmez; kaydet kontrolleri ve geçici favori durumu kaldırılmıştır. Boş açıklama, bölüm ve eski kayıtlardaki boş konu gösterilmez. Modelde ilan sahibinin profil kaydı veya güvenilir kullanıcı/yazar kimliği yoktur; ad karşılaştırmasıyla sahiplik kontrolü yapılmaz.

Başvur düğmesi şimdilik yalnızca işlemin hazır olmadığını bildirir. Başvuru/kabul/ret/eşleşme/sohbet durumu oluşturulmaz. Gerçek entegrasyonda başvuru ilan sahibinin Gelen Başvurular alanına gitmeli; yalnızca kabulden sonra tek bir ortak sohbet açılmalı. Bekleyen/reddedilen başvuru mesajlaşma yetkisi vermez. Kabul sonrası Mesaj Gönder mevcut sohbeti açmalı, ikinci sohbet oluşturmamalıdır. Sahiplik ve erişim denetimleri güvenilir kimliklerle gerçek entegrasyonda yapılmalıdır.

## Tek konum kaynağı

İlan Oluştur ve Arama, Navigator üzerindeki LocationCatalogScope içinden aynı LocationCatalog snapshot'ını kullanır. Varsayılan geçici kaynak yalnızca data/campus_locations.dart içindeki CampusLocations.catalog değeridir. Geçici katalog, ekibin locations.csv başlangıç verilerinden sağladığı 10 adı kullanır: Espressolab, Florida, Colombia, Starbucks, Study, Nevada, Loba, Albert, Nexq, Arabica. UUID değerleri verilmediği için geçici girişlerde id null kalır. Örnek ilan konumları bu katalogla uyumlu hâle getirilmiştir.

GET /api/v1/locations bağlandığında API cevabı gerçek id/name değerleriyle CampusLocation nesnelerine çevrilip MyApp(locationCatalog: ...) üzerinden TAM katalog olarak verilmelidir. Geçici katalogla veya ilan konumlarıyla birleştirilmez; boş API kataloğu da boş kalır. API yükleme/hata yönetimi ve gerçek çağrı henüz yoktur. locationId için sadece sunucunun gerçek kimliği kullanılmalıdır; geçici girişlerde id null'dır. Kaynak değişiminde eski konum seçimi menüde temizlenir, geçersiz konumla ilan yayımlanamaz.

İsimler Türkçe harf/büyük-küçük harf/boşluk farkları ve tekrarlı kimlikler bakımından tekilleştirilir; ilk kanonik ad korunur. Post modeli hâlâ konum adını tutar; oluşturma seçilen katalog adını kaydeder, arama eski ilan adlarını aynı normalize anahtarla eşler. Gerçek locationId ilan eşlemesi sonraki API entegrasyonuna aittir. Mevcut ilanların konum adları korunur. Oluşturma ve detay ekranlarındaki dekoratif harita önizlemeleri kaldırılmıştır; konum menüsü ve detay konum kartının stili korunur.

## Bölüm ve ders kataloğu

İlan Oluştur, Arama ve Kayıt Ol, Navigator üzerindeki AcademicCatalogScope aracılığıyla aynı AcademicCatalog snapshot'ını kullanır. Tek geçici kaynak AcademicCatalog.temporary'dir; mevcut Departments ve DepartmentCourses başlangıç seçeneklerini kullanır. API kataloğu MyApp(academicCatalog: ...) üzerinden tamamıyla bunun yerine verilir. Boş katalog da boş kalır; sunucu verileri geçici seçeneklerle birleştirilmez. Bölüm/ders endpoint adları bu checkout'ta doğrulanmadığı için varsayılmamış, HTTP servisi eklenmemiştir.

AcademicDepartment.id gerçek departmentId'yi, içindeki DepartmentCourse.id gerçek courseId'yi taşıyabilir. Derslerin hangi bölüme ait olduğu katalogda bölümün courses listesiyle temsil edilir; adlar kimlik yerine geçmez. Geçici kayıt kimlikleri null'dır. Diğer yalnızca formda eklenen kimliksiz manuel giriş seçeneğidir; katalogdaki gerçek dersler arasında tutulmaz.

Post/UserProfile modelleri değiştirilmedi. Yerel ilan ve kayıt akışı hâlâ adlarla çalışır; gelecekte API taşıma katmanı seçilen katalog kaydındaki gerçek kimlikleri kullanmalıdır. UUID ile kayıt, manuel dersin backend'e gönderim sözleşmesi ve kullanıcı kimlik doğrulaması bu görevde uygulanmadı. Backend'in manuel ders desteği ayrıca doğrulanmalıdır.

Arama, geçici kaynak etkin olduğunda eski/manuel ilan derslerini önceden olduğu gibi seçeneklere ekler. Dışarıdan verilen katalogda yalnızca o kataloğun ders seçenekleri gösterilir; ilanlardan veya geçici listeden ek ders üretilmez. Katalog dışı eski ilanlar Tümü seçiliyken görünür. Bölüm değişince ders seçimi, katalog kaynağı değişince bölüm/ders seçimleri temizlenir.
