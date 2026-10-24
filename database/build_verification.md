# Database Build Verification

Verified on 15 October 2026 against the local PostgreSQL instance.

- PostgreSQL version: 18.6 Homebrew
- Host and port: localhost 5433
- Database: comp9120
- Schema: remote_education
- Build result: schema and seed data committed successfully
- CRUD result: create read update and delete demonstration completed and rolled back
- Dump restore result: restored into a temporary database with 14 tables and 10 applications, then the temporary database was removed

## Imported rows

| Relation | Rows |
|---|---:|
| region | 5 |
| school | 5 |
| coordinator | 5 |
| student | 10 |
| eligibility_type | 5 |
| student_eligibility | 11 |
| organisation | 6 |
| provider | 4 |
| funder | 4 |
| resource_offering | 8 |
| resource_funding | 8 |
| application | 10 |
| allocation | 9 |
| usage_record | 10 |

## Integrity results

- Zero applications exceeded their requested quantity.
- Zero resource offerings exceeded their total quantity.
- Two applications contain multiple allocation events, demonstrating staged allocation.
- Rural Futures Network and TechBridge Foundation occur in both subtype tables, demonstrating the overlapping ISA constraint.
- Invalid year level was rejected by a CHECK constraint.
- Invalid region reference was rejected by a foreign key.
- Duplicate organisation email was rejected by a UNIQUE constraint.
- Zero requested quantity was rejected by a CHECK constraint.
- Invalid weak-entity record number was rejected by a CHECK constraint.

The two aggregate allocation limits must also be rechecked inside the allocation
transaction with application and offering row locks. That transaction belongs to
the core business logic work package.
