-- Injection cours Droit Pénal Général L2 S3 — Partie 1/2 (Chunks 0-19)
-- Matière: Droit Pénal Général | Niveau: L2 | Semestre: S3 | Tronc commun
-- Préparé par M. Boukary WILLY

DO $$
DECLARE v_doc_id UUID;
BEGIN
  INSERT INTO app.td_source_documents (
    subject, university, study_year, doc_type,
    storage_bucket, storage_path, original_filename,
    status, extracted_text
  ) VALUES (
    'Droit Pénal Général', NULL, 'L2', 'cours',
    'manual', 'manual/dpg_l2_s3_cours_complet.txt', 'Cours_DPG_L2_S3_BF_Willy.txt',
    'indexed',
    'Cours complet de Droit Pénal Général Licence 2 Semestre 3 — Introduction, classification des infractions, éléments constitutifs, responsabilité pénale, faits justificatifs, causes de non imputabilité, agent pénal, complicité, peines et mesures de sûreté.'
  )
  RETURNING id INTO v_doc_id;

  INSERT INTO app.td_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject, university, study_year, token_count) VALUES

  -- Chunk 0: Introduction — Définition du droit pénal
  (gen_random_uuid(), v_doc_id, 0,
$c$DROIT PÉNAL GÉNÉRAL — INTRODUCTION ET DÉFINITION

Le droit pénal ou droit criminel s'entend de l'ensemble des règles juridiques assorties d'une peine. Dans son acception la plus large, le droit pénal désigne la branche du droit positif ayant pour objet l'étude et la répression par l'État des comportements de nature à créer un trouble intolérable pour l'ordre public. Le droit pénal a vocation à incriminer et à sanctionner les comportements contraires aux valeurs cardinales et essentielles de la société.

Pourquoi le droit pénal ? Parce que le phénomène criminel est une réalité sociale et individuelle. Les règles juridiques ne sont jamais intégralement respectées. Il apparaît nécessaire que la société édicte des normes dotées de sanctions particulièrement énergiques destinées à recadrer ceux qui troublent gravement l'ordre public et à dissuader ceux qui seraient tentés par l'aventure criminelle.

Source principale au BF : Loi n° 025-2018/AN du 31 mai 2018 portant code pénal.$c$,
  '{"source":"cours","topic":"introduction","subtopic":"definition_droit_penal"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 220),

  -- Chunk 1: Évolution du droit pénal burkinabè
  (gen_random_uuid(), v_doc_id, 1,
$c$ÉVOLUTION DU DROIT PÉNAL BURKINABÈ

Trois grandes étapes en prenant la colonisation comme repère :

1. Période précoloniale : droit pénal fondé sur la coutume, guidé par les croyances populaires et les réalités socioculturelles. Système oral où le chef de famille, de clan, de village ou le roi faisait office de juge. Sanctions allant des corvées au châtiment divin.

2. Période coloniale : dualité juridique — régime pénal des indigènes et régime des citoyens français. Décret du 22 avril 1946 : unification du droit pénal et des juridictions répressives en Afrique, rendant applicables le code pénal et le code d'instruction criminelle français.

3. Période postcoloniale : le Code pénal burkinabè de 2018 (comme celui de 1996 qu'il remplace) reste largement inspiré du droit français. Toutefois, adaptation aux réalités burkinabè : pénalisation du mariage forcé, des mutilations génitales féminines et de l'accusation de sorcellerie.$c$,
  '{"source":"cours","topic":"introduction","subtopic":"evolution_droit_penal_bf"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 210),

  -- Chunk 2: Caractéristiques du droit pénal
  (gen_random_uuid(), v_doc_id, 2,
$c$CARACTÉRISTIQUES DU DROIT PÉNAL

1. Branche du droit positif : règles écrites auxquelles l'autorité publique attache des sanctions particulièrement énergiques (les peines). Se distingue de la morale.

2. Droit « sanctionnateur » : intervient au second degré pour ériger en infraction les manquements particulièrement graves aux règles des autres branches du droit (civil, commercial, administratif...).

3. Répression par l'État : l'État a le monopole de la répression. Le droit pénal n'est ni purement public ni purement privé : l'infraction porte atteinte à l'ordre social (droit public) mais cause aussi un préjudice individuel (droit privé). Le contentieux pénal relève des juridictions judiciaires. Le droit pénal revendique une certaine autonomie par rapport à la summa divisio.

4. Pluridisciplinarité : le droit pénal comprend le droit pénal général, le droit pénal spécial et la procédure pénale. Sciences auxiliaires : pénologie, criminologie, criminalistique.$c$,
  '{"source":"cours","topic":"introduction","subtopic":"caracteristiques_droit_penal"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 210),

  -- Chunk 3: Contenu et objet du DPG
  (gen_random_uuid(), v_doc_id, 3,
$c$CONTENU ET OBJET DU DROIT PÉNAL GÉNÉRAL

Le droit pénal comprend : le droit pénal général (étude de l'infraction, conditions générales de la responsabilité pénale et peines applicables), le droit pénal spécial (examen détaillé de chaque infraction) et la procédure pénale (mise en oeuvre du droit pénal).

Objet du DPG — double déclinaison :
- Première partie : étude de l'infraction (atteinte à la loi pénale) et des conditions générales de la responsabilité pénale. L'infraction suppose l'inobservation d'une prescription de la loi répressive et engage en principe la responsabilité de son auteur.
- Deuxième partie : étude du délinquant (auteur, co-auteur, complice) et de la réaction sociale (peine ou mesure pénale).

L'infraction se distingue du délit civil (art. 1382 CC — tout fait causant un dommage) et du délit disciplinaire (spécifique à une profession, sanctionné par les instances disciplinaires).$c$,
  '{"source":"cours","topic":"introduction","subtopic":"contenu_objet_dpg"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 210),

  -- Chunk 4: Classification tripartite
  (gen_random_uuid(), v_doc_id, 4,
$c$CLASSIFICATION TRIPARTITE DES INFRACTIONS (ART. 121-1 CP)

La gravité de l'infraction, mesurée par le quantum de la peine, sert de critère de classification.

1. Crimes (art. 121-1 al. 1) : infractions punies d'emprisonnement à vie ou supérieur à 10 ans. Exemples : meurtre, assassinat, empoisonnement.

2. Délits (art. 121-1 al. 2) : infractions punies d'emprisonnement de 30 jours à 10 ans et/ou d'amende supérieure à 200 000 FCFA. Exemples : vol, homicides involontaires, diffamation, injure, adultère.

3. Contraventions (art. 121-1 al. 3) : infractions de moindre gravité punies d'amende n'excédant pas 200 000 FCFA. Réparties en 4 classes par le Décret 97-84 du 28/02/1997 :
- 1re classe : 1 000 à 5 000 F (ex : coups de feu dans lieux publics, ivresse manifeste)
- 2e classe : 5 001 à 10 000 F (ex : divagation de fous, chiens non retenus)
- 3e classe : 10 001 à 15 000 F (ex : tapages nocturnes)
- 4e classe : 15 001 à 50 000 F (ex : blessures involontaires légères)$c$,
  '{"source":"cours","topic":"classification","subtopic":"classification_tripartite"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 240),

  -- Chunk 5: Intérêts de la classification tripartite
  (gen_random_uuid(), v_doc_id, 5,
$c$INTÉRÊTS DE LA DISTINCTION CRIME / DÉLIT / CONTRAVENTION

1. Sources du droit : art. 101 Constitution — seule la loi au sens strict peut instituer crimes et délits. Les contraventions sont déterminées par le règlement (décrets).

2. Compétence juridictionnelle : crimes → chambre criminelle de la Cour d'appel ; délits → tribunal correctionnel ; contraventions → tribunal de police.

3. Procédure : instruction préparatoire obligatoire en matière de crime, facultative en matière de délit.

4. Prescription de l'action publique : crimes = 10 ans ; délits = 3 ans ; contraventions = 1 an.

5. Prescription des peines : criminelles = 20 ans ; correctionnelles = 3 ans (5 ans art. 219-3) ; contraventionnelles = 2 ans (3 ans art. 219-4). Crimes contre l'humanité : imprescriptibles.

6. Tentative : toujours punissable pour les crimes ; seulement si la loi le prévoit pour les délits ; jamais punissable pour les contraventions.

7. Extradition : possible pour crimes et certains délits ; exclue pour contraventions.$c$,
  '{"source":"cours","topic":"classification","subtopic":"interets_classification_tripartite"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 220),

  -- Chunk 6: Infractions politiques et militaires
  (gen_random_uuid(), v_doc_id, 6,
$c$INFRACTIONS POLITIQUES ET MILITAIRES

Infraction de droit commun : ne relève pas d'un régime pénal particulier ou dérogatoire.

Infraction politique : selon la conception objective (retenue par le législateur), l'infraction est politique si les agissements ont pour objet de porter atteinte à l'organisation politique de l'État. Le mobile politique est indifférent. Intérêts : pas d'extradition en principe ; régime pénitentiaire moins rigoureux ; peines spécifiques.

Infraction militaire :
- Conception par l'objet : manquement à la discipline militaire (désertion, capitulation, insoumission) — infractions proprement militaires.
- Conception par le sujet : infraction de droit commun commise par un militaire dans l'exercice de ses fonctions.

Intérêts : procédure spéciale (code de justice militaire) ; compétence des juridictions militaires en temps de paix ; la condamnation militaire ne compte pas pour la récidive ; pas d'extradition.$c$,
  '{"source":"cours","topic":"classification","subtopic":"infractions_politiques_militaires"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 220),

  -- Chunk 7: Classification selon l'élément matériel
  (gen_random_uuid(), v_doc_id, 7,
$c$CLASSIFICATION SELON L'ÉLÉMENT MATÉRIEL

1. Infraction de commission vs d'omission : commission = acte positif interdit (vol, meurtre) ; omission = abstention de faire ce que la loi rend obligatoire (non-assistance à personne en danger). La tentative n'est pas concevable pour les infractions d'omission.

2. Instantanée vs continue : instantanée = réalisée en un temps négligeable (meurtre, vol) ; continue = se prolonge dans le temps (recel, séquestration). Intérêts : prescription, application des lois dans le temps, compétence territoriale.

3. Matérielle vs formelle : matérielle = résultat dommageable nécessaire (pas de meurtre sans décès) ; formelle = consommée indépendamment du résultat (empoisonnement constitué dès l'administration de substances mortifères).

4. Flagrante vs non flagrante : flagrante = se commet actuellement ou dans un temps très voisin. Intérêt : simplification de la procédure.

5. Isolée vs d'habitude : isolée = punissable au premier essai ; d'habitude = nécessite répétition (ex : exercice illégal de la médecine).

6. Simple vs complexe : simple = un seul élément matériel (meurtre) ; complexe = plusieurs actes nécessaires (escroquerie : manoeuvres + remise).$c$,
  '{"source":"cours","topic":"classification","subtopic":"classification_element_materiel"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 250),

  -- Chunk 8: Classification selon l'élément moral
  (gen_random_uuid(), v_doc_id, 8,
$c$CLASSIFICATION SELON L'ÉLÉMENT MORAL

Infraction intentionnelle : l'auteur a entrepris de transgresser la loi pénale de façon volontaire et consciente (dol général). Certaines infractions nécessitent une intention particulière (dol spécial) — un but précis poursuivi par l'auteur.

Infraction non intentionnelle : n'implique pas une volonté de commettre le fait prohibé. Punie à raison de la violation de la loi, à condition qu'il y ait eu une faute d'imprudence, de négligence ou de manquement à une obligation de prudence ou de sécurité prévue par un texte.

Intérêt principal : seules les infractions intentionnelles peuvent être tentées. La tentative dans l'infraction non intentionnelle est inconcevable (on ne peut pas tenter l'involontaire).

Toute infraction repose sur trois éléments cumulatifs : un élément légal, un élément matériel et un élément moral. Si l'un de ces éléments fait défaut, l'infraction ne peut exister.$c$,
  '{"source":"cours","topic":"classification","subtopic":"classification_element_moral"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 200),

  -- Chunk 9: Principe de légalité
  (gen_random_uuid(), v_doc_id, 9,
$c$PRINCIPE DE LÉGALITÉ DES INFRACTIONS ET DES PEINES

Adage : « nullum crimen, nulla poena sine lege ». Art. 5 Constitution : « tout ce qui n'est pas défendu par la loi ne peut être empêché ». Art. 111-1 CP : « nulle infraction ne peut être punie et nulle peine prononcée si elles ne sont légalement prévues ».

Ce principe trace la frontière entre le possible et l'interdit. Il constitue une garantie contre l'arbitraire des pouvoirs publics et du juge, et protège les libertés individuelles.

Sources textuelles (bloc de légalité pénale) :
1. Constitution (valeur suprême, art. 7 al. 2 Charte africaine DHPF)
2. Traités internationaux (art. 151 Constitution, art. 111-7 CP) — ex : Charte africaine, Traité de Rome CPI, Conventions de Genève
3. Loi au sens strict (art. 101 Constitution) — définit crimes et délits
4. Règlement — définit contraventions (Décret 97-84)

Ni la jurisprudence ni la doctrine ne sont des sources du droit pénal en raison du principe de légalité.$c$,
  '{"source":"cours","topic":"elements_constitutifs","subtopic":"principe_legalite"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 230),

  -- Chunk 10: Interprétation stricte
  (gen_random_uuid(), v_doc_id, 10,
$c$INTERPRÉTATION STRICTE DE LA LOI PÉNALE (ART. 111-2 AL. 1 CP)

Conséquence logique du principe de légalité. Le juge doit se contenter de tirer toutes les conséquences de la loi sans rien y retrancher et sans rien y ajouter.

Domaine : s'applique uniquement aux dispositions défavorables au prévenu (éléments constitutifs des infractions, peines). Les dispositions favorables (garanties de liberté individuelle, droits de la défense) peuvent s'interpréter largement.

Portée : devant un texte clair, le juge ne doit pas l'étendre à des hypothèses non comprises dans la loi. Le raisonnement par analogie est prohibé. Si le texte est obscur, le juge doit en rechercher le sens véritable. S'il ne parvient pas à saisir la pensée du législateur, il doit prononcer la relaxe. En cas de doute, il convient de ne pas réprimer.$c$,
  '{"source":"cours","topic":"elements_constitutifs","subtopic":"interpretation_stricte"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 190),

  -- Chunk 11: Application dans le temps
  (gen_random_uuid(), v_doc_id, 11,
$c$APPLICATION DE LA LOI PÉNALE DANS LE TEMPS

Lois pénales de fond (définissent infractions, peines, mesures de sûreté et éducatives) :

Principe : non-rétroactivité (art. 5 al. 2 Constitution, art. 111-2 et 112-1 al. 3 CP). « Seuls sont punissables les faits constitutifs d'une infraction à la date à laquelle ils ont été commis. »

Exceptions — application immédiate :
1. Lois plus douces (art. 112-1 al. 1-2) : la loi qui efface la nature punissable d'un fait a un effet rétroactif ; la loi qui allège une peine s'applique aux infractions n'ayant pas donné lieu à condamnation définitive.
2. Lois prévoyant mesures de sûreté et mesures éducatives pour mineurs.
3. Lois interprétatives : font corps avec la loi qu'elles interprètent.

Lois pénales de forme (compétence, procédure, prescription, voies de recours) : immédiatement applicables, même pour les infractions commises avant leur entrée en vigueur.$c$,
  '{"source":"cours","topic":"elements_constitutifs","subtopic":"application_dans_le_temps"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 220),

  -- Chunk 12: Application dans l'espace
  (gen_random_uuid(), v_doc_id, 12,
$c$APPLICATION DE LA LOI PÉNALE DANS L'ESPACE

Principe : territorialité (art. 113-1 al. 1 CP). La loi pénale s'applique à toute infraction commise sur le territoire national, quelle que soit la nationalité de l'auteur. Territoire = terres, espace aérien, espace fluvial. Extension aux aéronefs immatriculés au BF et navires battant pavillon BF.

Exceptions — compétence extraterritoriale (art. 113-1 al. 2) :
- Personnalité active : infraction commise par un Burkinabè hors du territoire si les faits constituent aussi une infraction dans le pays de commission.
- Personnalité passive : infraction commise contre un Burkinabè hors du territoire.
Conditions : plainte de la victime ou dénonciation officielle de l'autorité du pays où l'infraction a été perpétrée.$c$,
  '{"source":"cours","topic":"elements_constitutifs","subtopic":"application_dans_espace"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 190),

  -- Chunk 13: Élément matériel — contenu
  (gen_random_uuid(), v_doc_id, 13,
$c$ÉLÉMENT MATÉRIEL DE L'INFRACTION

Il n'y a pas d'infraction sans fait matériel constatable. La simple résolution criminelle ne constitue pas un fait susceptible de poursuites. La loi ne sanctionne pas les mauvaises pensées.

Contenu : actes d'exécution consistant en une commission (acte positif : tuer, voler, diffamer) ou une omission (acte négatif : non-assistance à personne en danger — art. 521-7 al. 2 CP ; non-témoignage en faveur d'un innocent — art. 374-11 CP).

Phases de l'infraction :
1. Résolution criminelle : représentation psychologique de l'acte — non punissable.
2. Actes préparatoires : préparation matérielle (acheter une arme, se procurer du poison) — en principe non punissables (art. 122-3 CP), sauf si l'acte constitue lui-même une infraction (détention illégale d'arme).
3. Commencement d'exécution : acte qui tend directement au délit, accompli avec l'intention de le commettre. C'est le seuil de la tentative punissable.$c$,
  '{"source":"cours","topic":"elements_constitutifs","subtopic":"element_materiel"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 220),

  -- Chunk 14: Tentative punissable
  (gen_random_uuid(), v_doc_id, 14,
$c$LA TENTATIVE PUNISSABLE (ART. 122 CP)

Art. 122 al. 1 : la tentative consiste dans l'entreprise de commettre un crime ou un délit, manifestée par des actes non équivoques tendant à son exécution, si ceux-ci n'ont pas été suspendus ou n'ont manqué leur effet que par des circonstances indépendantes de la volonté de leur auteur.

Trois conditions cumulatives :
1. Intention coupable : volonté manifeste de commettre l'infraction. Exclut la tentative pour les infractions non intentionnelles.
2. Commencement d'exécution : acte tendant directement au délit (conception intermédiaire — Cass.). Distinguer de l'acte préparatoire.
3. Absence de désistement volontaire : si l'auteur arrête volontairement et spontanément, la tentative n'est pas punissable. Si l'interruption est due à des circonstances extérieures (arrivée de la police, alarme), la tentative est punissable.

Le désistement doit intervenir avant la consommation de l'infraction. Après = repentir (pas exonératoire, mais le juge peut atténuer la peine).

Variantes : infraction inachevée (interruption), infraction manquée (exécution complète mais résultat non atteint), infraction impossible (irréalisable par nature — art. 122-1 al. 2 : punissable).

Art. 122-4 : la peine de la tentative = peine de l'infraction elle-même.$c$,
  '{"source":"cours","topic":"elements_constitutifs","subtopic":"tentative_punissable"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 250),

  -- Chunk 15: Élément moral — faute intentionnelle et non intentionnelle
  (gen_random_uuid(), v_doc_id, 15,
$c$ÉLÉMENT MORAL DE L'INFRACTION — LA FAUTE EN DROIT PÉNAL

Faute intentionnelle (dol — art. 111-4 al. 1) : « il n'y a point de crime ou de délit sans intention de le commettre ». L'agent a agi sciemment en vue de la réalisation de l'acte illicite. Tous les crimes sont intentionnels. Les délits sont majoritairement intentionnels. L'intention se distingue du mobile (raison de commettre, en principe indifférent à la qualification).

Faute non intentionnelle (art. 111-4 al. 2) : faute d'imprudence, de négligence ou de manquement à une obligation de prudence ou de sécurité. L'auteur n'a pas voulu le résultat mais a manqué aux diligences normales.

Faute contraventionnelle : résulte de la seule inobservation de la loi. La violation fait présumer la faute ; le ministère public est dispensé d'en rapporter la preuve. Seuls force majeure et causes de non-imputabilité conduisent à l'irresponsabilité.

Degrés : préméditation (dol aggravé — art. 216-5, ex : assassinat) ; dol déterminé (résultat voulu avec précision) ; dol indéterminé (résultat voulu mais pas dans sa gravité exacte).$c$,
  '{"source":"cours","topic":"elements_constitutifs","subtopic":"element_moral"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 240),

  -- Chunk 16: Faits justificatifs — ordre de la loi, légitime défense
  (gen_random_uuid(), v_doc_id, 16,
$c$FAITS JUSTIFICATIFS — CAUSES OBJECTIVES D'EXONÉRATION

Caractéristiques : circonstances extérieures à l'auteur, effacent le caractère délictueux de l'acte, profitent à tous les participants (auteurs, co-auteurs, complices).

1. Ordre de la loi (art. 132-1 al. 1) : pas de responsabilité pour un acte prescrit ou autorisé par la loi. Ex : arrestation par la police, perquisition, fouilles aéroportuaires. Inclut la coutume (sport : boxeur).

2. Commandement de l'autorité légitime (art. 132-1 al. 2) : pas de responsabilité sauf si l'acte est « manifestement illégal ». L'autorité doit être publique, compétente, et le subordonné doit agir dans la stricte exécution des ordres.

3. Légitime défense (art. 132-2 al. 1) : conditions :
- Attaque injuste (non justifiée par la loi)
- Attaque actuelle ou imminente (pas de légitime défense préventive)
- Riposte contemporaine à l'attaque
- Riposte proportionnée à la gravité de l'attaque
- Riposte nécessaire (seul moyen de défense)
Effets : irresponsabilité pénale ET civile.
Légitime défense des biens (art. 132-2 al. 2) : autorisée sauf homicide volontaire.
Présomptions (art. 132-2 al. 3) : repoussant de nuit effraction d'un lieu habité ; défense contre vols avec violences.$c$,
  '{"source":"cours","topic":"responsabilite_penale","subtopic":"faits_justificatifs"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 260),

  -- Chunk 17: État de nécessité
  (gen_random_uuid(), v_doc_id, 17,
$c$ÉTAT DE NÉCESSITÉ (ART. 132-3 CP)

Origine historique : affaire Ménard — une femme qui vole un pain pour nourrir son enfant affamé est relaxée.

Art. 132-3 : pas de responsabilité pour la personne qui commet une infraction en vue d'éviter un péril plus grave et imminent, sauf disproportion. L'agent choisit le moindre mal.

Conditions :
1. L'infraction doit être nécessaire : péril actuel ou imminent, non évitable autrement.
2. Proportionnalité entre la gravité du péril et les moyens employés.
3. L'intérêt protégé doit être supérieur à l'intérêt sacrifié (vie humaine > bien matériel).
4. La nécessité ne doit pas avoir été créée par celui qui commet l'infraction (nul ne peut se prévaloir de sa propre turpitude).

Effets : disparition de l'élément légal de l'infraction. Mais une responsabilité civile peut subsister pour réparer le dommage causé à un innocent.

Consentement de la victime : en règle générale, n'exonère pas (règles pénales d'ordre public). Exception : le consentement peut supprimer un élément constitutif (pas de viol si consentement, pas de séquestration si consentement). Conditions : antérieur ou concomitant, donné par personne capable, libre.$c$,
  '{"source":"cours","topic":"responsabilite_penale","subtopic":"etat_de_necessite"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 240),

  -- Chunk 18: Causes subjectives — démence, contrainte, erreur
  (gen_random_uuid(), v_doc_id, 18,
$c$CAUSES SUBJECTIVES D'EXONÉRATION — NON-IMPUTABILITÉ

Caractéristiques : s'attachent à la personne de l'agent (et non aux faits). Ne profitent qu'à la personne concernée (co-auteurs et complices restent punissables). L'infraction demeure, seul l'agent est rendu irresponsable.

1. Trouble psychique / démence (art. 132-4) : pas de responsabilité si l'auteur était en état de démence au temps de l'action. Conditions : désordre mental suffisamment grave pour anéantir le discernement ; existant au moment de l'infraction. Si altération seulement (art. 132-5) : responsable mais le juge en tient compte pour la peine.
États voisins : alcoolisme chronique = responsable ; ivresse = peut être circonstance aggravante ; somnambulisme = irresponsable ; hypnose = irresponsable ; stupéfiants = circonstance aggravante ; état passionnel = responsable mais peine atténuable.

2. Contrainte (art. 132-4 al. 2) : force ou contrainte à laquelle l'agent n'a pu résister. Physique (interne : épilepsie ; externe : tempête) ou morale (menaces anéantissant le libre arbitre). Doit être irrésistible, insurmontable et imprévisible (= force majeure du droit civil). La contrainte précédée d'une faute de l'agent n'est pas exonératoire.

3. Erreur de fait : exonère si elle porte sur les éléments constitutifs d'une infraction intentionnelle. Erreur de droit (art. 132-6) : exonère si un service public est à l'origine de l'erreur invincible.$c$,
  '{"source":"cours","topic":"responsabilite_penale","subtopic":"causes_non_imputabilite"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 260),

  -- Chunk 19: Minorité pénale
  (gen_random_uuid(), v_doc_id, 19,
$c$MINORITÉ PÉNALE (ART. 132-7 CP, LOI N° 015/AN DU 13 MAI 2014)

Âge de la responsabilité pénale : 13 ans.
Âge de la majorité pénale : 18 ans.

Mineur de moins de 13 ans : présomption irréfragable d'irresponsabilité pénale. Seules des mesures éducatives et de sûreté peuvent être ordonnées.

Mineur de 13 à 18 ans : priorité éducative mais responsabilité pénale possible. Les sanctions doivent être nécessairement atténuées (excuse de minorité de droit).

La vieillesse n'est pas une cause d'irresponsabilité pénale, sauf altération des facultés mentales.$c$,
  '{"source":"cours","topic":"responsabilite_penale","subtopic":"minorite_penale"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 170);

END;
$$;
