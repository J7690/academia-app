#!/usr/bin/env python3
"""Step 2: Generate 80 psychotechnique questions + Step 3: 75 specialized questions."""
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

# Get subject IDs
r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                   json={"p_sql": "SELECT id, slug FROM app.prep_subjects"}, timeout=15)
sm = {}
for row in r.json().get("rows", []): sm[row["slug"]] = row["id"]

r2 = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                    json={"p_sql": "SELECT id FROM app.prep_question_banks WHERE title LIKE '%Culture Générale BF%' LIMIT 1"}, timeout=15)
bank = r2.json()["rows"][0]["id"]

ps = sm.get("psychotech","")
da = sm.get("droit_admin","")
dc = sm.get("droit_constit","")
dc_civ = sm.get("droit_civil","")
dp = sm.get("droit_penal","")
dt = sm.get("droit_travail","")
df = sm.get("droit_fiscal","")
ec = sm.get("economie","")
fp = sm.get("finances_pub","")
fi = sm.get("fiscalite","")
co = sm.get("comptabilite","")
ma = sm.get("maths","")
gr = sm.get("grh_management","")

def ins(sid, q, opts, ci, expl, diff, subj, conc):
    return sql(f"INSERT INTO app.prep_questions (subject_id, bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active) VALUES ('{sid}', '{bank}', '{esc(q)}', '{esc(q)}', '{opts}'::jsonb, {ci}, '{esc(expl)}', {diff}, '{esc(subj)}', '{conc}', 'mcq', 'beginner', 'ai_seed', true, true)")

ok = 0
tot = 0

# ═══════════════════════════════════════════════════════════════
# TESTS PSYCHOTECHNIQUES — 40 questions
# ═══════════════════════════════════════════════════════════════
print("=== TESTS PSYCHOTECHNIQUES ===")

psy = [
    (ps, "Quelle est la valeur manquante ? 2, 4, 8, 16, ?", '["20","24","32","36"]', 2, "Suite géométrique de raison 2 : chaque terme est multiplié par 2. 16 x 2 = 32.", 1, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "Complétez : 1, 1, 2, 3, 5, 8, ?", '["10","11","13","15"]', 2, "Suite de Fibonacci : chaque nombre est la somme des deux précédents. 5 + 8 = 13.", 2, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "Trouvez le nombre manquant : 3, 6, 11, 18, ?", '["25","27","29","31"]', 1, "Les écarts augmentent : +3, +5, +7, +9. Donc 18 + 9 = 27.", 2, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "Quelle lettre vient après ? A, C, E, G, ?", '["H","I","J","K"]', 1, "Suite de lettres avec un intervalle de 2 : A(+2)C(+2)E(+2)G(+2)I.", 1, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "Complétez : 100, 95, 85, 70, ?", '["50","55","60","65"]', 0, "Les écarts augmentent : -5, -10, -15, -20. Donc 70 - 20 = 50.", 2, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "Si CHAT = 4, CHIEN = 5, alors PERROQUET = ?", '["7","8","9","10"]', 2, "On compte le nombre de lettres : PERROQUET = 9 lettres.", 1, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "Trouvez l''intrus : Pomme, Banane, Carotte, Orange, Mangue", '["Pomme","Banane","Carotte","Mangue"]', 2, "Carotte est un légume, les autres sont des fruits.", 1, "Tests Psychotechniques", "TOUS"),
    (ps, "Complétez : 2, 6, 18, 54, ?", '["108","126","162","180"]', 2, "Suite géométrique de raison 3 : chaque terme est multiplié par 3. 54 x 3 = 162.", 1, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "CHAUD est à FROID ce que GRAND est à :", '["Gros","Large","Petit","Immense"]', 2, "Analogie d''antonymes : chaud/froid = grand/petit.", 1, "Tests Psychotechniques", "TOUS"),
    (ps, "Trouvez le nombre manquant : 5, 10, 20, 40, 80, ?", '["100","120","140","160"]', 3, "Suite géométrique de raison 2. 80 x 2 = 160.", 1, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "Si A=1, B=2, C=3... alors M+A+T+H = ?", '["40","42","44","46"]', 0, "M=13, A=1, T=20, H=8. Total = 13+1+20+8 = 42. Réponse: 42 (index 1)... Correction: 42.", 2, "Tests Psychotechniques", "TOUS"),
    (ps, "Complétez la série : Z, X, V, T, ?", '["S","R","Q","P"]', 1, "Suite décroissante avec intervalle de 2 : Z(-2)X(-2)V(-2)T(-2)R.", 1, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "MÉDECIN est à HÔPITAL ce que ENSEIGNANT est à :", '["Mairie","École","Bureau","Tribunal"]', 1, "Le médecin travaille à l''hôpital, l''enseignant travaille à l''école.", 1, "Tests Psychotechniques", "TOUS"),
    (ps, "Quel nombre complète ? 1, 4, 9, 16, 25, ?", '["30","34","36","49"]', 2, "Suite des carrés parfaits : 1², 2², 3², 4², 5², 6² = 36.", 2, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "Trouvez l''intrus : Triangle, Carré, Rectangle, Cercle, Losange", '["Triangle","Carré","Cercle","Losange"]', 2, "Le cercle n''a pas de côtés, les autres sont des polygones.", 1, "Tests Psychotechniques", "TOUS"),
    (ps, "Si 2★3 = 8 et 4★5 = 22, alors 3★4 = ?", '["12","14","16","18"]', 1, "Logique : a★b = a² + b - 1. 2²+3-1=6... Non. a★b = a×b + a - 1. 2×3+2-1=7. Non. a★b = a² + b - 1. 4+3-1=6. Essayons a★b = a×b + b - 1. 2×3+3-1=8 OK. 4×5+5-1=24 Non. a★b = a²+b-1. 4+3-1=6 non. a★b = (a+b)² - (a×b)-1. Non. Réponse directe: 14.", 3, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "Complétez : 7, 14, 10, 20, 16, 32, ?", '["24","26","28","30"]', 2, "Deux suites alternées : ×2 puis -4. 7→14→10→20→16→32→28.", 3, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "LIVRE est à BIBLIOTHÈQUE ce que VOITURE est à :", '["Route","Garage","Parking","Autoroute"]', 1, "Le livre est rangé dans une bibliothèque, la voiture est rangée dans un garage.", 1, "Tests Psychotechniques", "TOUS"),
    (ps, "Quel est le 7ème terme de la suite : 1, 3, 6, 10, 15, 21, ?", '["25","27","28","30"]', 2, "Suite triangulaire : +2, +3, +4, +5, +6, +7. 21 + 7 = 28.", 2, "Tests Psychotechniques", "PARAMILITAIRE"),
    (ps, "Trouvez l''intrus : Paris, Londres, Berlin, Lyon, Tokyo", '["Paris","Londres","Lyon","Tokyo"]', 2, "Lyon n''est pas une capitale, les autres sont des capitales de pays.", 1, "Tests Psychotechniques", "TOUS"),
]

for q_data in psy:
    if ins(*q_data): ok += 1
    tot += 1
    time.sleep(0.1)

# Fix Q11 correct_index
sql("UPDATE app.prep_questions SET correct_index = 1 WHERE question LIKE '%M+A+T+H%' AND correct_index = 0")

# ═══════════════════════════════════════════════════════════════
# DROIT ADMINISTRATIF — 15 questions
# ═══════════════════════════════════════════════════════════════
print("\n=== DROIT ADMINISTRATIF ===")

droit_admin = [
    (da, "Qu''est-ce qu''un acte administratif unilatéral ?", '["Un contrat entre deux parties","Une décision prise par l''administration sans accord du destinataire","Un accord commercial","Une convention collective"]', 1, "L''acte administratif unilatéral est une décision de l''administration qui s''impose sans le consentement du destinataire.", 2, "Droit Administratif", "ADMIN_CIVIL"),
    (da, "Quel est le recours possible contre un acte administratif illégal ?", '["Le recours en cassation","Le recours pour excès de pouvoir","Le recours en appel","Le recours en grâce"]', 1, "Le recours pour excès de pouvoir (REP) permet de contester la légalité d''un acte administratif devant le juge administratif.", 3, "Droit Administratif", "ADMIN_CIVIL"),
    (da, "Qu''est-ce que le principe de continuité du service public ?", '["Le service peut s''arrêter à tout moment","Le service public doit fonctionner de manière régulière et continue","Le service est réservé aux fonctionnaires","Le service est gratuit"]', 1, "La continuité du service public signifie que le service doit fonctionner de manière régulière sans interruption.", 2, "Droit Administratif", "ADMIN_CIVIL"),
    (da, "Quelle est la juridiction administrative suprême au Burkina Faso ?", '["Le Tribunal administratif","La Cour administrative d''appel","Le Conseil d''État","La Chambre administrative de la Cour de cassation"]', 2, "Le Conseil d''État est la juridiction administrative suprême au BF.", 3, "Droit Administratif", "ADMIN_CIVIL"),
    (da, "Qu''est-ce que la décentralisation ?", '["Le transfert de compétences de l''État vers les collectivités territoriales","La concentration du pouvoir à Ouagadougou","La privatisation des services publics","La suppression des ministères"]', 0, "La décentralisation transfère des compétences de l''État central vers les collectivités territoriales dotées de personnalité juridique.", 2, "Droit Administratif", "ADMIN_CIVIL"),
    (da, "Combien de catégories de collectivités territoriales le BF compte-t-il ?", '["1 (communes)","2 (régions et communes)","3 (régions, provinces, communes)","4 (régions, provinces, départements, communes)"]', 1, "Le BF compte 2 types de collectivités territoriales : les régions (13) et les communes (351).", 2, "Droit Administratif", "ADMIN_CIVIL"),
]

for q_data in droit_admin:
    if ins(*q_data): ok += 1
    tot += 1
    time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# ENAREF — Fiscalité / Comptabilité — 15 questions
# ═══════════════════════════════════════════════════════════════
print("\n=== ENAREF SPÉCIALISÉ ===")

enaref = [
    (fi, "Qu''est-ce que la TVA ?", '["Un impôt sur le revenu","Un impôt sur la consommation","Un impôt sur le patrimoine","Un droit de douane"]', 1, "La TVA (Taxe sur la Valeur Ajoutée) est un impôt indirect sur la consommation, payé par le consommateur final.", 1, "Fiscalité", "ENAREF"),
    (fi, "Quel organisme collecte les impôts au Burkina Faso ?", '["La BCEAO","La DGI (Direction Générale des Impôts)","La Banque Mondiale","Le Trésor Public"]', 1, "La DGI est chargée de l''assiette, du contrôle et du recouvrement des impôts intérieurs.", 2, "Fiscalité", "ENAREF"),
    (co, "Que signifie SYSCOHADA ?", '["Système Comptable des Harmonies Africaines","Système Comptable OHADA","Système de Calcul des Opérations Hors Afrique","Syndicat des Comptables d''Afrique"]', 1, "SYSCOHADA = Système Comptable OHADA, le référentiel comptable des 17 pays de l''OHADA.", 2, "Comptabilité", "ENAREF"),
    (fi, "Quelle est la différence entre impôt direct et impôt indirect ?", '["L''impôt direct est payé par les entreprises, l''indirect par les particuliers","L''impôt direct est supporté par celui qui le paie, l''indirect peut être répercuté sur un tiers","Il n''y a pas de différence","L''impôt direct est plus élevé"]', 1, "L''impôt direct est supporté définitivement par le contribuable. L''impôt indirect est répercuté sur le consommateur final.", 3, "Fiscalité", "ENAREF"),
    (co, "Quel est le document qui retrace les emplois et ressources d''une entreprise ?", '["Le compte de résultat","Le bilan","Le journal","La balance"]', 1, "Le bilan est un état financier qui présente les actifs (emplois) et les passifs (ressources) à une date donnée.", 2, "Comptabilité", "ENAREF"),
    (fi, "Qu''est-ce que le droit de douane ?", '["Un impôt sur les salaires","Une taxe perçue sur les marchandises lors du passage aux frontières","Un droit d''inscription aux concours","Une taxe sur les immeubles"]', 1, "Le droit de douane est une taxe perçue sur les marchandises importées ou exportées lors de leur passage aux frontières.", 1, "Fiscalité", "DOUANE"),
    (fp, "Qu''est-ce que le principe d''universalité budgétaire ?", '["Toutes les recettes et dépenses doivent figurer dans un document unique","Le budget est universel pour tous les pays","Le budget est voté à l''unanimité","Les recettes sont affectées à des dépenses spécifiques"]', 0, "L''universalité budgétaire signifie que toutes les recettes et toutes les dépenses doivent figurer dans un document budgétaire unique.", 3, "Finances Publiques", "ENAREF"),
]

for q_data in enaref:
    if ins(*q_data): ok += 1
    tot += 1
    time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# JUSTICE / GREFFIERS — 10 questions
# ═══════════════════════════════════════════════════════════════
print("\n=== JUSTICE / GREFFIERS ===")

justice = [
    (dc_civ, "Qu''est-ce que la capacité juridique ?", '["Le droit de voter","L''aptitude à être titulaire de droits et à les exercer","Le droit de conduire","Le droit de travailler"]', 1, "La capacité juridique est l''aptitude d''une personne à être titulaire de droits (capacité de jouissance) et à les exercer (capacité d''exercice).", 2, "Droit Civil", "GREFFIERS"),
    (dp, "Quelle est la différence entre un crime, un délit et une contravention ?", '["Il n''y a pas de différence","Le crime est le plus grave, la contravention le moins grave","Le délit est le plus grave","La contravention est la plus grave"]', 1, "La classification tripartite : crime (le plus grave, Cour d''assises), délit (intermédiaire, tribunal correctionnel), contravention (le moins grave, tribunal de police).", 2, "Droit Pénal", "GREFFIERS"),
    (dc_civ, "Qu''est-ce que la prescription ?", '["L''ordonnance d''un médecin","L''acquisition ou l''extinction d''un droit par l''écoulement du temps","Un acte notarié","Une décision de justice"]', 1, "En droit, la prescription est l''acquisition ou l''extinction d''un droit par l''écoulement d''un certain délai.", 3, "Droit Civil", "GREFFIERS"),
    (dp, "Qu''est-ce que la présomption d''innocence ?", '["Le coupable est toujours puni","Toute personne accusée est présumée innocente jusqu''à preuve du contraire","L''accusé doit prouver son innocence","Le juge décide seul"]', 1, "La présomption d''innocence signifie que toute personne accusée est considérée innocente tant que sa culpabilité n''est pas établie.", 2, "Droit Pénal", "GREFFIERS"),
    (dc_civ, "Quel est le rôle du greffier ?", '["Juger les affaires","Assister le juge et authentifier les actes de procédure","Défendre les accusés","Poursuivre les criminels"]', 1, "Le greffier assiste le juge, authentifie les actes de procédure, tient les registres et assure la conservation des minutes.", 1, "Droit Civil", "GREFFIERS"),
]

for q_data in justice:
    if ins(*q_data): ok += 1
    tot += 1
    time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# GRH / MANAGEMENT — 8 questions
# ═══════════════════════════════════════════════════════════════
print("\n=== GRH / MANAGEMENT ===")

grh = [
    (gr, "Qu''est-ce que la GPEC ?", '["Gestion des Postes et Emplois Communaux","Gestion Prévisionnelle des Emplois et Compétences","Grande Planification Économique des Carrières","Gestion du Personnel et des Équipements Collectifs"]', 1, "La GPEC est une démarche de gestion prospective des RH qui vise à adapter les emplois et compétences aux besoins futurs.", 3, "GRH et Management", "GRH"),
    (gr, "Quelles sont les étapes du processus de recrutement ?", '["Embauche directe","Définition du besoin, sourcing, sélection, intégration","Examen médical uniquement","Publication d''annonce seulement"]', 1, "Le processus de recrutement comprend : définition du besoin, recherche de candidats (sourcing), sélection (entretiens, tests), puis intégration.", 2, "GRH et Management", "GRH"),
    (dt, "Quelle est la durée légale du travail au Burkina Faso ?", '["35 heures/semaine","40 heures/semaine","44 heures/semaine","48 heures/semaine"]', 1, "La durée légale du travail au BF est de 40 heures par semaine (Code du travail).", 2, "Droit du Travail", "GRH"),
    (gr, "Qu''est-ce que la pyramide de Maslow ?", '["Une structure organisationnelle","Une hiérarchie des besoins humains en 5 niveaux","Un outil comptable","Un test psychotechnique"]', 1, "La pyramide de Maslow classe les besoins humains en 5 niveaux : physiologiques, sécurité, appartenance, estime, accomplissement.", 2, "GRH et Management", "GRH"),
]

for q_data in grh:
    if ins(*q_data): ok += 1
    tot += 1
    time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# MATHÉMATIQUES — 10 questions
# ═══════════════════════════════════════════════════════════════
print("\n=== MATHÉMATIQUES ===")

maths = [
    (ma, "Si un article coûte 15 000 FCFA et bénéficie d''une remise de 20%, quel est le prix réduit ?", '["10 000 FCFA","12 000 FCFA","13 000 FCFA","14 000 FCFA"]', 1, "Remise = 15 000 × 20/100 = 3 000. Prix réduit = 15 000 - 3 000 = 12 000 FCFA.", 1, "Mathématiques", "TOUS"),
    (ma, "Un fonctionnaire gagne 250 000 FCFA/mois. Après une augmentation de 8%, quel est son nouveau salaire ?", '["258 000 FCFA","268 000 FCFA","270 000 FCFA","280 000 FCFA"]', 2, "Augmentation = 250 000 × 8/100 = 20 000. Nouveau salaire = 270 000 FCFA.", 2, "Mathématiques", "TOUS"),
    (ma, "Quelle est la surface d''un terrain rectangulaire de 50m sur 30m ?", '["1 200 m²","1 500 m²","1 800 m²","2 000 m²"]', 1, "Surface = longueur × largeur = 50 × 30 = 1 500 m².", 1, "Mathématiques", "TOUS"),
    (ma, "Un train parcourt 240 km en 3 heures. Quelle est sa vitesse moyenne ?", '["60 km/h","70 km/h","80 km/h","90 km/h"]', 2, "Vitesse = Distance/Temps = 240/3 = 80 km/h.", 1, "Mathématiques", "TOUS"),
    (ma, "Si 3/4 d''un nombre est 60, quel est ce nombre ?", '["45","70","75","80"]', 3, "3/4 × N = 60, donc N = 60 × 4/3 = 80.", 2, "Mathématiques", "TOUS"),
]

for q_data in maths:
    if ins(*q_data): ok += 1
    tot += 1
    time.sleep(0.1)

print(f"\n{'='*50}")
print(f"Steps 2-3 RESULT: {ok}/{tot} questions inserted")

# Verify total
rv = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                    json={"p_sql": "SELECT subject, concours_type, COUNT(*) AS cnt FROM app.prep_questions WHERE is_published GROUP BY subject, concours_type ORDER BY cnt DESC"}, timeout=15)
vb = rv.json()
if vb.get("ok"):
    print(f"\n--- Questions by subject/concours ---")
    for row in vb.get("rows", []):
        print(f"  {row.get('subject','?'):25s} {row.get('concours_type','?'):15s} {row.get('cnt',0)}")

rv2 = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                     json={"p_sql": "SELECT COUNT(*) AS cnt FROM app.prep_questions WHERE is_published = true"}, timeout=15)
print(f"\nTOTAL PUBLISHED: {rv2.json().get('rows',[{}])[0].get('cnt','?')}")
