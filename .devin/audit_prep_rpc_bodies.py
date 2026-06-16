#!/usr/bin/env python3
"""Audit Phase 1: Examine les corps des RPCs prep pour identifier quelles tables elles référencent."""
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

TABLE_TOKENS = [
    "td_question_banks", "td_questions", "td_quiz_attempts", "td_quiz_templates",
    "td_exam_papers", "td_flashcard_decks", "td_flashcards", "td_flashcard_progress",
    "td_badges", "td_student_badges", "td_ai_conversations", "td_ai_messages",
    "td_ai_config", "td_daily_goals",
    "prep_subjects", "prep_chapters", "prep_questions", "prep_question_choices",
    "prep_attempts", "prep_exams", "prep_exam_items", "prep_source_documents",
    "prep_doc_chunks", "prep_ai_generations", "prep_ai_usage_logs",
    "user_feature_entitlements",
]

RPCS = [
    "app_prep_create_question_bank", "app_prep_create_question",
    "app_prep_list_question_banks", "app_prep_list_questions",
    "app_prep_create_exam_paper", "app_prep_list_exam_papers",
    "app_prep_create_flashcard_deck", "app_prep_list_flashcard_decks",
    "app_prep_create_flashcard", "app_prep_list_flashcards",
    "app_prep_save_quiz_attempt", "app_prep_save_flashcard_review",
    "app_prep_admin_get_stats", "app_prep_admin_list_questions",
    "app_prep_admin_toggle_question", "app_prep_admin_upsert_badge",
    "app_prep_get_student_progress", "app_prep_get_subject_stats",
    "app_prep_get_leaderboard", "app_prep_get_ai_config",
    "app_prep_create_ai_conversation", "app_prep_save_ai_message",
    "app_prep_list_ai_conversations", "app_prep_list_ai_messages",
    "app_prep_update_ai_config", "app_prep_admin_list_ai_conversations",
    "app_prep_list_quiz_templates", "app_prep_create_quiz_template",
    # student-side RPCs (public schema)
    "app_prep_list_subjects", "app_prep_list_chapters",
    "app_prep_list_published_questions", "app_prep_list_question_choices",
    "app_prep_create_attempt", "app_prep_list_my_attempts",
    "app_prep_get_my_subject_stats", "app_prep_get_my_entitlement",
]

print("=" * 70)
print("AUDIT PHASE 1 — Corps des RPCs Prep Concours")
print("=" * 70)

# Get all function sources in one query
rows = sql("""
    SELECT n.nspname AS schema, p.proname AS name, 
           pg_get_functiondef(p.oid) AS definition
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname LIKE '%prep%'
      AND n.nspname IN ('public', 'app')
    ORDER BY p.proname
""")

# Build lookup
rpc_defs = {}
for row in rows:
    name = row.get("name", "")
    if name not in rpc_defs:
        rpc_defs[name] = row

results = {}
for rpc in RPCS:
    info = rpc_defs.get(rpc)
    if not info:
        results[rpc] = {"schema": "NOT FOUND", "tables": [], "security": "?"}
        print(f"\n  {rpc}: NOT FOUND")
        continue

    defn = info.get("definition", "")
    schema = info.get("schema", "?")

    # Find referenced tables
    tables_found = []
    for t in TABLE_TOKENS:
        if t in defn:
            tables_found.append(t)

    # Check security definer
    sec = "DEFINER" if "SECURITY DEFINER" in defn.upper() else "INVOKER"

    results[rpc] = {"schema": schema, "tables": tables_found, "security": sec}
    prefix = "td" if any(t.startswith("td_") for t in tables_found) else "prep" if any(t.startswith("prep_") for t in tables_found) else "none"
    print(f"\n  {rpc} [{schema}] [{sec}] → {prefix}: {tables_found}")

# Save
out = __import__("pathlib").Path(__file__).parent / "logs" / "audit_prep_rpc_bodies.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)

print(f"\n✅ Sauvegardé: {out}")
