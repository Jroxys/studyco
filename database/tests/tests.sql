-- Birim / kısıt / iş kuralı testleri. Her test kendi transaction'ında çalışır ve ROLLBACK edilir
-- (bkz. scripts/run_tests.sh). Başarısızlık = istisna fırlatır. Şartname test numaraları [S#] ile belirtilir.

-- [S1,S2] Kayıt, FK, e-posta büyük/küçük harf, telefon biçimi; hoş geldin bonusu (G6)
CREATE FUNCTION test.t01_user_registration() RETURNS void LANGUAGE plpgsql AS $$
DECLARE u uuid := test.mk_user(); v_email text;
BEGIN
  PERFORM test.eq((SELECT count(*) FROM users WHERE user_id = u), 1::bigint, 'kullanıcı kaydedildi [S1]');
  PERFORM test.eq(test.avail(u), 10, '10 token hoş geldin bonusu (e-posta doğrulamadan)');
  PERFORM test.eq(test.held(u), 0, 'bloke bakiye başlangıçta 0');
  PERFORM test.eq((SELECT count(*) FROM wallet_transactions wt JOIN wallets w USING (wallet_id)
                    WHERE w.user_id = u AND wt.transaction_type = 'WELCOME_BONUS'), 1::bigint,
                  'tek WELCOME_BONUS ledger satırı');
  PERFORM test.expect_error(test.raw_user_sql(gen_random_uuid(), 'x@test.local', '+905559990001'),
                            'violates foreign key constraint');
  SELECT email::text INTO v_email FROM users WHERE user_id = u;
  PERFORM test.expect_error(
    test.raw_user_sql((SELECT department_id FROM users WHERE user_id = u), upper(v_email), '+905559990002'),
    'users_email_uq');                                                                  -- [S2]
  PERFORM test.expect_error(
    test.raw_user_sql((SELECT department_id FROM users WHERE user_id = u), 'y@test.local', '0555 123'),
    'users_phone_format_ck');
  PERFORM test.integrity_ok();
END $$;

-- [S3] "Diğer" geçerli bölüm değil
CREATE FUNCTION test.t02_diger_is_not_a_department() RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  PERFORM test.eq((SELECT count(*) FROM departments WHERE name = 'Diğer'), 0::bigint, '"Diğer" seed edilmedi');
  PERFORM test.eq((SELECT count(*) FROM departments), 9::bigint, '9 bölüm seed edildi');
  PERFORM test.expect_error('SELECT test.mk_user(''Diğer'')', 'null value in column "department_id"');
END $$;

-- [S4] O-01: ilan, öğretmenin kendi bölümünün dersiyle açılır
CREATE FUNCTION test.t03_course_must_match_department() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user('Hukuk'); l uuid;
BEGIN
  l := test.mk_listing(t, test.base_time(), 60, 1);                               -- kendi bölümü: olur
  PERFORM test.expect_error(
    format('SELECT test.ins_listing(%L, %L, %L, %L, 1)', t, test.fx_course('İşletme'),
           test.base_time() + interval '1 day', test.base_time() + interval '1 day 1 hour'),
    'COURSE_DEPARTMENT_MISMATCH');
END $$;

-- [S5,S6] Zaman sırası ve fiyat kısıtı
CREATE FUNCTION test.t04_listing_time_and_price_constraints() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); c uuid := test.fx_course('Bilgisayar Mühendisliği'); b timestamptz := test.base_time();
BEGIN
  PERFORM test.expect_error(format('SELECT test.ins_listing(%L,%L,%L,%L,1)', t, c, b, b), 'listings_time_order_ck');
  PERFORM test.expect_error(format('SELECT test.ins_listing(%L,%L,%L,%L,1)', t, c, b, b - interval '1 hour'), 'listings_time_order_ck');
  PERFORM test.expect_error(format('SELECT test.ins_listing(%L,%L,%L,%L,4)', t, c, b, b + interval '1 hour'), 'listings_token_price_ck');
  PERFORM test.expect_error(format('SELECT test.ins_listing(%L,%L,%L,%L,-1)', t, c, b, b + interval '1 hour'), 'listings_token_price_ck');
  FOR p IN 0..3 LOOP
    PERFORM test.ins_listing(t, c, b + p * interval '1 day', b + p * interval '1 day' + interval '1 hour', p);
  END LOOP;
  PERFORM test.expect_error(
    format('SELECT test.ins_listing(%L,%L,%L,%L,1)', t, c, now() - interval '2 hours', now() - interval '1 hour'),
    'LISTING_START_IN_PAST');                                                          -- G3
END $$;

-- [S7] Bir ilana birden fazla PENDING talep gelebilir
CREATE FUNCTION test.t05_multiple_pending_requests() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); l uuid := test.mk_listing(t, test.base_time());
BEGIN
  PERFORM test.mk_request(l, test.mk_user());
  PERFORM test.mk_request(l, test.mk_user());
  PERFORM test.mk_request(l, test.mk_user());
  PERFORM test.eq((SELECT count(*) FROM lesson_requests WHERE listing_id = l AND request_status = 'PENDING'),
                  3::bigint, '3 bekleyen talep');
END $$;

-- [S8] Bir ilan için iki ACCEPTED talep olamaz (fonksiyon yolu + DOĞRUDAN UPDATE yolu)
CREATE FUNCTION test.t06_one_accepted_per_listing() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); l uuid := test.mk_listing(t, test.base_time());
        r1 uuid := test.mk_request(l, test.mk_user()); r2 uuid := test.mk_request(l, test.mk_user());
        t2 uuid := test.mk_user(); l2 uuid := test.mk_listing(t2, test.base_time() + interval '2 days');
        r3 uuid := test.mk_request(l2, test.mk_user()); r4 uuid := test.mk_request(l2, test.mk_user());
BEGIN
  PERFORM test.accept(r1);
  PERFORM test.expect_error(format('SELECT test.accept(%L)', r2), 'REQUEST_NOT_PENDING');   -- O-02: r2 artık kapalı
  PERFORM test.eq(test.req_status(r2), 'AUTO_CANCELLED', 'O-02: diğer talep otomatik iptal');
  PERFORM test.eq((SELECT auto_cancel_reason FROM lesson_requests WHERE request_id = r2),
                  'LISTING_ALREADY_BOOKED', 'O-02: sebep LISTING_ALREADY_BOOKED');
  -- fonksiyonu atlayan doğrudan UPDATE ile ikinci kabul:
  PERFORM test.raw_accept(r3);
  PERFORM test.expect_error(format('SELECT test.raw_accept(%L)', r4), 'lr_one_accepted_per_listing_uq');
END $$;

-- [S9] Kabul: bakiye düşer, bloke artar, ledger satırı, konuşma, ilan BOOKED; yetki ve tekrar
CREATE FUNCTION test.t07_accept_creates_hold() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user();
        l uuid := test.mk_listing(t, test.base_time(), 60, 2); r uuid := test.mk_request(l, s);
BEGIN
  PERFORM test.expect_error(format('SELECT accept_lesson_request(%L, %L)', r, s), 'NOT_LISTING_OWNER');
  PERFORM test.accept(r);
  PERFORM test.eq(test.avail(s), 8, 'available 10-2');
  PERFORM test.eq(test.held(s), 2, 'held +2');
  PERFORM test.eq(test.ledger_rows(r, 'HOLD'), 1::bigint, 'tek HOLD satırı');
  PERFORM test.eq(test.req_status(r), 'ACCEPTED', 'ACCEPTED');
  PERFORM test.eq(test.compl_status(r), 'AWAITING_CONFIRMATION', 'AWAITING_CONFIRMATION');
  PERFORM test.eq((SELECT agreed_token_amount FROM lesson_requests WHERE request_id = r), 2::smallint, 'fiyat snapshot');
  PERFORM test.eq((SELECT status FROM listings WHERE listing_id = l), 'BOOKED', 'ilan BOOKED');
  PERFORM test.eq((SELECT count(*) FROM conversations WHERE lesson_request_id = r), 1::bigint, 'konuşma açıldı');
  PERFORM test.eq((SELECT confirmation_deadline_at FROM lesson_requests WHERE request_id = r),
                  test.lesson_end(r) + interval '24 hours', 'onay süresi = bitiş + 24 saat');
  PERFORM test.expect_error(format('SELECT test.accept(%L)', r), 'REQUEST_NOT_PENDING');   -- ikinci kabul yok
  PERFORM test.integrity_ok();
END $$;

-- [S10] Yetersiz bakiye: kısmi değişiklik KALMAZ
CREATE FUNCTION test.t08_insufficient_balance_is_atomic() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user(); b timestamptz := test.base_time(); l uuid; r uuid; l4 uuid; r4 uuid;
BEGIN
  FOR i IN 1..3 LOOP                                    -- 3 x 3 = 9 token bloke -> 1 kalır
    l := test.mk_listing(t, b + i * interval '1 day', 60, 3);
    r := test.mk_request(l, s);
    PERFORM test.accept(r);
  END LOOP;
  PERFORM test.eq(test.avail(s), 1, 'kalan 1 token');
  l4 := test.mk_listing(t, b + interval '4 days', 60, 2);
  r4 := test.mk_request(l4, s);
  PERFORM test.expect_error(format('SELECT test.accept(%L)', r4), 'INSUFFICIENT_BALANCE');
  PERFORM test.eq(test.req_status(r4), 'PENDING', 'talep PENDING kaldı');
  PERFORM test.eq((SELECT status FROM listings WHERE listing_id = l4), 'PUBLISHED', 'ilan PUBLISHED kaldı');
  PERFORM test.eq(test.ledger_rows(r4), 0::bigint, 'ledger satırı yok');
  PERFORM test.eq((SELECT count(*) FROM conversations WHERE lesson_request_id = r4), 0::bigint, 'konuşma yok');
  PERFORM test.eq(test.avail(s), 1, 'bakiye değişmedi');
  PERFORM test.eq(test.held(s), 9, 'bloke değişmedi');
  PERFORM test.integrity_ok();
END $$;

-- [S11] Çakışan PENDING talepler otomatik iptal; bitişik olan etkilenmez
CREATE FUNCTION test.t09_overlapping_pending_auto_cancelled() RETURNS void LANGUAGE plpgsql AS $$
DECLARE s uuid := test.mk_user(); b timestamptz := test.base_time() + interval '1 day';
        lx uuid := test.mk_listing(test.mk_user(), b, 60);
        ly uuid := test.mk_listing(test.mk_user(), b + interval '30 minutes', 60);   -- çakışır
        lz uuid := test.mk_listing(test.mk_user(), b + interval '60 minutes', 60);   -- bitişik: çakışmaz
        rx uuid; ry uuid; rz uuid;
BEGIN
  rx := test.mk_request(lx, s); ry := test.mk_request(ly, s); rz := test.mk_request(lz, s);
  PERFORM test.accept(rx);
  PERFORM test.eq(test.req_status(ry), 'AUTO_CANCELLED', 'çakışan talep iptal');
  PERFORM test.eq((SELECT auto_cancel_reason FROM lesson_requests WHERE request_id = ry), 'TIME_CONFLICT', 'sebep TIME_CONFLICT');
  PERFORM test.eq(test.ledger_rows(ry), 0::bigint, 'iptal edilen talepte ledger yok');
  PERFORM test.eq(test.req_status(rz), 'PENDING', 'bitişik talep (15:00 = 15:00) çakışmaz [S7 spec 3.4.7]');
  PERFORM test.integrity_ok();
END $$;

-- [S12] Zaten kabul edilmiş aralıkla çakışan talep kabul edilemez
CREATE FUNCTION test.t10_conflict_with_accepted_lesson() RETURNS void LANGUAGE plpgsql AS $$
DECLARE s uuid := test.mk_user(); t4 uuid := test.mk_user(); b timestamptz := test.base_time() + interval '1 day';
        rx uuid := test.mk_request(test.mk_listing(test.mk_user(), b, 60), s); rw uuid;
BEGIN
  PERFORM test.accept(rx);
  rw := test.mk_request(test.mk_listing(t4, b + interval '15 minutes', 30), s);    -- gönderme serbest
  PERFORM test.expect_error(format('SELECT test.accept(%L)', rw), 'TIME_CONFLICT');
  PERFORM test.eq(test.req_status(rw), 'PENDING', 'reddedilen kabulde talep PENDING kalır');
  PERFORM test.eq(test.ledger_rows(rw), 0::bigint, 'ledger yok');
END $$;

-- G1: çakışma ROLDEN BAĞIMSIZ (öğretmen+öğrenci)
CREATE FUNCTION test.t11_conflict_is_role_agnostic() RETURNS void LANGUAGE plpgsql AS $$
DECLARE u uuid := test.mk_user(); s1 uuid := test.mk_user(); t2 uuid := test.mk_user(); b timestamptz := test.base_time() + interval '2 days';
        la uuid := test.mk_listing(u, b, 60);                         -- U öğretmen
        lb uuid := test.mk_listing(t2, b + interval '30 minutes', 60);-- U öğrenci olarak buna talep eder
        ra uuid := test.mk_request(la, s1); rb uuid := test.mk_request(lb, u);
        lb2 uuid; rb2 uuid;
        u2 uuid := test.mk_user(); t5 uuid := test.mk_user(); s6 uuid := test.mk_user(); c timestamptz := test.base_time() + interval '3 days';
        rc uuid := test.mk_request(test.mk_listing(t5, c, 60), u2); ld uuid; rd uuid;
BEGIN
  PERFORM test.accept(ra);                                       -- U öğretmen olarak kabul etti
  PERFORM test.eq(test.req_status(rb), 'AUTO_CANCELLED', 'U nin öğrenci olarak bekleyen çakışan talebi iptal');
  lb2 := test.mk_listing(t2, b + interval '45 minutes', 30);
  rb2 := test.mk_request(lb2, u);                                -- sonradan gönderilen
  PERFORM test.expect_error(format('SELECT test.accept(%L)', rb2), 'TIME_CONFLICT');
  -- tersi: önce öğrenci olarak kabul edilir, sonra öğretmen olarak çakışan ilan
  PERFORM test.accept(rc);
  ld := test.mk_listing(u2, c + interval '30 minutes', 60);
  rd := test.mk_request(ld, s6);
  PERFORM test.expect_error(format('SELECT test.accept(%L)', rd), 'TIME_CONFLICT');
  PERFORM test.integrity_ok();
END $$;

-- G2: Kod atlanırsa bile veritabanı çakışmayı reddeder (EXCLUDE kısıtı)
CREATE FUNCTION test.t12_exclude_constraint_backstop() RETURNS void LANGUAGE plpgsql AS $$
DECLARE s uuid := test.mk_user(); b timestamptz := test.base_time() + interval '1 day';
        r1 uuid := test.mk_request(test.mk_listing(test.mk_user(), b, 60), s);
        r2 uuid := test.mk_request(test.mk_listing(test.mk_user(), b + interval '30 minutes', 60), s);
        t3 uuid := test.mk_user();
        r3 uuid := test.mk_request(test.mk_listing(t3, b + interval '2 days', 60), test.mk_user());
        r4 uuid := test.mk_request(test.mk_listing(t3, b + interval '2 days 30 minutes', 60), test.mk_user());
BEGIN
  PERFORM test.raw_accept(r1);
  PERFORM test.expect_error(format('SELECT test.raw_accept(%L)', r2), 'accepted_slots_user_no_overlap');   -- öğrenci tarafı
  PERFORM test.raw_accept(r3);
  PERFORM test.expect_error(format('SELECT test.raw_accept(%L)', r4), 'accepted_slots_user_no_overlap');   -- öğretmen tarafı
END $$;

-- [S13] Reddedilen talepte token hareketi yok; O-11: reddedildikten sonra yeniden başvuru YOK
CREATE FUNCTION test.t13_reject_no_tokens_no_reapply() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user(); l uuid := test.mk_listing(t, test.base_time(), 60, 3);
        r uuid := test.mk_request(l, s);
BEGIN
  PERFORM test.expect_error(format('SELECT reject_lesson_request(%L, %L)', r, s), 'NOT_LISTING_OWNER');
  PERFORM reject_lesson_request(r, t);
  PERFORM test.eq(test.req_status(r), 'REJECTED', 'REJECTED');
  PERFORM test.eq(test.ledger_rows(r), 0::bigint, 'ledger yok');
  PERFORM test.eq(test.avail(s), 10, 'bakiye değişmedi');
  PERFORM test.expect_error(format('SELECT test.mk_request(%L, %L)', l, s), 'lr_one_per_student_listing_uq');
  PERFORM test.expect_error(format('SELECT reject_lesson_request(%L, %L)', r, t), 'REQUEST_NOT_PENDING');
END $$;

-- C5: öğretmen kendi ilanına talep gönderemez
CREATE FUNCTION test.t14_teacher_cannot_request_own_listing() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); l uuid := test.mk_listing(t, test.base_time());
BEGIN
  PERFORM test.expect_error(format('SELECT test.mk_request(%L, %L)', l, t), 'lr_not_self_ck');
END $$;

-- [S14] Konuşma yalnızca ACCEPTED talep için; talep başına tek konuşma
CREATE FUNCTION test.t15_conversation_rules() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); l uuid := test.mk_listing(t, test.base_time());
        r1 uuid := test.mk_request(l, test.mk_user()); r2 uuid := test.mk_request(l, test.mk_user());
BEGIN
  PERFORM test.expect_error(format('INSERT INTO conversations (lesson_request_id) VALUES (%L)', r1),
                            'CONVERSATION_REQUIRES_ACCEPTED_REQUEST');
  PERFORM test.accept(r1);
  PERFORM test.expect_error(format('INSERT INTO conversations (lesson_request_id) VALUES (%L)', r1), 'conversations_request_uq');
  PERFORM test.expect_error(format('INSERT INTO conversations (lesson_request_id) VALUES (%L)', r2),
                            'CONVERSATION_REQUIRES_ACCEPTED_REQUEST');   -- AUTO_CANCELLED talep
END $$;

-- [S15] Konuşma dışındaki kullanıcı mesaj gönderemez
CREATE FUNCTION test.t16_only_participants_can_message() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user(); x uuid := test.mk_user();
        r uuid := test.mk_request(test.mk_listing(t, test.base_time()), s); c uuid;
BEGIN
  PERFORM test.accept(r);
  c := (SELECT conversation_id FROM conversations WHERE lesson_request_id = r);
  PERFORM test.eq(is_conversation_participant(s, c), true, 'öğrenci katılımcı');
  PERFORM test.eq(is_conversation_participant(t, c), true, 'öğretmen katılımcı');
  PERFORM test.eq(is_conversation_participant(x, c), false, 'dışarıdan biri katılımcı değil');
  PERFORM test.expect_error(format($f$INSERT INTO messages (conversation_id, sender_id, body) VALUES (%L,%L,'selam')$f$, c, x), 'NOT_A_PARTICIPANT');
  INSERT INTO messages (conversation_id, sender_id, body) VALUES (c, s, 'Merhaba');
  INSERT INTO messages (conversation_id, sender_id, body) VALUES (c, t, 'Selam');
  PERFORM test.expect_error(format($f$INSERT INTO messages (conversation_id, sender_id, body) VALUES (%L,%L,'   ')$f$, c, s), 'messages_body_ck');
END $$;

-- [S16] G4: iki onay -> token öğretmene; onay bekleyen tek onayda token bloke
CREATE FUNCTION test.t17_both_confirm_transfers_token() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user();
        l uuid := test.mk_listing(t, test.base_time(), 60, 2); r uuid := test.mk_request(l, s); e timestamptz;
BEGIN
  PERFORM test.accept(r); e := test.lesson_end(r);
  PERFORM confirm_lesson(r, s, e + interval '1 hour');
  PERFORM test.eq(test.held(s), 2, 'tek onayda token bloke KALIR');
  PERFORM test.eq(test.avail(t), 10, 'öğretmen henüz almadı');
  PERFORM test.eq(test.compl_status(r), 'AWAITING_CONFIRMATION', 'hâlâ bekliyor (MANUAL_REVIEW DEĞİL)');
  PERFORM confirm_lesson(r, t, e + interval '2 hours');
  PERFORM test.eq(test.compl_status(r), 'COMPLETED', 'COMPLETED');
  PERFORM test.eq((SELECT settlement_basis FROM lesson_requests WHERE request_id = r), 'BOTH_CONFIRMED', 'dayanak');
  PERFORM test.eq(test.held(s), 0, 'öğrenci bloke 0'); PERFORM test.eq(test.avail(s), 8, 'öğrenci available 8');
  PERFORM test.eq(test.avail(t), 12, 'öğretmen +2');
  PERFORM test.eq((SELECT status FROM listings WHERE listing_id = l), 'COMPLETED', 'ilan COMPLETED');
  PERFORM test.eq(test.ledger_rows(r, 'SETTLEMENT_DEBIT'), 1::bigint, 'debit');
  PERFORM test.eq(test.ledger_rows(r, 'SETTLEMENT_CREDIT'), 1::bigint, 'credit');
  PERFORM test.integrity_ok();
END $$;

-- G4: onay penceresi [bitiş, bitiş+24sa]
CREATE FUNCTION test.t18_confirmation_window() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user(); x uuid := test.mk_user();
        r uuid := test.mk_request(test.mk_listing(t, test.base_time(), 60, 1), s); e timestamptz;
BEGIN
  PERFORM test.accept(r); e := test.lesson_end(r);
  PERFORM test.expect_error(format('SELECT confirm_lesson(%L,%L,%L)', r, s, e - interval '1 minute'), 'CONFIRMATION_TOO_EARLY');
  PERFORM test.expect_error(format('SELECT confirm_lesson(%L,%L,%L)', r, x, e + interval '1 hour'), 'NOT_A_PARTICIPANT');
  PERFORM test.expect_error(format('SELECT confirm_lesson(%L,%L,%L)', r, s, e + interval '24 hours 1 minute'), 'CONFIRMATION_WINDOW_CLOSED');
  -- DB kısıtı da aynı pencereyi zorlar (fonksiyon atlansa bile):
  PERFORM test.expect_error(format('UPDATE lesson_requests SET student_completed_at = %L WHERE request_id = %L', e - interval '1 hour', r), 'lr_confirm_window_ck');
  PERFORM test.expect_error(format('UPDATE lesson_requests SET teacher_completed_at = %L WHERE request_id = %L', e + interval '25 hours', r), 'lr_confirm_window_ck');
  PERFORM confirm_lesson(r, s, e + interval '24 hours');             -- tam 24. saatte hâlâ kabul
  PERFORM test.eq((SELECT student_completed_at FROM lesson_requests WHERE request_id = r), e + interval '24 hours', 'sınırda kabul edildi');
  PERFORM confirm_lesson(r, s, e + interval '24 hours');             -- tekrar: sessizce aynı sonuç
END $$;

-- Kullanıcı kararı: süre dolunca yalnızca ÖĞRETMEN onaylamışsa token öğretmene
CREATE FUNCTION test.t19_deadline_teacher_only_settles() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user();
        r uuid := test.mk_request(test.mk_listing(t, test.base_time(), 60, 3), s); e timestamptz;
BEGIN
  PERFORM test.accept(r); e := test.lesson_end(r);
  PERFORM confirm_lesson(r, t, e + interval '2 hours');
  PERFORM test.eq(process_expired_confirmations(e + interval '24 hours'), 0, 'tam süre sonunda henüz işlenmez');
  PERFORM test.eq(test.held(s), 3, 'hâlâ bloke');
  PERFORM test.eq(process_expired_confirmations(e + interval '24 hours 1 minute'), 1, 'süre dolunca 1 talep işlendi');
  PERFORM test.eq(test.compl_status(r), 'COMPLETED', 'COMPLETED');
  PERFORM test.eq((SELECT settlement_basis FROM lesson_requests WHERE request_id = r), 'TEACHER_ONLY_AT_DEADLINE', 'dayanak');
  PERFORM test.eq(test.avail(t), 13, 'öğretmen +3'); PERFORM test.eq(test.held(s), 0, 'öğrenci bloke 0');
  PERFORM test.eq(process_expired_confirmations(e + interval '30 hours'), 0, 'ikinci çalıştırma işlem yapmaz');
  PERFORM test.integrity_ok();
END $$;

-- Kullanıcı kararı: yalnızca ÖĞRENCİ onaylamışsa da token öğretmene
CREATE FUNCTION test.t20_deadline_student_only_settles() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user();
        r uuid := test.mk_request(test.mk_listing(t, test.base_time(), 60, 2), s); e timestamptz;
BEGIN
  PERFORM test.accept(r); e := test.lesson_end(r);
  PERFORM confirm_lesson(r, s, e + interval '3 hours');
  PERFORM test.eq(process_expired_confirmations(e + interval '25 hours'), 1, 'işlendi');
  PERFORM test.eq(test.compl_status(r), 'COMPLETED', 'COMPLETED');
  PERFORM test.eq((SELECT settlement_basis FROM lesson_requests WHERE request_id = r), 'STUDENT_ONLY_AT_DEADLINE', 'dayanak');
  PERFORM test.eq(test.avail(t), 12, 'öğretmen +2'); PERFORM test.eq(test.held(s), 0, 'bloke 0');
  PERFORM test.integrity_ok();
END $$;

-- [S17] Hiç onay yoksa: MANUAL_REVIEW, token bloke; geç onay kabul edilmez
CREATE FUNCTION test.t21_deadline_no_confirmation_manual_review() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user();
        r uuid := test.mk_request(test.mk_listing(t, test.base_time(), 60, 2), s); e timestamptz;
BEGIN
  PERFORM test.accept(r); e := test.lesson_end(r);
  PERFORM test.eq(process_expired_confirmations(e + interval '25 hours'), 1, 'işlendi');
  PERFORM test.eq(test.compl_status(r), 'MANUAL_REVIEW', 'MANUAL_REVIEW');
  PERFORM test.eq(test.held(s), 2, 'token bloke kalır'); PERFORM test.eq(test.avail(t), 10, 'öğretmen almadı');
  PERFORM test.expect_error(format('SELECT confirm_lesson(%L,%L,%L)', r, s, e + interval '26 hours'), 'CONFIRMATION_WINDOW_CLOSED');
  PERFORM test.expect_error(format('SELECT confirm_lesson(%L,%L,%L)', r, t, e + interval '2 hours'), 'CONFIRMATION_WINDOW_CLOSED');
  PERFORM test.expect_error(format('UPDATE lesson_requests SET completion_status = %L WHERE request_id = %L', 'COMPLETED', r), 'COMPLETION_INVALID_TRANSITION');
  PERFORM test.integrity_ok();    -- bloke bakiye = açık ders toplamı (MANUAL_REVIEW dahil)
END $$;

-- [S18] Settlement ikinci kez çalıştırılırsa token ikinci kez aktarılmaz
CREATE FUNCTION test.t22_settlement_is_idempotent() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user();
        r uuid := test.mk_request(test.mk_listing(t, test.base_time(), 60, 2), s); e timestamptz; w uuid;
BEGIN
  PERFORM test.accept(r); e := test.lesson_end(r); PERFORM test.complete(r);
  PERFORM settle_request_internal(r, 'BOTH_CONFIRMED', e + interval '3 hours');       -- ikinci kez
  PERFORM confirm_lesson(r, s, e + interval '4 hours');                               -- tekrar onay
  PERFORM process_expired_confirmations(e + interval '40 hours');
  PERFORM test.eq(test.avail(t), 12, 'öğretmen yalnızca bir kez +2'); PERFORM test.eq(test.avail(s), 8, 'öğrenci 8');
  PERFORM test.eq(test.ledger_rows(r), 3::bigint, 'HOLD + DEBIT + CREDIT = 3 satır');
  w := (SELECT wallet_id FROM wallets WHERE user_id = t);
  PERFORM test.expect_error(format($f$INSERT INTO wallet_transactions (wallet_id, lesson_request_id, transaction_type,
      available_delta, held_delta, idempotency_key) VALUES (%L,%L,'SETTLEMENT_CREDIT',2,0,'baska-anahtar')$f$, w, r),
      'wtx_once_per_request_uq');
  PERFORM test.integrity_ok();
END $$;

-- Ücretsiz ders (0 token): aynı iş akışı, ledger hareketi YOK
CREATE FUNCTION test.t23_free_lesson_has_no_ledger_movement() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user();
        r uuid := test.mk_request(test.mk_listing(t, test.base_time(), 60, 0), s);
BEGIN
  PERFORM test.accept(r); PERFORM test.complete(r);
  PERFORM test.eq(test.compl_status(r), 'COMPLETED', 'tamamlandı');
  PERFORM test.eq(test.ledger_rows(r), 0::bigint, 'ledger satırı yok');
  PERFORM test.eq(test.avail(s), 10, 'öğrenci 10'); PERFORM test.eq(test.avail(t), 10, 'öğretmen 10');
  PERFORM test.expect_error(format($f$INSERT INTO wallet_transactions (wallet_id, lesson_request_id, transaction_type,
      available_delta, held_delta, idempotency_key) SELECT wallet_id,%L,'HOLD',0,0,'sifir' FROM wallets WHERE user_id=%L$f$, r, s), 'wtx_nonzero_ck');
  PERFORM test.integrity_ok();
END $$;

-- [S19,S20] Değerlendirme
CREATE FUNCTION test.t24_reviews() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user(); x uuid := test.mk_user();
        r uuid := test.mk_request(test.mk_listing(t, test.base_time(), 60, 1), s);
BEGIN
  PERFORM test.accept(r);
  PERFORM test.expect_error(format($f$INSERT INTO reviews (lesson_request_id, reviewer_id, reviewee_id, rating) VALUES (%L,%L,%L,5)$f$, r, s, t), 'REVIEW_REQUIRES_COMPLETED_LESSON');
  PERFORM test.complete(r);
  INSERT INTO reviews (lesson_request_id, reviewer_id, reviewee_id, rating, comment) VALUES (r, s, t, 5, 'harika');
  INSERT INTO reviews (lesson_request_id, reviewer_id, reviewee_id, rating) VALUES (r, t, s, 4);
  PERFORM test.expect_error(format($f$INSERT INTO reviews (lesson_request_id, reviewer_id, reviewee_id, rating) VALUES (%L,%L,%L,3)$f$, r, s, t), 'reviews_once_per_reviewer_uq');
  PERFORM test.expect_error(format($f$INSERT INTO reviews (lesson_request_id, reviewer_id, reviewee_id, rating) VALUES (%L,%L,%L,0)$f$, r, s, t), 'reviews_rating_ck');
  PERFORM test.expect_error(format($f$INSERT INTO reviews (lesson_request_id, reviewer_id, reviewee_id, rating) VALUES (%L,%L,%L,6)$f$, r, s, t), 'reviews_rating_ck');
  PERFORM test.expect_error(format($f$INSERT INTO reviews (lesson_request_id, reviewer_id, reviewee_id, rating) VALUES (%L,%L,%L,3)$f$, r, x, t), 'REVIEW_PARTIES_MISMATCH');
  PERFORM test.expect_error(format($f$INSERT INTO reviews (lesson_request_id, reviewer_id, reviewee_id, rating) VALUES (%L,%L,%L,3)$f$, r, s, s), 'REVIEW_PARTIES_MISMATCH');
END $$;

-- [S21] + G13: bakiye = defter toplamı, defter değiştirilemez, cüzdana doğrudan yazılamaz
CREATE FUNCTION test.t25_ledger_integrity_and_guards() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user(); b timestamptz := test.base_time(); r uuid; l uuid; w uuid;
BEGIN
  FOR i IN 1..3 LOOP
    r := test.mk_request(test.mk_listing(t, b + i * interval '1 day', 60, i), s);
    PERFORM test.accept(r);
    IF i < 3 THEN PERFORM test.complete(r); END IF;
  END LOOP;
  PERFORM test.integrity_ok();
  PERFORM test.eq((SELECT sum(available_balance + held_balance) FROM wallets WHERE user_id IN (s, t)), 20::bigint, 'token korunumu');
  PERFORM test.expect_error('UPDATE wallet_transactions SET available_delta = 99', 'LEDGER_IS_APPEND_ONLY');
  PERFORM test.expect_error('DELETE FROM wallet_transactions', 'LEDGER_IS_APPEND_ONLY');
  PERFORM test.expect_error('TRUNCATE wallet_transactions', 'LEDGER_IS_APPEND_ONLY');
  PERFORM test.expect_error(format('UPDATE wallets SET available_balance = 1000 WHERE user_id = %L', s), 'WALLET_BALANCE_ONLY_VIA_LEDGER');
  PERFORM test.expect_error(format('UPDATE wallets SET held_balance = 0 WHERE user_id = %L', s), 'WALLET_BALANCE_ONLY_VIA_LEDGER');
  PERFORM test.expect_error(format('DELETE FROM wallets WHERE user_id = %L', s), 'WALLET_DELETE_FORBIDDEN');
  w := (SELECT wallet_id FROM wallets WHERE user_id = s);
  PERFORM test.expect_error(format($f$INSERT INTO wallet_transactions (wallet_id, transaction_type, available_delta, held_delta, idempotency_key)
      VALUES (%L,'WELCOME_BONUS',10,0,'ikinci-bonus')$f$, w), 'wtx_one_welcome_per_wallet_uq');
  PERFORM test.expect_error(format($f$INSERT INTO wallet_transactions (wallet_id, transaction_type, available_delta, held_delta, idempotency_key)
      VALUES (%L,'WELCOME_BONUS',-5,0,'eksi')$f$, w), 'wtx_shape_ck');
END $$;

-- O-09 / G2: değişmezlik kuralları
CREATE FUNCTION test.t26_immutability_rules() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); s uuid := test.mk_user(); l uuid := test.mk_listing(t, test.base_time(), 60, 1); r uuid;
BEGIN
  UPDATE listings SET token_price = 2, start_at = start_at + interval '1 hour', end_at = end_at + interval '1 hour'
   WHERE listing_id = l;                                                    -- henüz talep yok: serbest
  r := test.mk_request(l, s);
  UPDATE listings SET topic = 'yeni konu', description = 'açıklama' WHERE listing_id = l;   -- metin serbest
  PERFORM test.expect_error(format('UPDATE listings SET token_price = 3 WHERE listing_id = %L', l), 'LISTING_CORE_FIELDS_LOCKED');
  PERFORM test.expect_error(format('UPDATE listings SET start_at = start_at + interval ''1 hour'', end_at = end_at + interval ''1 hour'' WHERE listing_id = %L', l), 'LISTING_CORE_FIELDS_LOCKED');
  PERFORM test.expect_error(format('UPDATE listings SET teacher_id = %L WHERE listing_id = %L', s, l), 'LISTING_TEACHER_IMMUTABLE');
  PERFORM test.expect_error(format($f$UPDATE lesson_requests SET time_range = '[2030-01-01,2030-01-02)' WHERE request_id = %L$f$, r), 'REQUEST_SNAPSHOT_IMMUTABLE');
  PERFORM test.expect_error(format($f$UPDATE listings SET status = 'COMPLETED' WHERE listing_id = %L$f$, l), 'LISTING_INVALID_STATUS_TRANSITION');
  PERFORM reject_lesson_request(r, t);
  PERFORM test.expect_error(format($f$UPDATE lesson_requests SET request_status = 'ACCEPTED' WHERE request_id = %L$f$, r), 'REQUEST_STATUS_TERMINAL');
  PERFORM test.expect_error(format($f$UPDATE lesson_requests SET request_status = 'ACCEPTED', completion_status='AWAITING_CONFIRMATION' WHERE request_id = %L$f$, r), 'REQUEST_STATUS_TERMINAL');
  -- durum şekli kısıtı (G11): PENDING iken tamamlanma durumu ilerleyemez
  PERFORM test.expect_error(format($f$UPDATE lesson_requests SET completion_status = 'AWAITING_CONFIRMATION' WHERE request_id = %L$f$,
          test.mk_request(test.mk_listing(test.mk_user(), test.base_time() + interval '9 days'), test.mk_user())), 'lr_shape_not_accepted_ck');
END $$;

-- G3: tarihi geçen ilan
CREATE FUNCTION test.t27_expired_listings() RETURNS void LANGUAGE plpgsql AS $$
DECLARE t uuid := test.mk_user(); l uuid := test.mk_listing(t, test.base_time(), 60, 1); s uuid := test.mk_user();
        r uuid := test.mk_request(l, s); st timestamptz := (SELECT start_at FROM listings WHERE listing_id = l);
        l2 uuid := test.mk_listing(t, test.base_time() + interval '5 days'); r2 uuid := test.mk_request(l2, test.mk_user());
BEGIN
  PERFORM test.expect_error(format('SELECT accept_lesson_request(%L,%L,%L)', r, t, st), 'LISTING_EXPIRED');   -- tam başlangıçta
  PERFORM test.eq(test.req_status(r), 'PENDING', 'kabul edilemedi, talep hâlâ PENDING');
  PERFORM test.eq(expire_stale_requests(st - interval '1 minute'), 0, 'henüz geçmedi');
  PERFORM test.eq(expire_stale_requests(st), 1, 'temizlik işi 1 talebi kapattı');
  PERFORM test.eq(test.req_status(r), 'AUTO_CANCELLED', 'AUTO_CANCELLED');
  PERFORM test.eq((SELECT auto_cancel_reason FROM lesson_requests WHERE request_id = r), 'LISTING_EXPIRED', 'sebep');
  PERFORM test.eq(test.req_status(r2), 'PENDING', 'gelecekteki ilanın talebi etkilenmedi');
  PERFORM test.eq((SELECT effective_status FROM v_listing_state WHERE listing_id = l2), 'PUBLISHED', 'gelecekteki ilan PUBLISHED');
  -- BOOKED ilana yeni talep gelmez
  PERFORM test.accept(r2);
  PERFORM test.expect_error(format('SELECT test.mk_request(%L, %L)', l2, test.mk_user()), 'LISTING_NOT_PUBLISHED');
END $$;

-- Doğrulama kodları (G7, C1)
CREATE FUNCTION test.t28_auth_tokens() RETURNS void LANGUAGE plpgsql AS $$
DECLARE u uuid := test.mk_user(); u2 uuid := test.mk_user(); a uuid; b uuid;
BEGIN
  a := issue_auth_token(u, 'EMAIL_VERIFICATION', 'hash-ayni', interval '10 minutes');
  PERFORM issue_auth_token(u2, 'EMAIL_VERIFICATION', 'hash-ayni', interval '10 minutes');   -- C1: aynı hash iki kullanıcıda olabilir
  PERFORM test.eq(verify_auth_token(u, 'EMAIL_VERIFICATION', 'yanlis', 3), 'INVALID', '1. yanlış');
  PERFORM test.eq(verify_auth_token(u, 'EMAIL_VERIFICATION', 'yanlis', 3), 'INVALID', '2. yanlış');
  PERFORM test.eq(verify_auth_token(u, 'EMAIL_VERIFICATION', 'yanlis', 3), 'INVALID', '3. yanlış');
  PERFORM test.eq(verify_auth_token(u, 'EMAIL_VERIFICATION', 'hash-ayni', 3), 'LOCKED', 'deneme sınırı: doğru kod bile kilitli');
  b := issue_auth_token(u, 'EMAIL_VERIFICATION', 'yeni-hash', interval '10 minutes');       -- eskiyi iptal eder
  PERFORM test.eq((SELECT revoked_at IS NOT NULL FROM auth_tokens WHERE auth_token_id = a), true, 'eski kod iptal');
  PERFORM test.expect_error(format($f$INSERT INTO auth_tokens (user_id, purpose, token_hash, expires_at) VALUES (%L,'EMAIL_VERIFICATION','x', now()+interval '1 hour')$f$, u), 'auth_tokens_one_active_uq');
  PERFORM test.eq((SELECT email_verified_at IS NULL FROM users WHERE user_id = u), true, 'henüz doğrulanmadı');
  PERFORM test.eq(verify_auth_token(u, 'EMAIL_VERIFICATION', 'yeni-hash', 3), 'OK', 'doğru kod');
  PERFORM test.eq((SELECT email_verified_at IS NOT NULL FROM users WHERE user_id = u), true, 'e-posta doğrulandı');
  PERFORM test.eq(verify_auth_token(u, 'EMAIL_VERIFICATION', 'yeni-hash', 3), 'NOT_FOUND', 'tek kullanımlık');
  PERFORM issue_auth_token(u, 'PASSWORD_RESET', 'p-hash', interval '1 millisecond');
  PERFORM pg_sleep(0.05);
  PERFORM test.eq(verify_auth_token(u, 'PASSWORD_RESET', 'p-hash', 3), 'EXPIRED', 'süresi dolmuş kod');
END $$;

-- G14: anonimleştirme
CREATE FUNCTION test.t29_anonymize_user() RETURNS void LANGUAGE plpgsql AS $$
DECLARE u uuid := test.mk_user(); t uuid := test.mk_user(); s uuid := test.mk_user();
        r uuid := test.mk_request(test.mk_listing(t, test.base_time(), 60, 2), s);
BEGIN
  PERFORM test.accept(r);
  PERFORM test.expect_error(format('SELECT anonymize_user(%L)', s), 'USER_HAS_ACTIVE_OBLIGATIONS');   -- bloke token var
  PERFORM test.expect_error(format('SELECT anonymize_user(%L)', t), 'USER_HAS_ACTIVE_OBLIGATIONS');   -- açık ders var
  PERFORM anonymize_user(u);
  PERFORM test.eq((SELECT anonymized_at IS NOT NULL AND email::text LIKE 'anon-%@anonymized.invalid' AND first_name = 'Silinmiş' FROM users WHERE user_id = u), true, 'kişisel veri silindi');
  PERFORM anonymize_user(u);                                                                           -- tekrar: zararsız
  PERFORM test.expect_error(format('SELECT test.mk_listing(%L, %L)', u, test.base_time() + interval '6 days'), 'TEACHER_ANONYMIZED');
  PERFORM test.complete(r);
  PERFORM anonymize_user(s);                                                                           -- ders bitti: artık serbest
  PERFORM test.integrity_ok();
END $$;

-- Genel bütünlük: karışık senaryo + token korunumu
CREATE FUNCTION test.t30_mixed_scenario_conserves_tokens() RETURNS void LANGUAGE plpgsql AS $$
DECLARE us uuid[] := ARRAY(SELECT test.mk_user() FROM generate_series(1, 6)); b timestamptz := test.base_time() + interval '1 day';
        r1 uuid; r2 uuid; r3 uuid; r4 uuid; r5 uuid; e timestamptz;
BEGIN
  r1 := test.mk_request(test.mk_listing(us[1], b, 60, 3), us[2]);                           -- tamamlanır
  r2 := test.mk_request(test.mk_listing(us[3], b + interval '1 day', 60, 2), us[2]);        -- reddedilir
  r3 := test.mk_request(test.mk_listing(us[2], b + interval '2 days', 60, 1), us[4]);       -- MANUAL_REVIEW
  r4 := test.mk_request(test.mk_listing(us[5], b + interval '3 days', 60, 0), us[6]);       -- ücretsiz
  r5 := test.mk_request(test.mk_listing(us[5], b + interval '4 days', 60, 2), us[1]);       -- sadece bekliyor
  PERFORM test.accept(r1); PERFORM test.complete(r1);
  PERFORM reject_lesson_request(r2, us[3]);
  PERFORM test.accept(r3); e := test.lesson_end(r3); PERFORM process_expired_confirmations(e + interval '30 hours');
  PERFORM test.accept(r4); PERFORM test.complete(r4);
  PERFORM test.eq((SELECT sum(available_balance + held_balance) FROM wallets WHERE user_id = ANY(us)), 60::bigint, '6 kullanıcı x 10 token korunur');
  PERFORM test.eq(test.compl_status(r3), 'MANUAL_REVIEW', 'r3 MANUAL_REVIEW');
  PERFORM test.eq(test.held(us[4]), 1, 'r3 tokenı bloke');
  PERFORM test.integrity_ok();
END $$;
