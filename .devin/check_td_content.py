#!/usr/bin/env python3
"""Check: what's actually in td_questions vs prep_questions."""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": " ".join(q.split())}, timeout=30)
    body = r.json() if r.status_code == 200 else {"ok": False}
    return body.get("rows", []) if isinstance(body, dict) and body.get("ok") else []

print("=== ETAT DES CONTENUS ===\n")

print("[1] td_questions:")
r1 = sql("SELECT COUNT(*) AS cnt FROM app.td_questions")
print(f"    Total: {r1[0].get('cnt',0) if r1 else 0}")

r1b = sql("SELECT subject, COUNT(*) AS cnt FROM app.td_questions GROUP BY subject ORDER BY cnt DESC")
for r in r1b: print(f"    {r.get('subject','?'):30s} {r.get('cnt',0)}")

print(f"\n[2] prep_questions:")
r2 = sql("SELECT COUNT(*) AS cnt FROM app.prep_questions WHERE is_published = true")
print(f"    Total: {r2[0].get('cnt',0) if r2 else 0}")

r2b = sql("SELECT source, COUNT(*) AS cnt FROM app.prep_questions GROUP BY source ORDER BY cnt DESC")
for r in r2b: print(f"    source={r.get('source','?'):20s} {r.get('cnt',0)}")

print(f"\n[3] td_doc_chunks:")
r3 = sql("SELECT COUNT(*) AS cnt FROM app.td_doc_chunks")
print(f"    Total: {r3[0].get('cnt',0) if r3 else 0}")

print(f"\n[4] td_source_documents:")
r4 = sql("SELECT COUNT(*) AS cnt FROM app.td_source_documents")
print(f"    Total: {r4[0].get('cnt',0) if r4 else 0}")

print(f"\n[5] td_question_banks:")
r5 = sql("SELECT id, title, subject FROM app.td_question_banks")
for r in r5: print(f"    {r.get('title')} ({r.get('subject')})")
