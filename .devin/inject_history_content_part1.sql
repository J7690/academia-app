-- ═══════════════════════════════════════════════════════════════════════════
-- INJECTION CONTENU HISTORIQUE FIABLE — PRÉPARATION CONCOURS BURKINA FASO
-- Part 1/3 : Guerres mondiales + Guerre froide
-- Exécuter dans Supabase Dashboard > SQL Editor
-- Sources : Encyclopédie Universalis, ONU, UNESCO, Larousse, Britannica
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── PREMIÈRE GUERRE MONDIALE (1914-1918) ───────────────────────────────

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 0,
  $body$PREMIÈRE GUERRE MONDIALE (1914-1918) — CAUSES ET ALLIANCES

La Première Guerre mondiale, aussi appelée « Grande Guerre », est un conflit armé qui a impliqué la plupart des grandes puissances mondiales entre le 28 juillet 1914 et le 11 novembre 1918.

CAUSES PROFONDES :
1. Le nationalisme exacerbé : montée des revendications nationales en Europe (pangermanisme, panslavisme, irrédentisme italien).
2. L'impérialisme colonial : rivalités entre puissances européennes pour le contrôle de territoires en Afrique et en Asie (crises marocaines de 1905 et 1911).
3. La course aux armements : développement massif des arsenaux militaires, notamment entre l'Allemagne et le Royaume-Uni (course navale dreadnought).
4. Le système d'alliances : deux blocs antagonistes se forment progressivement :
   - La Triple-Alliance (1882) : Allemagne, Autriche-Hongrie, Italie
   - La Triple-Entente (1907) : France, Royaume-Uni, Russie

CAUSE IMMÉDIATE :
L'assassinat de l'archiduc François-Ferdinand d'Autriche-Hongrie à Sarajevo le 28 juin 1914 par Gavrilo Princip, un nationaliste serbe bosniaque. L'Autriche-Hongrie adresse un ultimatum à la Serbie le 23 juillet, déclenchant le jeu des alliances.

CHRONOLOGIE DU DÉCLENCHEMENT :
- 28 juillet 1914 : L'Autriche-Hongrie déclare la guerre à la Serbie
- 1er août 1914 : L'Allemagne déclare la guerre à la Russie
- 3 août 1914 : L'Allemagne déclare la guerre à la France
- 4 août 1914 : Le Royaume-Uni entre en guerre après l'invasion de la Belgique neutre par l'Allemagne

BELLIGÉRANTS :
- Puissances de l'Entente : France, Royaume-Uni, Russie, puis Italie (1915), États-Unis (1917), et 27 nations au total
- Puissances centrales : Allemagne, Autriche-Hongrie, Empire ottoman (1914), Bulgarie (1915)

Plus de 70 millions de militaires ont été mobilisés durant ce conflit, dont 60 millions d'Européens.$body$,
  '{"source": "encyclopedique", "topic": "Première Guerre mondiale", "subtopic": "Causes et alliances", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 420, false
);

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 1,
  $body$PREMIÈRE GUERRE MONDIALE (1914-1918) — DÉROULEMENT ET BATAILLES CLÉS

PHASE 1 — GUERRE DE MOUVEMENT (août-novembre 1914) :
- Plan Schlieffen : l'Allemagne envahit la France via la Belgique pour éviter une guerre sur deux fronts.
- Bataille de la Marne (5-12 septembre 1914) : les troupes françaises et britanniques arrêtent l'avancée allemande à 40 km de Paris. Le général Joffre coordonne la contre-offensive. Victoire décisive de l'Entente.
- Front Est : la Russie envahit la Prusse orientale mais subit de lourdes défaites (Tannenberg, août 1914).

PHASE 2 — GUERRE DE POSITION / TRANCHÉES (1915-1917) :
- Le front se stabilise sur 700 km de tranchées de la mer du Nord à la Suisse.
- Conditions atroces : boue, rats, gaz moutarde (première utilisation par les Allemands à Ypres en avril 1915), maladies.
- Bataille de Verdun (21 février - 18 décembre 1916) : offensive allemande visant à « saigner à blanc » l'armée française. 700 000 victimes (morts, blessés, disparus). Symbole de la résistance française sous le commandement de Pétain puis Nivelle.
- Bataille de la Somme (1er juillet - 18 novembre 1916) : offensive franco-britannique. Premier emploi du char d'assaut (tank) par les Britanniques le 15 septembre 1916. Plus d'un million de victimes au total.
- Genocide arménien (1915-1916) : le gouvernement ottoman organise la déportation et le massacre systématique de 1,2 à 1,5 million d'Arméniens.

PHASE 3 — TOURNANTS DE 1917 :
- Février-octobre 1917 : Révolutions russes. Le tsar Nicolas II abdique (février). Les bolcheviks de Lénine prennent le pouvoir (octobre) et signent l'armistice de Brest-Litovsk avec l'Allemagne (mars 1918).
- 6 avril 1917 : Les États-Unis entrent en guerre après la guerre sous-marine à outrance allemande et le télégramme Zimmermann.
- Mutineries dans l'armée française (mai-juin 1917) après l'échec de l'offensive Nivelle au Chemin des Dames.

INNOVATIONS MILITAIRES :
- Armes chimiques (gaz chlore, gaz moutarde)
- Aviation militaire (combats aériens, bombardements)
- Chars d'assaut (tanks)
- Sous-marins (U-Boot allemands)
- Artillerie lourde à longue portée$body$,
  '{"source": "encyclopedique", "topic": "Première Guerre mondiale", "subtopic": "Déroulement", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 480, false
);

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 2,
  $body$PREMIÈRE GUERRE MONDIALE (1914-1918) — FIN ET CONSÉQUENCES

FIN DE LA GUERRE :
- Printemps 1918 : dernières offensives allemandes (offensive Ludendorff) mais les renforts américains (2 millions de soldats) renversent la situation.
- Été-automne 1918 : contre-offensives alliées victorieuses (Bataille d'Amiens, 8 août 1918 — « jour de deuil de l'armée allemande » selon Ludendorff).
- 9 novembre 1918 : abdication du Kaiser Guillaume II d'Allemagne, proclamation de la République.
- 11 novembre 1918, 11h00 : signature de l'Armistice dans le wagon de Rethondes (forêt de Compiègne).

BILAN HUMAIN :
- Environ 10 millions de morts militaires et 8 millions de civils
- 21 millions de blessés
- France : 1,4 million de morts (27% des 18-27 ans), 4 millions de blessés
- Allemagne : 2 millions de morts
- Russie : 1,7 million de morts
- Royaume-Uni : 900 000 morts
- Apparition des « gueules cassées » (mutilés du visage)

TRAITÉ DE VERSAILLES (28 JUIN 1919) :
Signé dans la Galerie des Glaces du château de Versailles. Principales dispositions :
1. L'Allemagne reconnue « responsable de la guerre » (article 231 — clause de culpabilité)
2. Lourdes réparations financières : 132 milliards de marks-or
3. Pertes territoriales : Alsace-Lorraine rendue à la France, couloir de Dantzig à la Pologne, colonies redistribuées
4. Démilitarisation : armée allemande limitée à 100 000 hommes, interdiction de posséder des chars, avions, sous-marins
5. Création de la Société des Nations (SDN) le 10 janvier 1920, précurseur de l'ONU, siège à Genève

AUTRES TRAITÉS DE PAIX :
- Traité de Saint-Germain (1919) : avec l'Autriche
- Traité de Trianon (1920) : avec la Hongrie
- Traité de Neuilly (1919) : avec la Bulgarie
- Traité de Sèvres (1920) puis Lausanne (1923) : avec l'Empire ottoman/Turquie

CONSÉQUENCES GÉOPOLITIQUES :
- Disparition de 4 empires : allemand, austro-hongrois, russe, ottoman
- Création de nouveaux États : Pologne, Tchécoslovaquie, Yougoslavie, pays baltes
- Montée du communisme (URSS fondée en 1922)
- Frustrations allemandes qui nourriront le nazisme
- Mandat français et britannique sur les anciennes colonies ottomanes (Syrie, Liban, Palestine, Irak)
- L'Afrique : plus de 2 millions d'Africains mobilisés (tirailleurs sénégalais, combattants d'Afrique du Nord). Les colonies allemandes (Togo, Cameroun, Tanganyika, Namibie) redistribuées aux Alliés sous mandats de la SDN.$body$,
  '{"source": "encyclopedique", "topic": "Première Guerre mondiale", "subtopic": "Fin et conséquences", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 560, false
);

-- ─── SECONDE GUERRE MONDIALE (1939-1945) ────────────────────────────────

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 3,
  $body$SECONDE GUERRE MONDIALE (1939-1945) — CAUSES ET MONTÉE DES TOTALITARISMES

La Seconde Guerre mondiale est le conflit armé le plus vaste et le plus meurtrier de l'histoire humaine. Il a impliqué plus de 60 nations et causé entre 70 et 85 millions de morts.

CAUSES PROFONDES :

1. Conséquences du Traité de Versailles (1919) :
   - Humiliation et ressentiment en Allemagne (« Diktat de Versailles »)
   - Crise économique liée aux réparations de guerre
   - Sentiment de revanche (revanchisme)

2. Crise économique mondiale de 1929 :
   - Krach boursier de Wall Street (24 octobre 1929 — « Jeudi noir »)
   - Chômage massif en Europe (6 millions de chômeurs en Allemagne en 1932)
   - Montée des extrémismes politiques

3. Montée des totalitarismes :
   - Italie : Benito Mussolini fonde le fascisme, au pouvoir depuis 1922 (Marche sur Rome)
   - Allemagne : Adolf Hitler, chef du NSDAP (parti nazi), nommé chancelier le 30 janvier 1933. Idéologie fondée sur le racisme, l'antisémitisme, le pangermanisme et le Lebensraum (« espace vital »)
   - Japon : militarisme expansionniste. Invasion de la Mandchourie (1931), puis de la Chine (1937)

4. Échec de la sécurité collective :
   - La Société des Nations (SDN) impuissante face aux agressions
   - Politique d'appeasement (apaisement) de la France et du Royaume-Uni
   - Accords de Munich (30 septembre 1938) : la France et le Royaume-Uni acceptent l'annexion des Sudètes (Tchécoslovaquie) par Hitler. Phrase de Daladier : « Les c... »

5. Expansionnisme hitlérien :
   - 1935 : réarmement de l'Allemagne, lois de Nuremberg (lois antisémites)
   - Mars 1936 : remilitarisation de la Rhénanie
   - Mars 1938 : Anschluss (annexion de l'Autriche)
   - Mars 1939 : invasion de la Tchécoslovaquie
   - 23 août 1939 : Pacte germano-soviétique (Molotov-Ribbentrop) — accord de non-agression et partage secret de la Pologne et des pays baltes

DÉCLENCHEMENT :
Le 1er septembre 1939, l'Allemagne nazie envahit la Pologne (Blitzkrieg — « guerre éclair »).
Le 3 septembre 1939, la France et le Royaume-Uni déclarent la guerre à l'Allemagne.$body$,
  '{"source": "encyclopedique", "topic": "Seconde Guerre mondiale", "subtopic": "Causes et totalitarismes", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 500, false
);

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 4,
  $body$SECONDE GUERRE MONDIALE (1939-1945) — DÉROULEMENT PHASE 1 : VICTOIRES DE L'AXE (1939-1942)

BELLIGÉRANTS :
- Alliés : France, Royaume-Uni, URSS (juin 1941), États-Unis (décembre 1941), Chine, et 26+ nations
- Axe : Allemagne, Italie, Japon, et satellites (Hongrie, Roumanie, Bulgarie, Finlande)

FRONT EUROPÉEN (1939-1941) :
- Septembre 1939 : conquête de la Pologne en 5 semaines (Blitzkrieg). L'URSS envahit l'est de la Pologne (clause secrète du pacte Molotov-Ribbentrop).
- Octobre 1939 - avril 1940 : « Drôle de guerre » — front statique entre la France et l'Allemagne.
- Avril-juin 1940 : l'Allemagne envahit le Danemark, la Norvège, puis les Pays-Bas, la Belgique, le Luxembourg.
- Mai-juin 1940 : Bataille de France. L'armée allemande perce à Sedan (13 mai), contourne la ligne Maginot par les Ardennes. Débâcle française, exode de 8 millions de civils.
- 22 juin 1940 : Armistice franco-allemand signé à Rethondes. La France est divisée : zone occupée (nord) et zone « libre » sous le régime de Vichy dirigé par le maréchal Pétain.
- 18 juin 1940 : Appel du général de Gaulle depuis Londres — naissance de la France Libre.
- Juillet-octobre 1940 : Bataille d'Angleterre. La RAF résiste aux bombardements de la Luftwaffe. Churchill : « Jamais dans l'histoire des conflits humains, tant de gens n'ont dû autant à si peu. »

OPÉRATION BARBAROSSA (22 JUIN 1941) :
L'Allemagne envahit l'URSS avec 3,8 millions de soldats. Avancée rapide mais l'hiver et la résistance soviétique stoppent l'offensive devant Moscou (décembre 1941).

FRONT PACIFIQUE :
- 7 décembre 1941 : attaque japonaise sur Pearl Harbor (Hawaï). Les États-Unis entrent en guerre.
- Le Japon conquiert les Philippines, la Malaisie, Singapour, l'Indonésie, la Birmanie (décembre 1941 - mai 1942).

LA SHOAH :
- Politique d'extermination systématique des Juifs d'Europe par le régime nazi.
- Conférence de Wannsee (20 janvier 1942) : planification de la « Solution finale ».
- 6 principaux camps d'extermination : Auschwitz-Birkenau, Treblinka, Sobibor, Belzec, Chelmno, Majdanek.
- Bilan : environ 6 millions de Juifs assassinés (2/3 des Juifs d'Europe).
- Autres victimes du génocide nazi : Roms (500 000), handicapés, homosexuels, opposants politiques, prisonniers de guerre soviétiques.$body$,
  '{"source": "encyclopedique", "topic": "Seconde Guerre mondiale", "subtopic": "Phase 1 Axe victorieux", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 540, false
);

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 5,
  $body$SECONDE GUERRE MONDIALE (1939-1945) — PHASE 2 : TOURNANT ET VICTOIRE DES ALLIÉS (1943-1945)

TOURNANTS DÉCISIFS :

1. Bataille de Stalingrad (août 1942 - février 1943) :
   - L'armée allemande (6e armée, général Paulus) assiège Stalingrad.
   - Contre-offensive soviétique (opération Uranus) : encerclement et capitulation de 91 000 soldats allemands le 2 février 1943.
   - Tournant majeur sur le front Est. Plus de 2 millions de victimes.

2. Bataille de Midway (4-7 juin 1942) :
   - Victoire navale américaine décisive dans le Pacifique.
   - Destruction de 4 porte-avions japonais.
   - Renversement du rapport de forces dans le Pacifique.

3. Bataille d'El-Alamein (octobre-novembre 1942) :
   - Victoire britannique (général Montgomery) contre l'Afrika Korps de Rommel en Égypte.
   - Fin de la menace sur le canal de Suez.

LIBÉRATION DE L'EUROPE :
- Novembre 1942 : Débarquement allié en Afrique du Nord (opération Torch).
- Juillet 1943 : Débarquement en Sicile, puis en Italie. Chute de Mussolini (25 juillet 1943).
- 6 juin 1944 — JOUR J (D-Day) : Débarquement de Normandie (opération Overlord). Plus de 156 000 soldats alliés débarquent sur 5 plages (Utah, Omaha, Gold, Juno, Sword). Plus grande opération amphibie de l'histoire. Commandement : général Eisenhower.
- 15 août 1944 : Débarquement de Provence (sud de la France).
- 25 août 1944 : Libération de Paris. Le général de Gaulle descend les Champs-Élysées.
- Décembre 1944 : dernière contre-offensive allemande dans les Ardennes (Bataille des Ardennes).

FRONT EST :
- Été 1943 : Bataille de Koursk, plus grande bataille de chars de l'histoire. Victoire soviétique.
- 1944-1945 : l'Armée rouge avance vers Berlin, libérant la Pologne, la Roumanie, la Hongrie.

CONFÉRENCES DES ALLIÉS :
- Téhéran (novembre 1943) : Roosevelt, Churchill, Staline planifient le débarquement.
- Yalta (février 1945) : partage des zones d'influence en Europe, engagement soviétique contre le Japon.
- Potsdam (juillet 1945) : gestion de l'Allemagne vaincue, ultimatum au Japon.

FIN DE LA GUERRE :
- 30 avril 1945 : suicide d'Adolf Hitler dans son bunker à Berlin.
- 8 mai 1945 : capitulation inconditionnelle de l'Allemagne (V-E Day).
- 6 août 1945 : bombe atomique américaine sur Hiroshima (80 000 morts immédiats).
- 9 août 1945 : bombe atomique sur Nagasaki (40 000 morts immédiats).
- 2 septembre 1945 : capitulation du Japon (V-J Day). Fin officielle de la Seconde Guerre mondiale.$body$,
  '{"source": "encyclopedique", "topic": "Seconde Guerre mondiale", "subtopic": "Phase 2 victoire Alliés", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 580, false
);

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 6,
  $body$SECONDE GUERRE MONDIALE (1939-1945) — BILAN ET CONSÉQUENCES

BILAN HUMAIN (estimations) :
- 70 à 85 millions de morts au total (militaires et civils)
- URSS : 27 millions de morts (dont 14 millions de civils)
- Chine : 15 à 20 millions de morts
- Allemagne : 7 à 9 millions de morts
- Pologne : 6 millions de morts (dont 3 millions de Juifs)
- Japon : 2,5 à 3 millions de morts
- France : 567 000 morts
- Royaume-Uni : 450 000 morts
- États-Unis : 418 000 morts
- Plus de 60 millions de personnes déplacées en Europe

BILAN MATÉRIEL :
- Villes entièrement détruites : Stalingrad, Varsovie, Dresde, Hiroshima, Nagasaki
- Infrastructures européennes et asiatiques dévastées
- Coût estimé : 1 000 milliards de dollars de l'époque

CONSÉQUENCES GÉOPOLITIQUES :
1. Création de l'ONU (Organisation des Nations Unies) : Charte signée le 26 juin 1945 à San Francisco, entrée en vigueur le 24 octobre 1945. 51 membres fondateurs. Siège : New York.
2. Émergence de deux superpuissances : États-Unis et URSS → début de la Guerre froide.
3. Déclin des empires coloniaux européens : mouvements d'indépendance en Afrique et en Asie.
4. Procès de Nuremberg (novembre 1945 - octobre 1946) : 24 dirigeants nazis jugés pour crimes de guerre, crimes contre l'humanité et génocide. 12 condamnés à mort.
5. Procès de Tokyo (1946-1948) : jugement des criminels de guerre japonais.
6. Plan Marshall (1948) : aide économique américaine de 13 milliards de dollars pour la reconstruction de l'Europe.
7. Création d'Israël (14 mai 1948) : État juif en Palestine mandataire, source du conflit israélo-arabe.
8. Division de l'Allemagne en 4 zones d'occupation (américaine, britannique, française, soviétique), puis en 2 États : RFA (ouest, 1949) et RDA (est, 1949).
9. Déclaration universelle des droits de l'homme : adoptée le 10 décembre 1948 par l'Assemblée générale des Nations Unies.

IMPACT SUR L'AFRIQUE :
- Plus de 1 million d'Africains mobilisés par les puissances coloniales (tirailleurs sénégalais, forces d'Afrique du Nord).
- Campagnes d'Afrique du Nord et d'Éthiopie.
- Conférence de Brazzaville (janvier-février 1944) : la France Libre discute de l'avenir des colonies africaines. Pas d'indépendance envisagée mais promesses de réformes.
- Les sacrifices des soldats africains renforcent les revendications indépendantistes d'après-guerre.
- Massacre de Thiaroye (1er décembre 1944) : l'armée française tire sur des tirailleurs sénégalais réclamant leurs soldes au Sénégal. Symbole de l'injustice coloniale.$body$,
  '{"source": "encyclopedique", "topic": "Seconde Guerre mondiale", "subtopic": "Bilan et conséquences", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 590, false
);

-- ─── GUERRE FROIDE (1947-1991) ──────────────────────────────────────────

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 7,
  $body$LA GUERRE FROIDE (1947-1991) — ORIGINES ET BIPOLARISATION

La Guerre froide désigne la période de tensions géopolitiques et idéologiques entre les États-Unis (bloc occidental/capitaliste) et l'URSS (bloc soviétique/communiste) de 1947 à 1991, sans affrontement militaire direct entre les deux superpuissances.

ORIGINES (1945-1947) :
- Divergences idéologiques : capitalisme libéral (USA) vs communisme marxiste-léniniste (URSS)
- Désaccords sur le sort de l'Europe d'après-guerre : élections libres vs démocraties populaires
- Discours de Churchill à Fulton (5 mars 1946) : dénonce le « rideau de fer » qui s'abat sur l'Europe
- Doctrine Truman (12 mars 1947) : politique américaine d'endiguement (containment) du communisme. Aide militaire et économique aux pays menacés.
- Plan Marshall (5 juin 1947) : aide économique américaine à l'Europe (13 milliards de dollars). Refusé par l'URSS et ses satellites.
- Réplique soviétique : Doctrine Jdanov (septembre 1947), création du Kominform (bureau d'information des partis communistes), puis du CAEM/Comecon (1949).

BIPOLARISATION DU MONDE :

Bloc occidental :
- OTAN (Organisation du Traité de l'Atlantique Nord) : créée le 4 avril 1949. Membres fondateurs : USA, Canada, 10 pays européens. Article 5 : clause de défense collective.
- Économie de marché, démocratie libérale, droits individuels
- Influence en Europe de l'Ouest, Amérique latine, Asie du Sud-Est

Bloc soviétique :
- Pacte de Varsovie (14 mai 1955) : alliance militaire de l'URSS et des démocraties populaires d'Europe de l'Est (Pologne, RDA, Tchécoslovaquie, Hongrie, Roumanie, Bulgarie, Albanie).
- Économie planifiée, parti unique, collectivisation
- Influence en Europe de l'Est, Chine (jusqu'en 1960), Cuba, certains pays africains et asiatiques

MOUVEMENT DES NON-ALIGNÉS :
- Conférence de Bandung (Indonésie, avril 1955) : 29 pays afro-asiatiques refusent l'alignement sur un bloc. Leaders : Nehru (Inde), Nasser (Égypte), Sukarno (Indonésie), Tito (Yougoslavie).
- Création officielle du Mouvement des non-alignés à Belgrade (1961).
- Le Burkina Faso sous Thomas Sankara (1983-1987) s'inscrit dans une politique de non-alignement et d'indépendance vis-à-vis des blocs.$body$,
  '{"source": "encyclopedique", "topic": "Guerre froide", "subtopic": "Origines et bipolarisation", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 500, false
);

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 8,
  $body$LA GUERRE FROIDE (1947-1991) — CRISES MAJEURES

1. BLOCUS DE BERLIN (juin 1948 - mai 1949) :
- L'URSS bloque les accès terrestres à Berlin-Ouest pour forcer les Occidentaux à quitter la ville.
- Réponse : pont aérien américain et britannique (278 000 vols, 2,3 millions de tonnes de ravitaillement).
- Conséquence : création de la RFA (mai 1949) et de la RDA (octobre 1949). Construction du Mur de Berlin le 13 août 1961 (symbole de la division du monde).

2. GUERRE DE CORÉE (1950-1953) :
- 25 juin 1950 : la Corée du Nord (communiste) envahit la Corée du Sud.
- Intervention d'une coalition ONU menée par les USA (général MacArthur).
- La Chine intervient aux côtés du Nord (novembre 1950).
- Armistice de Panmunjom (27 juillet 1953). La Corée reste divisée au 38e parallèle.
- Bilan : 2,5 à 3 millions de morts.

3. CRISE DE SUEZ (1956) :
- Le président égyptien Nasser nationalise le canal de Suez (26 juillet 1956).
- Intervention militaire franco-britannique et israélienne.
- Pression conjointe des USA et de l'URSS force le retrait. Victoire diplomatique de Nasser.

4. CRISE DES MISSILES DE CUBA (16-28 octobre 1962) :
- L'URSS (Khrouchtchev) installe des missiles nucléaires à Cuba, à 150 km des côtes américaines.
- Le président Kennedy ordonne un blocus naval de Cuba.
- Négociations secrètes : l'URSS retire ses missiles, les USA s'engagent à ne pas envahir Cuba et retirent des missiles de Turquie.
- Moment le plus proche d'une guerre nucléaire. Création du « téléphone rouge » Moscou-Washington (1963).

5. GUERRE DU VIETNAM (1955-1975) :
- Conflit entre le Vietnam du Nord (communiste, soutenu par l'URSS et la Chine) et le Vietnam du Sud (soutenu par les USA).
- Engagement massif des USA (1965-1973) : 58 000 soldats américains tués, 2 à 3 millions de Vietnamiens morts.
- Offensive du Têt (1968), opposition croissante aux USA.
- Accords de Paris (27 janvier 1973) : retrait américain.
- 30 avril 1975 : chute de Saïgon, réunification du Vietnam sous régime communiste.

6. INVASION DE L'AFGHANISTAN (1979-1989) :
- L'URSS envahit l'Afghanistan (décembre 1979) pour soutenir le gouvernement communiste.
- Résistance des moudjahidines soutenus par les USA, le Pakistan et l'Arabie saoudite.
- Retrait soviétique en février 1989. « Vietnam de l'URSS ». 15 000 soldats soviétiques tués, 1 million de civils afghans morts.$body$,
  '{"source": "encyclopedique", "topic": "Guerre froide", "subtopic": "Crises majeures", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 560, false
);

INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction)
VALUES (
  gen_random_uuid(), NULL, 9,
  $body$LA GUERRE FROIDE (1947-1991) — DÉTENTE ET FIN

LA DÉTENTE (1962-1979) :
- Après la crise de Cuba, les deux blocs cherchent à éviter une confrontation nucléaire directe.
- Traité d'interdiction partielle des essais nucléaires (1963).
- Traité de non-prolifération nucléaire (TNP, 1968).
- Accords SALT I (1972) : limitation des armes stratégiques entre USA (Nixon) et URSS (Brejnev).
- Accords d'Helsinki (1975) : reconnaissance des frontières européennes, engagement sur les droits de l'homme.
- Ostpolitik de Willy Brandt (RFA) : politique de rapprochement avec l'Est.

LA « DEUXIÈME GUERRE FROIDE » (1979-1985) :
- Invasion soviétique de l'Afghanistan (1979), crise des euromissiles, boycotts olympiques (Moscou 1980 par les USA, Los Angeles 1984 par l'URSS).
- Ronald Reagan (président USA 1981-1989) : politique de fermeté, programme « Guerre des étoiles » (IDS — Initiative de défense stratégique).
- Course aux armements ruineuse pour l'économie soviétique.

GORBATCHEV ET LA FIN DE LA GUERRE FROIDE (1985-1991) :
- Mikhaïl Gorbatchev, secrétaire général du PCUS (mars 1985), lance deux réformes majeures :
  • Glasnost (transparence) : liberté d'expression et de presse
  • Perestroïka (restructuration) : réformes économiques vers l'économie de marché
- Traité FNI (1987) : élimination des missiles nucléaires à portée intermédiaire.
- Accords de Genève (1988) : retrait d'Afghanistan.

CHUTE DU BLOC SOVIÉTIQUE (1989-1991) :
- 1989 : révolutions pacifiques en Europe de l'Est (Pologne, Hongrie, Tchécoslovaquie — « Révolution de velours », Roumanie).
- 9 novembre 1989 : chute du Mur de Berlin. Symbole de la fin de la Guerre froide.
- 3 octobre 1990 : réunification de l'Allemagne.
- Août 1991 : tentative de coup d'État à Moscou contre Gorbatchev, échouée grâce à Boris Eltsine.
- 8 décembre 1991 : accords de Minsk — dissolution de l'URSS.
- 25 décembre 1991 : Gorbatchev démissionne. L'URSS cesse officiellement d'exister le 26 décembre 1991.
- 15 républiques soviétiques deviennent indépendantes, dont la Russie, l'Ukraine, la Biélorussie, les pays baltes, les républiques d'Asie centrale.

CONSÉQUENCES :
- Les États-Unis deviennent la seule superpuissance (« moment unipolaire »)
- Extension de l'OTAN vers l'Est
- Multiplication des conflits régionaux (ex-Yougoslavie, Caucase, Afrique)
- Mondialisation économique accélérée
- Impact sur l'Afrique : fin du soutien soviétique à de nombreux régimes, transitions démocratiques (vague de démocratisation des années 1990), conférences nationales souveraines (Bénin 1990, modèle pour l'Afrique francophone).$body$,
  '{"source": "encyclopedique", "topic": "Guerre froide", "subtopic": "Détente et fin", "fiabilite": "haute"}'::jsonb,
  'content', 'Culture Générale', 'TOUS', 580, false
);
