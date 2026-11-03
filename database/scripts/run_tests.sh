#!/usr/bin/env bash
# Tüm testleri YENİ, geçici bir veritabanında çalıştırır; işi bitince o geçici veritabanını siler.
#   bash scripts/run_tests.sh
# Güvenlik: Yalnızca kendi oluşturduğu '*_test' adlı veritabanını siler; 'studyco' gerçek veritabanına dokunmaz.
# KEEP_TEST_DB=yes verirseniz geçici veritabanı incelemeniz için silinmez.
# ROUNDS=N eşzamanlılık turu sayısı (varsayılan 10).
set -uo pipefail
cd "$(dirname "$0")/.."
TESTDB="studyco_${$}_${RANDOM}_test"
case "$TESTDB" in *_test) ;; *) echo "güvenlik: ad _test ile bitmeli" >&2; exit 2;; esac

cleanup() {
  if [ "${KEEP_TEST_DB:-}" = "yes" ]; then echo "(test veritabanı bırakıldı: $TESTDB)"; return; fi
  psql -X -q -d postgres -c "DROP DATABASE IF EXISTS \"$TESTDB\"" >/dev/null 2>&1
}
trap cleanup EXIT

echo "== Geçici test veritabanı: $TESTDB"
source scripts/_db_helpers.sh
createdb_utf8 "$TESTDB" || exit 1
export STUDYCO_DB="$TESTDB"
bash scripts/migrate.sh up >/dev/null || { echo "migration başarısız"; exit 1; }
P=(psql -X -q -v ON_ERROR_STOP=1 -d "$TESTDB")
for f in seeds/001_departments.sql tests/fixtures.sql tests/helpers.sql tests/tests.sql; do
  "${P[@]}" -f "$f" || { echo "YÜKLEME HATASI: $f -- testler çalıştırılamaz"; exit 1; }
done

# Güvenlik ağı: dosyada tanımlı her test gerçekten yüklendi mi? (sessizce eksik test = sahte başarı)
expected=$(grep -c '^CREATE FUNCTION test\.t[0-9][0-9]*_' tests/tests.sql)
loaded=$(psql -X -d "$TESTDB" -Atc "SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'test' AND p.proname ~ '^t[0-9]+_'")
if [ "$expected" -lt 1 ] || [ "$expected" != "$loaded" ]; then
  echo "TEST SAYISI TUTMUYOR: dosyada $expected, yüklenen $loaded"; exit 1
fi
echo "== $loaded test yüklendi"

pass=0; fail=0
for t in $(psql -X -d "$TESTDB" -Atc "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'test' AND p.proname ~ '^t[0-9]+_' ORDER BY p.proname"); do
  out="$(psql -X -q -d "$TESTDB" -v ON_ERROR_STOP=1 -c "BEGIN" -c "SELECT test.$t()" -c "ROLLBACK" 2>&1)"
  if [ $? -eq 0 ]; then
    pass=$((pass+1)); printf "  PASS  %s\n" "$t"
  else
    fail=$((fail+1)); printf "  FAIL  %s\n        %s\n" "$t" "$(echo "$out" | grep -m1 -E 'ERROR' )"
  fi
done
echo "== Birim/kısıt testleri: $pass geçti, $fail kaldı"

echo "== Eşzamanlılık testleri"
bash tests/concurrency.sh "$TESTDB"
crc=$?

echo
if [ $fail -eq 0 ] && [ $crc -eq 0 ]; then echo "SONUÇ: TÜM TESTLER GEÇTİ"; exit 0
else echo "SONUÇ: BAŞARISIZ TEST VAR (birim: $fail, eşzamanlılık rc=$crc)"; exit 1; fi
