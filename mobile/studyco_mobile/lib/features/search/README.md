# Arama

SearchScreen aynı PostsRepository örneğini dinler ve bütün geçici ilanları gösterir. Kartlar, renkler ve navigasyon korunur. Detay rotasına aynı Post nesnesi iletilir; geri dönünce filtreler ve kaydırma konumu korunur.

Arama yalnızca topic alanına uygulanır; Türkçe karakter ve harf toleransı korunur. Sonuçlar startsAt ASC sırasındadır; eşit tarihlerde yerel kararlılık için id kullanılır. Sonuçlar PostsRepository.discoverablePosts içinden gelir; başlamış/geçmiş veya başvuruya kapalı ilanlar keşifte yer almaz, tam snapshot içinde korunur. Ana Sayfa değişmedi: createdAt tarihine göre en yeni 6 ilanı gösterir. Bu sıralama backend listeleme sırasından farklıdır.

Kahve filtresi maxPrice üst sınırıdır (0–3). PostOffer.free her zaman 0 olarak yorumlanır; diğerlerinde coffeeCount kullanılır. Bölüm → Ders bağı korunur. Konum seçenekleri İlan Oluştur ile aynı LocationCatalogScope kataloğundan gelir; ilanlardan ek seçenek türetilmez. Katalog dışı eski ilanlar Tümü seçiliyken görünmeye devam eder. Bölüm, ders ve konum şu an geçici katalog adlarıyla filtrelenir; API entegrasyonunda gerçek departmentId, courseId ve locationId UUID değerlerine eşlenmelidir. Sahte UUID üretilmez, Post modeli değiştirilmez.

## Backend entegrasyonu için kalanlar

GET /api/v1/listings q (yalnız topic), departmentId, courseId, locationId, from/to (ISO-8601), maxPrice ve limit (en fazla 50) kabul eder. from/to tarih filtreleri bu ekranda henüz yoktur. Backend startAt alanı Post.startsAt ile eşlenmelidir. Gerçek API, kimlik doğrulama ve katalog eşlemeleri bu aşamada eklenmedi.

Backend cursor tabanlı sayfalama kullanır; sonraki sayfa cursor ile istenir. Şu an filtreler bellekteki tam listeye uygulanır; sonuç sayısı yerel liste sayısıdır. API bağlanırken filtreler sunucuya taşınmalı, filtre değişince cursor sıfırlanmalı ve sayfalar birleştirilmelidir; yalnız yüklenmiş sayfayı filtrelemek yeterli değildir.

Backend varsayılan listeleme sorgusu kullanıcının kendi ilanlarını hariç tutar; kendi ilanları için /api/v1/me/listings bulunur. Yerel repository şu an kendi ilanları dahil bütün ilanları gösterir. Bu fark kimlik doğrulama ve API entegrasyonu aşamasında ele alınmalıdır.

Bölüm/ders seçenekleri ortak AcademicCatalogScope üzerinden alınır. Bölüm değişimi ders filtresini her zaman sıfırlar. API kataloğu sağlandığında geçici dersler veya örnek ilan başlıkları bu kataloğa eklenmez; geçici katalogla çalışırken manuel/eskiden oluşturulmuş ders önerileri korunur. Gerçek kimlik eşlemesi ve bağlama noktası için ../posts/README.md içindeki bölüm/ders kataloğu notlarına bakın.
