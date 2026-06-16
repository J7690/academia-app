-- Injection Économie L1 — Tronc commun ECO.GES (UFR SEG UJKZ / UTS Burkina Faso)
-- Macroéconomie, Microéconomie, Gestion, Comptabilité, Statistiques, Droit, HPE

DO $$
DECLARE v_doc_id UUID;
BEGIN
  INSERT INTO app.td_source_documents (
    subject, university, study_year, doc_type,
    storage_bucket, storage_path, original_filename, status, extracted_text
  ) VALUES (
    'Économie', NULL, 'L1', 'cours',
    'manual', 'manual/eco_l1_programme_complet.txt', 'Programme_Economie_L1_BF.txt', 'indexed',
    'Programme L1 Économie-Gestion tronc commun — Introduction à la macroéconomie, microéconomie, gestion, comptabilité générale SYSCOHADA, statistiques descriptives, histoire de la pensée économique, introduction au droit, mathématiques appliquées.'
  ) RETURNING id INTO v_doc_id;

  INSERT INTO app.td_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject, university, study_year, token_count) VALUES

  (gen_random_uuid(), v_doc_id, 0,
$c$INTRODUCTION À LA MACROÉCONOMIE (L1 S1)

La macroéconomie étudie le fonctionnement de l'économie dans son ensemble à travers des agrégats : PIB, inflation, chômage, balance commerciale.

Le PIB (Produit Intérieur Brut) mesure la richesse créée sur un territoire en un an. Trois approches : production (somme des valeurs ajoutées + taxes - subventions), dépenses (C + I + G + X - M), revenus (rémunérations + EBE + revenus mixtes + impôts nets).

Croissance économique : variation du PIB réel. Facteurs : travail, capital, progrès technique (résidu de Solow). PIB nominal vs PIB réel (corrigé de l'inflation). Taux de croissance = (PIBt - PIBt-1) / PIBt-1 × 100.

Inflation : hausse générale et durable du niveau général des prix. Mesurée par l'IPC (Indice des Prix à la Consommation). Causes : inflation par la demande (excès de demande), inflation par les coûts (hausse des matières premières, salaires), inflation monétaire (théorie quantitative de la monnaie : MV = PY).

Chômage : population active - population occupée. Taux de chômage = chômeurs / population active × 100. Types : frictionnel (transition entre emplois), structurel (inadéquation compétences/emplois), conjoncturel (lié au cycle économique). Au BF : secteur informel dominant, sous-emploi.$c$,
  '{"source":"programme","topic":"macroeconomie","subtopic":"introduction_macro_L1"}'::jsonb, 'content', 'Économie', NULL, 'L1', 260),

  (gen_random_uuid(), v_doc_id, 1,
$c$MACROÉCONOMIE — POLITIQUE ÉCONOMIQUE ET MONNAIE (L1 S1)

Politique budgétaire : instrument de l'État pour réguler l'activité économique. Budget = recettes (impôts directs/indirects, cotisations) - dépenses (fonctionnement, investissement, transferts). Solde budgétaire : excédent ou déficit. Multiplicateur keynésien : une augmentation des dépenses publiques entraîne une augmentation plus que proportionnelle du PIB (k = 1/(1-c) où c = propension marginale à consommer).

Politique monétaire : menée par la Banque Centrale (BCEAO pour le BF dans la zone UEMOA). Instruments : taux directeur, réserves obligatoires, opérations d'open market. Objectif principal : stabilité des prix. Le franc CFA est arrimé à l'euro (1 EUR = 655,957 FCFA).

Monnaie : fonctions (unité de compte, moyen de paiement, réserve de valeur). Agrégats monétaires : M1 (billets + pièces + dépôts à vue), M2 (M1 + dépôts à terme < 2 ans), M3 (M2 + OPCVM monétaires + titres de créance < 2 ans). Création monétaire par les banques commerciales : système de réserves fractionnaires. Multiplicateur de crédit.

Circuit économique : agents (ménages, entreprises, État, reste du monde, institutions financières), flux réels et monétaires. Équilibre emplois-ressources : Y + M = C + I + G + X.$c$,
  '{"source":"programme","topic":"macroeconomie","subtopic":"politique_economique_monnaie"}'::jsonb, 'content', 'Économie', NULL, 'L1', 260),

  (gen_random_uuid(), v_doc_id, 2,
$c$INTRODUCTION À LA MICROÉCONOMIE (L1 S1)

La microéconomie étudie le comportement des agents économiques individuels (consommateurs, producteurs) et la formation des prix sur les marchés.

Théorie du consommateur : le consommateur rationnel maximise son utilité sous contrainte budgétaire. Utilité (satisfaction retirée de la consommation). Utilité marginale décroissante. Courbes d'indifférence (convexes, décroissantes, ne se croisent pas). TMS (Taux Marginal de Substitution) = pente de la courbe d'indifférence. Contrainte budgétaire : p1.x1 + p2.x2 = R. Optimum du consommateur : TMS = p1/p2 (tangence courbe d'indifférence / droite de budget).

Élasticités de la demande : élasticité-prix (variation % de la demande / variation % du prix) — demande élastique (|e| > 1), inélastique (|e| < 1), unitaire (|e| = 1). Élasticité-revenu : biens normaux (e > 0), biens inférieurs (e < 0), biens de luxe (e > 1). Élasticité croisée : biens substituables (e > 0), complémentaires (e < 0).

Offre et demande : loi de la demande (prix ↑ → quantité demandée ↓), loi de l'offre (prix ↑ → quantité offerte ↑). Équilibre de marché : intersection O et D. Déplacements de la courbe vs mouvements le long de la courbe. Surplus du consommateur et du producteur.$c$,
  '{"source":"programme","topic":"microeconomie","subtopic":"consommateur_marche"}'::jsonb, 'content', 'Économie', NULL, 'L1', 270),

  (gen_random_uuid(), v_doc_id, 3,
$c$MICROÉCONOMIE — THÉORIE DU PRODUCTEUR ET STRUCTURES DE MARCHÉ (L1 S1)

Théorie du producteur : l'entreprise maximise son profit (π = RT - CT). Fonction de production : Q = f(K, L). Rendements d'échelle : constants, croissants, décroissants. Productivité marginale décroissante (loi des rendements décroissants).

Coûts de production : coût fixe (CF), coût variable (CV), coût total (CT = CF + CV). Coût moyen (CM = CT/Q), coût marginal (Cm = ΔCT/ΔQ). Seuil de rentabilité : CM = prix. Seuil de fermeture : CVM = prix. Profit maximum : Cm = Rm (recette marginale).

Structures de marché :
- Concurrence pure et parfaite (CPP) : atomicité, homogénéité, libre entrée/sortie, transparence, mobilité. Prix = Cm en équilibre long terme. Profit nul à long terme.
- Monopole : un seul vendeur, barrières à l'entrée. Le monopoleur fixe le prix (price maker). Rm = Cm mais prix > Cm. Perte sèche (deadweight loss).
- Concurrence monopolistique : nombreux vendeurs, produits différenciés. Publicité, marques.
- Oligopole : quelques vendeurs dominants. Interdépendance stratégique. Modèles : Cournot (quantités), Bertrand (prix), Stackelberg (leader-suiveur). Cartels (OPEP).$c$,
  '{"source":"programme","topic":"microeconomie","subtopic":"producteur_marches"}'::jsonb, 'content', 'Économie', NULL, 'L1', 260),

  (gen_random_uuid(), v_doc_id, 4,
$c$INTRODUCTION À LA GESTION (L1 S1)

L'entreprise : unité économique qui combine des facteurs de production pour produire des biens ou services destinés à la vente. Classification : par taille (TPE, PME, grande entreprise), par secteur (primaire, secondaire, tertiaire), par forme juridique (EI, SARL, SA, SAS — droit OHADA au BF).

Fonctions de l'entreprise : production, commerciale (marketing), financière, ressources humaines, approvisionnement, R&D. Organigramme : structure hiérarchique, fonctionnelle, divisionnelle, matricielle.

Management : planifier (objectifs, stratégie), organiser (structure, répartition des tâches), diriger (leadership, motivation, communication), contrôler (évaluation, correction). Styles de management : autoritaire, paternaliste, consultatif, participatif (Likert). Théorie X et Y (McGregor).

Environnement de l'entreprise : micro-environnement (clients, fournisseurs, concurrents — modèle des 5 forces de Porter) et macro-environnement (analyse PESTEL : politique, économique, socioculturel, technologique, écologique, légal).

Entrepreneuriat au BF : création d'entreprise au CEFORE, RCCM, statut de l'entreprenant OHADA. Défis : accès au financement, fiscalité, secteur informel.$c$,
  '{"source":"programme","topic":"gestion","subtopic":"introduction_gestion"}'::jsonb, 'content', 'Économie', NULL, 'L1', 260),

  (gen_random_uuid(), v_doc_id, 5,
$c$COMPTABILITÉ GÉNÉRALE I — SYSCOHADA (L1 S2)

La comptabilité est un système d'information qui enregistre, classe et résume les opérations économiques d'une entité. Au BF et en zone OHADA : le SYSCOHADA (Système Comptable OHADA, révisé en 2017) est obligatoire.

Principes comptables fondamentaux : prudence, continuité d'exploitation, coût historique, permanence des méthodes, indépendance des exercices, non-compensation, intangibilité du bilan d'ouverture, importance significative.

Plan comptable SYSCOHADA : 8 classes. Classe 1 : Ressources durables (capitaux, emprunts). Classe 2 : Actif immobilisé (terrains, bâtiments, matériel). Classe 3 : Stocks. Classe 4 : Tiers (clients, fournisseurs). Classe 5 : Trésorerie (banque, caisse). Classe 6 : Charges. Classe 7 : Produits. Classe 8 : Comptes spéciaux.

Partie double : toute opération est enregistrée au débit d'un compte et au crédit d'un autre. Total débits = Total crédits. Le journal enregistre les écritures chronologiquement. Le grand livre regroupe par compte. La balance vérifie l'égalité.

États financiers SYSCOHADA : bilan (patrimoine à une date), compte de résultat (performance sur un exercice), TAFIRE (tableau financier des ressources et emplois), état annexé, état supplémentaire statistique.$c$,
  '{"source":"programme","topic":"comptabilite","subtopic":"comptabilite_syscohada"}'::jsonb, 'content', 'Économie', NULL, 'L1', 260),

  (gen_random_uuid(), v_doc_id, 6,
$c$STATISTIQUES DESCRIPTIVES (L1 S2)

La statistique descriptive a pour objet de résumer et décrire un ensemble de données.

Population, individu, variable (qualitative : nominale, ordinale ; quantitative : discrète, continue). Effectif, fréquence, fréquence cumulée.

Représentations graphiques : diagramme en barres (variable qualitative), histogramme (variable quantitative continue), diagramme circulaire, courbe des fréquences cumulées.

Paramètres de position : moyenne arithmétique (x̄ = Σxi/n), moyenne pondérée, médiane (valeur qui partage la série en deux parties égales), mode (valeur de plus grand effectif). Quartiles (Q1, Q2=médiane, Q3), déciles, centiles.

Paramètres de dispersion : étendue (max - min), variance (σ² = Σ(xi - x̄)²/n), écart-type (σ = √σ²), coefficient de variation (CV = σ/x̄ × 100). Écart interquartile (Q3 - Q1). Boîte à moustaches (boxplot).

Séries à deux variables : tableau de contingence, nuage de points, corrélation linéaire (coefficient de Pearson : r = Σ(xi-x̄)(yi-ȳ) / √[Σ(xi-x̄)².Σ(yi-ȳ)²]). Droite de régression linéaire (méthode des moindres carrés) : y = ax + b. Coefficient de détermination R².$c$,
  '{"source":"programme","topic":"statistiques","subtopic":"statistiques_descriptives"}'::jsonb, 'content', 'Économie', NULL, 'L1', 260),

  (gen_random_uuid(), v_doc_id, 7,
$c$MATHÉMATIQUES APPLIQUÉES À L'ÉCONOMIE (L1 S1-S2)

Fonctions d'une variable : domaine de définition, limites, continuité, dérivées. Dérivées usuelles. Sens de variation et extremums. Applications économiques : coût marginal (dérivée du coût total), recette marginale, élasticité = (dQ/Q) / (dP/P) = (dQ/dP).(P/Q).

Fonctions de plusieurs variables : dérivées partielles, gradient. Optimisation sous contrainte : multiplicateur de Lagrange (L = f(x,y) - λ.g(x,y), résoudre ∂L/∂x = 0, ∂L/∂y = 0, ∂L/∂λ = 0). Application : maximisation de l'utilité sous contrainte budgétaire.

Algèbre linéaire : matrices (addition, multiplication, transposée). Déterminant (2×2 : ad-bc, 3×3 : règle de Sarrus). Matrice inverse. Systèmes d'équations linéaires : méthode de Gauss, méthode de Cramer. Application : modèle de Leontief (input-output).

Suites et séries : suites arithmétiques (un = u0 + n.r) et géométriques (un = u0.qn). Sommes. Applications : capitalisation, actualisation, intérêts composés. Valeur actuelle nette (VAN) = Σ CF_t/(1+r)^t - I0.

Intégration : primitives, intégrale définie. Applications économiques : surplus du consommateur et du producteur (aire entre les courbes).$c$,
  '{"source":"programme","topic":"mathematiques","subtopic":"maths_eco"}'::jsonb, 'content', 'Économie', NULL, 'L1', 260),

  (gen_random_uuid(), v_doc_id, 8,
$c$HISTOIRE DE LA PENSÉE ÉCONOMIQUE (L1 S2)

Mercantilistes (XVIe-XVIIIe s.) : richesse = accumulation de métaux précieux. Protectionnisme, excédent commercial. Colbert (France), Thomas Mun (Angleterre).

Physiocrates (XVIIIe s.) : richesse = production agricole. « Laissez faire, laissez passer ». François Quesnay : Tableau économique (premier modèle de circuit économique).

Classiques (fin XVIIIe-XIXe s.) : Adam Smith (1776, Richesse des Nations) : division du travail, main invisible, libre-échange. David Ricardo : avantages comparatifs, théorie de la rente, loi des rendements décroissants. Thomas Malthus : population croît géométriquement, subsistances arithmétiquement. Jean-Baptiste Say : loi des débouchés (l'offre crée sa propre demande). John Stuart Mill : utilitarisme.

Karl Marx (XIXe s.) : critique du capitalisme, plus-value, exploitation, lutte des classes, baisse tendancielle du taux de profit.

Néoclassiques (fin XIXe s.) : révolution marginaliste. Léon Walras (équilibre général), Alfred Marshall (équilibre partiel, offre et demande), Carl Menger, William Stanley Jevons. Homo economicus rationnel.

John Maynard Keynes (1936, Théorie générale) : critique de la loi de Say, demande effective, chômage involontaire, rôle de l'État (politique budgétaire expansionniste), multiplicateur. Révolution keynésienne.

Courants contemporains : monétarisme (Friedman), école autrichienne (Hayek), nouvelle économie keynésienne, économie institutionnelle, économie du développement (pertinent pour le BF : Amartya Sen, développement humain).$c$,
  '{"source":"programme","topic":"histoire_pensee","subtopic":"HPE"}'::jsonb, 'content', 'Économie', NULL, 'L1', 270),

  (gen_random_uuid(), v_doc_id, 9,
$c$INTRODUCTION AU DROIT (L1 S1)

Le droit : ensemble des règles qui organisent la vie en société et dont le respect est assuré par la puissance publique. Distinction droit objectif (ensemble des règles) / droits subjectifs (prérogatives individuelles).

Sources du droit : Constitution (norme suprême), traités internationaux, lois (votées par l'Assemblée nationale), règlements (décrets, arrêtés), jurisprudence, coutume, doctrine. Hiérarchie des normes (pyramide de Kelsen).

Branches du droit : droit public (constitutionnel, administratif, fiscal, international public) / droit privé (civil, commercial, travail, international privé). Droit mixte : droit pénal, droit social.

Droit des personnes : personnes physiques (capacité juridique, état civil) et personnes morales (sociétés, associations). Patrimoine.

Droit commercial au BF : droit OHADA (Organisation pour l'Harmonisation en Afrique du Droit des Affaires). Actes uniformes : droit commercial général, droit des sociétés commerciales, droit des sûretés, procédures collectives, droit comptable. CCJA (Cour Commune de Justice et d'Arbitrage) à Abidjan.

Droit du travail au BF : Code du travail de 2008. Contrat de travail (CDI, CDD), salaire minimum (SMIG), congés, licenciement, inspection du travail.$c$,
  '{"source":"programme","topic":"droit","subtopic":"introduction_droit"}'::jsonb, 'content', 'Économie', NULL, 'L1', 250);

END;
$$;

-- ═══ QCM L1 Économie (30 questions) ═══
INSERT INTO app.td_questions (id, question_type, content, options, correct_index, explanation, difficulty, subject, is_active, study_year, field, semester, generation_mode) VALUES

(gen_random_uuid(), 'mcq', 'Le PIB mesure :',
'["La richesse totale d''un pays depuis sa création","La valeur des biens et services produits sur un territoire pendant un an","Le patrimoine total des ménages","Les exportations moins les importations"]'::jsonb,
1, 'Le PIB (Produit Intérieur Brut) mesure la richesse créée sur un territoire en une année. Il peut être calculé par les approches production, dépenses ou revenus.', 1, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''équilibre emplois-ressources s''écrit :',
'["Y = C + I","Y + M = C + I + G + X","Y = C + S","PIB = RNB + transferts"]'::jsonb,
1, 'L''équilibre emplois-ressources : Y + M = C + I + G + X (production + importations = consommation + investissement + dépenses publiques + exportations).', 2, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le multiplicateur keynésien (k) avec une propension marginale à consommer c = 0,8 vaut :',
'["0,8","1,25","4","5"]'::jsonb,
3, 'k = 1/(1-c) = 1/(1-0,8) = 1/0,2 = 5. Une hausse de 100 des dépenses publiques entraîne une hausse de 500 du PIB.', 2, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La BCEAO est la banque centrale de :',
'["Le Burkina Faso uniquement","La zone UEMOA (8 pays d''Afrique de l''Ouest)","Toute l''Afrique","La zone CEMAC"]'::jsonb,
1, 'La BCEAO (Banque Centrale des États de l''Afrique de l''Ouest) est la banque centrale commune des 8 pays de l''UEMOA dont le Burkina Faso.', 1, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le taux de change fixe du franc CFA par rapport à l''euro est de :',
'["1 EUR = 100 FCFA","1 EUR = 655,957 FCFA","1 EUR = 1000 FCFA","1 EUR = 500 FCFA"]'::jsonb,
1, 'Le franc CFA est arrimé à l''euro avec une parité fixe : 1 EUR = 655,957 FCFA.', 1, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La théorie quantitative de la monnaie s''exprime par :',
'["MV = PY","C + I = S + T","Y = C + I + G","PIB = VA + taxes"]'::jsonb,
0, 'MV = PY : masse monétaire × vitesse de circulation = niveau des prix × production réelle. Une augmentation de M entraîne une hausse de P (inflation monétaire).', 2, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''optimum du consommateur se trouve au point où :',
'["Le prix est minimum","Le TMS est égal au rapport des prix (p1/p2)","La courbe d''indifférence coupe la droite de budget","Le revenu est maximal"]'::jsonb,
1, 'L''optimum du consommateur est le point de tangence entre la courbe d''indifférence la plus élevée possible et la droite de budget : TMS = p1/p2.', 2, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Une demande est dite élastique si :',
'["L''élasticité-prix est nulle","L''élasticité-prix en valeur absolue est supérieure à 1","L''élasticité-prix en valeur absolue est inférieure à 1","Le prix ne change jamais"]'::jsonb,
1, 'La demande est élastique si |e| > 1 : la quantité demandée varie proportionnellement plus que le prix. Ex : biens de luxe, biens substituables.', 2, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'En concurrence pure et parfaite, le profit à long terme est :',
'["Maximum","Nul","Toujours positif","Toujours négatif"]'::jsonb,
1, 'En CPP, le libre entrée/sortie fait que les entreprises entrent quand il y a profit positif, ce qui fait baisser le prix jusqu''à ce que le profit soit nul à long terme.', 2, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le coût marginal est :',
'["Le coût total divisé par la quantité produite","Le coût de production de la dernière unité produite (ΔCT/ΔQ)","Le coût fixe plus le coût variable","Le coût moyen multiplié par la quantité"]'::jsonb,
1, 'Le coût marginal (Cm) est le coût supplémentaire engendré par la production d''une unité supplémentaire : Cm = ΔCT/ΔQ ou la dérivée du coût total par rapport à Q.', 2, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le modèle des 5 forces de Porter analyse :',
'["Le macro-environnement de l''entreprise","L''intensité concurrentielle dans un secteur d''activité","La structure organisationnelle de l''entreprise","Les ressources humaines"]'::jsonb,
1, 'Les 5 forces de Porter : pouvoir de négociation des clients, des fournisseurs, menace des nouveaux entrants, des produits de substitution, et rivalité entre concurrents existants.', 2, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''analyse PESTEL étudie :',
'["Les forces concurrentielles d''un secteur","Le macro-environnement : politique, économique, socioculturel, technologique, écologique, légal","Les fonctions de l''entreprise","Le plan marketing"]'::jsonb,
1, 'PESTEL est un outil d''analyse du macro-environnement de l''entreprise : Politique, Économique, Socioculturel, Technologique, Écologique, Légal.', 1, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le SYSCOHADA est :',
'["Le système fiscal du Burkina Faso","Le système comptable obligatoire en zone OHADA","Un système de gestion des stocks","Le code du travail ouest-africain"]'::jsonb,
1, 'Le SYSCOHADA (Système Comptable OHADA, révisé en 2017) est le référentiel comptable obligatoire pour les entreprises des 17 pays membres de l''OHADA.', 1, 'Économie', true, 'L1', 'Économie', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le principe de la partie double signifie que :',
'["On enregistre les opérations deux fois dans le journal","Tout montant débité dans un compte est crédité dans un autre, total débits = total crédits","Il faut deux signatures pour valider une écriture","Le bilan a deux parties"]'::jsonb,
1, 'La partie double : chaque opération est enregistrée au débit d''au moins un compte et au crédit d''au moins un autre. Total des débits = Total des crédits.', 2, 'Économie', true, 'L1', 'Économie', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Dans le plan comptable SYSCOHADA, la classe 6 correspond :',
'["À l''actif immobilisé","Aux charges (achats, services, impôts, charges de personnel...)","Aux produits","À la trésorerie"]'::jsonb,
1, 'Classe 6 = Charges des activités ordinaires. Classe 7 = Produits. Classe 1 = Ressources durables. Classe 2 = Actif immobilisé. Classe 5 = Trésorerie.', 2, 'Économie', true, 'L1', 'Économie', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La moyenne arithmétique de la série {2, 4, 6, 8, 10} est :',
'["4","5","6","8"]'::jsonb,
2, 'Moyenne = (2+4+6+8+10)/5 = 30/5 = 6.', 1, 'Économie', true, 'L1', 'Économie', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le coefficient de variation (CV) mesure :',
'["La valeur centrale d''une distribution","La dispersion relative des données par rapport à la moyenne (CV = σ/x̄ × 100)","La symétrie de la distribution","La corrélation entre deux variables"]'::jsonb,
1, 'Le CV = écart-type / moyenne × 100. Il permet de comparer la dispersion de séries ayant des moyennes différentes. Plus le CV est élevé, plus la dispersion relative est grande.', 2, 'Économie', true, 'L1', 'Économie', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le coefficient de corrélation de Pearson (r) est compris entre :',
'["0 et 1","0 et 100","-1 et +1","-∞ et +∞"]'::jsonb,
2, 'Le coefficient r est compris entre -1 (corrélation négative parfaite) et +1 (corrélation positive parfaite). r = 0 signifie absence de corrélation linéaire.', 2, 'Économie', true, 'L1', 'Économie', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Adam Smith est l''auteur de :',
'["Le Capital (1867)","La Richesse des Nations (1776)","La Théorie générale (1936)","Le Tableau économique (1758)"]'::jsonb,
1, 'Adam Smith a publié « Recherches sur la nature et les causes de la richesse des nations » en 1776, oeuvre fondatrice de l''économie politique classique.', 1, 'Économie', true, 'L1', 'Économie', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La « main invisible » d''Adam Smith signifie que :',
'["L''État doit diriger l''économie","La poursuite par chacun de son intérêt personnel contribue à l''intérêt général sans intervention de l''État","Le marché est toujours en déséquilibre","Les prix sont fixés par le gouvernement"]'::jsonb,
1, 'La main invisible : chaque individu, en poursuivant son intérêt personnel, est conduit à promouvoir l''intérêt général sans le vouloir, grâce au mécanisme du marché.', 1, 'Économie', true, 'L1', 'Économie', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La loi des débouchés de Say affirme que :',
'["La demande crée l''offre","L''offre crée sa propre demande","L''État doit réguler les marchés","Les exportations créent les importations"]'::jsonb,
1, 'La loi de Say : « l''offre crée sa propre demande » car la production génère les revenus nécessaires à l''achat de la production. Keynes la critiquera en 1936.', 2, 'Économie', true, 'L1', 'Économie', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La « demande effective » chez Keynes désigne :',
'["La demande des consommateurs uniquement","La demande globale anticipée par les entrepreneurs qui détermine le niveau de production et d''emploi","La demande de monnaie","La demande d''exportations"]'::jsonb,
1, 'Chez Keynes, la demande effective est la demande anticipée par les entrepreneurs. C''est elle qui détermine le niveau de production et donc d''emploi. Si elle est insuffisante, il y a chômage.', 3, 'Économie', true, 'L1', 'Économie', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La théorie des avantages comparatifs de Ricardo montre que :',
'["Seul le pays le plus productif peut exporter","Chaque pays a intérêt à se spécialiser dans la production où il a le moindre désavantage relatif","Le libre-échange est toujours défavorable aux pays pauvres","Les avantages absolus déterminent le commerce"]'::jsonb,
1, 'Ricardo démontre que même si un pays est moins productif dans tous les domaines, il a intérêt à se spécialiser dans le bien où son désavantage est le moindre (avantage comparatif).', 3, 'Économie', true, 'L1', 'Économie', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Dans la pyramide de Kelsen, la norme suprême est :',
'["La loi","Le règlement","La Constitution","Le traité international"]'::jsonb,
2, 'Dans la hiérarchie des normes de Kelsen : Constitution > traités > lois > règlements > jurisprudence. La Constitution est la norme suprême.', 1, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''OHADA est :',
'["Une organisation mondiale du commerce","L''Organisation pour l''Harmonisation en Afrique du Droit des Affaires","Un organisme de développement agricole","Une institution bancaire régionale"]'::jsonb,
1, 'L''OHADA (créée en 1993) harmonise le droit des affaires dans 17 pays africains via des Actes uniformes (droit commercial, sociétés, comptabilité, sûretés, etc.).', 1, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le multiplicateur de Lagrange permet de résoudre un problème de :',
'["Maximisation sans contrainte","Optimisation sous contrainte (maximiser ou minimiser une fonction soumise à une contrainte)","Calcul de déterminant","Résolution de systèmes linéaires"]'::jsonb,
1, 'Le multiplicateur de Lagrange résout les problèmes d''optimisation sous contrainte : max f(x,y) sous contrainte g(x,y)=0. Application : max utilité sous contrainte budgétaire.', 3, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le chômage structurel est dû à :',
'["Une baisse temporaire de l''activité économique","Une inadéquation entre les qualifications offertes et demandées sur le marché du travail","Le temps de recherche entre deux emplois","La saisonnalité de certains secteurs"]'::jsonb,
1, 'Le chômage structurel résulte d''une inadéquation entre les compétences des travailleurs et les besoins des employeurs. Il est durable et ne disparaît pas avec la reprise.', 2, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''inflation par la demande se produit quand :',
'["Les coûts de production augmentent","La demande globale excède l''offre globale","La masse monétaire diminue","Les prix sont fixés par l''État"]'::jsonb,
1, 'L''inflation par la demande se produit quand la demande globale excède la capacité productive de l''économie (offre), entraînant une hausse des prix.', 2, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Un monopoleur se distingue d''une entreprise en CPP car il est :',
'["Price taker (preneur de prix)","Price maker (faiseur de prix)","Toujours en perte","Soumis à la libre entrée"]'::jsonb,
1, 'Le monopoleur est « price maker » : il fixe le prix (ou la quantité) pour maximiser son profit, contrairement à l''entreprise en CPP qui est « price taker ».', 2, 'Économie', true, 'L1', 'Économie', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La VAN (Valeur Actuelle Nette) d''un investissement est :',
'["Le bénéfice comptable annuel","La somme des flux de trésorerie actualisés moins l''investissement initial","Le chiffre d''affaires total","Le taux de rentabilité interne"]'::jsonb,
1, 'VAN = Σ CF_t/(1+r)^t - I0. Si VAN > 0, l''investissement est rentable. Si VAN < 0, il détruit de la valeur. Le taux r est le taux d''actualisation.', 3, 'Économie', true, 'L1', 'Économie', 'S2', 'manual_injection');
