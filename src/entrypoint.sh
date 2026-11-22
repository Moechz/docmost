#!/bin/sh
# TOS wrapper: Docmost needs APP_SECRET, but hard-coding a secret in the
# compose file is forbidden. Generate one on first start and keep it next to
# the uploaded files so restarts and upgrades reuse the same secret.
set -u
set -e

umask 077
DATA_DIR=/app/data/storage
SECRET_FILE="$DATA_DIR/.app_secret"

mkdir -p "$DATA_DIR"
if [ ! -w "$DATA_DIR" ]; then
  echo "FATAL: $DATA_DIR is not writable by uid $(id -u):$(id -g)." >&2
  echo "The TOS installer normally chowns every bind-mount source to the" >&2
  echo "application user. If this is a manual install, run:" >&2
  echo "  chown -R 1000:1000 /Volume1/DockerAppData/docmostdocker" >&2
  exit 1
fi

if [ ! -s "$SECRET_FILE" ]; then
  # Write to a temporary file first so an interrupted first start cannot leave
  # a truncated secret behind (the app would reject it on the next boot).
  head -c 48 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$SECRET_FILE.tmp"
  chmod 600 "$SECRET_FILE.tmp"
  mv "$SECRET_FILE.tmp" "$SECRET_FILE"
fi
chmod 600 "$SECRET_FILE" 2>/dev/null || true

APP_SECRET="$(cat "$SECRET_FILE")"
if [ "${#APP_SECRET}" -lt 32 ]; then
  echo "FATAL: $SECRET_FILE is shorter than 32 characters." >&2
  echo "Delete it and restart the container to generate a new secret." >&2
  exit 1
fi
export APP_SECRET

exec docker-entrypoint.sh pnpm start
