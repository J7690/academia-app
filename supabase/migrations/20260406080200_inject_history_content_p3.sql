-- Injection contenu historique fiable — Prep Concours BF (Part 3/3)
-- Catastrophes nucléaires + Guerre en Ukraine + COVID-19

DO $$
DECLARE v_doc_id UUID;
BEGIN
  INSERT INTO app.prep_source_documents (id, doc_type, source_type, status, extracted_text, created_at, updated_at)
  VALUES (gen_random_uuid(), 'cours', 'text', 'indexed',
    'Contenu fiable — Tchernobyl, Fukushima, Guerre Ukraine, COVID-19', now(), now())
  RETURNING id INTO v_doc_id;

  INSERT INTO app.prep_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject_name, concours_type, token_count, is_correction) VALUES

  (gen_random_uuid(), v_doc_id, 0,
$c$CATASTROPHE NUCLÉAIRE DE TCHERNOBYL (26 AVRIL 1986)

LIEU : Centrale de Tchernobyl, Pripiat, RSS d'Ukraine (URSS), 100 km nord de Kiev. Réacteur n°4 RBMK-1000 (graphite).

ACCIDENT : Test de sécurité mal préparé → montée incontrôlable de puissance → deux explosions (26 avril 1986, 1h23). Incendie graphite → rejets radioactifs massifs pendant 10 jours. Nuage sur toute l'Europe.

RÉPONSE : URSS cache l'accident. Suède alerte le monde (28 avril). Évacuation Pripiat (49 000 hab.) le 27 avril. Zone d'exclusion 30 km. 350 000 évacués. 600 000-800 000 « liquidateurs ».

CLASSEMENT : Niveau 7 INES (maximum, avec Fukushima).

BILAN : 31 morts directes. Long terme : 4 000 décès cancer (OMS/AIEA 2005) à 93 000 (Greenpeace). 6 000+ cancers thyroïde enfants. Contamination : césium-137 (demi-vie 30 ans).

CONSÉQUENCES : Zone exclusion 2 600 km² (réserve naturelle involontaire). Nouveau sarcophage 2016 (1,5 Md€). Accélération chute URSS. Normes nucléaires renforcées mondialement. Convention notification AIEA (1986).$c$,
  '{"source":"encyclopedique","topic":"Tchernobyl","fiabilite":"haute"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 300, false),

  (gen_random_uuid(), v_doc_id, 1,
$c$CATASTROPHE NUCLÉAIRE DE FUKUSHIMA (11 MARS 2011)

LIEU : Centrale Fukushima Daiichi, côte est Japon. TEPCO. 6 réacteurs BWR.

ACCIDENT : Séisme magnitude 9.0 (Tohoku, 14h46) — plus puissant au Japon, 4e mondial. Réacteurs arrêtés automatiquement. Tsunami 14-15 m frappe la centrale (protection prévue 5,7 m). Générateurs diesel noyés → perte totale alimentation → fusion cœurs réacteurs 1, 2, 3. Explosions hydrogène (12-15 mars). Rejets radioactifs atmosphère et océan.

CLASSEMENT : Niveau 7 INES.

ÉVACUATION : Zone 20 km. 154 000 personnes. Contamination eau, sols, aliments. Eaux traitées rejetées dans le Pacifique (2023, controversé).

BILAN : Séisme/tsunami : 18 500 morts (catastrophe naturelle). Pas de décès par irradiation à court terme (1 technicien 2018). Impact psychologique majeur.

CONSÉQUENCES : Japon ferme 54 réacteurs (redémarrage progressif). Allemagne sort du nucléaire (avril 2023). Stress tests mondiaux. Coût déclassement estimé 200 Md$ sur 30-40 ans. Débat nucléaire vs renouvelables relancé.$c$,
  '{"source":"encyclopedique","topic":"Fukushima","fiabilite":"haute"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 300, false),

  (gen_random_uuid(), v_doc_id, 2,
$c$GUERRE EN UKRAINE — CONTEXTE ET CAUSES

Ukraine indépendante 24 août 1991. 44M habitants. Mémorandum Budapest (1994) : renonce au nucléaire contre garanties de sécurité.

CAUSES : 1) Élargissement OTAN vers l'Est (Pologne 1999, Baltes 2004). Sommet Bucarest 2008 : Ukraine/Géorgie « deviendront membres ». 2) Révolution Maïdan (fév 2014) : Ianoukovitch refuse accord UE, manifestations (100+ morts), fuite du président. 3) Annexion Crimée (mars 2014) : forces russes, référendum controversé 96,7%. Résolution ONU : 100 pour intégrité Ukraine, 11 contre. 4) Guerre Donbass (2014-22) : Donetsk/Louhansk, accords Minsk non appliqués, 14 000 morts. Vol MH17 abattu (17 juil 2014, 298 morts, missile Buk russe).

INVASION 24 FÉVRIER 2022 : « Opération militaire spéciale ». Plus grande offensive en Europe depuis 1945. Zelensky : « J'ai besoin de munitions, pas d'un taxi. »$c$,
  '{"source":"encyclopedique","topic":"Guerre Ukraine","subtopic":"contexte"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 280, false),

  (gen_random_uuid(), v_doc_id, 3,
$c$GUERRE EN UKRAINE — DÉROULEMENT ET CONSÉQUENCES

DÉROULEMENT : Fév-mars 2022 : offensive vers Kiev échoue, siège Marioupol. Avril : retrait nord, massacres Boutcha. Sept 2022 : contre-offensive ukrainienne Kharkiv, référendums annexion (4 régions, non reconnus). Nov 2022 : libération Kherson. 2023-24 : guerre de position, batailles Bakhmout.

RÉACTION : ONU (2 mars 2022) : 141 pour, 5 contre, 35 abstentions. Sanctions massives (gel actifs, SWIFT, embargo pétrole). Aide militaire USA (75+ Md$), UE, UK (HIMARS, Leopard, Patriot, F-16). CPI : mandat arrêt Poutine (mars 2023).

CONSÉQUENCES : Humanitaire (10 000+ civils tués ONU, 6,3M réfugiés Europe, 5,9M déplacés). Alimentaire (Ukraine+Russie = 30% blé mondial, accord céréalier suspendu 2023, hausse prix Afrique). Énergétique (crise gaz Europe, sabotage Nord Stream sept 2022). OTAN élargie (Finlande 2023, Suède 2024).

AFRIQUE : hausse prix céréales et engrais, insécurité alimentaire Sahel. Burkina Faso importateur net de blé affecté.$c$,
  '{"source":"encyclopedique","topic":"Guerre Ukraine","subtopic":"consequences"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 310, false),

  (gen_random_uuid(), v_doc_id, 4,
$c$PANDÉMIE COVID-19 — ORIGINES ET PROPAGATION

IDENTIFICATION : Déc 2019, pneumonies atypiques Wuhan (Chine). 7 janv 2020 : SARS-CoV-2 identifié. Maladie nommée COVID-19 (11 fév 2020, OMS).

ORIGINE : Hypothèse dominante : zoonotique (chauve-souris via hôte intermédiaire). Alternative : fuite laboratoire Wuhan. Non tranché.

PROPAGATION : Janv 2020 : cas hors Chine. Wuhan confinée (23 janv, 11M hab.). 11 mars 2020 : OMS déclare pandémie (Dr Tedros). Mars 2020 : Europe épicentre (Italie 9/3, France 17/3, UK 23/3). USA pays le plus touché (New York en crise).

VARIANTS : Alpha (UK fin 2020), Beta (Afrique du Sud), Delta (Inde 2021, très meurtrier), Omicron (Afrique du Sud nov 2021, très transmissible, moins sévère).

CHIFFRES OMS : 770+ millions cas. 7+ millions décès officiels (réel estimé 14-25M morts excédentaires). Plus touchés : USA, Brésil, Inde, Russie, Mexique.

BURKINA FASO : premiers cas 9 mars 2020. Couvre-feu, fermeture écoles, restrictions. ~22 000 cas, 396 décès officiels.$c$,
  '{"source":"encyclopedique","topic":"COVID-19","subtopic":"origines"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 320, false),

  (gen_random_uuid(), v_doc_id, 5,
$c$PANDÉMIE COVID-19 — RÉPONSES, VACCINS ET CONSÉQUENCES

MESURES : Confinements (4+ Md personnes, avril 2020). Gestes barrières, masques, PCR, antigéniques. Stratégies : strict (Chine « zéro COVID » jusqu'à déc 2022), modéré (France), immunité collective (Suède).

VACCINS (record < 1 an) : ARNm (Pfizer-BioNTech, Moderna — 1re utilisation massive). Vecteur viral (AstraZeneca, J&J, Spoutnik V). Inactivé (Sinopharm, Sinovac). Protéine (Novavax). 1re vaccination : 8 déc 2020 (Margaret Keenan, UK). COVAX (OMS/Gavi) pour accès équitable. 13+ Md doses administrées. Afrique < 30% vaccinée.

TRAITEMENTS : Dexaméthasone (cas graves), Paxlovid, anticorps monoclonaux.

ÉCONOMIE : Récession 2020 PIB -3,1% (FMI), pire depuis WWII. Plans relance USA (5 900 Md$), UE (750 Md€). Explosion dette. Accélération numérique.

SOCIAL : Inégalités aggravées. Impact psychologique. 1,6 Md enfants privés d'école (UNESCO). Violence domestique en hausse.

AFRIQUE : ~12M cas, 257 000 décès. Burkina : vaccination juin 2021, taux < 15%. OMS lève urgence internationale 5 mai 2023.

LEÇONS : renforcer systèmes santé africains, production locale vaccins (hubs Sénégal, Afrique du Sud), préparation pandémies.$c$,
  '{"source":"encyclopedique","topic":"COVID-19","subtopic":"reponses_consequences"}'::jsonb, 'content', 'Culture Générale', 'TOUS', 350, false);

END $$;
