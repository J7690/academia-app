#!/usr/bin/env python3
"""Inject massive university content into td_questions — all disciplines BF."""
import requests, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": " ".join(q.split())}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False}
    return isinstance(body, dict) and body.get("ok", False)

def esc(t): return t.replace("'", "''")

# Get bank ID
r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                    json={"p_sql": "SELECT id FROM app.td_question_banks WHERE title = 'Contenu Universitaire BF' LIMIT 1"}, timeout=15)
bank = r.json()["rows"][0]["id"]
print(f"Bank: {bank}")

def ins(q, opts, ci, expl, diff, subj):
    return sql(f"INSERT INTO app.td_questions (bank_id, question_type, content, options, correct_index, explanation, difficulty, subject, is_active) VALUES ('{bank}', 'mcq', '{esc(q)}', '{opts}'::jsonb, {ci}, '{esc(expl)}', {diff}, '{esc(subj)}', true)")

ok = 0; tot = 0

# ═══════════════════════ DROIT CIVIL APPROFONDI ═══════════════════════
print("=== DROIT CIVIL ===")
for q in [
    ("Qu''est-ce que le dol en droit civil ?", '["Un vice du consentement consistant en des manoeuvres pour tromper","Un type de contrat","Une clause penale","Un mode de paiement"]', 0, "Le dol est un vice du consentement : l''une des parties utilise des manoeuvres frauduleuses pour tromper l''autre et l''amener a contracter.", 3, "Droit Civil"),
    ("Quelle est la difference entre obligations de moyens et de resultat ?", '["L''obligation de moyens garantit le resultat","L''obligation de resultat impose d''atteindre un objectif precis, celle de moyens impose de faire son possible","Aucune difference","L''obligation de moyens est plus contraignante"]', 1, "Obligation de resultat : le debiteur doit atteindre le resultat promis (ex: livraison). Obligation de moyens : il doit deployer les diligences normales (ex: medecin).", 3, "Droit Civil"),
    ("Qu''est-ce que la subrogation en droit des obligations ?", '["Un transfert de propriete","La substitution d''une personne a une autre dans un rapport d''obligation","Un type de contrat","La nullite d''un acte"]', 1, "La subrogation est le mecanisme par lequel une personne (subrogee) se substitue a une autre (subrogeante) dans ses droits contre le debiteur.", 3, "Droit Civil"),
    ("En droit burkinabe, quel est le regime matrimonial legal a defaut de contrat de mariage ?", '["La separation des biens","La communaute reduite aux acquets","La communaute universelle","Le regime dotal"]', 0, "Au Burkina Faso, le regime legal est la separation des biens (Code des personnes et de la famille, art. 299).", 3, "Droit Civil"),
    ("Qu''est-ce que la prescription extinctive ?", '["L''acquisition d''un droit par le temps","L''extinction d''un droit par l''ecoulement d''un delai d''inaction","Un contrat a duree determinee","Une sanction penale"]', 1, "La prescription extinctive eteint un droit (ou une action en justice) apres un delai d''inaction du titulaire.", 2, "Droit Civil"),
]:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════ ALGEBRE / MATHS ═══════════════════════
print("=== ALGEBRE ===")
for q in [
    ("Qu''est-ce qu''un espace vectoriel ?", '["Un ensemble de nombres","Un ensemble muni d''une addition et d''une multiplication par un scalaire verifiant 8 axiomes","Un graphique","Un tableau de donnees"]', 1, "Un espace vectoriel est un ensemble V muni de 2 operations (addition + multiplication scalaire) verifiant 8 axiomes (associativite, commutativite, element neutre, etc.).", 3, "Algèbre"),
    ("Quelle est la dimension de R^3 ?", '["1","2","3","Infini"]', 2, "La dimension de R^3 est 3, car la base canonique {e1, e2, e3} contient 3 vecteurs.", 1, "Algèbre"),
    ("Le determinant d''une matrice 2x2 [[a,b],[c,d]] est :", '["a+d","ad-bc","ac-bd","ab+cd"]', 1, "det = ad - bc. C''est la formule de base du determinant 2x2.", 1, "Algèbre"),
    ("Qu''est-ce qu''une matrice inversible ?", '["Une matrice dont toutes les entrees sont positives","Une matrice carree dont le determinant est non nul","Une matrice diagonale","Une matrice nulle"]', 1, "Une matrice A est inversible si et seulement si det(A) != 0. Son inverse A^(-1) verifie A*A^(-1) = I.", 2, "Algèbre"),
    ("Qu''est-ce que le theoreme de Cayley-Hamilton ?", '["Toute matrice verifie son propre polynome caracteristique","Toute matrice est diagonalisable","Le determinant est toujours positif","Les valeurs propres sont reelles"]', 0, "Le theoreme de Cayley-Hamilton affirme que toute matrice carree A verifie son propre polynome caracteristique : p(A) = 0.", 4, "Algèbre"),
]:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════ MICROECONOMIE ═══════════════════════
print("=== MICROECONOMIE ===")
for q in [
    ("Qu''est-ce que l''utilite marginale ?", '["L''utilite totale","L''utilite supplementaire procuree par la consommation d''une unite supplementaire","Le prix du bien","Le cout de production"]', 1, "L''utilite marginale = variation de l''utilite totale quand la quantite consommee augmente d''une unite. Elle est generalement decroissante.", 2, "Microéconomie"),
    ("Qu''est-ce qu''un bien de Giffen ?", '["Un bien dont la demande augmente quand le prix augmente","Un bien normal","Un bien de luxe","Un bien gratuit"]', 0, "Un bien de Giffen est un cas exceptionnel ou la demande augmente quand le prix augmente (effet revenu > effet substitution).", 4, "Microéconomie"),
    ("En concurrence parfaite, le prix est egal a :", '["Le cout moyen","Le cout marginal","Le cout fixe","Le revenu total"]', 1, "En concurrence parfaite a l''equilibre : P = Cm (cout marginal). L''entreprise maximise son profit quand recette marginale = cout marginal.", 3, "Microéconomie"),
    ("Qu''est-ce que l''elasticite-revenu de la demande ?", '["Variation % de la quantite / Variation % du prix","Variation % de la quantite / Variation % du revenu","Le rapport offre/demande","Le taux d''inflation"]', 1, "Elasticite-revenu = (variation % de la demande) / (variation % du revenu). Si > 1 : bien de luxe. Si < 0 : bien inferieur.", 3, "Microéconomie"),
]:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════ COMPTABILITE SYSCOHADA ═══════════════════════
print("=== COMPTABILITE SYSCOHADA ===")
for q in [
    ("Quel est le plan comptable utilise dans l''espace OHADA ?", '["Le PCG francais","Le SYSCOHADA","Les normes IFRS","Le plan comptable americain"]', 1, "Les 17 pays de l''espace OHADA (dont le BF) utilisent le SYSCOHADA (Systeme Comptable OHADA) revise en 2017.", 1, "Comptabilité SYSCOHADA"),
    ("Dans le SYSCOHADA, la classe 4 concerne :", '["Les immobilisations","Les stocks","Les tiers (fournisseurs, clients, Etat)","Les charges"]', 2, "Classe 4 = Tiers : comptes fournisseurs (40), clients (41), personnel (42), Etat (44), organismes internationaux (45).", 2, "Comptabilité SYSCOHADA"),
    ("Qu''est-ce que l''amortissement en comptabilite ?", '["Un remboursement de dette","La constatation comptable de la perte de valeur d''un actif immobilise","Un benefice","Un impot"]', 1, "L''amortissement est la repartition systematique du cout d''un actif immobilise sur sa duree d''utilite prevue.", 2, "Comptabilité SYSCOHADA"),
    ("Quel est l''objectif des etats financiers du SYSCOHADA ?", '["Calculer les impots","Donner une image fidele de la situation financiere et du resultat","Remplacer le budget","Evaluer les employes"]', 1, "L''objectif premier : donner une image fidele du patrimoine, de la situation financiere et du resultat de l''entite.", 2, "Comptabilité SYSCOHADA"),
    ("Le resultat net de l''exercice se calcule par :", '["Actif - Passif","Produits - Charges","Capital + Reserves","Tresorerie - Dettes"]', 1, "Resultat = Total des produits - Total des charges. S''il est positif = benefice. S''il est negatif = perte.", 1, "Comptabilité SYSCOHADA"),
]:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════ INFORMATIQUE ═══════════════════════
print("=== INFORMATIQUE ===")
for q in [
    ("Qu''est-ce que la normalisation en base de donnees ?", '["Supprimer les donnees","Organiser les tables pour reduire la redondance et les anomalies","Chiffrer les donnees","Sauvegarder les donnees"]', 1, "La normalisation (1NF, 2NF, 3NF, BCNF) est le processus de structuration des tables pour eliminer les redondances et dependances fonctionnelles partielles.", 3, "Informatique"),
    ("En programmation, qu''est-ce que la recursivite ?", '["Une boucle for","Une fonction qui s''appelle elle-meme","Un type de variable","Un systeme d''exploitation"]', 1, "La recursivite est une technique ou une fonction s''appelle elle-meme avec des parametres modifies jusqu''a atteindre un cas de base.", 2, "Informatique"),
    ("Quelle est la difference entre TCP et UDP ?", '["TCP est plus rapide","TCP garantit la livraison des paquets, UDP non","UDP est plus securise","Aucune difference"]', 1, "TCP = fiable, connexion orientee, avec acquittement. UDP = rapide, sans connexion, sans garantie de livraison (streaming, jeux).", 2, "Informatique"),
    ("Qu''est-ce qu''une jointure SQL (JOIN) ?", '["Supprimer des lignes","Combiner des lignes de 2 tables basees sur une condition commune","Creer une table","Modifier une colonne"]', 1, "Le JOIN combine les lignes de 2+ tables quand une condition est verifiee (ex: WHERE t1.id = t2.foreign_id).", 2, "Informatique"),
]:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════ SCIENCES / MEDECINE ═══════════════════════
print("=== SCIENCES / MEDECINE ===")
for q in [
    ("Qu''est-ce que l''homeostasie ?", '["La reproduction cellulaire","La capacite de l''organisme a maintenir un equilibre interne stable","La digestion","La respiration"]', 1, "L''homeostasie est le maintien de conditions internes constantes (temperature, pH, glycemie) malgre les variations exterieures.", 2, "Sciences / Médecine"),
    ("Quel est le role de l''insuline ?", '["Augmenter la glycemie","Diminuer la glycemie en favorisant l''absorption du glucose par les cellules","Digerer les proteines","Transporter l''oxygene"]', 1, "L''insuline (produite par le pancreas) permet aux cellules d''absorber le glucose sanguin, diminuant ainsi la glycemie.", 2, "Sciences / Médecine"),
    ("Qu''est-ce que la meiose ?", '["Division cellulaire donnant 2 cellules identiques","Division cellulaire donnant 4 cellules haploides (gametes)","Fusion de 2 cellules","Mort cellulaire programmee"]', 1, "La meiose produit 4 cellules haploides (n chromosomes) a partir d''une cellule diploidee (2n). Elle est essentielle a la reproduction sexuee.", 3, "Sciences / Médecine"),
    ("Quel est le nombre de chromosomes dans une cellule humaine normale ?", '["23","44","46","48"]', 2, "Une cellule humaine diploidee contient 46 chromosomes (23 paires : 22 paires d''autosomes + 1 paire de chromosomes sexuels).", 1, "Sciences / Médecine"),
]:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════ PHILOSOPHIE ═══════════════════════
print("=== PHILOSOPHIE ===")
for q in [
    ("Qu''est-ce que l''empirisme ?", '["La connaissance vient uniquement de la raison","La connaissance vient de l''experience sensorielle","La connaissance est innee","La connaissance est impossible"]', 1, "L''empirisme (Locke, Hume) affirme que toute connaissance derive de l''experience sensorielle. L''esprit est une tabula rasa.", 2, "Philosophie"),
    ("Qu''est-ce que l''existentialisme selon Sartre ?", '["L''existence precede l''essence","L''essence precede l''existence","L''homme est determine","La liberte n''existe pas"]', 0, "Pour Sartre, l''existence precede l''essence : l''homme existe d''abord, puis se definit par ses choix. Il est condamne a etre libre.", 3, "Philosophie"),
    ("Qu''est-ce que la philosophie ubuntu ?", '["Je pense donc je suis","Je suis parce que nous sommes","L''homme est un loup pour l''homme","Le bonheur est le souverain bien"]', 1, "Ubuntu : philosophie africaine signifiant Je suis parce que nous sommes. L''humanite se definit par la relation a l''autre.", 2, "Philosophie"),
]:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════ ANGLAIS ═══════════════════════
print("=== ANGLAIS ===")
for q in [
    ("Which tense is used: I have been studying for 3 hours?", '["Simple past","Present perfect continuous","Future","Simple present"]', 1, "Present perfect continuous (have been + V-ing) exprime une action commencee dans le passe et qui continue.", 2, "Anglais"),
    ("What is the passive form of: They build houses?", '["Houses are built by them","Houses built by them","They are built houses","Houses were build"]', 0, "Active: They build houses -> Passive: Houses are built by them. (Object becomes subject + be + past participle)", 2, "Anglais"),
    ("Choose the correct sentence:", '["If I was you, I would go","If I were you, I would go","If I am you, I will go","If I be you, I go"]', 1, "Conditionnel type 2 (hypothetique present) : If + past subjunctive (were) + would + base form.", 2, "Anglais"),
]:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════ DROIT ADMINISTRATIF ═══════════════════════
print("=== DROIT ADMINISTRATIF ===")
for q in [
    ("Qu''est-ce que le principe de legalite en droit administratif ?", '["L''administration peut agir librement","L''administration doit agir conformement au droit","Le juge cree le droit","Les citoyens sont au-dessus de la loi"]', 1, "Le principe de legalite impose a l''administration de respecter l''ensemble des normes juridiques (Constitution, lois, reglements).", 2, "Droit Administratif"),
    ("Qu''est-ce qu''un contrat administratif ?", '["Tout contrat passe par une administration","Un contrat comportant des clauses exorbitantes du droit commun ou lie au service public","Un contrat de droit prive","Un contrat commercial"]', 1, "Un contrat est administratif s''il comporte des clauses exorbitantes du droit commun OU s''il fait participer le cocontractant a l''execution du service public.", 3, "Droit Administratif"),
    ("Qu''est-ce que la decentralisation au Burkina Faso ?", '["Le transfert de competences de l''Etat vers des collectivites territoriales dotees de personnalite juridique","La concentration du pouvoir","La privatisation","La suppression des regions"]', 0, "La decentralisation au BF transfere des competences aux 13 regions et 351 communes, chacune dotee de la personnalite juridique et de l''autonomie financiere.", 2, "Droit Administratif"),
]:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════ MACROECONOMIE ═══════════════════════
print("=== MACROECONOMIE ===")
for q in [
    ("Qu''est-ce que le multiplicateur keynesien ?", '["Le taux d''interet","Le rapport entre la variation du revenu national et la variation initiale de la depense","Le taux de change","Le PIB par habitant"]', 1, "Le multiplicateur keynesien : k = 1/(1-c) ou c = propension marginale a consommer. Une hausse de depense de 100 genere un revenu superieur a 100.", 4, "Macroéconomie"),
    ("Qu''est-ce que l''inflation ?", '["La baisse des prix","La hausse generalisee et durable du niveau general des prix","L''augmentation du PIB","La baisse du chomage"]', 1, "L''inflation est la hausse generalisee et durable du niveau general des prix, mesuree par l''IPC (Indice des Prix a la Consommation).", 1, "Macroéconomie"),
    ("Qu''est-ce que la politique monetaire ?", '["La politique fiscale","L''ensemble des actions de la banque centrale pour reguler la monnaie et le credit","La politique commerciale","La politique de l''emploi"]', 1, "La politique monetaire (menee par la BCEAO pour le BF) agit sur la masse monetaire et les taux d''interet pour influencer l''activite economique.", 2, "Macroéconomie"),
]:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

print(f"\n{'='*50}")
print(f"RESULT: {ok}/{tot} questions inserted")

# Final count
rv = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                    json={"p_sql": "SELECT subject, COUNT(*) AS cnt FROM app.td_questions GROUP BY subject ORDER BY cnt DESC"}, timeout=15)
if rv.json().get("ok"):
    total = 0
    print(f"\n--- td_questions par matiere ---")
    for row in rv.json().get("rows", []):
        cnt = row.get("cnt", 0); total += cnt
        print(f"  {row.get('subject','?'):30s} {cnt}")
    print(f"\n  GRAND TOTAL td_questions: {total}")
