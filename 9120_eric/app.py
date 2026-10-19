"""Flask UI connected to the supplied B backend and PostgreSQL."""
import csv
import io
import os
import secrets
from functools import wraps
from pathlib import Path

import psycopg
from flask import Flask, Response, abort, flash, g, redirect, render_template, request, session, url_for

from resource_hub import gateway as b

STATUS = {"pending": "Pending review", "under_review": "Under review", "approved": "Approved / allocated", "rejected": "Rejected", "withdrawn": "Withdrawn"}
PRIORITIES = {"low": "Low", "medium": "Medium", "high": "High", "urgent": "Urgent"}
USAGE = {"scheduled": "Scheduled", "in_progress": "In progress", "completed": "Completed", "missed": "Missed", "returned": "Returned (usage record)"}


def create_app(test_config=None):
    app = Flask(__name__, instance_relative_config=True)
    app.config.from_mapping(SECRET_KEY=os.environ.get("APP_SECRET_KEY"),
                            DEMO_LOGIN=os.environ.get("DEMO_LOGIN", "1") == "1",
                            SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax",
                            MAX_CONTENT_LENGTH=64 * 1024)
    if test_config:
        app.config.update(test_config)
    if not app.config["SECRET_KEY"]:
        Path(app.instance_path).mkdir(parents=True, exist_ok=True)
        key_file = Path(app.instance_path) / "session.key"
        try:
            with open(key_file, "x", opener=lambda path, flags: os.open(path, flags, 0o600)) as handle:
                handle.write(secrets.token_hex(32))
        except FileExistsError:
            pass
        app.config["SECRET_KEY"] = key_file.read_text().strip()

    def login_required(role=None):
        def decorate(fn):
            @wraps(fn)
            def wrapped(*args, **kwargs):
                if g.user is None:
                    return redirect(url_for("login"))
                if role and g.user["role"] != role:
                    abort(403)
                return fn(*args, **kwargs)
            return wrapped
        return decorate

    @app.before_request
    def load_user_and_csrf():
        g.user = b.actor(session.get("role"), session.get("user_id")) if session.get("user_id") else None
        if "csrf_token" not in session:
            session["csrf_token"] = secrets.token_hex(32)
        if request.method == "POST" and not secrets.compare_digest(request.form.get("csrf_token", ""), session["csrf_token"]):
            abort(400, description="This form has expired. Refresh the page and try again.")

    @app.context_processor
    def context():
        return {"status_labels": STATUS, "priority_labels": PRIORITIES, "usage_labels": USAGE, "demo_mode": app.config["DEMO_LOGIN"]}

    @app.after_request
    def response_headers(response):
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Content-Security-Policy"] = "default-src 'self'; style-src 'self'; img-src 'self' data:; script-src 'none'; frame-ancestors 'none'; form-action 'self'"
        response.headers["Cache-Control"] = "no-store"
        return response

    @app.route("/login", methods=["GET", "POST"])
    def login():
        if not app.config["DEMO_LOGIN"]:
            abort(403)
        if request.method == "POST":
            try:
                role, raw_id = request.form.get("identity", "").split(":")
                user = b.actor(role, int(raw_id))
            except (ValueError, TypeError):
                user = None
            if user:
                session.clear()
                session.update(user_id=user["id"], role=user["role"], csrf_token=secrets.token_hex(32))
                return redirect(url_for("dashboard"))
            flash("Choose a valid demo identity.", "error")
            return render_template("login.html", identities=b.identities()), 400
        return render_template("login.html", identities=b.identities())

    @app.post("/logout")
    def logout():
        session.clear()
        return redirect(url_for("login"))

    @app.get("/")
    @login_required()
    def dashboard():
        rows, stock = b.applications(g.user), b.resources(g.user["id"] if g.user["role"] == "student" else None)
        counts = {status: sum(a["status"] == status for a in rows) for status in STATUS}
        counts["allocated"] = sum(a["allocated_quantity"] > 0 for a in rows)
        return render_template("dashboard.html", applications=rows[:5], counts=counts, resources=stock,
                               total_applications=len(rows), active="dashboard")

    @app.get("/resources")
    @login_required()
    def resource_list():
        q, category = request.args.get("q", "").strip()[:100], request.args.get("category", "")
        all_resources = b.resources(g.user["id"] if g.user["role"] == "student" else None)
        suitable_only = request.args.get("suitable") == "1" and g.user["role"] == "student"
        rows = [r for r in all_resources if (not q or q.lower() in (r["name"] + r["description"] + r["location"]).lower())
                and (not category or r["category"] == category) and (not suitable_only or r["suitable"])]
        return render_template("resources.html", resources=rows, categories=sorted({r["category"] for r in all_resources}),
                               q=q, category=category, suitable_only=suitable_only, active="resources")

    @app.route("/applications/new", methods=["GET", "POST"])
    @login_required("student")
    def application_new():
        stock = b.resources(g.user["id"])
        if request.method == "POST":
            purpose, priority = request.form.get("purpose", "").strip(), request.form.get("priority", "medium")
            try:
                resource_id, quantity = int(request.form.get("resource_id", "")), int(request.form.get("quantity", ""))
            except ValueError:
                resource_id, quantity = -1, 0
            resource = next((r for r in stock if r["id"] == resource_id), None)
            if resource is None or not 1 <= quantity <= resource["total"] or not 10 <= len(purpose) <= 1500 or priority not in PRIORITIES:
                flash("Choose a valid resource, quantity and priority, and enter a learning goal of 10–1500 characters.", "error")
                return render_template("apply.html", resources=stock, active="apply"), 400
            if not resource["suitable"]:
                flash("This resource is unavailable, expired, or does not meet your eligibility requirements.", "error")
                return render_template("apply.html", resources=stock, active="apply"), 400
            try:
                application_id = b.services.submit_application(g.user["id"], resource_id, quantity, purpose, priority)
            except b.services.BusinessRuleError as exc:
                flash(str(exc), "error")
                return render_template("apply.html", resources=stock, active="apply"), 409
            flash("Application submitted. Your school coordinator will review it.", "success")
            return redirect(url_for("application_detail", application_id=application_id))
        return render_template("apply.html", resources=stock, active="apply")

    @app.get("/applications")
    @login_required()
    def application_list():
        rows, status = b.applications(g.user), request.args.get("status", "")
        if status:
            rows = [r for r in rows if r["status"] == status]
        return render_template("applications.html", applications=rows, status=status, active="applications")

    def visible_application(application_id):
        row = next((r for r in b.applications(g.user) if r["id"] == application_id), None)
        if row is None:
            abort(404)
        return row

    @app.get("/applications/<int:application_id>")
    @login_required()
    def application_detail(application_id):
        row = visible_application(application_id)
        return render_template("detail.html", application=row, allocations=b.allocation_details(application_id),
                               usage=b.usage_details(application_id), active="applications")

    @app.post("/applications/<int:application_id>/<action>")
    @login_required("coordinator")
    def transition(application_id, action):
        row = visible_application(application_id)
        if action not in ("approve", "reject"):
            abort(404)
        note = request.form.get("note", "").strip()
        if len(note) > 1000 or (action == "reject" and not note):
            flash("A rejection reason is required. Notes must not exceed 1000 characters.", "error")
            return redirect(url_for("application_detail", application_id=application_id))
        try:
            if action == "approve":
                try:
                    quantity = int(request.form.get("allocation_quantity", ""))
                except ValueError:
                    raise b.services.BusinessRuleError("Enter a valid allocation quantity.")
                b.services.approve_and_allocate(application_id, g.user["id"], quantity, note)
                flash("Approval and allocation committed together. Resource capacity has been updated.", "success")
            else:
                b.services.reject_application(application_id, g.user["id"], note)
                flash("Application rejected. The decision reason has been saved.", "success")
        except b.services.BusinessRuleError as exc:
            flash(str(exc), "error")
        return redirect(url_for("application_detail", application_id=row["id"]))

    @app.route("/usage", methods=["GET", "POST"])
    @login_required("coordinator")
    def usage():
        allocations = b.own_active_allocations(g.user)
        if request.method == "POST":
            try:
                allocation_id = int(request.form.get("allocation_id", ""))
            except ValueError:
                abort(400)
            if allocation_id not in {a["allocation_id"] for a in allocations}:
                abort(404)
            usage_type = request.form.get("usage_type", "").strip()
            usage_status, notes = request.form.get("usage_status", ""), request.form.get("notes", "").strip()
            if not 1 <= len(usage_type) <= 80 or usage_status not in USAGE or len(notes) > 1500:
                flash("Enter a usage type, valid status and notes of no more than 1500 characters.", "error")
                return render_template("usage.html", allocations=allocations, active="usage"), 400
            try:
                number = b.services.add_usage_record(allocation_id, usage_type, usage_status, notes)
                flash(f"Usage record #{number} saved.", "success")
            except b.services.BusinessRuleError as exc:
                flash(str(exc), "error")
            return redirect(url_for("usage"))
        return render_template("usage.html", allocations=allocations, active="usage")

    @app.get("/reports")
    @login_required("coordinator")
    def reports():
        rows = b.applications(g.user)
        counts = {status: sum(r["status"] == status for r in rows) for status in STATUS}
        return render_template("reports.html", counts=counts, resources=b.resources(), total=len(rows),
                               metrics=b.queries.dashboard_metrics(), utilisation=b.queries.utilisation_report(),
                               regions=b.queries.list_regions(), active="reports")

    @app.get("/reports.csv")
    @login_required("coordinator")
    def reports_csv():
        output, kind = io.StringIO(), request.args.get("kind", "applications")
        writer = csv.writer(output)
        if kind == "utilisation":
            fields = ["resource_name", "resource_type", "subject_area", "total_quantity", "allocated_quantity", "remaining_quantity", "pending_applications", "rejected_applications", "completed_usage_records"]
            writer.writerow(fields)
            rows = [[r[k] for k in fields] for r in b.queries.utilisation_report()]
        else:
            writer.writerow(["Application ID", "Student", "School", "Resource", "Requested quantity", "Allocated", "Unfulfilled", "Status", "Learning goal", "Decision reason", "Application date"])
            rows = [(r["id"], r["student_name"], r["school_name"], r["resource_name"], r["quantity"], r["allocated_quantity"], r["quantity_still_requested"], STATUS[r["status"]], r["purpose"], r["review_note"], r["created_at"]) for r in b.applications(g.user)]
        def safe(value):
            value = str(value)
            return "'" + value if value.lstrip().startswith(("=", "+", "-", "@")) or value.startswith(("\t", "\r", "\n")) else value
        for row in rows:
            writer.writerow([safe(v) for v in row])
        return Response("\ufeff" + output.getvalue(), content_type="text/csv; charset=utf-8",
                        headers={"Content-Disposition": f"attachment; filename={kind if kind == 'utilisation' else 'applications'}-report.csv"})

    @app.get("/health")
    def health():
        row = b.select("SELECT COUNT(*) AS count FROM resource_offering")[0]
        return {"status": "ok", "backend": "B Python + PostgreSQL", "offerings": row["count"], "demo_login": app.config["DEMO_LOGIN"]}

    @app.errorhandler(psycopg.Error)
    def database_error(error):
        app.logger.error("Database operation failed: %s", type(error).__name__)
        return render_template("error.html", error=type("DatabaseError", (), {"code": 503, "description": "The database operation could not be completed. Check PostgreSQL and try again."})()), 503

    @app.errorhandler(400)
    @app.errorhandler(403)
    @app.errorhandler(404)
    @app.errorhandler(413)
    def error_page(error):
        return render_template("error.html", error=error), error.code

    return app


if __name__ == "__main__":
    create_app().run(host="127.0.0.1", port=int(os.environ.get("PORT", "5000")), debug=False)
