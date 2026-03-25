#!/usr/bin/env python3
"""Phase 5 Audit: Tables prep_topics, prep_topic_predictions, prep_doc_chunks state, RPCs."""
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
print("PHASE 5 AUDIT — prep-analyze-trends")
print("=" * 60)

# 1. prep_topics table status
print("\n[1] prep_topics:")
ok1, r1 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_topics' ORDER BY ordinal_position", "columns")
for c in r1: print(f"    {c['column_name']}: {c['data_type']}")
ok1b, r1b = sql("SELECT COUNT(*) AS cnt FROM app.prep_topics", "count")
print(f"    rows: {r1b}")
results["prep_topics"] = {"columns": r1, "count": r1b}

# 2. prep_topic_predictions table status
print("\n[2] prep_topic_predictions:")
ok2, r2 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_topic_predictions' ORDER BY ordinal_position", "columns")
for c in r2: print(f"    {c['column_name']}: {c['data_type']}")
ok2b, r2b = sql("SELECT COUNT(*) AS cnt FROM app.prep_topic_predictions", "count")
print(f"    rows: {r2b}")
results["prep_topic_predictions"] = {"columns": r2, "count": r2b}

# 3. prep_question_topics junction
print("\n[3] prep_question_topics:")
ok3, r3 = sql("SELECT COUNT(*) AS cnt FROM app.prep_question_topics", "count")
print(f"    rows: {r3}")

# 4. prep_doc_chunks — how many indexed chunks exist?
print("\n[4] prep_doc_chunks:")
ok4, r4 = sql("SELECT COUNT(*) AS cnt FROM app.prep_doc_chunks", "count")
print(f"    rows: {r4}")

# 5. app_prep_get_predictions RPC exists?
print("\n[5] RPCs:")
ok5, r5 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name IN ('app_prep_get_predictions','app_prep_semantic_search') ORDER BY routine_name", "prediction RPCs")
for r in r5: print(f"    {r['routine_name']}")

# 6. Edge function
print("\n[6] Edge Function prep-analyze-trends:")
try:
    resp = requests.options(f"{URL}/functions/v1/prep-analyze-trends", timeout=10)
    print(f"    HTTP {resp.status_code}")
    results["edge_fn"] = resp.status_code
except Exception as e:
    print(f"    Error: {e}")

# 7. Existing questions — which subjects/concours_type do we have?
print("\n[7] Questions by subject/concours_type:")
ok7, r7 = sql("SELECT subject, concours_type, COUNT(*) AS cnt FROM app.prep_questions WHERE is_published GROUP BY subject, concours_type ORDER BY cnt DESC", "questions breakdown")
for r in r7: print(f"    {r.get('subject')}/{r.get('concours_type')}: {r.get('cnt')}")
results["questions_breakdown"] = r7

out = Path(__file__).parent / "logs" / "audit_phase5_trends.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"\n✅ Audit saved: {out}")
