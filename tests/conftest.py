"""Integration tests use an owned temporary PostgreSQL database, never demo data."""
import os
from pathlib import Path
from uuid import uuid4

import psycopg
import pytest
from psycopg import sql
from psycopg.conninfo import make_conninfo
from werkzeug.security import generate_password_hash

from app import create_app
from resource_hub import gateway as b

SOURCE = Path(__file__).resolve().parents[1] / "COMP9120_Assignment-feature-python-prototype/database"
TEST_PASSWORD = "integration-test-password"
TEST_PASSWORD_HASH = generate_password_hash(TEST_PASSWORD)


@pytest.fixture(scope="session")
def isolated_url():
    base = os.environ.get("DATABASE_URL")
    if not base:
        pytest.fail("Source scripts/env.sh and run scripts/database.sh before integration tests.")
    name = "hub_test_" + uuid4().hex[:16]
    admin = make_conninfo(base, dbname="postgres")
    with psycopg.connect(admin, autocommit=True) as conn:
        conn.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(name)))
    try:
        yield make_conninfo(base, dbname=name)
    finally:
        with psycopg.connect(admin, autocommit=True) as conn:
            conn.execute(sql.SQL("DROP DATABASE {} WITH (FORCE)").format(sql.Identifier(name)))


@pytest.fixture(autouse=True)
def data(isolated_url, monkeypatch):
    monkeypatch.setenv("DATABASE_URL", isolated_url)
    with psycopg.connect(isolated_url, autocommit=True) as conn:
        conn.execute("DROP SCHEMA IF EXISTS remote_education CASCADE")
        conn.execute((SOURCE / "schema.sql").read_text())
        conn.execute((SOURCE / "seed.sql").read_text())
        # Original demo dates are fixed. Relative dates keep isolated tests useful
        # after 2027 without modifying seed files or the real demonstration DB.
        conn.execute("UPDATE remote_education.resource_offering SET expiry_date=CURRENT_DATE+365")
        conn.execute("UPDATE remote_education.student_eligibility SET verified_date=CURRENT_DATE-1,expiry_date=CURRENT_DATE+365 WHERE verification_status='verified'")
    return {"student": 1, "coordinator": 1, "other_student": 3, "other_coordinator": 2,
            "offering": 8, "device": 3}


@pytest.fixture
def app():
    return create_app({"TESTING": True, "SECRET_KEY": "isolated-test-key",
                       "DEMO_PASSWORD_HASH": TEST_PASSWORD_HASH,
                       "DEMO_IDENTITIES": ("student:1", "student:2", "student:3", "coordinator:1", "coordinator:2")})


@pytest.fixture
def client(app):
    return app.test_client()


def login(client, role="student", actor_id=1):
    client.get("/login")
    return post(client, "/login", {"username": "560601108", "password": TEST_PASSWORD, "identity": f"{role}:{actor_id}"})


def post(client, path, data=None, **kwargs):
    with client.session_transaction() as session:
        token = session["csrf_token"]
    return client.post(path, data=dict(data or {}, csrf_token=token), **kwargs)


def submit(student=1, offering=8, quantity=1, goal="Complete remote education lessons with accessible learning materials."):
    return b.services.submit_application(student, offering, quantity, goal, "high")
