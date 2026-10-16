"""Run with: python -m app.test_connection"""

from __future__ import annotations

import sys

import psycopg

try:  # Supports `python -m app.test_connection`.
    from .db import get_connection
except ImportError:  # Supports `python app/test_connection.py`.
    from db import get_connection


def main() -> int:
    """Check that Python can connect to the expected database and schema."""
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT current_database() AS database_name;")
                database = cur.fetchone()["database_name"]

                cur.execute("SELECT current_schema() AS schema_name;")
                schema = cur.fetchone()["schema_name"]

                cur.execute("SELECT COUNT(*) AS region_count FROM region;")
                region_count = cur.fetchone()["region_count"]

        print("Database connection successful.")
        print(f"Database: {database}")
        print(f"Schema: {schema}")
        print(f"Regions found: {region_count}")
        return 0

    except (RuntimeError, psycopg.Error) as error:
        print("Database connection failed.", file=sys.stderr)
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
