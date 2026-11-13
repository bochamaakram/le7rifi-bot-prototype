#!/bin/sh
set -eu
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set=app_password="$APP_DB_PASSWORD" <<'SQL'
CREATE EXTENSION IF NOT EXISTS vector;
CREATE USER le7rayfi_app PASSWORD :'app_password' NOSUPERUSER NOBYPASSRLS;
GRANT CONNECT ON DATABASE le7rayfi TO le7rayfi_app;
GRANT USAGE, CREATE ON SCHEMA public TO le7rayfi_app;
SQL
