#!/usr/bin/env python3
"""Phase 2 Audit: Check pgvector availability, prep_doc_chunks columns, prep_source_documents columns."""
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
    err = body.get("error", "") if isinstance(body, dict) and not ok else ""
    rows = body.get("rows", []) if ok else []
    print(f"  {'✅' if ok else '❌'} {label} {('— ' + err[:150]) if err else ''}")
    return ok, rows

results = {}
print("=" * 60)
print("PHASE 2 AUDIT — pgvector + schema enrichment")
print("=" * 60)

# 1. Check if pgvector extension exists
print("\n[1] pgvector extension status:")
ok1, r1 = sql("SELECT extname, extversion FROM pg_extension WHERE extname = 'vector'", "Check pgvector")
print(f"  → {r1}")
results["pgvector_extension"] = r1

# 2. Check prep_doc_chunks current columns
print("\n[2] prep_doc_chunks columns:")
ok2, r2 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'prep_doc_chunks' ORDER BY ordinal_position", "prep_doc_chunks cols")
for c in r2:
    print(f"    {c.get('column_name')}: {c.get('data_type')}")
results["prep_doc_chunks_columns"] = r2

# 3. Check prep_source_documents current columns
print("\n[3] prep_source_documents columns:")
ok3, r3 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'prep_source_documents' ORDER BY ordinal_position", "prep_source_documents cols")
for c in r3:
    print(f"    {c.get('column_name')}: {c.get('data_type')}")
results["prep_source_documents_columns"] = r3

# 4. Check if tables prep_topics, prep_topic_predictions, prep_ai_corrections already exist
print("\n[4] New tables existence check:")
for t in ["prep_topics", "prep_question_topics", "prep_topic_predictions", "prep_ai_corrections"]:
    ok, r = sql(f"SELECT COUNT(*) AS exists FROM information_schema.tables WHERE table_schema = 'app' AND table_name = '{t}'", f"Table {t}")
    exists = r[0].get("exists", 0) if r else 0
    print(f"    → {'EXISTS' if exists > 0 else 'DOES NOT EXIST'}")
    results[f"table_{t}"] = exists

# 5. Check existing RPCs that reference prep_doc_chunks (to not break them)
print("\n[5] RPCs referencing prep_doc_chunks:")
ok5, r5 = sql("SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname IN ('public','app') AND pg_get_functiondef(p.oid) LIKE '%prep_doc_chunks%'", "RPCs using prep_doc_chunks")
for r in r5:
    print(f"    → {r.get('proname')}")
results["rpcs_using_doc_chunks"] = r5

# 6. Check prep_doc_chunks row count
print("\n[6] Data counts:")
ok6, r6 = sql("SELECT COUNT(*) AS cnt FROM app.prep_doc_chunks", "prep_doc_chunks count")
print(f"    → {r6}")
ok7, r7 = sql("SELECT COUNT(*) AS cnt FROM app.prep_source_documents", "prep_source_documents count")
print(f"    → {r7}")
results["prep_doc_chunks_count"] = r6
results["prep_source_documents_count"] = r7

# 7. Check existing RLS on prep_doc_chunks
print("\n[7] RLS policies on prep_doc_chunks:")
ok8, r8 = sql("SELECT policyname, cmd, roles FROM pg_policies WHERE schemaname = 'app' AND tablename = 'prep_doc_chunks'", "RLS prep_doc_chunks")
for p in r8:
    print(f"    → {p}")
results["rls_prep_doc_chunks"] = r8

# Save
out = Path(__file__).parent / "logs" / "audit_phase2_pgvector.json"
out.parent.mkdir(exist_ok=True)
with open(out, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"\n✅ Audit saved: {out}")
