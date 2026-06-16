-- Injection cours Droit Pénal Général L2 S3 — Partie 2/2 (Chunks 20-34)
-- Agent pénal, complicité, peines, mesures de sûreté, extinction

DO $$
DECLARE v_doc_id UUID;
BEGIN
  SELECT id INTO v_doc_id FROM app.td_source_documents
  WHERE subject = 'Droit Pénal Général' AND study_year = 'L2' AND original_filename = 'Cours_DPG_L2_S3_BF_Willy.txt'
  LIMIT 1;

  IF v_doc_id IS NULL THEN RAISE EXCEPTION 'Source document DPG L2 not found'; END IF;

  INSERT INTO app.td_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject, university, study_year, token_count) VALUES

  -- Chunk 20: Personnes physiques — auteur et coauteur
  (gen_random_uuid(), v_doc_id, 20,
$c$L'AGENT PÉNAL — PERSONNES PHYSIQUES (ART. 131-2 CP)

Art. 131-2 : « Est auteur ou coauteur toute personne physique qui, personnellement et de façon principale, accomplit les éléments constitutifs d'une infraction par commission ou omission ou qui est à l'origine de tels faits. »

Auteur matériel : personne qui réalise matériellement tous les faits prohibés par la loi (celui qui ouvre le feu, qui dérobe des bijoux, qui s'abstient de porter secours).

Coauteur : plusieurs personnes accomplissent l'infraction, chacun réalisant soit les mêmes actes, soit des actes déterminants. Ex : viol collectif. Chaque coauteur réalise tous les éléments constitutifs. La coaction se distingue de la complicité (rôle secondaire).

Répression : chaque coauteur est poursuivi comme s'il avait été l'unique auteur. Les causes personnelles d'atténuation ou d'aggravation restent individuelles.$c$,
  '{"source":"cours","topic":"agent_penal","subtopic":"personnes_physiques"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 200),

  -- Chunk 21: Chef d'entreprise
  (gen_random_uuid(), v_doc_id, 21,
$c$RESPONSABILITÉ PÉNALE DU CHEF D'ENTREPRISE

Le chef d'entreprise est pénalement responsable des infractions commises au sein de son entreprise en sa qualité de dirigeant (même si la sécurité est déléguée à un salarié). Ce qui est reproché : imprudence ou négligence dans l'organisation de l'activité.

Délégation de pouvoirs : le chef d'entreprise peut déléguer tout ou partie de ses pouvoirs à un subordonné. Conditions : acceptation par le subordonné ; compétence, autorité et moyens nécessaires. Effet : le délégataire devient pénalement responsable des aspects délégués.

Le chef d'entreprise reste toujours responsable de ses actes ou omissions personnels en violation de la loi pénale.$c$,
  '{"source":"cours","topic":"agent_penal","subtopic":"chef_entreprise"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 170),

  -- Chunk 22: Personnes morales
  (gen_random_uuid(), v_doc_id, 22,
$c$RESPONSABILITÉ PÉNALE DES PERSONNES MORALES (ART. 131-2 AL. 2 ET 131-3 CP)

Personnes morales concernées : toutes, y compris l'État et ses démembrements. Mais pour les personnes publiques, uniquement pour les infractions commises dans l'exercice d'activités susceptibles de délégation de service public (pas les activités régaliennes). Les personnes morales de droit privé (sociétés, associations, syndicats) doivent avoir la personnalité juridique.

Conditions cumulatives :
1. Infraction commise « au nom et dans l'intérêt » de la personne morale (pas dans l'intérêt personnel du dirigeant).
2. Infraction commise par un organe ou un représentant de la personne morale dans l'exercice de ses fonctions.

Un délégataire de pouvoirs ou un dirigeant de fait peut engager la responsabilité pénale de la personne morale. La responsabilité de la personne morale n'exclut pas celle de la personne physique auteur ou complice des mêmes faits (cumul possible).$c$,
  '{"source":"cours","topic":"agent_penal","subtopic":"personnes_morales"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 210),

  -- Chunk 23: Complicité — conditions
  (gen_random_uuid(), v_doc_id, 23,
$c$LA COMPLICITÉ — CONDITIONS (ART. 131-4 CP)

Le complice est la personne qui, sciemment, par aide ou assistance, a facilité la préparation ou la consommation de l'acte incriminé. Participation indirecte, accessoire.

Trois conditions cumulatives :

1. Fait principal pénalement punissable : pas de complicité sans infraction (principe de légalité). Le fait peut être une infraction consommée ou une tentative. La complicité d'une tentative est punissable, mais la tentative de complicité ne l'est pas. Seule la complicité de crime ou délit est punissable (pas la contravention).

2. Acte matériel de complicité :
- Actes positifs antérieurs ou concomitants : procurer armes/instruments, préparer ou faciliter l'action, provoquer par don/promesse/menace/ordre/abus d'autorité.
- Actes postérieurs : fournir habituellement logement à des malfaiteurs ; non-dénonciation d'un crime tenté ou consommé (sauf conjoint et parents/alliés jusqu'au 4e degré).

3. Intention coupable : le complice doit avoir conscience que son aide tend à la commission d'une infraction. Une faute d'imprudence ne suffit pas.$c$,
  '{"source":"cours","topic":"agent_penal","subtopic":"complicite_conditions"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 230),

  -- Chunk 24: Complicité — sanctions
  (gen_random_uuid(), v_doc_id, 24,
$c$SANCTIONS DE LA COMPLICITÉ (ART. 131-5 CP)

Art. 131-5 : « Les complices d'un crime ou d'un délit sont punis comme les auteurs même de ce crime ou de ce délit sauf si la loi en dispose autrement. » Pas de complicité pour les contraventions.

Assimilation du complice à l'auteur pour la détermination de la peine encourue. Mais le juge peut individualiser la peine concrètement prononcée.

Incidence des circonstances :
- Circonstances personnelles (art. 216-1 al. 2) : n'ont d'effet qu'à l'égard de la personne concernée. La récidive de l'auteur principal n'affecte pas le complice ; la minorité de l'auteur ne bénéficie pas au complice.
- Circonstances réelles/objectives : impactent le complice. Ex : prescription de l'infraction profite aussi au complice ; le fait justificatif (légitime défense) de l'auteur bénéficie au complice.

La complicité n'est pas punissable si l'auteur principal commet une infraction totalement différente de celle à laquelle le complice avait voulu apporter son concours.$c$,
  '{"source":"cours","topic":"agent_penal","subtopic":"complicite_sanctions"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 210),

  -- Chunk 25: Fonctions et caractères de la peine
  (gen_random_uuid(), v_doc_id, 25,
$c$FONCTIONS ET CARACTÈRES DE LA PEINE

Fonctions :
1. Rétribution/expiation : châtiment, souffrance proportionnelle à la gravité des faits.
2. Intimidation/prévention : dissuasion collective et individuelle.
3. Élimination : retrait temporaire ou définitif du délinquant du circuit social.
4. Insertion/resocialisation : améliorer le délinquant en vue de sa réinsertion. Mécanismes : remise de peine, libération conditionnelle, permission de sortie, sursis.

Caractères :
- Infamante : désigne le condamné à la réprobation publique.
- Afflictive : châtiment douloureux ressenti dans le corps, la liberté, la réputation ou le patrimoine.
- Définitive : acquiert l'autorité de chose jugée.
- Déterminée : durée ou montant fixé par le législateur (fourchette) et précisé par le juge.
- Personnelle : ne frappe que l'auteur de l'infraction. Pas de responsabilité pénale du fait d'autrui (sauf exceptions). Le décès arrête les poursuites.$c$,
  '{"source":"cours","topic":"peine","subtopic":"fonctions_caracteres"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 230),

  -- Chunk 26: Classification des peines — criminelles, correctionnelles, contraventionnelles
  (gen_random_uuid(), v_doc_id, 26,
$c$CLASSIFICATION DES PEINES PAR ÉCHELLE

Peines criminelles (majeurs — art. 212-1) : emprisonnement à vie ; emprisonnement > 10 ans ; amende (personnes morales) ; dissolution (personnes morales) ; dégradation civique ; confiscation. Pour mineurs (art. 212-9) : emprisonnement max = moitié de la peine des majeurs (max 15 ans) ; confiscation.

Peines correctionnelles (majeurs — art. 213-1) : emprisonnement à temps ; amende ; travail d'intérêt général ; interdictions temporaires ou définitives ; dissolution des personnes morales. Pour mineurs (art. 213-8) : admonestation, réprimande, remise aux parents, placement, amende et emprisonnement (>13 ans), TIG (>16 ans).

Peines contraventionnelles : uniquement l'amende (max 200 000 FCFA, 400 000 en récidive). 4 classes selon le Décret 97-84.$c$,
  '{"source":"cours","topic":"peine","subtopic":"classification_echelle"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 210),

  -- Chunk 27: Peines principales, complémentaires, accessoires, alternatives
  (gen_random_uuid(), v_doc_id, 27,
$c$CLASSIFICATION DES PEINES PAR RAPPORTS ENTRE ELLES

Peines principales : nécessairement prononcées pour une infraction déterminée. Socle de la sanction, déterminent la nature de l'infraction.

Peines complémentaires : viennent compléter la peine principale. Obligatoires (ex : confiscation d'objets dangereux — art. 214-23 al. 7) ou facultatives (déchéances, interdiction de séjour, interdiction d'exercer...). Le juge peut parfois prononcer une peine complémentaire à titre de peine principale.

Peines accessoires : s'attachent automatiquement à la peine principale sans que le juge ait besoin de les prononcer. Ex : condamné à l'emprisonnement à vie → incapacité automatique de donner et recevoir (art. 212-5).

Peines alternatives : peuvent se substituer aux peines principales. Pas en matière criminelle. En matière correctionnelle : TIG alternatif à l'emprisonnement. En matière contraventionnelle : amende alternative à la suspension du permis.$c$,
  '{"source":"cours","topic":"peine","subtopic":"classification_rapports"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 210),

  -- Chunk 28: Domaine d'effet des peines
  (gen_random_uuid(), v_doc_id, 28,
$c$CLASSIFICATION DES PEINES PAR DOMAINE D'EFFET

1. Peines corporelles : atteignent la vie ou l'intégrité physique. Depuis l'abolition de la peine de mort par la loi 025-2018, plus aucune peine corporelle en droit burkinabè.

2. Peines privatives/restrictives de liberté : emprisonnement (privative), interdiction de séjour, interdiction du territoire (restrictives).

3. Peines patrimoniales/pécuniaires : amende (criminelle, correctionnelle ou de simple police) et confiscation (générale ou spéciale, obligatoire ou facultative).

4. Peines professionnelles : interdiction d'exercer (art. 214-6), exclusion des marchés publics, fermeture d'établissement.

5. Peines affectant l'exercice de droits : interdiction de fonctions publiques, privation de droits civiques/civils/de famille, interdiction de port d'arme, d'émettre un chèque.

Mesures de sûreté (art. 221-1) : mesures individuelles coercitives préventives. Ne visent pas à punir mais à remédier à un état dangereux. Pas de limite temporelle fixe. Ex : internement d'aliénés, traitement des toxicomanes, liberté surveillée des mineurs.$c$,
  '{"source":"cours","topic":"peine","subtopic":"domaine_effet_mesures_surete"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 230),

  -- Chunk 29: Circonstances aggravantes et récidive
  (gen_random_uuid(), v_doc_id, 29,
$c$CAUSES D'AGGRAVATION DE LA PEINE

Circonstances aggravantes : particularités limitativement prévues par la loi qui augmentent la culpabilité et la peine. Peuvent être objectives/réelles (effraction, violence) ou subjectives/personnelles (qualité de l'auteur), générales ou spéciales. Ex : vol avec arme, MGF par personnel médical, préméditation.

Récidive (art. 218-3 et s.) : circonstance aggravante. Conditions : condamnation définitive antérieure + nouvelle infraction indépendante.

Hypothèses :
- Crime puis crime : récidive générale et perpétuelle → peine doublée.
- Crime puis délit intentionnel : récidive générale et temporaire (5 ans) → peine doublée.
- Délit intentionnel puis crime : générale et temporaire (5 ans) → peine doublée.
- Délit puis délit identique/assimilé : spéciale et temporaire (5 ans) → peine doublée. Art. 218-4 : vol, escroquerie, abus de confiance, recel, etc. considérés comme même délit.
- Contraventions : récidive si jugement définitif dans les 12 mois précédents (art. 218-5) → amende doublée.$c$,
  '{"source":"cours","topic":"peine","subtopic":"aggravation_recidive"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 230),

  -- Chunk 30: Atténuation — circonstances atténuantes, excuses
  (gen_random_uuid(), v_doc_id, 30,
$c$CAUSES D'ATTÉNUATION ET D'EXEMPTION DE LA PEINE

Circonstances atténuantes (art. 81 CP) : causes judiciaires d'atténuation laissées à l'appréciation souveraine du juge. Permettent de prononcer une peine inférieure à la peine normalement prévue. Faits extérieurs, antécédents du prévenu, insignifiance du dommage, repentir, chances d'amendement...

Excuses absolutoires : circonstances légalement prévues qui entraînent une dispense complète de la peine malgré la culpabilité établie. Outil de politique criminelle. S'imposent au juge. N'exonèrent pas de la responsabilité civile. Ex : dénonciation d'un complot avant toute tentative (art. 311-8, 362-3 CP).

Excuses atténuantes : circonstances légales qui réduisent la peine sans la supprimer. Ex : excuse de minorité (13-18 ans), excuse de provocation (flagrant délit d'adultère au domicile conjugal).

Différence clé : les excuses (absolutoires ou atténuantes) découlent d'un texte de loi précis ; les circonstances atténuantes sont laissées à la discrétion du juge.

Concours réel d'infractions (art. 111-8) : la peine la plus forte absorbe la plus faible (pas de cumul). Cumul possible entre contraventions, entre délits et contraventions non connexes.$c$,
  '{"source":"cours","topic":"peine","subtopic":"attenuation_excuses"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 240),

  -- Chunk 31: Sursis et libération conditionnelle
  (gen_random_uuid(), v_doc_id, 31,
$c$SUSPENSION DE LA PEINE — SURSIS ET LIBÉRATION CONDITIONNELLE

Sursis (art. 615-1 et s. CPP) : suspension de l'exécution de la peine. Mesure de faveur pour délinquants primaires.
Conditions : pas de condamnation antérieure (sauf infractions politiques et militaires) ; ne pas commettre de nouvelle infraction grave dans un délai de 5 ans. Si l'épreuve réussit → dispense définitive. Si nouvelle infraction → révocation (cumul des deux peines). S'applique aux amendes et emprisonnement. Ne fait pas obstacle aux dommages-intérêts.

Libération conditionnelle (art. 614-1 et s. CPP) : libération anticipée avant la fin de la peine privative de liberté.
Conditions : avoir exécuté la moitié ou les 2/3 de la peine ; bonne conduite ; gages sérieux de réadaptation sociale ; acceptation des conditions.
Si l'épreuve réussit → libération définitive, peine réputée exécutée (mais la condamnation subsiste pour récidive/sursis). Si incident → révocation et réincarcération pour le reliquat.

Autres causes suspensives : semi-liberté, placement à l'extérieur, démence survenue en cours d'exécution.$c$,
  '{"source":"cours","topic":"peine","subtopic":"sursis_liberation_conditionnelle"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 230),

  -- Chunk 32: Extinction des peines
  (gen_random_uuid(), v_doc_id, 32,
$c$EXTINCTION DES SANCTIONS PÉNALES

Extinction AVEC effacement de la condamnation :

1. Amnistie : loi du pouvoir législatif qui fait disparaître rétroactivement le caractère infractionnel d'un fait. Personnelle (catégorie de personnes) ou réelle (catégorie de faits). Efface la condamnation, ne préjudicie pas aux droits des parties civiles, ne compte pas pour la récidive, autorise le sursis.

2. Réhabilitation : judiciaire (prononcée par la chambre de l'instruction, après enquête, conditions de délai : 5 ans crime, 3 ans délit, 1 an contravention, doublés pour récidivistes) ou légale (automatique après un certain délai — art. 623-3 CPP). Efface la condamnation du casier judiciaire.

Extinction SANS effacement de la condamnation :

1. Grâce : acte de clémence du Président du Faso (art. 54 Constitution). Totale, partielle ou commutation. N'efface pas la condamnation (reste au casier, compte pour récidive, fait obstacle au sursis).

2. Prescription de la peine : 20 ans (crimes), 3 ans (délits), 2 ans (contraventions). Crimes contre l'humanité : imprescriptibles. La condamnation subsiste.

3. Mort du délinquant : met fin à toutes les peines. Les peines pécuniaires devenues définitives avant le décès se transmettent aux héritiers comme dettes.$c$,
  '{"source":"cours","topic":"peine","subtopic":"extinction_peines"}'::jsonb, 'content', 'Droit Pénal Général', NULL, 'L2', 250);

END;
$$;
