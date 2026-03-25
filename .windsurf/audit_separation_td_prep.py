#!/usr/bin/env python3
"""Audit: Cartographier l'état actuel des tables TD vs Prep pour la séparation complète."""
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
print("AUDIT SEPARATION TD vs PREP")
print("=" * 60)

# 1. Existing td_questions table?
print("\n[1] Tables TD content/IA existantes:")
for t in ["td_questions", "td_question_banks", "td_doc_chunks", "td_source_documents",
          "td_ai_config", "td_ai_conversations", "td_ai_messages"]:
    ok, r = sql(f"SELECT COUNT(*) AS cnt FROM information_schema.tables WHERE table_schema='app' AND table_name='{t}'", t)
    exists = r[0].get("cnt", 0) if r else 0
    print(f"    {t}: {'EXISTS' if exists > 0 else 'DOES NOT EXIST'}")

# 2. td_questions columns if exists
print("\n[2] td_questions columns (if exists):")
ok2, r2 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='td_questions' ORDER BY ordinal_position", "td_questions cols")
for c in r2: print(f"    {c['column_name']}: {c['data_type']}")

# 3. prep_questions columns (reference)
print("\n[3] prep_questions columns (reference):")
ok3, r3 = sql("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='prep_questions' ORDER BY ordinal_position", "prep_questions cols")
for c in r3: print(f"    {c['column_name']}: {c['data_type']}")

# 4. Count university content currently in prep_questions
print("\n[4] University content in prep_questions:")
ok4, r4 = sql("SELECT source, COUNT(*) AS cnt FROM app.prep_questions WHERE source = 'university_bf' GROUP BY source", "university count")
for r in r4: print(f"    source={r.get('source')}: {r.get('cnt')} questions")

# 5. td_ai_config content
print("\n[5] td_ai_config:")
ok5, r5 = sql("SELECT config_key, LEFT(config_value, 80) AS preview FROM app.td_ai_config", "td_ai_config")
for c in r5: print(f"    {c.get('config_key')}: {c.get('preview')}")

# 6. prep_ai_config content
print("\n[6] prep_ai_config:")
ok6, r6 = sql("SELECT config_key, LEFT(config_value, 80) AS preview FROM app.prep_ai_config", "prep_ai_config")
for c in r6: print(f"    {c.get('config_key')}: {c.get('preview')}")

# 7. Edge Functions current state
print("\n[7] Edge Functions:")
for fn in ["prep-tutor-chat", "td-tutor-chat", "prep-ingest-document", "td-ingest-document", "prep-generate-questions", "td-generate-exercises"]:
    try:
        resp = requests.options(f"{URL}/functions/v1/{fn}", timeout=10)
        print(f"    {fn}: HTTP {resp.status_code}")
    except: print(f"    {fn}: TIMEOUT")

# 8. pgvector extension
print("\n[8] pgvector:")
ok8, r8 = sql("SELECT extname, extversion FROM pg_extension WHERE extname = 'vector'", "pgvector")
for r in r8: print(f"    {r.get('extname')} v{r.get('extversion')}")

out = Path(__file__).parent / "logs" / "audit_separation_td_prep.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump({"td_questions_exists": bool(r2), "prep_cols": r3, "td_ai_config": r5}, f, indent=2)
print(f"\nAudit saved: {out}")
