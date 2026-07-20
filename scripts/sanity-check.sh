#!/usr/bin/env bash
#
# sanity-check.sh — end-to-end verification of the whole submission.
#
# Runs exactly what the reviewers run:
#   Terraform : fmt -> init -> validate -> plan -refresh=false   (dev + prod)
#   Database  : docker compose up -> backup.sh -> restore.sh
# plus seed-count and index-usage checks. Cleans up after itself.
#
# Terraform CLI is optional: if `terraform` isn't installed, it falls back to
# the official hashicorp/terraform Docker image.
#
# Usage:  ./scripts/sanity-check.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PASS=0; FAIL=0
ok()   { echo "  ✅ $*"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $*"; FAIL=$((FAIL+1)); }
hdr()  { echo ""; echo "=== $* ==="; }

# --- Terraform runner: local CLI if present, else Docker image ---
TF_IMG="hashicorp/terraform:1.9.5"
if command -v terraform >/dev/null 2>&1; then
  tf() { ( cd "$ROOT/infra/$1" && shift && terraform "$@" ); }
  tf_fmt() { ( cd "$ROOT/infra" && terraform fmt "$@" ); }
else
  echo "(terraform CLI not found — using Docker image $TF_IMG)"
  tf() { local d="$1"; shift; docker run --rm -v "$ROOT/infra":/infra -w "/infra/$d" "$TF_IMG" "$@"; }
  tf_fmt() { docker run --rm -v "$ROOT/infra":/infra -w /infra "$TF_IMG" fmt "$@"; }
fi

########################################
hdr "1. Terraform: fmt"
if tf_fmt -check -recursive >/dev/null 2>&1; then ok "fmt clean (no files need formatting)"
else bad "fmt reported files needing formatting"; fi

for env in dev prod; do
  hdr "2. Terraform: $env (init / validate / plan -refresh=false)"
  tf "envs/$env" init -no-color >/tmp/sc_init_$env.log 2>&1 \
    && ok "$env init" || bad "$env init (see /tmp/sc_init_$env.log)"
  tf "envs/$env" validate -no-color >/tmp/sc_val_$env.log 2>&1 \
    && ok "$env validate" || bad "$env validate (see /tmp/sc_val_$env.log)"
  tf "envs/$env" plan -refresh=false -no-color >/tmp/sc_plan_$env.log 2>&1
  if grep -qE "^Plan: [0-9]+ to add" /tmp/sc_plan_$env.log; then
    ok "$env plan: $(grep -E '^Plan:' /tmp/sc_plan_$env.log)"
  else
    bad "$env plan failed (see /tmp/sc_plan_$env.log)"
  fi
done
# tidy terraform working dirs (may be root-owned if Docker was used)
docker run --rm -v "$ROOT/infra":/infra alpine sh -c \
  'find /infra/envs -maxdepth 2 -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null; \
   find /infra/envs -name ".terraform.lock.hcl" -delete 2>/dev/null; true' >/dev/null 2>&1

########################################
hdr "3. Database: docker compose up"
docker compose down -v >/dev/null 2>&1
if docker compose up -d >/tmp/sc_up.log 2>&1; then ok "docker compose up"; else bad "docker compose up (see /tmp/sc_up.log)"; fi
health=none
for _ in $(seq 1 30); do
  health=$(docker inspect --format '{{.State.Health.Status}}' bookings-db 2>/dev/null || echo none)
  [ "$health" = "healthy" ] && break; sleep 2
done
[ "$health" = "healthy" ] && ok "container healthy" || bad "container not healthy (status=$health)"

q() { docker compose exec -T db psql -U bookings -d bookings -tAc "$1" 2>/dev/null; }

hdr "4. Seed data checks"
b=$(q "SELECT count(*) FROM hotel_bookings")
e=$(q "SELECT count(*) FROM booking_events")
c=$(q "SELECT count(DISTINCT city) FROM hotel_bookings")
o=$(q "SELECT count(DISTINCT org_id) FROM hotel_bookings")
s=$(q "SELECT count(DISTINCT status) FROM hotel_bookings")
[ "${b:-0}" -ge 100 ] && ok "hotel_bookings = $b (>=100)" || bad "hotel_bookings = ${b:-0} (<100)"
[ "${e:-0}" -ge 1 ]   && ok "booking_events = $e"          || bad "booking_events = ${e:-0}"
[ "${c:-0}" -ge 2 ]   && ok "distinct cities = $c"          || bad "distinct cities = ${c:-0}"
[ "${o:-0}" -ge 2 ]   && ok "distinct orgs = $o"            || bad "distinct orgs = ${o:-0}"
[ "${s:-0}" -ge 2 ]   && ok "distinct statuses = $s"        || bad "distinct statuses = ${s:-0}"

hdr "5. Index usage (forced, index-only scan on covering index)"
plan=$(docker compose exec -T db psql -U bookings -d bookings -c "
  SET enable_seqscan = off;
  EXPLAIN SELECT org_id, status, COUNT(*), SUM(amount)
  FROM hotel_bookings
  WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
  GROUP BY org_id, status;" 2>/dev/null)
if echo "$plan" | grep -q "idx_hotel_bookings_city_created_at"; then
  ok "planner uses idx_hotel_bookings_city_created_at"
else
  bad "index not referenced in EXPLAIN"
fi

hdr "6. Backup"
if ./scripts/backup.sh >/tmp/sc_backup.log 2>&1 && ls backups/*.dump >/dev/null 2>&1; then
  ok "backup created: $(ls -1t backups/*.dump | head -1)"
else
  bad "backup failed (see /tmp/sc_backup.log)"
fi

hdr "7. Restore into fresh DB + row-count match"
./scripts/restore.sh >/tmp/sc_restore.log 2>&1
rb=$(docker compose exec -T db psql -U bookings -d bookings_restore -tAc "SELECT count(*) FROM hotel_bookings" 2>/dev/null)
re=$(docker compose exec -T db psql -U bookings -d bookings_restore -tAc "SELECT count(*) FROM booking_events" 2>/dev/null)
if [ "${rb:-0}" = "${b:-0}" ] && [ "${re:-0}" = "${e:-0}" ]; then
  ok "restored counts match source (bookings=$rb, events=$re)"
else
  bad "restored counts differ (source $b/$e vs restored ${rb:-0}/${re:-0}) — see /tmp/sc_restore.log"
fi

hdr "8. Cleanup"
docker compose down -v >/dev/null 2>&1 && ok "compose down -v"
rm -rf backups && ok "removed local backups/"

########################################
echo ""
echo "==================== RESULT ===================="
echo "  PASS: $PASS    FAIL: $FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "  🎉 All checks passed — submission is review-ready."
  exit 0
else
  echo "  ⚠️  Some checks failed — see /tmp/sc_*.log above."
  exit 1
fi
