#!/usr/bin/env python3
"""Phase 12 Audit: Admin prep RPCs, existing screen structure, Edge Functions."""
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
print("PHASE 12 AUDIT -- Admin upload PDF + predictions")
print("=" * 60)

# 1. AdminPrepConcoursProvider methods already exist
print("\n[1] Admin prep RPCs:")
ok1, r1 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name LIKE 'app_admin_prep%' ORDER BY routine_name", "admin prep RPCs")
for r in r1: print(f"    {r.get('routine_name')}")

# 2. Bucket
print("\n[2] Bucket prep-documents:")
ok2, r2 = sql("SELECT id, name, public FROM storage.buckets WHERE name = 'prep-documents'", "bucket")
for r in r2: print(f"    {r}")

# 3. Predictions RPC
print("\n[3] Predictions RPC:")
ok3, r3 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name = 'app_prep_get_predictions'", "predictions")
for r in r3: print(f"    {r.get('routine_name')}")

# 4. Edge Functions
print("\n[4] Edge Functions:")
for fn in ["prep-ingest-document", "prep-generate-questions", "prep-analyze-trends"]:
    try:
        resp = requests.options(f"{URL}/functions/v1/{fn}", timeout=10)
        print(f"    {fn}: HTTP {resp.status_code}")
    except: print(f"    {fn}: ERROR")

# 5. Data counts
print("\n[5] Data:")
for t in ["prep_source_documents", "prep_doc_chunks", "prep_topics", "prep_topic_predictions", "prep_questions"]:
    ok, r = sql(f"SELECT COUNT(*) AS cnt FROM app.{t}", t)
    print(f"    {t}: {r[0].get('cnt',0) if r else '?'}")

out = Path(__file__).parent / "logs" / "audit_phase12_admin.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"admin_rpcs": r1}, f, indent=2, ensure_ascii=False)
print(f"\nAudit saved: {out}")
