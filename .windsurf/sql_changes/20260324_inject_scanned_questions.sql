-- ============================================================
-- ACADEMIA — INJECTION QUESTIONS DOCUMENT SCANNÉ
-- Source: Document de préparation au concours (Burkina Faso)
-- Matières: Mathématiques, Physique, Chimie, Biologie, Économie, Droit
-- Date: 2026-03-24
-- ============================================================

-- ─── ÉTAPE 1 : Créer les matières ──────────────────────────

INSERT INTO app.prep_subjects (id, slug, title, description, sort_order, is_active)
VALUES
  ('11111111-0001-0001-0001-000000000001', 'mathematiques', 'Mathématiques',
   'Algèbre, analyse, géométrie, probabilités et statistiques', 1, TRUE),
  ('11111111-0002-0002-0002-000000000002', 'physique', 'Physique',
   'Mécanique, électricité, optique et thermodynamique', 2, TRUE),
  ('11111111-0003-0003-0003-000000000003', 'chimie', 'Chimie',
   'Réactions chimiques, solutions, pH et chimie organique', 3, TRUE),
  ('11111111-0004-0004-0004-000000000004', 'biologie', 'Biologie',
   'Cellule, génétique, physiologie et systèmes du vivant', 4, TRUE),
  ('11111111-0005-0005-0005-000000000005', 'economie', 'Économie',
   'Microéconomie, macroéconomie, marché et indicateurs économiques', 5, TRUE),
  ('11111111-0006-0006-0006-000000000006', 'droit', 'Droit',
   'Droit constitutionnel, civil et notions juridiques fondamentales', 6, TRUE)
ON CONFLICT (slug) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  sort_order = EXCLUDED.sort_order,
  is_active = TRUE;

-- ─── ÉTAPE 2 : Créer les chapitres ────────────────────────

INSERT INTO app.prep_chapters (id, subject_id, slug, title, sort_order, is_active)
VALUES
  -- Mathématiques
  ('22222222-0001-0001-0001-000000000001',
   (SELECT id FROM app.prep_subjects WHERE slug = 'mathematiques'),
   'suites', 'Suites numériques', 1, TRUE),
  ('22222222-0002-0002-0002-000000000002',
   (SELECT id FROM app.prep_subjects WHERE slug = 'mathematiques'),
   'fonctions', 'Fonctions et dérivées', 2, TRUE),
  ('22222222-0003-0003-0003-000000000003',
   (SELECT id FROM app.prep_subjects WHERE slug = 'mathematiques'),
   'probabilites', 'Probabilités et statistiques', 3, TRUE),
  ('22222222-0004-0004-0004-000000000004',
   (SELECT id FROM app.prep_subjects WHERE slug = 'mathematiques'),
   'nombres-complexes', 'Nombres complexes', 4, TRUE),
  ('22222222-0005-0005-0005-000000000005',
   (SELECT id FROM app.prep_subjects WHERE slug = 'mathematiques'),
   'geometrie', 'Géométrie dans l''espace', 5, TRUE),
  -- Physique
  ('22222222-0011-0011-0011-000000000011',
   (SELECT id FROM app.prep_subjects WHERE slug = 'physique'),
   'mecanique', 'Mécanique', 1, TRUE),
  ('22222222-0012-0012-0012-000000000012',
   (SELECT id FROM app.prep_subjects WHERE slug = 'physique'),
   'electricite', 'Électricité', 2, TRUE),
  ('22222222-0013-0013-0013-000000000013',
   (SELECT id FROM app.prep_subjects WHERE slug = 'physique'),
   'optique', 'Optique', 3, TRUE),
  -- Chimie
  ('22222222-0021-0021-0021-000000000021',
   (SELECT id FROM app.prep_subjects WHERE slug = 'chimie'),
   'reactions', 'Réactions chimiques', 1, TRUE),
  ('22222222-0022-0022-0022-000000000022',
   (SELECT id FROM app.prep_subjects WHERE slug = 'chimie'),
   'solutions', 'Solutions et pH', 2, TRUE),
  -- Biologie
  ('22222222-0031-0031-0031-000000000031',
   (SELECT id FROM app.prep_subjects WHERE slug = 'biologie'),
   'cellule', 'Biologie cellulaire', 1, TRUE),
  ('22222222-0032-0032-0032-000000000032',
   (SELECT id FROM app.prep_subjects WHERE slug = 'biologie'),
   'genetique', 'Génétique', 2, TRUE),
  -- Économie
  ('22222222-0041-0041-0041-000000000041',
   (SELECT id FROM app.prep_subjects WHERE slug = 'economie'),
   'macroeconomie', 'Macroéconomie', 1, TRUE),
  ('22222222-0042-0042-0042-000000000042',
   (SELECT id FROM app.prep_subjects WHERE slug = 'economie'),
   'marche', 'Marché et prix', 2, TRUE),
  -- Droit
  ('22222222-0051-0051-0051-000000000051',
   (SELECT id FROM app.prep_subjects WHERE slug = 'droit'),
   'constitution', 'Droit constitutionnel', 1, TRUE),
  ('22222222-0052-0052-0052-000000000052',
   (SELECT id FROM app.prep_subjects WHERE slug = 'droit'),
   'droit-civil', 'Droit civil', 2, TRUE)
ON CONFLICT (subject_id, slug) DO NOTHING;

-- ─── ÉTAPE 3 : Injecter les questions (is_published = TRUE) ─

INSERT INTO app.prep_questions
  (id, subject_id, chapter_id, source, question_type, level,
   question, explanation, correct_answer, estimated_time_sec, is_published)
VALUES

-- ── MATHÉMATIQUES ──────────────────────────────────────────

('33333333-0001-0001-0001-000000000001',
 (SELECT id FROM app.prep_subjects WHERE slug = 'mathematiques'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'suites'),
 'import', 'mcq', 'intermediate',
 'Soit une suite définie par $u_0 = 2$ et $u_{n+1} = \frac{2u_n + 1}{u_n + 2}$. Quelle est la nature de cette suite?',
 'La suite converge vers $\ell$ tel que $\ell = \frac{2\ell + 1}{\ell + 2}$ → $\ell^2 = 1$ → $\ell = 1$ (car $u_0 > 0$). C''est une suite convergente.',
 'Suite convergente',
 90, TRUE),

('33333333-0002-0002-0002-000000000002',
 (SELECT id FROM app.prep_subjects WHERE slug = 'mathematiques'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'fonctions'),
 'import', 'mcq', 'beginner',
 'Calculer la dérivée de $f(x) = x\ln(x) - x$.',
 '$f''(x) = \ln(x) + x \cdot \frac{1}{x} - 1 = \ln(x) + 1 - 1 = \ln(x)$',
 '$\ln(x)$',
 60, TRUE),

('33333333-0003-0003-0003-000000000003',
 (SELECT id FROM app.prep_subjects WHERE slug = 'mathematiques'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'nombres-complexes'),
 'import', 'mcq', 'beginner',
 'Quel est l''argument du nombre complexe $z = 1 + i$?',
 '$\arg(1 + i) = \arctan\left(\frac{1}{1}\right) = \frac{\pi}{4}$',
 '$\frac{\pi}{4}$',
 45, TRUE),

('33333333-0004-0004-0004-000000000004',
 (SELECT id FROM app.prep_subjects WHERE slug = 'mathematiques'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'probabilites'),
 'import', 'mcq', 'beginner',
 'Une urne contient 3 boules blanches et 5 boules noires. Quelle est la probabilité de tirer une boule blanche?',
 '$P(\text{blanche}) = \frac{3}{3+5} = \frac{3}{8}$',
 '$\frac{3}{8}$',
 45, TRUE),

('33333333-0005-0005-0005-000000000005',
 (SELECT id FROM app.prep_subjects WHERE slug = 'mathematiques'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'geometrie'),
 'import', 'mcq', 'intermediate',
 'Le volume d''un cylindre de rayon $r = 5$ cm et de hauteur $h = 10$ cm est :',
 '$V = \pi r^2 h = \pi \times 25 \times 10 = 250\pi$ cm³',
 '$250\pi$ cm³',
 60, TRUE),

('33333333-0006-0006-0006-000000000006',
 (SELECT id FROM app.prep_subjects WHERE slug = 'mathematiques'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'probabilites'),
 'import', 'mcq', 'beginner',
 'La médiane de la série : 5, 8, 9, 11, 14, 17, 21 est :',
 'Pour une série de 7 valeurs triées, la médiane est la 4ème valeur : 11.',
 '11',
 45, TRUE),

-- ── PHYSIQUE ───────────────────────────────────────────────

('33333333-0011-0011-0011-000000000011',
 (SELECT id FROM app.prep_subjects WHERE slug = 'physique'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'mecanique'),
 'import', 'mcq', 'beginner',
 'Un cycliste parcourt 90 km en 2h30. Quelle est sa vitesse moyenne?',
 'Vitesse = Distance / Temps = 90 ÷ 2,5 = 36 km/h',
 '36 km/h',
 45, TRUE),

('33333333-0012-0012-0012-000000000012',
 (SELECT id FROM app.prep_subjects WHERE slug = 'physique'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'electricite'),
 'import', 'mcq', 'beginner',
 'Dans un circuit électrique, que représente $I$?',
 'I représente l''intensité du courant électrique, mesurée en ampères (A).',
 'L''intensité du courant',
 30, TRUE),

('33333333-0013-0013-0013-000000000013',
 (SELECT id FROM app.prep_subjects WHERE slug = 'physique'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'optique'),
 'import', 'mcq', 'intermediate',
 'Un objet placé devant une lentille convergente à une distance supérieure à 2f donne une image :',
 'Pour un objet au-delà de 2f d''une lentille convergente, l''image est réelle et renversée.',
 'Réelle et renversée',
 60, TRUE),

-- ── CHIMIE ─────────────────────────────────────────────────

('33333333-0021-0021-0021-000000000021',
 (SELECT id FROM app.prep_subjects WHERE slug = 'chimie'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'reactions'),
 'import', 'mcq', 'intermediate',
 'La saponification est une réaction entre :',
 'La saponification est la réaction d''un ester avec une base forte (NaOH ou KOH) pour former un savon (acide gras + alcool).',
 'Un ester et une base forte',
 60, TRUE),

('33333333-0022-0022-0022-000000000022',
 (SELECT id FROM app.prep_subjects WHERE slug = 'chimie'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'solutions'),
 'import', 'mcq', 'intermediate',
 'Quel est le pH d''une solution d''acide chlorhydrique de concentration 0,1 mol/L?',
 'HCl est un acide fort qui se dissocie totalement : [H⁺] = 0,1 mol/L → pH = −log(0,1) = 1',
 '1',
 60, TRUE),

('33333333-0023-0023-0023-000000000023',
 (SELECT id FROM app.prep_subjects WHERE slug = 'chimie'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'solutions'),
 'import', 'mcq', 'beginner',
 'La dissolution du chlorure de sodium (NaCl) dans l''eau produit :',
 'NaCl est un sel ionique qui se dissocie complètement en solution aqueuse : NaCl → Na⁺ + Cl⁻',
 'Des ions Na⁺ et Cl⁻',
 45, TRUE),

-- ── BIOLOGIE ───────────────────────────────────────────────

('33333333-0031-0031-0031-000000000031',
 (SELECT id FROM app.prep_subjects WHERE slug = 'biologie'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'cellule'),
 'import', 'mcq', 'beginner',
 'Où s''effectue la synthèse des protéines dans la cellule?',
 'Les ribosomes sont les usines cellulaires de la synthèse protéique. Ils lisent l''ARNm pour produire des protéines.',
 'Dans les ribosomes',
 45, TRUE),

('33333333-0032-0032-0032-000000000032',
 (SELECT id FROM app.prep_subjects WHERE slug = 'biologie'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'cellule'),
 'import', 'mcq', 'beginner',
 'Les globules blancs responsables de la défense de l''organisme sont :',
 'Les leucocytes (globules blancs) assurent la défense immunitaire. Ils incluent les lymphocytes, monocytes et granulocytes.',
 'Les leucocytes',
 45, TRUE),

('33333333-0033-0033-0033-000000000033',
 (SELECT id FROM app.prep_subjects WHERE slug = 'biologie'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'genetique'),
 'import', 'mcq', 'beginner',
 'L''ADN contient toutes les informations génétiques et se trouve principalement dans :',
 'L''ADN est localisé principalement dans le noyau cellulaire, mais aussi en faible quantité dans les mitochondries.',
 'Le noyau',
 45, TRUE),

-- ── ÉCONOMIE ───────────────────────────────────────────────

('33333333-0041-0041-0041-000000000041',
 (SELECT id FROM app.prep_subjects WHERE slug = 'economie'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'macroeconomie'),
 'import', 'mcq', 'intermediate',
 'Le PIB mesure :',
 'Le PIB (Produit Intérieur Brut) est la valeur totale des biens et services produits sur un territoire pendant une période donnée (généralement un an).',
 'La production de richesses sur un territoire en un an',
 60, TRUE),

('33333333-0042-0042-0042-000000000042',
 (SELECT id FROM app.prep_subjects WHERE slug = 'economie'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'macroeconomie'),
 'import', 'mcq', 'beginner',
 'L''inflation est :',
 'L''inflation désigne une hausse générale, durable et auto-entretenue du niveau des prix dans une économie.',
 'Une hausse générale et durable des prix',
 45, TRUE),

('33333333-0043-0043-0043-000000000043',
 (SELECT id FROM app.prep_subjects WHERE slug = 'economie'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'marche'),
 'import', 'mcq', 'intermediate',
 'Sur un marché concurrentiel, le prix d''équilibre est déterminé par :',
 'En concurrence pure et parfaite, le prix d''équilibre est celui pour lequel l''offre est égale à la demande.',
 'L''offre et la demande',
 60, TRUE),

-- ── DROIT ──────────────────────────────────────────────────

('33333333-0051-0051-0051-000000000051',
 (SELECT id FROM app.prep_subjects WHERE slug = 'droit'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'constitution'),
 'import', 'mcq', 'beginner',
 'Au Burkina Faso, qui est le chef de l''État?',
 'Selon la Constitution burkinabè, le Président du Faso est le chef de l''État.',
 'Le Président du Faso',
 30, TRUE),

('33333333-0052-0052-0052-000000000052',
 (SELECT id FROM app.prep_subjects WHERE slug = 'droit'),
 (SELECT id FROM app.prep_chapters WHERE slug = 'droit-civil'),
 'import', 'mcq', 'beginner',
 'À quel âge atteint-on la majorité civile au Burkina Faso?',
 'La majorité civile est fixée à 18 ans au Burkina Faso (Code des personnes et de la famille).',
 '18 ans',
 30, TRUE)

ON CONFLICT (id) DO NOTHING;

-- ─── ÉTAPE 4 : Injecter les choix (QCM) ─────────────────────

INSERT INTO app.prep_question_choices
  (id, question_id, choice_label, choice_text, is_correct, sort_order)
VALUES

-- Q1: Suites
('44444444-0001-0001-0001-000000000001', '33333333-0001-0001-0001-000000000001', 'A', 'Suite arithmétique', FALSE, 1),
('44444444-0001-0001-0001-000000000002', '33333333-0001-0001-0001-000000000001', 'B', 'Suite géométrique', FALSE, 2),
('44444444-0001-0001-0001-000000000003', '33333333-0001-0001-0001-000000000001', 'C', 'Suite arithmético-géométrique', FALSE, 3),
('44444444-0001-0001-0001-000000000004', '33333333-0001-0001-0001-000000000001', 'D', 'Suite convergente', TRUE, 4),

-- Q2: Dérivée
('44444444-0002-0001-0001-000000000001', '33333333-0002-0002-0002-000000000002', 'A', '$\ln(x)$', TRUE, 1),
('44444444-0002-0001-0001-000000000002', '33333333-0002-0002-0002-000000000002', 'B', '$\ln(x) - 1$', FALSE, 2),
('44444444-0002-0001-0001-000000000003', '33333333-0002-0002-0002-000000000002', 'C', '$\frac{1}{x} - 1$', FALSE, 3),
('44444444-0002-0001-0001-000000000004', '33333333-0002-0002-0002-000000000002', 'D', '$x + \ln(x)$', FALSE, 4),

-- Q3: Argument complexe
('44444444-0003-0001-0001-000000000001', '33333333-0003-0003-0003-000000000003', 'A', '$\frac{\pi}{6}$', FALSE, 1),
('44444444-0003-0001-0001-000000000002', '33333333-0003-0003-0003-000000000003', 'B', '$\frac{\pi}{4}$', TRUE, 2),
('44444444-0003-0001-0001-000000000003', '33333333-0003-0003-0003-000000000003', 'C', '$\frac{\pi}{3}$', FALSE, 3),
('44444444-0003-0001-0001-000000000004', '33333333-0003-0003-0003-000000000003', 'D', '$\frac{\pi}{2}$', FALSE, 4),

-- Q4: Probabilité urne
('44444444-0004-0001-0001-000000000001', '33333333-0004-0004-0004-000000000004', 'A', '$\frac{3}{5}$', FALSE, 1),
('44444444-0004-0001-0001-000000000002', '33333333-0004-0004-0004-000000000004', 'B', '$\frac{5}{8}$', FALSE, 2),
('44444444-0004-0001-0001-000000000003', '33333333-0004-0004-0004-000000000004', 'C', '$\frac{3}{8}$', TRUE, 3),
('44444444-0004-0001-0001-000000000004', '33333333-0004-0004-0004-000000000004', 'D', '$\frac{5}{3}$', FALSE, 4),

-- Q5: Cylindre
('44444444-0005-0001-0001-000000000001', '33333333-0005-0005-0005-000000000005', 'A', '$250\pi$ cm³', TRUE, 1),
('44444444-0005-0001-0001-000000000002', '33333333-0005-0005-0005-000000000005', 'B', '$150\pi$ cm³', FALSE, 2),
('44444444-0005-0001-0001-000000000003', '33333333-0005-0005-0005-000000000005', 'C', '$500\pi$ cm³', FALSE, 3),
('44444444-0005-0001-0001-000000000004', '33333333-0005-0005-0005-000000000005', 'D', '$50\pi$ cm³', FALSE, 4),

-- Q6: Médiane
('44444444-0006-0001-0001-000000000001', '33333333-0006-0006-0006-000000000006', 'A', '9', FALSE, 1),
('44444444-0006-0001-0001-000000000002', '33333333-0006-0006-0006-000000000006', 'B', '11', TRUE, 2),
('44444444-0006-0001-0001-000000000003', '33333333-0006-0006-0006-000000000006', 'C', '14', FALSE, 3),
('44444444-0006-0001-0001-000000000004', '33333333-0006-0006-0006-000000000006', 'D', '12', FALSE, 4),

-- Q7: Vitesse cycliste
('44444444-0007-0001-0001-000000000001', '33333333-0011-0011-0011-000000000011', 'A', '30 km/h', FALSE, 1),
('44444444-0007-0001-0001-000000000002', '33333333-0011-0011-0011-000000000011', 'B', '36 km/h', TRUE, 2),
('44444444-0007-0001-0001-000000000003', '33333333-0011-0011-0011-000000000011', 'C', '40 km/h', FALSE, 3),
('44444444-0007-0001-0001-000000000004', '33333333-0011-0011-0011-000000000011', 'D', '45 km/h', FALSE, 4),

-- Q8: Intensité courant
('44444444-0008-0001-0001-000000000001', '33333333-0012-0012-0012-000000000012', 'A', 'La tension', FALSE, 1),
('44444444-0008-0001-0001-000000000002', '33333333-0012-0012-0012-000000000012', 'B', 'La résistance', FALSE, 2),
('44444444-0008-0001-0001-000000000003', '33333333-0012-0012-0012-000000000012', 'C', 'L''intensité du courant', TRUE, 3),
('44444444-0008-0001-0001-000000000004', '33333333-0012-0012-0012-000000000012', 'D', 'La puissance', FALSE, 4),

-- Q9: Lentille convergente
('44444444-0009-0001-0001-000000000001', '33333333-0013-0013-0013-000000000013', 'A', 'Virtuelle et droite', FALSE, 1),
('44444444-0009-0001-0001-000000000002', '33333333-0013-0013-0013-000000000013', 'B', 'Réelle et renversée', TRUE, 2),
('44444444-0009-0001-0001-000000000003', '33333333-0013-0013-0013-000000000013', 'C', 'Virtuelle et renversée', FALSE, 3),
('44444444-0009-0001-0001-000000000004', '33333333-0013-0013-0013-000000000013', 'D', 'Réelle et droite', FALSE, 4),

-- Q10: Saponification
('44444444-0010-0001-0001-000000000001', '33333333-0021-0021-0021-000000000021', 'A', 'Un acide et une base', FALSE, 1),
('44444444-0010-0001-0001-000000000002', '33333333-0021-0021-0021-000000000021', 'B', 'Un ester et une base forte', TRUE, 2),
('44444444-0010-0001-0001-000000000003', '33333333-0021-0021-0021-000000000021', 'C', 'Un alcool et un acide', FALSE, 3),
('44444444-0010-0001-0001-000000000004', '33333333-0021-0021-0021-000000000021', 'D', 'Deux acides', FALSE, 4),

-- Q11: pH HCl
('44444444-0011-0001-0001-000000000001', '33333333-0022-0022-0022-000000000022', 'A', '0', FALSE, 1),
('44444444-0011-0001-0001-000000000002', '33333333-0022-0022-0022-000000000022', 'B', '1', TRUE, 2),
('44444444-0011-0001-0001-000000000003', '33333333-0022-0022-0022-000000000022', 'C', '2', FALSE, 3),
('44444444-0011-0001-0001-000000000004', '33333333-0022-0022-0022-000000000022', 'D', '3', FALSE, 4),

-- Q12: NaCl dissous
('44444444-0012-0001-0001-000000000001', '33333333-0023-0023-0023-000000000023', 'A', 'Des molécules de NaCl', FALSE, 1),
('44444444-0012-0001-0001-000000000002', '33333333-0023-0023-0023-000000000023', 'B', 'Des ions Na⁺ et Cl⁻', TRUE, 2),
('44444444-0012-0001-0001-000000000003', '33333333-0023-0023-0023-000000000023', 'C', 'Du sodium métallique et du chlore gazeux', FALSE, 3),
('44444444-0012-0001-0001-000000000004', '33333333-0023-0023-0023-000000000023', 'D', 'De l''hydroxyde de sodium', FALSE, 4),

-- Q13: Ribosomes
('44444444-0013-0001-0001-000000000001', '33333333-0031-0031-0031-000000000031', 'A', 'Dans le noyau', FALSE, 1),
('44444444-0013-0001-0001-000000000002', '33333333-0031-0031-0031-000000000031', 'B', 'Dans les mitochondries', FALSE, 2),
('44444444-0013-0001-0001-000000000003', '33333333-0031-0031-0031-000000000031', 'C', 'Dans les ribosomes', TRUE, 3),
('44444444-0013-0001-0001-000000000004', '33333333-0031-0031-0031-000000000031', 'D', 'Dans l''appareil de Golgi', FALSE, 4),

-- Q14: Leucocytes
('44444444-0014-0001-0001-000000000001', '33333333-0032-0032-0032-000000000032', 'A', 'Les hématies', FALSE, 1),
('44444444-0014-0001-0001-000000000002', '33333333-0032-0032-0032-000000000032', 'B', 'Les plaquettes', FALSE, 2),
('44444444-0014-0001-0001-000000000003', '33333333-0032-0032-0032-000000000032', 'C', 'Les leucocytes', TRUE, 3),
('44444444-0014-0001-0001-000000000004', '33333333-0032-0032-0032-000000000032', 'D', 'Les lymphocytes uniquement', FALSE, 4),

-- Q15: ADN noyau
('44444444-0015-0001-0001-000000000001', '33333333-0033-0033-0033-000000000033', 'A', 'Le cytoplasme', FALSE, 1),
('44444444-0015-0001-0001-000000000002', '33333333-0033-0033-0033-000000000033', 'B', 'Les ribosomes', FALSE, 2),
('44444444-0015-0001-0001-000000000003', '33333333-0033-0033-0033-000000000033', 'C', 'Le noyau', TRUE, 3),
('44444444-0015-0001-0001-000000000004', '33333333-0033-0033-0033-000000000033', 'D', 'Les mitochondries', FALSE, 4),

-- Q16: PIB
('44444444-0016-0001-0001-000000000001', '33333333-0041-0041-0041-000000000041', 'A', 'La richesse accumulée par un pays', FALSE, 1),
('44444444-0016-0001-0001-000000000002', '33333333-0041-0041-0041-000000000041', 'B', 'La production de richesses sur un territoire en un an', TRUE, 2),
('44444444-0016-0001-0001-000000000003', '33333333-0041-0041-0041-000000000041', 'C', 'Le niveau de vie des habitants', FALSE, 3),
('44444444-0016-0001-0001-000000000004', '33333333-0041-0041-0041-000000000041', 'D', 'Les exportations moins les importations', FALSE, 4),

-- Q17: Inflation
('44444444-0017-0001-0001-000000000001', '33333333-0042-0042-0042-000000000042', 'A', 'Une baisse des prix', FALSE, 1),
('44444444-0017-0001-0001-000000000002', '33333333-0042-0042-0042-000000000042', 'B', 'Une hausse générale et durable des prix', TRUE, 2),
('44444444-0017-0001-0001-000000000003', '33333333-0042-0042-0042-000000000042', 'C', 'Une augmentation du chômage', FALSE, 3),
('44444444-0017-0001-0001-000000000004', '33333333-0042-0042-0042-000000000042', 'D', 'Une baisse de la production', FALSE, 4),

-- Q18: Marché concurrentiel
('44444444-0018-0001-0001-000000000001', '33333333-0043-0043-0043-000000000043', 'A', 'L''État uniquement', FALSE, 1),
('44444444-0018-0001-0001-000000000002', '33333333-0043-0043-0043-000000000043', 'B', 'Les producteurs uniquement', FALSE, 2),
('44444444-0018-0001-0001-000000000003', '33333333-0043-0043-0043-000000000043', 'C', 'L''offre et la demande', TRUE, 3),
('44444444-0018-0001-0001-000000000004', '33333333-0043-0043-0043-000000000043', 'D', 'Les consommateurs uniquement', FALSE, 4),

-- Q19: Chef de l'État BF
('44444444-0019-0001-0001-000000000001', '33333333-0051-0051-0051-000000000051', 'A', 'Le Premier ministre', FALSE, 1),
('44444444-0019-0001-0001-000000000002', '33333333-0051-0051-0051-000000000051', 'B', 'Le Président de l''Assemblée', FALSE, 2),
('44444444-0019-0001-0001-000000000003', '33333333-0051-0051-0051-000000000051', 'C', 'Le Président du Faso', TRUE, 3),
('44444444-0019-0001-0001-000000000004', '33333333-0051-0051-0051-000000000051', 'D', 'Le Ministre de la Justice', FALSE, 4),

-- Q20: Majorité civile BF
('44444444-0020-0001-0001-000000000001', '33333333-0052-0052-0052-000000000052', 'A', '16 ans', FALSE, 1),
('44444444-0020-0001-0001-000000000002', '33333333-0052-0052-0052-000000000052', 'B', '18 ans', TRUE, 2),
('44444444-0020-0001-0001-000000000003', '33333333-0052-0052-0052-000000000052', 'C', '20 ans', FALSE, 3),
('44444444-0020-0001-0001-000000000004', '33333333-0052-0052-0052-000000000052', 'D', '21 ans', FALSE, 4)

ON CONFLICT (id) DO NOTHING;

-- ─── ÉTAPE 5 : Enregistrer le document source ─────────────────

INSERT INTO app.prep_source_documents
  (subject_id, year, doc_type, source_type, extracted_text, status)
SELECT
  (SELECT id FROM app.prep_subjects WHERE slug = 'mathematiques'),
  2026,
  'concours',
  'text',
  'Document de préparation au concours (Burkina Faso) — Matières: Mathématiques, Physique, Chimie, Biologie, Économie, Droit. Document original scanné et reconverti. 20 questions injectées manuellement dans le système le 2026-03-24.',
  'processed'
WHERE NOT EXISTS (
  SELECT 1 FROM app.prep_source_documents
  WHERE doc_type = 'concours' AND year = 2026
  AND extracted_text LIKE '%2026-03-24%'
);

-- ─── VÉRIFICATION ──────────────────────────────────────────

SELECT
  s.title AS matière,
  COUNT(q.id) AS nb_questions
FROM app.prep_subjects s
LEFT JOIN app.prep_questions q
  ON q.subject_id = s.id AND q.is_published = TRUE
GROUP BY s.title
ORDER BY s.title;
