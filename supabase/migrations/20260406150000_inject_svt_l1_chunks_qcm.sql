-- Injection SVT L1 — Sciences de la Vie et de la Terre — Source document + chunks + QCM
-- Adapté aux programmes Sorbonne / UJKZ Ouagadougou / standards internationaux

DO $$
DECLARE v_doc_id UUID;
BEGIN
  INSERT INTO app.td_source_documents (
    subject, university, study_year, doc_type,
    storage_bucket, storage_path, original_filename, status, extracted_text
  ) VALUES (
    'Sciences de la Vie et de la Terre', NULL, 'L1', 'cours',
    'manual', 'manual/svt_l1_programme_complet.txt', 'Programme_SVT_L1.txt', 'indexed',
    'Programme complet SVT L1 — Biologie cellulaire, chimie générale, géosciences, mathématiques pour les sciences, biodiversité, écologie introductive.'
  ) RETURNING id INTO v_doc_id;

  INSERT INTO app.td_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject, university, study_year, token_count) VALUES

  (gen_random_uuid(), v_doc_id, 0,
$c$BIOLOGIE CELLULAIRE — ORGANISATION CELLULAIRE DU VIVANT (L1 S1)

La cellule est l'unité structurale et fonctionnelle de tous les êtres vivants. On distingue deux grands types cellulaires : les cellules procaryotes (bactéries, archées) sans noyau délimité par une membrane, et les cellules eucaryotes (animales, végétales, champignons, protistes) possédant un noyau vrai.

Organites de la cellule eucaryote : noyau (contient l'ADN, siège de la transcription), réticulum endoplasmique (rugueux : synthèse protéique ; lisse : synthèse lipidique), appareil de Golgi (maturation et tri des protéines), mitochondries (respiration cellulaire, production d'ATP), lysosomes (digestion intracellulaire), cytosquelette (microfilaments d'actine, microtubules, filaments intermédiaires).

Particularités de la cellule végétale : paroi cellulosique, vacuole centrale, chloroplastes (photosynthèse). Membrane plasmique : bicouche de phospholipides, protéines membranaires (intégrales, périphériques), perméabilité sélective.

Cycle cellulaire : interphase (G1, S, G2) et mitose (prophase, métaphase, anaphase, télophase). La méiose produit des cellules haploïdes (gamètes) à partir de cellules diploïdes.$c$,
  '{"source":"programme","topic":"biologie_cellulaire","subtopic":"organisation_cellulaire"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L1', 250),

  (gen_random_uuid(), v_doc_id, 1,
$c$CHIMIE GÉNÉRALE — STRUCTURE ET RÉACTIVITÉ (L1 S1)

Structure de l'atome : noyau (protons + neutrons) et cortège électronique. Nombre atomique Z, nombre de masse A, isotopes. Configuration électronique : principe d'exclusion de Pauli, règle de Klechkowski, règle de Hund.

Classification périodique : périodes et groupes. Propriétés périodiques : rayon atomique, énergie d'ionisation, électronégativité (échelle de Pauling). Métaux, non-métaux, métalloïdes.

Liaisons chimiques : liaison covalente (partage d'électrons), liaison ionique (transfert d'électrons), liaison métallique, interactions faibles (Van der Waals, liaisons hydrogène). Modèle de Lewis. Géométrie moléculaire : méthode VSEPR.

Réactions chimiques : équilibre des réactions, stoechiométrie, loi de conservation de la masse (Lavoisier). Solutions aqueuses : concentration molaire, pH, acides et bases (Brønsted-Lowry). Réactions d'oxydo-réduction : nombre d'oxydation, couples redox.$c$,
  '{"source":"programme","topic":"chimie","subtopic":"structure_reactivite"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L1', 230),

  (gen_random_uuid(), v_doc_id, 2,
$c$GÉOSCIENCES — TERRE, CLIMAT, ENVIRONNEMENT (L1 S1)

Structure interne de la Terre : croûte (continentale : granitique ; océanique : basaltique), manteau (supérieur et inférieur), noyau (externe liquide, interne solide). Discontinuités : Moho, Gutenberg, Lehmann. Méthodes d'étude : sismologie (ondes P et S).

Tectonique des plaques : plaques lithosphériques, dorsales océaniques (divergence), zones de subduction (convergence), failles transformantes. Moteur : convection mantellique. Preuves : complémentarité des côtes, fossiles identiques, paléomagnétisme, âge des fonds océaniques.

Minéraux et roches : roches magmatiques (plutoniques : granite ; volcaniques : basalte), roches sédimentaires (détritiques : grès ; chimiques : calcaire ; organiques : charbon), roches métamorphiques (schiste, gneiss, marbre). Cycle des roches.

Climat : facteurs (rayonnement solaire, effet de serre, circulation atmosphérique et océanique). Changements climatiques : paléoclimatologie, indicateurs (isotopes de l'oxygène, carottes de glace, pollens fossiles). Enjeux environnementaux actuels : réchauffement climatique, biodiversité menacée.$c$,
  '{"source":"programme","topic":"geosciences","subtopic":"terre_climat_environnement"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L1', 250),

  (gen_random_uuid(), v_doc_id, 3,
$c$MATHÉMATIQUES POUR LES SCIENCES (L1 S1-S2)

Analyse : fonctions d'une variable réelle (limites, continuité, dérivabilité). Dérivées et applications (études de fonctions, optimisation). Intégrales : primitives, intégrale de Riemann, calcul d'aires. Développements limités.

Algèbre linéaire : vecteurs, espaces vectoriels, applications linéaires. Matrices : opérations, déterminant, inverse. Systèmes d'équations linéaires (méthode de Gauss).

Statistiques et probabilités : statistiques descriptives (moyenne, médiane, écart-type, variance). Lois de probabilité : loi binomiale, loi de Poisson, loi normale. Tests statistiques de base.

Applications en biologie : modélisation de la croissance des populations (modèle exponentiel, modèle logistique), cinétique enzymatique (équation de Michaelis-Menten), pharmacocinétique. Analyse de données expérimentales : régression linéaire, corrélation.$c$,
  '{"source":"programme","topic":"mathematiques","subtopic":"maths_pour_sciences"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L1', 220),

  (gen_random_uuid(), v_doc_id, 4,
$c$BIODIVERSITÉ ET ÉCOLOGIE INTRODUCTIVE (L1 S2)

Classification du vivant : les trois domaines (Bacteria, Archaea, Eukarya). Règnes eucaryotes : Animalia, Plantae, Fungi, Protista. Systématique phylogénétique : arbres phylogénétiques, synapomorphies, groupes monophylétiques. Nomenclature binomiale de Linné.

Diversité des organismes :
- Procaryotes : bactéries (Gram+, Gram-), archées (extrémophiles)
- Protistes : algues unicellulaires, protozoaires
- Champignons : levures, moisissures, champignons filamenteux
- Végétaux : bryophytes, ptéridophytes, gymnospermes, angiospermes
- Animaux : invertébrés (cnidaires, mollusques, arthropodes, annélides) ; vertébrés (poissons, amphibiens, reptiles, oiseaux, mammifères)

Écologie introductive : écosystèmes, chaînes et réseaux trophiques, producteurs, consommateurs, décomposeurs. Cycles biogéochimiques (carbone, azote, phosphore). Pyramides écologiques (nombre, biomasse, énergie). Notion de niche écologique.$c$,
  '{"source":"programme","topic":"biodiversite","subtopic":"biodiversite_ecologie_intro"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L1', 240),

  (gen_random_uuid(), v_doc_id, 5,
$c$BIOLOGIE ANIMALE ET VÉGÉTALE INTRODUCTIVE (L1 S2)

Biologie animale :
- Plans d'organisation : symétrie radiaire (cnidaires), symétrie bilatérale (bilatériens). Protostomiens vs deutérostomiens.
- Grandes fonctions : nutrition (digestion, absorption), respiration (branchiale, pulmonaire, cutanée, trachéenne), circulation (ouverte vs fermée), excrétion (néphridies, reins), reproduction (sexuée, asexuée).

Biologie végétale :
- Organisation de la plante : racine (absorption eau et sels minéraux), tige (transport), feuille (photosynthèse).
- Tissus végétaux : méristèmes, parenchyme, collenchyme, sclérenchyme, xylème, phloème.
- Photosynthèse : phase claire (thylakoïdes : photolyse de l'eau, chaîne de transport d'électrons, ATP synthase) et phase sombre (cycle de Calvin, fixation du CO2).
- Reproduction végétale : cycle de développement haplo-diplobiontique, fleur (sépales, pétales, étamines, pistil), pollinisation, fécondation, formation du fruit et de la graine. Germination.$c$,
  '{"source":"programme","topic":"biologie_organismes","subtopic":"biologie_animale_vegetale"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L1', 240);

END;
$$;

-- ═══ QCM L1 SVT (20 questions) ═══
INSERT INTO app.td_questions (id, question_type, content, options, correct_index, explanation, difficulty, subject, is_active, study_year, field, semester, generation_mode) VALUES

(gen_random_uuid(), 'mcq', 'Quelle est l''unité structurale et fonctionnelle de tous les êtres vivants ?',
'["Le tissu","L''organe","La cellule","La molécule"]'::jsonb, 2,
'La cellule est l''unité structurale et fonctionnelle de tous les êtres vivants. C''est le plus petit niveau d''organisation possédant toutes les propriétés du vivant.', 1, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Quel organite est le siège de la respiration cellulaire et de la production d''ATP ?',
'["Le noyau","Le réticulum endoplasmique","La mitochondrie","L''appareil de Golgi"]'::jsonb, 2,
'La mitochondrie est le siège de la respiration cellulaire aérobie et produit l''essentiel de l''ATP de la cellule eucaryote.', 1, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Quelles sont les structures présentes dans la cellule végétale mais absentes de la cellule animale ?',
'["Mitochondries et ribosomes","Paroi cellulosique, vacuole centrale et chloroplastes","Noyau et réticulum endoplasmique","Lysosomes et peroxysomes"]'::jsonb, 1,
'La cellule végétale possède une paroi cellulosique, une vacuole centrale et des chloroplastes que la cellule animale n''a pas.', 1, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La méiose produit :',
'["2 cellules diploïdes identiques","4 cellules haploïdes génétiquement différentes","2 cellules haploïdes identiques","4 cellules diploïdes identiques"]'::jsonb, 1,
'La méiose est une division réductionnelle qui produit 4 cellules haploïdes (gamètes) génétiquement différentes à partir d''une cellule diploïde.', 2, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Quelle est la discontinuité qui sépare la croûte du manteau terrestre ?',
'["Gutenberg","Lehmann","Moho (Mohorovičić)","Conrad"]'::jsonb, 2,
'La discontinuité de Mohorovičić (Moho) sépare la croûte terrestre du manteau. Gutenberg sépare le manteau du noyau externe, Lehmann le noyau externe du noyau interne.', 2, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Quel phénomène se produit aux dorsales océaniques ?',
'["La subduction d''une plaque sous une autre","La divergence des plaques et la formation de nouvelle croûte océanique","La collision de deux plaques continentales","La formation de montagnes"]'::jsonb, 1,
'Aux dorsales océaniques, les plaques divergent et du magma remonte, créant une nouvelle croûte océanique (accrétion océanique).', 2, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les trois types de roches dans le cycle des roches sont :',
'["Calcaire, granite et basalte","Magmatiques, sédimentaires et métamorphiques","Plutoniques, volcaniques et détritiques","Cristallines, amorphes et organiques"]'::jsonb, 1,
'Les trois grands types de roches sont : magmatiques (cristallisation du magma), sédimentaires (dépôt et diagenèse) et métamorphiques (transformation par pression/température).', 1, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le pH d''une solution acide est :',
'["Égal à 7","Supérieur à 7","Inférieur à 7","Toujours égal à 0"]'::jsonb, 2,
'Une solution acide a un pH inférieur à 7. Un pH = 7 est neutre, un pH > 7 est basique.', 1, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La méthode VSEPR permet de déterminer :',
'["La masse molaire d''une molécule","La géométrie tridimensionnelle d''une molécule","L''énergie d''ionisation d''un atome","Le nombre d''isotopes d''un élément"]'::jsonb, 1,
'La méthode VSEPR (Valence Shell Electron Pair Repulsion) permet de prédire la géométrie tridimensionnelle d''une molécule à partir de la répulsion des paires d''électrons.', 2, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les trois domaines du vivant sont :',
'["Animalia, Plantae, Fungi","Procaryotes, Eucaryotes, Virus","Bacteria, Archaea, Eukarya","Protista, Monera, Plantae"]'::jsonb, 2,
'La classification actuelle divise le vivant en trois domaines : Bacteria (bactéries), Archaea (archées) et Eukarya (eucaryotes).', 1, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La photosynthèse se déroule dans :',
'["Les mitochondries","Les chloroplastes","Le noyau","Le réticulum endoplasmique"]'::jsonb, 1,
'La photosynthèse se déroule dans les chloroplastes : phase claire dans les thylakoïdes et phase sombre (cycle de Calvin) dans le stroma.', 1, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Dans un écosystème, les décomposeurs :',
'["Produisent de la matière organique par photosynthèse","Consomment les producteurs primaires","Dégradent la matière organique morte en matière minérale","Se nourrissent exclusivement d''herbivores"]'::jsonb, 2,
'Les décomposeurs (bactéries, champignons) dégradent la matière organique morte et la transforment en matière minérale, bouclant les cycles biogéochimiques.', 1, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''équation de Michaelis-Menten décrit :',
'["La croissance d''une population","La cinétique enzymatique","L''équilibre chimique","La loi de gravitation"]'::jsonb, 1,
'L''équation de Michaelis-Menten (v = Vmax[S]/(Km+[S])) décrit la relation entre la vitesse de réaction enzymatique et la concentration en substrat.', 2, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le xylème transporte :',
'["La sève élaborée (matière organique)","La sève brute (eau et sels minéraux)","Les hormones végétales uniquement","Le CO2 atmosphérique"]'::jsonb, 1,
'Le xylème transporte la sève brute (eau et sels minéraux) des racines vers les feuilles. Le phloème transporte la sève élaborée (matière organique).', 2, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La liaison hydrogène est :',
'["Une liaison covalente très forte","Une interaction faible entre un atome d''hydrogène lié à un atome électronégatif et un autre atome électronégatif","Une liaison ionique impliquant l''hydrogène","Une liaison métallique"]'::jsonb, 1,
'La liaison hydrogène est une interaction faible entre un H lié à un atome très électronégatif (O, N, F) et un autre atome électronégatif porteur d''un doublet non liant.', 2, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La tectonique des plaques est principalement mise en mouvement par :',
'["La rotation de la Terre","La convection mantellique","Les marées océaniques","Le vent solaire"]'::jsonb, 1,
'Le moteur principal de la tectonique des plaques est la convection mantellique : le manteau chaud monte et le manteau refroidi descend, entraînant les plaques.', 2, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Dans la nomenclature binomiale de Linné, Homo sapiens désigne :',
'["Le genre puis l''espèce","La famille puis le genre","L''ordre puis la famille","L''espèce puis la sous-espèce"]'::jsonb, 0,
'La nomenclature binomiale utilise deux noms latins : le premier (majuscule) désigne le genre, le second (minuscule) désigne l''espèce. Ex : Homo (genre) sapiens (espèce).', 1, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les phases de la mitose dans l''ordre sont :',
'["Métaphase, prophase, télophase, anaphase","Prophase, métaphase, anaphase, télophase","Anaphase, prophase, métaphase, télophase","Télophase, anaphase, métaphase, prophase"]'::jsonb, 1,
'Les 4 phases de la mitose sont dans l''ordre : prophase (condensation des chromosomes), métaphase (alignement), anaphase (séparation), télophase (décondensation).', 1, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le cycle de Calvin se déroule :',
'["Dans les thylakoïdes des chloroplastes","Dans le stroma des chloroplastes","Dans la matrice des mitochondries","Dans le cytoplasme"]'::jsonb, 1,
'Le cycle de Calvin (phase sombre de la photosynthèse) se déroule dans le stroma des chloroplastes. Il fixe le CO2 pour produire des glucides.', 2, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''électronégativité est :',
'["La capacité d''un atome à perdre des électrons","La capacité d''un atome à attirer les électrons d''une liaison chimique","L''énergie nécessaire pour arracher un électron","Le nombre d''électrons de valence"]'::jsonb, 1,
'L''électronégativité (échelle de Pauling) mesure la capacité d''un atome engagé dans une liaison chimique à attirer les électrons de cette liaison.', 2, 'Sciences de la Vie et de la Terre', true, 'L1', 'SVT', 'S1', 'manual_injection');
