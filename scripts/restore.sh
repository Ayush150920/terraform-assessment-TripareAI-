#!/usr/bin/env bash
#
# restore.sh — restore a dump into a FRESH database and verify the result.
#
# Usage:
#   ./scripts/restore.sh [path/to/backup.dump]
#
# If no file is given, the most recent dump in BACKUP_DIR is used.
#
# Env overrides (defaults match docker-compose.yml):
#   DB_USER      (default: bookings)
#   RESTORE_DB   (default: bookings_restore)   <- restored into this fresh DB
#   BACKUP_DIR   (default: <repo>/backups)
#
# The restore targets a brand-new database (dropped + recreated) so it never
# touches the original 'bookings' database, then prints row counts for verification.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT/docker-compose.yml"
SERVICE="db"

DB_USER="${DB_USER:-bookings}"
RESTORE_DB="${RESTORE_DB:-bookings_restore}"
BACKUP_DIR="${BACKUP_DIR:-$ROOT/backups}"

compose() { docker compose -f "$COMPOSE_FILE" "$@"; }

# Resolve the dump file: explicit arg, else newest *.dump in BACKUP_DIR.
BACKUP_FILE="${1:-}"
if [ -z "$BACKUP_FILE" ]; then
  BACKUP_FILE="$(ls -t "$BACKUP_DIR"/*.dump 2>/dev/null | head -n1 || true)"
fi

if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: no backup file found. Pass one explicitly or run ./scripts/backup.sh first." >&2
  exit 1
fi

if [ -z "$(compose ps -q "$SERVICE" 2>/dev/null)" ]; then
  echo "ERROR: the '$SERVICE' container is not running." >&2
  echo "Start it first with:  docker compose up -d" >&2
  exit 1
fi

echo "Restoring '$BACKUP_FILE' into fresh database '$RESTORE_DB' ..."

# Recreate the target database from scratch.
compose exec -T "$SERVICE" psql -U "$DB_USER" -d postgres -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS ${RESTORE_DB};"
compose exec -T "$SERVICE" psql -U "$DB_USER" -d postgres -v ON_ERROR_STOP=1 \
  -c "CREATE DATABASE ${RESTORE_DB};"

# Restore the custom-format dump.
compose exec -T "$SERVICE" pg_restore -U "$DB_USER" -d "$RESTORE_DB" --no-owner < "$BACKUP_FILE"

echo ""
echo "Restore finished. Verification (row counts in '$RESTORE_DB'):"
compose exec -T "$SERVICE" psql -U "$DB_USER" -d "$RESTORE_DB" -v ON_ERROR_STOP=1 -c "
    SELECT 'hotel_bookings' AS table_name, COUNT(*) AS rows FROM hotel_bookings
    UNION ALL
    SELECT 'booking_events', COUNT(*) FROM booking_events
    ORDER BY table_name;
"

echo ""
echo "Done. Compare these counts against the source database:"
echo "  docker compose exec db psql -U ${DB_USER} -d bookings \\"
echo "    -c \"SELECT count(*) FROM hotel_bookings; SELECT count(*) FROM booking_events;\""
