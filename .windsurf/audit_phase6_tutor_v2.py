#!/usr/bin/env python3
"""Phase 6 Audit: prep-tutor-chat current state, semantic search RPC, ai_corrections table."""
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
    print(f"  {'✅' if ok else '❌'} {label}")
    return ok, rows

results = {}
print("=" * 60)
print("PHASE 6 AUDIT — Tuteur IA v2")
print("=" * 60)

# 1. prep-tutor-chat Edge Function status
print("\n[1] Edge Function prep-tutor-chat:")
try:
    resp = requests.options(f"{URL}/functions/v1/prep-tutor-chat", timeout=10)
    print(f"    HTTP {resp.status_code}")
    results["edge_fn"] = resp.status_code
except Exception as e:
    print(f"    Error: {e}")

# 2. RPCs used by prep-tutor-chat
print("\n[2] RPCs used by tuteur:")
for rpc in ["app_prep_get_ai_config", "app_prep_list_ai_messages", "app_prep_save_ai_message", "app_prep_semantic_search"]:
    ok, r = sql(f"SELECT routine_name FROM information_schema.routines WHERE routine_name = '{rpc}'", rpc)
    print(f"    {rpc}: {'EXISTS' if r else 'MISSING'}")

# 3. prep_ai_corrections table
print("\n[3] prep_ai_corrections:")
ok3, r3 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_ai_corrections' ORDER BY ordinal_position", "columns")
for c in r3: print(f"    {c['column_name']}: {c['data_type']}")
ok3b, r3b = sql("SELECT COUNT(*) AS cnt FROM app.prep_ai_corrections", "count")
print(f"    rows: {r3b}")

# 4. prep_ai_conversations
print("\n[4] prep_ai_conversations:")
ok4, r4 = sql("SELECT COUNT(*) AS cnt FROM app.prep_ai_conversations", "count")
print(f"    rows: {r4}")

# 5. prep_doc_chunks with embeddings (for semantic search readiness)
print("\n[5] Chunks with embeddings:")
ok5, r5 = sql("SELECT COUNT(*) AS cnt FROM app.prep_doc_chunks WHERE embedding IS NOT NULL", "chunks with embeddings")
print(f"    → {r5}")

# 6. Check app_prep_semantic_search signature
print("\n[6] app_prep_semantic_search params:")
ok6, r6 = sql("SELECT parameter_name, data_type FROM information_schema.parameters p JOIN information_schema.routines r ON r.specific_name = p.specific_name WHERE r.routine_name = 'app_prep_semantic_search' AND p.parameter_name IS NOT NULL ORDER BY p.ordinal_position", "params")
for p in r6: print(f"    {p['parameter_name']}: {p['data_type']}")

out = Path(__file__).parent / "logs" / "audit_phase6_tutor_v2.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"\n✅ Audit saved: {out}")
