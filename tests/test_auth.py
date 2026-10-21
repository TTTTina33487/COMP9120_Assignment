"""Credential, session and account-to-workspace authorization tests."""
import pytest
from werkzeug.security import generate_password_hash

from resource_hub.auth import DEFAULT_IDENTITIES
from conftest import TEST_PASSWORD, login, post


def test_sign_in_form_requires_account_and_masked_password(client):
    response = client.get("/login")
    assert response.status_code == 200
    assert 'name="username"' in response.text
    assert 'name="password" type="password"' in response.text
    assert TEST_PASSWORD not in response.text


def test_correct_credentials_open_default_student_workspace(client):
    client.get("/login")
    with client.session_transaction() as session:
        previous_csrf = session["csrf_token"]
    response = post(client, "/login", {"username": "560601108", "password": TEST_PASSWORD})
    assert response.status_code == 302 and response.location == "/"
    with client.session_transaction() as session:
        assert session["account_username"] == "560601108"
        assert session["user_id"] == 1 and session["role"] == "student"
        assert session["csrf_token"] != previous_csrf
        assert "password" not in session
    assert "Welcome back, Ava Mitchell" in client.get("/").text


@pytest.mark.parametrize("username,password", [
    ("560601108", "wrong-password"),
    ("unknown-account", TEST_PASSWORD),
    ("", ""),
    ("\u6e2c\u8a66", TEST_PASSWORD),
])
def test_bad_credentials_do_not_create_authenticated_session(client, username, password):
    client.get("/login")
    response = post(client, "/login", {"username": username, "password": password, "identity": "student:1"})
    assert response.status_code == 401
    assert "Invalid account, password or workspace" in response.text
    assert client.get("/").status_code == 302
    with client.session_transaction() as session:
        assert "account_username" not in session and "user_id" not in session


def test_identity_only_login_cannot_bypass_password(client):
    client.get("/login")
    assert post(client, "/login", {"identity": "coordinator:1"}).status_code == 401
    assert client.get("/reports").status_code == 302


def test_account_cannot_select_an_unbound_workspace(app, client):
    app.config["DEMO_IDENTITIES"] = DEFAULT_IDENTITIES
    response = client.get("/login")
    assert 'value="coordinator:2"' not in response.text
    assert 'value="student:3"' not in response.text
    response = post(client, "/login", {"username": "560601108", "password": TEST_PASSWORD, "identity": "coordinator:2"})
    assert response.status_code == 401
    assert client.get("/reports").status_code == 302


def test_old_role_only_cookie_is_not_an_authenticated_session(client):
    with client.session_transaction() as session:
        session.update(user_id=1, role="coordinator")
    assert client.get("/reports").status_code == 302


def test_logout_revokes_workspace_access(client):
    login(client, "coordinator")
    assert client.get("/reports").status_code == 200
    assert post(client, "/logout").status_code == 302
    assert client.get("/reports").status_code == 302


def test_changing_credentials_invalidates_existing_sessions(app, client):
    login(client)
    assert client.get("/").status_code == 200
    app.config["DEMO_PASSWORD_HASH"] = generate_password_hash("replacement-test-password")
    assert client.get("/").status_code == 302


def test_sign_in_still_requires_csrf(client):
    client.get("/login")
    response = client.post("/login", data={"username": "560601108", "password": TEST_PASSWORD})
    assert response.status_code == 400
    assert client.get("/").status_code == 302
