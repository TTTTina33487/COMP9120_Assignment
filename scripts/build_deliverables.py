"""Build the one-page poster, captioned real-interaction video and handover ZIP."""
import json
import os
import re
import subprocess
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts"
WORK = OUT / "demo-frames"


def run(*args):
    subprocess.run([str(a) for a in args], check=True, cwd=ROOT)


def probe(path):
    return json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", str(path)]))


def timestamp(seconds):
    ms = round(seconds * 1000)
    return f"{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}"


def srt(rows):
    return "\n\n".join(f"{i}\n{timestamp(start)} --> {timestamp(end)}\n{text}" for i, (start, end, text) in enumerate(rows, 1)) + "\n"


def title_html(kicker, title, subtitle, facts):
    return f"""<!doctype html><html><head><meta charset='utf-8'><style>
    *{{box-sizing:border-box}}body{{margin:0;width:1920px;height:1080px;background:#153e34;color:#f2f6e8;font-family:Arial,sans-serif;padding:130px 150px;position:relative;overflow:hidden}}
    .kicker{{font-size:19px;letter-spacing:6px;color:#a2c67a}}h1{{font-size:100px;letter-spacing:-4px;line-height:1.1;max-width:1350px;margin:65px 0 35px}}h1 span{{color:#d5f198}}p{{font-size:26px;line-height:1.6;color:#b3cbb2;max-width:1320px}}.facts{{display:flex;gap:70px;margin-top:65px;color:#d2ec9d;font-size:22px}}.foot{{position:absolute;bottom:65px;color:#7ea581;font-size:16px;letter-spacing:2px}}.circle{{position:absolute;border:2px solid #6b955344;width:750px;height:750px;border-radius:50%;right:-180px;top:400px;z-index:-1}}
    </style></head><body><div class='kicker'>{kicker}</div><h1>{title}</h1><p>{subtitle}</p><div class='facts'>{facts}</div><div class='foot'>COMP9120 · REMOTE EDUCATION RESOURCE SUPPORT SYSTEM</div><div class='circle'></div></body></html>"""


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    result = json.loads((OUT / "browser-result.json").read_text())
    if result["status"] != "passed" or result.get("credential_login") != "passed":
        raise RuntimeError("Complete browser verification before generating delivery assets")
    suites = ET.parse(OUT / "test-results.xml").getroot()
    tests = sum(int(row.attrib["tests"]) for row in suites.findall("testsuite"))
    failures = sum(int(row.attrib.get("failures", 0)) + int(row.attrib.get("errors", 0)) + int(row.attrib.get("skipped", 0)) for row in suites.findall("testsuite"))
    if not tests or failures:
        raise RuntimeError("Delivery requires a nonempty, passing integration test result")
    poster = ROOT / "docs/poster.html"
    content = re.sub(r'(id="test-count">)\d+(<)', lambda match: match[1] + str(tests) + match[2], poster.read_text())
    poster.write_text(content)
    # Chromium's managed policy does not allow file: navigation. Serve the
    # poster and its relative screenshots over a local-only HTTP connection.
    static_server = ThreadingHTTPServer(("127.0.0.1", 0), partial(SimpleHTTPRequestHandler, directory=str(ROOT)))
    Thread(target=static_server.serve_forever, daemon=True).start()
    with sync_playwright() as pw:
        browser = pw.chromium.launch(executable_path=os.environ.get("CHROMIUM_PATH", "/usr/bin/chromium"), args=["--no-sandbox"], headless=True)
        page = browser.new_page(viewport={"width": 1122, "height": 1587}, device_scale_factor=1)
        page.goto(f"http://127.0.0.1:{static_server.server_port}/docs/poster.html", wait_until="networkidle")
        assert page.evaluate("document.querySelector('.footer').getBoundingClientRect().bottom <= 1587"), "Poster content overflows A3 page"
        page.pdf(path=str(OUT / "Poster.pdf"), prefer_css_page_size=True, print_background=True)
        page.screenshot(path=str(OUT / "Poster.png"))
        page.set_viewport_size({"width": 1920, "height": 1080})
        page.set_content(title_html("WORKING PROTOTYPE / SYNTHETIC DATA", "Distance should not<br>decide <span>access.</span>", "A student-to-support journey powered by Flask, the team's Python services and PostgreSQL.", "<span>DISCOVER</span><span>APPLY</span><span>REVIEW + ALLOCATE</span><span>TRACK + REPORT</span>"))
        page.screenshot(path=str(WORK / "intro.png"))
        page.set_content(title_html("VERIFIED WORKFLOW / HONEST BOUNDARIES", f"<span>{tests} checks.</span><br>One connected system.", "Real PostgreSQL integration, rollback and concurrent-allocation checks.<br>Desktop workflow and mobile layout verified in Chromium.", "<span>LOCAL DEMO IDENTITIES</span><span>NO REAL STUDENT DATA</span><span>POSTER + SOURCE + RUNBOOK</span>"))
        page.screenshot(path=str(WORK / "outro.png"))
        browser.close()
    static_server.shutdown()
    static_server.server_close()
    raw = OUT / "browser/workflow.webm"
    raw_duration = float(probe(raw)["format"]["duration"])
    workflow_duration = 90
    intro_duration, outro_duration = 7, 11
    factor = workflow_duration / raw_duration
    captions = []
    scenes = result["scenes"]
    for i, scene in enumerate(scenes):
        start = max(0, scene["start"] * factor)
        end = scenes[i+1]["start"] * factor if i+1 < len(scenes) else workflow_duration
        captions.append((start, min(end, workflow_duration), scene["title"] + "\n" + scene["subtitle"]))
    (WORK / "workflow.srt").write_text(srt(captions))
    full_captions = [(0, intro_duration, "Remote Education Resource Support System\nCOMP9120 · Working prototype with synthetic data")]
    full_captions.extend((a+intro_duration, b+intro_duration, text) for a,b,text in captions)
    full_captions.append((intro_duration+workflow_duration, intro_duration+workflow_duration+outro_duration,
                          f"{tests} passing integration checks + real browser workflow\nPassword-protected demo account with assigned workspaces."))
    (OUT / "Showcase.srt").write_text(srt(full_captions))
    common = ["-an", "-c:v", "libx264", "-preset", "fast", "-crf", "23", "-pix_fmt", "yuv420p", "-r", "24", "-threads", "2"]
    for name, duration in (("intro", intro_duration), ("outro", outro_duration)):
        run("ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-loop", "1", "-i", WORK / f"{name}.png", "-t", duration, *common, WORK / f"{name}.mp4")
    vf = (f"setpts={factor:.8f}*(PTS-STARTPTS),fps=24,scale=1336:928:force_original_aspect_ratio=decrease,"
          "pad=1920:1080:(ow-iw)/2:40:color=0x153e34,setsar=1,"
          f"subtitles={WORK / 'workflow.srt'}:force_style='FontName=DejaVu Sans,FontSize=9,PrimaryColour=&H00F3F7EC,OutlineColour=&H00283E15,BorderStyle=1,Outline=0.5,Shadow=0,MarginV=6'")
    run("ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", raw, "-vf", vf,
        "-t", workflow_duration, *common, WORK / "workflow.mp4")
    concat = WORK / "concat.txt"
    concat.write_text("\n".join(f"file '{WORK / (name + '.mp4')}'" for name in ("intro", "workflow", "outro")) + "\n")
    run("ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", concat,
        "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo", "-c:v", "copy", "-c:a", "aac", "-shortest", "-movflags", "+faststart", OUT / "Showcase.mp4")
    info = probe(OUT / "Showcase.mp4")
    seconds = float(info["format"]["duration"])
    assert 100 <= seconds < 180
    streams = [s for s in info["streams"] if s["codec_type"] == "video"]
    assert streams[0]["width"] == 1920 and streams[0]["height"] == 1080
    validation = f"""# Verified delivery results

## PostgreSQL integration

`python -m pytest --junitxml=artifacts/test-results.xml -q`: **{tests} passed; no failures, errors or skipped tests**.
Tests use real PostgreSQL with the original schema and synthetic seed data in an owned temporary database.
Coverage includes student and coordinator pages, applications, duplicate requests, partial allocation,
rejection, usage records and CSV exports. Negative cases include school isolation, role access, CSRF,
invalid quantities, expired offerings or eligibility, missing eligibility, capacity limits, repeated approval,
and concurrent applications competing for the last unit. The original five negative database-constraint
checks also pass. Application pages and CSV headers are verified in English.

## Real browser workflow

`python scripts/browser_check.py`: **passed**.
Desktop: 1440 x 1000. Mobile: 390 x 844 without page-level horizontal overflow.
No JavaScript page errors or HTTP 5xx responses were observed.
The browser selects a student, filters eligible resources, submits a request, switches to the same-school
coordinator, approves and allocates two units, saves a completed usage record, inspects the history and
downloads both CSV reports. PostgreSQL confirms allocated_quantity = 2 for the submitted application.
Screenshots are captured from the English interface. Test and capture databases are cleaned up afterward;
the interactive demonstration database is preserved.
The configured account {result['tested_account']} successfully signs in with its real password for both
the student and coordinator workspaces. Captured passwords are masked. Integration checks also cover
incorrect credentials, role-only login bypass, unassigned workspaces, logout and credential rotation.

## Deliverables

- Poster.pdf: one A3 page; editable HTML, real English UI captures and verified test counts.
- Showcase.mp4: {seconds:.1f} seconds, 1920 x 1080, H.264/AAC; edited real interaction footage.
- Showcase.srt: editable English subtitles. The video has a silent audio track and no spoken narration.
- sample-applications.csv: school-scoped application details downloaded by the browser.
- sample-utilisation.csv: platform-wide resource summaries downloaded by the browser.
- screenshots/: English desktop and mobile captures.

## Scope and limitations

The prototype uses one password-protected demo account with two assigned workspaces. B supports initial partial
allocation but does not expose post-approval top-ups or automatic stock release from usage returns.
All seed data is synthetic. No external deployment or real educational impact is claimed.
"""
    (ROOT / "docs/VALIDATION.md").write_text(validation)
    (OUT / "media-metadata.json").write_text(json.dumps({"video_seconds": seconds, "width": 1920, "height": 1080, "tests_passed": tests, "video_codec": "h264", "voiceover": False}, indent=2))
    # Portable handover: sources and reviewable outputs only, no credentials,
    # instance data, Git history, virtualenv or intermediate encodes.
    exclude = {".git", ".venv", "instance", "__pycache__", ".pytest_cache", "browser", "demo-frames"}
    destination = OUT / "9120-delivery.zip"
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        for path in sorted(ROOT.rglob("*")):
            relative = path.relative_to(ROOT)
            if not path.is_file() or any(part in exclude for part in relative.parts) or path == destination:
                continue
            if (path.name.startswith(".env") and path.name != ".env.example") or path.suffix in (".log", ".webm", ".pyc"):
                continue
            bundle.write(path, str(relative))
    print(f"Built A3 poster, {seconds:.1f}s captioned MP4, SRT, validation and delivery ZIP.")


if __name__ == "__main__":
    main()
