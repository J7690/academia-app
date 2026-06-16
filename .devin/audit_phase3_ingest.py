#!/usr/bin/env python3
"""Phase 3 Audit: Check existing Edge Functions, RPCs for document ingestion, OpenRouter env vars."""
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
    err = body.get("error", "") if not ok else ""
    print(f"  {'✅' if ok else '❌'} {label} {('— ' + err[:150]) if err else ''}")
    return ok, rows

results = {}
print("=" * 60)
print("PHASE 3 AUDIT — Edge Function prep-ingest-document")
print("=" * 60)

# 1. RPCs that manage source documents
print("\n[1] RPCs for source documents:")
ok1, r1 = sql("SELECT routine_name, routine_schema FROM information_schema.routines WHERE routine_name LIKE '%source_document%' OR routine_name LIKE '%doc_chunk%' ORDER BY routine_name", "Source doc RPCs")
for r in r1:
    print(f"    {r.get('routine_schema')}.{r.get('routine_name')}")
results["source_doc_rpcs"] = r1

# 2. Check prep_source_documents status values
print("\n[2] Valid statuses in prep_source_documents:")
ok2, r2 = sql("SELECT DISTINCT status FROM app.prep_source_documents", "Distinct statuses")
print(f"    → {r2}")
results["statuses"] = r2

# 3. Check the RPC app_prep_get_rag_chunks body (it reads from prep_doc_chunks)
print("\n[3] app_prep_get_rag_chunks — reads from which tables:")
ok3, r3 = sql("SELECT pg_get_functiondef(p.oid) AS def FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE p.proname = 'app_prep_get_rag_chunks' LIMIT 1", "RAG chunks RPC")
if r3:
    defn = r3[0].get("def", "")
    uses = []
    for t in ["prep_doc_chunks", "prep_source_documents", "prep_questions"]:
        if t in defn:
            uses.append(t)
    print(f"    Uses tables: {uses}")
    # Check which statuses it filters
    if "indexed" in defn:
        print("    Filters: status IN ('indexed', 'validated', 'published')")
results["rag_chunks_tables"] = uses if r3 else []

# 4. Check bucket prep-documents
print("\n[4] Storage bucket prep-documents:")
ok4, r4 = sql("SELECT id, name, public, file_size_limit FROM storage.buckets WHERE name = 'prep-documents'", "Bucket check")
for r in r4:
    print(f"    {r}")
results["bucket"] = r4

# 5. Existing Edge Functions (check by OPTIONS)
print("\n[5] Edge Function availability:")
for fn in ["prep-tutor-chat", "prep-ingest-document", "bobodo-chat"]:
    try:
        resp = requests.options(f"{URL}/functions/v1/{fn}", timeout=10)
        status = resp.status_code
    except:
        status = "ERROR"
    print(f"    {fn}: HTTP {status}")
    results[f"edge_{fn}"] = status

# 6. Check OpenRouter env vars (via prep-tutor-chat which uses them)
print("\n[6] OpenRouter config (from prep_ai_config):")
ok6, r6 = sql("SELECT config_key, LEFT(config_value, 30) AS preview FROM app.prep_ai_config", "AI config")
for r in r6:
    print(f"    {r.get('config_key')}: {r.get('preview')}")
results["ai_config"] = r6

# Save
out = Path(__file__).parent / "logs" / "audit_phase3_ingest.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"\n✅ Audit saved: {out}")
