-- Transforme un compte existant en conseiller d'orientation, avec ses
-- créneaux de disponibilité.
--
-- À exécuter APRÈS avoir créé le compte dans Supabase → Authentication →
-- Users → Add user. Ce script ne crée aucun compte : il ne fait que rattacher
-- un compte existant au module d'orientation.
--
-- Idempotent : relançable sans dommage.
--
-- Pour retirer ce conseiller de démonstration :
--   DELETE FROM app.orientation_counselors
--    WHERE user_id = (SELECT id FROM auth.users WHERE email = 'conseiller.orientation@academia.test');
--   (les créneaux et rendez-vous suivent en cascade)

DO $$
DECLARE
  v_email text := 'conseiller.orientation@academia.test';
  v_user  uuid;
BEGIN
  SELECT id INTO v_user FROM auth.users WHERE email = v_email;

  IF v_user IS NULL THEN
    RAISE EXCEPTION
      'Compte % introuvable. Créez-le d''abord dans Supabase → Authentication → Users → Add user.',
      v_email;
  END IF;

  -- ── Profil du conseiller ─────────────────────────────────────────────
  INSERT INTO app.orientation_counselors (
    user_id, full_name, kind, specialites, niveaux, langues,
    bio, tarif_fcfa, duree_minutes, is_active
  ) VALUES (
    v_user,
    'Mariam Zongo',
    'orientation',
    ARRAY[
      'filieres_scientifiques',
      'filieres_litteraires',
      'concours_fonction_publique',
      'etudes_superieures'
    ],
    ARRAY['terminale', 'licence', 'master'],
    ARRAY['fr', 'moore', 'dioula'],
    'Conseillère d''orientation. J''accompagne les élèves de terminale et les '
    || 'étudiants dans le choix de leur filière, la préparation des concours de '
    || 'la fonction publique et les dossiers d''admission.',
    0,   -- gratuit pendant la phase de test
    45,
    true
  )
  ON CONFLICT (user_id) DO UPDATE SET
    full_name     = excluded.full_name,
    kind          = excluded.kind,
    specialites   = excluded.specialites,
    niveaux       = excluded.niveaux,
    langues       = excluded.langues,
    bio           = excluded.bio,
    tarif_fcfa    = excluded.tarif_fcfa,
    duree_minutes = excluded.duree_minutes,
    is_active     = true,
    updated_at    = now();

  -- ── Créneaux ─────────────────────────────────────────────────────────
  -- Large volontairement, pour que le test trouve toujours un créneau libre
  -- quelle que soit l'heure à laquelle vous l'effectuez.
  DELETE FROM app.orientation_availability WHERE counselor_id = v_user;

  INSERT INTO app.orientation_availability (counselor_id, weekday, start_time, end_time)
  SELECT v_user, d, '08:00'::time, '12:00'::time FROM generate_series(0, 6) d;

  INSERT INTO app.orientation_availability (counselor_id, weekday, start_time, end_time)
  SELECT v_user, d, '14:00'::time, '19:00'::time FROM generate_series(0, 6) d;

  RAISE NOTICE 'Conseiller % prêt (%). Créneaux : tous les jours 8h-12h et 14h-19h.',
    v_email, v_user;
END $$;

-- Contrôle
SELECT c.full_name,
       u.email,
       c.duree_minutes,
       array_length(c.specialites, 1) AS nb_specialites,
       (SELECT count(*) FROM app.orientation_availability a
         WHERE a.counselor_id = c.user_id) AS plages_hebdomadaires
FROM app.orientation_counselors c
JOIN auth.users u ON u.id = c.user_id;
