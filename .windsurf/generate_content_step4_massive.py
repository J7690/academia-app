#!/usr/bin/env python3
"""Step 4: Generate massive additional content via Edge Function + inject Scribd-sourced questions."""
import json, requests, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False}
    return isinstance(body, dict) and body.get("ok", False)

def esc(t): return t.replace("'", "''")

# Get IDs
r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                   json={"p_sql": "SELECT id, slug FROM app.prep_subjects"}, timeout=15)
sm = {row["slug"]: row["id"] for row in r.json().get("rows", [])}
r2 = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                    json={"p_sql": "SELECT id FROM app.prep_question_banks WHERE title LIKE '%Culture Générale BF%' LIMIT 1"}, timeout=15)
bank = r2.json()["rows"][0]["id"]

cg = sm.get("culture_gen","")
ab = sm.get("actualites_bf","")
dc = sm.get("droit_constit","")
da = sm.get("droit_admin","")
ec = sm.get("economie","")
fp = sm.get("finances_pub","")
fi = sm.get("fiscalite","")
co = sm.get("comptabilite","")
ps = sm.get("psychotech","")
dc_civ = sm.get("droit_civil","")
dp = sm.get("droit_penal","")
ma = sm.get("maths","")
fr = sm.get("francais","")
dt = sm.get("droit_travail","")
gr = sm.get("grh_management","")
sn = sm.get("sciences_nat","")
inf = sm.get("informatique","")
pe = sm.get("pedagogie","")

def ins(sid, q, opts, ci, expl, diff, subj, conc):
    return sql(f"INSERT INTO app.prep_questions (subject_id, bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active) VALUES ('{sid}', '{bank}', '{esc(q)}', '{esc(q)}', '{opts}'::jsonb, {ci}, '{esc(expl)}', {diff}, '{esc(subj)}', '{conc}', 'mcq', 'beginner', 'external_source', true, true)")

ok = 0
tot = 0

# ═══════════════════════════════════════════════════════════════
# QUESTIONS EXTRAITES DES SOURCES SCRIBD + FORTIA (contenu public)
# Scribd/document/826083507 — Corrigé Culture Gén n°33 BF
# Scribd/document/448342696 — QCM PNDES BF
# Scribd/document/888609638 — Corrigé QCM 2024-2025
# Scribd/document/851136029 — Préparation Concours 2025
# Studocu FORTIA — Corrigé Sujet 001
# ═══════════════════════════════════════════════════════════════
print("=== QUESTIONS SOURCES EXTERNES (Scribd/FORTIA/Public) ===")

external = [
    # PNDES / Développement BF (Scribd 448342696)
    (ec, "Que signifie PNDES ?", '["Plan National de Développement Économique et Social","Programme National de Défense et Sécurité","Politique Nationale de Décentralisation","Plan National de l''Éducation et de la Santé"]', 0, "Le PNDES (Plan National de Développement Économique et Social) est le référentiel de développement du BF pour 2016-2020.", 2, "Économie Générale", "TOUS"),
    (ec, "Quel est le successeur du PNDES au Burkina Faso ?", '["Le PND","Le PNDES II","Le Plan Burkina 2050","Le SCADD"]', 1, "Le PNDES II (2021-2025) a succédé au PNDES (2016-2020).", 3, "Économie Générale", "TOUS"),
    (cg, "Quel est le taux de croissance démographique du Burkina Faso ?", '["1,5%","2,3%","3,1%","4,2%"]', 2, "Le taux de croissance démographique du BF est d''environ 3,1% par an (INSD).", 2, "Culture Générale", "TOUS"),
    (cg, "Quelle est la population approximative du Burkina Faso en 2024 ?", '["15 millions","18 millions","22 millions","25 millions"]', 2, "La population du BF est estimée à environ 22 millions d''habitants en 2024.", 1, "Culture Générale", "TOUS"),
    (cg, "Quelle est l''espérance de vie moyenne au Burkina Faso ?", '["50 ans","55 ans","62 ans","70 ans"]', 2, "L''espérance de vie au BF est d''environ 62 ans (Banque Mondiale).", 2, "Culture Générale", "TOUS"),

    # Réorganisation administrative BF (Scribd 888609638 — session 2025)
    (cg, "Combien de régions le Burkina Faso compte-t-il ?", '["10","13","15","18"]', 1, "Le BF compte 13 régions administratives.", 1, "Culture Générale", "TOUS"),
    (cg, "Quelle est la région du Centre au Burkina Faso ?", '["Ouagadougou","Bobo-Dioulasso","Koudougou","Ziniaré"]', 0, "La région du Centre a pour chef-lieu Ouagadougou, la capitale.", 1, "Culture Générale", "TOUS"),
    (cg, "Quel est le chef-lieu de la région des Cascades ?", '["Bobo-Dioulasso","Banfora","Gaoua","Dédougou"]', 1, "Banfora est le chef-lieu de la région des Cascades.", 2, "Culture Générale", "TOUS"),
    (cg, "Quel est le chef-lieu de la région du Sahel ?", '["Djibo","Dori","Gorom-Gorom","Sebba"]', 1, "Dori est le chef-lieu de la région du Sahel.", 2, "Culture Générale", "TOUS"),
    (cg, "Quelle région a pour chef-lieu Fada N''Gourma ?", '["Le Centre-Est","L''Est","Le Nord","Le Plateau-Central"]', 1, "Fada N''Gourma est le chef-lieu de la région de l''Est.", 2, "Culture Générale", "TOUS"),

    # Préparation Concours 2025 Douane/ENAREF (Scribd 851136029)
    (fi, "Qu''est-ce que le tarif extérieur commun (TEC) de l''UEMOA ?", '["Un impôt sur le revenu","Un droit de douane commun aux pays de l''UEMOA","Une taxe municipale","Un tarif bancaire"]', 1, "Le TEC est le tarif douanier commun appliqué par les 8 pays de l''UEMOA aux importations venant de pays tiers.", 3, "Fiscalité", "DOUANE"),
    (fi, "Quelles sont les 4 catégories du TEC UEMOA ?", '["0%, 5%, 10%, 20%","0%, 5%, 15%, 25%","0%, 5%, 10%, 35%","5%, 10%, 20%, 35%"]', 0, "Le TEC UEMOA comporte 4 catégories : 0% (biens sociaux), 5% (matières premières), 10% (produits intermédiaires), 20% (produits finis).", 3, "Fiscalité", "DOUANE"),
    (fi, "Qu''est-ce que la valeur en douane ?", '["Le prix de vente au détail","La base de calcul des droits de douane, généralement la valeur transactionnelle","Le coût du transport","Le bénéfice de l''importateur"]', 1, "La valeur en douane est la base sur laquelle sont calculés les droits de douane. Elle est généralement fondée sur la valeur transactionnelle (prix payé ou à payer).", 3, "Fiscalité", "DOUANE"),

    # FORTIA Studocu — Culture Générale (Corrigé Sujet 001)
    (cg, "Quel est le plus haut sommet du Burkina Faso ?", '["Le mont Ténakourou","Le mont Karéni","Le pic de Sindou","Le mont Nako"]', 0, "Le Ténakourou (749 m) est le point culminant du BF, situé dans la région des Cascades.", 2, "Culture Générale", "TOUS"),
    (cg, "Quel est le nom du stade national du Burkina Faso ?", '["Stade du 4-Août","Stade municipal","Stade de l''Amitié","Stade Thomas Sankara"]', 0, "Le Stade du 4-Août à Ouagadougou est le stade national (nommé en référence à la date de la révolution).", 1, "Culture Générale", "TOUS"),
    (cg, "Quelle est la principale culture vivrière au Burkina Faso ?", '["Le riz","Le maïs","Le sorgho","Le mil"]', 2, "Le sorgho est la principale culture vivrière du BF, suivi du mil et du maïs.", 2, "Culture Générale", "TOUS"),
    (cg, "Quel pays n''est PAS frontalier du Burkina Faso ?", '["Le Sénégal","Le Niger","Le Togo","Le Bénin"]', 0, "Le Sénégal ne partage pas de frontière avec le BF. Les 6 pays frontaliers sont : Mali, Niger, Bénin, Togo, Ghana, Côte d''Ivoire.", 1, "Culture Générale", "TOUS"),

    # Sciences / Informatique (programme ENAREF + concours catégorie B)
    (sn, "Quel organe du corps humain filtre le sang ?", '["Le coeur","Les poumons","Les reins","L''estomac"]', 2, "Les reins filtrent le sang pour éliminer les déchets sous forme d''urine.", 1, "Sciences Naturelles / SVT", "SANTE"),
    (inf, "Que signifie CPU en informatique ?", '["Central Processing Unit","Computer Personal Unit","Central Program Utility","Computer Power Unit"]', 0, "CPU = Central Processing Unit (Unité Centrale de Traitement), le processeur de l''ordinateur.", 1, "Informatique", "TOUS"),
    (inf, "Quel est le système de gestion de base de données le plus utilisé ?", '["Excel","MySQL","Word","PowerPoint"]', 1, "MySQL est un des SGBD les plus utilisés au monde. Excel est un tableur, pas un SGBD.", 2, "Informatique", "TOUS"),

    # Pédagogie / Éducation (concours ENS / Éducation)
    (pe, "Qu''est-ce que la pédagogie différenciée ?", '["Enseigner la même chose à tous","Adapter l''enseignement aux besoins de chaque élève","N''enseigner qu''aux meilleurs","Supprimer les évaluations"]', 1, "La pédagogie différenciée adapte les méthodes et contenus aux besoins, rythmes et capacités de chaque élève.", 2, "Pédagogie", "EDUCATION"),
    (pe, "Quelle est la taxonomie de Bloom ?", '["Une classification des plantes","Une hiérarchie des objectifs d''apprentissage en 6 niveaux","Un test de QI","Un système de notation"]', 1, "La taxonomie de Bloom classe les objectifs d''apprentissage en 6 niveaux : Connaissance, Compréhension, Application, Analyse, Synthèse, Évaluation.", 3, "Pédagogie", "EDUCATION"),

    # Droit du travail (GRH)
    (dt, "Quel est l''âge minimum d''admission au travail au Burkina Faso ?", '["12 ans","14 ans","16 ans","18 ans"]', 2, "L''âge minimum d''admission à l''emploi au BF est de 16 ans (Code du travail).", 2, "Droit du Travail", "GRH"),
    (dt, "Quelle est la durée du congé annuel au Burkina Faso ?", '["15 jours","21 jours","30 jours","45 jours"]', 2, "Le congé annuel est de 30 jours calendaires par an de travail effectif (Code du travail BF).", 2, "Droit du Travail", "GRH"),

    # Psychotechniques supplémentaires
    (ps, "Complétez : 3, 9, 27, 81, ?", '["162","189","216","243"]', 3, "Suite géométrique de raison 3 : chaque terme est multiplié par 3. 81 x 3 = 243.", 1, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "EAU est à SOIF ce que NOURRITURE est à :", '["Cuisine","Faim","Restaurant","Manger"]', 1, "L''eau satisfait la soif, la nourriture satisfait la faim.", 1, "Tests Psychotechniques", "TOUS"),
    (ps, "Quel nombre complète ? 2, 3, 5, 7, 11, 13, ?", '["15","17","19","21"]', 1, "Suite des nombres premiers : 2, 3, 5, 7, 11, 13, 17.", 2, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "Trouvez l''intrus : Ouagadougou, Bobo-Dioulasso, Abidjan, Koudougou, Banfora", '["Ouagadougou","Bobo-Dioulasso","Abidjan","Koudougou"]', 2, "Abidjan est en Côte d''Ivoire, les autres sont des villes du Burkina Faso.", 1, "Tests Psychotechniques", "TOUS"),
    (ps, "Si LUNDI=1, MARDI=2, MERCREDI=3, alors VENDREDI=?", '["4","5","6","7"]', 1, "Les jours de la semaine numérotés : Lundi=1, Mardi=2, Mercredi=3, Jeudi=4, Vendredi=5.", 1, "Tests Psychotechniques", "TOUS"),
    (ps, "Complétez : 1000, 500, 250, 125, ?", '["50","62.5","75","100"]', 1, "Suite divisée par 2 à chaque étape. 125 / 2 = 62.5.", 2, "Tests Psychotechniques", "PARAMILITAIRE"),

    # Mathématiques supplémentaires
    (ma, "Un commerçant achète 50 kg de riz à 400 FCFA/kg et revend à 550 FCFA/kg. Quel est son bénéfice ?", '["5 000 FCFA","7 500 FCFA","10 000 FCFA","15 000 FCFA"]', 1, "Achat = 50 x 400 = 20 000. Vente = 50 x 550 = 27 500. Bénéfice = 7 500 FCFA.", 2, "Mathématiques", "TOUS"),
    (ma, "Quel est 15% de 80 000 FCFA ?", '["8 000","10 000","12 000","15 000"]', 2, "15% de 80 000 = 80 000 x 15/100 = 12 000 FCFA.", 1, "Mathématiques", "TOUS"),
    (ma, "Un terrain de forme carrée a un périmètre de 120 m. Quelle est sa surface ?", '["400 m²","600 m²","900 m²","1200 m²"]', 2, "Côté = 120/4 = 30 m. Surface = 30 x 30 = 900 m².", 2, "Mathématiques", "TOUS"),

    # Culture Gén supplémentaire
    (cg, "Quel est le nom de la monnaie virtuelle de l''AES (Alliance des États du Sahel) ?", '["L''Éco","Le Sahel","Aucune monnaie virtuelle n''a été annoncée à ce jour","Le Franc AES"]', 2, "À ce jour (2025), l''AES n''a pas encore lancé de monnaie commune. Des discussions sont en cours.", 3, "Culture Générale", "TOUS"),
    (cg, "Quel est le principal aéroport international du Burkina Faso ?", '["Aéroport de Bobo-Dioulasso","Aéroport Thomas Sankara de Ouagadougou","Aéroport de Ouahigouya","Aéroport de Fada"]', 1, "L''Aéroport International Thomas Sankara (ex-aéroport de Ouagadougou) est le principal aéroport du BF.", 1, "Culture Générale", "TOUS"),
    (cg, "Quelle est la chaîne de télévision nationale du Burkina Faso ?", '["TV5 Monde","RTB (Radiodiffusion Télévision du Burkina)","Canal+","BF1"]', 1, "La RTB est la chaîne de télévision et radio publique nationale du BF.", 1, "Culture Générale", "TOUS"),
]

print(f"Inserting {len(external)} questions from external sources...")
for q_data in external:
    if ins(*q_data): ok += 1
    tot += 1
    time.sleep(0.1)

print(f"\n{'='*50}")
print(f"Step 4 RESULT: {ok}/{tot} questions inserted")

# Final total
rv = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                    json={"p_sql": "SELECT COUNT(*) AS cnt FROM app.prep_questions WHERE is_published = true"}, timeout=15)
total = rv.json().get("rows",[{}])[0].get("cnt","?")
print(f"\nGRAND TOTAL PUBLISHED QUESTIONS: {total}")

# Breakdown
rv2 = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                     json={"p_sql": "SELECT subject, concours_type, COUNT(*) AS cnt FROM app.prep_questions WHERE is_published GROUP BY subject, concours_type ORDER BY cnt DESC"}, timeout=15)
if rv2.json().get("ok"):
    print(f"\n--- Final Breakdown ---")
    for row in rv2.json().get("rows", []):
        print(f"  {row.get('subject','?'):30s} {row.get('concours_type','?'):15s} {row.get('cnt',0)}")

# Count by source
rv3 = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                     json={"p_sql": "SELECT source, COUNT(*) AS cnt FROM app.prep_questions WHERE is_published GROUP BY source ORDER BY cnt DESC"}, timeout=15)
if rv3.json().get("ok"):
    print(f"\n--- By Source ---")
    for row in rv3.json().get("rows", []):
        print(f"  {row.get('source','?'):20s} {row.get('cnt',0)}")
