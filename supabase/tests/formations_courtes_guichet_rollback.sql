-- Essai du guichet et du tableau de session (lot 2, 27/10/2026), en
-- transaction ANNULÉE (RAISE EXCEPTION final). Avant application, coller la
-- migration 20261027150000 à l'endroit marqué « MIGRATION ».
-- Effet résiduel : chaque exécution consomme des numéros de reçu.
DO $essai$
DECLARE
  c_a     uuid := '0fc48f26-1f57-4e6b-96f9-1690f111cad3';
  c_b     uuid := '5dfeaa14-2f6b-4ffb-8ea2-32e953cc7208';
  c_c     uuid := 'c47212f3-c9e8-42e9-bb9e-5429c903e0ef';
  c_admin uuid := '5f0584e1-e260-4635-aba9-ad3352f31a6a';
  v_t uuid; v_s uuid; v_pay uuid; r jsonb; v_txt text; v_n int;
  v_log text := ''; v_fail int := 0;
BEGIN
  -- ===== MIGRATION =====

  CREATE FUNCTION pg_temp.fc_as(p_uid uuid, p_role text DEFAULT 'authenticated') RETURNS void LANGUAGE plpgsql AS $f$
  BEGIN
    IF p_uid IS NULL THEN
      PERFORM set_config('request.jwt.claims', json_build_object('role', p_role)::text, true);
      PERFORM set_config('request.jwt.claim.sub', '', true);
    ELSE
      PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
      PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    END IF;
  END $f$;
  CREATE FUNCTION pg_temp.fc_ok(p_cond boolean, p_label text, p_detail text DEFAULT NULL) RETURNS text LANGUAGE sql AS $f$
    SELECT CASE WHEN COALESCE(p_cond, false) THEN 'OK ' ELSE 'ECHEC ' END || p_label
           || CASE WHEN COALESCE(p_cond, false) OR p_detail IS NULL THEN '' ELSE ' :: ' || p_detail END || E'\n'
  $f$;

  UPDATE app.students SET phone = '22670999001' WHERE id = c_a;
  INSERT INTO app.short_trainings (title, price, is_active, benefits)
  VALUES ('ESSAI guichet', 10000, true, '[]'::jsonb) RETURNING id INTO v_t;
  INSERT INTO app.short_training_sessions (training_id, start_at, end_at, location, capacity, status, is_active)
  VALUES (v_t, now() + interval '5 days', now() + interval '6 days', 'Tanghin', 2, 'open', true) RETURNING id INTO v_s;

  -- 1. Un étudiant n'a accès à rien
  PERFORM pg_temp.fc_as(c_a);
  r := public.app_admin_find_students_by_phone('70999001');
  v_log := v_log || pg_temp.fc_ok(r->>'error' = 'not_admin', '1 recherche refusee a un etudiant', r::text);
  r := public.app_admin_short_training_cash(v_s, c_a);
  v_log := v_log || pg_temp.fc_ok(r->>'error' = 'not_admin', '1 guichet refuse a un etudiant', r::text);
  r := public.app_admin_short_training_session_board(v_s);
  v_log := v_log || pg_temp.fc_ok(r->>'error' = 'not_admin', '1 tableau refuse a un etudiant', r::text);

  -- 2. Recherche par téléphone (8 chiffres, avec espaces, avec indicatif)
  PERFORM pg_temp.fc_as(c_admin);
  r := public.app_admin_find_students_by_phone('70 99 90 01');
  v_log := v_log || pg_temp.fc_ok(jsonb_array_length(r->'students') >= 1
                                  AND (r->'students'->0->>'student_id')::uuid = c_a, '2 trouve par 8 chiffres', r::text);
  r := public.app_admin_find_students_by_phone('+226 70999001');
  v_log := v_log || pg_temp.fc_ok(jsonb_array_length(r->'students') >= 1, '2 trouve avec indicatif', r::text);
  r := public.app_admin_find_students_by_phone('123');
  v_log := v_log || pg_temp.fc_ok(r->>'error' = 'numero_invalide', '2 numero trop court', r::text);

  -- 3. Encaissement espèces de A
  r := public.app_admin_short_training_cash(v_s, c_a, 'Payé au siège');
  v_pay := (r->>'payment_id')::uuid;
  v_log := v_log || pg_temp.fc_ok((r->>'success')::boolean AND r->>'receipt_number' LIKE 'REC-%', '3 guichet A', r::text);
  SELECT status INTO v_txt FROM app.short_training_registrations WHERE session_id = v_s AND user_id = c_a;
  v_log := v_log || pg_temp.fc_ok(v_txt = 'confirmed', '3 place A confirmee', v_txt);
  SELECT pr.snapshot->'reglement'->>'canal' || ' / ' || (pr.snapshot->>'libelle') INTO v_txt
  FROM app.payment_receipts pr WHERE pr.payment_id = v_pay;
  v_log := v_log || pg_temp.fc_ok(v_txt = 'cash / Inscription — formation pratique', '3 recu especes', v_txt);
  r := public.app_admin_short_training_cash(v_s, c_a);
  v_log := v_log || pg_temp.fc_ok(r->>'error' = 'deja_inscrit', '3 pas de double encaissement', r::text);

  -- 4. B a déclaré un Mobile Money : le guichet refuse tant que ce n'est pas tranché
  PERFORM pg_temp.fc_as(c_b);
  r := public.app_short_training_checkout(v_s, 'mobile_money', 'orange_money', 'ESSAIGUICHET01');
  v_pay := (r->>'payment_id')::uuid;
  PERFORM pg_temp.fc_as(c_admin);
  r := public.app_admin_short_training_cash(v_s, c_b);
  v_log := v_log || pg_temp.fc_ok(r->>'error' = 'paiement_declare_en_attente', '4 declaration en attente bloque', r::text);
  r := public.app_admin_verify_payment(v_pay, 'invalid', 'Référence introuvable');
  SELECT payment_status || ' / ' || (hold_expires_at <= now())::text INTO v_txt
  FROM app.short_training_registrations WHERE session_id = v_s AND user_id = c_b;
  v_log := v_log || pg_temp.fc_ok(v_txt = 'rejected / true', '4 refus libere la place', v_txt);
  r := public.app_admin_short_training_cash(v_s, c_b);
  v_log := v_log || pg_temp.fc_ok((r->>'success')::boolean, '4 guichet B apres refus', r::text);

  -- 5. Capacité 2 atteinte
  r := public.app_admin_short_training_cash(v_s, c_c);
  v_log := v_log || pg_temp.fc_ok(r->>'error' = 'complet', '5 complet', r::text);
  r := public.app_admin_short_training_cash(v_s, c_c, NULL, true);
  v_log := v_log || pg_temp.fc_ok((r->>'success')::boolean, '5 depassement explicite', r::text);

  -- 6. Le tableau
  r := public.app_admin_short_training_session_board(v_s);
  v_log := v_log || pg_temp.fc_ok((r->'totals'->>'confirmes')::int = 3
                                  AND (r->'totals'->>'encaisse_especes')::numeric = 30000
                                  AND (r->'totals'->>'a_valider')::int = 0
                                  AND jsonb_array_length(r->'registrations') = 3,
                                  '6 totaux du tableau', (r->'totals')::text);
  SELECT count(*) INTO v_n FROM jsonb_array_elements(r->'registrations') x
  WHERE x->>'receipt_number' LIKE 'REC-%' AND x->>'etat' = 'confirmee';
  v_log := v_log || pg_temp.fc_ok(v_n = 3, '6 trois recus visibles', v_n::text);

  -- 7. Formation terminée
  UPDATE app.short_training_sessions SET start_at = now() - interval '3 days', end_at = now() - interval '2 days' WHERE id = v_s;
  r := public.app_admin_short_training_cash(v_s, c_c);
  v_log := v_log || pg_temp.fc_ok(r->>'error' IN ('formation_terminee', 'deja_inscrit'), '7 garde de fin', r::text);

  v_fail := (length(v_log) - length(replace(v_log, 'ECHEC', ''))) / 5;
  RAISE EXCEPTION 'ESSAI-GUICHET echecs=% %', v_fail, E'\n' || v_log;
END
$essai$;
