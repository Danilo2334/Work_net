#!/bin/sh
# Use an encrypted off-server destination for the resulting private dump.
set -eu
umask 077
: "${WORKNET_ENV_FILE:?Set the private environment path}"
: "${WORKNET_BACKUP_DIR:?Set a private backup directory outside the checkout}"
mkdir -p "$WORKNET_BACKUP_DIR"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
dump="$WORKNET_BACKUP_DIR/worknet-$stamp.dump"
partial="$dump.partial"
docker compose --env-file "$WORKNET_ENV_FILE" -f "$(dirname "$0")/compose.yaml" \
  exec -T db sh -c 'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$partial"
test -s "$partial"
mv "$partial" "$dump"
printf '%s\n' "Backup created in the private backup directory. Copy it off this server."
