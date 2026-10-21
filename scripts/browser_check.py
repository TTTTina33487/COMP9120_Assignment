"""Exercise the real browser workflow and record reviewable demo footage.

Starts its own app on an unused port and uses an owned temporary PostgreSQL
database. It never resets the interactive development database.
"""
import json
import getpass
import os
import re
import socket
import shutil
import subprocess
import sys
import time
import urllib.request
from pathlib import Path
from uuid import uuid4

import psycopg
import playwright
from psycopg import sql
from psycopg.conninfo import make_conninfo
from playwright.sync_api import expect, sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts"


def main():
    username = os.environ.get("DEMO_USERNAME", "560601108")
    password = os.environ.get("DEMO_TEST_PASSWORD") or getpass.getpass("Demo account password for browser verification: ")
    # Reuse the verified system FFmpeg for recording, without downloading a
    # second browser toolchain or writing into the read-only home directory.
    browser_root = Path(os.environ.setdefault("PLAYWRIGHT_BROWSERS_PATH", "/workspace/.tools/playwright"))
    metadata = Path(playwright.__file__).parent / "driver/package/browsers.json"
    revision = next(row["revision"] for row in json.loads(metadata.read_text())["browsers"] if row["name"] == "ffmpeg")
    recorder = browser_root / f"ffmpeg-{revision}" / "ffmpeg-linux"
    recorder.parent.mkdir(parents=True, exist_ok=True)
    if not recorder.exists():
        recorder.symlink_to(shutil.which("ffmpeg") or "/usr/bin/ffmpeg")
    (OUT / "screenshots").mkdir(parents=True, exist_ok=True)
    (OUT / "browser").mkdir(exist_ok=True)
    (OUT / "browser-result.json").unlink(missing_ok=True)
    name = "hub_browser_" + uuid4().hex[:12]
    base = os.environ["DATABASE_URL"]
    admin = make_conninfo(base, dbname="postgres")
    database_url = make_conninfo(base, dbname=name)
    with psycopg.connect(admin, autocommit=True) as conn:
        conn.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(name)))
    with socket.socket() as port_socket:
        port_socket.bind(("127.0.0.1", 0))
        port = port_socket.getsockname()[1]
    env = dict(os.environ, DATABASE_URL=database_url, PORT=str(port), DEMO_LOGIN="1")
    process = None
    log = (OUT / "browser" / "server.log").open("w")
    scenes = []
    started = time.monotonic()
    try:
        subprocess.run([sys.executable, "scripts/prepare_database.py"], cwd=ROOT, env=env, check=True)
        process = subprocess.Popen([sys.executable, "app.py"], cwd=ROOT, env=env, stdout=log, stderr=log)
        url = f"http://127.0.0.1:{port}"
        for _ in range(100):
            try:
                with urllib.request.urlopen(url + "/health", timeout=1) as response:
                    assert json.load(response)["offerings"] == 8
                    break
            except OSError:
                if process.poll() is not None:
                    raise RuntimeError("Browser app exited; see artifacts/browser/server.log")
                time.sleep(.1)
        else:
            raise RuntimeError("Browser app startup timed out")
        with sync_playwright() as pw:
            browser = pw.chromium.launch(executable_path=os.environ.get("CHROMIUM_PATH", "/usr/bin/chromium"), args=["--no-sandbox"], headless=True)
            context = browser.new_context(viewport={"width": 1440, "height": 1000},
                                          record_video_dir=str(OUT / "browser"), record_video_size={"width": 1440, "height": 1000})
            page = context.new_page()
            errors = []
            page.on("pageerror", lambda err: errors.append(str(err)))
            page.on("response", lambda response: errors.append(f"HTTP {response.status}") if response.status >= 500 else None)
            video = page.video
            video_start = time.monotonic()

            def shot(name, title, subtitle, hold=2):
                assert page.locator("html").get_attribute("lang") == "en"
                assert not re.search(r"[\u3400-\u9fff]", page.locator("body").inner_text())
                assert page.evaluate("document.documentElement.scrollWidth <= window.innerWidth"), name
                page.screenshot(path=str(OUT / "screenshots" / f"{name}.png"), full_page=True)
                scenes.append({"image": f"screenshots/{name}.png", "title": title, "subtitle": subtitle,
                               "start": round(time.monotonic() - video_start, 2)})
                page.wait_for_timeout(hold * 1000)

            def login(identity):
                page.goto(url + "/login")
                page.locator("#username").fill(username)
                page.locator("#password").fill(password)
                page.locator("#identity").select_option(identity)
                page.get_by_role("button", name="Sign in", exact=True).click()
                expect(page.get_by_role("heading", level=1)).to_contain_text("Welcome back")

            page.goto(url + "/login")
            page.locator("#username").fill(username)
            page.locator("#password").fill(password)
            assert page.locator("#password").get_attribute("type") == "password"
            shot("01-login", "01 / ACCOUNT SIGN-IN", "Account and masked password · Authorised student and coordinator workspaces")
            login("student:1")
            shot("02-dashboard", "02 / STUDENT OVERVIEW", "Ava Mitchell · Requests, allocations and available support")
            page.get_by_role("link", name="Explore resources", exact=False).first.click()
            page.locator("input[name=suitable]").check()
            page.get_by_role("button", name="Search", exact=True).click()
            expect(page.get_by_role("heading", name="Refurbished Learning Device", exact=True)).to_be_visible()
            expect(page.get_by_role("heading", name="Satellite Internet Learning Voucher", exact=True)).to_have_count(0)
            shot("03-resources", "03 / ELIGIBILITY-AWARE SEARCH", "B: list_offerings + list_suitable_offerings")
            page.goto(url + "/applications/new?resource_id=8")
            page.locator("#quantity").fill("2")
            page.locator("#priority").select_option("high")
            page.locator("#purpose").fill("I need access to the Year 10 study library to review offline learning materials and complete independent mathematics practice.")
            shot("04-apply", "04 / SUBMIT A LEARNING NEED", "B: submit_application · Quantity 2 · Priority high")
            page.get_by_role("button", name="Submit application").click()
            expect(page.locator(".badge.big")).to_have_text("Pending review")
            application_id = int(page.url.rsplit("/", 1)[-1])
            shot("05-submitted", "05 / PERSISTED APPLICATION", "Student sees the saved request; stock is not reserved yet")
            page.get_by_role("button", name="Sign out").click()
            login("coordinator:1")
            page.get_by_role("link", name="Review & allocate", exact=False).first.click()
            page.get_by_role("link", name="Pending review", exact=True).click()
            shot("06-review-queue", "06 / SCHOOL-SCOPED REVIEW", "Amelia Carter · Only applications from her own school")
            page.goto(url + f"/applications/{application_id}")
            page.locator("#allocation_quantity").fill("2")
            page.locator("#note").fill("Learning need reviewed. Approve two study-library units for remote learning.")
            shot("07-review", "07 / CHECK BEFORE ALLOCATING", "B validates school, verified eligibility, expiry and capacity")
            page.get_by_role("button", name="Approve & allocate").click()
            expect(page.locator(".badge.big")).to_have_text("Approved / allocated")
            expect(page.locator(".details")).to_contain_text("2 / 2 / 0")
            shot("08-allocated", "08 / ATOMIC APPROVAL + ALLOCATION", "B: approve_and_allocate · Stock and decision commit together")
            with psycopg.connect(database_url) as conn:
                allocation_id = conn.execute("SELECT allocation_id FROM remote_education.allocation WHERE application_id=%s", (application_id,)).fetchone()[0]
                allocated = conn.execute("SELECT allocated_quantity FROM remote_education.v_application_fulfilment WHERE application_id=%s", (application_id,)).fetchone()[0]
                assert allocated == 2
            page.goto(url + "/usage")
            page.locator("#allocation_id").select_option(str(allocation_id))
            page.locator("#usage_type").fill("independent_study")
            page.locator("#usage_status").select_option("completed")
            page.locator("#notes").fill("Completed the first offline module and mathematics practice.")
            shot("09-usage", "09 / RECORD LEARNING ACTIVITY", "B: add_usage_record · Sequential record numbers per allocation")
            page.get_by_role("button", name="Save usage record").click()
            expect(page.get_by_role("alert")).to_contain_text("saved")
            page.goto(url + f"/applications/{application_id}")
            expect(page.locator(".timeline")).to_contain_text("independent_study")
            shot("10-tracking", "10 / TRACEABLE OUTCOMES", "Application → Allocation → Usage record")
            page.goto(url + "/reports")
            with page.expect_download() as download_info:
                page.get_by_role("link", name="Export school applications CSV", exact=False).click()
            download_info.value.save_as(OUT / "sample-applications.csv")
            with page.expect_download() as download_info:
                page.get_by_role("link", name="Resource CSV", exact=False).click()
            download_info.value.save_as(OUT / "sample-utilisation.csv")
            shot("11-reports", "11 / LIVE REPORTS + CSV", "B: dashboard_metrics · utilisation_report · list_regions", hold=3)
            # Check mobile layout independently without altering desktop footage.
            mobile_context = browser.new_context(storage_state=context.storage_state(), viewport={"width": 390, "height": 844})
            mobile = mobile_context.new_page()
            mobile.goto(url + "/resources")
            assert mobile.evaluate("document.documentElement.scrollWidth <= window.innerWidth")
            mobile.screenshot(path=str(OUT / "screenshots/12-mobile.png"), full_page=True)
            mobile.goto(url + "/")
            assert mobile.evaluate("document.documentElement.scrollWidth <= window.innerWidth")
            mobile.screenshot(path=str(OUT / "screenshots/13-mobile-overview.png"), full_page=True)
            mobile.goto(url + "/reports")
            assert mobile.evaluate("document.documentElement.scrollWidth <= window.innerWidth")
            mobile.screenshot(path=str(OUT / "screenshots/14-mobile-reports.png"), full_page=True)
            mobile_context.clear_cookies()
            mobile.goto(url + "/login")
            mobile.locator("#username").fill(username)
            mobile.locator("#password").fill(password)
            assert mobile.evaluate("document.documentElement.scrollWidth <= window.innerWidth")
            mobile.screenshot(path=str(OUT / "screenshots/15-mobile-login.png"), full_page=True)
            mobile_context.close()
            assert not errors, errors
            context.close()
            raw_path = Path(video.path())
            raw_path.replace(OUT / "browser/workflow.webm")
            browser.close()
        result = {"status": "passed", "workflow": "student → coordinator → allocate → usage → report CSV",
                  "credential_login": "passed", "tested_account": username,
                  "application_id": application_id, "allocated_quantity": allocated,
                  "desktop": "1440x1000", "mobile": "390x844; no horizontal overflow",
                  "console_errors": errors, "duration_seconds": round(time.monotonic()-started, 2), "scenes": scenes}
        (OUT / "browser-result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2))
        print("Browser workflow passed; screenshots, real interaction footage and CSV exports saved.")
    finally:
        if process:
            process.terminate()
            process.wait(timeout=10)
        log.close()
        with psycopg.connect(admin, autocommit=True) as conn:
            conn.execute(sql.SQL("DROP DATABASE {} WITH (FORCE)").format(sql.Identifier(name)))


if __name__ == "__main__":
    main()
