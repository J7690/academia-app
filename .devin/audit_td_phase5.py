#!/usr/bin/env python3
"""Phase 5 TD Audit: Teacher RPCs for local groups, assignments, correction IA."""
import json, requests
from pathlib import Path

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=30)
    body = r.json() if r.status_code == 200 else {"ok": False}
    ok = isinstance(body, dict) and body.get("ok", False)
    rows = body.get("rows", []) if ok else []
    print(f"  {'OK' if ok else 'ERR'} {label}")
    return ok, rows

print("=" * 60)
print("PHASE 5 TD AUDIT -- Enseignant groupes + exercices + IA")
print("=" * 60)

# 1. Teacher RPCs for local groups (Phase 1)
print("\n[1] Teacher local groups RPCs:")
ok1, r1 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_td_teacher%local%' OR routine_name LIKE 'app_td_teacher%group%' ORDER BY routine_name", "teacher group RPCs")
for r in r1: print(f"    {r.get('routine_name')}")

# 2. Teacher RPCs for assignments (existing + new)
print("\n[2] Teacher assignment RPCs:")
ok2, r2 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_td_teacher%assignment%' OR routine_name LIKE 'app_td_teacher%exercise%' OR routine_name LIKE 'app_td_teacher%submission%' ORDER BY routine_name", "teacher assignment RPCs")
for r in r2: print(f"    {r.get('routine_name')}")

# 3. Check if teacher exercise/submission RPCs need to be created
print("\n[3] Missing teacher TD exercise RPCs:")
needed = ["app_td_teacher_create_exercise", "app_td_teacher_list_exercises", "app_td_teacher_list_exercise_submissions", "app_td_teacher_grade_exercise"]
for rpc in needed:
    ok, r = sql(f"SELECT routine_name FROM information_schema.routines WHERE routine_name = '{rpc}'", rpc)
    print(f"    {rpc}: {'EXISTS' if r else 'TO CREATE'}")

# 4. Edge Function prep-grade-assignment (reusable)
print("\n[4] Edge Function prep-grade-assignment:")
try:
    resp = requests.options(f"{URL}/functions/v1/prep-grade-assignment", timeout=10)
    print(f"    HTTP {resp.status_code}")
except: print("    ERROR")

# 5. td_teacher_profiles table
print("\n[5] td_teacher_profiles columns:")
ok5, r5 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='td_teacher_profiles' ORDER BY ordinal_position", "cols")
for c in r5: print(f"    {c['column_name']}: {c['data_type']}")

out = Path(__file__).parent / "logs" / "audit_td_phase5.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"teacher_group_rpcs": r1, "teacher_assignment_rpcs": r2}, f, indent=2)
print(f"\nAudit saved: {out}")
