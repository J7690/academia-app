#!/usr/bin/env python3
"""Phase 6 TD Audit: Admin RPCs for local groups, stats, pricing."""
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
print("PHASE 6 TD AUDIT -- Admin dashboard")
print("=" * 60)

print("\n[1] Admin local groups RPC:")
ok1, r1 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_td_admin%local%' OR routine_name LIKE 'app_td_admin%group%' ORDER BY routine_name", "admin group RPCs")
for r in r1: print(f"    {r.get('routine_name')}")

print("\n[2] Admin assign teacher RPC:")
ok2, r2 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_td_admin_assign%' ORDER BY routine_name", "assign RPCs")
for r in r2: print(f"    {r.get('routine_name')}")

print("\n[3] Existing admin TD RPCs:")
ok3, r3 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_td_admin%' ORDER BY routine_name", "all admin td RPCs")
for r in r3: print(f"    {r.get('routine_name')}")

print("\n[4] td_teacher_profiles data:")
ok4, r4 = sql("SELECT COUNT(*) AS cnt FROM app.td_teacher_profiles", "teacher profiles")
print(f"    rows: {r4[0].get('cnt',0) if r4 else '?'}")

print("\n[5] td_local_groups data:")
ok5, r5 = sql("SELECT COUNT(*) AS cnt FROM app.td_local_groups", "groups")
print(f"    rows: {r5[0].get('cnt',0) if r5 else '?'}")

out = Path(__file__).parent / "logs" / "audit_td_phase6.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"admin_rpcs": [r.get("routine_name") for r in r3]}, f, indent=2)
print(f"\nAudit saved: {out}")
