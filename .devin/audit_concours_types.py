#!/usr/bin/env python3
"""Audit concours types, subjects, and question distribution."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

m = SupabaseAutoManager()

def sql(q):
    r = requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql", headers=m.headers, json={"p_sql": q.strip()}, timeout=30).json()
    return r.get("rows", [])

print("=== 1. Distinct concours_type values ===")
for row in sql("SELECT DISTINCT concours_type, count(*) AS cnt FROM app.prep_questions GROUP BY concours_type ORDER BY cnt DESC"):
    print(f"  {row}")

print("\n=== 2. Subjects ===")
for row in sql("SELECT id, title, slug, concours_type FROM app.prep_subjects ORDER BY title"):
    print(f"  {row}")

print("\n=== 3. Questions per subject ===")
for row in sql("""
    SELECT s.title AS subject, q.concours_type, count(*) AS cnt
    FROM app.prep_questions q
    LEFT JOIN app.prep_subjects s ON s.id = q.subject_id
    GROUP BY s.title, q.concours_type
    ORDER BY cnt DESC
    LIMIT 20
"""):
    print(f"  {row}")

print("\n=== 4. Chapters per subject ===")
for row in sql("""
    SELECT s.title AS subject, count(c.id) AS chapters
    FROM app.prep_subjects s
    LEFT JOIN app.prep_chapters c ON c.subject_id = s.id
    GROUP BY s.title
    ORDER BY chapters DESC
"""):
    print(f"  {row}")

print("\n=== 5. AI generation modes used ===")
for row in sql("SELECT DISTINCT generation_type, status, count(*) AS cnt FROM app.prep_ai_generations GROUP BY generation_type, status ORDER BY cnt DESC"):
    print(f"  {row}")

print("\n=== 6. Question banks ===")
for row in sql("SELECT id, title, concours_type, mode, questions_count, is_published FROM app.prep_question_banks ORDER BY created_at DESC LIMIT 10"):
    print(f"  {row}")

print("\n=== 7. prep_generate_questions Edge Function modes ===")
print("  (from code: similar, exam_blanc, revision, adaptive)")

print("\n=== 8. Concours type values in prep_doc_chunks ===")
for row in sql("SELECT DISTINCT concours_type, count(*) AS cnt FROM app.prep_doc_chunks GROUP BY concours_type ORDER BY cnt DESC"):
    print(f"  {row}")

print("\n=== 9. Concours type values in prep_source_documents ===")
for row in sql("SELECT DISTINCT concours_type, count(*) AS cnt FROM app.prep_source_documents GROUP BY concours_type ORDER BY cnt DESC"):
    print(f"  {row}")
