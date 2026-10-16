"""Streamlit interface for the Remote Education Resource Allocation Platform."""

from __future__ import annotations

import psycopg
import streamlit as st

try:  # Supports package execution and Streamlit script execution.
    from . import queries
    from .services import (
        BusinessRuleError,
        add_usage_record,
        approve_and_allocate,
        reject_application,
        submit_application,
    )
except ImportError:  # pragma: no cover - used by `streamlit run app/app.py`.
    import queries
    from services import (
        BusinessRuleError,
        add_usage_record,
        approve_and_allocate,
        reject_application,
        submit_application,
    )


st.set_page_config(
    page_title="Remote Education Resource Allocation",
    page_icon="🎓",
    layout="wide",
)


def show_rows(rows: list[dict], empty_message: str) -> None:
    """Show query results consistently across pages."""
    if rows:
        st.dataframe(rows, use_container_width=True, hide_index=True)
    else:
        st.info(empty_message)


def label(row: dict, id_field: str, text: str) -> str:
    return f"{row[id_field]} - {text}"


def handle_error(error: Exception) -> None:
    """Show safe, useful errors while keeping database internals out of the UI."""
    if isinstance(error, BusinessRuleError):
        st.error(str(error))
    elif isinstance(error, psycopg.Error):
        st.error("Database operation failed. Please check the database setup and try again.")
    else:
        st.error(str(error))


def dashboard_page() -> None:
    st.title("Remote Education Resource Allocation Platform")
    st.caption("PostgreSQL-backed prototype for education support in remote regions")

    metrics = queries.dashboard_metrics()
    columns = st.columns(4)
    columns[0].metric("Students", metrics["students"])
    columns[1].metric("Pending applications", metrics["pending_applications"])
    columns[2].metric("Active allocations", metrics["active_allocations"])
    columns[3].metric("Exhausted offerings", metrics["exhausted_offerings"])

    st.subheader("Regional support priority")
    show_rows(queries.list_regions(), "No region data is available.")


def student_page() -> None:
    st.title("Student resource search and application")
    students = queries.list_students()
    if not students:
        st.warning("No students are available. Run database/seed.sql first.")
        return

    student_by_label = {
        label(row, "student_id", f"{row['student_name']} ({row['school_name']})"): row
        for row in students
    }
    selected_label = st.selectbox("Student", student_by_label)
    student = student_by_label[selected_label]

    st.caption(
        f"Year {student['year_level']} | {student['school_name']} | "
        f"Internet: {student['internet_access_level']}"
    )

    offerings = queries.list_suitable_offerings(student["student_id"])
    st.subheader("Suitable available resources")
    show_rows(offerings, "No current offerings meet this student's verified eligibility.")

    if offerings:
        offering_by_label = {
            label(
                row,
                "offering_id",
                f"{row['resource_name']} (remaining: {row['remaining_quantity']})",
            ): row
            for row in offerings
        }
        with st.form("submit_application_form"):
            offering_label = st.selectbox("Resource offering", offering_by_label)
            selected_offering = offering_by_label[offering_label]
            quantity = st.number_input(
                "Requested quantity",
                min_value=1,
                max_value=int(selected_offering["remaining_quantity"]),
                value=1,
                step=1,
            )
            learning_goal = st.text_area("Learning goal")
            priority = st.selectbox("Priority", ["low", "medium", "high", "urgent"], index=1)
            submitted = st.form_submit_button("Submit application")

        if submitted:
            try:
                application_id = submit_application(
                    student["student_id"],
                    selected_offering["offering_id"],
                    int(quantity),
                    learning_goal,
                    priority,
                )
                st.success(f"Application #{application_id} submitted as pending.")
            except Exception as error:
                handle_error(error)

    st.subheader("Application history")
    show_rows(
        queries.list_student_applications(student["student_id"]),
        "This student has not submitted any applications.",
    )


def coordinator_page() -> None:
    st.title("Coordinator review and allocation")
    coordinators = queries.list_coordinators()
    if not coordinators:
        st.warning("No coordinators are available. Run database/seed.sql first.")
        return

    coordinator_by_label = {
        label(row, "coordinator_id", f"{row['coordinator_name']} ({row['school_name']})"): row
        for row in coordinators
    }
    coordinator_label = st.selectbox("Coordinator", coordinator_by_label)
    coordinator = coordinator_by_label[coordinator_label]
    queue = queries.list_review_queue(coordinator["coordinator_id"])

    st.subheader("Pending applications from this school")
    show_rows(queue, "No pending applications are waiting for this coordinator.")
    if not queue:
        return

    application_by_label = {
        label(
            row,
            "application_id",
            f"{row['student_name']} - {row['resource_name']}",
        ): row
        for row in queue
    }
    selected_label = st.selectbox("Application to review", application_by_label)
    application = application_by_label[selected_label]
    max_allocation = min(
        int(application["quantity_still_requested"]),
        int(application["remaining_quantity"]),
    )

    st.caption(
        f"Learning goal: {application['learning_goal']} | "
        f"Requested remaining: {application['quantity_still_requested']} | "
        f"Offering remaining: {application['remaining_quantity']}"
    )

    with st.form("review_application_form"):
        decision = st.radio("Decision", ["Approve and allocate", "Reject"])
        quantity = st.number_input(
            "Allocation quantity",
            min_value=1,
            max_value=max(1, max_allocation),
            value=1,
            step=1,
            disabled=decision == "Reject" or max_allocation <= 0,
        )
        reason = st.text_area("Decision reason", value="Approved after eligibility and capacity checks.")
        submitted = st.form_submit_button("Save decision")

    if submitted:
        try:
            if decision == "Approve and allocate":
                if max_allocation <= 0:
                    raise BusinessRuleError("No capacity remains for this application.")
                allocation_id = approve_and_allocate(
                    application["application_id"],
                    coordinator["coordinator_id"],
                    int(quantity),
                    reason,
                )
                st.success(
                    f"Application approved and allocation #{allocation_id} created atomically."
                )
            else:
                reject_application(
                    application["application_id"],
                    coordinator["coordinator_id"],
                    reason,
                )
                st.success("Application rejected.")
        except Exception as error:
            handle_error(error)


def usage_page() -> None:
    st.title("Usage tracking")
    allocations = queries.list_allocations()
    show_rows(allocations, "No active allocations are available for usage tracking.")
    if not allocations:
        return

    allocation_by_label = {
        label(
            row,
            "allocation_id",
            f"{row['student_name']} - {row['resource_name']}",
        ): row
        for row in allocations
    }
    with st.form("usage_record_form"):
        allocation_label = st.selectbox("Active allocation", allocation_by_label)
        usage_type = st.text_input("Usage type", placeholder="e.g. device_delivery")
        usage_status = st.selectbox(
            "Usage status",
            ["scheduled", "in_progress", "completed", "missed", "returned"],
        )
        notes = st.text_area("Notes (optional)")
        submitted = st.form_submit_button("Add usage record")

    if submitted:
        try:
            allocation = allocation_by_label[allocation_label]
            record_no = add_usage_record(
                allocation["allocation_id"], usage_type, usage_status, notes
            )
            st.success(f"Usage record #{record_no} added.")
        except Exception as error:
            handle_error(error)


def reports_page() -> None:
    st.title("Utilisation and unmet-demand report")
    st.caption("Supply, allocations, outstanding demand, and completed use by resource offering.")
    show_rows(queries.utilisation_report(), "No offering data is available.")


PAGES = {
    "Dashboard": dashboard_page,
    "Student application": student_page,
    "Coordinator review": coordinator_page,
    "Usage tracking": usage_page,
    "Reports": reports_page,
}


def main() -> None:
    page = st.sidebar.radio("Navigation", list(PAGES))
    try:
        PAGES[page]()
    except Exception as error:
        handle_error(error)


if __name__ == "__main__":
    main()
