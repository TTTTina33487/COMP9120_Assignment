"""Write operations and transactions for the Remote Education prototype."""

from __future__ import annotations

import psycopg

try:  # Supports both `streamlit run app/app.py` and package-based tests.
    from .db import get_connection
except ImportError:  # pragma: no cover - used when Streamlit runs this directory as a script.
    from db import get_connection


class BusinessRuleError(ValueError):
    """Raised when a requested operation violates a project business rule."""


def submit_application(
    student_id: int,
    offering_id: int,
    requested_quantity: int,
    learning_goal: str,
    priority_level: str,
) -> int:
    """Create a pending application and return its identifier."""
    if requested_quantity <= 0:
        raise BusinessRuleError("Requested quantity must be greater than zero.")
    if not learning_goal.strip():
        raise BusinessRuleError("A learning goal is required.")

    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO application (
                        student_id, offering_id, requested_quantity,
                        learning_goal, priority_level, decision_status
                    )
                    VALUES (%s, %s, %s, %s, %s, 'pending')
                    RETURNING application_id;
                """, (
                    student_id,
                    offering_id,
                    requested_quantity,
                    learning_goal.strip(),
                    priority_level,
                ))
                return cur.fetchone()["application_id"]
    except psycopg.errors.UniqueViolation as error:
        raise BusinessRuleError(
            "This student has already submitted an application for this offering today."
        ) from error


def approve_and_allocate(
    application_id: int,
    coordinator_id: int,
    allocation_quantity: int,
    decision_reason: str,
) -> int:
    """Approve a pending application and create an allocation atomically.

    The application and its offering are locked before capacity is calculated.
    Therefore concurrent approvals for the same offering cannot over-allocate it.
    Any failed validation raises an exception and rolls back every change.
    """
    if allocation_quantity <= 0:
        raise BusinessRuleError("Allocation quantity must be greater than zero.")

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT ap.application_id,
                       ap.student_id,
                       ap.requested_quantity,
                       ap.decision_status,
                       s.school_id AS student_school_id,
                       ro.offering_id,
                       ro.total_quantity,
                       ro.expiry_date,
                       ro.required_eligibility_type_id
                FROM application AS ap
                JOIN student AS s ON s.student_id = ap.student_id
                JOIN resource_offering AS ro ON ro.offering_id = ap.offering_id
                WHERE ap.application_id = %s
                FOR UPDATE OF ap, ro;
            """, (application_id,))
            application = cur.fetchone()

            if application is None:
                raise BusinessRuleError("Application not found.")
            if application["decision_status"] != "pending":
                raise BusinessRuleError("Only pending applications can be approved.")

            cur.execute("""
                SELECT 1
                FROM coordinator
                WHERE coordinator_id = %s AND school_id = %s;
            """, (coordinator_id, application["student_school_id"]))
            if cur.fetchone() is None:
                raise BusinessRuleError(
                    "A coordinator may only review applications from their own school."
                )

            if application["expiry_date"] < _database_today(cur):
                raise BusinessRuleError("Expired resource offerings cannot be allocated.")

            required_type_id = application["required_eligibility_type_id"]
            if required_type_id is not None:
                cur.execute("""
                    SELECT 1
                    FROM student_eligibility
                    WHERE student_id = %s
                      AND eligibility_type_id = %s
                      AND verification_status = 'verified'
                      AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE);
                """, (application["student_id"], required_type_id))
                if cur.fetchone() is None:
                    raise BusinessRuleError(
                        "The student does not have verified, unexpired eligibility for this offering."
                    )

            cur.execute("""
                SELECT COALESCE(SUM(quantity_allocated)
                           FILTER (WHERE allocation_status IN ('active', 'completed')), 0)
                           AS already_allocated
                FROM allocation
                WHERE application_id = %s;
            """, (application_id,))
            allocated_for_application = cur.fetchone()["already_allocated"]

            cur.execute("""
                SELECT COALESCE(SUM(al.quantity_allocated)
                           FILTER (WHERE al.allocation_status IN ('active', 'completed')), 0)
                           AS already_allocated
                FROM allocation AS al
                JOIN application AS other_ap
                    ON other_ap.application_id = al.application_id
                WHERE other_ap.offering_id = %s;
            """, (application["offering_id"],))
            allocated_for_offering = cur.fetchone()["already_allocated"]

            still_requested = application["requested_quantity"] - allocated_for_application
            remaining_capacity = application["total_quantity"] - allocated_for_offering

            if allocation_quantity > still_requested:
                raise BusinessRuleError(
                    f"Allocation exceeds the application's remaining request ({still_requested})."
                )
            if allocation_quantity > remaining_capacity:
                raise BusinessRuleError(
                    f"Allocation exceeds remaining offering capacity ({remaining_capacity})."
                )

            cur.execute("""
                UPDATE application
                SET reviewer_id = %s,
                    decision_status = 'approved',
                    decision_date = CURRENT_TIMESTAMP,
                    decision_reason = %s
                WHERE application_id = %s;
            """, (coordinator_id, decision_reason.strip() or "Approved and allocated.", application_id))

            cur.execute("""
                INSERT INTO allocation (application_id, quantity_allocated, allocation_status)
                VALUES (%s, %s, 'active')
                RETURNING allocation_id;
            """, (application_id, allocation_quantity))
            return cur.fetchone()["allocation_id"]


def reject_application(
    application_id: int,
    coordinator_id: int,
    decision_reason: str,
) -> None:
    """Reject a pending application after verifying the coordinator's school."""
    if not decision_reason.strip():
        raise BusinessRuleError("A rejection reason is required.")

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT ap.decision_status, s.school_id
                FROM application AS ap
                JOIN student AS s ON s.student_id = ap.student_id
                WHERE ap.application_id = %s
                FOR UPDATE OF ap;
            """, (application_id,))
            application = cur.fetchone()
            if application is None:
                raise BusinessRuleError("Application not found.")
            if application["decision_status"] != "pending":
                raise BusinessRuleError("Only pending applications can be rejected.")

            cur.execute("""
                SELECT 1 FROM coordinator
                WHERE coordinator_id = %s AND school_id = %s;
            """, (coordinator_id, application["school_id"]))
            if cur.fetchone() is None:
                raise BusinessRuleError(
                    "A coordinator may only review applications from their own school."
                )

            cur.execute("""
                UPDATE application
                SET reviewer_id = %s,
                    decision_status = 'rejected',
                    decision_date = CURRENT_TIMESTAMP,
                    decision_reason = %s
                WHERE application_id = %s;
            """, (coordinator_id, decision_reason.strip(), application_id))


def add_usage_record(
    allocation_id: int,
    usage_type: str,
    usage_status: str,
    notes: str,
) -> int:
    """Add the next sequential usage record for an active allocation."""
    if not usage_type.strip():
        raise BusinessRuleError("Usage type is required.")

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT allocation_id
                FROM allocation
                WHERE allocation_id = %s AND allocation_status = 'active'
                FOR UPDATE;
            """, (allocation_id,))
            if cur.fetchone() is None:
                raise BusinessRuleError("An active allocation was not found.")

            cur.execute("""
                SELECT COALESCE(MAX(record_no), 0) + 1 AS next_record_no
                FROM usage_record
                WHERE allocation_id = %s;
            """, (allocation_id,))
            record_no = cur.fetchone()["next_record_no"]

            cur.execute("""
                INSERT INTO usage_record (
                    allocation_id, record_no, usage_type, usage_status, notes
                )
                VALUES (%s, %s, %s, %s, %s)
                RETURNING record_no;
            """, (allocation_id, record_no, usage_type.strip(), usage_status, notes.strip() or None))
            return cur.fetchone()["record_no"]


def _database_today(cursor: psycopg.Cursor):
    """Read CURRENT_DATE from PostgreSQL, avoiding client/server date drift."""
    cursor.execute("SELECT CURRENT_DATE AS today;")
    return cursor.fetchone()["today"]
