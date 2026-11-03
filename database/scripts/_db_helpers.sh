# Ortak yardımcılar (setup_db.sh ve run_tests.sh tarafından 'source' edilir).

# UTF8 veritabanı oluşturur. NEDEN template0? Bazı kurulumlarda (ör. EDB macOS) varsayılan
# şablon 'template1' SQL_ASCII kodlamalıdır ve ondan UTF8 veritabanı türetilemez.
# PG17+: yerleşik 'C.UTF-8' yerel ayarı (Unicode büyük/küçük harf dönüşümü, işletim
# sisteminden bağımsız -> citext 'İ/ı/Ş' gibi harfleri de doğru katlar).
# Daha eski sürüm ya da hata: C yereli (yalnızca ASCII harf katlama; e-posta için yeterli).
createdb_utf8() {
  local db="$1" ver
  ver="$(psql -X -d postgres -Atc "SHOW server_version_num")" || return 1
  if [ "$ver" -ge 170000 ] && \
     createdb -T template0 -E UTF8 --locale-provider=builtin --builtin-locale=C.UTF-8 "$db" 2>/dev/null; then
    echo "  ($db: UTF8, yerel ayar builtin C.UTF-8)"
    return 0
  fi
  createdb -T template0 -E UTF8 --locale=C "$db" && echo "  ($db: UTF8, yerel ayar C)"
}
