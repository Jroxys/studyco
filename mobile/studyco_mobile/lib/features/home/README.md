# home

Ana Sayfa: screens/home_screen.dart. Modelden beslenen üst alan ve alt navigasyon widgets/ altındadır. Ana Sayfa kategori çipi içermez; tüm Özel Ders ilanlarını oluşturulma zamanına göre sıralayıp ilk 6 ilanı gösterir. Filtreleme search/ altında yapılır. Üstteki Tümü bağlantısı ve alt menüdeki Ara aynı repository ile Arama ekranını açar; onDestination verilirse mevcut callback önceliklidir.

HomeScreen, PostsRepository ve UserProfile alır. Örnek veri veya repository implementasyonu UI içinde oluşturulmaz; app/debug/ bu bağımlılıkları önizleme için birleştirir. Gerçek rotalar callback ile app katmanından bağlanabilir.


Önizleme ve entegrasyon notları: ../../../docs/home.md
