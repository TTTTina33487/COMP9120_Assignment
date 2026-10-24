# Remote Education PostgreSQL Database

This directory contains the database and data work package owned by Zhongyuan An.
It implements the revised conceptual ER model after tutor feedback.

## Connection used for the local build

- PostgreSQL: 18.6
- Host: `localhost`
- Port: `5433`
- Database: `comp9120`
- Schema: `remote_education`

## Files

- `schema.sql` creates relations, keys, foreign keys, uniqueness constraints,
  domain checks, indexes and two allocation summary views.
- `seed.sql` imports realistic synthetic data.
- `crud.sql` demonstrates basic create, read, update and delete operations inside
  a rolled-back transaction.
- `constraint_tests.sql` runs negative tests that confirm invalid rows are
  rejected by CHECK, UNIQUE and foreign-key constraints.
- `verification.sql` checks row counts, constraints, eligibility matching,
  overlapping organisation roles and aggregate allocation rules.
- `relational_schema.dbml` is the editable relational schema source.
- `relational_schema.puml` is the source used for the rendered schema diagram.
- `remote_education_dump.sql` is a complete schema-and-data dump of the verified
  local PostgreSQL build.

## Build commands

```bash
psql -X -h localhost -p 5433 -d comp9120 -v ON_ERROR_STOP=1 \
  -f database/schema.sql

psql -X -h localhost -p 5433 -d comp9120 -v ON_ERROR_STOP=1 \
  -f database/seed.sql

psql -X -h localhost -p 5433 -d comp9120 -v ON_ERROR_STOP=1 \
  -f database/verification.sql

psql -X -h localhost -p 5433 -d comp9120 -v ON_ERROR_STOP=1 \
  -f database/crud.sql

psql -X -h localhost -p 5433 -d comp9120 -v ON_ERROR_STOP=1 \
  -f database/constraint_tests.sql
```

## Important mapping decisions

- `student_eligibility` maps the M:N `HOLDS` relationship and stores its
  verification attributes.
- `provider` and `funder` map the overlapping, partial ISA hierarchy using
  primary keys that are also foreign keys to `organisation`.
- `resource_funding` maps the M:N `FUNDS` relationship.
- `reviewer_id` and the decision attributes remain in `application` because the
  current scope allows at most one review decision per application.
- Multiple `allocation` rows may reference the same application, which supports
  staged and partial allocation.
- `usage_record` is a weak relation identified by the composite primary key
  `(allocation_id, record_no)`.

The two aggregate allocation limits are not ordinary row-level `CHECK`
constraints. The core service transaction owned by the business-logic member
must lock the application and offering, then ensure:

1. allocated quantity for an application does not exceed `requested_quantity`;
2. allocated quantity for an offering does not exceed `total_quantity`.
