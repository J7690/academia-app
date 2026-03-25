#!/usr/bin/env python3
"""Phase 9 Audit: Teacher prep RPCs, existing teacher_prep_screen usage, new assignment RPCs."""
import json, requests
from pathlib import Path

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=30)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    rows = body.get("rows", []) if ok else []
    print(f"  {'OK' if ok else 'ERR'} {label}")
    return ok, rows

print("=" * 60)
print("PHASE 9 AUDIT -- Teacher Concours RPCs")
print("=" * 60)

# 1. All prep RPCs the teacher/instructor can call
print("\n[1] All prep RPCs for teacher role:")
ok1, r1 = sql("SELECT routine_name, routine_schema FROM information_schema.routines WHERE (routine_name LIKE 'app_prep_teacher%' OR routine_name LIKE 'app_prep_create%' OR routine_name LIKE 'app_prep_list%') AND routine_schema IN ('app','public') ORDER BY routine_name", "teacher prep RPCs")
for r in r1: print(f"    {r.get('routine_schema')}.{r.get('routine_name')}")

# 2. New assignment RPCs (Phase 7)
print("\n[2] Assignment RPCs (Phase 7):")
ok2, r2 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE '%prep_%assignment%' OR routine_name LIKE '%prep_%submission%' ORDER BY routine_name", "assignment RPCs")
for r in r2: print(f"    {r.get('routine_name')}")

# 3. New live session RPCs (Phase 8)
print("\n[3] Live session RPCs (Phase 8):")
ok3, r3 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE '%prep_%live%' ORDER BY routine_name", "live RPCs")
for r in r3: print(f"    {r.get('routine_name')}")

# 4. Check what TdService prep methods exist (these call RPCs in schema app)
print("\n[4] TdService RPCs used by teacher_prep_screen (schema app):")
ok4, r4 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'app' AND routine_name LIKE 'app_prep_%' ORDER BY routine_name", "app.app_prep_*")
for r in r4: print(f"    {r.get('routine_name')}")

# 5. Verify data in tables
print("\n[5] Data status:")
for t in ["prep_assignments", "prep_assignment_submissions", "prep_live_sessions", "prep_live_participants"]:
    ok, r = sql(f"SELECT COUNT(*) AS cnt FROM app.{t}", t)
    print(f"    {t}: {r[0].get('cnt',0) if r else '?'} rows")

out = Path(__file__).parent / "logs" / "audit_phase9_teacher_concours.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"teacher_rpcs": r1, "assignment_rpcs": r2, "live_rpcs": r3, "app_prep_rpcs": r4}, f, indent=2, ensure_ascii=False)
print(f"\nAudit saved: {out}")
