#!/usr/bin/env python3
"""Phase A Audit: Check if psychotech tables exist, existing prep_* schema, providers registered."""
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

results = {}
print("=" * 60)
print("PHASE A AUDIT -- Machine Psychotechnique")
print("=" * 60)

# 1. Check if psychotech tables already exist
print("\n[1] Psychotech tables existence:")
for t in ["prep_psychotech_results", "prep_psychotech_profiles"]:
    ok, r = sql(f"SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}'", t)
    exists = r[0].get("cnt", 0) if r else 0
    print(f"    -> {'EXISTS' if exists > 0 else 'DOES NOT EXIST'}")
    results[t] = exists

# 2. Check existing psychotech RPCs
print("\n[2] Psychotech RPCs:")
ok2, r2 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE '%psychotech%' ORDER BY routine_name", "psychotech RPCs")
for r in r2: print(f"    {r.get('routine_name')}")
results["psychotech_rpcs"] = r2

# 3. Total prep_* tables (current)
print("\n[3] Current prep_* tables count:")
ok3, r3 = sql("SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name LIKE 'prep_%'", "prep_* count")
print(f"    -> {r3[0].get('cnt',0) if r3 else '?'}")

# 4. Check prep_student_progress table (we'll link psychotech to it)
print("\n[4] prep_student_progress columns:")
ok4, r4 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_student_progress' ORDER BY ordinal_position", "columns")
for c in r4: print(f"    {c['column_name']}: {c['data_type']}")

# 5. Current published questions count by subject (to see psychotech questions)
print("\n[5] Psychotech questions currently in DB:")
ok5, r5 = sql("SELECT COUNT(*) AS cnt FROM app.prep_questions WHERE subject = 'Tests Psychotechniques' AND is_published = true", "psychotech questions")
print(f"    -> {r5[0].get('cnt',0) if r5 else 0}")

# 6. Existing prep_badges (to add psychotech badges)
print("\n[6] Existing badges:")
ok6, r6 = sql("SELECT code, title FROM app.prep_badges ORDER BY code", "badges")
for b in r6: print(f"    {b.get('code')}: {b.get('title')}")

out = Path(__file__).parent / "logs" / "audit_phase_a_psychotech.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"\nAudit saved: {out}")
