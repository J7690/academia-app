#!/usr/bin/env python3
"""Verify Phase 2 deployment."""
import json, requests

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=30)
    body = r.json()
    if isinstance(body, dict) and body.get("ok"):
        return body.get("rows", [])
    return []

print("=== PHASE 2 VERIFICATION ===\n")

print("prep_doc_chunks columns:")
for c in sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_doc_chunks' ORDER BY ordinal_position"):
    print(f"  {c['column_name']:25s} {c['data_type']}")

print("\nprep_source_documents columns:")
for c in sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_source_documents' ORDER BY ordinal_position"):
    print(f"  {c['column_name']:25s} {c['data_type']}")

print("\nNew tables:")
for t in ["prep_topics", "prep_question_topics", "prep_topic_predictions", "prep_ai_corrections"]:
    r = sql(f"SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}'")
    print(f"  {t}: {'EXISTS' if r and r[0].get('cnt',0) > 0 else 'MISSING'}")

print("\nNew RPCs:")
for r in sql("SELECT routine_name FROM information_schema.routines WHERE routine_name IN ('app_prep_semantic_search','app_prep_get_predictions') ORDER BY routine_name"):
    print(f"  {r['routine_name']}")

print("\nRLS policies on new tables:")
r = sql("SELECT COUNT(*) AS cnt FROM pg_policies WHERE schemaname='app' AND tablename IN ('prep_topics','prep_question_topics','prep_topic_predictions','prep_ai_corrections')")
print(f"  Total: {r[0].get('cnt',0) if r else 0} policies")

print("\nIndex on embedding:")
for r in sql("SELECT indexname FROM pg_indexes WHERE schemaname='app' AND tablename='prep_doc_chunks' AND indexname LIKE '%embedding%'"):
    print(f"  {r['indexname']}")

print("\n✅ Verification complete")
