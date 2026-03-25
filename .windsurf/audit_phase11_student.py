#!/usr/bin/env python3
"""Phase 11 Audit: Student RPCs for assignments, live sessions, predictions."""
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
print("PHASE 11 AUDIT -- Student concours UI")
print("=" * 60)

# 1. Student assignment RPCs
print("\n[1] Student assignment RPCs:")
ok1, r1 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_prep_student%assignment%' OR routine_name LIKE 'app_prep_student%submission%' ORDER BY routine_name", "student assignment RPCs")
for r in r1: print(f"    {r.get('routine_name')}")

# 2. Student live session RPCs
print("\n[2] Student live session RPCs:")
ok2, r2 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_prep_student%live%' ORDER BY routine_name", "student live RPCs")
for r in r2: print(f"    {r.get('routine_name')}")

# 3. Predictions RPC
print("\n[3] Predictions RPC:")
ok3, r3 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name = 'app_prep_get_predictions'", "predictions RPC")
for r in r3: print(f"    {r.get('routine_name')}")

# 4. Data counts
print("\n[4] Data:")
for t, label in [("prep_assignments", "assignments"), ("prep_live_sessions", "live sessions"), ("prep_topic_predictions", "predictions"), ("prep_questions", "questions")]:
    ok, r = sql(f"SELECT COUNT(*) AS cnt FROM app.{t}", label)
    print(f"    {t}: {r[0].get('cnt',0) if r else '?'}")

out = Path(__file__).parent / "logs" / "audit_phase11_student.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"assignment_rpcs": r1, "live_rpcs": r2, "prediction_rpcs": r3}, f, indent=2, ensure_ascii=False)
print(f"\nAudit saved: {out}")
