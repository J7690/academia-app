#!/usr/bin/env python3
"""Phase 7 TD Audit: Check matching infrastructure, student profiles, teacher profiles."""
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
print("PHASE 7 TD AUDIT -- Algorithme matching")
print("=" * 60)

# 1. Check matching RPCs don't exist yet
print("\n[1] Matching RPCs:")
for rpc in ["app_td_auto_match_groups", "app_td_suggest_groups_for_student", "app_td_auto_assign_teacher"]:
    ok, r = sql(f"SELECT routine_name FROM information_schema.routines WHERE routine_name = '{rpc}'", rpc)
    print(f"    {rpc}: {'EXISTS' if r else 'TO CREATE'}")

# 2. Student profiles with is_seeking_group
print("\n[2] td_student_profiles columns (matching fields):")
ok2, r2 = sql("SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='td_student_profiles' AND column_name IN ('subjects_needed','neighborhood','availability_days','availability_times','is_seeking_group','university','study_year') ORDER BY column_name", "cols")
for c in r2: print(f"    {c['column_name']}")

# 3. Teacher profiles with matching fields
print("\n[3] td_teacher_profiles columns (matching fields):")
ok3, r3 = sql("SELECT column_name FROM information_schema.columns WHERE table_schema='app' AND table_name='td_teacher_profiles' AND column_name IN ('specialties','neighborhoods','availability_days','availability_times','is_available') ORDER BY column_name", "cols")
for c in r3: print(f"    {c['column_name']}")

# 4. Local groups status values
print("\n[4] td_local_groups status field:")
ok4, r4 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='td_local_groups' AND column_name IN ('status','subject','neighborhood','max_members','current_members','assigned_teacher_id') ORDER BY column_name", "cols")
for c in r4: print(f"    {c['column_name']}: {c['data_type']}")

# 5. Data
print("\n[5] Data counts:")
for t in ["td_student_profiles", "td_teacher_profiles", "td_local_groups"]:
    ok, r = sql(f"SELECT COUNT(*) AS cnt FROM app.{t}", t)
    print(f"    {t}: {r[0].get('cnt',0) if r else '?'}")

out = Path(__file__).parent / "logs" / "audit_td_phase7.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"student_cols": r2, "teacher_cols": r3, "group_cols": r4}, f, indent=2)
print(f"\nAudit saved: {out}")
