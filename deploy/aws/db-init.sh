#!/bin/sh
set -eu
# psql reads values from its environment rather than exposing passwords in argv.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
\getenv app_user WORKNET_APP_DB_USER
\getenv app_password WORKNET_APP_DB_PASSWORD
\getenv app_database POSTGRES_DB
CREATE ROLE :"app_user" LOGIN PASSWORD :'app_password' NOSUPERUSER NOCREATEDB NOCREATEROLE;
ALTER DATABASE :"app_database" OWNER TO :"app_user";
SQL
