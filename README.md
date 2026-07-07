# DevOps Assessment — Terraform + Database Reliability

Production-oriented AWS infrastructure (Terraform) plus a locally-runnable
PostgreSQL stack demonstrating migrations, seeding, query optimization, and
backup/restore.

> AWS deployment is **not** required. The Terraform is reviewed via
> `fmt` / `init` / `validate` / `plan`, and the database tasks run entirely
> locally with Docker Compose.

---

## Architecture

```
Internet
   │
   ▼
 ALB  (public subnets, SG: allow :80 from 0.0.0.0/0)
   │  forward :80
   ▼
ECS / Fargate service  (private subnets, SG: allow app port from ALB SG only)
   │  :5432
   ▼
 RDS PostgreSQL  (private subnets, SG: allow :5432 from ECS SG only,
                  publicly_accessible = false)
```

- **RDS is private** — `publicly_accessible = false`, placed in private
  subnets, and its security group only permits ingress from the ECS tasks'
  security group. Nothing else in the VPC (or the internet) can reach it.
- Fargate tasks run in private subnets and reach the internet (image pulls)
  through a **NAT gateway**.

---

## Repository layout

```
.
├── infra/                        # Part 1 & 2 — Terraform
│   ├── modules/
│   │   ├── network/              # VPC, public/private subnets, IGW, NAT, routes
│   │   ├── ecs/                  # ALB, ALB/ECS SGs, cluster, task def, service
│   │   └── rds/                  # RDS SG, subnet group, private PostgreSQL
│   └── envs/
│       ├── dev/                  # small instance, retention 1d, no deletion protection
│       └── prod/                 # larger multi-AZ instance, retention 30d, deletion protection
├── docker-compose.yml            # Part 4 — local database (run from repo root)
├── db/                           # Part 4 & 5 — SQL
│   ├── migrations/
│   │   ├── 001_schema.sql        # hotel_bookings, booking_events
│   │   └── 002_indexes.sql       # covering index for the reporting query
│   └── seed/
│       └── seed.sql              # 200 bookings + events
├── scripts/                      # Part 6 — backup & restore
│   ├── backup.sh
│   └── restore.sh
└── .github/workflows/terraform.yml   # Part 3 — CI: fmt/init/validate/plan on PRs
```

Each environment has its **own** variables, `terraform.tfvars`, backend
configuration, resource sizing, RDS backup retention, and deletion-protection
setting.

| Setting               | dev             | prod                |
|-----------------------|-----------------|---------------------|
| AZs / subnets         | 2 AZs           | 3 AZs               |
| ECS desired count     | 1               | 3                   |
| Task CPU / memory     | 256 / 512       | 1024 / 2048         |
| RDS instance class    | `db.t3.micro`   | `db.r6g.large`      |
| RDS multi-AZ          | false           | true                |
| Backup retention      | 1 day           | 30 days             |
| Deletion protection   | false           | true                |
| State backend (key)   | `dev/…`         | `prod/…`            |

---

## Part 1–3: Terraform

### Prerequisites
- Terraform >= 1.5 (CI pins 1.9.5)
- **No AWS account or credentials needed for review.** The provider uses
  static placeholder credentials plus `skip_credentials_validation` /
  `skip_requesting_account_id` / `skip_metadata_api_check`, and the code has
  **no data sources**, so `plan -refresh=false` runs fully offline and makes
  no API calls. (Before a real deployment, remove the `mock_*` credentials in
  `envs/<env>/providers.tf` and supply real ones.)

### Review commands (run per environment)

```bash
# Formatting (whole tree)
terraform -chdir=infra fmt -check -recursive

# dev
cd infra/envs/dev
terraform init
terraform validate
terraform plan -refresh=false

# prod
cd ../prod
terraform init
terraform validate
terraform plan -refresh=false
```

**Verified locally** (Terraform 1.9.5): `fmt` clean, both envs `validate`
successfully, and `plan -refresh=false` produces **dev = 29 resources to add**
and **prod = 33 to add** with `0 to change, 0 to destroy`.

### State backend

For frictionless offline review, the committed `backend.tf` in each env uses
Terraform's **local** backend (so `init`/`plan` need no S3 bucket or
credentials). The production remote backend — **S3 + DynamoDB lock, with a
distinct bucket/key per environment** — is provided in
`envs/<env>/backend-s3.tf.example`. To deploy for real, rename that file to
`backend.tf` and run `terraform init`.

### Part 3: GitHub Actions

[`.github/workflows/terraform.yml`](.github/workflows/terraform.yml) runs on
pull requests touching `infra/**`. For each environment (`dev`, `prod`) it runs
`fmt` → `init` → `validate` → `plan -refresh=false`, then:

- uploads the plan as a **workflow artifact** (`tfplan-dev`, `tfplan-prod`), and
- posts the plan as a **PR comment** (collapsible, with per-step outcomes).

---

## Part 4–6: Local database

### Prerequisites
- Docker + Docker Compose v2

### Start the database (Part 4 & 5)

From the repo root:

```bash
docker compose up -d
```

On first boot the container runs, in order:
`001_schema.sql` → `002_indexes.sql` → `seed.sql`, giving you the two tables,
the tuning index, and **200 seeded bookings** (6 cities, 4 organizations,
5 statuses) plus booking events.

Connection details (local only):
`host=localhost port=5432 db=bookings user=bookings password=bookings_local_pw`.

Verify the data loaded:

```bash
docker compose exec db psql -U bookings -d bookings -c \
  "SELECT count(*) FROM hotel_bookings;"          # -> 200
docker compose exec db psql -U bookings -d bookings -c \
  "SELECT count(DISTINCT city) cities,
          count(DISTINCT org_id) orgs,
          count(DISTINCT status) statuses FROM hotel_bookings;"  # -> 6 / 4 / 5
```

### Part 5: Query optimization

Target query:

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

Index added ([`db/migrations/002_indexes.sql`](db/migrations/002_indexes.sql)):

```sql
CREATE INDEX idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
```

**Why this index:**

1. **`city` first (equality).** The `WHERE city = 'delhi'` predicate is an
   equality match, so `city` is the leading column — it lets the index jump
   straight to the `delhi` rows.
2. **`created_at` second (range).** After fixing `city`, matching rows are
   ordered by `created_at`, so the `created_at >= NOW() - INTERVAL '30 days'`
   range is served as a contiguous slice with no extra filtering.
3. **`INCLUDE (org_id, status, amount)` (covering).** The query only reads
   `org_id`, `status`, and `amount`. Storing them in the index leaf makes it a
   **covering index**, so PostgreSQL can satisfy the whole aggregation with an
   **index-only scan** and skip heap lookups. `org_id`/`status`/`amount` are in
   `INCLUDE` (not the key) because they aren't used for searching or ordering —
   this keeps the key small while still avoiding the heap.

**Verify the plan uses the index:**

```bash
docker compose exec db psql -U bookings -d bookings -c "
EXPLAIN (ANALYZE, BUFFERS)
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;"
```

> Note on the seed dataset: with only 200 rows the whole table is ~3 pages, so
> the planner may still pick a sequential scan (it's genuinely cheaper at that
> size). To confirm the index is valid and gets chosen once the table grows,
> force it:
>
> ```bash
> docker compose exec db psql -U bookings -d bookings -c "
> SET enable_seqscan = off;
> EXPLAIN (ANALYZE) SELECT org_id, status, COUNT(*), SUM(amount)
> FROM hotel_bookings
> WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
> GROUP BY org_id, status;"
> ```
>
> This shows `Index Only Scan using idx_hotel_bookings_city_created_at` with the
> `Index Cond` covering both predicates — verified locally.

### Part 6: Backup & restore

```bash
# From the repo root, with the db container running:
./scripts/backup.sh                 # -> backups/bookings_YYYYmmdd_HHMMSS.dump
./scripts/restore.sh                # restores newest dump into a FRESH db
./scripts/restore.sh backups/bookings_20260101_120000.dump   # or a specific file
```

- **`backup.sh`** runs `pg_dump -Fc` (custom, compressed format) inside the
  container and writes a **timestamped** dump to `backups/`.
- **`restore.sh`** drops and recreates a separate database (`bookings_restore` by
  default, override with `RESTORE_DB=...`), restores the dump into it, and
  prints row counts. Restoring into a fresh DB proves the dump is
  self-contained and never risks the source data.

**How to verify the restore worked:**

The restore script ends by printing the row counts in the restored database:

```
 table_name    | rows
---------------+------
 booking_events|  347
 hotel_bookings|  200
```

Confirm they match the source database:

```bash
docker compose exec db \
  psql -U bookings -d bookings -c \
  "SELECT count(*) AS bookings FROM hotel_bookings;
   SELECT count(*) AS events   FROM booking_events;"
```

Equal counts in `bookings` (source) and `bookings_restore` (restored) confirm a
successful restore. **Verified locally:** source and restored both report
200 bookings / 347 events. (Exact event counts vary per seed run because
events are generated with randomness; the two databases always match.)

### Tear down

```bash
docker compose down -v      # from repo root; -v also removes the data volume
```

---

## End-to-end verification summary

| Task | Command | Result |
|------|---------|--------|
| Terraform format | `terraform -chdir=infra fmt -check -recursive` | clean |
| Terraform validate (dev/prod) | `terraform validate` | Success |
| Terraform plan (dev) | `terraform plan -refresh=false` | 29 to add |
| Terraform plan (prod) | `terraform plan -refresh=false` | 33 to add |
| DB up + seed | `docker compose up -d` | 200 bookings / 6 cities / 4 orgs / 5 statuses |
| Query optimization | `EXPLAIN` with `enable_seqscan=off` | Index-only scan on covering index |
| Backup | `./scripts/backup.sh` | timestamped `.dump` created |
| Restore | `./scripts/restore.sh` | fresh DB, row counts match source |
