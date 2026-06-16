#!/usr/bin/env python3
"""Phase 7 Audit: Check if prep_assignments tables exist, check TD assignments for reference."""
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
    print(f"  {'✅' if ok else '❌'} {label} {('— ' + err[:150]) if err else ''}")
    return ok, rows

results = {}
print("=" * 60)
print("PHASE 7 AUDIT — Exercices asynchrones")
print("=" * 60)

# 1. Check if prep_assignments already exists
print("\n[1] New tables existence:")
for t in ["prep_assignments", "prep_assignment_submissions"]:
    ok, r = sql(f"SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}'", f"Table {t}")
    exists = r[0].get("cnt", 0) if r else 0
    print(f"    → {'EXISTS' if exists > 0 else 'DOES NOT EXIST'}")
    results[t] = exists

# 2. Check existing TD assignment tables (for reference, not to modify)
print("\n[2] TD assignment tables (for reference):")
ok2, r2 = sql("SELECT table_name FROM information_schema.tables WHERE table_schema='app' AND table_name LIKE 'td_%assignment%' ORDER BY table_name", "TD assignment tables")
for r in r2: print(f"    → {r.get('table_name')}")

# 3. Check existing RPCs with 'assignment'
print("\n[3] Existing assignment RPCs:")
ok3, r3 = sql("SELECT routine_name, routine_schema FROM information_schema.routines WHERE routine_name LIKE '%assignment%' ORDER BY routine_name", "Assignment RPCs")
for r in r3: print(f"    {r.get('routine_schema')}.{r.get('routine_name')}")
results["existing_assignment_rpcs"] = r3

# 4. Edge Function prep-grade-assignment
print("\n[4] Edge Function prep-grade-assignment:")
try:
    resp = requests.options(f"{URL}/functions/v1/prep-grade-assignment", timeout=10)
    print(f"    HTTP {resp.status_code}")
except Exception as e:
    print(f"    Error: {e}")

# 5. Current prep_* table count
print("\n[5] Total prep_* tables:")
ok5, r5 = sql("SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name LIKE 'prep_%'", "prep_* count")
print(f"    → {r5}")

out = Path(__file__).parent / "logs" / "audit_phase7_assignments.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"\n✅ Audit saved: {out}")
