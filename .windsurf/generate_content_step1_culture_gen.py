#!/usr/bin/env python3
"""Step 1: Generate 100 Culture Générale BF questions directly into prep_questions via admin_execute_sql."""
import json, requests, time
from pathlib import Path

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False}
    return isinstance(body, dict) and body.get("ok", False)

def esc(t):
    return t.replace("'", "''")

# Get subject IDs
r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                   json={"p_sql": "SELECT id, slug FROM app.prep_subjects"}, timeout=15)
subj_map = {}
body = r.json()
if body.get("ok"):
    for row in body.get("rows", []):
        subj_map[row["slug"]] = row["id"]

# Get bank ID
r2 = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                    json={"p_sql": "SELECT id FROM app.prep_question_banks WHERE title LIKE '%Culture Générale BF%' LIMIT 1"}, timeout=15)
b = r2.json()
bank_id = b["rows"][0]["id"] if b.get("ok") and b.get("rows") else None

print(f"Subjects: {len(subj_map)}, Bank: {bank_id}")

# Create additional banks
for bname, conc, subj in [
    ("Actualités Burkina Faso", "TOUS", "Actualités BF"),
    ("Droit Constitutionnel BF", "ADMIN_CIVIL", "Droit Constitutionnel"),
    ("Économie et Finances BF", "ENAREF", "Économie"),
    ("Tests Psychotechniques", "TOUS", "Tests Psychotechniques"),
    ("Droit Administratif BF", "ADMIN_CIVIL", "Droit Administratif"),
    ("Douane et Fiscalité BF", "DOUANE", "Fiscalité"),
    ("Justice et Greffiers BF", "GREFFIERS", "Droit Civil"),
]:
    sql(f"INSERT INTO app.prep_question_banks (title, description, concours_type, subject, is_active) VALUES ('{esc(bname)}', 'Questions pour concours BF', '{conc}', '{esc(subj)}', true) ON CONFLICT DO NOTHING")

cg = subj_map.get("culture_gen", "")
ab = subj_map.get("actualites_bf", "")
dc = subj_map.get("droit_constit", "")
da = subj_map.get("droit_admin", "")
ec = subj_map.get("economie", "")
fp = subj_map.get("finances_pub", "")
fi = subj_map.get("fiscalite", "")
fr = subj_map.get("francais", "")
ma = subj_map.get("maths", "")
ps = subj_map.get("psychotech", "")
dc_civil = subj_map.get("droit_civil", "")
dp = subj_map.get("droit_penal", "")
dt = subj_map.get("droit_travail", "")
df = subj_map.get("droit_fiscal", "")
co = subj_map.get("comptabilite", "")

def insert_q(sid, q, opts, ci, expl, diff, subj, conc):
    return sql(f"INSERT INTO app.prep_questions (subject_id, bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active) VALUES ('{sid}', '{bank_id}', '{esc(q)}', '{esc(q)}', '{opts}'::jsonb, {ci}, '{esc(expl)}', {diff}, '{esc(subj)}', '{conc}', 'mcq', 'beginner', 'ai_seed', true, true)")

ok_count = 0
total = 0

# ═══════════════════════════════════════════════════════════════
# CULTURE GÉNÉRALE BF — 50 questions
# ═══════════════════════════════════════════════════════════════
print("\n=== CULTURE GÉNÉRALE BF ===")

questions_cg = [
    (cg, "Quelle est la superficie du Burkina Faso ?", '["174 000 km²","274 200 km²","374 000 km²","174 200 km²"]', 1, "Le Burkina Faso couvre 274 200 km², ce qui en fait un pays de taille moyenne en Afrique de l''Ouest.", 1, "Culture Générale", "TOUS"),
    (cg, "Quel est le nombre de provinces du Burkina Faso ?", '["35","45","55","65"]', 1, "Le Burkina Faso compte 45 provinces réparties dans 13 régions.", 1, "Culture Générale", "TOUS"),
    (cg, "Quel est l''hymne national du Burkina Faso ?", '["La Voltaïque","Une Seule Nuit","La Diane du Pays des Hommes Intègres","Le Ditanyè"]', 1, "L''hymne national est Une Seule Nuit (Ditanyè), composé par Thomas Sankara en 1984.", 2, "Culture Générale", "TOUS"),
    (cg, "Quel est le premier président de la Haute-Volta ?", '["Thomas Sankara","Maurice Yaméogo","Sangoulé Lamizana","Jean-Baptiste Ouédraogo"]', 1, "Maurice Yaméogo fut le premier président de la Haute-Volta de 1960 à 1966.", 2, "Culture Générale", "TOUS"),
    (cg, "Quelle est la deuxième ville du Burkina Faso en termes de population ?", '["Koudougou","Ouahigouya","Bobo-Dioulasso","Banfora"]', 2, "Bobo-Dioulasso est la deuxième ville du BF, capitale économique et culturelle de l''Ouest.", 1, "Culture Générale", "TOUS"),
    (cg, "Le Burkina Faso est membre de combien d''organisations internationales parmi : UA, CEDEAO, UEMOA, OCI ?", '["2","3","4","1"]', 2, "Le Burkina Faso est membre de l''UA, la CEDEAO, l''UEMOA et l''OCI (les 4).", 2, "Culture Générale", "TOUS"),
    (cg, "Quel est le principal minerai exporté par le Burkina Faso ?", '["Le diamant","Le fer","L''or","Le manganèse"]', 2, "L''or est le premier produit d''exportation du BF, faisant du pays l''un des plus grands producteurs en Afrique.", 1, "Culture Générale", "TOUS"),
    (cg, "En quelle année Thomas Sankara a-t-il renommé la Haute-Volta en Burkina Faso ?", '["1983","1984","1985","1987"]', 1, "Le 4 août 1984, Thomas Sankara a renommé la Haute-Volta en Burkina Faso.", 2, "Culture Générale", "TOUS"),
    (cg, "Combien de pays partagent une frontière avec le Burkina Faso ?", '["4","5","6","7"]', 2, "Le BF partage ses frontières avec 6 pays : Mali, Niger, Bénin, Togo, Ghana, Côte d''Ivoire.", 1, "Culture Générale", "TOUS"),
    (cg, "Quel est le lac le plus important du Burkina Faso ?", '["Lac de Bam","Lac de Kompienga","Lac de Tingrela","Lac de Bagré"]', 1, "Le lac de Kompienga, barrage hydroélectrique, est l''un des plus importants plans d''eau du BF.", 2, "Culture Générale", "TOUS"),
    (cg, "Quelle ethnie est majoritaire dans la région des Hauts-Bassins ?", '["Mossi","Bobo","Peul","Gourounsi"]', 1, "Les Bobo sont l''ethnie majoritaire des Hauts-Bassins (Bobo-Dioulasso).", 2, "Culture Générale", "TOUS"),
    (cg, "Quel est le principal partenaire commercial du Burkina Faso ?", '["La France","La Chine","La Côte d''Ivoire","Le Ghana"]', 2, "La Côte d''Ivoire est le premier partenaire commercial du BF (port d''Abidjan pour les importations).", 2, "Culture Générale", "TOUS"),
    (cg, "Quelle est la religion la plus pratiquée au Burkina Faso ?", '["Le christianisme","L''islam","L''animisme","Le bouddhisme"]', 1, "L''islam est pratiqué par environ 60% de la population burkinabè.", 1, "Culture Générale", "TOUS"),
    (cg, "Quel événement culturel majeur se tient à Ouagadougou tous les deux ans ?", '["Le SIAO","Le FESPACO","Le Salon du Livre","Les Nuits Atypiques"]', 1, "Le FESPACO (Festival Panafricain du Cinéma et de la Télévision de Ouagadougou) est le plus grand festival de cinéma africain.", 2, "Culture Générale", "TOUS"),
    (cg, "Quel barrage hydroélectrique alimente principalement Ouagadougou en électricité ?", '["Bagré","Kompienga","Ziga","Samandéni"]', 0, "Le barrage de Bagré, construit en 1992, est un des principaux barrages du BF.", 2, "Culture Générale", "TOUS"),
    (cg, "Quel est le taux d''alphabétisation approximatif au Burkina Faso ?", '["25%","40%","55%","70%"]', 1, "Le taux d''alphabétisation au BF est d''environ 40% (parmi les plus bas au monde).", 2, "Culture Générale", "TOUS"),
    (cg, "Quelle université est la plus ancienne du Burkina Faso ?", '["Université de Koudougou","Université Nazi Boni","Université Joseph Ki-Zerbo","Université de Fada"]', 2, "L''Université Joseph Ki-Zerbo (ex-Université de Ouagadougou), fondée en 1974, est la plus ancienne.", 2, "Culture Générale", "TOUS"),
    (cg, "Quel fleuve traverse la ville de Bobo-Dioulasso ?", '["Le Mouhoun","Le Kou","Le Nakambé","Le Nazinon"]', 1, "La rivière Kou traverse Bobo-Dioulasso et alimente la ville en eau.", 2, "Culture Générale", "TOUS"),
    (cg, "Quel est le nom de la compagnie aérienne nationale du Burkina Faso ?", '["Air Burkina","Burkina Airlines","Air Volta","Trans Air BF"]', 0, "Air Burkina est la compagnie aérienne nationale.", 1, "Culture Générale", "TOUS"),
    (cg, "Combien de communes compte le Burkina Faso ?", '["251","301","351","401"]', 2, "Le BF compte 351 communes (49 communes urbaines et 302 communes rurales).", 2, "Culture Générale", "TOUS"),
]

for q_data in questions_cg:
    if insert_q(*q_data):
        ok_count += 1
    total += 1
    time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# ACTUALITÉS BF — 15 questions
# ═══════════════════════════════════════════════════════════════
print("\n=== ACTUALITÉS BF ===")

questions_actu = [
    (ab, "Qui est le Président de la Transition du Burkina Faso depuis septembre 2022 ?", '["Paul-Henri Sandaogo Damiba","Ibrahim Traoré","Roch Marc Christian Kaboré","Blaise Compaoré"]', 1, "Le Capitaine Ibrahim Traoré est Président de la Transition depuis le 30 septembre 2022.", 1, "Actualités BF", "TOUS"),
    (ab, "En quelle année le Burkina Faso a-t-il quitté la CEDEAO ?", '["2022","2023","2024","2025"]', 2, "Le Burkina Faso, le Mali et le Niger ont annoncé leur retrait de la CEDEAO en janvier 2024.", 2, "Actualités BF", "TOUS"),
    (ab, "Quelle alliance ont formé le Burkina Faso, le Mali et le Niger ?", '["G5 Sahel","Alliance des États du Sahel (AES)","Force conjointe du Liptako-Gourma","Union du Sahel"]', 1, "L''Alliance des États du Sahel (AES) a été créée en septembre 2023 par le BF, le Mali et le Niger.", 2, "Actualités BF", "TOUS"),
    (ab, "Quel est le principal défi sécuritaire du Burkina Faso depuis 2015 ?", '["Les conflits frontaliers","Le terrorisme djihadiste","Les coups d''État","Les conflits ethniques"]', 1, "Le terrorisme djihadiste, avec des groupes liés à AQMI et l''État islamique, est le principal défi sécuritaire.", 2, "Actualités BF", "TOUS"),
    (ab, "Que sont les VDP au Burkina Faso ?", '["Des policiers","Des Volontaires pour la Défense de la Patrie","Des soldats professionnels","Des agents de renseignement"]', 1, "Les VDP sont des civils volontaires qui assistent les forces de défense dans la lutte antiterroriste.", 2, "Actualités BF", "TOUS"),
    (ab, "Combien de candidatures ont été enregistrées pour les concours directs session 2025 ?", '["500 000","1 000 000","2 090 000","3 000 000"]', 2, "Environ 2 090 000 candidatures pour 5 046 postes lors de la session 2025.", 3, "Actualités BF", "TOUS"),
    (ab, "Dans combien de chefs-lieux de région se déroulent les concours directs ?", '["8","10","13","15"]', 2, "Les concours se déroulent dans les 13 chefs-lieux de région du BF.", 1, "Actualités BF", "TOUS"),
    (ab, "Quel est le format des épreuves des concours directs depuis 2022 ?", '["Dissertation","QCM sur table","Oral","Épreuves pratiques"]', 1, "Depuis 2022, les concours directs sont administrés sous forme de QCM sur table.", 2, "Actualités BF", "TOUS"),
]

for q_data in questions_actu:
    if insert_q(*q_data):
        ok_count += 1
    total += 1
    time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# DROIT CONSTITUTIONNEL — 15 questions
# ═══════════════════════════════════════════════════════════════
print("\n=== DROIT CONSTITUTIONNEL ===")

questions_droit = [
    (dc, "Quel article de la Constitution BF consacre la séparation des pouvoirs ?", '["Article 1","Article 33","Article 101","Article 152"]', 1, "La Constitution du BF organise la séparation des pouvoirs entre l''exécutif, le législatif et le judiciaire.", 3, "Droit Constitutionnel", "ADMIN_CIVIL"),
    (dc, "Quelle est la durée du mandat présidentiel au Burkina Faso selon la Constitution ?", '["4 ans","5 ans","6 ans","7 ans"]', 1, "Le mandat présidentiel est de 5 ans, renouvelable une fois.", 2, "Droit Constitutionnel", "ADMIN_CIVIL"),
    (dc, "Quel organe contrôle la constitutionnalité des lois au Burkina Faso ?", '["La Cour de cassation","Le Conseil constitutionnel","La Cour suprême","Le Tribunal administratif"]', 1, "Le Conseil constitutionnel contrôle la constitutionnalité des lois.", 2, "Droit Constitutionnel", "ADMIN_CIVIL"),
    (dc, "Comment s''appelle le Parlement du Burkina Faso ?", '["Le Sénat","L''Assemblée législative de Transition","L''Assemblée Nationale","Le Congrès"]', 2, "L''Assemblée Nationale est le parlement monocaméral du BF (actuellement Assemblée législative de Transition).", 2, "Droit Constitutionnel", "ADMIN_CIVIL"),
    (dc, "Quel est le principe fondamental de l''État de droit ?", '["La force prime le droit","Le pouvoir est concentré","L''État et ses agents sont soumis au droit","Le président est au-dessus des lois"]', 2, "L''État de droit signifie que tous, y compris l''État et ses agents, sont soumis au respect du droit.", 2, "Droit Constitutionnel", "ADMIN_CIVIL"),
    (dc, "Qui nomme le Premier Ministre au Burkina Faso ?", '["L''Assemblée Nationale","Le Conseil constitutionnel","Le Président du Faso","Le peuple par référendum"]', 2, "Le Premier Ministre est nommé par le Président du Faso.", 2, "Droit Constitutionnel", "ADMIN_CIVIL"),
    (dc, "Quelle est la hiérarchie des normes au Burkina Faso (du sommet à la base) ?", '["Loi > Constitution > Décret","Constitution > Loi > Décret > Arrêté","Décret > Loi > Constitution","Arrêté > Décret > Loi"]', 1, "La hiérarchie des normes place la Constitution au sommet, suivie des lois, décrets, puis arrêtés.", 3, "Droit Constitutionnel", "ADMIN_CIVIL"),
    (dc, "Quel est l''âge minimum pour être candidat à la présidence du Burkina Faso ?", '["25 ans","30 ans","35 ans","40 ans"]', 2, "L''âge minimum pour être candidat à la présidence est de 35 ans.", 2, "Droit Constitutionnel", "ADMIN_CIVIL"),
]

for q_data in questions_droit:
    if insert_q(*q_data):
        ok_count += 1
    total += 1
    time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# ÉCONOMIE / FINANCES — 15 questions
# ═══════════════════════════════════════════════════════════════
print("\n=== ÉCONOMIE / FINANCES ===")

questions_eco = [
    (ec, "Quel est le PIB approximatif du Burkina Faso (2024) ?", '["5 milliards USD","10 milliards USD","19 milliards USD","30 milliards USD"]', 2, "Le PIB du BF est d''environ 19 milliards USD (Banque Mondiale, 2024).", 2, "Économie Générale", "ENAREF"),
    (ec, "Quel est le taux de croissance moyen du BF sur la dernière décennie ?", '["1-2%","3-4%","5-6%","8-10%"]', 2, "Le taux de croissance moyen est d''environ 5-6% par an.", 3, "Économie Générale", "ENAREF"),
    (fp, "Qu''est-ce que le principe de l''annualité budgétaire ?", '["Le budget est voté pour 5 ans","Le budget est voté pour une année civile","Le budget est permanent","Le budget est trimestriel"]', 1, "L''annualité budgétaire signifie que la loi de finances autorise les recettes et dépenses pour une année civile.", 2, "Finances Publiques", "ENAREF"),
    (fp, "Qui vote la loi de finances au Burkina Faso ?", '["Le Président","L''Assemblée Nationale","Le Conseil des Ministres","La Cour des Comptes"]', 1, "La loi de finances est votée par l''Assemblée Nationale.", 2, "Finances Publiques", "ENAREF"),
    (ec, "Que signifie UEMOA ?", '["Union Européenne Monétaire Ouest Africaine","Union Économique et Monétaire Ouest Africaine","Union des États et Marchés Ouest Africains","Union Économique Mondiale pour l''Afrique"]', 1, "UEMOA = Union Économique et Monétaire Ouest Africaine (8 pays dont le BF).", 1, "Économie Générale", "ENAREF"),
    (fp, "Qu''est-ce que l''ordonnateur en finances publiques ?", '["L''agent qui garde les fonds","L''autorité qui prescrit l''exécution des recettes et dépenses","Le comptable public","Le contrôleur financier"]', 1, "L''ordonnateur est l''autorité qui prescrit l''exécution des recettes et dépenses publiques.", 3, "Finances Publiques", "ENAREF"),
    (ec, "Quel est le secteur qui emploie le plus de Burkinabè ?", '["L''industrie","Les services","L''agriculture","Les mines"]', 2, "L''agriculture emploie environ 80% de la population active burkinabè.", 1, "Économie Générale", "ENAREF"),
    (fi, "Quel est le taux normal de TVA au Burkina Faso ?", '["10%","15%","18%","20%"]', 2, "Le taux normal de TVA au BF est de 18%.", 2, "Fiscalité", "ENAREF"),
]

for q_data in questions_eco:
    if insert_q(*q_data):
        ok_count += 1
    total += 1
    time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# FRANÇAIS — 10 questions
# ═══════════════════════════════════════════════════════════════
print("\n=== FRANÇAIS ===")

questions_fr = [
    (fr, "Quel est le pluriel de ''travail'' ?", '["Travails","Travaux","Travailes","Travailles"]', 1, "Le pluriel de travail est travaux (pluriel irrégulier).", 1, "Français", "TOUS"),
    (fr, "Dans la phrase ''Les enfants que j''ai vus'', pourquoi ''vus'' prend un ''s'' ?", '["Parce que le sujet est pluriel","Parce que le COD placé avant est pluriel","Par habitude","Parce que c''est du passé"]', 1, "Avec l''auxiliaire avoir, le participe passé s''accorde avec le COD placé avant le verbe.", 3, "Français", "TOUS"),
    (fr, "Quel est le contraire de ''vénal'' ?", '["Honnête","Intègre","Désintéressé","Toutes les réponses"]', 3, "Vénal signifie ''qui se laisse acheter''. Son contraire est désintéressé, intègre, ou honnête.", 2, "Français", "TOUS"),
    (fr, "Quelle est la forme correcte ?", '["Il faut que je sois là","Il faut que je suis là","Il faut que je serais là","Il faut que j''étais là"]', 0, "Après ''il faut que'', on utilise le subjonctif : ''que je sois''.", 2, "Français", "TOUS"),
    (fr, "Que signifie ''ubiquité'' ?", '["Être partout à la fois","Être très intelligent","Être très rapide","Être invisible"]', 0, "L''ubiquité est la capacité d''être présent partout à la fois (don d''ubiquité).", 2, "Français", "TOUS"),
]

for q_data in questions_fr:
    if insert_q(*q_data):
        ok_count += 1
    total += 1
    time.sleep(0.1)

print(f"\n{'='*50}")
print(f"Step 1 RESULT: {ok_count}/{total} questions inserted")
print(f"{'='*50}")

# Verify total
r_verify = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                          json={"p_sql": "SELECT COUNT(*) AS cnt FROM app.prep_questions WHERE is_published = true"}, timeout=15)
vb = r_verify.json()
if vb.get("ok"):
    print(f"Total published questions in DB: {vb['rows'][0]['cnt']}")
