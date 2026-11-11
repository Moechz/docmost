#!/bin/sh
# TOS wrapper: Docmost needs APP_SECRET, but hard-coding a secret in the
# compose file is forbidden. Generate one on first start and keep it next to
# the uploaded files so restarts and upgrades reuse the same secret.
set -u
set -e
mkdir -p /app/data/storage
SECRET_FILE=/app/data/storage/.app_secret
if [ ! -s "$SECRET_FILE" ]; then
  head -c 48 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$SECRET_FILE"
fi
export APP_SECRET="$(cat "$SECRET_FILE")"
exec docker-entrypoint.sh pnpm start
