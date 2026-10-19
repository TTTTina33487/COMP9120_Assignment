"""Initialize only an absent project schema; never reset an existing database."""
import os
from pathlib import Path

import psycopg
from psycopg import sql
from psycopg.conninfo import conninfo_to_dict, make_conninfo


def main():
    url = os.environ["DATABASE_URL"]
    options = conninfo_to_dict(url)
    database = options.get("dbname", "remote_education_db")
    admin_url = make_conninfo(url, dbname="postgres")
    with psycopg.connect(admin_url, autocommit=True) as conn:
        if not conn.execute("SELECT 1 FROM pg_database WHERE datname=%s", (database,)).fetchone():
            conn.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(database)))
    source = Path(__file__).resolve().parents[1] / "COMP9120_Assignment-feature-python-prototype/database"
    with psycopg.connect(url, autocommit=True) as conn:
        exists = conn.execute("SELECT to_regclass('remote_education.region')").fetchone()[0]
        if exists is None:
            conn.execute((source / "schema.sql").read_text())
            conn.execute((source / "seed.sql").read_text())
            print("Initialized original PostgreSQL schema and synthetic seed data.")
        else:
            print("Existing project data preserved; no schema/seed scripts reapplied.")
        count = conn.execute("SELECT COUNT(*) FROM remote_education.resource_offering").fetchone()[0]
        print(f"Database ready: {count} resource offerings.")


if __name__ == "__main__":
    main()
