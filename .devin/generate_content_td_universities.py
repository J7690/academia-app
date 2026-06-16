#!/usr/bin/env python3
"""Inject university-level TD content across all disciplines for BF universities."""
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

# Get subject IDs + bank
r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                   json={"p_sql": "SELECT id, slug FROM app.prep_subjects"}, timeout=15)
sm = {row["slug"]: row["id"] for row in r.json().get("rows", [])}
r2 = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                    json={"p_sql": "SELECT id FROM app.prep_question_banks WHERE title LIKE '%Culture Générale BF%' LIMIT 1"}, timeout=15)
bank = r2.json()["rows"][0]["id"]

cg = sm.get("culture_gen","")
dc = sm.get("droit_constit","")
da = sm.get("droit_admin","")
dc_civ = sm.get("droit_civil","")
dp = sm.get("droit_penal","")
dt = sm.get("droit_travail","")
ec = sm.get("economie","")
fp = sm.get("finances_pub","")
fi = sm.get("fiscalite","")
co = sm.get("comptabilite","")
ma = sm.get("maths","")
fr = sm.get("francais","")
sn = sm.get("sciences_nat","")
inf = sm.get("informatique","")
pe = sm.get("pedagogie","")
gr = sm.get("grh_management","")
ps = sm.get("psychotech","")

def ins(sid, q, opts, ci, expl, diff, subj, conc):
    return sql(f"INSERT INTO app.prep_questions (subject_id, bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active) VALUES ('{sid}', '{bank}', '{esc(q)}', '{esc(q)}', '{opts}'::jsonb, {ci}, '{esc(expl)}', {diff}, '{esc(subj)}', '{conc}', 'mcq', 'beginner', 'university_bf', true, true)")

ok = 0
tot = 0

# ═══════════════════════════════════════════════════════════════
# DROIT CIVIL (L1-L2) — Programme UJK/UCAO BF
# ═══════════════════════════════════════════════════════════════
print("=== DROIT CIVIL ===")
questions = [
    (dc_civ, "Quelle est la source principale du droit civil au Burkina Faso ?", '["La Constitution","Le Code des personnes et de la famille","Le Code pénal","Le Code du travail"]', 1, "Le Code des personnes et de la famille (Zatu AN VII du 16 nov 1989) est la source principale du droit civil burkinabe.", 2, "Droit Civil", "TOUS"),
    (dc_civ, "Qu''est-ce que la personnalité juridique ?", '["Le droit de vote","L''aptitude a etre titulaire de droits et d''obligations","Le droit de conduire","La citoyennete"]', 1, "La personnalite juridique est l''aptitude a etre sujet de droit, c-a-d titulaire de droits et d''obligations.", 2, "Droit Civil", "TOUS"),
    (dc_civ, "A quel age acquiert-on la majorite civile au Burkina Faso ?", '["16 ans","18 ans","20 ans","21 ans"]', 3, "Au Burkina Faso, la majorite civile est fixee a 21 ans (art. 554 du Code des personnes et de la famille), contrairement a la France (18 ans).", 2, "Droit Civil", "TOUS"),
    (dc_civ, "Qu''est-ce qu''un contrat synallagmatique ?", '["Un contrat a titre gratuit","Un contrat ou les deux parties ont des obligations reciproques","Un contrat unilateral","Un contrat verbal"]', 1, "Le contrat synallagmatique cree des obligations reciproques entre les parties (ex: vente, bail).", 2, "Droit Civil", "TOUS"),
    (dc_civ, "Quels sont les 3 elements de la responsabilite civile delictuelle ?", '["Faute, dommage, lien de causalite","Contrat, inexecution, sanction","Intention, action, resultat","Prejudice, indemnisation, jugement"]', 0, "La responsabilite civile delictuelle repose sur 3 elements : une faute, un dommage et un lien de causalite entre les deux.", 3, "Droit Civil", "TOUS"),
    (dc_civ, "Qu''est-ce que la force majeure en droit civil ?", '["Un evenement previsible","Un evenement imprevisible, irresistible et exterieur","Une faute grave","Un cas de negligence"]', 1, "La force majeure est un evenement imprevisible, irresistible et exterieur qui exonere de la responsabilite.", 3, "Droit Civil", "TOUS"),
]
for q in questions:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# ANALYSE MATHÉMATIQUE (L1-L2)
# ═══════════════════════════════════════════════════════════════
print("=== ANALYSE MATHEMATIQUE ===")
maths_q = [
    (ma, "Quelle est la derivee de f(x) = x^3 + 2x^2 - 5x + 1 ?", '["3x^2 + 4x - 5","3x^2 + 2x - 5","x^3 + 4x - 5","3x^2 + 4x + 1"]', 0, "f''(x) = 3x^2 + 4x - 5 (regle de derivation des polynomes : n*x^(n-1)).", 2, "Mathématiques", "TOUS"),
    (ma, "Quelle est la limite de (sin x)/x quand x tend vers 0 ?", '["0","1","Infini","N''existe pas"]', 1, "lim(x->0) sin(x)/x = 1. C''est un resultat fondamental d''analyse.", 2, "Mathématiques", "TOUS"),
    (ma, "Qu''est-ce qu''une suite de Cauchy ?", '["Une suite croissante","Une suite dont les termes se rapprochent indefiniment","Une suite bornee","Une suite periodique"]', 1, "Une suite de Cauchy est une suite (u_n) telle que pour tout epsilon > 0, il existe N tel que pour tout m,n >= N, |u_m - u_n| < epsilon.", 3, "Mathématiques", "TOUS"),
    (ma, "La primitive de 1/x est :", '["x^2/2","ln|x| + C","1/x^2","e^x"]', 1, "L''integrale de 1/x dx = ln|x| + C (logarithme neperien).", 2, "Mathématiques", "TOUS"),
    (ma, "Le theoreme de Rolle stipule que si f est continue sur [a,b], derivable sur ]a,b[ et f(a)=f(b), alors :", '["f est constante","Il existe c dans ]a,b[ tel que f''(c) = 0","f est croissante","f(a) = 0"]', 1, "Le theoreme de Rolle garantit l''existence d''au moins un point c dans ]a,b[ ou la derivee s''annule.", 3, "Mathématiques", "TOUS"),
    (ma, "Quelle est l''integrale de e^x dx ?", '["xe^x + C","e^x + C","e^(x+1)/(x+1) + C","ln(e^x) + C"]', 1, "L''integrale de e^x est e^x + C. La fonction exponentielle est sa propre primitive.", 1, "Mathématiques", "TOUS"),
]
for q in maths_q:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# ÉCONOMIE GÉNÉRALE / MICROÉCONOMIE (L1-L2)
# ═══════════════════════════════════════════════════════════════
print("=== ECONOMIE ===")
eco_q = [
    (ec, "Qu''est-ce que le PIB ?", '["Le produit interieur brut = somme des valeurs ajoutees","Le produit international bancaire","Le plan d''investissement budgetaire","Le protocole d''intervention bilateral"]', 0, "Le PIB = somme des valeurs ajoutees produites par les agents economiques residant sur le territoire national pendant une annee.", 1, "Économie Générale", "TOUS"),
    (ec, "Qu''est-ce que l''elasticite-prix de la demande ?", '["Le rapport prix/quantite","La mesure de la sensibilite de la demande a une variation de prix","Le prix d''equilibre","Le cout marginal"]', 1, "L''elasticite-prix de la demande = (variation % de la quantite demandee) / (variation % du prix). Elle mesure la reactivite de la demande au prix.", 3, "Économie Générale", "TOUS"),
    (ec, "Dans le modele offre-demande, qu''arrive-t-il quand le prix est superieur au prix d''equilibre ?", '["Penurie","Exces d''offre (surplus)","Equilibre","Inflation"]', 1, "Quand P > Pe, la quantite offerte > quantite demandee = surplus/exces d''offre.", 2, "Économie Générale", "TOUS"),
    (ec, "Qu''est-ce que la loi des rendements decroissants ?", '["Plus on produit, plus le cout baisse","A partir d''un certain seuil, chaque unite supplementaire d''un facteur produit de moins en moins","La production est toujours croissante","Les couts sont constants"]', 1, "Quand on augmente un facteur de production (les autres etant fixes), la productivite marginale finit par decroitre.", 3, "Économie Générale", "TOUS"),
    (ec, "Quel est le taux de croissance du PIB reel du Burkina Faso en 2024 (approximatif) ?", '["1-2%","3-4%","5-6%","8-10%"]', 2, "Le BF a connu un taux de croissance d''environ 5-6% ces dernieres annees malgre les defis securitaires.", 2, "Économie Générale", "TOUS"),
]
for q in eco_q:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# COMPTABILITE SYSCOHADA (L1-L3)
# ═══════════════════════════════════════════════════════════════
print("=== COMPTABILITE SYSCOHADA ===")
compta_q = [
    (co, "Dans le SYSCOHADA revise, les comptes de classe 1 representent :", '["Les charges","Les produits","Les ressources stables (capitaux propres + dettes financieres)","La tresorerie"]', 2, "Classe 1 du SYSCOHADA = Ressources stables : capital social, reserves, emprunts a long terme.", 2, "Comptabilité", "TOUS"),
    (co, "Qu''est-ce que le principe de prudence en comptabilite ?", '["Enregistrer tous les benefices probables","Ne comptabiliser que les pertes probables et pas les gains incertains","Ignorer les pertes","Surestimer les actifs"]', 1, "Le principe de prudence impose d''enregistrer les charges et pertes des qu''elles sont probables, mais les produits que lorsqu''ils sont realises.", 2, "Comptabilité", "TOUS"),
    (co, "Quelle est la formule du bilan comptable ?", '["Actif = Passif","Actif - Passif = Resultat","Actif = Charges + Produits","Produits - Charges = Actif"]', 0, "L''equation fondamentale : ACTIF = PASSIF (avec Passif = Capitaux propres + Dettes).", 1, "Comptabilité", "TOUS"),
    (co, "Dans le SYSCOHADA, les comptes de classe 6 enregistrent :", '["Les immobilisations","Les produits","Les charges des activites ordinaires","Les stocks"]', 2, "Classe 6 = Charges des activites ordinaires (achats, services exterieurs, impots, charges de personnel, etc.).", 2, "Comptabilité", "TOUS"),
    (co, "Qu''est-ce qu''une ecriture comptable en partie double ?", '["Un enregistrement dans un seul compte","Tout debit a un credit correspondant de meme montant","Un enregistrement en deux devises","Un double paiement"]', 1, "Principe de la partie double : toute operation est enregistree au debit d''un compte et au credit d''un autre, pour le meme montant.", 1, "Comptabilité", "TOUS"),
]
for q in compta_q:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# INFORMATIQUE (L1-L2)
# ═══════════════════════════════════════════════════════════════
print("=== INFORMATIQUE ===")
info_q = [
    (inf, "Qu''est-ce qu''un algorithme ?", '["Un logiciel","Une suite finie d''instructions pour resoudre un probleme","Un langage de programmation","Un systeme d''exploitation"]', 1, "Un algorithme est une suite finie et ordonnee d''instructions permettant de resoudre un probleme ou d''obtenir un resultat.", 1, "Informatique", "TOUS"),
    (inf, "Quelle est la complexite temporelle d''une recherche dichotomique ?", '["O(n)","O(n^2)","O(log n)","O(1)"]', 2, "La recherche dichotomique a une complexite en O(log n) car elle divise l''espace de recherche par 2 a chaque etape.", 3, "Informatique", "TOUS"),
    (inf, "En SQL, quelle commande permet de selectionner des donnees ?", '["INSERT","UPDATE","SELECT","DELETE"]', 2, "SELECT est la commande SQL pour extraire des donnees d''une table.", 1, "Informatique", "TOUS"),
    (inf, "Qu''est-ce qu''une cle primaire dans une base de donnees ?", '["Un mot de passe","Un identifiant unique pour chaque enregistrement d''une table","Un index de recherche","Un type de donnees"]', 1, "La cle primaire identifie de maniere unique chaque ligne d''une table relationnelle.", 2, "Informatique", "TOUS"),
    (inf, "Quel est le resultat de 1011 + 0110 en binaire ?", '["1001","10001","10101","10001"]', 1, "1011 (11) + 0110 (6) = 10001 (17 en decimal).", 2, "Informatique", "TOUS"),
]
for q in info_q:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# SCIENCES NATURELLES / MEDECINE (1ere annee)
# ═══════════════════════════════════════════════════════════════
print("=== SCIENCES / MEDECINE ===")
sci_q = [
    (sn, "Quelle est la molecule responsable du transport de l''oxygene dans le sang ?", '["L''insuline","L''hemoglobine","Le glucose","L''ADN"]', 1, "L''hemoglobine est la proteine presente dans les globules rouges qui transporte l''oxygene des poumons vers les tissus.", 1, "Sciences Naturelles / SVT", "TOUS"),
    (sn, "Qu''est-ce que la mitose ?", '["La division cellulaire qui produit 2 cellules identiques","La fusion de 2 cellules","La mort cellulaire","La division qui produit des gametes"]', 0, "La mitose est la division cellulaire qui produit 2 cellules filles genetiquement identiques a la cellule mere.", 2, "Sciences Naturelles / SVT", "TOUS"),
    (sn, "Quel est le pH du sang humain normal ?", '["5.0","6.5","7.4","8.5"]', 2, "Le pH sanguin normal est de 7.35 a 7.45 (legerement alcalin). Un ecart meme leger est dangereux.", 2, "Sciences Naturelles / SVT", "TOUS"),
    (sn, "Quel organe produit la bile ?", '["L''estomac","Le foie","Le pancreas","L''intestin"]', 1, "La bile est produite par le foie et stockee dans la vesicule biliaire. Elle aide a la digestion des graisses.", 1, "Sciences Naturelles / SVT", "TOUS"),
    (sn, "Qu''est-ce que l''ATP en biochimie ?", '["Un acide amine","La molecule energetique universelle de la cellule","Un lipide","Une vitamine"]', 1, "L''ATP (Adenosine TriPhosphate) est la principale source d''energie utilisable par les cellules vivantes.", 2, "Sciences Naturelles / SVT", "TOUS"),
]
for q in sci_q:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# PHILOSOPHIE / SOCIOLOGIE (L1)
# ═══════════════════════════════════════════════════════════════
print("=== PHILOSOPHIE / SOCIOLOGIE ===")
philo_q = [
    (pe, "Qui a ecrit La Republique ?", '["Aristote","Platon","Socrate","Descartes"]', 1, "La Republique est un dialogue de Platon ou il expose sa theorie de la cite ideale et le mythe de la caverne.", 1, "Pédagogie", "TOUS"),
    (pe, "Qu''est-ce que le cogito de Descartes ?", '["Je pense donc je suis","L''homme est un animal politique","Connais-toi toi-meme","La fin justifie les moyens"]', 0, "Cogito ergo sum = Je pense donc je suis. Pour Descartes, le doute meme prouve l''existence du sujet pensant.", 2, "Pédagogie", "TOUS"),
    (pe, "Qu''est-ce que la socialisation selon Durkheim ?", '["L''apprentissage de la solitude","Le processus par lequel l''individu integre les normes et valeurs de la societe","La creation d''entreprise","L''immigration"]', 1, "Pour Durkheim, la socialisation est le processus d''integration des normes, valeurs et comportements de la societe.", 2, "Pédagogie", "TOUS"),
    (pe, "Quel philosophe africain a theorise la Negritude ?", '["Kwame Nkrumah","Leopold Sedar Senghor","Nelson Mandela","Thomas Sankara"]', 1, "Leopold Sedar Senghor (avec Aime Cesaire) a theorise la Negritude, mouvement de revalorisation de la culture noire.", 2, "Pédagogie", "TOUS"),
]
for q in philo_q:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# DROIT CONSTITUTIONNEL BF (approfondi)
# ═══════════════════════════════════════════════════════════════
print("=== DROIT CONSTITUTIONNEL BF ===")
dconst_q = [
    (dc, "En quelle annee la Constitution actuelle du Burkina Faso a-t-elle ete adoptee ?", '["1960","1987","1991","2000"]', 2, "La Constitution du BF a ete adoptee par referendum le 2 juin 1991 et a ete revisee plusieurs fois depuis.", 2, "Droit Constitutionnel", "TOUS"),
    (dc, "Combien de titres comporte la Constitution du Burkina Faso ?", '["10","15","17","20"]', 2, "La Constitution du BF comporte 17 titres (du Titre I sur l''Etat et la souverainete au Titre XVII sur la revision).", 3, "Droit Constitutionnel", "TOUS"),
    (dc, "Quel organe veille a la regularite des elections au Burkina Faso ?", '["Le Tribunal administratif","Le Conseil constitutionnel","La CENI","Le Ministere de la Justice"]', 1, "Le Conseil constitutionnel veille a la regularite des elections et proclame les resultats definitifs.", 2, "Droit Constitutionnel", "TOUS"),
    (dc, "Qu''est-ce que le Mediateur du Faso ?", '["Un juge","Une autorite administrative independante chargee de la mediation entre l''administration et les citoyens","Un avocat","Un policier"]', 1, "Le Mediateur du Faso est une AAI qui recoit les reclamations des citoyens contre l''administration.", 3, "Droit Constitutionnel", "TOUS"),
]
for q in dconst_q:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# GRH / MANAGEMENT
# ═══════════════════════════════════════════════════════════════
print("=== GRH / MANAGEMENT ===")
grh_q = [
    (gr, "Quelles sont les 4 fonctions du management selon Fayol ?", '["Vendre, acheter, stocker, livrer","Planifier, organiser, diriger, controler","Recruter, former, payer, licencier","Produire, financer, communiquer, innover"]', 1, "Henri Fayol a defini 4 fonctions fondamentales : Planifier (prevoir), Organiser, Diriger (commander), Controler (PODC).", 2, "GRH et Management", "TOUS"),
    (gr, "Qu''est-ce que la theorie X et Y de McGregor ?", '["Deux types de produits","Deux visions opposees du travailleur (X=passif, Y=motive)","Deux types de marches","Deux formes de contrat"]', 1, "McGregor : Theorie X = l''homme est paresseux et fuit les responsabilites. Theorie Y = l''homme est naturellement motive et recherche les responsabilites.", 3, "GRH et Management", "TOUS"),
    (gr, "Au Burkina Faso, quel est l''organisme charge de la securite sociale des travailleurs ?", '["La BCEAO","La CNSS","La DGI","Le Tresor Public"]', 1, "La CNSS (Caisse Nationale de Securite Sociale) gere les prestations sociales des travailleurs du secteur prive au BF.", 2, "GRH et Management", "TOUS"),
]
for q in grh_q:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
# FRANÇAIS / MÉTHODOLOGIE
# ═══════════════════════════════════════════════════════════════
print("=== FRANCAIS / METHODOLOGIE ===")
fr_q = [
    (fr, "Quelle est la structure d''une dissertation en 3 parties ?", '["Introduction, developpement, bibliographie","These, antithese, synthese","Probleme, analyse, solution","Resume, critique, opinion"]', 1, "La dissertation classique suit le plan dialectique : These (arguments pour), Antithese (arguments contre), Synthese (depassement).", 2, "Français", "TOUS"),
    (fr, "Qu''est-ce qu''un syllogisme ?", '["Une figure de style","Un raisonnement logique en 3 propositions (premisse majeure, mineure, conclusion)","Un type de poeme","Une erreur de grammaire"]', 1, "Le syllogisme : Tous les hommes sont mortels (majeure). Socrate est un homme (mineure). Donc Socrate est mortel (conclusion).", 2, "Français", "TOUS"),
    (fr, "Quelle est la difference entre ''ce'' et ''se'' ?", '["Aucune difference","Ce = demonstratif, Se = pronom reflexif","Ce = pronom personnel, Se = adjectif","Ce = verbe, Se = adverbe"]', 1, "Ce est un determinant demonstratif (ce livre) ou pronom (ce qui). Se est un pronom reflexif (il se lave).", 1, "Français", "TOUS"),
    (fr, "Qu''est-ce qu''un commentaire de texte ?", '["Un resume du texte","Une analyse structuree qui met en evidence les procedes et le sens d''un texte","Une traduction","Une dictee"]', 1, "Le commentaire de texte est un exercice d''analyse litteraire qui etudie le fond (sens, themes) et la forme (procedes, style) d''un texte.", 2, "Français", "TOUS"),
]
for q in fr_q:
    if ins(*q): ok += 1
    tot += 1; time.sleep(0.1)

print(f"\n{'='*50}")
print(f"RESULT: {ok}/{tot} questions inserted")

# Final count
rv = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                    json={"p_sql": "SELECT subject, COUNT(*) AS cnt FROM app.prep_questions WHERE is_published GROUP BY subject ORDER BY cnt DESC"}, timeout=15)
if rv.json().get("ok"):
    print(f"\n--- Questions par matiere ---")
    total = 0
    for row in rv.json().get("rows", []):
        cnt = row.get("cnt", 0)
        total += cnt
        print(f"  {row.get('subject','?'):35s} {cnt}")
    print(f"\n  GRAND TOTAL: {total}")
