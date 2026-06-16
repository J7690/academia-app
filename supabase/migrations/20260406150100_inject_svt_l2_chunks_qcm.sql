-- Injection SVT L2 — Sciences de la Vie et de la Terre — Chunks + QCM
-- Génétique, Biochimie, Écologie, Physiologie, Microbiologie, Biologie cellulaire

DO $$
DECLARE v_doc_id UUID;
BEGIN
  INSERT INTO app.td_source_documents (
    subject, university, study_year, doc_type,
    storage_bucket, storage_path, original_filename, status, extracted_text
  ) VALUES (
    'Sciences de la Vie et de la Terre', NULL, 'L2', 'cours',
    'manual', 'manual/svt_l2_programme_complet.txt', 'Programme_SVT_L2.txt', 'indexed',
    'Programme complet SVT L2 — Génétique, biochimie, écologie et évolution, physiologie animale et végétale, microbiologie, biologie cellulaire approfondie, biostatistiques.'
  ) RETURNING id INTO v_doc_id;

  INSERT INTO app.td_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject, university, study_year, token_count) VALUES

  (gen_random_uuid(), v_doc_id, 0,
$c$GÉNÉTIQUE (L2 S3)

Génétique mendélienne : lois de Mendel (uniformité des hybrides F1, ségrégation des caractères en F2, indépendance des caractères). Monohybridisme et dihybridisme. Dominance complète, codominance, dominance incomplète. Allèles multiples (groupes sanguins ABO). Gènes liés et recombinaison génétique. Cartographie génétique.

Génétique moléculaire : structure de l'ADN (Watson et Crick, double hélice, complémentarité A-T, G-C). Réplication semi-conservative (Meselson-Stahl). Transcription (ARN polymérase, promoteur, terminateur). Code génétique (triplets, dégénérescence, universalité). Traduction (ribosomes, ARNt, initiation, élongation, terminaison).

Mutations : mutations ponctuelles (substitution, insertion, délétion), mutations chromosomiques (délétions, duplications, inversions, translocations), mutations génomiques (polyploïdie, aneuploïdie : trisomie 21). Agents mutagènes (UV, agents chimiques). Réparation de l'ADN.

Génétique des populations : fréquences alléliques, équilibre de Hardy-Weinberg, forces évolutives (mutation, sélection, dérive, migration).$c$,
  '{"source":"programme","topic":"genetique","subtopic":"genetique_L2"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L2', 250),

  (gen_random_uuid(), v_doc_id, 1,
$c$BIOCHIMIE 1 : MÉTABOLISME ET ENZYMOLOGIE (L2 S3)

Glucides : classification (oses, osides, polyosides). Glucose : structure, isomères (alpha/bêta). Amidon, glycogène, cellulose. Rôles : énergie, structure, reconnaissance cellulaire.

Lipides : acides gras (saturés, insaturés), triglycérides (réserve énergétique), phospholipides (membranes), stéroïdes (cholestérol, hormones stéroïdiennes).

Acides aminés et protéines : 20 acides aminés standards, liaison peptidique. Niveaux de structure : primaire (séquence), secondaire (hélice alpha, feuillet bêta), tertiaire (repliement 3D), quaternaire (assemblage de sous-unités). Dénaturation.

Enzymologie : enzymes = catalyseurs biologiques protéiques. Site actif, complexe enzyme-substrat. Cinétique de Michaelis-Menten : Vmax, Km. Inhibition compétitive, non compétitive, incompétitive. Régulation allostérique. Cofacteurs et coenzymes (NAD+, FAD, CoA).

Métabolisme énergétique : glycolyse (10 étapes, bilan : 2 ATP, 2 NADH, 2 pyruvates), cycle de Krebs (dans la matrice mitochondriale, production de CO2, NADH, FADH2), chaîne respiratoire (complexes I-IV, chimiosmose, ATP synthase). Bilan global : ~36-38 ATP par glucose. Fermentations : alcoolique (levures), lactique (muscles).$c$,
  '{"source":"programme","topic":"biochimie","subtopic":"metabolisme_enzymologie"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L2', 260),

  (gen_random_uuid(), v_doc_id, 2,
$c$ÉCOLOGIE ET ÉVOLUTION (L2 S3)

Écologie des populations : dynamique des populations, modèles de croissance (exponentiel, logistique), capacité de charge (K), stratégies r et K. Relations interspécifiques : compétition, prédation, parasitisme, mutualisme, commensalisme.

Écologie des communautés : diversité spécifique (indices de Shannon, Simpson). Successions écologiques (primaires, secondaires). Perturbations et résilience. Biomes terrestres : forêts tropicales, savanes, déserts, forêts tempérées, taïga, toundra. Biomes aquatiques : zones pélagique, benthique, littorale.

Évolution : théorie de l'évolution par sélection naturelle (Darwin). Preuves de l'évolution : fossiles, anatomie comparée (organes homologues/analogues), biogéographie, biologie moléculaire (horloge moléculaire). Spéciation : allopatrique, sympatrique, parapatrique. Mécanismes : sélection naturelle (directionnelle, stabilisante, diversifiante), dérive génétique, flux de gènes.

Phylogénie : arbres phylogénétiques, cladistique, synapomorphies. Classification phylogénétique du vivant. Grandes transitions évolutives : origine de la vie, cellule eucaryote (endosymbiose), pluricellularité, conquête du milieu terrestre.$c$,
  '{"source":"programme","topic":"ecologie","subtopic":"ecologie_evolution_L2"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L2', 260),

  (gen_random_uuid(), v_doc_id, 3,
$c$PHYSIOLOGIE ANIMALE ET NEUROSCIENCES (L2 S4)

Système nerveux : neurone (corps cellulaire, dendrites, axone, gaine de myéline). Potentiel de repos (-70 mV), potentiel d'action (dépolarisation, repolarisation, hyperpolarisation). Conduction saltatoire. Synapses chimiques : neurotransmetteurs (acétylcholine, dopamine, sérotonine, GABA, glutamate). Synapses excitatrices et inhibitrices.

Système cardiovasculaire : coeur (4 cavités), circulation systémique et pulmonaire. Cycle cardiaque (systole, diastole). Pression artérielle. Composition du sang (plasma, globules rouges, blancs, plaquettes). Hémostase.

Système respiratoire : ventilation pulmonaire, échanges gazeux alvéolaires, transport des gaz (O2 lié à l'hémoglobine, CO2 sous forme de bicarbonates). Courbe de dissociation de l'hémoglobine (effet Bohr).

Système digestif : digestion mécanique et chimique, enzymes digestives (amylase, pepsine, trypsine, lipase). Absorption intestinale (villosités, microvillosités). Système rénal : néphron, filtration glomérulaire, réabsorption tubulaire, sécrétion. Régulation de l'osmolarité et du pH.$c$,
  '{"source":"programme","topic":"physiologie","subtopic":"physiologie_animale_neurosciences"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L2', 260),

  (gen_random_uuid(), v_doc_id, 4,
$c$MICROBIOLOGIE ET BIOLOGIE DES ORGANISMES (L2 S3-S4)

Bactériologie : morphologie (cocci, bacilles, spirilles), structure (paroi : Gram+/Gram-, membrane, flagelles, pili, capsule). Croissance bactérienne : phases (latence, exponentielle, stationnaire, déclin). Temps de génération. Milieux de culture. Métabolisme bactérien : aérobies, anaérobies, anaérobies facultatifs.

Virologie : structure des virus (capside, acide nucléique ADN ou ARN, enveloppe). Cycles : lytique et lysogénique. Rétrovirus (VIH). Bactériophages. Prions.

Mycologie : champignons unicellulaires (levures) et filamenteux (moisissures). Mycélium, hyphe. Reproduction : sexuée et asexuée (spores). Symbioses : mycorhizes, lichens.

Parasitologie introductive : protozoaires parasites (Plasmodium : paludisme, Trypanosoma : maladie du sommeil). Helminthes (vers parasites). Cycles de vie parasitaires.

Biologie cellulaire approfondie : signalisation cellulaire (récepteurs membranaires, seconds messagers : AMPc, Ca2+, voies MAPK). Apoptose (mort cellulaire programmée). Cytosquelette et motilité cellulaire. Adhérence cellulaire (cadhérines, intégrines). Jonctions cellulaires (serrées, communicantes, desmosomes).$c$,
  '{"source":"programme","topic":"microbiologie","subtopic":"microbiologie_biologie_cellulaire"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L2', 260),

  (gen_random_uuid(), v_doc_id, 5,
$c$PHYSIOLOGIE VÉGÉTALE ET BIOSTATISTIQUES (L2 S4)

Physiologie végétale :
- Nutrition hydrominérale : absorption racinaire (poils absorbants), transport de l'eau (xylème, théorie de la tension-cohésion), transpiration foliaire (stomates).
- Nutrition carbonée : photosynthèse (bilan : 6CO2 + 6H2O → C6H12O6 + 6O2). Plantes C3 (cycle de Calvin seul), C4 (fixation préalable du CO2 par PEP carboxylase), CAM (fixation nocturne du CO2).
- Hormones végétales : auxines (élongation cellulaire, phototropisme), gibbérellines (germination, croissance des tiges), cytokinines (division cellulaire), éthylène (maturation des fruits), acide abscissique (dormance, fermeture des stomates).
- Développement : germination, croissance primaire et secondaire, floraison (photopériodisme), sénescence.

Biostatistiques :
- Statistiques descriptives : moyenne, médiane, mode, variance, écart-type, coefficient de variation.
- Tests d'hypothèse : test du chi-deux, test t de Student, ANOVA. Risque alpha, p-value.
- Régression et corrélation : régression linéaire, coefficient de corrélation de Pearson.
- Plans expérimentaux : variables indépendantes, dépendantes, contrôlées. Répétitions et randomisation.$c$,
  '{"source":"programme","topic":"physiologie_vegetale","subtopic":"physio_vegetale_biostats"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L2', 260);

END;
$$;

-- ═══ QCM L2 SVT (20 questions) ═══
INSERT INTO app.td_questions (id, question_type, content, options, correct_index, explanation, difficulty, subject, is_active, study_year, field, semester, generation_mode) VALUES

(gen_random_uuid(), 'mcq', 'Selon la première loi de Mendel, les hybrides F1 sont :',
'["Tous différents","Tous uniformes et expriment le caractère dominant","50% dominants et 50% récessifs","Tous récessifs"]'::jsonb, 1,
'La première loi de Mendel (loi d''uniformité) : tous les hybrides F1 issus du croisement de deux lignées pures sont uniformes et expriment le caractère dominant.', 1, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S3', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La réplication de l''ADN est dite semi-conservative car :',
'["Seule la moitié de l''ADN est répliquée","Chaque nouvelle molécule d''ADN contient un brin ancien et un brin nouvellement synthétisé","L''ADN est copié deux fois","La réplication ne conserve que les gènes essentiels"]'::jsonb, 1,
'La réplication semi-conservative (démontrée par Meselson et Stahl) produit deux molécules d''ADN, chacune contenant un brin parental et un brin néoformé.', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S3', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La trisomie 21 est un exemple de :',
'["Mutation ponctuelle","Mutation chromosomique","Mutation génomique (aneuploïdie)","Mutation par insertion"]'::jsonb, 2,
'La trisomie 21 est une aneuploïdie (mutation génomique) : présence de 3 copies du chromosome 21 au lieu de 2.', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S3', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le Km (constante de Michaelis) représente :',
'["La vitesse maximale de la réaction","La concentration en substrat pour laquelle la vitesse est égale à Vmax/2","Le nombre de molécules de substrat transformées par seconde","L''énergie d''activation de la réaction"]'::jsonb, 1,
'Le Km est la concentration en substrat pour laquelle la vitesse de réaction enzymatique est égale à la moitié de Vmax. C''est une mesure de l''affinité enzyme-substrat.', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S3', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le bilan net de la glycolyse (une molécule de glucose) est :',
'["36 ATP","2 ATP, 2 NADH, 2 pyruvates","4 ATP, 4 NADH","2 ATP, 2 FADH2"]'::jsonb, 1,
'La glycolyse produit 4 ATP mais en consomme 2, donc le bilan net est 2 ATP + 2 NADH + 2 pyruvates.', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S3', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La fermentation alcoolique produit :',
'["Acide lactique et CO2","Éthanol et CO2","Acide acétique et H2O","Méthanol et O2"]'::jsonb, 1,
'La fermentation alcoolique (levures) transforme le pyruvate en éthanol + CO2, régénérant le NAD+ nécessaire à la glycolyse.', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S3', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La capacité de charge (K) d''un écosystème représente :',
'["Le nombre maximal d''espèces","L''effectif maximal d''une population que l''environnement peut supporter durablement","La vitesse de croissance maximale","La surface totale de l''écosystème"]'::jsonb, 1,
'K est l''effectif maximal d''une population qu''un environnement peut supporter de façon durable, compte tenu des ressources disponibles.', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S3', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''endosymbiose explique l''origine de :',
'["Le noyau cellulaire","Les mitochondries et les chloroplastes","La paroi cellulaire","Les ribosomes"]'::jsonb, 1,
'La théorie endosymbiotique (Lynn Margulis) explique l''origine des mitochondries (bactérie aérobie) et des chloroplastes (cyanobactérie) par ingestion puis symbiose.', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S3', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le potentiel de repos d''un neurone est d''environ :',
'["+40 mV","-70 mV","0 mV","-120 mV"]'::jsonb, 1,
'Le potentiel de repos d''un neurone est d''environ -70 mV, maintenu par la pompe Na+/K+ ATPase (3 Na+ sortent, 2 K+ entrent).', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S4', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''effet Bohr décrit :',
'["L''augmentation de l''affinité de l''hémoglobine pour l''O2 en milieu acide","La diminution de l''affinité de l''hémoglobine pour l''O2 quand le pH diminue ou le CO2 augmente","La production d''ATP par les globules rouges","Le transport du CO2 sous forme dissoute"]'::jsonb, 1,
'L''effet Bohr : quand le pH diminue ou que la pCO2 augmente (tissus actifs), l''affinité de l''hémoglobine pour l''O2 diminue, favorisant la libération d''O2.', 3, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S4', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les bactéries Gram-positives se distinguent des Gram-négatives par :',
'["L''absence de paroi","Une paroi épaisse de peptidoglycane sans membrane externe","Une membrane externe et une couche mince de peptidoglycane","La présence de chloroplastes"]'::jsonb, 1,
'Les Gram+ ont une paroi épaisse de peptidoglycane (retient le cristal violet). Les Gram- ont une paroi mince de peptidoglycane + une membrane externe (lipopolysaccharides).', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S3', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le cycle lysogénique d''un virus se caractérise par :',
'["La destruction immédiate de la cellule hôte","L''intégration du génome viral dans le chromosome de l''hôte","La production massive de virions","L''absence totale de reproduction virale"]'::jsonb, 1,
'Dans le cycle lysogénique, le génome viral s''intègre dans le chromosome de l''hôte (prophage) et se réplique avec lui. La cellule n''est pas immédiatement lysée.', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S4', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les stomates permettent :',
'["L''absorption de l''eau par les racines","Les échanges gazeux (CO2/O2) et la transpiration au niveau des feuilles","Le transport de la sève élaborée","La fixation de l''azote atmosphérique"]'::jsonb, 1,
'Les stomates sont des pores sur l''épiderme des feuilles permettant les échanges gazeux (entrée CO2, sortie O2 et H2O par transpiration).', 1, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S4', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les plantes C4 se distinguent des plantes C3 par :',
'["L''absence de photosynthèse","Une fixation préalable du CO2 par la PEP carboxylase avant le cycle de Calvin","L''absence de chloroplastes","Une photosynthèse uniquement nocturne"]'::jsonb, 1,
'Les plantes C4 fixent d''abord le CO2 en acide oxaloacétique (4C) via la PEP carboxylase dans les cellules du mésophylle, puis le transfèrent aux cellules de la gaine pour le cycle de Calvin.', 3, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S4', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le test du chi-deux permet de :',
'["Calculer la moyenne d''un échantillon","Tester la conformité entre des résultats observés et des résultats théoriques attendus","Mesurer la corrélation entre deux variables","Calculer la variance"]'::jsonb, 1,
'Le test du chi-deux compare des effectifs observés à des effectifs théoriques pour déterminer si l''écart est statistiquement significatif.', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S4', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''auxine est une hormone végétale qui :',
'["Inhibe la croissance","Favorise l''élongation cellulaire et le phototropisme","Provoque la maturation des fruits","Induit la dormance"]'::jsonb, 1,
'L''auxine (AIA) favorise l''élongation cellulaire. Elle est impliquée dans le phototropisme : redistribution latérale de l''auxine vers le côté ombragé.', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S4', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La spéciation allopatrique implique :',
'["Une sélection sexuelle au sein d''une même population","Une séparation géographique des populations","Une mutation instantanée créant une nouvelle espèce","Un croisement entre deux espèces différentes"]'::jsonb, 1,
'La spéciation allopatrique se produit quand une barrière géographique sépare une population en deux, permettant une divergence génétique indépendante.', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S3', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le code génétique est dit dégénéré car :',
'["Il contient des erreurs","Plusieurs codons peuvent coder le même acide aminé","Chaque codon code plusieurs acides aminés","Il n''est pas universel"]'::jsonb, 1,
'Le code génétique est dégénéré (redondant) : il y a 64 codons pour seulement 20 acides aminés, donc plusieurs codons codent le même acide aminé.', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S3', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les mycorhizes sont des associations symbiotiques entre :',
'["Deux espèces de champignons","Des champignons et des racines de plantes","Des bactéries et des algues","Des virus et des bactéries"]'::jsonb, 1,
'Les mycorhizes sont des symbioses entre champignons et racines de plantes : le champignon fournit eau et minéraux, la plante fournit des glucides issus de la photosynthèse.', 2, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S4', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''AMPc est un exemple de :',
'["Neurotransmetteur","Second messager intracellulaire","Hormone stéroïdienne","Enzyme digestive"]'::jsonb, 1,
'L''AMPc (AMP cyclique) est un second messager intracellulaire produit par l''adénylate cyclase. Il active la protéine kinase A et amplifie le signal extracellulaire.', 3, 'Sciences de la Vie et de la Terre', true, 'L2', 'SVT', 'S4', 'manual_injection');
