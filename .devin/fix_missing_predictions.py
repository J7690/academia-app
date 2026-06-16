#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fix missing topics and predictions - use exact DB names."""
import sys, json, requests
sys.stdout.reconfigure(encoding='utf-8')
from supabase_auto_manager import SupabaseAutoManager
m = SupabaseAutoManager()

def sql(q, timeout=60):
    return requests.post(f"{m.url}/rest/v1/rpc/admin_execute_sql",
        headers=m.headers, json={"p_sql": q.strip()}, timeout=timeout).json()

def ddl(q, timeout=120):
    return requests.post(f"{m.url}/rest/v1/rpc/execute_ddl",
        headers=m.headers, json={"ddl_query": q.strip()}, timeout=timeout).json()

# 1. Get existing topics
r = sql("SELECT id, name FROM app.prep_topics ORDER BY name")
existing = {row["name"]: row["id"] for row in r.get("rows", [])}
print("Existing topics:", list(existing.keys()))

# 2. Topics to create (not in DB yet)
to_create = {
    "Droit Constitutionnel": "droit",
    "Droit Administratif": "droit",
    "Finances Publiques": "finances",
    "Francais": "culture_gen",
    "Tests Psychotechniques": "mathematiques",
    "Droit Fiscal": "fiscalite",
    "Actualites BF": "actualites",
}

for name, cat in to_create.items():
    if name not in existing:
        esc = name.replace("'", "''")
        r = ddl(f"INSERT INTO app.prep_topics (name, category) VALUES ('{esc}', '{cat}')")
        # Get the new ID
        r2 = sql(f"SELECT id FROM app.prep_topics WHERE name = '{esc}'")
        if r2.get("rows"):
            existing[name] = r2["rows"][0]["id"]
            print(f"  Created: {name} -> {existing[name][:8]}...")
        else:
            print(f"  FAILED to create: {name}")

print(f"\nTotal topics now: {len(existing)}")

# 3. Define all predictions
# Format: topic_name -> {concours_type: (score, freq, reasoning)}
all_predictions = {
    "Droit Constitutionnel": {
        "TOUS": (80, 9), "ENAREF": (75, 9), "ADMIN_CIVIL": (90, 9),
        "PARAMILITAIRE": (70, 9), "DOUANE": (70, 9), "GREFFIERS": (90, 9),
    },
    "Droit Administratif": {
        "TOUS": (75, 6), "ENAREF": (70, 6), "ADMIN_CIVIL": (90, 6),
        "PARAMILITAIRE": (55, 6), "DOUANE": (65, 6), "GREFFIERS": (75, 6),
    },
    "Finances Publiques": {
        "TOUS": (70, 5), "ENAREF": (90, 5), "ADMIN_CIVIL": (65, 5),
        "PARAMILITAIRE": (45, 5), "DOUANE": (80, 5), "GREFFIERS": (55, 5),
    },
    "Francais": {
        "TOUS": (80, 5), "ENAREF": (75, 5), "ADMIN_CIVIL": (80, 5),
        "PARAMILITAIRE": (80, 5), "DOUANE": (70, 5), "GREFFIERS": (85, 5),
    },
    "Tests Psychotechniques": {
        "TOUS": (60, 26), "ENAREF": (55, 26), "ADMIN_CIVIL": (60, 26),
        "PARAMILITAIRE": (80, 26), "DOUANE": (55, 26), "GREFFIERS": (50, 26),
    },
    "Droit Fiscal": {
        "TOUS": (55, 0), "ENAREF": (90, 0), "ADMIN_CIVIL": (45, 0),
        "PARAMILITAIRE": (35, 0), "DOUANE": (85, 0), "GREFFIERS": (45, 0),
    },
    "Actualites BF": {
        "TOUS": (85, 8), "ENAREF": (80, 8), "ADMIN_CIVIL": (85, 8),
        "PARAMILITAIRE": (80, 8), "DOUANE": (75, 8), "GREFFIERS": (80, 8),
    },
}

reasonings = {
    "Droit Constitutionnel": "Constitution du BF, institutions, separation des pouvoirs. Fondamental.",
    "Droit Administratif": "Actes administratifs, contentieux, service public BF.",
    "Finances Publiques": "Budget Etat, loi de finances, tresor. Cle pour ENAREF.",
    "Francais": "Grammaire, orthographe, resume, dissertation. Toujours present.",
    "Tests Psychotechniques": "Suites logiques, analogies, raisonnement. Fort pour Paramilitaire.",
    "Droit Fiscal": "Code des impots BF, procedures fiscales. Specifique ENAREF et Douane.",
    "Actualites BF": "Actualites du Burkina Faso et de la sous-region. Toujours en culture gen.",
}

inserted = 0
for topic_name, preds in all_predictions.items():
    tid = existing.get(topic_name)
    if not tid:
        print(f"  SKIP {topic_name}: not in DB")
        continue

    reason = reasonings.get(topic_name, "").replace("'", "''")
    for ct, (score, freq) in preds.items():
        r = sql(f"""
            INSERT INTO app.prep_topic_predictions (topic_id, concours_type, target_year, probability_score, frequency_count, reasoning)
            VALUES ('{tid}', '{ct}', '2027', {score}, {freq}, '{reason}')
            ON CONFLICT (topic_id, concours_type, target_year) DO UPDATE SET
                probability_score = {score}, frequency_count = {freq}, reasoning = '{reason}', updated_at = now()
        """)
        if r.get("ok"):
            inserted += 1

    print(f"  [{preds['TOUS'][0]}%] {topic_name}")

print(f"\n  +{inserted} predictions")

# Final stats
print("\n=== FINAL ===")
r = sql("SELECT count(*)::text AS n FROM app.prep_topics")
print(f"  Topics: {r.get('rows', [{}])[0].get('n','?') if r.get('rows') else '?'}")
r = sql("SELECT count(*)::text AS n FROM app.prep_topic_predictions")
print(f"  Predictions: {r.get('rows', [{}])[0].get('n','?') if r.get('rows') else '?'}")

# Re-run tagging
r = sql("SELECT public.app_admin_auto_tag_questions_to_topics() AS result")
if r.get("rows"):
    print(f"  Auto-tag: {r['rows'][0]}")

r = sql("SELECT count(*)::text AS n FROM app.prep_question_topics")
print(f"  Q-T links: {r.get('rows', [{}])[0].get('n','?') if r.get('rows') else '?'}")

print("\n[OK]")
