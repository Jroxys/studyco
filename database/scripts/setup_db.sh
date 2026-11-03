#!/usr/bin/env bash
# studyco veritabanını OLUŞTURUR (yoksa), migration'ları uygular, bölüm seed'ini yükler.
#   bash scripts/setup_db.sh
# Mevcut hiçbir veritabanına dokunmaz; var olan 'studyco' varsa onu silmez, yalnızca eksik
# migration'ları uygular. Ad değiştirmek için: STUDYCO_DB=baska_ad bash scripts/setup_db.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB="${STUDYCO_DB:-studyco}"

exists="$(psql -X -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname = '$DB'")"
if [ -z "$exists" ]; then
  echo "Veritabanı oluşturuluyor: $DB"
  source scripts/_db_helpers.sh
  createdb_utf8 "$DB"
else
  echo "Veritabanı zaten var: $DB (silinmeyecek; yalnızca eksik migration'lar uygulanacak)"
fi

STUDYCO_DB="$DB" bash scripts/migrate.sh up
psql -X -q -v ON_ERROR_STOP=1 -d "$DB" -f seeds/001_departments.sql
echo "Bölümler:"; psql -X -d "$DB" -Atc "SELECT name FROM departments ORDER BY name"
echo "Tamam. Gerçek ders/kafe verisi için: psql -d $DB -f seeds/load_catalog.sql"
