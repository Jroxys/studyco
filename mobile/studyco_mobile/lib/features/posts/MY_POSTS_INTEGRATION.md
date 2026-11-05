# İlanlarım entegrasyonu

Mevcut kaynak yalnızca InMemoryPostsRepository: oluşturma, düzenleme ve silme oturumluk işlemlerdir; HTTP isteği veya kalıcı kayıt yapılmaz.

UserProfile.id ve Post.authorId gerçek entegrasyonda doğrulanmış kullanıcı kimliğiyle doldurulmalıdır. Kimlik yokken aynı UserProfile nesnesine bağlı oturum kimliği kullanılır. Yazar adıyla eşleme yapılmaz; authorId olmayan eski örnek ilanlar İlanlarım listesine alınmaz. Sunucu her güncelleme/silmede sahipliği ayrıca doğrulamalıdır.

Bu checkout içinde backend kodu veya güncelleme DTO sözleşmesi bulunmadığından hiçbir alan için gerçek API desteği varsayılmadı. Başlık/ders (courseId veya manuel başlık), konu, açıklama, tarih, başlangıç/bitiş zamanı ve saat dilimi, buluşma konumu (locationId), kahve/token miktarı ve ücretsiz seçeneği backend ile ayrı ayrı doğrulanmalıdır. Bölüm ve konu kategorisi düzenlemede korunur. Token cüzdanı işlemi yapılmaz.

PostsRepository.supportsFullPostEditing varsayılan olarak false; desteklenmeyen adaptörde düzenleme kaydedilmez. Yalnızca bellek kaynağı şimdilik tüm alanları destekler. Kısmi güncelleme destekleyen gerçek adaptör için alan bazında yetenekler ve salt okunur form alanları eklenmeden bu bayrak açılmamalıdır. updatePost/deletePost varsayılanları hata döndürür; uzak adaptör başarı cevabından sonra kendi snapshot'ını yenileyip notifyListeners çağırmalıdır. İstemci başarısız işlemde kaydı kaldırmaz veya formu kapatmaz.

Durum, backend durum alanı bulunmadığı için bitiş zamanından türetilir: bitiş gelecekteyse Aktif, değilse Süresi Doldu / Geçmiş İlanlar. İptal/tamamlandı durumu uydurulmaz. applicationCount null ise başvuru sayısı gösterilmez; sıfır verilirse gösterilir. Gerçek durumlar ve başvuru sayıları API eşlemesi gerektirir.

## Geçmiş ilanlarda işlem kısıtlaması

Proje dosyalarında ilan veya başvuru durum enum'u, tamamlanmayı doğrulayan veri, backend kaynak kodu ve OpenAPI sözleşmesi bulunamadı. Post modelinde yalnızca zamanlar ve isteğe bağlı applicationCount var; sayı başvuru durumu değildir. Bu nedenle yeni API alanı veya durum enum'u eklenmedi. Bitiş anı dahil geçmiş ilanlar Süresi Doldu olarak gösterilir; zamanın geçmesi Tamamlandı anlamına gelmez.

Geçmiş ilan kartları ve detayları yalnızca görüntülenir. Düzenle/sil butonları oluşturulmaz; detayda Başvur yoktur. Açık kalan düzenleme formunda kaydetme ve silme onayı sonrasında güncel repository kaydı yeniden kontrol edilir. InMemoryPostsRepository güncelleme ve silmeden önce requireMutablePost ile sahipliği ve kayıtlı bitiş zamanını doğrular. Düzenleme isteğindeki yeni tarihler eski kaydın geçmiş olmasını geçersiz kılamaz. Reddedilen işlemler snapshot'ı değiştirmez ve bildirim üretmez.

Gerçek repository adaptörü aynı kontrolü istekten önce ve gecikmeli işlerde işlem anında uygulamalıdır. Backend düzenleme, silme ve başvuru işlemlerinde kimliği, kendi kayıtlı bitiş zamanını ve mevcut gerçek durumlarını sunucu saatiyle atomik olarak doğrulamalıdır. İstemcinin buton gizlemesi veya yeni tarih gönderimi yetki sağlamaz. Sunucu ret cevabında yerel kayıt silinmemeli/güncellenmemeli; güncel snapshot yenilenmelidir.

Entegrasyonda doğrulanması gereken eksikler: gerçek ilan/başvuru durum değerleri ve izin verilen geçişler; ders tamamlanmasının güvenilir kaynağı; hangi gerçek durumların ilanı geçmiş/salt okunur yaptığı; düzenleme/silme/başvuru için sunucu kuralları; saat dilimi ve yetkili sunucu zamanı; bu işlemlerin ret/hata sözleşmesi. Tamamlandı ancak doğrulanmış tamamlanma verisi eşlendiğinde gösterilebilir. Burada backend kodu bulunmadığı için sunucu tarafı kısıtlama uygulanmadı veya uygulanmış varsayılmadı.
