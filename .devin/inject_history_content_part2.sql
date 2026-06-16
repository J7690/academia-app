-- ═══════════════════════════════════════════════════════════════════════════
-- INJECTION CONTENU HISTORIQUE FIABLE — PRÉPARATION CONCOURS BURKINA FASO
-- Part 2/3 : Organisations africaines + Colonisation + Esclavage + Indépendances
-- Exécuter dans Supabase Dashboard > SQL Editor
-- Sources : UA, CEDEAO, UEMOA, UNESCO, Encyclopédie Universalis, Britannica
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── UNION AFRICAINE (UA) ───────────────────────────────────────────────

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 10,
  $body$L'UNION AFRICAINE (UA) — DE L'OUA À L'UA

ORGANISATION DE L'UNITÉ AFRICAINE (OUA) :
- Fondée le 25 mai 1963 à Addis-Abeba (Éthiopie) par 32 États africains indépendants.
- Charte signée par les chefs d'État fondateurs dont Kwame Nkrumah (Ghana), Haïlé Sélassié (Éthiopie), Modibo Keïta (Mali), Sékou Touré (Guinée), Gamal Abdel Nasser (Égypte).
- Objectifs : promouvoir l'unité et la solidarité des États africains, coordonner la coopération, défendre la souveraineté et l'intégrité territoriale, éliminer le colonialisme.
- Principes fondamentaux : non-ingérence dans les affaires intérieures, respect des frontières héritées de la colonisation (principe de l'uti possidetis juris), règlement pacifique des différends.
- Siège : Addis-Abeba, Éthiopie.
- Le 25 mai est célébré comme Journée de l'Afrique.

LIMITES DE L'OUA :
- Incapacité à prévenir les conflits internes (guerres civiles, génocides)
- Principe de non-ingérence empêchant toute intervention dans les crises humanitaires
- Faiblesse financière et institutionnelle
- Génocide du Rwanda (1994) : échec majeur de la communauté internationale et de l'OUA

TRANSITION VERS L'UNION AFRICAINE :
- Initiative du colonel Mouammar Kadhafi (Libye) lors du sommet de Syrte (septembre 1999).
- Acte constitutif de l'Union Africaine adopté le 11 juillet 2000 à Lomé (Togo).
- L'UA remplace officiellement l'OUA le 9 juillet 2002 lors du sommet de Durban (Afrique du Sud).
- Premier président de la Commission de l'UA : Alpha Oumar Konaré (Mali, 2003-2008).

DIFFÉRENCES MAJEURES OUA → UA :
- Passage du principe de « non-ingérence » au principe de « non-indifférence » : l'UA peut intervenir dans un État membre en cas de génocide, crimes de guerre ou crimes contre l'humanité (Article 4h de l'Acte constitutif).
- Structures plus élaborées inspirées de l'Union européenne.
- Focus sur l'intégration économique, la gouvernance démocratique et les droits de l'homme.$body$,
  '{"source": "encyclopedique", "topic": "Union Africaine", "subtopic": "OUA vers UA", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 450, false
);

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 11,
  $body$L'UNION AFRICAINE (UA) — STRUCTURE ET RÉALISATIONS

MEMBRES : 55 États membres (tous les pays africains). Le Maroc, absent de l'OUA depuis 1984 (conflit du Sahara occidental), a réintégré l'UA en janvier 2017.

ORGANES PRINCIPAUX :
1. Conférence des chefs d'État et de gouvernement : organe suprême, se réunit deux fois par an. Présidence tournante annuelle.
2. Conseil exécutif : composé des ministres des Affaires étrangères. Prépare les décisions de la Conférence.
3. Commission de l'Union Africaine : secrétariat permanent basé à Addis-Abeba. Dirigée par un président élu pour 4 ans. Présidents notables : Alpha Oumar Konaré (Mali), Nkosazana Dlamini-Zuma (Afrique du Sud), Moussa Faki Mahamat (Tchad, depuis 2017).
4. Parlement panafricain : créé en 2004, siège à Midrand (Afrique du Sud). Rôle consultatif.
5. Conseil de paix et de sécurité (CPS) : créé en 2004, 15 membres. Gère les crises et conflits. Peut autoriser des missions de paix.
6. Cour africaine des droits de l'homme et des peuples : siège à Arusha (Tanzanie). Créée en 2006.
7. NEPAD (Nouveau partenariat pour le développement de l'Afrique) : programme économique adopté en 2001.

RÉALISATIONS ET PROGRAMMES CLÉS :
- Agenda 2063 : vision stratégique à long terme adoptée en 2013. « L'Afrique que nous voulons ». 7 aspirations incluant la paix, l'intégration, la bonne gouvernance, le développement durable.
- ZLECAF (Zone de libre-échange continentale africaine) : accord signé à Kigali le 21 mars 2018, entré en vigueur le 30 mai 2019. 54 pays signataires. Plus grande zone de libre-échange au monde par le nombre de pays. Objectif : créer un marché unique de 1,3 milliard de personnes et un PIB combiné de 3 400 milliards de dollars.
- Force africaine en attente (FAA) : force militaire multinationale pour les opérations de paix.
- Mécanisme africain d'évaluation par les pairs (MAEP) : évaluation volontaire de la gouvernance.
- Missions de paix : AMISOM en Somalie, MISCA en Centrafrique, missions au Darfour.

DÉFIS :
- Financement (dépendance aux partenaires extérieurs : 60% du budget opérationnel)
- Coups d'État persistants (Mali 2020-2021, Burkina Faso 2022, Niger 2023, Gabon 2023)
- Conflits armés (Sahel, RDC, Éthiopie/Tigré, Soudan)
- Mise en œuvre effective des décisions
- Le Burkina Faso est membre fondateur de l'OUA (1963) et membre actif de l'UA. Ouagadougou a accueilli plusieurs sommets de l'UA.$body$,
  '{"source": "encyclopedique", "topic": "Union Africaine", "subtopic": "Structure et réalisations", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 530, false
);

-- ─── CEDEAO (Communauté Économique des États de l'Afrique de l'Ouest) ───

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 12,
  $body$LA CEDEAO — COMMUNAUTÉ ÉCONOMIQUE DES ÉTATS DE L'AFRIQUE DE L'OUEST

CRÉATION ET FONDEMENTS :
- Traité de Lagos signé le 28 mai 1975 par 15 États ouest-africains.
- Traité révisé à Cotonou le 24 juillet 1993 (renforcement des pouvoirs, ajout de la dimension politique et sécuritaire).
- Siège : Abuja (Nigeria).
- Langues officielles : anglais, français, portugais.

ÉTATS MEMBRES (15) :
- Zone francophone : Bénin, Burkina Faso, Côte d'Ivoire, Guinée, Mali, Niger, Sénégal, Togo
- Zone anglophone : Gambie, Ghana, Libéria, Nigeria, Sierra Leone
- Zone lusophone : Cap-Vert, Guinée-Bissau
- La Mauritanie s'est retirée en décembre 2000.
- En janvier 2024, le Burkina Faso, le Mali et le Niger ont annoncé leur retrait de la CEDEAO (effectif janvier 2025), formant l'Alliance des États du Sahel (AES).

OBJECTIFS :
1. Promouvoir l'intégration économique : libre circulation des personnes, des biens, des services et des capitaux
2. Harmoniser les politiques économiques et sectorielles
3. Créer un marché commun ouest-africain
4. Promouvoir la paix et la stabilité régionale
5. À terme : créer une union monétaire avec une monnaie unique (projet ECO)

ORGANES PRINCIPAUX :
- Conférence des chefs d'État et de gouvernement : organe suprême
- Conseil des ministres : organe exécutif
- Commission de la CEDEAO : secrétariat permanent (Abuja)
- Parlement de la CEDEAO : siège à Abuja
- Cour de justice de la CEDEAO : siège à Abuja
- Banque d'investissement et de développement de la CEDEAO (BIDC) : siège à Lomé

PROTOCOLE DE LIBRE CIRCULATION :
- Protocole de 1979 : droit de libre entrée, résidence et établissement pour les citoyens de la CEDEAO.
- Passeport CEDEAO (carte d'identité biométrique) : facilite les déplacements.
- Suppression des visas pour les ressortissants de la CEDEAO dans l'espace communautaire.$body$,
  '{"source": "encyclopedique", "topic": "CEDEAO", "subtopic": "Création et structure", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 450, false
);

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 13,
  $body$LA CEDEAO — RÉALISATIONS, RÔLE SÉCURITAIRE ET DÉFIS

RÉALISATIONS ÉCONOMIQUES :
- Tarif extérieur commun (TEC) : adopté en 2015, harmonise les droits de douane.
- Schéma de libéralisation des échanges (SLE) : réduction progressive des droits de douane intra-communautaires.
- Projets d'infrastructures : autoroute transafricaine Lagos-Abidjan, interconnexions électriques (WAPP — West African Power Pool), gazoduc ouest-africain.
- Projet de monnaie unique ECO (en discussion depuis 2003, reporté plusieurs fois).

RÔLE SÉCURITAIRE — ECOMOG ET MISSIONS DE PAIX :
- ECOMOG (ECOWAS Monitoring Group) : force militaire d'intervention créée en 1990.
- Interventions majeures :
  • Libéria (1990-1997, 2003) : première intervention militaire pour mettre fin à la guerre civile
  • Sierra Leone (1997-2000) : restauration du président élu Ahmad Tejan Kabbah
  • Guinée-Bissau (1998-1999)
  • Côte d'Ivoire (2003) : force de maintien de la paix
  • Gambie (2017) : intervention pour installer le président élu Adama Barrow après le refus de Yahya Jammeh de quitter le pouvoir
  • Mali (2013) : soutien à l'intervention française (opération Serval)

MÉCANISME DE PRÉVENTION DES CONFLITS :
- Protocole de Lomé (1999) : mécanisme de prévention, gestion et règlement des conflits.
- Protocole additionnel sur la démocratie et la bonne gouvernance (2001) : interdiction des changements anticonstitutionnels de gouvernement. Sanctions possibles : suspension, embargo.

CRISES RÉCENTES ET DÉFIS :
- Coups d'État au Mali (2020, 2021), en Guinée (2021), au Burkina Faso (janvier et septembre 2022), au Niger (2023) : la CEDEAO a appliqué des sanctions économiques et diplomatiques.
- Menace de retrait du Burkina Faso, du Mali et du Niger (annonce en janvier 2024) → création de l'Alliance des États du Sahel (AES) le 16 septembre 2023 (charte de Liptako-Gourma).
- Terrorisme au Sahel : groupes jihadistes (JNIM, EIGS) actifs au Mali, Burkina Faso, Niger.
- Difficultés de mise en œuvre de la libre circulation (tracasseries routières, barrières non tarifaires).
- Inégalités économiques : le Nigeria représente plus de 60% du PIB de la CEDEAO.

Le Burkina Faso est membre fondateur de la CEDEAO (1975). Le pays a joué un rôle important dans l'organisation mais a annoncé son retrait en janvier 2024 avec le Mali et le Niger.$body$,
  '{"source": "encyclopedique", "topic": "CEDEAO", "subtopic": "Réalisations et défis", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 520, false
);

-- ─── UEMOA (Union Économique et Monétaire Ouest-Africaine) ──────────────

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 14,
  $body$L'UEMOA — UNION ÉCONOMIQUE ET MONÉTAIRE OUEST-AFRICAINE

CRÉATION ET FONDEMENTS :
- Traité signé le 10 janvier 1994 à Dakar (Sénégal).
- Entrée en vigueur le 1er août 1994.
- Succède à l'UMOA (Union monétaire ouest-africaine, créée en 1962) et à la CEAO (Communauté économique de l'Afrique de l'Ouest, créée en 1973).
- Siège de la Commission : Ouagadougou (Burkina Faso).

ÉTATS MEMBRES (8) :
Bénin, Burkina Faso, Côte d'Ivoire, Guinée-Bissau (adhésion en 1997), Mali, Niger, Sénégal, Togo.
Tous ces pays partagent le franc CFA (XOF) comme monnaie commune.

OBJECTIFS :
1. Renforcer la compétitivité des activités économiques dans un marché ouvert et concurrentiel
2. Assurer la convergence des performances et des politiques économiques des États membres
3. Créer un marché commun basé sur la libre circulation des personnes, des biens, des services et des capitaux
4. Coordonner les politiques sectorielles nationales (agriculture, industrie, transport, télécommunications)
5. Harmoniser les législations et les politiques fiscales

ORGANES :
- Conférence des chefs d'État et de gouvernement : organe suprême, définit les grandes orientations.
- Conseil des ministres : pouvoir de décision, adopte les actes juridiques.
- Commission de l'UEMOA : organe exécutif, siège à Ouagadougou. Assure l'application des décisions.
- Cour de justice : siège à Ouagadougou. Veille au respect du droit communautaire.
- Cour des comptes : siège à Ouagadougou. Contrôle les comptes de l'Union.
- Comité interparlementaire → Parlement de l'UEMOA (siège à Bamako).
- BCEAO (Banque Centrale des États de l'Afrique de l'Ouest) : siège à Dakar. Gère la politique monétaire et émet le franc CFA.
- BOAD (Banque Ouest-Africaine de Développement) : siège à Lomé. Financement du développement.

LE FRANC CFA (XOF) :
- Créé le 26 décembre 1945.
- Parité fixe avec l'euro : 1 EUR = 655,957 FCFA.
- Garantie de convertibilité assurée par le Trésor français.
- Dévaluation du 11 janvier 1994 : le franc CFA perd 50% de sa valeur (passage de 1 FF = 50 FCFA à 1 FF = 100 FCFA). Mesure décidée pour restaurer la compétitivité des économies africaines.
- Réforme de décembre 2019 : annonce du remplacement du franc CFA par l'ECO dans la zone UEMOA. La France se retire du conseil d'administration de la BCEAO et le compte d'opérations au Trésor français est supprimé. Mise en œuvre toujours en attente.

CRITÈRES DE CONVERGENCE :
- Ratio du solde budgétaire / PIB ≥ -3%
- Taux d'inflation annuel ≤ 3%
- Ratio dette publique / PIB ≤ 70%
- Masse salariale / recettes fiscales ≤ 35%

Le Burkina Faso abrite le siège de la Commission de l'UEMOA à Ouagadougou, ce qui en fait un acteur institutionnel central de l'organisation.$body$,
  '{"source": "encyclopedique", "topic": "UEMOA", "subtopic": "Création et fonctionnement", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 580, false
);

-- ─── EAC (Communauté d'Afrique de l'Est) ────────────────────────────────

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 15,
  $body$L'EAC — COMMUNAUTÉ D'AFRIQUE DE L'EST (EAST AFRICAN COMMUNITY)

HISTORIQUE :
- Première EAC fondée en 1967 par le Kenya, l'Ouganda et la Tanzanie. Dissoute en 1977 en raison de divergences politiques (socialisme tanzanien vs capitalisme kenyan) et du conflit ougando-tanzanien.
- Relancée : nouveau Traité signé le 30 novembre 1999, entré en vigueur le 7 juillet 2000.
- Siège : Arusha (Tanzanie).

ÉTATS MEMBRES (7, en 2024) :
- Membres fondateurs (2000) : Kenya, Ouganda, Tanzanie
- Adhésions : Rwanda (2007), Burundi (2007), Soudan du Sud (2016), RD Congo (2022)
- Population totale : environ 300 millions d'habitants
- PIB combiné : environ 305 milliards de dollars

OBJECTIFS :
1. Union douanière (effective depuis 2005) : tarif extérieur commun
2. Marché commun (Protocole de 2010) : libre circulation des personnes, des travailleurs, des biens, des services et des capitaux
3. Union monétaire : Protocole signé en 2013, monnaie unique prévue (pas encore mise en œuvre)
4. Fédération politique d'Afrique de l'Est : objectif à long terme

ORGANES :
- Sommet des chefs d'État : organe suprême
- Conseil des ministres : organe décisionnel
- Secrétariat : organe exécutif à Arusha
- Assemblée législative de l'Afrique de l'Est (EALA) : parlement régional à Arusha
- Cour de justice de l'Afrique de l'Est : siège à Arusha

RÉALISATIONS :
- Passeport est-africain
- Réduction des barrières tarifaires intra-régionales
- Projets d'infrastructures : chemin de fer à écartement normal (SGR), corridors routiers
- Harmonisation des normes et standards

DÉFIS :
- Instabilité politique (Burundi, RDC, Soudan du Sud)
- Déséquilibres économiques (le Kenya domine)
- Conflits frontaliers (RDC-Rwanda, Ouganda-RDC)
- Mise en œuvre lente de l'intégration monétaire et politique

L'EAC est considérée comme l'une des communautés économiques régionales les plus avancées d'Afrique en termes d'intégration.$body$,
  '{"source": "encyclopedique", "topic": "EAC", "subtopic": "Communauté Afrique de l Est", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 450, false
);

-- ─── LA COLONISATION DE L'AFRIQUE ──────────────────────────────────────

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 16,
  $body$LA COLONISATION DE L'AFRIQUE — CAUSES ET MOTIVATIONS

DÉFINITION :
La colonisation est le processus par lequel des puissances européennes ont conquis, occupé et administré des territoires en Afrique (et ailleurs), imposant leur domination politique, économique et culturelle aux populations autochtones. La colonisation systématique de l'Afrique s'est principalement déroulée entre 1880 et 1960.

CAUSES ET MOTIVATIONS :

1. MOTIVATIONS ÉCONOMIQUES :
   - Recherche de matières premières : or, diamants, cuivre, caoutchouc, ivoire, huile de palme, coton, cacao, café
   - Recherche de débouchés commerciaux pour les produits manufacturés européens (Révolution industrielle)
   - Investissement des capitaux excédentaires européens
   - Contrôle des routes commerciales maritimes (canal de Suez, cap de Bonne-Espérance)

2. MOTIVATIONS POLITIQUES ET STRATÉGIQUES :
   - Rivalités entre puissances européennes : prestige national, course à la puissance
   - Contrôle de territoires stratégiques (bases navales, points de ravitaillement)
   - Expansion du domaine national

3. MOTIVATIONS IDÉOLOGIQUES ET CULTURELLES :
   - « Mission civilisatrice » : idéologie selon laquelle l'Europe devait « civiliser » les peuples « primitifs ». Jules Ferry (France, 1885) : « Les races supérieures ont un droit vis-à-vis des races inférieures [...] un devoir de civiliser les races inférieures. »
   - Darwinisme social : application abusive des théories de Darwin aux sociétés humaines
   - Évangélisation : missions chrétiennes (catholiques et protestantes) précèdent ou accompagnent la colonisation
   - Sociétés de géographie et explorations : Livingstone, Stanley, Brazza, Savorgnan de Brazza

4. MOTIVATIONS DÉMOGRAPHIQUES :
   - Croissance démographique européenne → recherche de territoires de peuplement
   - Colonies de peuplement (Algérie, Afrique du Sud, Kenya)

PHASES DE LA COLONISATION :
- XVe-XVIIIe siècle : comptoirs commerciaux côtiers (traite négrière)
- XIXe siècle : explorations intérieures, traités avec les chefs locaux
- 1880-1914 : « Scramble for Africa » — partage systématique du continent
- 1914-1960 : apogée et déclin de la colonisation$body$,
  '{"source": "encyclopedique", "topic": "Colonisation", "subtopic": "Causes et motivations", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 470, false
);

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 17,
  $body$LA COLONISATION DE L'AFRIQUE — CONFÉRENCE DE BERLIN ET PARTAGE

LA CONFÉRENCE DE BERLIN (15 NOVEMBRE 1884 - 26 FÉVRIER 1885) :
- Organisée par le chancelier allemand Otto von Bismarck.
- 14 nations participantes : Allemagne, Autriche-Hongrie, Belgique, Danemark, Espagne, États-Unis, France, Grande-Bretagne, Italie, Pays-Bas, Portugal, Russie, Suède-Norvège, Empire ottoman.
- Aucun représentant africain n'était présent.

DÉCISIONS PRINCIPALES :
1. Liberté de commerce dans le bassin du Congo et le bassin du Niger
2. Liberté de navigation sur les fleuves Congo et Niger
3. Principe de l'occupation effective : pour revendiquer un territoire, une puissance devait y établir une administration réelle (et non simplement le déclarer sien)
4. Obligation de notifier les autres puissances de toute nouvelle prise de possession
5. L'État libre du Congo est reconnu comme propriété personnelle du roi Léopold II de Belgique

PARTAGE DE L'AFRIQUE APRÈS BERLIN :

France (le plus grand empire colonial en Afrique) :
- Afrique occidentale française (AOF) : Sénégal, Mauritanie, Soudan français (Mali), Guinée, Côte d'Ivoire, Haute-Volta (Burkina Faso), Dahomey (Bénin), Niger
- Afrique équatoriale française (AEF) : Gabon, Congo, Oubangui-Chari (Centrafrique), Tchad
- Madagascar, Djibouti, Comores
- Afrique du Nord : Algérie (colonie depuis 1830), Tunisie (protectorat 1881), Maroc (protectorat 1912)

Royaume-Uni :
- Égypte, Soudan, Nigeria, Ghana (Gold Coast), Sierra Leone, Gambie, Kenya, Ouganda, Tanganyika (après 1918), Rhodésie (Zimbabwe/Zambie), Afrique du Sud, Botswana, Swaziland, Lesotho, Malawi, Somaliland

Allemagne (jusqu'en 1918) :
- Togo, Cameroun, Tanganyika (Tanzanie), Namibie (Sud-Ouest africain)
- Colonies perdues au profit des Alliés après la Première Guerre mondiale

Belgique : Congo (État libre du Congo → Congo belge), Rwanda-Urundi
Portugal : Angola, Mozambique, Guinée-Bissau, Cap-Vert, São Tomé
Italie : Libye, Érythrée, Somalie italienne, brève occupation de l'Éthiopie (1936-1941)
Espagne : Sahara occidental, Guinée équatoriale, petits territoires au Maroc

SEULS ÉTATS AFRICAINS JAMAIS COLONISÉS :
- Éthiopie (sauf brève occupation italienne 1936-1941) : victoire à la bataille d'Adoua (1er mars 1896) contre l'Italie
- Libéria : fondé en 1847 par des esclaves afro-américains affranchis$body$,
  '{"source": "encyclopedique", "topic": "Colonisation", "subtopic": "Conférence de Berlin et partage", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 560, false
);

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 18,
  $body$LA COLONISATION DE L'AFRIQUE — SYSTÈME COLONIAL ET EXPLOITATION

FORMES D'ADMINISTRATION COLONIALE :

1. Administration directe (modèle français) :
   - Assimilation : transformer les colonisés en citoyens français
   - Remplacement des structures traditionnelles par l'administration française
   - Nomination de chefs indigènes soumis au gouverneur colonial
   - Code de l'indigénat (1887-1946) : régime juridique discriminatoire imposé aux « sujets » africains (travail forcé, impôt de capitation, restrictions de circulation, punitions collectives)
   - Très peu d'Africains accédaient à la citoyenneté française (statut de « citoyen » vs « sujet »)

2. Administration indirecte (modèle britannique — indirect rule) :
   - Théorisée par Lord Lugard au Nigeria
   - Maintien des chefs traditionnels comme intermédiaires
   - Les chefs locaux administrent sous le contrôle du résident britannique
   - Respect relatif des structures sociales existantes
   - Moins coûteux mais crée des divisions ethniques instrumentalisées

EXPLOITATION ÉCONOMIQUE :
- Économie de traite : cultures d'exportation imposées (arachide, cacao, coton, café, hévéa)
- Travail forcé : construction de routes, chemins de fer (ex : Congo-Océan au Congo français, 17 000 morts estimés)
- Impôt de capitation : les Africains devaient payer en monnaie coloniale, les forçant à travailler dans les plantations ou les mines
- Pillage des ressources naturelles : or, diamants, caoutchouc (Congo de Léopold II : régime de terreur, mutilations, 10 millions de morts estimés entre 1885 et 1908)
- Compagnies concessionnaires : vastes territoires concédés à des entreprises privées

LA HAUTE-VOLTA (actuel Burkina Faso) SOUS LA COLONISATION :
- Conquête française : prise de Ouagadougou en 1896, résistance du Mogho Naba
- La Haute-Volta est créée comme colonie le 1er mars 1919
- Supprimée en 1932 et partagée entre le Soudan français, la Côte d'Ivoire et le Niger (pour faciliter le recrutement de main-d'œuvre pour les plantations ivoiriennes)
- Reconstituée le 4 septembre 1947 grâce aux efforts de leaders voltaïques (Daniel Ouezzin Coulibaly, Philippe Zinda Kaboré, Nazi Boni)
- Résistances : soulèvement des Bwa et des Marka (1915-1916), résistance des Lobi, des Gourmantché

CONSÉQUENCES CULTURELLES :
- Imposition des langues européennes
- Destruction ou marginalisation des cultures locales
- Système éducatif colonial formant des auxiliaires de l'administration
- Christianisation et modification des structures sociales
- Tracé artificiel des frontières divisant des peuples et regroupant des ethnies rivales$body$,
  '{"source": "encyclopedique", "topic": "Colonisation", "subtopic": "Système colonial et exploitation", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 570, false
);

-- ─── L'ESCLAVAGE ────────────────────────────────────────────────────────

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 19,
  $body$L'ESCLAVAGE — LA TRAITE NÉGRIÈRE ATLANTIQUE

DÉFINITION :
L'esclavage est un système dans lequel des êtres humains sont considérés comme la propriété d'autres personnes, privés de liberté et contraints au travail forcé. La traite négrière atlantique (ou traite transatlantique) est le commerce d'esclaves africains vers les Amériques entre le XVIe et le XIXe siècle. Elle est reconnue comme un crime contre l'humanité.

LES TROIS TRAITES NÉGRIÈRES :
1. Traite transsaharienne (VIIe-XXe siècle) : commerce d'esclaves africains vers le Maghreb et le Moyen-Orient via le Sahara. Estimation : 8 à 12 millions de personnes.
2. Traite orientale (VIIe-XIXe siècle) : via l'océan Indien vers le monde arabo-musulman, l'Inde, l'Asie du Sud-Est. Estimation : 5 à 8 millions de personnes.
3. Traite transatlantique (XVIe-XIXe siècle) : vers les Amériques. La plus documentée et la plus massive. Estimation : 12 à 15 millions de personnes déportées (selon la base de données Slave Voyages), dont environ 1,5 à 2 millions morts durant la traversée.

LE COMMERCE TRIANGULAIRE :
Système commercial reliant trois continents :
1. Première étape (Europe → Afrique) : les navires européens partent de ports comme Liverpool, Nantes, Bordeaux, Amsterdam, Lisbonne avec des marchandises (armes, alcool, textiles, pacotille, poudre à canon) destinées aux royaumes africains.
2. Deuxième étape — « Le passage du milieu » (Afrique → Amériques) : les esclaves sont entassés dans les cales des navires. Traversée de 6 à 10 semaines dans des conditions inhumaines. Taux de mortalité de 10 à 20%.
3. Troisième étape (Amériques → Europe) : les navires repartent chargés de produits coloniaux (sucre, coton, tabac, café, cacao, indigo).

ZONES DE CAPTURE EN AFRIQUE :
- Sénégambie, Côte de l'Or (Ghana), Côte des Esclaves (Bénin, Togo, Nigeria), Congo, Angola, Mozambique
- Les captifs étaient souvent des prisonniers de guerre entre royaumes africains, des victimes de razzias ou des personnes vendues pour dettes
- Royaumes impliqués dans la traite : Dahomey, Ashanti, Oyo, Congo, certains États côtiers

PRINCIPAUX PAYS NÉGRIERS EUROPÉENS :
- Portugal/Brésil : environ 5,8 millions d'esclaves transportés (le plus gros trafiquant)
- Grande-Bretagne : environ 3,2 millions
- France : environ 1,3 million (ports : Nantes, Bordeaux, La Rochelle, Le Havre)
- Espagne : environ 1 million
- Pays-Bas : environ 500 000$body$,
  '{"source": "encyclopedique", "topic": "Esclavage", "subtopic": "Traite négrière atlantique", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 540, false
);

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 20,
  $body$L'ESCLAVAGE — ABOLITION ET HÉRITAGE

MOUVEMENT ABOLITIONNISTE :

Pionniers de l'abolition :
- Bartolomé de Las Casas (XVIe siècle) : prêtre espagnol, premier à dénoncer le traitement des indigènes et des esclaves
- Les Quakers (XVIIe-XVIIIe siècle) : mouvement religieux anglo-américain opposé à l'esclavage
- Montesquieu (1748) : « De l'esclavage des nègres » (L'Esprit des lois), ironie mordante contre l'esclavage
- Voltaire, Condorcet, l'abbé Grégoire : philosophes des Lumières favorables à l'abolition
- William Wilberforce : parlementaire britannique, combat pour l'abolition pendant 20 ans
- Toussaint Louverture : leader de la révolution haïtienne (1791-1804), ancien esclave devenu général

ÉTAPES DE L'ABOLITION :
- 1794 : Première abolition française (Convention nationale, 4 février 1794) — limitée et révoquée par Napoléon
- 1er janvier 1804 : Indépendance d'Haïti — première République noire, née d'une révolte d'esclaves. Seule révolution d'esclaves réussie de l'histoire.
- 1807 : Le Royaume-Uni interdit la traite (Slave Trade Act)
- 1833 : Le Royaume-Uni abolit l'esclavage dans son empire (Slavery Abolition Act)
- 27 avril 1848 : Abolition définitive de l'esclavage en France (décret de Victor Schoelcher, sous-secrétaire d'État aux Colonies). 250 000 esclaves libérés.
- 1863 : Proclamation d'émancipation d'Abraham Lincoln aux États-Unis
- 1865 : 13e amendement de la Constitution américaine abolit l'esclavage
- 1888 : Le Brésil est le dernier pays des Amériques à abolir l'esclavage (Lei Áurea)

BILAN ET IMPACT :
- 12 à 15 millions d'Africains déportés vers les Amériques (estimation base Slave Voyages / UNESCO)
- Impact démographique dévastateur sur l'Afrique : dépeuplement de régions entières, déséquilibre des structures sociales
- Enrichissement considérable de l'Europe et des Amériques (accumulation primitive du capital)
- Création de la diaspora africaine des Amériques
- Racisme systémique hérité de l'esclavage (ségrégation, apartheid, discriminations persistantes)

RECONNAISSANCE ET MÉMOIRE :
- La traite négrière et l'esclavage reconnus comme crime contre l'humanité par la France (loi Taubira, 21 mai 2001)
- Journée internationale du souvenir de la traite négrière et de son abolition : 23 août (UNESCO)
- Route de l'esclave : programme de l'UNESCO lancé en 1994 à Ouidah (Bénin), lieu emblématique de la traite en Afrique de l'Ouest
- Gorée (Sénégal) : Maison des esclaves, symbole mondial de la traite négrière, inscrite au patrimoine mondial de l'UNESCO$body$,
  '{"source": "encyclopedique", "topic": "Esclavage", "subtopic": "Abolition et héritage", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 570, false
);

-- ─── LES INDÉPENDANCES AFRICAINES ──────────────────────────────────────

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 21,
  $body$LES INDÉPENDANCES AFRICAINES — CONTEXTE ET MOUVEMENTS NATIONALISTES

CONTEXTE FAVORABLE AUX INDÉPENDANCES :

1. Impact des deux guerres mondiales :
   - Participation des soldats africains (tirailleurs) → prise de conscience des inégalités
   - Affaiblissement des puissances coloniales (France, Royaume-Uni, Belgique)
   - Idéaux de liberté et d'autodétermination des peuples

2. Charte de l'Atlantique (1941) :
   - Roosevelt et Churchill affirment le droit des peuples à disposer d'eux-mêmes
   - Contradiction avec le maintien des empires coloniaux

3. Création de l'ONU (1945) :
   - Charte des Nations Unies : principe du droit des peuples à l'autodétermination
   - Commission de décolonisation de l'ONU
   - Résolution 1514 (14 décembre 1960) : Déclaration sur l'octroi de l'indépendance aux pays et peuples coloniaux

4. Contexte de la Guerre froide :
   - Les USA et l'URSS soutiennent la décolonisation (pour étendre leurs sphères d'influence)
   - Mouvements anticoloniaux trouvent des soutiens auprès des deux blocs

5. Conférence de Bandung (avril 1955) :
   - 29 pays afro-asiatiques affirment leur solidarité anticoloniale
   - Impulsion au mouvement des non-alignés

GRANDS LEADERS ET MOUVEMENTS NATIONALISTES :

Afrique de l'Ouest :
- Kwame Nkrumah (Ghana) : panafricaniste, « Show boy » de l'indépendance africaine. Le Ghana est le premier pays d'Afrique noire à obtenir l'indépendance (6 mars 1957).
- Léopold Sédar Senghor (Sénégal) : poète, théoricien de la Négritude, premier président du Sénégal
- Sékou Touré (Guinée) : « Nous préférons la pauvreté dans la liberté à la richesse dans l'esclavage » (discours du 25 août 1958 devant de Gaulle). La Guinée vote NON au référendum et devient indépendante le 2 octobre 1958.
- Félix Houphouët-Boigny (Côte d'Ivoire) : fondateur du RDA (Rassemblement Démocratique Africain, 1946)
- Modibo Keïta (Mali), Hamani Diori (Niger), Hubert Maga (Dahomey/Bénin)

Afrique du Nord :
- Habib Bourguiba (Tunisie), FLN (Algérie — guerre d'indépendance 1954-1962)

Afrique centrale et australe :
- Patrice Lumumba (Congo) : assassiné en janvier 1961
- Julius Nyerere (Tanzanie), Jomo Kenyatta (Kenya)
- Nelson Mandela (Afrique du Sud) : lutte contre l'apartheid$body$,
  '{"source": "encyclopedique", "topic": "Indépendances africaines", "subtopic": "Contexte et leaders", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 550, false
);

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 22,
  $body$LES INDÉPENDANCES AFRICAINES — CHRONOLOGIE ET CAS DU BURKINA FASO

CHRONOLOGIE DES INDÉPENDANCES :

Années 1950 :
- 1951 : Libye (ancienne colonie italienne sous tutelle ONU)
- 1956 : Soudan, Tunisie, Maroc
- 1957 : Ghana (premier pays d'Afrique subsaharienne)
- 1958 : Guinée (vote NON au référendum français)

1960 — « L'ANNÉE DE L'AFRIQUE » (17 pays accèdent à l'indépendance) :
- 1er janvier : Cameroun
- 27 avril : Togo
- 20 juin : Mali (Fédération du Mali, puis séparation avec le Sénégal)
- 26 juin : Madagascar
- 30 juin : Congo-Léopoldville (Congo belge → RDC)
- 1er juillet : Somalie
- 1er août : Dahomey (Bénin)
- 3 août : Niger
- 5 août : HAUTE-VOLTA (BURKINA FASO)
- 7 août : Côte d'Ivoire
- 11 août : Tchad
- 13 août : Centrafrique
- 15 août : Congo-Brazzaville
- 17 août : Gabon
- 20 août : Sénégal
- 22 septembre : Mali
- 1er octobre : Nigeria
- 28 novembre : Mauritanie

Années 1960-1970 :
- 1961 : Sierra Leone, Tanzanie
- 1962 : Algérie (après 8 ans de guerre, 1,5 million de morts), Ouganda, Rwanda, Burundi
- 1963 : Kenya
- 1964 : Malawi, Zambie
- 1966 : Botswana, Lesotho
- 1968 : Swaziland, Guinée équatoriale, Maurice
- 1975 : Mozambique, Angola, Cap-Vert, São Tomé, Comores (colonies portugaises — après la Révolution des Œillets au Portugal en 1974)
- 1977 : Djibouti

Cas tardifs :
- 1980 : Zimbabwe (ex-Rhodésie du Sud)
- 1990 : Namibie (dernière colonie classique en Afrique)
- 1993 : Érythrée (séparation de l'Éthiopie)
- 2011 : Soudan du Sud (séparation du Soudan)

LE BURKINA FASO :
- Nom colonial : Haute-Volta (du nom des trois cours du fleuve Volta)
- Indépendance : 5 août 1960
- Premier président : Maurice Yaméogo (1960-1966)
- Principaux dirigeants : Sangoulé Lamizana (1966-1980), Saye Zerbo (1980-1982), Jean-Baptiste Ouédraogo (1982-1983), Thomas Sankara (1983-1987), Blaise Compaoré (1987-2014)
- Thomas Sankara renomme le pays « Burkina Faso » (« Pays des hommes intègres ») le 4 août 1984. Réformes sociales majeures : vaccination, alphabétisation, droits des femmes, autosuffisance alimentaire. Assassiné le 15 octobre 1987.
- Loi fondamentale de la Communauté franco-africaine (1958) : la Haute-Volta vote OUI au référendum, devenant une république autonome au sein de la Communauté française avant l'indépendance totale en 1960.$body$,
  '{"source": "encyclopedique", "topic": "Indépendances africaines", "subtopic": "Chronologie et Burkina Faso", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 600, false
);
