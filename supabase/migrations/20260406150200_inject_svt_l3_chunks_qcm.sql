-- Injection SVT L3 — Sciences de la Vie et de la Terre — Chunks + QCM
-- Biologie moléculaire, Immunologie, Développement, Biodiversité, Écologie avancée

DO $$
DECLARE v_doc_id UUID;
BEGIN
  INSERT INTO app.td_source_documents (
    subject, university, study_year, doc_type,
    storage_bucket, storage_path, original_filename, status, extracted_text
  ) VALUES (
    'Sciences de la Vie et de la Terre', NULL, 'L3', 'cours',
    'manual', 'manual/svt_l3_programme_complet.txt', 'Programme_SVT_L3.txt', 'indexed',
    'Programme SVT L3 — Biologie moléculaire et génétique fonctionnelle, immunologie, biologie du développement, biodiversité animale et végétale, écologie des communautés et écosystèmes, biochimie avancée.'
  ) RETURNING id INTO v_doc_id;

  INSERT INTO app.td_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject, university, study_year, token_count) VALUES

  (gen_random_uuid(), v_doc_id, 0,
$c$BIOLOGIE MOLÉCULAIRE ET GÉNÉTIQUE FONCTIONNELLE (L3 S5)

Régulation de l'expression génique chez les procaryotes : opéron lactose (modèle Jacob et Monod), régulation positive (CAP-AMPc) et négative (répresseur lac). Opéron tryptophane et atténuation.

Régulation chez les eucaryotes : niveaux multiples — chromatine (euchromatine/hétérochromatine, modifications des histones : acétylation, méthylation), transcription (facteurs de transcription, enhancers, silencers, promoteurs), post-transcription (épissage alternatif, stabilité des ARNm, micro-ARN), traduction, post-traduction (phosphorylation, ubiquitination).

Épigénétique : méthylation de l'ADN (îlots CpG), empreinte génomique, inactivation du chromosome X. Héritabilité des marques épigénétiques.

Techniques de biologie moléculaire : PCR (amplification), électrophorèse, Southern/Northern/Western blot, séquençage (Sanger, NGS), clonage moléculaire, enzymes de restriction, vecteurs (plasmides, phages). Génie génétique : OGM, CRISPR-Cas9 (édition génomique). Génomique, transcriptomique, protéomique.$c$,
  '{"source":"programme","topic":"biologie_moleculaire","subtopic":"biologie_moleculaire_L3"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L3', 250),

  (gen_random_uuid(), v_doc_id, 1,
$c$IMMUNOLOGIE (L3 S6)

Immunité innée : barrières physiques (peau, muqueuses), cellules (macrophages, neutrophiles, cellules NK, cellules dendritiques), réponse inflammatoire (vasodilatation, recrutement cellulaire), protéines du complément (voie classique, alternative, des lectines). Reconnaissance par les PRR (TLR) des PAMPs microbiens.

Immunité adaptative : spécificité et mémoire. Lymphocytes B : production d'anticorps (immunoglobulines : IgG, IgM, IgA, IgE, IgD), sélection clonale, plasmocytes, cellules mémoire. Structure des anticorps : chaînes lourdes et légères, régions variables et constantes, site de liaison à l'antigène.

Lymphocytes T : maturation thymique, sélection positive et négative. LT CD4+ (helpers : Th1, Th2, Th17, Treg) et LT CD8+ (cytotoxiques). Complexe majeur d'histocompatibilité : CMH I (toutes les cellules nucléées) et CMH II (cellules présentatrices d'antigènes). Présentation de l'antigène.

Vaccination : principe (mémoire immunitaire), types de vaccins (vivants atténués, inactivés, sous-unitaires, ARNm). Immunopathologie : hypersensibilités (types I à IV), auto-immunité, immunodéficiences (VIH/SIDA). Greffe et rejet.$c$,
  '{"source":"programme","topic":"immunologie","subtopic":"immunologie_L3"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L3', 260),

  (gen_random_uuid(), v_doc_id, 2,
$c$BIOLOGIE DU DÉVELOPPEMENT ANIMAL ET VÉGÉTAL (L3 S5)

Développement animal :
- Gamétogenèse : spermatogenèse et ovogenèse. Fécondation : reconnaissance, fusion, activation de l'oeuf, blocage de la polyspermie.
- Segmentation : holoblastique (totale : oursin, amphibien), méroblastique (partielle : oiseau, poisson). Morula, blastula.
- Gastrulation : mise en place des 3 feuillets embryonnaires (ectoderme, mésoderme, endoderme). Mouvements morphogénétiques. Organogenèse : neurulation (tube neural), somites.
- Gènes du développement : gènes homéotiques (Hox), gradients morphogénétiques, induction embryonnaire (organisateur de Spemann). Modèle Drosophile : gènes maternels, gap, pair-rule, segment polarity.

Développement végétal :
- Embryogenèse végétale : de la graine à la plantule. Méristèmes apicaux (caulinaire et racinaire).
- Organogenèse florale : modèle ABC de la détermination des pièces florales. Gènes MADS-box.
- Totipotence cellulaire végétale : culture in vitro, callogenèse, embryogenèse somatique.$c$,
  '{"source":"programme","topic":"developpement","subtopic":"biologie_developpement_L3"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L3', 250),

  (gen_random_uuid(), v_doc_id, 3,
$c$BIODIVERSITÉ ANIMALE, VÉGÉTALE ET ÉCOLOGIE AVANCÉE (L3 S5-S6)

Biodiversité animale et adaptation :
- Invertébrés : éponges, cnidaires (coraux, méduses), plathelminthes, nématodes, annélides, mollusques (gastéropodes, bivalves, céphalopodes), arthropodes (insectes, crustacés, arachnides), échinodermes.
- Vertébrés : agnathes, chondrichtyens (requins), ostéichtyens (poissons osseux), amphibiens, reptiles, oiseaux, mammifères. Adaptations : locomotion, thermorégulation, reproduction.

Biodiversité végétale :
- Algues : chlorophytes, rhodophytes, phéophytes. Transition vers le milieu terrestre.
- Bryophytes (mousses), ptéridophytes (fougères), gymnospermes (conifères), angiospermes (monocotylédones, dicotylédones). Coévolution plantes-pollinisateurs.

Écologie avancée :
- Écologie des communautés : indices de diversité, relations interspécifiques, succession écologique.
- Écologie des écosystèmes : flux d'énergie, productivité primaire, cycles biogéochimiques (C, N, P, S).
- Biologie de la conservation : espèces menacées, fragmentation des habitats, corridors écologiques, services écosystémiques. Convention sur la diversité biologique (CDB). Cas du BF : aires protégées, faune du Sahel.$c$,
  '{"source":"programme","topic":"biodiversite","subtopic":"biodiversite_ecologie_L3"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L3', 260),

  (gen_random_uuid(), v_doc_id, 4,
$c$BIOCHIMIE AVANCÉE ET MICROBIOLOGIE (L3 S6)

Biochimie 2 :
- Métabolisme des acides aminés : transamination, désamination oxydative, cycle de l'urée. Acides aminés glucoformateurs et cétogènes.
- Métabolisme des lipides : bêta-oxydation des acides gras, biosynthèse des acides gras (acide gras synthase), corps cétoniques. Biosynthèse du cholestérol (voie du mévalonate).
- Intégration du métabolisme : régulation hormonale (insuline, glucagon, adrénaline), état nourri vs état de jeûne. Métabolisme hépatique, musculaire, cérébral.
- Biochimie structurale avancée : techniques de purification des protéines (chromatographie, électrophorèse SDS-PAGE), détermination de structure (cristallographie, RMN, cryo-EM).

Microbiologie avancée :
- Génétique bactérienne : transformation, transduction, conjugaison. Éléments génétiques mobiles (transposons, plasmides).
- Antibiotiques : mécanismes d'action (paroi, membrane, synthèse protéique, acides nucléiques), résistance (bêta-lactamases, pompes d'efflux, modification de cible).
- Microbiome : microbiote intestinal humain, rôle dans la santé et la maladie. Applications biotechnologiques des microorganismes.$c$,
  '{"source":"programme","topic":"biochimie","subtopic":"biochimie_microbiologie_L3"}'::jsonb, 'content', 'Sciences de la Vie et de la Terre', NULL, 'L3', 260);

END;
$$;

-- ═══ QCM L3 SVT (20 questions) ═══
INSERT INTO app.td_questions (id, question_type, content, options, correct_index, explanation, difficulty, subject, is_active, study_year, field, semester, generation_mode) VALUES

(gen_random_uuid(), 'mcq', 'L''opéron lactose chez E. coli est un exemple de :',
'["Régulation post-traductionnelle","Régulation de l''expression génique au niveau transcriptionnel chez les procaryotes","Régulation épigénétique","Régulation par micro-ARN"]'::jsonb, 1,
'L''opéron lac (Jacob et Monod) est le modèle classique de régulation transcriptionnelle chez les procaryotes : le répresseur lac bloque la transcription en l''absence de lactose.', 2, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S5', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'CRISPR-Cas9 est un outil d''édition génomique qui fonctionne en :',
'["Ajoutant des chromosomes supplémentaires","Coupant l''ADN à un site spécifique guidé par un ARN guide, permettant des modifications ciblées","Empêchant la transcription de tous les gènes","Méthylant l''ensemble du génome"]'::jsonb, 1,
'CRISPR-Cas9 utilise un ARN guide complémentaire de la séquence cible pour diriger la nucléase Cas9 qui coupe l''ADN double brin. La réparation cellulaire permet insertion, délétion ou correction.', 3, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S5', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les cellules présentatrices d''antigènes expriment :',
'["Le CMH I uniquement","Le CMH II uniquement","Le CMH I et le CMH II","Ni CMH I ni CMH II"]'::jsonb, 2,
'Les CPA (cellules dendritiques, macrophages, lymphocytes B) expriment à la fois le CMH I (toutes les cellules nucléées) et le CMH II (spécifique aux CPA) pour présenter les antigènes aux lymphocytes T.', 3, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S6', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les anticorps de type IgE sont principalement impliqués dans :',
'["La réponse immunitaire primaire","Les réactions d''hypersensibilité de type I (allergies) et la défense antiparasitaire","La protection des muqueuses","L''activation du complément"]'::jsonb, 1,
'Les IgE se fixent sur les mastocytes et basophiles. Lors d''un second contact avec l''allergène, la dégranulation libère l''histamine → réaction allergique (hypersensibilité type I).', 3, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S6', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les trois feuillets embryonnaires mis en place lors de la gastrulation sont :',
'["Mésoderme, périderme, endocarpe","Ectoderme, mésoderme, endoderme","Épiderme, derme, hypoderme","Cortex, moelle, périoste"]'::jsonb, 1,
'La gastrulation met en place les 3 feuillets : ectoderme (peau, système nerveux), mésoderme (muscles, squelette, appareil urogénital), endoderme (tube digestif, poumons).', 2, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S5', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les gènes Hox contrôlent :',
'["La photosynthèse","L''identité des segments le long de l''axe antéro-postérieur de l''embryon","La division cellulaire","La respiration cellulaire"]'::jsonb, 1,
'Les gènes Hox (homéotiques) sont des facteurs de transcription qui spécifient l''identité des segments le long de l''axe antéro-postérieur. Ils sont très conservés chez les animaux.', 3, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S5', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le modèle ABC de la détermination florale explique :',
'["La photosynthèse dans les pétales","Comment les combinaisons de gènes A, B et C déterminent l''identité des pièces florales","La pollinisation par les insectes","La germination des graines"]'::jsonb, 1,
'Modèle ABC : gènes A seuls → sépales ; A+B → pétales ; B+C → étamines ; C seuls → carpelles. Ces gènes MADS-box régulent l''identité des organes floraux.', 3, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S5', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La bêta-oxydation des acides gras se déroule dans :',
'["Le cytoplasme","La matrice mitochondriale","Le réticulum endoplasmique","Le noyau"]'::jsonb, 1,
'La bêta-oxydation se déroule dans la matrice mitochondriale. Chaque tour de cycle raccourcit l''acide gras de 2 carbones et produit 1 acétyl-CoA, 1 NADH et 1 FADH2.', 2, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S6', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La résistance bactérienne aux antibiotiques peut se propager par :',
'["Mitose uniquement","Conjugaison, transformation et transduction","Méiose et fécondation","Photosynthèse"]'::jsonb, 1,
'Les gènes de résistance (souvent sur des plasmides) se transmettent entre bactéries par conjugaison (pili), transformation (ADN libre) et transduction (bactériophages).', 2, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S6', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''épissage alternatif permet :',
'["De corriger les mutations de l''ADN","De produire plusieurs protéines différentes à partir d''un seul gène","D''amplifier l''ADN","De méthyler les histones"]'::jsonb, 1,
'L''épissage alternatif permet de combiner différemment les exons d''un même pré-ARNm, produisant plusieurs ARNm matures et donc plusieurs protéines à partir d''un seul gène.', 3, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S5', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La sélection clonale des lymphocytes B implique que :',
'["Tous les lymphocytes B produisent le même anticorps","Seuls les lymphocytes B dont le récepteur reconnaît l''antigène sont activés et prolifèrent","Les lymphocytes B sont produits uniquement après l''infection","La sélection se fait dans le thymus"]'::jsonb, 1,
'Sélection clonale : l''antigène sélectionne le lymphocyte B spécifique, qui prolifère (expansion clonale) et se différencie en plasmocytes (anticorps) et cellules mémoire.', 3, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S6', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La productivité primaire nette d''un écosystème correspond à :',
'["La quantité totale d''énergie fixée par les producteurs","La quantité d''énergie fixée par les producteurs moins leur respiration","L''énergie disponible pour les décomposeurs uniquement","La biomasse totale de l''écosystème"]'::jsonb, 1,
'PPN = PPB - Respiration des producteurs. C''est la quantité de matière organique effectivement disponible pour les niveaux trophiques supérieurs.', 2, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S6', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Le cycle de l''urée permet de :',
'["Synthétiser des acides aminés","Éliminer l''excès d''azote sous forme d''urée","Dégrader le glucose","Synthétiser du cholestérol"]'::jsonb, 1,
'Le cycle de l''urée (foie) convertit l''ammoniac toxique issu du catabolisme des acides aminés en urée, excrétée par les reins.', 2, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S6', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La méthylation de l''ADN au niveau des îlots CpG entraîne généralement :',
'["L''activation de la transcription","La répression de la transcription","La réplication de l''ADN","La traduction des protéines"]'::jsonb, 1,
'La méthylation des cytosines dans les îlots CpG est une marque épigénétique qui recrute des protéines répressives et condense la chromatine → répression transcriptionnelle.', 3, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S5', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''organisateur de Spemann est une structure embryonnaire qui :',
'["Produit les gamètes","Induit la formation du tube neural par signalisation","Forme les os du squelette","Régule la division cellulaire"]'::jsonb, 1,
'L''organisateur de Spemann (lèvre dorsale du blastopore chez les amphibiens) sécrète des molécules qui induisent la neurulation dans l''ectoderme sus-jacent.', 3, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S5', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Quelle technique permet d''amplifier un fragment spécifique d''ADN in vitro ?',
'["Western blot","Électrophorèse","PCR (Polymerase Chain Reaction)","Chromatographie"]'::jsonb, 2,
'La PCR utilise une ADN polymérase thermostable (Taq), des amorces spécifiques et des cycles de dénaturation/hybridation/élongation pour amplifier exponentiellement un fragment d''ADN.', 1, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S5', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les services écosystémiques incluent :',
'["Uniquement la production alimentaire","La pollinisation, la purification de l''eau, la régulation du climat et le recyclage des nutriments","Uniquement les ressources minérales","Seulement les loisirs et le tourisme"]'::jsonb, 1,
'Les services écosystémiques comprennent les services d''approvisionnement (nourriture), de régulation (climat, eau, pollinisation), de support (cycles biogéochimiques) et culturels (loisirs).', 2, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S6', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'L''insuline favorise :',
'["La glycogénolyse et la lipolyse","La glycogenèse et la lipogenèse (stockage)","La néoglucogenèse","La cétogenèse"]'::jsonb, 1,
'L''insuline (état nourri) favorise le stockage : glycogenèse (synthèse de glycogène), lipogenèse (synthèse de triglycérides), absorption du glucose par les cellules.', 2, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S6', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'La polyspermie est empêchée lors de la fécondation par :',
'["La petite taille de l''ovocyte","La réaction corticale et la dépolarisation de la membrane","L''absence de récepteurs spermatiques","La destruction des spermatozoïdes surnuméraires par les globules blancs"]'::jsonb, 1,
'Le blocage de la polyspermie implique : un blocage rapide (dépolarisation membranaire) et un blocage lent (réaction corticale : exocytose des granules corticaux modifiant la zone pellucide).', 3, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S5', 'manual_injection'),

(gen_random_uuid(), 'mcq', 'Les arthropodes constituent le groupe animal le plus diversifié. Ils comprennent :',
'["Uniquement les insectes","Les insectes, crustacés, arachnides et myriapodes","Les mollusques et les échinodermes","Les annélides et les nématodes"]'::jsonb, 1,
'Les arthropodes (exosquelette chitineux, corps segmenté, appendices articulés) incluent : insectes, crustacés, arachnides (araignées, scorpions) et myriapodes (mille-pattes).', 1, 'Sciences de la Vie et de la Terre', true, 'L3', 'SVT', 'S5', 'manual_injection');
