#!/usr/bin/env bash
# Eşzamanlılık testleri: GERÇEK paralel psql oturumları (ayrı bağlantılar) ile yarış durumları.
# Kullanım: bash tests/concurrency.sh <test_veritabanı_adı>   (genelde run_tests.sh çağırır)
# Veriyi kalıcı (commit) olarak kurduğu için YALNIZCA '_test' ile biten veritabanında çalışır.
set -uo pipefail
cd "$(dirname "$0")/.."
DB="${1:?test veritabanı adı gerekli}"
case "$DB" in *_test) ;; *) echo "güvenlik: yalnızca *_test veritabanı" >&2; exit 2;; esac
ROUNDS="${ROUNDS:-10}"
Q=(psql -X -q -At -v ON_ERROR_STOP=1 -d "$DB")
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAILS=0

check() { # ad beklenen gelen
  if [ "$2" != "$3" ]; then echo "    HATA [$1]: beklenen=$2 gelen=$3"; FAILS=$((FAILS+1)); fi
}

# Hepsi aynı anda ateşlensin diye ortak bir "start" zamanı: şimdi + 1.2 sn
start_time() { "${Q[@]}" -c "SELECT (clock_timestamp() + interval '1200 milliseconds')::text"; }

# worker <dosya_öneki> <T0> <SQL>   -> bekler, sonra SQL'i çalıştırır; çıktıyı ve çıkış kodunu yazar
worker() {
  local pre="$1" t0="$2" sql="$3"
  (
    out="$(psql -X -q -At -d "$DB" \
        -c "SELECT pg_sleep(GREATEST(0, extract(epoch FROM (TIMESTAMPTZ '$t0' - clock_timestamp()))))" \
        -c "$sql" 2>&1)"
    echo $? > "$pre.rc"; echo "$out" > "$pre.out"
  ) &
}
ok_count()  { local n=0; for f in "$TMP"/"$1"*.rc; do [ "$(cat "$f")" = "0" ] && n=$((n+1)); done; echo $n; }
deadlocks() { cat "$TMP"/"$1"*.out 2>/dev/null | grep -ci 'deadlock' || true; }
unexpected() { # beklenmeyen hata mesajları (izin verilen kodlar dışında)
  cat "$TMP"/"$1"*.out 2>/dev/null | grep -i 'error' | grep -vE "$2" | head -3
}

echo "-- C1: aynı ilana 5 öğrencinin kabulü AYNI ANDA ($ROUNDS tur)"
for i in $(seq 1 "$ROUNDS"); do
  IFS='|' read -r T RS L <<< "$("${Q[@]}" -c "SELECT test.race_same_listing(5)")"
  T0="$(start_time)"; k=0
  for R in ${RS//,/ }; do k=$((k+1)); worker "$TMP/c1_$k" "$T0" "SELECT accept_lesson_request('$R','$T')"; done
  wait
  check "C1.$i kabul sayısı" 1 "$("${Q[@]}" -c "SELECT count(*) FROM lesson_requests WHERE listing_id='$L' AND request_status='ACCEPTED'")"
  check "C1.$i HOLD sayısı"  1 "$("${Q[@]}" -c "SELECT count(*) FROM wallet_transactions WHERE transaction_type='HOLD' AND lesson_request_id IN (SELECT request_id FROM lesson_requests WHERE listing_id='$L')")"
  check "C1.$i iptal edilen" 4 "$("${Q[@]}" -c "SELECT count(*) FROM lesson_requests WHERE listing_id='$L' AND request_status='AUTO_CANCELLED'")"
  check "C1.$i başarılı çağrı" 1 "$(ok_count c1_)"
  check "C1.$i deadlock" 0 "$(deadlocks c1_)"
  u="$(unexpected c1_ 'REQUEST_NOT_PENDING|LISTING_ALREADY_BOOKED')"; [ -n "$u" ] && { echo "    beklenmeyen: $u"; FAILS=$((FAILS+1)); }
  rm -f "$TMP"/c1_*
done

echo "-- C2: aynı öğrencinin çakışan 4 ilandaki kabulü AYNI ANDA ($ROUNDS tur)"
for i in $(seq 1 "$ROUNDS"); do
  IFS='|' read -r S PAIRS <<< "$("${Q[@]}" -c "SELECT test.race_student_overlap(4)")"
  T0="$(start_time)"; k=0
  for P in ${PAIRS//,/ }; do k=$((k+1)); worker "$TMP/c2_$k" "$T0" "SELECT accept_lesson_request('${P#*:}','${P%%:*}')"; done
  wait
  check "C2.$i başarılı çağrı" 1 "$(ok_count c2_)"
  check "C2.$i ACCEPTED" 1 "$("${Q[@]}" -c "SELECT count(*) FROM lesson_requests WHERE student_id='$S' AND request_status='ACCEPTED'")"
  check "C2.$i slot" 1 "$("${Q[@]}" -c "SELECT count(*) FROM accepted_slots WHERE user_id='$S'")"
  check "C2.$i held" 1 "$("${Q[@]}" -c "SELECT held_balance FROM wallets WHERE user_id='$S'")"
  check "C2.$i deadlock" 0 "$(deadlocks c2_)"
  u="$(unexpected c2_ 'REQUEST_NOT_PENDING|TIME_CONFLICT')"; [ -n "$u" ] && { echo "    beklenmeyen: $u"; FAILS=$((FAILS+1)); }
  rm -f "$TMP"/c2_*
done

echo "-- C3: çapraz rol (aynı kişi öğretmen ve öğrenci) AYNI ANDA ($ROUNDS tur)"
for i in $(seq 1 "$ROUNDS"); do
  IFS='|' read -r U RA RB T2 <<< "$("${Q[@]}" -c "SELECT test.race_cross_role()")"
  T0="$(start_time)"
  worker "$TMP/c3_a" "$T0" "SELECT accept_lesson_request('$RA','$U')"
  worker "$TMP/c3_b" "$T0" "SELECT accept_lesson_request('$RB','$T2')"
  wait
  check "C3.$i başarılı çağrı" 1 "$(ok_count c3_)"
  check "C3.$i U nun slotu" 1 "$("${Q[@]}" -c "SELECT count(*) FROM accepted_slots WHERE user_id='$U'")"
  check "C3.$i deadlock" 0 "$(deadlocks c3_)"
  rm -f "$TMP"/c3_*
done

echo "-- C4: iki tarafın onayı AYNI ANDA -> tam bir kez aktarım ($ROUNDS tur)"
for i in $(seq 1 "$ROUNDS"); do
  IFS='|' read -r R S T E <<< "$("${Q[@]}" -c "SELECT test.race_accepted_lesson(2)")"
  NOW="$("${Q[@]}" -c "SELECT (upper(time_range) + interval '1 hour')::text FROM lesson_requests WHERE request_id='$R'")"
  T0="$(start_time)"
  worker "$TMP/c4_s" "$T0" "SELECT confirm_lesson('$R','$S','$NOW')"
  worker "$TMP/c4_t" "$T0" "SELECT confirm_lesson('$R','$T','$NOW')"
  wait
  check "C4.$i başarılı çağrı" 2 "$(ok_count c4_)"
  check "C4.$i COMPLETED" COMPLETED "$("${Q[@]}" -c "SELECT completion_status FROM lesson_requests WHERE request_id='$R'")"
  check "C4.$i settlement satırı" 2 "$("${Q[@]}" -c "SELECT count(*) FROM wallet_transactions WHERE lesson_request_id='$R' AND transaction_type LIKE 'SETTLEMENT%'")"
  check "C4.$i öğretmen" 12 "$("${Q[@]}" -c "SELECT available_balance FROM wallets WHERE user_id='$T'")"
  check "C4.$i öğrenci" "8|0" "$("${Q[@]}" -c "SELECT available_balance||'|'||held_balance FROM wallets WHERE user_id='$S'")"
  check "C4.$i deadlock" 0 "$(deadlocks c4_)"
  rm -f "$TMP"/c4_*
done

echo "-- C5: süresi dolan onayların AYNI ANDA işlenmesi -> tam bir kez aktarım ($ROUNDS tur)"
for i in $(seq 1 "$ROUNDS"); do
  IFS='|' read -r R S T E <<< "$("${Q[@]}" -c "SELECT test.race_accepted_lesson(3)")"
  "${Q[@]}" -c "SELECT confirm_lesson('$R','$T',(SELECT upper(time_range) + interval '2 hours' FROM lesson_requests WHERE request_id='$R')) IS NOT NULL" >/dev/null
  LATE="$("${Q[@]}" -c "SELECT (upper(time_range) + interval '25 hours')::text FROM lesson_requests WHERE request_id='$R'")"
  T0="$(start_time)"
  worker "$TMP/c5_1" "$T0" "SELECT finalize_expired_request('$R','$LATE')"
  worker "$TMP/c5_2" "$T0" "SELECT finalize_expired_request('$R','$LATE')"
  worker "$TMP/c5_3" "$T0" "SELECT process_expired_confirmations('$LATE')"
  wait
  check "C5.$i başarılı çağrı" 3 "$(ok_count c5_)"
  check "C5.$i settlement satırı" 2 "$("${Q[@]}" -c "SELECT count(*) FROM wallet_transactions WHERE lesson_request_id='$R' AND transaction_type LIKE 'SETTLEMENT%'")"
  check "C5.$i öğretmen" 13 "$("${Q[@]}" -c "SELECT available_balance FROM wallets WHERE user_id='$T'")"
  check "C5.$i deadlock" 0 "$(deadlocks c5_)"
  rm -f "$TMP"/c5_*
done

echo "-- Genel bütünlük (tüm kalıcı yarış verisi üzerinde)"
check "bütünlük ihlali" 0 "$("${Q[@]}" -c "SELECT count(*) FROM v_integrity_violations")"
check "token korunumu" 0 "$("${Q[@]}" -c "SELECT (SELECT sum(available_balance+held_balance) FROM wallets) - 10 * (SELECT count(*) FROM users)")"

if [ "$FAILS" -eq 0 ]; then echo "   eşzamanlılık: TÜMÜ GEÇTİ (C1-C5 x $ROUNDS tur)"; exit 0
else echo "   eşzamanlılık: $FAILS HATA"; exit 1; fi
