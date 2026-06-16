#!/usr/bin/env python3
"""Phase S3 Audit: td_questions structure, td_doc_chunks readiness, Edge Function status."""
import requests, json
URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": " ".join(q.split())}, timeout=30)
    body = r.json() if r.status_code == 200 else {"ok": False}
    ok = isinstance(body, dict) and body.get("ok", False)
    rows = body.get("rows", []) if ok else []
    print(f"  {'OK' if ok else 'ERR'} {label}")
    return rows

print("=== S3 AUDIT ===")
print("\n[1] td_questions columns:")
for c in sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='td_questions' ORDER BY ordinal_position", "cols"):
    print(f"    {c['column_name']}: {c['data_type']}")

print("\n[2] td_questions count:")
r = sql("SELECT COUNT(*) AS cnt FROM app.td_questions", "count")
print(f"    {r[0].get('cnt',0) if r else '?'}")

print("\n[3] td_question_banks:")
for b in sql("SELECT id, title, subject FROM app.td_question_banks LIMIT 5", "banks"):
    print(f"    {b.get('title')} ({b.get('subject')})")

print("\n[4] app_td_semantic_search exists:")
r = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name = 'app_td_semantic_search'", "rpc")
print(f"    {'EXISTS' if r else 'MISSING'}")

print("\n[5] Edge Function td-generate-exercises:")
try:
    resp = requests.options(f"{URL}/functions/v1/td-generate-exercises", timeout=10)
    print(f"    HTTP {resp.status_code}")
except: print("    TIMEOUT")
