"""Read-only parameterised queries used by the Streamlit prototype."""

from __future__ import annotations

try:  # Supports both `streamlit run app/app.py` and package-based tests.
    from .db import get_connection
except ImportError:  # pragma: no cover - used when Streamlit runs this directory as a script.
    from db import get_connection


def _fetch_all(sql: str, params: tuple = ()) -> list[dict]:
    """Execute a read-only parameterised query and return dictionary rows."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()


def list_regions() -> list[dict]:
    """Return all regions in priority order for the dashboard."""
    sql = """
        SELECT region_id, region_name, remoteness_level,
               internet_access_level, support_priority_level
        FROM region
        ORDER BY CASE support_priority_level
            WHEN 'critical' THEN 1
            WHEN 'high' THEN 2
            WHEN 'medium' THEN 3
            ELSE 4
        END, region_name;
    """

    return _fetch_all(sql)


def list_offerings(subject_area: str | None = None) -> list[dict]:
    """Return current resource offerings and remaining capacity.

    The optional subject filter uses a bound parameter rather than SQL string
    interpolation, preventing SQL injection.
    """
    sql = """
        SELECT ro.offering_id,
               ro.resource_name,
               ro.resource_type,
               ro.subject_area,
               cap.remaining_quantity,
               ro.expiry_date,
               et.type_name AS required_eligibility
        FROM resource_offering AS ro
        JOIN v_offering_capacity AS cap ON cap.offering_id = ro.offering_id
        LEFT JOIN eligibility_type AS et
            ON et.eligibility_type_id = ro.required_eligibility_type_id
        WHERE (%s IS NULL OR ro.subject_area = %s)
        ORDER BY ro.expiry_date, ro.resource_name;
    """

    return _fetch_all(sql, (subject_area, subject_area))


def list_students() -> list[dict]:
    """Return students with their school and regional context."""
    return _fetch_all("""
        SELECT s.student_id,
               s.first_name || ' ' || s.last_name AS student_name,
               s.year_level,
               s.has_device,
               s.internet_access_level,
               sc.school_name,
               r.region_name
        FROM student AS s
        JOIN school AS sc ON sc.school_id = s.school_id
        JOIN region AS r ON r.region_id = sc.region_id
        ORDER BY sc.school_name, s.last_name, s.first_name;
    """)


def list_coordinators() -> list[dict]:
    """Return coordinators for the coordinator workflow."""
    return _fetch_all("""
        SELECT c.coordinator_id,
               c.coordinator_name,
               c.role,
               sc.school_name
        FROM coordinator AS c
        JOIN school AS sc ON sc.school_id = c.school_id
        ORDER BY sc.school_name, c.coordinator_name;
    """)


def list_suitable_offerings(student_id: int) -> list[dict]:
    """Find unexpired, eligible offerings with remaining capacity for one student."""
    return _fetch_all("""
        SELECT ro.offering_id,
               ro.resource_name,
               ro.resource_type,
               ro.subject_area,
               cap.remaining_quantity,
               ro.expiry_date,
               et.type_name AS required_eligibility
        FROM resource_offering AS ro
        JOIN v_offering_capacity AS cap ON cap.offering_id = ro.offering_id
        LEFT JOIN eligibility_type AS et
            ON et.eligibility_type_id = ro.required_eligibility_type_id
        WHERE ro.expiry_date >= CURRENT_DATE
          AND cap.remaining_quantity > 0
          AND (
                ro.required_eligibility_type_id IS NULL
                OR EXISTS (
                    SELECT 1
                    FROM student_eligibility AS se
                    WHERE se.student_id = %s
                      AND se.eligibility_type_id = ro.required_eligibility_type_id
                      AND se.verification_status = 'verified'
                      AND (se.expiry_date IS NULL OR se.expiry_date >= CURRENT_DATE)
                )
          )
        ORDER BY ro.subject_area, ro.resource_name;
    """, (student_id,))


def list_student_applications(student_id: int) -> list[dict]:
    """Return application outcomes and allocation progress for a student."""
    return _fetch_all("""
        SELECT ap.application_id,
               ro.resource_name,
               ap.application_date,
               ap.requested_quantity,
               fulfil.allocated_quantity,
               fulfil.quantity_still_requested,
               ap.priority_level,
               ap.decision_status,
               ap.decision_reason
        FROM application AS ap
        JOIN resource_offering AS ro ON ro.offering_id = ap.offering_id
        JOIN v_application_fulfilment AS fulfil
            ON fulfil.application_id = ap.application_id
        WHERE ap.student_id = %s
        ORDER BY ap.application_date DESC, ap.application_id DESC;
    """, (student_id,))


def list_review_queue(coordinator_id: int) -> list[dict]:
    """Return pending applications only for students at a coordinator's school."""
    return _fetch_all("""
        SELECT ap.application_id,
               s.first_name || ' ' || s.last_name AS student_name,
               sc.school_name,
               r.support_priority_level AS regional_priority,
               ro.resource_name,
               ap.requested_quantity,
               fulfil.allocated_quantity,
               fulfil.quantity_still_requested,
               cap.remaining_quantity,
               ap.learning_goal,
               ap.priority_level,
               ap.application_date
        FROM application AS ap
        JOIN student AS s ON s.student_id = ap.student_id
        JOIN school AS sc ON sc.school_id = s.school_id
        JOIN region AS r ON r.region_id = sc.region_id
        JOIN resource_offering AS ro ON ro.offering_id = ap.offering_id
        JOIN v_application_fulfilment AS fulfil
            ON fulfil.application_id = ap.application_id
        JOIN v_offering_capacity AS cap ON cap.offering_id = ro.offering_id
        JOIN coordinator AS c ON c.school_id = sc.school_id
        WHERE c.coordinator_id = %s
          AND ap.decision_status = 'pending'
        ORDER BY CASE ap.priority_level
            WHEN 'urgent' THEN 1
            WHEN 'high' THEN 2
            WHEN 'medium' THEN 3
            ELSE 4
        END,
        CASE r.support_priority_level
            WHEN 'critical' THEN 1
            WHEN 'high' THEN 2
            WHEN 'medium' THEN 3
            ELSE 4
        END,
        ap.application_date;
    """, (coordinator_id,))


def list_allocations() -> list[dict]:
    """Return allocations suitable for adding usage records."""
    return _fetch_all("""
        SELECT al.allocation_id,
               s.first_name || ' ' || s.last_name AS student_name,
               ro.resource_name,
               al.quantity_allocated,
               al.allocation_status,
               al.allocation_date
        FROM allocation AS al
        JOIN application AS ap ON ap.application_id = al.application_id
        JOIN student AS s ON s.student_id = ap.student_id
        JOIN resource_offering AS ro ON ro.offering_id = ap.offering_id
        WHERE al.allocation_status = 'active'
        ORDER BY al.allocation_date DESC;
    """)


def dashboard_metrics() -> dict:
    """Return headline counts for the dashboard."""
    rows = _fetch_all("""
        SELECT
            (SELECT COUNT(*) FROM student) AS students,
            (SELECT COUNT(*) FROM application
             WHERE decision_status = 'pending') AS pending_applications,
            (SELECT COUNT(*) FROM allocation
             WHERE allocation_status = 'active') AS active_allocations,
            (SELECT COUNT(*) FROM v_offering_capacity
             WHERE remaining_quantity = 0) AS exhausted_offerings;
    """)
    return rows[0]


def utilisation_report() -> list[dict]:
    """Compare supply, allocation, demand, and recorded usage for each offering."""
    return _fetch_all("""
        SELECT ro.resource_name,
               ro.resource_type,
               ro.subject_area,
               ro.total_quantity,
               cap.allocated_quantity,
               cap.remaining_quantity,
               COUNT(DISTINCT ap.application_id)
                   FILTER (WHERE ap.decision_status = 'pending') AS pending_applications,
               COUNT(DISTINCT ap.application_id)
                   FILTER (WHERE ap.decision_status = 'rejected') AS rejected_applications,
               COUNT(ur.record_no)
                   FILTER (WHERE ur.usage_status = 'completed') AS completed_usage_records
        FROM resource_offering AS ro
        JOIN v_offering_capacity AS cap ON cap.offering_id = ro.offering_id
        LEFT JOIN application AS ap ON ap.offering_id = ro.offering_id
        LEFT JOIN allocation AS al ON al.application_id = ap.application_id
        LEFT JOIN usage_record AS ur ON ur.allocation_id = al.allocation_id
        GROUP BY ro.offering_id, ro.resource_name, ro.resource_type,
                 ro.subject_area, ro.total_quantity, cap.allocated_quantity,
                 cap.remaining_quantity
        ORDER BY ro.resource_name;
    """)

