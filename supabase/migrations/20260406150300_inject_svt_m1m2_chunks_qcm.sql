-- Injection SVT M1-M2 — Sciences de la Vie et de la Terre — Chunks + QCM
-- Spécialités Master: Biologie moléculaire et cellulaire, Écologie, Neurosciences, Biotechnologies

DO $$
DECLARE v_doc_id UUID;
BEGIN
  INSERT INTO app.td_source_documents (
    subject, university, study_year, doc_type,
    storage_bucket, storage_path, original_filename, status, extracted_text
  ) VALUES (
    'Sciences de la Vie et de la Terre', NULL, 'M1', 'cours',
    'manual', 'manual/svt_m1m2_programme_complet.txt', 'Programme_SVT_M1_M2.txt', 'indexed',
    'Programme SVT Master — Biologie moléculaire et cellulaire avancée, génomique, protéomique, écologie avancée, neurosciences, biotechnologies, bio-informatique, biologie de la conservation.'
  ) RETURNING id INTO v_doc_id;

  INSERT INTO app.td_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject, university, study_year, token_count) VALUES

  (gen_random_uuid(), v_doc_id, 0,
$c$MASTER BIOLOGIE MOLÉCULAIRE ET CELLULAIRE — M1

Biologie cellulaire avancée : trafic vésiculaire (COPI, COPII, clathrine), voies de signalisation (Wnt, Notch, Hedgehog, TGF-bêta, JAK-STAT, MAPK/ERK, PI3K/Akt). Cycle cellulaire avancé : checkpoints (G1/S, G2/M), kinases dépendantes des cyclines (CDK), protéine Rb, p53 gardien du génome. Cancer : oncogènes, gènes suppresseurs de tumeurs, instabilité génomique, hallmarks du cancer (Hanahan et Weinberg).

Biologie moléculaire avancée : réplication de l'ADN eucaryote (origines de réplication, complexe pré-réplicatif), télomères et télomérase. Réparation de l'ADN : excision de bases (BER), excision de nucléotides (NER), recombinaison homologue, jonction d'extrémités non homologues (NHEJ). Recombinaison génétique.

Épigénomique : techniques ChIP-seq, ATAC-seq, bisulfite sequencing. Régulation par ARN non codants : miARN, lncARN, siARN. Interférence par ARN (RNAi).

Génomique et bioinformatique : séquençage de nouvelle génération (Illumina, PacBio, Nanopore), assemblage de génomes, annotation, génomique comparative. Transcriptomique (RNA-seq), protéomique (spectrométrie de masse), métabolomique. Bases de données (GenBank, UniProt, PDB). Analyse bioinformatique : alignement de séquences (BLAST), phylogénie moléculaire.$c$,
  '{"source":"programme","topic":"master_BMC","subtopic":"biologie_mol_cell_M1"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'M1', 270),

  (gen_random_uuid(), v_doc_id, 1,
$c$MASTER ÉCOLOGIE, BIODIVERSITÉ, ÉVOLUTION — M1

Écologie quantitative : modélisation écologique, dynamique des populations structurées (matrices de Leslie), modèles de métapopulations (Levins), théorie des perturbations intermédiaires. Analyses multivariées : ACP, AFC, classification hiérarchique. Modèles de distribution d'espèces (SDM, MaxEnt).

Biologie de la conservation : listes rouges UICN, analyses de viabilité des populations (PVA), génétique de la conservation (diversité génétique, consanguinité, effet fondateur). Corridors écologiques, aires protégées, restauration écologique. Contexte BF : parcs nationaux (W, Arly, Pendjari — complexe WAP), réserves de biosphère (Mare aux Hippopotames).

Biogéographie : théorie de la biogéographie insulaire (MacArthur et Wilson), biomes, provinces biogéographiques. Paléoécologie : reconstitution des paléoenvironnements (pollen, isotopes).

Écologie fonctionnelle : traits fonctionnels, compromis (trade-offs), stratégies CSR de Grime. Relations structure-fonction dans les communautés. Écologie chimique : allélochimiques, phéromones, interactions plantes-herbivores.

Changement global : changement climatique (modèles GIEC, scénarios RCP/SSP), impacts sur la biodiversité (déplacement d'aires, phénologie), services écosystémiques et évaluation économique. ODD (Objectifs de Développement Durable) liés à la biodiversité.$c$,
  '{"source":"programme","topic":"master_ecologie","subtopic":"ecologie_conservation_M1"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'M1', 270),

  (gen_random_uuid(), v_doc_id, 2,
$c$MASTER NEUROSCIENCES — M1

Neurobiologie moléculaire et cellulaire : canaux ioniques (voltage-dépendants, ligand-dépendants), récepteurs (ionotropes : AMPA, NMDA, GABA-A ; métabotropes : couplés aux protéines G). Plasticité synaptique : potentialisation à long terme (LTP), dépression à long terme (LTD). Base moléculaire de la mémoire et de l'apprentissage.

Neuroanatomie fonctionnelle : cortex cérébral (aires de Brodmann, lobes), système limbique (hippocampe, amygdale), ganglions de la base, cervelet, tronc cérébral. Voies sensorielles et motrices. Système nerveux autonome (sympathique, parasympathique).

Neurosciences cognitives : perception, attention, mémoire (de travail, épisodique, sémantique, procédurale), langage, fonctions exécutives. Techniques : IRMf, EEG, MEG, stimulation magnétique transcrânienne (TMS).

Neuropathologie : maladies neurodégénératives (Alzheimer : plaques amyloïdes, dégénérescences neurofibrillaires ; Parkinson : perte de neurones dopaminergiques de la substance noire), épilepsie, sclérose en plaques (démyélinisation), AVC, troubles psychiatriques (schizophrénie, dépression : hypothèses sérotoninergiques et dopaminergiques).$c$,
  '{"source":"programme","topic":"master_neurosciences","subtopic":"neurosciences_M1"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'M1', 260),

  (gen_random_uuid(), v_doc_id, 3,
$c$MASTER BIOTECHNOLOGIES ET BIO-INFORMATIQUE — M1/M2

Biotechnologies :
- Génie génétique avancé : vecteurs d'expression, systèmes de production recombinante (E. coli, levure, cellules d'insectes, cellules CHO). Protéines recombinantes thérapeutiques (insuline, anticorps monoclonaux, facteurs de croissance).
- Thérapie génique : vecteurs viraux (AAV, lentivirus), vecteurs non viraux, CRISPR thérapeutique, CAR-T cells. Essais cliniques.
- Biotechnologies végétales : OGM (plantes Bt, résistantes aux herbicides), culture in vitro, micropropagation, amélioration génétique assistée par marqueurs (MAS).
- Biotechnologies microbiennes : fermentation industrielle, production d'antibiotiques, enzymes industrielles, biocarburants, bioremédiation.

Bio-informatique :
- Programmation pour biologistes : Python, R (Bioconductor). Analyse de séquences : alignement (BLAST, ClustalW), annotation fonctionnelle (Gene Ontology).
- Génomique computationnelle : assemblage de novo, mapping, variant calling, analyse RNA-seq (DESeq2, EdgeR). Phylogénomique.
- Biologie structurale computationnelle : modélisation par homologie, docking moléculaire, dynamique moléculaire. Drug design assisté par ordinateur.
- Intelligence artificielle en biologie : machine learning pour la classification (forêts aléatoires, SVM), deep learning (AlphaFold pour la prédiction de structure protéique).$c$,
  '{"source":"programme","topic":"master_biotech","subtopic":"biotechnologies_bioinformatique"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'M1', 270),

  (gen_random_uuid(), v_doc_id, 4,
$c$SPÉCIALITÉS MASTER M2 — APPROFONDISSEMENT ET RECHERCHE

Biologie cellulaire, développement et cellules souches (M2) : cellules souches embryonnaires et adultes, cellules iPS (Yamanaka), différenciation dirigée, organoïdes, médecine régénérative. Éthique de la recherche sur les cellules souches.

Immunologie avancée (M2) : immunothérapie du cancer (checkpoint inhibitors : anti-PD-1, anti-CTLA-4), CAR-T cells, vaccins thérapeutiques. Immunologie des greffes. Tolérance immunitaire. Auto-immunité : mécanismes et traitements.

Génétique humaine et maladies génétiques (M2) : cartographie génétique, études d'association pangénomique (GWAS), diagnostic moléculaire, conseil génétique. Maladies monogéniques (drépanocytose, mucoviscidose, thalassémies) et polygéniques (diabète, HTA).

Écologie tropicale et gestion de la biodiversité (M2) : écosystèmes tropicaux (forêts, savanes, zones humides), gestion durable des ressources naturelles, agroécologie. Pertinent pour le BF : gestion des terroirs, lutte contre la désertification, adaptation au changement climatique au Sahel.

Microbiologie appliquée (M2) : microbiome et santé, résistance aux antimicrobiens (AMR), épidémiologie moléculaire, microbiologie alimentaire (HACCP), biotechnologies microbiennes pour l'agriculture et l'environnement.$c$,
  '{"source":"programme","topic":"master_M2","subtopic":"specialites_M2"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'M2', 260);

END;
$$;

-- ═══ QCM M1-M2 SVT (20 questions) ═══
INSERT INTO app.td_questions (id, question_type, content, options, correct_index, explanation, difficulty, subject, is_active, study_year, field, semester, generation_mode) VALUES

(gen_random_uuid(), 'mcq', 'Les « hallmarks » du cancer selon Hanahan et Weinberg incluent :',
'["Uniquement la prolifération incontrôlée","L''autosuffisance en signaux de croissance, l''insensibilité aux signaux anti-prolifératifs, l''évasion de l''apoptose, l''angiogenèse, l''invasion et la métastase","Uniquement les mutations de p53","La résistance aux antibiotiques"]'::jsonb, 1,
'Les hallmarks du cancer sont les caractéristiques fondamentales acquises par les cellules cancéreuses : prolifération, résistance à la mort, angiogenèse, invasion, immortalité réplicative, reprogrammation métabolique, évasion immunitaire.', 3, 'Sciences de la Vie et de la Terre', true, 'M1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La voie de signalisation MAPK/ERK est typiquement activée par :',
'["Des récepteurs nucléaires","Des récepteurs à activité tyrosine kinase (RTK) via Ras","Des canaux ioniques","Des récepteurs couplés aux protéines G exclusivement"]'::jsonb, 1,
'La voie MAPK/ERK : ligand (facteur de croissance) → RTK → adaptateur (Grb2/SOS) → Ras (GTPase) → Raf → MEK → ERK → facteurs de transcription (prolifération, différenciation).', 3, 'Sciences de la Vie et de la Terre', true, 'M1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le séquençage de nouvelle génération (NGS) Illumina repose sur :',
'["Le séquençage par terminaison de chaîne (méthode Sanger)","Le séquençage par synthèse avec des nucléotides fluorescents réversibles","Le séquençage par nanopores","L''électrophorèse capillaire"]'::jsonb, 1,
'Illumina utilise le séquençage par synthèse (SBS) : les nucléotides fluorescents sont incorporés un par un, photographiés, puis le terminateur réversible est clivé pour le cycle suivant.', 3, 'Sciences de la Vie et de la Terre', true, 'M1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La potentialisation à long terme (LTP) est :',
'["Une diminution durable de l''efficacité synaptique","Un renforcement durable de la transmission synaptique, base moléculaire de la mémoire","La mort des neurones par apoptose","La régénération des axones"]'::jsonb, 1,
'La LTP est un renforcement durable de la transmission synaptique après stimulation à haute fréquence. Elle implique les récepteurs NMDA, l''entrée de Ca2+, et l''insertion d''AMPA.', 3, 'Sciences de la Vie et de la Terre', true, 'M1', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La théorie de la biogéographie insulaire de MacArthur et Wilson prédit que :',
'["Les grandes îles proches du continent ont plus d''espèces que les petites îles éloignées","Toutes les îles ont le même nombre d''espèces","La richesse spécifique ne dépend que de la taille de l''île","La distance au continent n''a aucun effet"]'::jsonb, 0,
'MacArthur et Wilson : la richesse spécifique d''une île résulte d''un équilibre entre immigration (diminue avec la distance) et extinction (augmente quand la surface diminue).', 3, 'Sciences de la Vie et de la Terre', true, 'M1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les cellules iPS (induced Pluripotent Stem cells) sont obtenues par :',
'["Extraction d''embryons","Reprogrammation de cellules somatiques adultes par expression de facteurs de transcription (Oct4, Sox2, Klf4, c-Myc)","Fusion de gamètes in vitro","Clonage par transfert de noyau"]'::jsonb, 1,
'Yamanaka (2006, Nobel 2012) a montré que 4 facteurs de transcription (Oct4, Sox2, Klf4, c-Myc) suffisent à reprogrammer des cellules adultes en cellules pluripotentes (iPS).', 3, 'Sciences de la Vie et de la Terre', true, 'M2', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les anticorps monoclonaux thérapeutiques anti-PD-1 agissent en :',
'["Tuant directement les cellules cancéreuses","Bloquant un checkpoint immunitaire pour réactiver les lymphocytes T contre la tumeur","Empêchant l''angiogenèse tumorale","Induisant l''apoptose des cellules tumorales"]'::jsonb, 1,
'Les anti-PD-1 (pembrolizumab, nivolumab) bloquent l''interaction PD-1/PD-L1 qui inhibe les lymphocytes T, réactivant ainsi la réponse immunitaire anti-tumorale.', 3, 'Sciences de la Vie et de la Terre', true, 'M2', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'BLAST est un outil bio-informatique qui permet de :',
'["Séquencer de l''ADN","Rechercher des séquences similaires dans des bases de données biologiques","Visualiser des structures protéiques 3D","Assembler un génome"]'::jsonb, 1,
'BLAST (Basic Local Alignment Search Tool) compare une séquence requête (ADN ou protéine) aux séquences des bases de données pour trouver des homologies.', 2, 'Sciences de la Vie et de la Terre', true, 'M1', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'AlphaFold (DeepMind) est un programme d''intelligence artificielle qui :',
'["Séquence l''ADN","Prédit la structure tridimensionnelle des protéines à partir de leur séquence","Diagnostique des maladies","Analyse des images microscopiques"]'::jsonb, 1,
'AlphaFold utilise le deep learning pour prédire avec une précision remarquable la structure 3D des protéines à partir de leur seule séquence en acides aminés.', 2, 'Sciences de la Vie et de la Terre', true, 'M2', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La maladie d''Alzheimer est caractérisée au niveau neuropathologique par :',
'["La perte de neurones dopaminergiques","L''accumulation de plaques amyloïdes (peptide Abêta) et de dégénérescences neurofibrillaires (protéine tau hyperphosphorylée)","La démyélinisation des axones","Des crises d''épilepsie récurrentes"]'::jsonb, 1,
'Alzheimer : deux lésions caractéristiques — plaques séniles (dépôts extracellulaires de peptide Abêta) et dégénérescences neurofibrillaires (accumulation intracellulaire de protéine tau).', 3, 'Sciences de la Vie et de la Terre', true, 'M1', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La drépanocytose est causée par :',
'["Une délétion chromosomique","Une mutation ponctuelle dans le gène de la bêta-globine (Glu→Val en position 6)","Un excès de fer","Une infection virale"]'::jsonb, 1,
'La drépanocytose résulte d''une mutation faux-sens (GAG→GTG) remplaçant l''acide glutamique par la valine en position 6 de la bêta-globine → hémoglobine S → falciformation.', 2, 'Sciences de la Vie et de la Terre', true, 'M2', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le complexe WAP (W-Arly-Pendjari) au Burkina Faso est :',
'["Un centre de recherche universitaire","Un complexe transfrontalier d''aires protégées pour la conservation de la biodiversité","Une zone industrielle","Un réseau de barrages hydroélectriques"]'::jsonb, 1,
'Le complexe WAP est un ensemble transfrontalier d''aires protégées partagé entre le BF, le Niger et le Bénin, classé patrimoine mondial UNESCO, abritant éléphants, lions, guépards.', 2, 'Sciences de la Vie et de la Terre', true, 'M2', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les études GWAS (Genome-Wide Association Studies) servent à :',
'["Séquencer un génome entier","Identifier des variants génétiques associés à des maladies ou des traits dans de grandes populations","Cloner des gènes","Produire des protéines recombinantes"]'::jsonb, 1,
'Les GWAS comparent les fréquences de millions de SNPs entre cas et témoins pour identifier des loci génétiques associés à des maladies complexes ou des traits.', 3, 'Sciences de la Vie et de la Terre', true, 'M2', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La méthode HACCP en microbiologie alimentaire est :',
'["Un test de détection de bactéries","Un système de gestion de la sécurité alimentaire basé sur l''analyse des dangers et la maîtrise des points critiques","Un antibiotique alimentaire","Une technique de conservation"]'::jsonb, 1,
'HACCP (Hazard Analysis Critical Control Points) est une démarche systématique d''identification, d''évaluation et de maîtrise des dangers significatifs pour la sécurité alimentaire.', 2, 'Sciences de la Vie et de la Terre', true, 'M2', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les vecteurs AAV (Adeno-Associated Virus) sont utilisés en thérapie génique car :',
'["Ils sont très pathogènes","Ils sont non pathogènes, peu immunogènes et permettent une expression stable du transgène","Ils intègrent toujours leur ADN dans le génome hôte","Ils ne peuvent infecter que les bactéries"]'::jsonb, 1,
'Les AAV sont des vecteurs de choix en thérapie génique : non pathogènes, faiblement immunogènes, expression durable du transgène (surtout dans les cellules post-mitotiques).', 3, 'Sciences de la Vie et de la Terre', true, 'M2', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le modèle MaxEnt en écologie est utilisé pour :',
'["Calculer la diversité génétique","Modéliser la distribution potentielle d''une espèce à partir de données de présence et de variables environnementales","Mesurer la productivité d''un écosystème","Analyser des séquences ADN"]'::jsonb, 1,
'MaxEnt (Maximum Entropy) modélise la distribution géographique potentielle d''espèces en utilisant des points de présence et des variables bioclimatiques (température, précipitations).', 3, 'Sciences de la Vie et de la Terre', true, 'M1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''agroécologie vise à :',
'["Maximiser l''utilisation de pesticides chimiques","Concevoir des systèmes agricoles durables en s''inspirant des processus écologiques naturels","Remplacer toute l''agriculture par la cueillette","Éliminer toute forme d''élevage"]'::jsonb, 1,
'L''agroécologie applique les principes écologiques à l''agriculture : diversification des cultures, lutte biologique, recyclage des nutriments, réduction des intrants chimiques.', 2, 'Sciences de la Vie et de la Terre', true, 'M2', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La technique ChIP-seq permet d''étudier :',
'["La séquence d''un gène","Les interactions protéine-ADN à l''échelle du génome entier","La structure 3D des protéines","Le métabolisme cellulaire"]'::jsonb, 1,
'ChIP-seq (Chromatin Immunoprecipitation + sequencing) identifie les sites de liaison d''une protéine (facteur de transcription, histone modifiée) sur l''ensemble du génome.', 3, 'Sciences de la Vie et de la Terre', true, 'M1', 'SVT', 'S1', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les organoïdes sont :',
'["Des organismes génétiquement modifiés","Des structures tridimensionnelles dérivées de cellules souches qui reproduisent l''architecture et les fonctions d''un organe in vitro","Des organites cellulaires isolés","Des tissus prélevés par biopsie"]'::jsonb, 1,
'Les organoïdes sont des mini-organes cultivés in vitro à partir de cellules souches. Ils reproduisent la structure et la fonction d''un organe (intestin, cerveau, foie) pour la recherche et le screening de médicaments.', 3, 'Sciences de la Vie et de la Terre', true, 'M2', 'SVT', 'S2', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La bioremédiation utilise :',
'["Des robots pour nettoyer les sols","Des microorganismes pour dégrader ou transformer des polluants environnementaux","Des produits chimiques pour neutraliser la pollution","La radioactivité pour stériliser les sols"]'::jsonb, 1,
'La bioremédiation exploite les capacités métaboliques des microorganismes (bactéries, champignons) pour dégrader ou transformer des polluants (hydrocarbures, métaux lourds, pesticides).', 2, 'Sciences de la Vie et de la Terre', true, 'M2', 'SVT', 'S2', 'manual_injection');
