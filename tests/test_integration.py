import csv
import io
import re
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

import psycopg
import pytest

from resource_hub import gateway as b
from conftest import SOURCE, TEST_PASSWORD, login, post, submit


def state(application_id):
    return b.select("SELECT * FROM application WHERE application_id=%s", (application_id,))[0]


def capacity(offering=8):
    return b.select("SELECT remaining_quantity FROM v_offering_capacity WHERE offering_id=%s", (offering,))[0]["remaining_quantity"]


@pytest.mark.parametrize("path", ["/", "/resources", "/applications", "/applications/new"])
def test_student_pages(client, path):
    login(client)
    response = client.get(path)
    assert response.status_code == 200
    assert "B Python backend connected" in response.text
    assert '<html lang="en">' in response.text
    assert not re.search(r"[\u3400-\u9fff]", response.text)


@pytest.mark.parametrize("path", ["/", "/resources", "/applications", "/reports", "/usage"])
def test_coordinator_pages(client, path):
    login(client, "coordinator")
    response = client.get(path)
    assert response.status_code == 200
    assert '<html lang="en">' in response.text
    assert not re.search(r"[\u3400-\u9fff]", response.text)


def test_full_workflow_uses_B_and_updates_reports(client):
    login(client)
    before = capacity()
    response = post(client, "/applications/new", {"resource_id": 8, "quantity": 2, "purpose": "Use the study library for independent remote learning.", "priority": "high"})
    assert response.status_code == 302
    application_id = int(response.location.rsplit("/", 1)[-1])
    assert state(application_id)["decision_status"] == "pending"
    assert capacity() == before
    login(client, "coordinator")
    post(client, f"/applications/{application_id}/approve", {"allocation_quantity": 2, "note": "Verified learning need"})
    assert state(application_id)["decision_status"] == "approved"
    assert capacity() == before - 2
    allocation = b.allocation_details(application_id)[0]
    response = post(client, "/usage", {"allocation_id": allocation["allocation_id"], "usage_type": "offline_study", "usage_status": "completed", "notes": "First module completed"})
    assert response.status_code == 302
    assert b.usage_details(application_id)[0]["notes"] == "First module completed"
    assert "saved" in client.get("/usage").text
    report = client.get("/reports.csv")
    rows = list(csv.reader(io.StringIO(report.data.decode("utf-8-sig"))))
    assert rows[0][0] == "Application ID"
    assert not re.search(r"[\u3400-\u9fff]", report.data.decode("utf-8-sig"))
    assert any(row[0] == str(application_id) and row[5] == "2" for row in rows[1:])


def test_csrf_and_role_permissions(client):
    assert client.get("/").status_code == 302
    login(client)
    assert client.post("/applications/new", data={"quantity": 1}).status_code == 400
    for path in ("/reports", "/reports.csv", "/usage"):
        assert client.get(path).status_code == 403
    application_id = submit()
    assert post(client, f"/applications/{application_id}/approve", {"allocation_quantity": 1}).status_code == 403


def test_student_cannot_read_another_student_application(client):
    application_id = submit(student=3)
    login(client)
    assert client.get(f"/applications/{application_id}").status_code == 404


def test_coordinator_cannot_read_or_write_other_school(client):
    application_id = submit(student=3)
    login(client, "coordinator")
    assert client.get(f"/applications/{application_id}").status_code == 404
    assert post(client, f"/applications/{application_id}/approve", {"allocation_quantity": 1}).status_code == 404
    assert state(application_id)["decision_status"] == "pending"
    text = client.get("/reports.csv").data.decode("utf-8-sig")
    assert "Sophie Johnson" not in text


def test_B_rejects_cross_school_and_rolls_back():
    application_id = submit(student=3)
    with pytest.raises(b.services.BusinessRuleError, match="own school"):
        b.services.approve_and_allocate(application_id, 1, 1, "invalid school")
    assert state(application_id)["reviewer_id"] is None
    assert not b.allocation_details(application_id)


@pytest.mark.parametrize("quantity", [0, -1, 9999])
def test_invalid_request_quantities(client, quantity):
    login(client)
    response = post(client, "/applications/new", {"resource_id": 8, "quantity": quantity, "purpose": "A sufficiently detailed learning goal.", "priority": "medium"})
    assert response.status_code == 400


def test_duplicate_submission_is_explained(client):
    login(client)
    form = {"resource_id": 8, "quantity": 1, "purpose": "A sufficiently detailed learning goal.", "priority": "medium"}
    assert post(client, "/applications/new", form).status_code == 302
    response = post(client, "/applications/new", form)
    assert response.status_code == 409
    assert "already submitted" in response.text


def test_invalid_identity_and_priority(client):
    client.get("/login")
    assert post(client, "/login", {"username": "560601108", "password": TEST_PASSWORD, "identity": "admin:1"}).status_code == 401
    login(client)
    assert post(client, "/applications/new", {"resource_id": 8, "quantity": 1, "purpose": "Detailed learning requirement.", "priority": "admin"}).status_code == 400


def test_capacity_failure_rolls_back_all_changes():
    application_id = submit(quantity=2)
    with b.db.get_connection() as conn:
        conn.execute("UPDATE resource_offering SET total_quantity=1 WHERE offering_id=8")
    before = capacity()
    with pytest.raises(b.services.BusinessRuleError, match="capacity"):
        b.services.approve_and_allocate(application_id, 1, 2, "Must fail")
    row = state(application_id)
    assert row["decision_status"] == "pending" and row["reviewer_id"] is None and row["decision_reason"] is None
    assert not b.allocation_details(application_id)
    assert capacity() == before


def test_expired_resource_rolls_back():
    application_id = submit()
    with b.db.get_connection() as conn:
        conn.execute("UPDATE resource_offering SET expiry_date=CURRENT_DATE-1 WHERE offering_id=8")
    with pytest.raises(b.services.BusinessRuleError, match="Expired"):
        b.services.approve_and_allocate(application_id, 1, 1, "Must fail")
    assert state(application_id)["decision_status"] == "pending"
    assert not b.allocation_details(application_id)


def test_missing_eligibility_rolls_back():
    application_id = submit(student=2, offering=3)
    with pytest.raises(b.services.BusinessRuleError, match="eligibility"):
        b.services.approve_and_allocate(application_id, 1, 1, "Must fail")
    assert state(application_id)["decision_status"] == "pending"
    assert not b.allocation_details(application_id)


def test_expired_eligibility_rolls_back():
    application_id = submit(offering=3)
    with b.db.get_connection() as conn:
        conn.execute("UPDATE student_eligibility SET verified_date=CURRENT_DATE-10,expiry_date=CURRENT_DATE-1 WHERE student_id=1")
    with pytest.raises(b.services.BusinessRuleError, match="eligibility"):
        b.services.approve_and_allocate(application_id, 1, 1, "Must fail")
    assert not b.allocation_details(application_id)


def test_reject_and_cannot_reapprove(client):
    application_id = submit()
    login(client, "coordinator")
    post(client, f"/applications/{application_id}/reject", {"note": ""})
    assert state(application_id)["decision_status"] == "pending"
    post(client, f"/applications/{application_id}/reject", {"note": "Need more learning detail"})
    assert state(application_id)["decision_status"] == "rejected"
    with pytest.raises(b.services.BusinessRuleError, match="pending"):
        b.services.approve_and_allocate(application_id, 1, 1, "invalid")


def test_repeat_approval_does_not_double_allocate(client):
    application_id = submit()
    login(client, "coordinator")
    before = capacity()
    for _ in range(2):
        post(client, f"/applications/{application_id}/approve", {"allocation_quantity": 1, "note": "Approved"})
    assert len(b.allocation_details(application_id)) == 1
    assert capacity() == before - 1


def test_partial_allocation_is_visible_and_bounded(client):
    application_id = submit(quantity=3)
    b.services.approve_and_allocate(application_id, 1, 1, "Partial support")
    login(client)
    assert "3 / 1 / 2" in client.get(f"/applications/{application_id}").text
    with pytest.raises(b.services.BusinessRuleError):
        b.services.approve_and_allocate(application_id, 1, 1, "B currently cannot top up approved requests")


def test_over_request_allocation_rolls_back():
    application_id = submit()
    with pytest.raises(b.services.BusinessRuleError, match="remaining request"):
        b.services.approve_and_allocate(application_id, 1, 2, "invalid")
    assert state(application_id)["decision_status"] == "pending"


def test_usage_sequence_and_return_does_not_release_stock():
    application_id = submit()
    allocation_id = b.services.approve_and_allocate(application_id, 1, 1, "Approved")
    before = capacity()
    assert b.services.add_usage_record(allocation_id, "learning", "completed", "one") == 1
    assert b.services.add_usage_record(allocation_id, "delivery", "returned", "two") == 2
    assert capacity() == before


def test_usage_cannot_target_other_school(client):
    application_id = submit(student=3)
    allocation_id = b.services.approve_and_allocate(application_id, 2, 1, "Approved")
    login(client, "coordinator")
    response = post(client, "/usage", {"allocation_id": allocation_id, "usage_type": "test", "usage_status": "completed"})
    assert response.status_code == 404
    assert not b.usage_details(application_id)


def test_suitable_search_and_query_injection(client):
    login(client)
    response = client.get("/resources?suitable=1")
    assert "Refurbished Learning Device" in response.text
    assert "Satellite Internet Learning Voucher" not in response.text
    assert "Refurbished Learning Device" in client.get("/resources?q=device").text
    assert client.get("/resources?q=%27%20OR%201%3D1--").status_code == 200
    assert b.queries.list_offerings("' OR 1=1--") == []


def test_csv_formula_and_html_escaping(client):
    application_id = submit(goal="=HYPERLINK(\"example\") <script>alert(1)</script>")
    login(client)
    response = client.get(f"/applications/{application_id}")
    assert "<script>alert(1)</script>" not in response.text
    assert "&lt;script&gt;" in response.text
    login(client, "coordinator")
    response = client.get("/reports.csv")
    rows = list(csv.reader(io.StringIO(response.data.decode("utf-8-sig"))))
    assert next(r for r in rows[1:] if r[0] == str(application_id))[8].startswith("'=HYPERLINK")
    resource_csv = client.get("/reports.csv?kind=utilisation")
    assert len(list(csv.reader(io.StringIO(resource_csv.data.decode("utf-8-sig"))))) == 9


def test_original_database_negative_constraints():
    notices = []
    with b.db.get_connection() as conn:
        conn.add_notice_handler(lambda notice: notices.append(notice.message_primary))
        conn.execute((SOURCE / "constraint_tests.sql").read_text())
    assert len([n for n in notices if n.startswith("PASS:")]) == 5


def test_concurrent_approvals_cannot_oversubscribe():
    with b.db.get_connection() as conn:
        # Offering 8 already has seeded allocations; retain exactly one free unit.
        conn.execute("UPDATE resource_offering SET total_quantity=(SELECT allocated_quantity+1 FROM v_offering_capacity WHERE offering_id=8) WHERE offering_id=8")
    first, second = submit(student=1), submit(student=2)
    barrier = Barrier(2)
    def approve(application_id):
        barrier.wait(timeout=10)
        try:
            b.services.approve_and_allocate(application_id, 1, 1, "Concurrent review")
            return "approved"
        except b.services.BusinessRuleError:
            return "blocked"
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(approve, [first, second]))
    assert sorted(results) == ["approved", "blocked"]
    assert capacity() == 0
    assert sum(len(b.allocation_details(app_id)) for app_id in (first, second)) == 1


def test_demo_login_can_be_disabled(app):
    app.config["DEMO_LOGIN"] = False
    assert app.test_client().get("/login").status_code == 403


def test_health_checks_real_postgres(client):
    response = client.get("/health")
    assert response.status_code == 200 and response.json["offerings"] == 8
    assert response.json["backend"] == "B Python + PostgreSQL"
