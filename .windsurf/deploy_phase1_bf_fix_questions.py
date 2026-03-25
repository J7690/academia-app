#!/usr/bin/env python3
"""Fix: Insert 15 BF questions with proper subject_id."""
import json, requests, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    err = body.get("error", "") if isinstance(body, dict) and not ok else ""
    print(f"  {'✅' if ok else '❌'} {label} {('— ' + err[:200]) if err else ''}")
    return ok, body

# Get IDs
_, r = sql("SELECT id, slug FROM app.prep_subjects", "Get subject IDs")
subj_map = {}
if isinstance(r, dict) and r.get("rows"):
    for row in r["rows"]:
        subj_map[row["slug"]] = row["id"]

_, r2 = sql("SELECT id FROM app.prep_question_banks WHERE title = 'Culture Générale BF — Tronc commun' LIMIT 1", "Get bank ID")
bank_id = r2["rows"][0]["id"] if isinstance(r2, dict) and r2.get("rows") else None

print(f"\nSubjects: {len(subj_map)}, Bank: {bank_id}")
if not bank_id:
    print("❌ No bank found, aborting")
    exit(1)

cg_id = subj_map.get("culture_gen", "")
dc_id = subj_map.get("droit_constit", "")
ec_id = subj_map.get("economie", "")
fp_id = subj_map.get("finances_pub", "")

questions = [
    (cg_id, "Quelle est la capitale du Burkina Faso ?", '["Bobo-Dioulasso","Ouagadougou","Koudougou","Banfora"]', 1, "Ouagadougou est la capitale politique et administrative du Burkina Faso.", 1, "Culture Générale", "TOUS"),
    (cg_id, "En quelle année le Burkina Faso a-t-il obtenu son indépendance ?", '["1958","1960","1962","1956"]', 1, "La Haute-Volta a obtenu son indépendance le 5 août 1960.", 1, "Culture Générale", "TOUS"),
    (cg_id, "Combien de régions administratives compte le Burkina Faso ?", '["10","13","15","17"]', 1, "Le Burkina Faso est divisé en 13 régions, 45 provinces et 351 communes.", 1, "Culture Générale", "TOUS"),
    (cg_id, "Quel est l''ancien nom du Burkina Faso ?", '["Côte d''Ivoire","Haute-Volta","Sénégal","Mali"]', 1, "Le pays s''appelait Haute-Volta jusqu''au 4 août 1984.", 1, "Culture Générale", "TOUS"),
    (cg_id, "Que signifie Burkina Faso ?", '["Terre des hommes libres","Pays des hommes intègres","Nation des braves","Terre de paix"]', 1, "Burkina Faso = Pays des hommes intègres. Burkina (mooré) + Faso (dioula).", 1, "Culture Générale", "TOUS"),
    (cg_id, "Quel est le fleuve principal du Burkina Faso ?", '["Le Niger","Le Mouhoun","Le Sénégal","Le Congo"]', 1, "Le Mouhoun (Volta Noire) est le seul fleuve permanent, environ 860 km.", 2, "Culture Générale", "TOUS"),
    (cg_id, "Quelle est la devise du Burkina Faso ?", '["Liberté Égalité Fraternité","Unité Progrès Justice","Paix Travail Patrie","Un Peuple Un But Une Foi"]', 1, "La devise est Unité - Progrès - Justice.", 1, "Culture Générale", "TOUS"),
    (cg_id, "Quelle institution forme les agents des régies financières au BF ?", '["ENAM","ENAREF","ENS","Université Ki-Zerbo"]', 1, "ENAREF forme douanes, impôts, trésor. Cycles A, B, C.", 2, "Culture Générale", "ENAREF"),
    (cg_id, "Quel est le principal groupe ethnique du Burkina Faso ?", '["Peul","Mossi","Bobo","Gourounsi"]', 1, "Les Mossi = environ 50 pourcent de la population.", 1, "Culture Générale", "TOUS"),
    (cg_id, "Qui est le père de la révolution burkinabè ?", '["Maurice Yaméogo","Sangoulé Lamizana","Thomas Sankara","Blaise Compaoré"]', 2, "Thomas Sankara, président 1983-1987, a renommé le pays.", 2, "Culture Générale", "TOUS"),
    (cg_id, "Quelle monnaie utilise le Burkina Faso ?", '["Naira","Franc CFA XOF","Cedi","Dalasi"]', 1, "Le Franc CFA émis par la BCEAO. Membre de l''UEMOA.", 1, "Culture Générale", "TOUS"),
    (cg_id, "Quel est le 1er produit d''exportation agricole du BF ?", '["Cacao","Café","Coton","Arachide"]', 2, "Le coton est le 1er produit agricole. L''or est le 1er tous secteurs.", 2, "Culture Générale", "TOUS"),
    (dc_id, "Qui est le chef de l''État selon la Constitution du BF ?", '["Premier Ministre","Président du Faso","Président Assemblée","Chef État-Major"]', 1, "Le Président du Faso est chef de l''État.", 2, "Droit Constitutionnel", "ADMIN_CIVIL"),
    (ec_id, "Quel organe émet le Franc CFA zone UEMOA ?", '["Banque Mondiale","BCEAO","FMI","BAD"]', 1, "La BCEAO est l''institution d''émission des 8 États UEMOA.", 2, "Économie Générale", "ENAREF"),
    (fp_id, "Qu''est-ce que la loi de finances au BF ?", '["Décret présidentiel","Loi autorisant recettes et dépenses de l''État","Arrêté ministériel","Directive BCEAO"]', 1, "Loi prévoyant et autorisant ressources et charges de l''État.", 3, "Finances Publiques", "ENAREF"),
]

print(f"\nInserting {len(questions)} questions...")
ok_count = 0
for sid, q, opts, cidx, expl, diff, subj, conc in questions:
    ok, _ = sql(
        f"INSERT INTO app.prep_questions (subject_id, bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active) "
        f"VALUES ('{sid}', '{bank_id}', '{q}', '{q}', '{opts}'::jsonb, {cidx}, '{expl}', {diff}, '{subj}', '{conc}', 'mcq', 'beginner', 'manual', true, true)",
        f"Q: {q[:45]}..."
    )
    if ok:
        ok_count += 1
    time.sleep(0.15)

print(f"\n--- RESULT: {ok_count}/{len(questions)} questions inserted ---")

# Final verification
print("\n--- VERIFICATION ---")
sql("SELECT COUNT(*) AS cnt FROM app.prep_subjects WHERE is_active = true", "Subjects")
sql("SELECT COUNT(*) AS cnt FROM app.prep_questions WHERE is_published = true", "Questions")
sql("SELECT COUNT(*) AS cnt FROM app.prep_question_banks", "Banks")
