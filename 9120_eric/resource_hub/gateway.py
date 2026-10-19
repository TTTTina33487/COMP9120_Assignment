"""UI adapter over B's unmodified PostgreSQL Python package.

Load the supplied package under a distinct name because its original name
(`app`) would collide with the Flask entry point. All business writes are
delegated to B's services; extra SELECTs supply UI detail and school scoping.
"""
import importlib
import importlib.util
import sys
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / "COMP9120_Assignment-feature-python-prototype" / "app"
if "project_backend" not in sys.modules:
    spec = importlib.util.spec_from_file_location("project_backend", SOURCE / "__init__.py", submodule_search_locations=[str(SOURCE)])
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
queries = importlib.import_module("project_backend.queries")
services = importlib.import_module("project_backend.services")
db = importlib.import_module("project_backend.db")


def select(sql, params=()):
    with db.get_connection() as conn:
        return conn.execute(sql, params).fetchall()


def identities():
    return queries.list_students(), queries.list_coordinators()


def actor(role, actor_id):
    if role == "student":
        rows = select("""SELECT student_id AS id,first_name || ' ' || last_name AS name,
            school_id FROM student WHERE student_id=%s""", (actor_id,))
    elif role == "coordinator":
        rows = select("SELECT coordinator_id AS id,coordinator_name AS name,school_id FROM coordinator WHERE coordinator_id=%s", (actor_id,))
    else:
        return None
    return dict(rows[0], role=role) if rows else None


def resources(student_id=None):
    offerings = queries.list_offerings()
    details = {r["offering_id"]: r for r in select("""SELECT ro.offering_id, ro.total_quantity,
        o.organisation_name, CURRENT_DATE AS today FROM resource_offering ro
        JOIN organisation o ON o.organisation_id=ro.provider_id""")}
    suitable = {r["offering_id"] for r in queries.list_suitable_offerings(student_id)} if student_id else set()
    result = []
    for r in offerings:
        extra = details[r["offering_id"]]
        result.append(dict(r, id=r["offering_id"], name=r["resource_name"], category=r["subject_area"],
                           location=extra["organisation_name"], total=extra["total_quantity"],
                           available=r["remaining_quantity"], suitable=r["offering_id"] in suitable,
                           expired=r["expiry_date"] < extra["today"],
                           description=f"Type: {r['resource_type']} · Eligibility: {r['required_eligibility'] or 'No additional eligibility required'}"))
    return result


def applications(user):
    if user["role"] == "student":
        queries.list_student_applications(user["id"])
        clause, params = "ap.student_id=%s", (user["id"],)
    else:
        queries.list_review_queue(user["id"])
        clause, params = "s.school_id=%s", (user["school_id"],)
    return select(f"""SELECT ap.*,ap.application_id AS id,ap.offering_id AS resource_id,
        ap.requested_quantity AS quantity,ap.learning_goal AS purpose,
        ap.decision_status AS status,COALESCE(ap.decision_reason,'') AS review_note,
        ap.application_date::text AS created_at, s.first_name || ' ' || s.last_name AS student_name,
        sc.school_name,ro.resource_name,ro.subject_area AS category,
        o.organisation_name AS location,ro.total_quantity AS total,
        f.allocated_quantity,f.quantity_still_requested
        FROM application ap JOIN student s ON s.student_id=ap.student_id
        JOIN school sc ON sc.school_id=s.school_id
        JOIN resource_offering ro ON ro.offering_id=ap.offering_id
        JOIN organisation o ON o.organisation_id=ro.provider_id
        JOIN v_application_fulfilment f ON f.application_id=ap.application_id
        WHERE {clause} ORDER BY ap.application_date DESC,ap.application_id DESC""", params)


def allocation_details(application_id):
    return select("SELECT * FROM allocation WHERE application_id=%s ORDER BY allocation_id", (application_id,))


def usage_details(application_id):
    return select("""SELECT ur.* FROM usage_record ur JOIN allocation al USING(allocation_id)
        WHERE al.application_id=%s ORDER BY ur.record_date,ur.allocation_id,ur.record_no""", (application_id,))


def own_active_allocations(user):
    own_ids = {r["id"] for r in applications(user)}
    relation = {r["allocation_id"]: r["application_id"] for r in select(
        """SELECT al.allocation_id,al.application_id FROM allocation al JOIN application ap USING(application_id)
        JOIN student s USING(student_id) WHERE s.school_id=%s""", (user["school_id"],))}
    return [dict(r, application_id=relation[r["allocation_id"]]) for r in queries.list_allocations()
            if relation.get(r["allocation_id"]) in own_ids]
