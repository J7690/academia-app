#!/usr/bin/env python3
"""D21 - Preuve REST directe pour chaque RPC whiteboard Flutter"""
import requests
import json
from datetime import datetime

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
HEADERS = {
    "apikey": SKEY,
    "Authorization": "Bearer " + SKEY,
    "Content-Type": "application/json",
}
ADMIN = URL + "/rest/v1/rpc/admin_execute_sql"

results = []
TS = datetime.now().isoformat()

def log(msg):
    results.append(msg)
    print(msg)

def rest_rpc(name, payload, label=None):
    log(f"\n{'='*70}")
    log(f"RPC: {name} | {label or ''} | {datetime.now().isoformat()}")
    r = requests.post(f"{URL}/rest/v1/rpc/{name}", headers=HEADERS, json=payload, timeout=20)
    log(f"HTTP STATUS: {r.status_code}")
    try:
        body = r.json()
        log(f"BODY TYPE: {type(body).__name__}")
        log(f"BODY: {json.dumps(body, ensure_ascii=False)[:800]}")
        return r.status_code, body
    except Exception as e:
        log(f"BODY RAW: {r.text[:400]}")
        log(f"PARSE ERROR: {e}")
        return r.status_code, None

def admin_sql(label, sql):
    log(f"\n--- ADMIN SQL: {label} ---")
    r = requests.post(ADMIN, headers=HEADERS, json={"p_sql": sql}, timeout=30)
    log(f"HTTP STATUS: {r.status_code}")
    try:
        body = r.json()
        log(f"RESPONSE: {json.dumps(body, ensure_ascii=False)[:600]}")
        return r.status_code, body
    except:
        log(f"RAW: {r.text[:400]}")
        return r.status_code, None

log("="*70)
log(f"D21 - AUDIT REST SUPABASE GROUND TRUTH")
log(f"Timestamp: {TS}")
log("="*70)

# ─── SECTION 1: TABLES via REST direct ─────────────────────────────────────
log("\n\n### SECTION 1 – TABLES WHITEBOARD VIA REST DIRECT ###")

for table in ["whiteboard_projects", "whiteboard_renders", "whiteboard_ai_generations"]:
    log(f"\n--- TABLE: {table} ---")
    r = requests.get(f"{URL}/rest/v1/{table}?limit=1", headers=HEADERS, timeout=15)
    log(f"HTTP STATUS: {r.status_code}")
    log(f"BODY: {r.text[:300]}")

# ─── SECTION 2: RPCs Flutter via REST ───────────────────────────────────────
log("\n\n### SECTION 2 – RPCs FLUTTER VIA REST DIRECT ###")

# 2.1 whiteboard_create_project  — with a real student_id via admin
log("\n--- Getting a real student_id ---")
status, body = admin_sql("get real student_id",
    "SELECT id FROM auth.users LIMIT 1;")
real_uid = None
if status == 200 and body:
    rows = body.get("data", [])
    if rows:
        real_uid = rows[0][0] if isinstance(rows[0], list) else rows[0].get("id")
        log(f"REAL UID: {real_uid}")

# Also try whiteboard_get_any_student_id
status2, body2 = rest_rpc("whiteboard_get_any_student_id", {}, "get any student id")
any_sid = None
if status2 == 200 and body2 is not None:
    any_sid = body2
    log(f"ANY STUDENT ID: {any_sid}")

test_uid = any_sid or real_uid or "00000000-0000-0000-0000-000000000001"
log(f"\nUsing student_id for tests: {test_uid}")

# 2.2 whiteboard_create_project
rest_rpc("whiteboard_create_project", {
    "p_student_id": test_uid,
    "p_subject": "D21_AUDIT_TEST",
    "p_renderer_id": "scientific",
    "p_theme_id": "scientific",
    "p_narration_mode": "none",
    "p_storyboard_json": {}
}, "CREATE PROJECT")

# 2.3 whiteboard_list_projects
rest_rpc("whiteboard_list_projects", {"p_status": None}, "LIST PROJECTS")

# 2.4 whiteboard_get_project — with a known project_id from C3J
KNOWN_PROJECT_ID = "7c399415-972d-4e47-b31f-03c7ce476f78"
rest_rpc("whiteboard_get_project", {"p_project_id": KNOWN_PROJECT_ID}, "GET PROJECT (known C3J)")

# 2.5 whiteboard_update_project
rest_rpc("whiteboard_update_project", {
    "p_project_id": KNOWN_PROJECT_ID,
    "p_subject": "D21_AUDIT_UPDATE",
    "p_status": None,
    "p_renderer_id": None,
    "p_theme_id": None,
    "p_narration_mode": None,
    "p_storyboard_json": None
}, "UPDATE PROJECT (known C3J)")

# 2.6 whiteboard_delete_project — on a test ID, not a real one
rest_rpc("whiteboard_delete_project", {
    "p_project_id": "00000000-0000-0000-0000-000000000099"
}, "DELETE PROJECT (fake ID — should fail gracefully)")

# 2.7 whiteboard_create_render_job
rest_rpc("whiteboard_create_render_job", {
    "p_project_id": KNOWN_PROJECT_ID
}, "CREATE RENDER JOB (known C3J)")

# 2.8 whiteboard_get_render_status — known render from C3J
KNOWN_RENDER_ID = "fd9e3969-be64-45a9-8e95-00606ac51446"
rest_rpc("whiteboard_get_render_status", {
    "p_render_id": KNOWN_RENDER_ID
}, "GET RENDER STATUS (known C3J render)")

# ─── SECTION 3: Worker RPCs ───────────────────────────────────────────────
log("\n\n### SECTION 3 – RPCs WORKER VIA REST ###")

rest_rpc("whiteboard_fetch_queued_jobs", {"p_limit": 10}, "FETCH QUEUED JOBS")
rest_rpc("whiteboard_mark_processing", {"p_job_id": "00000000-0000-0000-0000-000000000099"}, "MARK PROCESSING (fake — should fail)")
rest_rpc("whiteboard_mark_done", {"p_job_id": "00000000-0000-0000-0000-000000000099", "p_video_url": "test", "p_duration_ms": 0}, "MARK DONE (fake — should fail)")
rest_rpc("whiteboard_mark_failed", {"p_job_id": "00000000-0000-0000-0000-000000000099", "p_error_message": "test"}, "MARK FAILED (fake — should fail)")
rest_rpc("whiteboard_get_any_student_id", {}, "GET ANY STUDENT ID")

# ─── SECTION 4: Edge Function ─────────────────────────────────────────────
log("\n\n### SECTION 4 – EDGE FUNCTION ###")
log("\n--- whiteboard-generate-storyboard (service_role only, no user JWT) ---")
r = requests.post(
    f"{URL}/functions/v1/whiteboard-generate-storyboard",
    headers=HEADERS,
    json={"mode": "simple_subject", "subject": "Dérivée d'une fonction", "renderer": "scientific", "theme": "scientific", "narration_mode": "none"},
    timeout=20
)
log(f"HTTP STATUS: {r.status_code}")
log(f"BODY: {r.text[:400]}")

# ─── SECTION 5: Admin SQL – tables via pg_class ───────────────────────────
log("\n\n### SECTION 5 – TABLES VIA pg_class (admin_execute_sql) ###")

admin_sql("whiteboard tables pg_class",
    """SELECT n.nspname, c.relname, c.relkind
       FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE c.relname ILIKE '%whiteboard%' OR c.relname ILIKE '%render%'
       ORDER BY n.nspname, c.relname;""")

admin_sql("whiteboard RPCs pg_proc",
    """SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as sig
       FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE p.proname ILIKE '%whiteboard%' OR p.proname ILIKE '%storyboard%'
       ORDER BY n.nspname, p.proname;""")

# Save
outfile = "c:\\Users\\fasop\\AndroidStudioProjects\\academia\\.windsurf\\d21_supabase_rpc_proof_output.txt"
with open(outfile, "w", encoding="utf-8") as f:
    f.write("\n".join(results))
log(f"\n\nSaved to: {outfile}")
