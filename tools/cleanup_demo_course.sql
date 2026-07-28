-- Retire le cours de démonstration créé le 26 juillet 2026 pour la recette
-- du Studio Live, ainsi que ses sections, leçons et inscriptions.
--
-- À exécuter quand la recette est terminée et que du contenu réel l'a remplacé.
-- Sans effet si le cours a déjà été supprimé.

DO $$
DECLARE
  v_course uuid;
  v_lessons int;
  v_sections int;
  v_enrollments int;
BEGIN
  SELECT id INTO v_course FROM app.online_courses
    WHERE title = '[DEMO] Analyse — Suites numériques' LIMIT 1;

  IF v_course IS NULL THEN
    RAISE NOTICE 'Aucun cours de démonstration à retirer.';
    RETURN;
  END IF;

  DELETE FROM app.online_course_lessons
    WHERE section_id IN (SELECT id FROM app.online_course_sections WHERE course_id = v_course);
  GET DIAGNOSTICS v_lessons = ROW_COUNT;

  DELETE FROM app.online_course_sections WHERE course_id = v_course;
  GET DIAGNOSTICS v_sections = ROW_COUNT;

  DELETE FROM app.online_course_enrollments WHERE course_id = v_course;
  GET DIAGNOSTICS v_enrollments = ROW_COUNT;

  -- Les séances du moteur unifié rattachées à ce cours perdent leur rattachement
  -- mais sont conservées : elles peuvent contenir un historique de recette utile.
  UPDATE app.academia_sessions SET course_id = NULL WHERE course_id = v_course;

  DELETE FROM app.online_courses WHERE id = v_course;

  RAISE NOTICE 'Cours de démonstration retiré : % leçon(s), % section(s), % inscription(s).',
    v_lessons, v_sections, v_enrollments;
END $$;
