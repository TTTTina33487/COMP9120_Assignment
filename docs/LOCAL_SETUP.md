# Run the website on your computer

This project is one Flask website backed by B's Python modules and PostgreSQL.
Students, coordinators, resource search, usage tracking and reports are pages
of the same application. No separate frontend server or npm installation is needed.

## 1. Requirements

- Python 3.12 is recommended; the code requires Python 3.10 or later.
- PostgreSQL 15 or later, with its service running. Cloud verification uses PostgreSQL 17.
- Git, or a downloaded and extracted ZIP of the delivery branch.

Chromium and FFmpeg are only needed to regenerate screenshots and videos.
They are not needed to run the website.

## 2. Download the delivery branch

```bash
git clone --branch codex/remote-education-delivery --single-branch https://github.com/Eric-LIN18/9120.git
cd 9120
```

Alternatively, select the delivery branch on GitHub, choose **Code > Download ZIP**,
extract it and open a terminal in the directory containing `app.py`.
All following commands run from that directory, not from either nested database package.

## 3. Install Python dependencies

Windows PowerShell:

```powershell
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
```

macOS / Linux:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
[ -f .env ] || cp .env.example .env
```

These commands use the virtual environment directly; activating it is optional.
If `.env` already exists, keep it and check its connection settings.

## 4. Initialize a new local database once

Using PostgreSQL command-line tools:

```bash
createdb -U postgres remote_education_db
psql -U postgres -d remote_education_db -v ON_ERROR_STOP=1 -f COMP9120_Assignment-feature-python-prototype/database/schema.sql
psql -U postgres -d remote_education_db -v ON_ERROR_STOP=1 -f COMP9120_Assignment-feature-python-prototype/database/seed.sql
```

The tools may prompt for your local PostgreSQL password. Adjust the username,
host or port if your installation differs. If the tools are not on PATH, use
their full installed paths or use pgAdmin instead.

In **pgAdmin**, create `remote_education_db`, open its Query Tool, then open and
execute the same `schema.sql` followed by `seed.sql`. Use only the
`COMP9120_Assignment-feature-python-prototype/database/` copy.

Initialize an empty development database only once. If B already provided a
database containing this schema and data, use it without reapplying these scripts.
Do not reset an existing database just to repeat a demonstration.

## 5. Edit .env

```dotenv
DATABASE_URL=postgresql://postgres:YOUR_LOCAL_PASSWORD@127.0.0.1:5432/remote_education_db
DEMO_LOGIN=1
PORT=5000
```

Replace the placeholder with your own local database password and adjust the
username, host, port and database name as needed. URL-encode special password
characters such as `@`, `:` and `/`. The B connection module loads `.env`.
An already exported `DATABASE_URL` takes precedence over the file.
Keep `.env` local; it is excluded from version control and the delivery ZIP.

## 6. Start the website

Windows PowerShell:

```powershell
.\.venv\Scripts\python.exe app.py
```

macOS / Linux:

```bash
.venv/bin/python app.py
```

Keep the terminal open. On the **same computer**, enter `http://127.0.0.1:5000`
in your browser. This is a local address, not a public link to the Codex environment.
Press `Ctrl+C` in the terminal to stop the foreground Flask process.

If port 5000 is already occupied, first check whether your application is already
running. Otherwise set `PORT=5001` in `.env`, restart and use port 5001 in the browser.

## 7. Try the English workflow

1. Enter account **560601108** and the test password provided by the project owner.
   Leave **Workspace** on **Student / Ava Mitchell**, then click **Sign in**.
2. Open **Explore resources**, optionally select **Eligible only**, and click **Search**.
3. Open **New application** and choose **Downloadable Year 10 Study Library**.
   Request two units and enter a learning goal of at least ten characters.
4. Click **Submit application**. The request is pending; stock is not reserved yet.
5. **Sign out**, enter the same account and password, and choose the
   **Coordinator / Amelia Carter** workspace before clicking **Sign in**.
6. Open **Review & allocate**, select the request and click **Approve & allocate**.
7. Open **Usage records**, select the allocation and click **Save usage record**
   after entering the usage details.
8. Open **Reports** to view summaries and download **Export school applications CSV**
   or **Resource CSV**.

The password-protected demo account is assigned only these two same-school
workspaces. See [ACCOUNT_LOGIN.md](ACCOUNT_LOGIN.md) for configuration and login tests.
Same-day duplicate student/resource requests
are blocked. Seed eligibility and offering dates expire mainly in 2027.

## 8. Tests and screenshots

To run tests locally, install `requirements-dev.txt` in the same virtual environment
and run `python -m pytest --junitxml=artifacts/test-results.xml -q` with that
environment's Python executable. Your test PostgreSQL user needs permission to
create temporary databases. Tests do not reset the interactive database.

Screenshot and media generation is verified in the configured Debian cloud
environment. It uses Linux paths, Chromium and system FFmpeg:

```bash
source scripts/env.sh
bash scripts/database.sh
.venv/bin/python -m pytest --junitxml=artifacts/test-results.xml -q
.venv/bin/python scripts/browser_check.py
.venv/bin/python scripts/build_deliverables.py
```

The browser script privately prompts for the configured application password.
New English screenshots are in `artifacts/screenshots/`. The same capture run
supplies the updated Poster and video. You can download existing assets without
installing these capture tools. See the root README for the cloud-specific setup.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Flask or psycopg cannot be imported | Run pip using the virtual environment's Python and `requirements.txt`. |
| PostgreSQL connection refused | Confirm its service, host and port. Do not use the cloud Unix socket path on your PC. |
| Password authentication failed | Check the local account, `.env` and URL encoding. |
| `remote_education` tables are missing | Verify the database name and initialize the original SQL once in an empty database. |
| A resource cannot be requested | Check verified eligibility, expiry and remaining quantity. |
| An approved request cannot receive another allocation | B currently supports initial allocation only, including an initial partial allocation. |
| A returned usage record does not release stock | Usage status does not automatically change the allocation lifecycle in the current B service. |

The commands are documented for Windows and macOS/Linux. Automated execution
and browser validation for this delivery were performed on Debian Linux.
