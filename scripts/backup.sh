#!/usr/bin/env bash
#
# backup.sh — create a timestamped dump of the local PostgreSQL database.
#
# Usage:
#   ./scripts/backup.sh
#
# Env overrides (defaults match docker-compose.yml):
#   DB_USER      (default: bookings)
#   DB_NAME      (default: bookings)
#   BACKUP_DIR   (default: <repo>/backups)
#
# Output: <BACKUP_DIR>/bookings_YYYYmmdd_HHMMSS.dump  (custom-format, pg_restore-ready)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT/docker-compose.yml"
SERVICE="db"

DB_USER="${DB_USER:-bookings}"
DB_NAME="${DB_NAME:-bookings}"
BACKUP_DIR="${BACKUP_DIR:-$ROOT/backups}"

compose() { docker compose -f "$COMPOSE_FILE" "$@"; }

# Make sure the database container is up.
if [ -z "$(compose ps -q "$SERVICE" 2>/dev/null)" ]; then
  echo "ERROR: the '$SERVICE' container is not running." >&2
  echo "Start it first with:  docker compose up -d" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUTFILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.dump"

echo "Backing up database '$DB_NAME' ..."
# -Fc = custom format (compressed, restorable with pg_restore).
compose exec -T "$SERVICE" pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc > "$OUTFILE"

SIZE="$(du -h "$OUTFILE" | cut -f1)"
echo "Backup complete: $OUTFILE ($SIZE)"
