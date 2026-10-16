# Remote Education Resource Support System

COMP9120 Database Management Systems group project.

This project is a PostgreSQL-backed prototype for managing education-support resources in remote areas. It supports schools, students, support eligibility, resource offerings, applications, allocations, and usage records.

## Project goals

- Store and manage related education-support data consistently.
- Allow students to submit resource-support applications.
- Allow coordinators to review applications and allocate available resources.
- Record resource usage and produce operational reports.
- Demonstrate PostgreSQL constraints, meaningful queries, and a multi-step transaction with rollback behaviour.

## Tech stack

- **Database:** PostgreSQL
- **Application:** Python
- **Database driver:** psycopg

## Repository structure

```text
.
|-- database/
|   |-- schema.sql             # Tables, keys, constraints, indexes, and views
|   |-- seed.sql               # Synthetic development/demo data
|   |-- verification.sql       # Data and schema verification queries
|   |-- crud.sql               # CRUD demonstration queries
|   `-- constraint_tests.sql   # Negative constraint tests
|-- app/
|   |-- db.py                  # PostgreSQL connection helper
|   |-- services.py            # Application, review, allocation business logic
|   |-- queries.py             # Query and report functions for the prototype
|   `-- test_connection.py     # Database connection check
|-- docs/
|   |-- ERD.png
|   |-- relational_schema.png
|   `-- normalisation.md
|-- .env.example               # Safe local database configuration example
|-- requirements.txt
`-- README.md
```

> Update this section if the final repository structure differs.

## Prerequisites

- PostgreSQL 15 or later
- Python 3.10 or later
- Git

## Set up locally

### 1. Clone the repository

```powershell
git clone https://github.com/TTTTina33487/COMP9120_Assignment.git
cd COMP9120_Assignment
```

### 2. Create a Python environment

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

If PowerShell blocks activation, run the following in the current terminal and activate the environment again:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### 3. Create a local PostgreSQL database

Create an empty database called `remote_education_db` in pgAdmin or with:

```powershell
createdb -U postgres remote_education_db
```

### 4. Initialise the database

Run the SQL scripts in order:

```powershell
psql -U postgres -d remote_education_db -f database\schema.sql
psql -U postgres -d remote_education_db -f database\seed.sql
psql -U postgres -d remote_education_db -f database\verification.sql
psql -U postgres -d remote_education_db -f database\constraint_tests.sql
```

Alternatively, open each file in pgAdmin Query Tool and run it in the same order.

### 5. Configure your database connection

Copy the example configuration file:

```powershell
Copy-Item .env.example .env
```

Update `.env` with **your own local** PostgreSQL details:

```env
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@localhost:5432/remote_education_db
```

Do not commit `.env` to GitHub. It must be listed in `.gitignore`.

### 6. Test the Python backend connection

```powershell
.venv\Scripts\python.exe -m app.test_connection
```

The `app/` directory contains the Python backend layer. A separate team member
may connect these functions to the final user interface.

## Main prototype workflow

```text
Student submits an application
        -> Coordinator reviews the application
        -> System verifies eligibility and available quantity
        -> System creates an allocation and updates resource availability
        -> Usage of the allocated resource is recorded
        -> Dashboard/report queries show current activity and resource status
```

The allocation workflow is implemented as a database transaction. If eligibility is invalid, stock is insufficient, or a database operation fails, the entire allocation must be rolled back so that data remains consistent.

## Representative features

- View student, school, eligibility, and resource-offering information.
- Submit and review support applications.
- Allocate resources only when business rules are satisfied.
- Record usage of allocated resources.
- View reports such as pending applications, available resources, allocation status, usage activity, and expiring eligibility.

## Team workflow

All members work from the same GitHub repository. Pull the latest changes before starting work and push completed, tested changes with meaningful commit messages.

```powershell
git pull origin main
git add <files>
git commit -m "Describe the change"
git push origin main
```

Suggested ownership:

- **SQL/database member:** maintains scripts in `database/`, including schema changes and seed data.
- **Python/backend member:** maintains the database connection and business logic in `app/`.
- **UI/integration member:** connects the backend functions to the final interface and prepares the demo workflow.

If a schema change affects table names, columns, data types, keys, or constraints, the database member should notify the group. Other members should re-run the updated scripts against a fresh local database before testing their code.

## Resetting a development database

During development, schema changes may require a clean database. Only reset your own local development database:

```powershell
dropdb -U postgres remote_education_db
createdb -U postgres remote_education_db
```

Then repeat the initialisation steps above. Never run these commands against a shared or production database.

## Security and repository rules

- Never commit database passwords, `.env`, or Streamlit secret files.
- Use synthetic data only; do not include real student or personal information.
- Keep SQL changes in version-controlled `.sql` scripts rather than undocumented pgAdmin edits.
- Test the complete workflow after pulling schema changes.

## Assessment deliverables

The final submission package will include database scripts, source code, a project report, a maximum three-minute prototype showcase video, and a one-page project poster.
