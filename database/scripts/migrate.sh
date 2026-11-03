#!/usr/bin/env bash
# Basit SQL migration çalıştırıcısı (ORM'den bağımsız).
#   bash scripts/migrate.sh up            -> bekleyen tüm migration'ları uygular
#   bash scripts/migrate.sh status        -> uygulanmış sürümleri listeler
#   CONFIRM_DESTRUCTIVE=yes bash scripts/migrate.sh down [N]   -> son N migration'ı geri alır (VERİ SİLER)
# Bağlantı: libpq ortam değişkenleri (PGHOST, PGPORT, PGUSER, PGPASSWORD...). Parola koda yazılmaz.
# Hedef veritabanı: STUDYCO_DB (varsayılan: studyco)
set -euo pipefail
cd "$(dirname "$0")/.."
DB="${STUDYCO_DB:-studyco}"
PSQL=(psql -X -q -v ON_ERROR_STOP=1 -d "$DB")

"${PSQL[@]}" -c "CREATE TABLE IF NOT EXISTS schema_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())"

cmd="${1:-status}"
case "$cmd" in
  up)
    for f in migrations/up/*.sql; do
      v="$(basename "$f" .sql)"
      done_already="$("${PSQL[@]}" -Atc "SELECT 1 FROM schema_migrations WHERE version = '$v'")"
      if [ -z "$done_already" ]; then
        echo "UP   $v"
        # -1: dosya + kayıt tek transaction'da; yarım kalmış migration olmaz
        "${PSQL[@]}" -1 -f "$f" -c "INSERT INTO schema_migrations (version) VALUES ('$v')"
      else
        echo "skip $v (uygulanmış)"
      fi
    done
    ;;
  down)
    if [ "${CONFIRM_DESTRUCTIVE:-}" != "yes" ]; then
      echo "Reddedildi: 'down' veri siler. Emin iseniz CONFIRM_DESTRUCTIVE=yes ile tekrar çalıştırın." >&2
      exit 1
    fi
    n="${2:-1}"
    for v in $("${PSQL[@]}" -Atc "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT $n"); do
      echo "DOWN $v"
      "${PSQL[@]}" -1 -f "migrations/down/$v.sql" -c "DELETE FROM schema_migrations WHERE version = '$v'"
    done
    ;;
  status)
    "${PSQL[@]}" -c "SELECT version, applied_at FROM schema_migrations ORDER BY version"
    ;;
  *)
    echo "Kullanım: bash scripts/migrate.sh up|down [N]|status" >&2; exit 2 ;;
esac
