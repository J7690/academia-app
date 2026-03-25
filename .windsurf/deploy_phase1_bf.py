#!/usr/bin/env python3
"""Deploy Phase 1: BF adaptation SQL."""
import json, requests, time, re
from pathlib import Path

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q, label=""):
    clean = " ".join(q.split())
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": clean}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    err = body.get("error", "") if isinstance(body, dict) and not ok else ""
    print(f"  {'✅' if ok else '❌'} {label} {('— ' + err[:200]) if err else ''}")
    return ok

print("=" * 60)
print("PHASE 1 — Deploying BF Adaptation SQL")
print("=" * 60)

# 1. Delete old maths subject
sql("DELETE FROM app.prep_subjects WHERE slug = 'maths'", "Delete old 'maths' subject")

# 2. Insert BF subjects (one by one to handle ON CONFLICT properly)
subjects = [
    ("culture_gen", "Culture Générale", "Questions de culture générale pour tous les concours du Burkina Faso", 1),
    ("actualites_bf", "Actualités du Burkina Faso", "Actualités nationales et internationales en rapport avec le Burkina Faso", 2),
    ("droit_constit", "Droit Constitutionnel", "Constitution du Burkina Faso, organisation des pouvoirs, droits fondamentaux", 3),
    ("droit_admin", "Droit Administratif", "Organisation administrative, actes administratifs, contentieux administratif", 4),
    ("droit_civil", "Droit Civil", "Droit des personnes, droit des obligations, droit des contrats", 5),
    ("droit_penal", "Droit Pénal", "Infractions, procédure pénale, droit pénal général et spécial", 6),
    ("droit_travail", "Droit du Travail", "Contrat de travail, relations professionnelles, sécurité sociale", 7),
    ("droit_fiscal", "Droit Fiscal", "Fiscalité directe et indirecte, procédures fiscales", 8),
    ("economie", "Économie Générale", "Macroéconomie, microéconomie, économie du développement", 9),
    ("finances_pub", "Finances Publiques", "Budget de l''État, comptabilité publique, contrôle des finances", 10),
    ("fiscalite", "Fiscalité", "Impôts, taxes, TVA, régimes fiscaux au Burkina Faso", 11),
    ("comptabilite", "Comptabilité", "Comptabilité générale, analytique, SYSCOHADA", 12),
    ("francais", "Français", "Grammaire, conjugaison, orthographe, compréhension de texte", 13),
    ("psychotech", "Tests Psychotechniques", "Logique verbale, numérique, aptitude au raisonnement", 14),
    ("maths", "Mathématiques", "Arithmétique, algèbre, géométrie, statistiques", 15),
    ("sciences_nat", "Sciences Naturelles / SVT", "Biologie, géologie, écologie, santé", 16),
    ("informatique", "Informatique", "Algorithmique, bases de données, réseaux, systèmes", 17),
    ("grh_management", "GRH et Management", "Gestion des ressources humaines, management des organisations", 18),
    ("pedagogie", "Pédagogie", "Sciences de l''éducation, didactique, psychologie de l''apprentissage", 19),
]

print("\nInserting 19 BF subjects...")
for slug, title, desc, order in subjects:
    sql(f"INSERT INTO app.prep_subjects (slug, title, description, sort_order, is_active) VALUES ('{slug}', '{title}', '{desc}', {order}, true) ON CONFLICT (slug) DO UPDATE SET title = '{title}', description = '{desc}', sort_order = {order}, is_active = true",
        f"Subject {slug}")
    time.sleep(0.15)

# 3. Update system prompt to BF
print("\nUpdating system prompt to BF...")
bf_prompt = "Tu es un tuteur expert en préparation aux concours de la fonction publique du Burkina Faso (ENAREF, Administrateurs Civils, Douane, Greffiers, ENS, Éducation, Santé, Agriculture, Eaux et Forêts, GRH, Paramilitaire). Tu expliques les concepts pas à pas, tu proposes des exercices, tu corriges les erreurs avec bienveillance. Tu t''adaptes au niveau de l''étudiant. Langue : français. Contexte : système administratif et éducatif burkinabè. Tu peux aider en : culture générale, actualités du Burkina Faso, droit (constitutionnel, administratif, civil, pénal, fiscal, du travail), économie générale, finances publiques, fiscalité, comptabilité, français, tests psychotechniques, mathématiques, sciences naturelles, informatique, GRH et management, pédagogie. Quand tu donnes une réponse à un exercice, montre le raisonnement étape par étape. Si l''étudiant fait une erreur, corrige-le avec bienveillance en expliquant pourquoi. Utilise des exemples concrets du contexte burkinabè quand c''est pertinent (institutions, lois, géographie du Burkina Faso). Adapte la longueur de ta réponse : courte pour les questions simples, détaillée pour les exercices et explications."
sql(f"UPDATE app.prep_ai_config SET config_value = '{bf_prompt}', updated_at = now() WHERE config_key = 'system_prompt'", "Update system prompt")

# 4. Create BF question bank
print("\nCreating BF question bank...")
sql("INSERT INTO app.prep_question_banks (title, description, concours_type, subject, is_active) VALUES ('Culture Générale BF — Tronc commun', 'Questions de culture générale pour tous les concours directs du Burkina Faso', 'TOUS', 'Culture Générale', true) ON CONFLICT DO NOTHING", "Create bank")

# 5. Get bank ID and insert questions
print("\nInserting 15 BF questions...")
# We need to get the bank_id first
r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                   json={"p_sql": "SELECT id FROM app.prep_question_banks WHERE title = 'Culture Générale BF — Tronc commun' LIMIT 1"}, timeout=30)
body = r.json()
bank_id = None
if isinstance(body, dict) and body.get("ok") and body.get("rows"):
    bank_id = body["rows"][0].get("id")
    print(f"  Bank ID: {bank_id}")

if bank_id:
    questions = [
        ("Quelle est la capitale du Burkina Faso ?", '["Bobo-Dioulasso","Ouagadougou","Koudougou","Banfora"]', 1, "Ouagadougou est la capitale politique et administrative du Burkina Faso.", 1, "Culture Générale", "TOUS"),
        ("En quelle année le Burkina Faso a-t-il obtenu son indépendance ?", '["1958","1960","1962","1956"]', 1, "La Haute-Volta a obtenu son indépendance le 5 août 1960.", 1, "Culture Générale", "TOUS"),
        ("Combien de régions administratives compte le Burkina Faso ?", '["10","13","15","17"]', 1, "Le Burkina Faso est divisé en 13 régions administratives, 45 provinces et 351 communes.", 1, "Culture Générale", "TOUS"),
        ("Quel est l''ancien nom du Burkina Faso ?", '["Côte d''Ivoire","Haute-Volta","Sénégal","Mali"]', 1, "Le Burkina Faso s''appelait la Haute-Volta jusqu''au 4 août 1984.", 1, "Culture Générale", "TOUS"),
        ("Que signifie Burkina Faso ?", '["Terre des hommes libres","Pays des hommes intègres","Nation des braves","Terre de paix"]', 1, "Burkina Faso signifie Pays des hommes intègres. Burkina vient du mooré et Faso du dioula.", 1, "Culture Générale", "TOUS"),
        ("Quel est le fleuve principal du Burkina Faso ?", '["Le Niger","Le Mouhoun (Volta Noire)","Le Sénégal","Le Congo"]', 1, "Le Mouhoun (anciennement Volta Noire) est le principal cours d''eau permanent du Burkina Faso.", 2, "Culture Générale", "TOUS"),
        ("Quelle est la devise du Burkina Faso ?", '["Liberté, Égalité, Fraternité","Unité, Progrès, Justice","Paix, Travail, Patrie","Un Peuple, Un But, Une Foi"]', 1, "La devise du Burkina Faso est Unité - Progrès - Justice.", 1, "Culture Générale", "TOUS"),
        ("Quelle institution forme les agents des régies financières au BF ?", '["ENAM","ENAREF","ENS","Université Joseph Ki-Zerbo"]', 1, "L''ENAREF forme les agents des douanes, impôts et trésor public. Cycles A, B, C.", 2, "Culture Générale", "ENAREF"),
        ("Quel est le principal groupe ethnique du Burkina Faso ?", '["Peul","Mossi","Bobo","Gourounsi"]', 1, "Les Mossi constituent environ 50%% de la population du Burkina Faso.", 1, "Culture Générale", "TOUS"),
        ("Qui est considéré comme le père de la révolution burkinabè ?", '["Maurice Yaméogo","Sangoulé Lamizana","Thomas Sankara","Blaise Compaoré"]', 2, "Thomas Sankara, président de 1983 à 1987, a renommé le pays en Burkina Faso.", 2, "Culture Générale", "TOUS"),
        ("Quelle est la monnaie utilisée au Burkina Faso ?", '["Le Naira","Le Franc CFA (XOF)","Le Cedi","Le Dalasi"]', 1, "Le Burkina Faso utilise le Franc CFA émis par la BCEAO. Membre de l''UEMOA.", 1, "Culture Générale", "TOUS"),
        ("Quel est le principal produit d''exportation agricole du BF ?", '["Le cacao","Le café","Le coton","L''arachide"]', 2, "Le coton est le principal produit agricole. L''or est le 1er produit d''exportation tous secteurs.", 2, "Culture Générale", "TOUS"),
        ("Qui est le chef de l''État selon la Constitution du BF ?", '["Le Premier Ministre","Le Président du Faso","Le Président de l''Assemblée","Le Chef d''État-Major"]', 1, "Le Président du Faso est le chef de l''État, garant de l''indépendance nationale.", 2, "Droit Constitutionnel", "ADMIN_CIVIL"),
        ("Quel organe émet le Franc CFA dans la zone UEMOA ?", '["La Banque Mondiale","La BCEAO","Le FMI","La BAD"]', 1, "La BCEAO est l''institution d''émission monétaire des 8 États de l''UEMOA dont le BF.", 2, "Économie Générale", "ENAREF"),
        ("Qu''est-ce que la loi de finances au Burkina Faso ?", '["Un décret présidentiel","La loi qui autorise les recettes et dépenses de l''État","Un arrêté ministériel","Une directive BCEAO"]', 1, "La loi de finances prévoit et autorise les ressources et charges de l''État, votée par l''Assemblée.", 3, "Finances Publiques", "ENAREF"),
    ]

    for q_text, opts, c_idx, expl, diff, subj, conc in questions:
        sql(f"INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active) VALUES ('{bank_id}', '{q_text}', '{q_text}', '{opts}'::jsonb, {c_idx}, '{expl}', {diff}, '{subj}', '{conc}', 'mcq', 'beginner', 'manual', true, true)",
            f"Q: {q_text[:40]}...")
        time.sleep(0.15)

# Verify
print("\n--- VERIFICATION ---")
sql("SELECT COUNT(*) AS cnt FROM app.prep_subjects WHERE is_active = true", "Active subjects count")
sql("SELECT COUNT(*) AS cnt FROM app.prep_questions WHERE is_published = true", "Published questions count")
sql("SELECT COUNT(*) AS cnt FROM app.prep_question_banks", "Question banks count")
sql("SELECT config_key, LEFT(config_value, 80) AS preview FROM app.prep_ai_config WHERE config_key = 'system_prompt'", "System prompt preview")

print("\n✅ Phase 1 SQL deployment complete!")
