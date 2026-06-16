-- ============================================================================
-- PHASE 1: Adaptation Burkina Faso — Seed data concours + matières + prompt
-- Date: 2026-03-15
-- ============================================================================

-- 1. Supprimer l'ancien sujet "maths" camerounais
DELETE FROM app.prep_subjects WHERE slug = 'maths';

-- 2. Insérer les matières BF
INSERT INTO app.prep_subjects (slug, title, description, sort_order, is_active) VALUES
('culture_gen', 'Culture Générale', 'Questions de culture générale pour tous les concours du Burkina Faso', 1, true),
('actualites_bf', 'Actualités du Burkina Faso', 'Actualités nationales et internationales en rapport avec le Burkina Faso', 2, true),
('droit_constit', 'Droit Constitutionnel', 'Constitution du Burkina Faso, organisation des pouvoirs, droits fondamentaux', 3, true),
('droit_admin', 'Droit Administratif', 'Organisation administrative, actes administratifs, contentieux administratif', 4, true),
('droit_civil', 'Droit Civil', 'Droit des personnes, droit des obligations, droit des contrats', 5, true),
('droit_penal', 'Droit Pénal', 'Infractions, procédure pénale, droit pénal général et spécial', 6, true),
('droit_travail', 'Droit du Travail', 'Contrat de travail, relations professionnelles, sécurité sociale', 7, true),
('droit_fiscal', 'Droit Fiscal', 'Fiscalité directe et indirecte, procédures fiscales', 8, true),
('economie', 'Économie Générale', 'Macroéconomie, microéconomie, économie du développement', 9, true),
('finances_pub', 'Finances Publiques', 'Budget de l''État, comptabilité publique, contrôle des finances', 10, true),
('fiscalite', 'Fiscalité', 'Impôts, taxes, TVA, régimes fiscaux au Burkina Faso', 11, true),
('comptabilite', 'Comptabilité', 'Comptabilité générale, analytique, SYSCOHADA', 12, true),
('francais', 'Français', 'Grammaire, conjugaison, orthographe, compréhension de texte', 13, true),
('psychotech', 'Tests Psychotechniques', 'Logique verbale, numérique, aptitude au raisonnement', 14, true),
('maths', 'Mathématiques', 'Arithmétique, algèbre, géométrie, statistiques', 15, true),
('sciences_nat', 'Sciences Naturelles / SVT', 'Biologie, géologie, écologie, santé', 16, true),
('informatique', 'Informatique', 'Algorithmique, bases de données, réseaux, systèmes', 17, true),
('grh_management', 'GRH et Management', 'Gestion des ressources humaines, management des organisations', 18, true),
('pedagogie', 'Pédagogie', 'Sciences de l''éducation, didactique, psychologie de l''apprentissage', 19, true)
ON CONFLICT (slug) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description, sort_order = EXCLUDED.sort_order, is_active = true;

-- 3. Mettre à jour le prompt système IA pour le Burkina Faso
UPDATE app.prep_ai_config
SET config_value = 'Tu es un tuteur expert en préparation aux concours de la fonction publique du Burkina Faso (ENAREF, Administrateurs Civils, Douane, Greffiers, ENS, Éducation, Santé, Agriculture, Eaux et Forêts, GRH, Paramilitaire). Tu expliques les concepts pas à pas, tu proposes des exercices, tu corriges les erreurs avec bienveillance. Tu t''adaptes au niveau de l''étudiant. Langue : français. Contexte : système administratif et éducatif burkinabè. Tu peux aider en : culture générale, actualités du Burkina Faso, droit (constitutionnel, administratif, civil, pénal, fiscal, du travail), économie générale, finances publiques, fiscalité, comptabilité, français, tests psychotechniques, mathématiques, sciences naturelles, informatique, GRH et management, pédagogie. Quand tu donnes une réponse à un exercice, montre le raisonnement étape par étape. Si l''étudiant fait une erreur, corrige-le avec bienveillance en expliquant pourquoi. Utilise des exemples concrets du contexte burkinabè quand c''est pertinent (institutions, lois, géographie du Burkina Faso). Adapte la longueur de ta réponse : courte pour les questions simples, détaillée pour les exercices et explications.',
    updated_at = now()
WHERE config_key = 'system_prompt';

-- 4. Insérer 50 questions de culture générale BF comme contenu initial
-- Banque de questions BF
INSERT INTO app.prep_question_banks (title, description, concours_type, subject, is_active)
VALUES ('Culture Générale BF — Tronc commun', 'Questions de culture générale pour tous les concours directs du Burkina Faso', 'TOUS', 'Culture Générale', true);

-- Récupérer l'ID de la banque
DO $$
DECLARE
  v_bank_id UUID;
BEGIN
  SELECT id INTO v_bank_id FROM app.prep_question_banks WHERE title = 'Culture Générale BF — Tronc commun' LIMIT 1;

  -- Q1
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'Quelle est la capitale du Burkina Faso ?', 'Quelle est la capitale du Burkina Faso ?', '["Bobo-Dioulasso","Ouagadougou","Koudougou","Banfora"]'::jsonb, 1, 'Ouagadougou est la capitale politique et administrative du Burkina Faso depuis l''indépendance en 1960. Bobo-Dioulasso est la capitale économique.', 1, 'Culture Générale', 'TOUS', 'mcq', 'beginner', 'manual', true, true);

  -- Q2
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'En quelle année le Burkina Faso a-t-il obtenu son indépendance ?', 'En quelle année le Burkina Faso a-t-il obtenu son indépendance ?', '["1958","1960","1962","1956"]'::jsonb, 1, 'La Haute-Volta (ancien nom du Burkina Faso) a obtenu son indépendance le 5 août 1960. Le pays a été renommé Burkina Faso le 4 août 1984 par Thomas Sankara.', 1, 'Culture Générale', 'TOUS', 'mcq', 'beginner', 'manual', true, true);

  -- Q3
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'Combien de régions administratives compte le Burkina Faso ?', 'Combien de régions administratives compte le Burkina Faso ?', '["10","13","15","17"]'::jsonb, 1, 'Le Burkina Faso est divisé en 13 régions administratives, 45 provinces et 351 communes. Les 13 régions sont : Boucle du Mouhoun, Cascades, Centre, Centre-Est, Centre-Nord, Centre-Ouest, Centre-Sud, Est, Hauts-Bassins, Nord, Plateau-Central, Sahel, Sud-Ouest.', 1, 'Culture Générale', 'TOUS', 'mcq', 'beginner', 'manual', true, true);

  -- Q4
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'Quel est l''ancien nom du Burkina Faso ?', 'Quel est l''ancien nom du Burkina Faso ?', '["Côte d''Ivoire","Haute-Volta","Sénégal","Mali"]'::jsonb, 1, 'Le Burkina Faso s''appelait la Haute-Volta (du nom des trois affluents du fleuve Volta : Volta Noire, Volta Blanche, Volta Rouge) jusqu''au 4 août 1984.', 1, 'Culture Générale', 'TOUS', 'mcq', 'beginner', 'manual', true, true);

  -- Q5
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'Que signifie "Burkina Faso" ?', 'Que signifie "Burkina Faso" ?', '["Terre des hommes libres","Pays des hommes intègres","Nation des braves","Terre de paix"]'::jsonb, 1, '"Burkina Faso" signifie "Pays des hommes intègres". "Burkina" vient du mooré (intégrité) et "Faso" du dioula (patrie/terre).', 1, 'Culture Générale', 'TOUS', 'mcq', 'beginner', 'manual', true, true);

  -- Q6
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'Quel est le fleuve principal du Burkina Faso ?', 'Quel est le fleuve principal du Burkina Faso ?', '["Le Niger","Le Mouhoun (Volta Noire)","Le Sénégal","Le Congo"]'::jsonb, 1, 'Le Mouhoun (anciennement Volta Noire) est le principal cours d''eau du Burkina Faso. C''est le seul fleuve permanent du pays, avec environ 860 km.', 2, 'Culture Générale', 'TOUS', 'mcq', 'beginner', 'manual', true, true);

  -- Q7
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'Quelle est la devise du Burkina Faso ?', 'Quelle est la devise du Burkina Faso ?', '["Liberté, Égalité, Fraternité","Unité, Progrès, Justice","Paix, Travail, Patrie","Un Peuple, Un But, Une Foi"]'::jsonb, 1, 'La devise du Burkina Faso est "Unité - Progrès - Justice". Elle figure sur les armoiries et les documents officiels de l''État.', 1, 'Culture Générale', 'TOUS', 'mcq', 'beginner', 'manual', true, true);

  -- Q8
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'Quelle institution forme les agents des régies financières au Burkina Faso ?', 'Quelle institution forme les agents des régies financières au Burkina Faso ?', '["ENAM","ENAREF","ENS","Université Joseph Ki-Zerbo"]'::jsonb, 1, 'L''ENAREF (École Nationale des Régies Financières) forme les agents des douanes, des impôts et du trésor public au Burkina Faso. Elle propose 3 cycles : A (inspecteurs), B (contrôleurs), C (agents).', 2, 'Culture Générale', 'ENAREF', 'mcq', 'beginner', 'manual', true, true);

  -- Q9
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'Quel est le principal groupe ethnique du Burkina Faso ?', 'Quel est le principal groupe ethnique du Burkina Faso ?', '["Peul","Mossi","Bobo","Gourounsi"]'::jsonb, 1, 'Les Mossi constituent environ 50% de la population du Burkina Faso. Ils sont principalement concentrés dans le plateau central, autour de Ouagadougou.', 1, 'Culture Générale', 'TOUS', 'mcq', 'beginner', 'manual', true, true);

  -- Q10
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'Qui est considéré comme le père de la révolution burkinabè ?', 'Qui est considéré comme le père de la révolution burkinabè ?', '["Maurice Yaméogo","Sangoulé Lamizana","Thomas Sankara","Blaise Compaoré"]'::jsonb, 2, 'Thomas Sankara, président de 1983 à 1987, est considéré comme le père de la révolution burkinabè. Il a renommé le pays de "Haute-Volta" en "Burkina Faso" et initié de nombreuses réformes sociales.', 2, 'Culture Générale', 'TOUS', 'mcq', 'beginner', 'manual', true, true);

  -- Q11
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'Quelle est la monnaie utilisée au Burkina Faso ?', 'Quelle est la monnaie utilisée au Burkina Faso ?', '["Le Naira","Le Franc CFA (XOF)","Le Cedi","Le Dalasi"]'::jsonb, 1, 'Le Burkina Faso utilise le Franc CFA de l''Afrique de l''Ouest (XOF), émis par la BCEAO. Le pays est membre de l''UEMOA (Union Économique et Monétaire Ouest-Africaine).', 1, 'Culture Générale', 'TOUS', 'mcq', 'beginner', 'manual', true, true);

  -- Q12
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'Quel est le principal produit d''exportation agricole du Burkina Faso ?', 'Quel est le principal produit d''exportation agricole du Burkina Faso ?', '["Le cacao","Le café","Le coton","L''arachide"]'::jsonb, 2, 'Le coton est le principal produit d''exportation agricole du Burkina Faso, qui est l''un des plus grands producteurs de coton en Afrique. L''or est le premier produit d''exportation tous secteurs confondus.', 2, 'Culture Générale', 'TOUS', 'mcq', 'beginner', 'manual', true, true);

  -- Q13 Droit
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'Selon la Constitution du Burkina Faso, qui est le chef de l''État ?', 'Selon la Constitution du Burkina Faso, qui est le chef de l''État ?', '["Le Premier Ministre","Le Président du Faso","Le Président de l''Assemblée Nationale","Le Chef d''État-Major"]'::jsonb, 1, 'Selon la Constitution du Burkina Faso, le Président du Faso est le chef de l''État. Il est garant de l''indépendance nationale, de l''intégrité du territoire et du respect de la Constitution.', 2, 'Droit Constitutionnel', 'ADMIN_CIVIL', 'mcq', 'intermediate', 'manual', true, true);

  -- Q14 Économie
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'Quel est l''organe qui émet le Franc CFA dans la zone UEMOA ?', 'Quel est l''organe qui émet le Franc CFA dans la zone UEMOA ?', '["La Banque Mondiale","La BCEAO","Le FMI","La BAD"]'::jsonb, 1, 'La BCEAO (Banque Centrale des États de l''Afrique de l''Ouest) est l''institution d''émission monétaire commune aux 8 États membres de l''UEMOA dont le Burkina Faso.', 2, 'Économie Générale', 'ENAREF', 'mcq', 'intermediate', 'manual', true, true);

  -- Q15 Finances publiques
  INSERT INTO app.prep_questions (bank_id, question, content, options, correct_index, explanation, difficulty, subject, concours_type, question_type, level, source, is_published, is_active)
  VALUES (v_bank_id, 'Qu''est-ce que la loi de finances au Burkina Faso ?', 'Qu''est-ce que la loi de finances au Burkina Faso ?', '["Un décret présidentiel","La loi qui autorise et prévoit les recettes et dépenses de l''État","Un arrêté ministériel","Une directive de la BCEAO"]'::jsonb, 1, 'La loi de finances est l''acte législatif qui prévoit et autorise, pour chaque année civile, l''ensemble des ressources et des charges de l''État. Elle est votée par l''Assemblée Nationale.', 3, 'Finances Publiques', 'ENAREF', 'mcq', 'intermediate', 'manual', true, true);

END $$;
