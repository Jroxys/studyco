# StudyCo Ana Sayfa MVP

## Tasarım

`C:\StudyCoProject\design_references\studyco_home.png` doğrudan incelendi. Üst marka/kampüs alanı, mesaj ve bildirim rozetleri, kullanıcı özeti, öneriler başlığı, iki sütunlu kartlar, sağ alttaki AI Asistan ve alt navigasyon referanstan uyarlandı. Gerçek `assets/images/studyco_logo.png` kullanılır.

Renkler mevcut temadan türetilir; ayrı palet ve bağımlılık eklenmez. Kahve etiketi referanstaki altın tonunun yerine temanın sıcak container tonunu kullanır. Platformun sistem çubuğu, font ve ikonları referansla birebir aynı değildir. Uzun metinlerde kontrollü satır sayısı ve üç nokta kullanılır; Tooltip tam metni verir. Telefon genişliği ve yazı ölçeğine göre kart yüksekliği uyarlanır, iki sütun korunur. Küçük ekranlarda ikinci satırı görmek için dikey kaydırma gerekir. AI alanı grid viewport'unun dışındadır; son kartı kapatmaz.

## Android Studio önizleme

Device Manager ile emülatörü açın. Run > Edit Configurations > Flutter > Additional run args:

```text
--dart-define=HOME_PREVIEW=true
```

Debug ile çalıştırın. Normal giriş ekranı için argümanı kaldırın. Seçenek değişikliklerinde uygulamayı durdurup yeniden çalıştırın; hot reload yeterli değildir.

Terminal:

```sh
flutter run --debug -d emulator-5554 --dart-define=HOME_PREVIEW=true
```

Cihaz kimliği `flutter devices` ile kontrol edilir. `HOME_PREVIEW` yalnızca `kDebugMode` altında etkindir; profile/release sürümlerinde Ana Sayfa önizlemesi açılmaz. `AUTH_PREVIEW=forgot|verify|reset` birlikte verilirse geçerli auth önizlemesi önceliklidir. Auth ekranlarına veya login başarı akışına müdahale edilmez. Android geri tuşu önizlemeden giriş ekranına döner. Bu önizleme oturum oluşturmaz; kullanıcı, ilanlar ve rozetler örnek veridir.

## İşlevler

İlk sürüm yalnızca Özel Ders ilanlarını destekler. `PostType` altyapısı korunur; tek seçenek `tutoring` olur. Ana Sayfa tüm ilanları repository’den alır, yalnızca Özel Ders ilanlarını seçer, `createdAt` azalan ve eşitlikte `id` artan sıralamayla ilk 6 ilanı gösterir. `startsAt` dersin başlangıcıdır. Repository bütün ilanları korur; gelecekte Arama aynı kaynağı kullanabilir. Kahve ve ücretsiz teklifleri korunur; gerçek ödeme veya token transferi yoktur.

- Ana Sayfa kategori çipi veya bölüm/kategori filtresi içermez. Açıklama En yeni özel ders ilanları şeklindedir; kartlar başlık alanının hemen ardından gelir. Üstteki Tümü bağlantısı ve alt menüdeki Ara aynı `_destination('Ara')` akışını kullanır. `onDestination` verilmemişse mevcut henüz kullanılamıyor mesajı gösterilir; yeni Arama ekranı oluşturulmaz.
- Kaydet ikonu session içindeki repository durumunu değiştirir. Uygulama/önizleme yeniden oluşturulduğunda kaybolur; kalıcı kayıt iddiası yoktur.
- `SliverGrid.builder` tek PostCard üzerinden dinamik liste üretir. Repository'nin `addPost` çağrısı dinleyicilere bildirilir; aynı instance'ı kullanan Ana Sayfa otomatik güncellenir. İlan Oluştur ekranı önizlemedeki alt navigasyondan aynı repository ile açılır; başarılı ekleme sonrası mevcut Ana Sayfa'ya dönülür; liste repository bildirimiyle otomatik yenilenir. Ayrıntılar: [İlan Oluştur](create_post.md).
- `onOpenPost(Post)` ve `onDestination(String)` callback'leri app katmanından gerçek rotalara bağlanabilir. Şimdilik detay, mesaj, bildirim, profil, arama ve AI işlemleri henüz kullanılamadığını bildirir.
- Yükleniyor, hata/yeniden dene ve boş liste durumları vardır. Gerçek REST çağrısı veya kullanıcı doğrulaması yapılmaz.

## Katmanlar ve backend bağlantısı

- `features/posts/models/post.dart`: immutable ilan modeli ve sunum etiketleri.
- `features/posts/domain/posts_repository.dart`: paylaşılabilir veri kaynağı arayüzü; refresh, posts, addPost, isSaved, toggleSaved ve değişiklik bildirimi.
- `features/posts/data/in_memory_posts_repository.dart`: yalnızca bellek implementasyonu.
- `features/posts/data/sample_posts.dart`: dört sabit tasarım örneği; güncel canlı ilanlar değildir.
- `features/posts/widgets/post_card.dart`: yeniden kullanılabilir kart; yönlendirme ve kayıt işlemleri callback olarak alınır.
- `features/profile/models/user_profile.dart`: kullanıcı özeti modeli.
- `features/home/widgets/`: üst alan ve alt navigasyon.
- `features/home/screens/home_screen.dart`: UI durumu, yükleme ve hatalar, dinamik grid.
- `app/debug/home_preview_data.dart`: örnek kullanıcı ve rozet değerleri.
- `app/debug/home_preview.dart`: repository yaşam döngüsü ve örnek ekranın composition root'u.
- `app/app.dart`: yalnızca debug başlangıç seçimi; auth önizlemesi önceliklidir.

API hazır olduğunda `features/posts/data/` altında PostsRepository implementasyonu ve API DTO/JSON eşlemeleri eklenir. `refresh`, `addPost`, `toggleSaved` gerçek endpoint'lere bağlanır; her başarılı değişiklikte dinleyicilere güncel snapshot bildirilir. Hata/oturum, zaman dilimi, sayfalama, kaydetme yetkisi ve veri eşleme sözleşmesi sunucu ile netleştirilmelidir. Sample data yerine gerçek kullanıcı profili ve okunmamış sayıları app katmanında sağlanır; gerçek giriş sonrası yönlendirme ayrıca bağlanır. HomeScreen ve PostCard HTTP ayrıntısı bilmez.

Gelecekte İlan Oluştur ve Ana Sayfa'ya aynı repository instance'ı app katmanından verilmelidir. Başarısız API isteği başarı gibi gösterilmemeli; arayüzdeki kayıt durumu yalnızca doğrulanmış sonuçla güncellenmelidir.

Önizlemeyi kaldırmak için `app/debug/home_preview*.dart` dosyalarını ve app.dart içindeki HomePreview import/alternatifini kaldırın. Kullanıcıya debug düğmeleri sunulmaz.

## Kontroller

```sh
flutter analyze
flutter test
flutter test test/home_preview_test.dart --dart-define=HOME_PREVIEW=true
flutter test test/home_preview_test.dart --dart-define=HOME_PREVIEW=true --dart-define=AUTH_PREVIEW=verify
```

Testler: çiplerin bulunmaması, tüm bölümlerden en yeni 6 ilan, Tümü/Ara hedef eşitliği, bellek içi ekleme ve bildirimi, kaydet/kaldır, detay callback'i, boş liste, hazır olmayan hedefler, 320x568 ekran ve iki kat yazı ölçeğinde uzun metinler, AI alanının grid üzerinde olmaması ve debug başlangıç/geri dönüş önceliği.
