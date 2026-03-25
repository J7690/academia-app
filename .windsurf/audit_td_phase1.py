#!/usr/bin/env python3
"""Phase 1 TD Audit: existing TD tables, RPCs, check new tables don't exist yet."""
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
    err = body.get("error", "") if not ok else ""
    print(f"  {'OK' if ok else 'ERR'} {label} {('-- ' + err[:150]) if err else ''}")
    return ok, rows

results = {}
print("=" * 60)
print("PHASE 1 TD AUDIT -- Tables existantes + nouvelles")
print("=" * 60)

# 1. Existing TD tables
print("\n[1] Tables TD existantes:")
ok1, r1 = sql("SELECT table_name FROM information_schema.tables WHERE table_schema = 'app' AND table_name LIKE 'td_%' ORDER BY table_name", "td_* tables")
for t in r1: print(f"    {t.get('table_name')}")
results["existing_td_tables"] = [t["table_name"] for t in r1]

# 2. Check new tables don't exist
print("\n[2] Nouvelles tables (doivent NE PAS exister):")
for t in ["td_student_profiles", "td_local_groups", "td_local_group_members", "td_physical_sessions", "td_teacher_profiles"]:
    ok, r = sql(f"SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}'", t)
    exists = r[0].get("cnt", 0) if r else 0
    print(f"    {t}: {'EXISTS (!) ' if exists > 0 else 'DOES NOT EXIST (OK)'}")
    results[t] = exists

# 3. Existing TD RPCs
print("\n[3] RPCs TD existantes:")
ok3, r3 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_schema IN ('app','public') AND routine_name LIKE 'app_td_%' ORDER BY routine_name", "td RPCs")
for r in r3: print(f"    {r.get('routine_name')}")
results["existing_td_rpcs"] = [r["routine_name"] for r in r3]

# 4. students table columns (to understand student data structure)
print("\n[4] app.students columns:")
ok4, r4 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='students' ORDER BY ordinal_position", "students cols")
for c in r4: print(f"    {c['column_name']}: {c['data_type']}")

# 5. TD enrollments structure (reference for group membership)
print("\n[5] td_enrollments columns:")
ok5, r5 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='td_enrollments' ORDER BY ordinal_position", "td_enrollments cols")
for c in r5: print(f"    {c['column_name']}: {c['data_type']}")

# 6. td_sessions structure (reference for physical sessions)
print("\n[6] td_sessions columns:")
ok6, r6 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='td_sessions' ORDER BY ordinal_position", "td_sessions cols")
for c in r6: print(f"    {c['column_name']}: {c['data_type']}")

# 7. Row counts
print("\n[7] Row counts:")
for t in ["td_sessions", "td_enrollments", "td_subjects", "td_questions", "td_student_progress"]:
    ok, r = sql(f"SELECT COUNT(*) AS cnt FROM app.{t}", t)
    print(f"    {t}: {r[0].get('cnt',0) if r else '?'}")

out = Path(__file__).parent / "logs" / "audit_td_phase1.json"
out.parent.mkdir(exist_ok=True)
with open(out, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"\nAudit saved: {out}")
