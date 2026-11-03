# StudyCo ER diyagramı (düzeltilmiş)

Şartnamedeki taslaktan farklar: (1) `users` ile `lesson_requests` ve `reviews` arasında **iki ayrı** ilişki var
(öğrenci/öğretmen, değerlendiren/değerlendirilen); (2) yeni tablo `accepted_slots` (çakışma kısıtı için);
(3) `lesson_requests.teacher_id` ve `time_range` ilandan kopyalanan değiştirilemez snapshot alanlarıdır.

```mermaid
erDiagram
    DEPARTMENTS ||--o{ USERS : "bölümü"
    DEPARTMENTS ||--o{ COURSES : "içerir"
    USERS ||--|| WALLETS : "sahibi"
    USERS ||--o{ AUTH_TOKENS : "doğrulama kodu"
    USERS ||--o{ LISTINGS : "öğretmen olarak açar"
    COURSES ||--o{ LISTINGS : "dersi"
    LOCATIONS ||--o{ LISTINGS : "buluşma yeri"
    LISTINGS ||--o{ LESSON_REQUESTS : "talep alır"
    USERS ||--o{ LESSON_REQUESTS : "öğrenci olarak gönderir"
    USERS ||--o{ LESSON_REQUESTS : "öğretmen (snapshot)"
    LESSON_REQUESTS ||--o| CONVERSATIONS : "kabulde açılır"
    CONVERSATIONS ||--o{ MESSAGES : "içerir"
    USERS ||--o{ MESSAGES : "gönderir"
    WALLETS ||--o{ WALLET_TRANSACTIONS : "defter"
    LESSON_REQUESTS ||--o{ WALLET_TRANSACTIONS : "hold ve settlement"
    LESSON_REQUESTS ||--o{ ACCEPTED_SLOTS : "kabulde 2 satır"
    USERS ||--o{ ACCEPTED_SLOTS : "meşgul zaman dilimi"
    LESSON_REQUESTS ||--o{ REVIEWS : "en çok 2"
    USERS ||--o{ REVIEWS : "değerlendiren"
    USERS ||--o{ REVIEWS : "değerlendirilen"
```

## Durum makineleri

```mermaid
stateDiagram-v2
    direction LR
    state "request_status" as RS {
        [*] --> PENDING
        PENDING --> ACCEPTED: öğretmen kabul (HOLD)
        PENDING --> REJECTED: öğretmen red
        PENDING --> AUTO_CANCELLED: çakışma / ilan doldu / ilan tarihi geçti
    }
```

```mermaid
stateDiagram-v2
    direction LR
    [*] --> NOT_STARTED
    NOT_STARTED --> AWAITING_CONFIRMATION: talep kabul edildi
    AWAITING_CONFIRMATION --> COMPLETED: iki onay (hemen) / süre dolunca en az bir onay
    AWAITING_CONFIRMATION --> MANUAL_REVIEW: süre doldu, HİÇ onay yok
```

Onay penceresi: `[ders bitişi, ders bitişi + 24 saat]`. Pencere dışı onay reddedilir.
Süre dolunca **en az bir** taraf onaylamışsa token öğretmene aktarılır (`settlement_basis` neyin
dayanak olduğunu kaydeder); kimse onaylamamışsa `MANUAL_REVIEW` ve token bloke kalır.
