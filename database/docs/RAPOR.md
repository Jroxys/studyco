# Uygulanan kararlar, varsayımlar ve açık noktalar

## 1. Test sonuçları (dürüst özet)

Çalıştırılan ortamlar: **PostgreSQL 16.15 (Linux, geçici sunucu)** ve **PostgreSQL 18.4 (macOS, geliştirici makinesi, 3 Kasım 2026)**. İkisinde de tüm testler geçti.

| Grup | Sonuç |
|---|---|
| 30 birim/kısıt/iş kuralı testi (`tests/tests.sql`) | 30 geçti, 0 kaldı |
| Eşzamanlılık C1-C5, her biri 10 tur, gerçek paralel oturumlar | Hepsi geçti, deadlock yok |
| Mutasyon kontrolü: kilitleri kaldırılmış kopya | Eşzamanlılık testi **başarısız oldu** (deadlock ve beklenmeyen hatalar yakalandı). Test gerçekten hata yakalayabiliyor |
| `setup_db.sh` ilk ve ikinci çalıştırma, `migrate.sh down 5` + tekrar `up`, `load_catalog.sql` | Doğrulandı |

Şartname test numaraları ve karşılıkları:

| Şartname testi | Karşılık |
|---|---|
| 1, 2 | `t01` |
| 3 | `t02` |
| 4 | `t03` |
| 5, 6 | `t04` |
| 7 | `t05` |
| 8 (eşzamanlı dahil) | `t06`, `C1` |
| 9 | `t07` |
| 10 | `t08` |
| 11 | `t09` |
| 12 | `t10`, `t11`, `t12`, `C2`, `C3` |
| 13 | `t13` |
| 14 | `t15` |
| 15 | `t16` (yazma DB'de zorlanır; **okuma** yetkisi backend işidir, `is_conversation_participant` yardımcısı hazır) |
| 16 | `t17`, `C4` |
| 17 | `t17`, `t19`, `t20`, `t21` (anlamı **sizin kararınızla değişti**, bkz. 2) |
| 18 | `t22`, `C5` |
| 19, 20 | `t24` |
| 21 | `t25`, `t30` ve `v_integrity_violations` çoğu testin sonunda kontrol edilir |

## 2. Bu görüşmede verdiğiniz kararlar ve uygulanışı

| Karar | Uygulama |
|---|---|
| G1, G2, G3 düzeltilsin | `accepted_slots` + EXCLUDE (rolden bağımsız çakışma); kabul edilmiş ilanın saati/fiyatı değişmez; `EXPIRED` türetilir |
| Onay yalnızca ders bittikten sonra; bitişten 24 saat sonrası geçersiz | Pencere `[bitiş, bitiş+24sa]`; fonksiyon **ve** DB CHECK'i (`lr_confirm_window_ck`) zorlar |
| Süre dolunca öğretmen **veya** öğrenci onaylamışsa token öğretmene gider | `finalize_expired_request`; dayanak `settlement_basis`'e yazılır |
| Kimse onaylamazsa | `MANUAL_REVIEW`, token bloke (şartnamedeki 48 saat yerine 24 saat) |
| G6: bonus e-posta onayı beklemeden | Kayıtta cüzdan + 10 token (tek bonus DB'de garanti) |
| G7-G15 önerdiğim gibi | HMAC notu + `attempt_count`; sıfır ledger yok; `UNIQUE` idempotency; wallet_id sıralı kilit; durum CHECK'leri; trigger'lar; append-only defter; `anonymize_user`; PG13+, citext, btree_gist, düz SQL up/down |
| O-01, O-02, G1/G2, G4 "evet" | Uygulandı |
| O-11: reddedilen talebe tekrar teklif **yok** | `UNIQUE(listing_id, student_id)` (kabul edilmeyen/iptal edilen talepler için de geçerli) |
| Kendi makinemde çalışsın | Betikler hazır; ayrıntı `README.md` |

## 3. Şartnamedeki çelişkilerin çözümü

C1 (hash UNIQUE olmaz) çözüldü. C2 (tek onay MANUAL_REVIEW değildir) kararınızla netleşti. C3: `AUTO_CANCELLED` sebepleri
`TIME_CONFLICT`, `LISTING_ALREADY_BOOKED`, `LISTING_EXPIRED`. C4: `MANUAL_ADJUSTMENT` tipi eklenmedi (admin akışı belli olunca eklenir).
C5: "kendine talep" kuralı `student_id <> teacher_id` olarak talep **gönderme** tarafına kondu. C6: ER diyagramı düzeltildi.

## 4. Sizin onayınıza sunmadan verdiğim kararlar (değiştirmek isterseniz söyleyin)

1. **Telefon** `NOT NULL`, `UNIQUE`, E.164 (`+90...`). "Seçtiğim yere kadar evet" cevabınızı O-06 için de evet saydım.
2. **Kabul sınırı ders BAŞLANGICI.** İlk analizde `end_at` demiştim. Ders başladıktan sonra token bloke edip kabul etmek anlamsız olduğu için `start_at` yaptım.
3. **O-09:** İlana ilk talep geldiği an ders/yer/saat/fiyat değişmez (konu ve açıklama değişir). Aksi halde öğrenci görmediği saate/fiyata bağlanabilirdi.
4. `completion_status`, talep **kabul edildiği anda** `AWAITING_CONFIRMATION` olur; onaylar ancak ders bitince alınır.
5. G1'in doğal sonucu olarak, bir ders kabul edilince iki tarafın (hangi rolde olursa olsun) çakışan **diğer bekleyen** talepleri de `TIME_CONFLICT` ile kapanır. Şartname yalnızca öğrencinin bekleyenlerini sayıyordu.
6. `settlement_basis` sütunu eklendi (tek onayla otomatik aktarımın denetim izi).
7. Aynı öğretmenin birbirini kesen iki ilanı **yayınlanabilir**; yalnızca biri kabul edilebilir (ikincisi `TIME_CONFLICT` alır). Daha katı kural (yayınlamayı da engelleme) `listings` üzerine tek bir EXCLUDE ile eklenebilir.
8. Onay tekrarı (aynı kişi iki kez) hata değil, sessizce aynı sonuçtur.

## 5. Hâlâ açık olan ve benim doldurmadığım noktalar

| ID | Durum |
|---|---|
| O-03 / O-10 | `MANUAL_REVIEW` nasıl çözülecek: admin akışı yok. Durum şu an **terminal** |
| O-04 | **Gerçek ders ve kafe listesi yok.** Aramalarım resmi bir kaynak bulamadı. CSV şablonları boş (`seeds/data/`); doğrulanmış veriyle `seeds/load_catalog.sql` ile yüklenir |
| O-05 | OTP süresi ve deneme sınırı: fonksiyonlar bunları **parametre** olarak ister, ben sayı seçmedim |
| O-07 | ORM seçilmedi. Öneri: Node `pg` (parametreli sorgu) ile bu SQL fonksiyonlarını çağırmak. ORM'ler EXCLUDE, trigger ve partial index'i modelleyemez; ORM kullanılacaksa yalnızca okuma/CRUD için, kritik akışlar bu fonksiyonlar üzerinden yürümeli |
| O-08 | Üniversite e-posta alan adı zorunluluğu yok. Hoş geldin bonusu doğrulamasız olduğundan çoklu hesapla token biriktirme **mümkün** (kararınız); telefon UNIQUE olması bunu bir ölçüde zorlaştırır |
| — | Uygulama için sınırlı DB rolü ve yetkileri tanımlanmadı (şartname §9). Deploy aşamasında yazılmalı |
| — | Mesaj ve değerlendirme **okuma** yetkisi backend'de; DB yalnızca yazmayı zorlar |
| — | Zamanlanmış işler (`process_expired_confirmations`, `expire_stale_requests`) henüz zamanlanmadı; backend veya `pg_cron` ile çağrılmalı |
| — | Kullanıcı anonimleştirme **politikası** (ne zaman çağrılacağı) hukuki karar; yalnızca mekanizma var |
| — | Kimlik tipi UUID v4. v7 (zaman sıralı) PG 18'den sonra yerleşik; ihtiyaç olursa değiştirilebilir |
