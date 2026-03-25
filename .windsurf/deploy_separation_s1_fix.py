#!/usr/bin/env python3
"""Fix S1: Create td bank with subject + move questions."""
import requests, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql_raw(q, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": q}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    err = body.get("error", "") if not ok else ""
    rows = body.get("rows", []) if ok else []
    print(f"  {'OK' if ok else 'ERR'} {label} {('-- ' + err[:200]) if err else ''}")
    return ok, rows

def sql(q, label=""): return sql_raw(" ".join(q.split()), label)

print("=" * 60)
print("FIX S1 -- Create bank + move questions")
print("=" * 60)

# 1. Check td_question_banks columns to know required fields
print("\n[1] td_question_banks columns:")
ok, cols = sql("SELECT column_name, is_nullable FROM information_schema.columns WHERE table_schema='app' AND table_name='td_question_banks' ORDER BY ordinal_position", "cols")
for c in cols: print(f"    {c['column_name']}: nullable={c['is_nullable']}")

# 2. Create bank with all required fields
print("\n[2] Create university bank:")
sql("INSERT INTO app.td_question_banks (title, description, subject, is_active) VALUES ('Contenu Universitaire BF', 'Questions pedagogiques universites BF', 'Toutes matieres', true) ON CONFLICT DO NOTHING", "Create bank")

ok, rows = sql("SELECT id FROM app.td_question_banks WHERE title = 'Contenu Universitaire BF' LIMIT 1", "Get bank ID")
td_bank_id = rows[0]["id"] if rows else None
print(f"  Bank ID: {td_bank_id}")

# 3. Move questions
if td_bank_id:
    print("\n[3] Copy 47 questions to td_questions:")
    sql(f"INSERT INTO app.td_questions (bank_id, question_type, content, options, correct_index, explanation, difficulty, subject, tags, points, is_active) SELECT '{td_bank_id}', COALESCE(question_type,'mcq'), content, options, correct_index, explanation, difficulty, subject, tags, COALESCE(points, 1), COALESCE(is_active, true) FROM app.prep_questions WHERE source = 'university_bf' ON CONFLICT DO NOTHING", "Copy to td_questions")

    print("\n[4] Delete from prep_questions:")
    sql("DELETE FROM app.prep_questions WHERE source = 'university_bf'", "Delete from prep")

# 4. Verify
print("\n--- VERIFICATION ---")
sql("SELECT COUNT(*) AS cnt FROM app.td_questions", "td_questions total")
sql("SELECT COUNT(*) AS cnt FROM app.prep_questions WHERE source = 'university_bf'", "prep university (should be 0)")
sql("SELECT COUNT(*) AS cnt FROM app.prep_questions WHERE is_published = true", "prep concours remaining")
sql("SELECT subject, COUNT(*) AS cnt FROM app.td_questions GROUP BY subject ORDER BY cnt DESC", "td_questions by subject")
