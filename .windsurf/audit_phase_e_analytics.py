#!/usr/bin/env python3
"""Phase E Audit: psychotech tables, RPCs, existing data."""
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
print("PHASE E AUDIT -- Analytics adaptatif")
print("=" * 60)

print("\n[1] Psychotech RPCs:")
ok1, r1 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE '%psychotech%' ORDER BY routine_name", "RPCs")
for r in r1: print(f"    {r.get('routine_name')}")

print("\n[2] Tables:")
for t in ["prep_psychotech_results", "prep_psychotech_profiles"]:
    ok, r = sql(f"SELECT COUNT(*) AS cnt FROM app.{t}", t)
    print(f"    {t}: {r[0].get('cnt',0) if r else '?'} rows")

print("\n[3] prep_psychotech_profiles columns:")
ok3, r3 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_psychotech_profiles' ORDER BY ordinal_position", "cols")
for c in r3: print(f"    {c['column_name']}: {c['data_type']}")

print("\n[4] prep_psychotech_results columns:")
ok4, r4 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_psychotech_results' ORDER BY ordinal_position", "cols")
for c in r4: print(f"    {c['column_name']}: {c['data_type']}")

out = Path(__file__).parent / "logs" / "audit_phase_e_analytics.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"rpcs": r1, "profiles_cols": r3, "results_cols": r4}, f, indent=2, ensure_ascii=False)
print(f"\nAudit saved: {out}")
