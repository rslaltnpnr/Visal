#!/usr/bin/env bash
# Tüm göçleri, Supabase panelindeki SQL Editor'e yapıştırılabilecek tek
# dosyada birleştirir (veritabanı şifresi gerektirmeyen kurulum yolu).
# Göçler supabase_migrations tablosuna da işlenir; böylece sonradan
# `supabase db push` aynı göçleri tekrar çalıştırmaz.
#   bash supabase/build_setup_sql.sh > supabase/setup_all.sql
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "-- VISAL veritabanı kurulumu (otomatik üretildi: supabase/build_setup_sql.sh)"
echo "-- Supabase → SQL Editor → New query → tamamını yapıştırın → Run."
echo "begin;"
for f in "$HERE"/migrations/*.sql; do
  echo
  echo "-- ===== $(basename "$f") ====="
  cat "$f"
done
echo
echo "create schema if not exists supabase_migrations;"
echo "create table if not exists supabase_migrations.schema_migrations (version text primary key, statements text[], name text);"
for f in "$HERE"/migrations/*.sql; do
  b="$(basename "$f" .sql)"
  echo "insert into supabase_migrations.schema_migrations (version, name) values ('${b%%_*}', '${b#*_}') on conflict (version) do nothing;"
done
echo "commit;"
