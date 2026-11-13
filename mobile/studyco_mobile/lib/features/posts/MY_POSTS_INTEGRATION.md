# İlanlarım entegrasyonu

Aktif feature/flutter-ui dalında InMemoryPostsRepository kullanılır. Oluşturma, düzenleme ve silme oturumluk mock işlemlerdir; gerçek HTTP veya kalıcı kayıt yoktur. Teslim denetiminde yerel origin/integration/backend-flutter (786449e) backend kaynakları Git nesnelerinden salt okunur incelendi; canlı servis doğrulanmadı.

UserProfile.id / Post.authorId gerçek entegrasyonda JWT kullanıcısı ve sunucu UUID’si olmalıdır. postsOwnerId fallback’i yalnız yerel kimliktir; yazar adıyla sahiplik eşlemesi yapılmaz. Oluşturma, detay, İlanlarım ve başvurular aynı repository örneklerini paylaşır.

## Doğrulanmış API sınırı

- GET /api/v1/me/listings: kullanıcının ilanları; dizi yanıtı, pendingRequestCount içerir.
- POST /api/v1/listings: courseId, locationId, topic, isteğe bağlı description, startAt, endAt, tokenPrice ister. UUID’ler gerçek katalogdan gelmelidir. topic en fazla 160, description en fazla 5000 karakter; tokenPrice 0–3, süre en fazla 8 saattir.
- PATCH /api/v1/listings/{id}: yalnız topic ve description desteklenir. Ders, konum, saat ve fiyatı değiştiren mock tam düzenleme bu endpoint’e aynen taşınamaz.
- İlan silme endpoint’i yoktur. Mock deletePost için hayalî DELETE çağrısı veya sunucu başarı sonucu üretilemez.

Post modeli ders/bölüm/konum gösterim adlarını tutar; courseId/locationId doğrudan alanı yoktur. Gerçek adaptörün güvenilir katalog kimliği eşlemesi gereklidir. Manuel ders başlığının backend’de courseId karşılığı yoksa ürün kararı gerekir; sahte UUID üretilmez.

supportsFullPostEditing varsayılan false’dur; yalnız mock tam düzenlemeyi açar. Gerçek adaptörde alan bazında kısıtlamalar sağlanmadan bayrak açılmamalıdır. updatePost/deletePost varsayılanları hata verir. Başarı ancak sunucu onayından sonra snapshot + notifyListeners ile yayınlanır; başarısız işlemde form ve son sağlam veri korunur.

## Mevcut durum ve güvenlik kontrolleri

PostStatus published, booked ve unknown içerir. Booked kaydı kişisel geçmişte kalır, keşifte gösterilmez ve düzenlenemez/silinemez. Zamanın geçmesi dersin tamamlandığını kanıtlamaz. Tamamlanma Application.completionStatus üzerinden değerlendirilir.

Bitiş anı dahil geçmiş ilanlar salt okunurdur. requireMutablePost, güncel kayıt üzerinde kimlik, published durumu ve bitiş zamanını kontrol eder; payload’daki yeni tarih eski kaydı yeniden düzenlenebilir yapmaz. Kabul commit’i başvuru ve ilan snapshot’larını aynı yerel işlemde tutarlı günceller. Mock silme gerçek DB davranışı değildir.

applicationCount yoksa sayı gösterilmez; mevcut backend pendingRequestCount değerinin eşlemesi açıkça yapılmalıdır. Gerçek sunucunun sahiplik, durum, zaman ve transaction kontrolleri istemci kontrollerinden bağımsızdır. Bakiye/token transferi Flutter’da yapılmaz.
