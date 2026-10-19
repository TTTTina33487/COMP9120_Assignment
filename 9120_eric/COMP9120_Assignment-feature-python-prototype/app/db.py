"""PostgreSQL connection helpers for the Remote Education prototype."""

from __future__ import annotations

import os

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row


load_dotenv()


def get_connection() -> psycopg.Connection:
    """Return a connection configured to use the remote_education schema.

    Connection details are read from DATABASE_URL in the developer's local .env
    file. Credentials must never be hard-coded or committed to the repository.
    """
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError(
            "DATABASE_URL is missing. Copy .env.example to .env and set your "
            "local PostgreSQL credentials."
        )

    return psycopg.connect(
        database_url,
        row_factory=dict_row,
        options="-c search_path=remote_education,public",
    )

