"""Read-only parameterised queries used by the prototype UI."""

from __future__ import annotations

from app.db import get_connection


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

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
            return cur.fetchall()


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

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (subject_area, subject_area))
            return cur.fetchall()

