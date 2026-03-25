#!/usr/bin/env python3
"""Phase 4 TD Audit: Check existing TD assignment tables, RPCs for student exercises."""
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
print("PHASE 4 TD AUDIT -- Exercices TD etudiant")
print("=" * 60)

# 1. Check existing TD assignment-related tables
print("\n[1] TD tables related to exercises/assignments:")
ok1, r1 = sql("SELECT table_name FROM information_schema.tables WHERE table_schema='app' AND (table_name LIKE 'td_%assignment%' OR table_name LIKE 'td_%exercise%' OR table_name LIKE 'td_%submission%') ORDER BY table_name", "TD assignment tables")
for t in r1: print(f"    {t.get('table_name')}")
if not r1: print("    (aucune table TD assignment)")

# 2. Check existing prep_assignments (concours) — reference
print("\n[2] prep_assignments (concours, reference):")
ok2, r2 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_assignments' ORDER BY ordinal_position", "cols")
for c in r2: print(f"    {c['column_name']}: {c['data_type']}")

# 3. Check if td_assignments table exists
print("\n[3] td_assignments existence:")
ok3, r3 = sql("SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='td_assignments'", "td_assignments")
exists = r3[0].get("cnt", 0) if r3 else 0
print(f"    -> {'EXISTS' if exists > 0 else 'DOES NOT EXIST'}")

# 4. td_assignment_submissions existence
print("\n[4] td_assignment_submissions existence:")
ok4, r4 = sql("SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='td_assignment_submissions'", "td_assignment_submissions")
exists2 = r4[0].get("cnt", 0) if r4 else 0
print(f"    -> {'EXISTS' if exists2 > 0 else 'DOES NOT EXIST'}")

# 5. Existing RPCs for TD teacher assignments
print("\n[5] TD teacher assignment RPCs:")
ok5, r5 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_td_teacher%assignment%' ORDER BY routine_name", "RPCs")
for r in r5: print(f"    {r.get('routine_name')}")

# 6. Edge Function prep-grade-assignment (reusable for TD)
print("\n[6] Edge Function prep-grade-assignment:")
try:
    resp = requests.options(f"{URL}/functions/v1/prep-grade-assignment", timeout=10)
    print(f"    HTTP {resp.status_code}")
except: print("    ERROR")

out = Path(__file__).parent / "logs" / "audit_td_phase4.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"td_assignment_tables": [t["table_name"] for t in r1], "td_assignments_exists": exists, "td_assignment_submissions_exists": exists2}, f, indent=2)
print(f"\nAudit saved: {out}")
