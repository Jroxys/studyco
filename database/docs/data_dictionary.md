# Veri sözlüğü ve backend sözleşmesi

Tip seçimleri: `uuid` (tahmin edilemez, dağıtık üretilebilir; `gen_random_uuid()` PG13+), `timestamptz` (saat dilimi
karışıklığı yok; Europe/Istanbul gösterimi uygulamada), `smallint` (0-3 fiyat, 1-5 puan), `integer` (bakiye),
`citext` (e-posta), `tstzrange` (zaman aralığı, EXCLUDE için). Şema ayrıntısı için `migrations/up/*.sql`
okunmalıdır; her kısıtın yanında neden yazılıdır. Burada özet ve backend'in bilmesi gerekenler var.

## Tablolar

| Tablo | Amaç | Öne çıkan kısıtlar |
|---|---|---|
| `departments` | Bölüm kataloğu | `name` UNIQUE. "Diğer" seed edilmez |
| `users` | Hesap (rol yok) | `email` citext UNIQUE; `phone` NOT NULL UNIQUE, E.164; `anonymized_at` |
| `courses` | Bölüme bağlı ders | `UNIQUE(department_id, course_name)` |
| `locations` | Kampüs kafeleri | `name` UNIQUE; lat/lng ya ikisi dolu ya ikisi boş. Uygulama rolüne INSERT verilmemeli |
| `auth_tokens` | E-posta doğrulama / parola sıfırlama | `token_hash` UNIQUE **değil**; kullanıcı+amaç başına tek aktif kod; `attempt_count` |
| `listings` | Tek seanslık ilan | `end_at > start_at`; fiyat 0-3; `time_range` türetilmiş; durum PUBLISHED/BOOKED/COMPLETED |
| `lesson_requests` | Talep + tamamlanma | `UNIQUE(listing_id, student_id)`; kabul edilen tek (partial unique); durum şekli ve onay penceresi için CHECK kısıtları (`lr_*_ck`) |
| `accepted_slots` | Kabul edilmiş derslerin kullanıcı bazlı zaman dilimi | `EXCLUDE (user_id =, time_range &&)` |
| `wallets` | Kullanıcı başına tek cüzdan | bakiyeler >= 0; doğrudan UPDATE yasak |
| `wallet_transactions` | Token defteri (append-only) | tip başına şekil CHECK'i; idempotency anahtarı; talep+cüzdan+tip tek |
| `conversations` | Kabul edilen talebe bağlı oda | `lesson_request_id` UNIQUE; yalnızca ACCEPTED |
| `messages` | Metin mesajı | gönderen katılımcı olmalı (trigger); gövde boş olamaz |
| `reviews` | Karşılıklı puan | 1-5; talep başına değerlendiren başına bir; yalnızca COMPLETED |

## İndeksler (neden bunlar, neden yalnızca bunlar?)

| İndeks | Hizmet ettiği sorgu |
|---|---|
| `listings(status, start_at)` | Açık ilanları tarihe göre listele |
| `listings(teacher_id)` | Öğretmenin ilanları |
| `lesson_requests(student_id, request_status)` / `(teacher_id, request_status)` | "Taleplerim", "bana gelenler", çakışma iptali |
| `lesson_requests(confirmation_deadline_at) WHERE AWAITING_CONFIRMATION` | Süresi dolan onaylar işi |
| `lesson_requests(lower(time_range)) WHERE PENDING` | Tarihi geçen bekleyenler işi |
| `messages(conversation_id, sent_at)` | Sohbet ekranı |
| `reviews(reviewee_id)` | Kullanıcının puanları |
| `wallet_transactions(wallet_id, created_at)` | Cüzdan hareket geçmişi |

Diğer ihtiyaçlar UNIQUE/PK/EXCLUDE kısıtlarının kendi indeksleriyle karşılanır. Gerçek yük görülmeden
daha fazla indeks eklenmedi.

## Backend'in çağıracağı fonksiyonlar

Hepsi tek transaction'da çalışır. Hata = `RAISE EXCEPTION '<KOD>'` (SQLSTATE `P0001`); backend `error.message` içindeki
kodu okur. `p_now` yalnızca test içindir; **istemciden gelen bir değerle ASLA doldurulmaz**.

| Fonksiyon | İş |
|---|---|
| `accept_lesson_request(request, teacher)` | Kabul + HOLD + konuşma + otomatik iptaller |
| `reject_lesson_request(request, teacher)` | Red (token hareketi yok) |
| `confirm_lesson(request, user)` | Ders sonrası onay; ikinci onayda otomatik aktarım |
| `process_expired_confirmations()` | **Zamanlanmış iş** (öneri: 5-15 dk). Süresi dolan onayları sonuçlandırır |
| `expire_stale_requests()` | **Zamanlanmış iş**. Ders başlamış ama PENDING kalanları kapatır (doğruluk buna bağlı değil) |
| `issue_auth_token(user, purpose, hash, ttl)` / `verify_auth_token(user, purpose, hash, max_attempts)` | Doğrulama kodları. `INVALID` dönen çağrıyı **commit edin** |
| `anonymize_user(user)` | KVKK anonimleştirme (aktif yükümlülük varsa reddeder) |
| `is_conversation_participant(user, conversation)` | Mesaj **okuma** yetkisi için yardımcı (yazma DB'de zorlanır) |
| `finalize_expired_request`, `settle_request_internal` | İç fonksiyonlar; doğrudan çağırmayın |
| görünüm `v_integrity_violations` | Boş dönmeli; izleme/alarm için kullanın |
| görünüm `v_listing_state` | `effective_status` (EXPIRED türetilmiş) |

## Hata kodları

| Kod | Anlamı | Önerilen HTTP |
|---|---|---|
| `REQUEST_NOT_FOUND`, `USER_NOT_FOUND` | Kayıt yok | 404 |
| `NOT_LISTING_OWNER`, `NOT_A_PARTICIPANT` | Yetkisiz | 403 |
| `REQUEST_NOT_PENDING`, `REQUEST_NOT_ACCEPTED`, `LISTING_NOT_PUBLISHED`, `LISTING_ALREADY_BOOKED`, `TIME_CONFLICT`, `REQUEST_NOT_SETTLEABLE`, `USER_HAS_ACTIVE_OBLIGATIONS` | Durum çakışması | 409 |
| `LISTING_EXPIRED`, `LISTING_START_IN_PAST` | Zaman geçmiş | 409 / 422 |
| `INSUFFICIENT_BALANCE` | Bakiye yetersiz | 402 veya 409 |
| `CONFIRMATION_TOO_EARLY`, `CONFIRMATION_WINDOW_CLOSED` | Onay penceresi dışında | 409 |
| `COURSE_DEPARTMENT_MISMATCH`, `COURSE_INACTIVE`, `LOCATION_INACTIVE_OR_UNKNOWN`, `TEACHER_ANONYMIZED` | İlan doğrulaması | 422 |
| `LISTING_CORE_FIELDS_LOCKED`, `LISTING_TEACHER_IMMUTABLE` | İlan düzenleme yasağı | 409 |
| `REVIEW_REQUIRES_COMPLETED_LESSON`, `REVIEW_PARTIES_MISMATCH` | Değerlendirme kuralı | 409 / 403 |
| `CONVERSATION_REQUIRES_ACCEPTED_REQUEST` | Konuşma kuralı | 409 |
| `LEDGER_IS_APPEND_ONLY`, `WALLET_*` | Programlama hatası (savunma hattı) | 500 |
| kısıt adları (`lr_one_per_student_listing_uq`, `lr_not_self_ck`, `users_email_uq`...) | PG kısıt ihlali; `error.constraint` ile eşleyin | 409 / 422 |

## Kilit sırası (deadlock'a karşı)

users (id sırasıyla, yalnızca kabul) → listings → lesson_requests → wallets (wallet_id sırasıyla).
Tüm fonksiyonlar aynı sırayı izler. Backend, bu fonksiyonlar dışında aynı tablolara elle kilit alıyorsa aynı sırayı korumalıdır.
