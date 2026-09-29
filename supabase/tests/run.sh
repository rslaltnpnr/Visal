#!/usr/bin/env bash
# Şema + RLS testleri: yerel geçici PostgreSQL üzerinde çalışır.
#   bash supabase/tests/run.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
PGBIN="${PGBIN:-/usr/lib/postgresql/16/bin}"
DATA="$(mktemp -d)"
chown postgres "$DATA" 2>/dev/null || true
as_pg() { if [ "$(id -u)" = 0 ]; then su postgres -s /bin/bash -c "$*"; else bash -c "$*"; fi; }
as_pg "$PGBIN/initdb -D $DATA -A trust -U postgres >/dev/null"
as_pg "$PGBIN/pg_ctl -D $DATA -o '-p 54329 -k /tmp -c wal_level=logical' -l $DATA/log start >/dev/null"
trap 'as_pg "$PGBIN/pg_ctl -D $DATA stop -m fast >/dev/null"; rm -rf "$DATA"' EXIT
PSQL="psql -h /tmp -p 54329 -U postgres -v ON_ERROR_STOP=1 -q"
$PSQL -c "create database visal_test" >/dev/null
$PSQL -d visal_test -f "$HERE/00_supabase_stubs.sql"
for f in "$ROOT"/migrations/*.sql; do
  sed -e 's/^create extension if not exists pg_cron;//' \
      -e 's/^create extension if not exists pg_net with schema extensions;//' "$f" \
    | $PSQL -d visal_test
done
$PSQL -d visal_test -f "$HERE/10_rls_test.sql"
echo "Tüm veritabanı testleri geçti."
