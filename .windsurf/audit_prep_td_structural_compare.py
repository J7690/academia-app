#!/usr/bin/env python3
"""Phase 1b: Compare structural mapping between td_* and prep_* tables."""
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
    return body

# 1. Get columns of all td_* tables used by prep RPCs
td_tables = [
    "td_question_banks", "td_questions", "td_quiz_attempts", "td_quiz_templates",
    "td_exam_papers", "td_flashcard_decks", "td_flashcards", "td_flashcard_progress",
    "td_badges", "td_student_badges", "td_ai_conversations", "td_ai_messages", "td_ai_config",
]

# 2. Get columns of all prep_* tables
prep_tables = [
    "prep_subjects", "prep_chapters", "prep_questions", "prep_question_choices",
    "prep_attempts", "prep_exams", "prep_exam_items", "prep_source_documents",
    "prep_doc_chunks", "prep_ai_generations", "prep_ai_usage_logs",
]

all_tables = td_tables + prep_tables
results = {}

for t in all_tables:
    rows = sql(f"""
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = '{t}'
        ORDER BY ordinal_position
    """)
    count_rows = sql(f"SELECT COUNT(*) AS cnt FROM app.{t}")
    cnt = count_rows[0].get("cnt", "?") if isinstance(count_rows, list) and count_rows else "?"
    results[t] = {"columns": rows if isinstance(rows, list) else [], "row_count": cnt}
    cols = [r.get("column_name", "?") for r in (rows if isinstance(rows, list) else [])]
    print(f"  {t} ({cnt} rows): {cols}")

# Save
out = __import__("pathlib").Path(__file__).parent / "logs" / "audit_prep_td_structural.json"
with open(out, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)
print(f"\n✅ Sauvegardé: {out}")
