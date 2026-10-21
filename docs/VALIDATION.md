# Verified delivery results

## PostgreSQL integration

`python -m pytest --junitxml=artifacts/test-results.xml -q`: **47 passed; no failures, errors or skipped tests**.
Tests use real PostgreSQL with the original schema and synthetic seed data in an owned temporary database.
Coverage includes student and coordinator pages, applications, duplicate requests, partial allocation,
rejection, usage records and CSV exports. Negative cases include school isolation, role access, CSRF,
invalid quantities, expired offerings or eligibility, missing eligibility, capacity limits, repeated approval,
and concurrent applications competing for the last unit. The original five negative database-constraint
checks also pass. Application pages and CSV headers are verified in English.

## Real browser workflow

`python scripts/browser_check.py`: **passed**.
Desktop: 1440 x 1000. Mobile: 390 x 844 without page-level horizontal overflow.
No JavaScript page errors or HTTP 5xx responses were observed.
The browser selects a student, filters eligible resources, submits a request, switches to the same-school
coordinator, approves and allocates two units, saves a completed usage record, inspects the history and
downloads both CSV reports. PostgreSQL confirms allocated_quantity = 2 for the submitted application.
Screenshots are captured from the English interface. Test and capture databases are cleaned up afterward;
the interactive demonstration database is preserved.
The configured account 560601108 successfully signs in with its real password for both
the student and coordinator workspaces. Captured passwords are masked. Integration checks also cover
incorrect credentials, role-only login bypass, unassigned workspaces, logout and credential rotation.

## Deliverables

- Poster.pdf: one A3 page; editable HTML, real English UI captures and verified test counts.
- Showcase.mp4: 108.0 seconds, 1920 x 1080, H.264/AAC; edited real interaction footage.
- Showcase.srt: editable English subtitles. The video has a silent audio track and no spoken narration.
- sample-applications.csv: school-scoped application details downloaded by the browser.
- sample-utilisation.csv: platform-wide resource summaries downloaded by the browser.
- screenshots/: English desktop and mobile captures.

## Scope and limitations

The prototype uses one password-protected demo account with two assigned workspaces. B supports initial partial
allocation but does not expose post-approval top-ups or automatic stock release from usage returns.
All seed data is synthetic. No external deployment or real educational impact is claimed.
