# profile

Sorumluluk: Kullanıcı profili.

screens/profile_screen.dart mevcut UserProfile verisini gösteren ana ekrandır. Normal telefonlarda ana seçenekler tek ekrana sığar; içerik, küçük ekranlarda ve büyük yazıda doğal yüksekliğiyle kaydırılabilir. Ortak HomeBottomNavigation aynen kullanılır.

widgets/profile_widgets.dart kimlik, istatistik ve seçenek kartlarını içerir. Puan, değerlendirme sayısı ve token bakiyesi için veri kaynağı bulunmadığından sayısal değer uydurulmaz; mevcut olmadıkları belirtilir.

models/profile_destination.dart alt sayfalar için tipli hedefleri tanımlar. ProfileScreen.onOpenSection gelecekte bu sayfalara bağlanabilir; şimdilik bilgilendirme gösterilir. Çıkış Yap oturumu değiştirmez. Profil düzenleme, token yükleme, aktiviteler, ayarlar ve destek alt ekranları bu kapsamda uygulanmamıştır.

navigation/profile_navigation.dart aynı kullanıcı ve PostsRepository örneğini kullanır; kaynak ekranı canlı tutar. Kaynak sekmeye dönüş mevcut rotayı açığa çıkarır, böylece arama kriterleri ve form taslakları korunur. Ana Sayfa'nın onDestination callback'i varsa mevcut önceliği korunur.

API, kalıcı kayıt, bakiye transferi veya kimlik doğrulama işlemi eklenmemiştir.

İlk sürüm yalnızca Sivas Cumhuriyet Üniversitesi içindir. Profil kartında isim ve bölüm UserProfile verisinden, üniversite adı core/constants/app_university.dart ortak sabitinden gelir. Backend kullanıcı kaydında üniversite alanı beklenmez. UserProfile.university, Ana Sayfa ve İlan Oluştur görünümünü korumak için isteğe bağlı eski gösterim alanı olarak tutulur; verilmezse ortak sabiti kullanır. Profil kartı bu eski değeri dikkate almaz. Kayıt formunda üniversite seçimi yoktur; profil düzenleme alt ekranı henüz uygulanmamıştır.
