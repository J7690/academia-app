#!/usr/bin/env python3
"""Phase 4 Audit: RPCs for question insertion, existing generation pipeline, prep_questions structure."""
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
print("PHASE 4 AUDIT — prep-generate-questions")
print("=" * 60)

# 1. Existing RPCs for creating questions
print("\n[1] RPCs for question creation/management:")
ok1, r1 = sql("SELECT routine_name, routine_schema FROM information_schema.routines WHERE routine_name LIKE '%prep%question%' OR routine_name LIKE '%prep%create_question%' ORDER BY routine_name", "Question RPCs")
for r in r1:
    print(f"    {r.get('routine_schema')}.{r.get('routine_name')}")
results["question_rpcs"] = r1

# 2. app_prep_create_question signature — does it insert into prep_questions?
print("\n[2] app_prep_create_question target table:")
ok2, r2 = sql("SELECT pg_get_functiondef(p.oid) AS def FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE p.proname = 'app_prep_create_question' AND n.nspname = 'app' LIMIT 1", "Create question RPC body")
if r2:
    defn = r2[0].get("def", "")
    for t in ["prep_questions", "prep_question_choices", "td_questions"]:
        if t in defn:
            print(f"    → Uses table: {t}")
results["create_question_body"] = "prep_questions" if r2 and "prep_questions" in r2[0].get("def", "") else "unknown"

# 3. Current prep_questions count + sample
print("\n[3] prep_questions current state:")
ok3, r3 = sql("SELECT COUNT(*) AS cnt FROM app.prep_questions WHERE is_published = true", "Published questions")
print(f"    → {r3}")

# 4. prep_ai_generations current state
print("\n[4] prep_ai_generations:")
ok4, r4 = sql("SELECT COUNT(*) AS cnt FROM app.prep_ai_generations", "AI generations count")
print(f"    → {r4}")

# 5. Check app_admin_prep_publish_ai_generation — what does it do?
print("\n[5] app_admin_prep_publish_ai_generation body:")
ok5, r5 = sql("SELECT pg_get_functiondef(p.oid) AS def FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE p.proname = 'app_admin_prep_publish_ai_generation' LIMIT 1", "Publish AI generation")
if r5:
    defn = r5[0].get("def", "")
    # Check if it inserts into prep_questions
    inserts_questions = "prep_questions" in defn
    print(f"    → Inserts into prep_questions: {inserts_questions}")
    print(f"    → Length: {len(defn)} chars")
results["publish_inserts_questions"] = inserts_questions if r5 else False

# 6. Edge function availability
print("\n[6] Edge Function prep-generate-questions:")
try:
    resp = requests.options(f"{URL}/functions/v1/prep-generate-questions", timeout=10)
    print(f"    → HTTP {resp.status_code}")
    results["edge_fn_status"] = resp.status_code
except Exception as e:
    print(f"    → Error: {e}")
    results["edge_fn_status"] = "error"

# 7. Check app_prep_semantic_search exists (we'll use it)
print("\n[7] Semantic search RPC:")
ok7, r7 = sql("SELECT routine_name FROM information_schema.routines WHERE routine_name = 'app_prep_semantic_search'", "Semantic search")
print(f"    → {'EXISTS' if r7 else 'MISSING'}")

# 8. prep_question_banks — existing banks
print("\n[8] Question banks:")
ok8, r8 = sql("SELECT id, title, concours_type, subject FROM app.prep_question_banks LIMIT 10", "Banks list")
for r in r8:
    print(f"    → {r.get('title')} ({r.get('concours_type')}/{r.get('subject')})")
results["banks"] = r8

# Save
out = Path(__file__).parent / "logs" / "audit_phase4_generate.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"\n✅ Audit saved: {out}")
