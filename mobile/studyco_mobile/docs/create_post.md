# İlan Oluştur

Referans: `C:/StudyCoProject/design_references/studyco_create_post.png`.

Ekran `features/posts/screens/create_post_screen.dart` altında yer alır. Yalnızca Özel Ders ilanı oluşturur. İlgili bölüm `Post.department`, seçilen ders adı `Post.title`, dersin mevcut Ana Sayfa kategorisi `Post.subject`, zorunlu konu `Post.topic`, isteğe bağlı açıklama `Post.description` alanına yazılır. Kullanıcı adı enjekte edilen `UserProfile.firstName` üzerinden alınır; soyadı üretilmez.

## Akış

`HomePreview`, sahip olduğu repository ve kullanıcıyı `CreatePostScreen` rotasına verir. `HomeScreen.onCreatePost` bir `Future<bool?>` döndürür. Yalnızca başarılı eklemede ekran `true` ile kapanır; mevcut Ana Sayfa'ya dönülür. Ana Sayfa artık kategori filtresi tutmadığından filtre sıfırlama yapılmaz. Repository ve Ana Sayfa yeniden oluşturulmaz. `AnimatedBuilder` bildirimi alır; bütün Özel Ders ilanları `createdAt` azalan / `id` artan sıralamayla listelenir, gösterim ilk 6 ilanla sınırlıdır. Repository bütün kayıtları tutar.

İlanlar yalnızca oturum belleğinde tutulur. Ekrandaki açıklama ve başarı mesajı kalıcı sunucu yayını yapılmadığını belirtir. Kahve seçenekleri semboliktir; bakiye/ödeme/transfer yapılmaz.

`createdAt` gönderim anında UTC olarak üretilir. `startsAt` ve `endsAt` seçilen günün yerel saatleriyle oluşturulur. Bitiş aynı gün ve başlangıçtan sonra, başlangıç yayınlama anından sonra olmalıdır. Kimlik yerel zaman damgası, oturum sayacı ve repository çakışma kontrolüyle üretilir. Backend bağlandığında kimlik ve zaman otoritesi ayrıca kararlaştırılmalıdır.

## Konum seçimi

Dosya: `lib/features/posts/widgets/post_location_field.dart`.

`PostLocationField` yalnızca izin verilen katalogdan seçim yapılan zorunlu konum menüsüdür. Altındaki mevcut bilgilendirme metni korunur. Serbest metin veya Diğer seçeneği yoktur. `onLocationChanged(String)` formdaki seçili adı günceller; form liste üyeliğini tekrar doğrular ve adı `Post.location` olarak kaydeder. Liste dışı değerler ve gönderim sırasında gelen değişiklikler kabul edilmez.

İlan Oluştur ve İlan Detayları ekranlarındaki dekoratif harita önizlemeleri ve bunlara özel çizim/widget kodları kaldırılmıştır. Konum menüsü, kafe adı ve konum doğrulaması korunur; harita entegrasyonu eklenmemiştir.

## Backend bağlantısı

Mevcut `PostsRepository.addPost` sözleşmesini uygulayan gerçek veri kaynağı eklenmeli. DTO/JSON, kimlik üretimi, tarih/saat dilimi, yazar kimliği, konum ve tekrar deneme/idempotency sözleşmeleri henüz belirlenmedi. Başarılı doğrulanmış işlemden sonra repository dinleyicilere bildirim göndermeli. Form yalnızca `await addPost` tamamlanınca kapanır; hata halinde girdileri korur.

## Kontroller

`flutter analyze`

`flutter test`

`flutter test test/home_preview_test.dart --dart-define=HOME_PREVIEW=true`

Testler: zorunlu alanlar, bölüm/ders ayrımı ve zorunlu konu, boşluk kontrolü ve trim ile yayınlama, tarih/saat sınırları, dört karşılık, çift gönderim, başarısızlık/yeniden deneme, aynı repository, Ana Sayfa'ya dönüş ve otomatik güncelleme, en fazla 6 ilan ve eski kayıtların korunması, haritasız yayınlama, navigasyon, 320px ekran/klavye ve 2x yazı ölçeği.

## Bağlı bölüm ve ders seçimleri

Bölüm ve ders seçeneklerinin çalışma zamanı kaynağı ortak `AcademicCatalogScope` içindeki `AcademicCatalog` nesnesidir. Kayıt Ol, İlan Oluştur ve Arama aynı kaynağı kullanır. Varsayılan `AcademicCatalog.temporary`, `Departments.values` listesini kullanarak bölüm sırasını ve adlarını korur. API kataloğu `MyApp(academicCatalog: ...)` üzerinden bu kaynağın tamamen yerine verilir; listeler birleştirilmez.

Geçici ders önerilerinin kaynağı `lib/features/posts/data/department_courses.dart` dosyasıdır; ekranlar bunları doğrudan okumaz, ortak akademik katalogdan alır. Ortak bölüm listesindeki 10 bölümün tamamı için 3–4 hazır ders vardır. Bunlar kullanıcıya yardımcı başlangıç önerileridir; resmi üniversite müfredatı değildir. Bölüm listesi veya eşleştirmeler değiştiğinde testler her bölümde 3–5 hazır ders bulunmasını denetler. Bölüm listesinde ayrıca Matematik bölümü bulunmadığı için yeni bir bölüm eklenmemiştir.

`DepartmentCourses.byDepartment` yalnızca hazır dersleri tutar. Geçici yardımcı `forDepartment` ve ortak kataloğun `coursesFor(..., includeOther: true)` metodu, form için listenin sonuna tek bir `Diğer` seçeneği ekler. Bu seçenek gerçek katalog dersi değildir ve kimliği yoktur. `DepartmentCourse.isOther`, bu seçeneği gerçek derslerden ayırır. Diğer seçildiğinde zorunlu `Ders adını yazın *` alanı açılır; boş veya yalnızca boşluk içeren değer kabul edilmez. Manuel ders adı trim edilerek `Post.title` alanına yazılır. Hazır seçimlerde aynı alan seçilen dersin adını alır. Bölüm değişince ders ve manuel ad temizlenir; hazır derse geçildiğinde manuel alan gizlenir ve temizlenir. Ders seçiminden sonra zorunlu Konu alanı gelir; ardından isteğe bağlı çok satırlı Açıklama bulunur. Konu kullanıcı tarafından yazılır; boş veya yalnızca boşluk içeren değer reddedilir.

Her hazır `DepartmentCourse`, ders adı ve mevcut `PostSubject` eşleşmesini taşır. Bilgisayar/Yazılım bölümlerindeki yazılım dersleri `coding`, mevcut Lineer Cebir dersi `mathematics` olur. Diğer bölümlerin hazır dersleri nötr `general` kategorisindedir. Manuel ders adından kategori tahmin edilmez: bütün `Diğer` seçimleri `general` olarak kaydedilir. Bölüm bir Ana Sayfa kategorisi değildir. İleride yeni dersler eklenirken nötr kategoriyi kullanmak mümkündür; uyumsuz dersleri yazılım veya matematik kategorisine zorla eşleştirmeyin.

Ana Sayfa'da kategori filtreleri bulunmaz. `coding`, `mathematics` ve `general` değerleri modelde korunur; gelecekte Arama ekranının filtrelemesi için kullanılabilir. Bütün Özel Ders ilanlarından `createdAt` azalan / `id` artan sıralamayla ilk 6 ilan gösterilir. Repository'nin tüm ilanları tutması ve otomatik güncelleme korunur. Tümü bağlantısı alt menüdeki Ara ile aynı hedefe gider. İlan Oluştur formunun kategori bilgisi üretmesi değişmez.

Bölüm ve ders seçimi boş başlar, ikisi de zorunludur. `Post.department` eski ilanlarla uyum için nullable kalır; yeni ekranın oluşturduğu ilanlarda mutlaka dolar. Ders adı `Post.title`, isteğe bağlı ders ayrıntıları `Post.description` alanında saklanır. `Post.topic` eski, konusu olmayan kayıtlarla uyum için modelde `String?` olarak korunur. Eski konu değerleri değişmez. İlan Oluştur formu ise yeni her ilan için boş olmayan bir konu zorunlu tutar ve `trim()` uygulayarak `Post.topic` alanına yazar. Sahte konu veya ders adından türetilmiş konu üretilmez. Bu yerel model değişikliği bir API/JSON sözleşmesi tanımlamaz.

Konumların tek kaynağı `lib/features/posts/data/campus_locations.dart` içindeki `CampusLocations.values` sabit listesidir; repository ilanlarından türetilmez. Mevcut dört örnek ad geçici seçeneklerdir. `isTemporary = true` iken ekranda kampüs içi uygunluklarının henüz doğrulanmadığı açıkça belirtilir. Ekip arkadaşı gerçek listeyi belirlediğinde bu dosyada isimleri güncellemeli; doğrulama tamamlanınca `isTemporary` bayrağını false yapmalıdır. Boş listede menü devre dışı kalır, açıklama gösterilir ve yayınlama engellenir. Kullanıcı listeden seçim yapmadan yayınlayamaz; serbest metin veya Diğer seçeneği bulunmaz.


