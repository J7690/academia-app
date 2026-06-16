#!/usr/bin/env python3
"""Phase 10 Audit: prep live session RPCs, existing live infrastructure."""
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
print("PHASE 10 AUDIT -- Live sessions enseignant concours")
print("=" * 60)

# 1. prep_live RPCs
print("\n[1] prep live teacher RPCs:")
ok1, r1 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_prep_teacher%live%' ORDER BY routine_name", "prep teacher live RPCs")
for r in r1: print(f"    {r.get('routine_name')}")

# 2. prep_live_sessions columns
print("\n[2] prep_live_sessions columns:")
ok2, r2 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_live_sessions' ORDER BY ordinal_position", "columns")
for c in r2: print(f"    {c['column_name']}: {c['data_type']}")

# 3. Distinction: online_course_live_sessions vs prep_live_sessions
print("\n[3] Live session table distinction:")
ok3a, r3a = sql("SELECT COUNT(*) AS cnt FROM app.online_course_live_sessions", "online_course count")
ok3b, r3b = sql("SELECT COUNT(*) AS cnt FROM app.prep_live_sessions", "prep_live count")
print(f"    online_course_live_sessions: {r3a[0].get('cnt',0) if r3a else '?'} rows")
print(f"    prep_live_sessions: {r3b[0].get('cnt',0) if r3b else '?'} rows")

# 4. Verify RPC signatures
print("\n[4] RPC signatures:")
for rpc in ["app_prep_teacher_upsert_live_session", "app_prep_teacher_list_live_sessions", "app_prep_teacher_start_live_session"]:
    ok, r = sql(f"SELECT parameter_name, data_type FROM information_schema.parameters p JOIN information_schema.routines r ON r.specific_name = p.specific_name WHERE r.routine_name = '{rpc}' AND p.parameter_name IS NOT NULL ORDER BY p.ordinal_position", rpc)
    params = [f"{p['parameter_name']}:{p['data_type']}" for p in r]
    print(f"    {rpc}: {params}")

out = Path(__file__).parent / "logs" / "audit_phase10_live_teacher.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"rpcs": r1, "columns": r2}, f, indent=2, ensure_ascii=False)
print(f"\nAudit saved: {out}")
