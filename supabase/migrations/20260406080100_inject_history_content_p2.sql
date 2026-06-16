-- Injection contenu historique fiable — Prep Concours BF (Part 2/3)
-- Organisations africaines + Colonisation + Esclavage + Indépendances

DO $$
DECLARE v_doc_id UUID;
BEGIN
  INSERT INTO app.prep_source_documents (id, doc_type, source_type, status, extracted_text, created_at, updated_at)
  VALUES (gen_random_uuid(), 'cours', 'text', 'indexed',
    'Contenu fiable — UA, CEDEAO, UEMOA, EAC, Colonisation, Esclavage, Indépendances africaines', now(), now())
  RETURNING id INTO v_doc_id;

  INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction) VALUES

  (gen_random_uuid(), v_doc_id, 0,
$c$L'UNION AFRICAINE (UA)

OUA fondée le 25 mai 1963 à Addis-Abeba par 32 États. Fondateurs : Nkrumah (Ghana), Haïlé Sélassié (Éthiopie), Modibo Keïta (Mali), Sékou Touré (Guinée). Objectifs : unité, solidarité, élimination du colonialisme, respect frontières héritées (uti possidetis juris). Limite majeure : non-ingérence → incapacité face aux conflits (génocide Rwanda 1994).

TRANSITION : Initiative Kadhafi, Syrte (1999). Acte constitutif adopté à Lomé (11 juil 2000). UA remplace OUA le 9 juillet 2002 (Durban). Innovation : « non-indifférence » (art. 4h : intervention possible en cas de génocide).

55 ÉTATS MEMBRES. Maroc réintégré en janvier 2017.

ORGANES : Conférence chefs d'État, Conseil exécutif, Commission (Addis-Abeba), Parlement panafricain (Midrand), Conseil paix et sécurité, Cour africaine droits de l'homme (Arusha).

PROGRAMMES : Agenda 2063. ZLECAF (signée Kigali 21 mars 2018, 54 pays, 1,3 Md habitants). Force africaine en attente. MAEP.

DÉFIS : financement (60% externe), coups d'État (Mali, Burkina, Niger, Gabon), conflits (Sahel, RDC, Soudan).

Burkina Faso : membre fondateur OUA (1963), membre actif UA.$c$,
  '{"source":"encyclopedique","topic":"Union Africaine"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 320, false),

  (gen_random_uuid(), v_doc_id, 1,
$c$LA CEDEAO — COMMUNAUTÉ ÉCONOMIQUE DES ÉTATS DE L'AFRIQUE DE L'OUEST

Traité de Lagos, 28 mai 1975. Révisé Cotonou 24 juil 1993. Siège : Abuja (Nigeria).

15 ÉTATS : Francophone (Bénin, Burkina Faso, Côte d'Ivoire, Guinée, Mali, Niger, Sénégal, Togo), Anglophone (Gambie, Ghana, Libéria, Nigeria, Sierra Leone), Lusophone (Cap-Vert, Guinée-Bissau). En janv 2024, Burkina, Mali, Niger annoncent leur retrait → Alliance des États du Sahel (AES, 16 sept 2023).

OBJECTIFS : libre circulation personnes/biens, marché commun, harmonisation politiques, paix régionale, monnaie unique ECO.

ORGANES : Conférence chefs d'État, Conseil ministres, Commission, Parlement, Cour de justice, BIDC (Lomé).

SÉCURITÉ (ECOMOG) : Libéria (1990-97), Sierra Leone (1997-2000), Gambie (2017). Protocole Lomé (1999). Protocole démocratie (2001) : interdiction changements anticonstitutionnels.

RÉALISATIONS : TEC (2015), passeport CEDEAO, libre circulation (protocole 1979), infrastructures (autoroute Lagos-Abidjan, WAPP).

DÉFIS : coups d'État récents, terrorisme sahélien, Nigeria = 60%+ du PIB communautaire.$c$,
  '{"source":"encyclopedique","topic":"CEDEAO"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 340, false),

  (gen_random_uuid(), v_doc_id, 2,
$c$L'UEMOA — UNION ÉCONOMIQUE ET MONÉTAIRE OUEST-AFRICAINE

Traité signé 10 janvier 1994 à Dakar. Succède à l'UMOA (1962) et CEAO (1973). Siège Commission : Ouagadougou (Burkina Faso).

8 ÉTATS : Bénin, Burkina Faso, Côte d'Ivoire, Guinée-Bissau (1997), Mali, Niger, Sénégal, Togo. Monnaie : franc CFA (XOF).

OBJECTIFS : compétitivité, convergence, marché commun, coordination sectorielle, harmonisation fiscale.

ORGANES : Conférence chefs d'État, Conseil ministres, Commission (Ouagadougou), Cour de justice (Ouagadougou), Cour des comptes (Ouagadougou), Parlement (Bamako), BCEAO (Dakar), BOAD (Lomé).

FRANC CFA : créé 26 déc 1945. Parité fixe 1 EUR = 655,957 FCFA. Dévaluation 11 janv 1994 (-50%). Réforme déc 2019 : remplacement annoncé par ECO, France se retire du CA BCEAO. Mise en œuvre en attente.

CONVERGENCE : solde budgétaire/PIB ≥ -3%, inflation ≤ 3%, dette/PIB ≤ 70%, masse salariale/recettes ≤ 35%.

Burkina Faso abrite le siège de la Commission UEMOA.$c$,
  '{"source":"encyclopedique","topic":"UEMOA"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 310, false),

  (gen_random_uuid(), v_doc_id, 3,
$c$L'EAC — COMMUNAUTÉ D'AFRIQUE DE L'EST

Première EAC (1967, Kenya/Ouganda/Tanzanie) dissoute 1977. Relancée : traité 30 nov 1999, en vigueur 7 juil 2000. Siège : Arusha (Tanzanie).

7 ÉTATS : Kenya, Ouganda, Tanzanie (2000), Rwanda, Burundi (2007), Soudan du Sud (2016), RD Congo (2022). Population ~300M. PIB ~305 Md$.

ÉTAPES D'INTÉGRATION : union douanière (2005), marché commun (2010), union monétaire (protocole 2013), fédération politique (objectif).

ORGANES : Sommet, Conseil ministres, Secrétariat (Arusha), EALA (parlement), Cour de justice.

RÉALISATIONS : passeport est-africain, réduction barrières tarifaires, chemin de fer SGR.

DÉFIS : instabilité (Burundi, RDC, Soudan du Sud), déséquilibres (Kenya domine), conflits frontaliers. Considérée parmi les CER les plus avancées d'Afrique.$c$,
  '{"source":"encyclopedique","topic":"EAC"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 250, false),

  (gen_random_uuid(), v_doc_id, 4,
$c$LA COLONISATION DE L'AFRIQUE — CAUSES, CONFÉRENCE DE BERLIN ET PARTAGE

Processus de conquête européenne de l'Afrique (1880-1960).

MOTIVATIONS : Économiques (matières premières, débouchés industriels, routes commerciales). Politiques (prestige, rivalités). Idéologiques (« mission civilisatrice » Jules Ferry 1885, darwinisme social, évangélisation, explorations Livingstone/Stanley/Brazza).

CONFÉRENCE DE BERLIN (15 nov 1884 - 26 fév 1885) : Bismarck, 14 nations, aucun Africain. Principes : liberté commerce (Congo, Niger), occupation effective, notification. Congo = propriété Léopold II.

PARTAGE : France (AOF, AEF, Maghreb, Madagascar — plus grand empire). UK (Égypte, Nigeria, Ghana, Kenya, Afrique du Sud). Allemagne (Togo, Cameroun, Tanganyika, Namibie — perdus 1918). Belgique (Congo, Rwanda-Urundi). Portugal (Angola, Mozambique). Italie (Libye, Érythrée, Somalie). Jamais colonisés : Éthiopie (victoire Adoua 1896), Libéria (1847).

SYSTÈMES : Direct (français, assimilation, Code indigénat 1887-1946, travail forcé). Indirect (britannique, indirect rule de Lugard, chefs locaux maintenus).

HAUTE-VOLTA : Ouagadougou pris 1896. Colonie créée 1er mars 1919. Supprimée 1932 (main-d'œuvre Côte d'Ivoire). Reconstituée 4 sept 1947 (Ouezzin Coulibaly, Zinda Kaboré, Nazi Boni). Résistances Bwa-Marka (1915-16).$c$,
  '{"source":"encyclopedique","topic":"Colonisation"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 380, false),

  (gen_random_uuid(), v_doc_id, 5,
$c$L'ESCLAVAGE — TRAITE NÉGRIÈRE ET ABOLITION

TROIS TRAITES : Transsaharienne (VIIe-XXe s., 8-12M). Orientale (VIIe-XIXe s., 5-8M). Transatlantique (XVIe-XIXe s., 12-15M déportés, 1,5-2M morts en mer — base Slave Voyages/UNESCO).

COMMERCE TRIANGULAIRE : 1) Europe→Afrique (armes, alcool, textiles contre captifs). 2) Afrique→Amériques (« passage du milieu », 6-10 sem, mortalité 10-20%). 3) Amériques→Europe (sucre, coton, tabac, café). Zones : Sénégambie, Côte de l'Or, Côte des Esclaves, Congo, Angola. Royaumes impliqués : Dahomey, Ashanti, Oyo. Pays négriers : Portugal/Brésil (~5,8M), UK (~3,2M), France (~1,3M), Espagne (~1M), Pays-Bas (~500K).

ABOLITION : 1794 (1re abolition française, révoquée). Haïti 1804 (1re République noire, seule révolution d'esclaves réussie). UK : traite interdite 1807, esclavage aboli 1833. France : décret Schoelcher 27 avril 1848. USA : 13e amendement 1865. Brésil 1888 (dernier des Amériques).

BILAN : Impact démographique dévastateur. Enrichissement Europe. Racisme systémique. Reconnaissance : loi Taubira 2001 (crime contre l'humanité). 23 août : Journée UNESCO. Route de l'esclave (Ouidah, Bénin). Gorée (Sénégal, patrimoine mondial).$c$,
  '{"source":"encyclopedique","topic":"Esclavage"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 370, false),

  (gen_random_uuid(), v_doc_id, 6,
$c$LES INDÉPENDANCES AFRICAINES — CONTEXTE ET LEADERS

FACTEURS : Guerres mondiales (tirailleurs → prise de conscience). Affaiblissement puissances coloniales. Charte Atlantique (1941). ONU résolution 1514 (1960). Guerre froide (USA/URSS soutiennent décolonisation). Bandung (1955).

LEADERS : Nkrumah (Ghana, 1er indépendant Afrique noire 6 mars 1957). Senghor (Sénégal, Négritude). Sékou Touré (Guinée, « liberté dans la pauvreté », 2 oct 1958). Houphouët-Boigny (RDA 1946). Lumumba (Congo, assassiné janv 1961). Mandela (anti-apartheid). FLN (Algérie 1954-62).$c$,
  '{"source":"encyclopedique","topic":"Indépendances africaines","subtopic":"contexte"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 220, false),

  (gen_random_uuid(), v_doc_id, 7,
$c$INDÉPENDANCES AFRICAINES — CHRONOLOGIE ET BURKINA FASO

1951 Libye. 1956 Soudan, Tunisie, Maroc. 1957 Ghana. 1958 Guinée.

1960 « ANNÉE DE L'AFRIQUE » (17 pays) : Cameroun (1/1), Togo (27/4), Mali, Madagascar (26/6), Congo-Léopoldville (30/6), Somalie (1/7), Dahomey/Bénin (1/8), Niger (3/8), HAUTE-VOLTA/BURKINA (5/8), Côte d'Ivoire (7/8), Tchad (11/8), Centrafrique (13/8), Congo-Brazzaville (15/8), Gabon (17/8), Sénégal (20/8), Mali (22/9), Nigeria (1/10), Mauritanie (28/11).

1962 Algérie (guerre 8 ans, 1,5M morts), Ouganda, Rwanda, Burundi. 1963 Kenya. 1975 Angola, Mozambique, Cap-Vert (Révolution Œillets Portugal). 1990 Namibie. 2011 Soudan du Sud.

BURKINA FASO : Indépendance 5 août 1960. 1er président Maurice Yaméogo (1960-66). Lamizana (1966-80), Zerbo, Ouédraogo. Thomas Sankara (1983-87) : renomme le pays « Burkina Faso » (Pays des hommes intègres, 4 août 1984). Réformes majeures : vaccination, alphabétisation, droits des femmes, autosuffisance alimentaire. Assassiné 15 octobre 1987. Compaoré (1987-2014).$c$,
  '{"source":"encyclopedique","topic":"Indépendances africaines","subtopic":"chronologie_burkina"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 350, false);

END $$;
