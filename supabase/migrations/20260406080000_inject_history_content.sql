-- Injection contenu historique fiable — Prep Concours BF (Part 1/3)
-- Guerres mondiales + Guerre froide

DO $$
DECLARE v_doc_id UUID;
BEGIN
  INSERT INTO app.prep_source_documents (id, doc_type, source_type, status, extracted_text, created_at, updated_at)
  VALUES (gen_random_uuid(), 'cours', 'text', 'indexed',
    'Contenu historique fiable pour préparation concours — Guerres mondiales, Guerre froide', now(), now())
  RETURNING id INTO v_doc_id;

  INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction) VALUES
  (gen_random_uuid(), v_doc_id, 0,
$c$PREMIÈRE GUERRE MONDIALE (1914-1918) — CAUSES ET ALLIANCES

La Première Guerre mondiale est un conflit armé entre le 28 juillet 1914 et le 11 novembre 1918.

CAUSES : 1) Nationalisme exacerbé (pangermanisme, panslavisme). 2) Impérialisme colonial (crises marocaines 1905, 1911). 3) Course aux armements (course navale Allemagne-UK). 4) Système d'alliances : Triple-Alliance (1882 : Allemagne, Autriche-Hongrie, Italie) vs Triple-Entente (1907 : France, UK, Russie).

CAUSE IMMÉDIATE : Assassinat de l'archiduc François-Ferdinand à Sarajevo le 28 juin 1914 par Gavrilo Princip.

DÉCLENCHEMENT : 28/7/1914 Autriche→Serbie, 1/8 Allemagne→Russie, 3/8 Allemagne→France, 4/8 UK entre en guerre.

BELLIGÉRANTS : Entente (France, UK, Russie, Italie 1915, USA 1917, 27 nations) vs Centraux (Allemagne, Autriche-Hongrie, Empire ottoman, Bulgarie). 70 millions de mobilisés.$c$,
  '{"source":"encyclopedique","topic":"WWI","subtopic":"causes"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 300, false),

  (gen_random_uuid(), v_doc_id, 1,
$c$PREMIÈRE GUERRE MONDIALE — DÉROULEMENT

GUERRE DE MOUVEMENT (1914) : Plan Schlieffen, invasion par la Belgique. Bataille de la Marne (5-12 sept 1914) : Joffre arrête les Allemands à 40 km de Paris. Front Est : défaites russes (Tannenberg).

GUERRE DE TRANCHÉES (1915-1917) : 700 km de la mer du Nord à la Suisse. Verdun (21 fév-18 déc 1916) : 700 000 victimes, résistance française (Pétain). Somme (1er juil-18 nov 1916) : 1 million de victimes, premiers chars britanniques. Génocide arménien (1915-1916) : 1,2-1,5 million de morts.

TOURNANTS 1917 : Révolutions russes (fév/oct), armistice Brest-Litovsk (mars 1918). USA entrent en guerre (6 avril 1917, guerre sous-marine, télégramme Zimmermann). Mutineries françaises après échec Nivelle.

INNOVATIONS : Gaz chimiques, aviation, chars d'assaut, sous-marins (U-Boot), artillerie lourde.$c$,
  '{"source":"encyclopedique","topic":"WWI","subtopic":"déroulement"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 280, false),

  (gen_random_uuid(), v_doc_id, 2,
$c$PREMIÈRE GUERRE MONDIALE — FIN ET CONSÉQUENCES

FIN : Offensive Ludendorff (printemps 1918) échoue. Renforts US (2M soldats). Bataille d'Amiens (8 août 1918). Abdication Kaiser Guillaume II (9 nov). Armistice 11 novembre 1918, 11h, wagon de Rethondes.

BILAN : 10M morts militaires, 8M civils, 21M blessés. France : 1,4M morts (27% des 18-27 ans). Allemagne : 2M. Russie : 1,7M. UK : 900 000.

TRAITÉ DE VERSAILLES (28 juin 1919) : 1) Allemagne « responsable » (art. 231). 2) 132 milliards marks-or de réparations. 3) Pertes territoriales (Alsace-Lorraine, Dantzig). 4) Armée limitée à 100 000 hommes. 5) Création SDN (10 janv 1920, Genève).

CONSÉQUENCES : 4 empires disparaissent (allemand, austro-hongrois, russe, ottoman). Nouveaux États (Pologne, Tchécoslovaquie, Yougoslavie). URSS (1922). Frustrations allemandes → nazisme. Afrique : 2M+ d'Africains mobilisés (tirailleurs sénégalais). Colonies allemandes (Togo, Cameroun, Tanganyika, Namibie) redistribuées sous mandats SDN.$c$,
  '{"source":"encyclopedique","topic":"WWI","subtopic":"fin_consequences"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 320, false),

  (gen_random_uuid(), v_doc_id, 3,
$c$SECONDE GUERRE MONDIALE (1939-1945) — CAUSES

Conflit le plus meurtrier : 60+ nations, 70-85 millions de morts.

CAUSES : 1) Traité de Versailles (humiliation, réparations). 2) Crise de 1929 (krach 24 oct, 6M chômeurs en Allemagne 1932). 3) Totalitarismes : Mussolini (fascisme, 1922), Hitler (NSDAP, chancelier 30 janv 1933 — racisme, antisémitisme, Lebensraum), Japon militariste (Mandchourie 1931, Chine 1937). 4) SDN impuissante, politique d'apaisement, Accords de Munich (30 sept 1938). 5) Expansionnisme hitlérien : Nuremberg (1935), Rhénanie (1936), Anschluss (mars 1938), Tchécoslovaquie (mars 1939), Pacte germano-soviétique (23 août 1939).

DÉCLENCHEMENT : 1er septembre 1939, Blitzkrieg en Pologne. 3 septembre : France et UK déclarent la guerre.$c$,
  '{"source":"encyclopedique","topic":"WWII","subtopic":"causes"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 260, false),

  (gen_random_uuid(), v_doc_id, 4,
$c$SECONDE GUERRE MONDIALE — PHASE 1 : AXE VICTORIEUX (1939-1942)

Alliés : France, UK, URSS (juin 1941), USA (déc 1941), Chine. Axe : Allemagne, Italie, Japon.

EUROPE : Pologne (5 sem). Drôle de guerre (oct 1939-avr 1940). Bataille de France (mai-juin 1940) : percée Sedan, débâcle. Armistice 22 juin 1940 (Vichy/Pétain). Appel de Gaulle 18 juin 1940. Bataille d'Angleterre (juil-oct 1940) : RAF résiste.

BARBAROSSA (22 juin 1941) : 3,8M soldats. Stoppée devant Moscou (déc 1941).

PACIFIQUE : Pearl Harbor (7 déc 1941) → USA en guerre. Japon conquiert Philippines, Malaisie, Singapour, Indonésie, Birmanie.

SHOAH : Wannsee (20 janv 1942) : « Solution finale ». 6 camps d'extermination (Auschwitz-Birkenau, Treblinka, Sobibor, Belzec, Chelmno, Majdanek). 6 millions de Juifs assassinés. Autres victimes : Roms (500 000), handicapés, homosexuels.$c$,
  '{"source":"encyclopedique","topic":"WWII","subtopic":"phase1_axe"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 280, false),

  (gen_random_uuid(), v_doc_id, 5,
$c$SECONDE GUERRE MONDIALE — PHASE 2 : VICTOIRE ALLIÉE (1943-1945)

TOURNANTS : Stalingrad (août 1942-fév 1943, 2M victimes). Midway (juin 1942, 4 porte-avions japonais détruits). El-Alamein (oct-nov 1942, Montgomery vs Rommel).

LIBÉRATION : Afrique du Nord (nov 1942, Torch). Sicile (juil 1943), chute Mussolini (25 juil). JOUR J 6 juin 1944 : Normandie (Overlord), 156 000 soldats, 5 plages, Eisenhower. Provence (15 août). Paris libéré (25 août 1944). Koursk (été 1943) : plus grande bataille de chars.

CONFÉRENCES : Téhéran (nov 1943), Yalta (fév 1945), Potsdam (juil 1945).

FIN : Suicide Hitler (30 avr 1945). Capitulation Allemagne 8 mai 1945. Hiroshima (6 août, 80 000 morts). Nagasaki (9 août, 40 000 morts). Capitulation Japon 2 sept 1945.$c$,
  '{"source":"encyclopedique","topic":"WWII","subtopic":"phase2_allies"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 260, false),

  (gen_random_uuid(), v_doc_id, 6,
$c$SECONDE GUERRE MONDIALE — BILAN ET CONSÉQUENCES

BILAN : 70-85M morts. URSS 27M, Chine 15-20M, Allemagne 7-9M, Pologne 6M, Japon 2,5-3M, France 567 000, UK 450 000, USA 418 000. 60M+ déplacés.

CONSÉQUENCES : 1) ONU créée (26 juin 1945, San Francisco, 51 membres). 2) USA et URSS superpuissances → Guerre froide. 3) Déclin empires coloniaux → indépendances. 4) Nuremberg (1945-46) : 24 nazis jugés, 12 condamnés à mort. 5) Plan Marshall (1948, 13 Md$). 6) Création Israël (14 mai 1948). 7) Allemagne divisée : RFA/RDA (1949). 8) DUDH (10 déc 1948).

AFRIQUE : 1M+ Africains mobilisés. Conférence Brazzaville (janv 1944). Massacre Thiaroye (1er déc 1944) : tirailleurs tués réclamant leurs soldes. Les sacrifices renforcent les revendications indépendantistes.$c$,
  '{"source":"encyclopedique","topic":"WWII","subtopic":"bilan"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 280, false),

  (gen_random_uuid(), v_doc_id, 7,
$c$GUERRE FROIDE (1947-1991) — ORIGINES ET BIPOLARISATION

Tensions USA (capitalisme) vs URSS (communisme), 1947-1991, sans affrontement direct.

ORIGINES : Churchill « rideau de fer » (Fulton, 5 mars 1946). Doctrine Truman (12 mars 1947) : containment. Plan Marshall (5 juin 1947, 13 Md$). Réplique : Jdanov, Kominform, Comecon.

BLOCS : Occidental = OTAN (4 avr 1949, art. 5), démocratie, marché. Soviétique = Pacte de Varsovie (14 mai 1955), parti unique, planification.

NON-ALIGNÉS : Bandung (avr 1955, 29 pays : Nehru, Nasser, Sukarno, Tito). Belgrade 1961. Burkina Faso sous Sankara (1983-87) : non-alignement.$c$,
  '{"source":"encyclopedique","topic":"Guerre froide","subtopic":"origines"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 220, false),

  (gen_random_uuid(), v_doc_id, 8,
$c$GUERRE FROIDE — CRISES MAJEURES

1) BERLIN (1948-49) : Blocus soviétique, pont aérien allié (278 000 vols). RFA/RDA (1949). Mur (13 août 1961).
2) CORÉE (1950-53) : Nord envahit Sud. Coalition ONU (USA) vs Chine. Panmunjom. 2,5-3M morts.
3) SUEZ (1956) : Nasser nationalise. Intervention franco-britannique. Pression USA/URSS → retrait.
4) CUBA (oct 1962) : Missiles soviétiques. Blocus Kennedy. Retrait. « Téléphone rouge ». Plus proche de la guerre nucléaire.
5) VIETNAM (1955-75) : Nord (URSS/Chine) vs Sud (USA). 58 000 US tués, 2-3M Vietnamiens. Paris (1973). Saïgon (30 avr 1975).
6) AFGHANISTAN (1979-89) : URSS envahit. Moudjahidines (USA). Retrait 1989. « Vietnam de l'URSS ».$c$,
  '{"source":"encyclopedique","topic":"Guerre froide","subtopic":"crises"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 240, false),

  (gen_random_uuid(), v_doc_id, 9,
$c$GUERRE FROIDE — FIN ET CONSÉQUENCES

DÉTENTE (1962-79) : TNP (1968), SALT I (1972), Helsinki (1975), Ostpolitik (Brandt).

GORBATCHEV (1985-91) : Glasnost + Perestroïka. FNI (1987). Retrait Afghanistan.

CHUTE : 1989 révolutions (Pologne, Hongrie, Tchécoslovaquie, Roumanie). Mur de Berlin (9 nov 1989). Réunification Allemagne (3 oct 1990). Coup raté août 1991. Dissolution URSS (25-26 déc 1991). 15 républiques indépendantes.

CONSÉQUENCES : USA seule superpuissance. Extension OTAN. Mondialisation. Afrique : fin soutien soviétique, transitions démocratiques (conférences nationales — Bénin 1990).$c$,
  '{"source":"encyclopedique","topic":"Guerre froide","subtopic":"fin"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 200, false);

END $$;
