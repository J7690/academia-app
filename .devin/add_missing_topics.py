#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Add missing topics and their predictions."""
import sys, json, requests
sys.stdout.reconfigure(encoding='utf-8')
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

def run_sql(q, timeout=60):
    return requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers, json={"p_sql": q.strip()}, timeout=timeout).json()

def run_ddl(q, timeout=120):
    return requests.post(f"{m.url}/rest/v1/rpc/execute_ddl",
        headers=m.headers, json={"ddl_query": q.strip()}, timeout=timeout).json()

# Missing topics
missing = [
    ("Droit Constitutionnel", "droit", 80, 75, 90, 70, 70, 90, 9,
     "Constitution du BF, institutions, separation des pouvoirs. Fondamental."),
    ("Finances Publiques", "finances", 70, 90, 65, 45, 80, 55, 5,
     "Budget Etat, loi de finances, tresor. Cle pour ENAREF."),
    ("Comptabilite", "fiscalite", 50, 85, 40, 30, 70, 40, 2,
     "Plan comptable, ecritures. Specifique ENAREF et Douane."),
    ("Tests Psychotechniques", "mathematiques", 60, 55, 60, 80, 55, 50, 26,
     "Suites logiques, analogies, raisonnement. Fort pour Paramilitaire."),
    ("Droit Administratif", "droit", 75, 70, 90, 55, 65, 75, 6,
     "Actes administratifs, contentieux, service public BF."),
    ("Francais", "culture_gen", 80, 75, 80, 80, 70, 85, 5,
     "Grammaire, orthographe, resume, dissertation. Toujours present."),
    ("Actualites BF", "actualites", 85, 80, 85, 80, 75, 80, 8,
     "Actualites du Burkina Faso et de la sous-region. Toujours en culture gen."),
    ("Droit Fiscal", "fiscalite", 55, 90, 45, 35, 85, 45, 0,
     "Code des impots BF, procedures fiscales. Specifique ENAREF et Douane."),
]

concours_types = ["TOUS", "ENAREF", "ADMIN_CIVIL", "PARAMILITAIRE", "DOUANE", "GREFFIERS"]
total = 0

for name, cat, *scores_rest in missing:
    scores = scores_rest[:6]
    freq = scores_rest[6]
    reasoning = scores_rest[7]
    esc_name = name.replace("'", "''")
    esc_reason = reasoning.replace("'", "''")

    # Create topic
    r = run_sql(f"INSERT INTO app.prep_topics (name, category) VALUES ('{esc_name}', '{cat}') ON CONFLICT (name) DO UPDATE SET category = '{cat}' RETURNING id")
    tid = r.get("rows", [{}])[0].get("id") if r.get("rows") else None
    if not tid:
        print(f"  SKIP {name}")
        continue

    for i, ct in enumerate(concours_types):
        score = scores[i]
        run_sql(f"""
            INSERT INTO app.prep_topic_predictions (topic_id, concours_type, target_year, probability_score, frequency_count, reasoning)
            VALUES ('{tid}', '{ct}', '2027', {score}, {freq}, '{esc_reason}')
            ON CONFLICT (topic_id, concours_type, target_year) DO UPDATE SET
                probability_score = {score}, frequency_count = {freq}, reasoning = '{esc_reason}', updated_at = now()
        """)
        total += 1

    print(f"  [{scores[0]}%] {name} ({cat})")

print(f"\n  +{total} predictions")

# Re-run auto-tagging
print("\n=== Re-run auto-tagging ===")
r = run_sql("SELECT public.app_admin_auto_tag_questions_to_topics() AS result")
if r.get("rows"):
    print(f"  {r['rows'][0]}")

# Final counts
print("\n=== Final counts ===")
r = run_sql("SELECT count(*)::text AS n FROM app.prep_topics")
print(f"  Topics: {r.get('rows', [{}])[0].get('n','0') if r.get('rows') else '?'}")
r = run_sql("SELECT count(*)::text AS n FROM app.prep_topic_predictions")
print(f"  Predictions: {r.get('rows', [{}])[0].get('n','0') if r.get('rows') else '?'}")
r = run_sql("SELECT count(*)::text AS n FROM app.prep_question_topics")
print(f"  Q-T links: {r.get('rows', [{}])[0].get('n','0') if r.get('rows') else '?'}")

print("\n[OK]")
