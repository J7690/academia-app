#!/usr/bin/env python3
"""Phase 3 TD Audit: Verify local groups tables + RPCs from Phase 1."""
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
print("PHASE 3 TD AUDIT -- Groupes Locaux")
print("=" * 60)

# 1. Verify tables exist (Phase 1)
print("\n[1] Tables Phase 1:")
for t in ["td_student_profiles", "td_local_groups", "td_local_group_members"]:
    ok, r = sql(f"SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}'", t)
    print(f"    -> {'EXISTS' if r and r[0].get('cnt',0) > 0 else 'MISSING!'}")

# 2. Verify RPCs exist (Phase 1)
print("\n[2] RPCs Phase 1:")
for rpc in ["app_td_student_upsert_profile", "app_td_student_get_profile", "app_td_student_list_local_groups", "app_td_student_join_group", "app_td_student_create_group"]:
    ok, r = sql(f"SELECT routine_name FROM information_schema.routines WHERE routine_name = '{rpc}'", rpc)
    print(f"    {rpc}: {'EXISTS' if r else 'MISSING!'}")

# 3. td_local_groups columns
print("\n[3] td_local_groups columns:")
ok3, r3 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='td_local_groups' ORDER BY ordinal_position", "cols")
for c in r3: print(f"    {c['column_name']}: {c['data_type']}")

# 4. students city/geo fields
print("\n[4] students geo fields:")
ok4, r4 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='students' AND column_name IN ('city','geo_latitude','geo_longitude','full_name') ORDER BY column_name", "geo cols")
for c in r4: print(f"    {c['column_name']}: {c['data_type']}")

# 5. Data counts
print("\n[5] Row counts:")
for t in ["td_student_profiles", "td_local_groups", "td_local_group_members"]:
    ok, r = sql(f"SELECT COUNT(*) AS cnt FROM app.{t}", t)
    print(f"    {t}: {r[0].get('cnt',0) if r else '?'}")

out = Path(__file__).parent / "logs" / "audit_td_phase3.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"tables": True, "rpcs": True}, f, indent=2)
print(f"\nAudit saved: {out}")
