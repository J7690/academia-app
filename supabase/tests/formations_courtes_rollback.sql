-- Essai de bout en bout des formations courtes (lot 1, 27/10/2026), en
-- transaction ANNULÉE : le bloc finit par RAISE EXCEPTION 'ESSAI ...'.
--
-- Pour éprouver la migration AVANT de l'appliquer, coller le contenu de
-- 20261027120000_formations_courtes_payer_pour_s_inscrire.sql à l'endroit
-- marqué « MIGRATION » ci-dessous. Après application, l'exécuter tel quel.
--
-- Comptes d'essai (@academia.test) : A = student.review, B = test_credit_e2e,
-- C = commercial.review, admin = admin.review.
-- Effet résiduel connu : `app.recu_numero_seq` n'est pas transactionnelle,
-- chaque exécution consomme deux numéros de reçu.
DO $essai$
DECLARE
  c_a     uuid := '0fc48f26-1f57-4e6b-96f9-1690f111cad3';
  c_b     uuid := '5dfeaa14-2f6b-4ffb-8ea2-32e953cc7208';
  c_c     uuid := 'c47212f3-c9e8-42e9-bb9e-5429c903e0ef';
  c_admin uuid := '5f0584e1-e260-4635-aba9-ad3352f31a6a';
  v_t uuid; v_s uuid; v_pay uuid; v_pay2 uuid; v_reg uuid;
  r jsonb; v_snap jsonb; v_txt text; v_n int;
  v_log text := ''; v_fail int := 0;
BEGIN
  -- ===== MIGRATION =====

  CREATE FUNCTION pg_temp.fc_as(p_uid uuid, p_role text DEFAULT 'authenticated') RETURNS void
  LANGUAGE plpgsql AS $f$
  BEGIN
    IF p_uid IS NULL THEN
      PERFORM set_config('request.jwt.claims', json_build_object('role', p_role)::text, true);
      PERFORM set_config('request.jwt.claim.sub', '', true);
    ELSE
      PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
      PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    END IF;
  END $f$;

  CREATE FUNCTION pg_temp.fc_ok(p_cond boolean, p_label text, p_detail text DEFAULT NULL) RETURNS text
  LANGUAGE sql AS $f$
    SELECT CASE WHEN COALESCE(p_cond, false) THEN 'OK ' ELSE 'ECHEC ' END
           || p_label || CASE WHEN COALESCE(p_cond, false) OR p_detail IS NULL THEN '' ELSE ' :: ' || p_detail END
           || E'\n'
  $f$;

  INSERT INTO app.short_trainings (title, short_description, price, is_active, organizer_name, benefits)
  VALUES ('ESSAI asticots', 'essai', 10000, true, 'Nexiom Group',
          '["Boîtier de production","Conseils techniques"]'::jsonb)
  RETURNING id INTO v_t;
  INSERT INTO app.short_training_sessions
    (training_id, start_at, end_at, location, welcome_location, practice_location, capacity, status, is_active)
  VALUES (v_t, now() + interval '10 days', now() + interval '11 days', 'Tanghin',
          'Siège de Nexiom Group, Tanghin', 'Kamboinssin', 2, 'open', true)
  RETURNING id INTO v_s;

  -- 1. Sans connexion : refusé
  PERFORM pg_temp.fc_as(NULL, 'anon');
  r := public.app_short_training_checkout(v_s, 'ligdicash');
  v_log := v_log || pg_temp.fc_ok(r->>'error' = 'not_authenticated', '1 anon refuse', r::text);

  -- 2. A, LigdiCash : montant lu côté serveur
  PERFORM pg_temp.fc_as(c_a);
  r := public.app_short_training_checkout(v_s, 'ligdicash', NULL, NULL, '{"elevage":"volailles"}');
  v_pay := (r->>'payment_id')::uuid;
  v_log := v_log || pg_temp.fc_ok((r->>'success')::boolean AND (r->>'amount')::numeric = 10000, '2 A checkout', r::text);
  SELECT count(*) INTO v_n FROM app.application_payments
   WHERE id = v_pay AND amount_due = 10000 AND payment_reason = 'short_training'
     AND status = 'pending' AND short_training_registration_id IS NOT NULL;
  v_log := v_log || pg_temp.fc_ok(v_n = 1, '2 paiement cree conforme');

  -- 3. A recommence : l'ancien paiement jamais lancé est annulé
  r := public.app_short_training_checkout(v_s, 'ligdicash');
  v_pay2 := (r->>'payment_id')::uuid;
  SELECT status::text INTO v_txt FROM app.application_payments WHERE id = v_pay;
  v_log := v_log || pg_temp.fc_ok(v_pay2 <> v_pay AND v_txt = 'cancelled', '3 relance annule le precedent', v_txt);

  -- 4. LigdiCash lance puis confirme (côté serveur)
  UPDATE app.application_payments SET status = 'processing' WHERE id = v_pay2;
  SELECT payment_status INTO v_txt FROM app.short_training_registrations WHERE payment_id = v_pay2;
  v_log := v_log || pg_temp.fc_ok(v_txt = 'processing', '4 suivi processing', v_txt);
  r := public.app_short_training_checkout(v_s, 'ligdicash');
  v_log := v_log || pg_temp.fc_ok(r->>'error' = 'paiement_en_cours', '4 pas de doublon pendant processing', r::text);
  PERFORM pg_temp.fc_as(NULL, 'service_role');
  r := public.app_confirm_ligdicash_payment(v_pay2, 'TOK-ESSAI', 'TX-ESSAI-1', 'orange', 'short_training', 10000);
  v_log := v_log || pg_temp.fc_ok((r->>'success')::boolean, '4 confirmation LigdiCash', r::text);
  SELECT status INTO v_txt FROM app.short_training_registrations WHERE session_id = v_s AND user_id = c_a;
  v_log := v_log || pg_temp.fc_ok(v_txt = 'confirmed', '4 inscription A confirmee par le serveur', v_txt);

  -- 5. Le reçu
  SELECT pr.snapshot INTO v_snap FROM app.payment_receipts pr WHERE pr.payment_id = v_pay2;
  v_log := v_log || pg_temp.fc_ok(v_snap->>'libelle' = 'Inscription — formation pratique', '5 libelle', v_snap->>'libelle');
  v_log := v_log || pg_temp.fc_ok(v_snap->'formation_courte'->>'lieu_pratique' = 'Kamboinssin'
                                  AND v_snap->'formation_courte'->>'lieu_accueil' LIKE 'Siège%'
                                  AND jsonb_array_length(v_snap->'formation_courte'->'avantages') = 2,
                                  '5 bloc formation', (v_snap->'formation_courte')::text);
  v_log := v_log || pg_temp.fc_ok(v_snap->'formation_courte'->>'mentions' LIKE 'Aucun remboursement après le début%',
                                  '5 mentions par defaut', v_snap->'formation_courte'->>'mentions');
  v_log := v_log || pg_temp.fc_ok(v_snap->>'designation' LIKE 'ESSAI asticots · du %', '5 designation datee', v_snap->>'designation');
  v_log := v_log || pg_temp.fc_ok((v_snap->>'montant')::numeric = 10000, '5 montant');

  -- 6. A déjà inscrit
  PERFORM pg_temp.fc_as(c_a);
  r := public.app_short_training_checkout(v_s, 'ligdicash');
  v_log := v_log || pg_temp.fc_ok((r->>'deja_inscrit')::boolean, '6 deja inscrit', r::text);

  -- 7. B, Mobile Money déclaré au 66 66 05 38
  PERFORM pg_temp.fc_as(c_b);
  r := public.app_short_training_checkout(v_s, 'mobile_money', 'orange_money', '12');
  v_log := v_log || pg_temp.fc_ok(r->>'error' = 'reference_transaction_requise', '7 reference trop courte', r::text);
  r := public.app_short_training_checkout(v_s, 'mobile_money', 'free_money', 'PP231027.1234.A5');
  v_log := v_log || pg_temp.fc_ok(r->>'error' = 'operateur_invalide', '7 operateur invalide', r::text);
  r := public.app_short_training_checkout(v_s, 'mobile_money', 'orange_money', 'pp231027.1234.a5');
  v_pay := (r->>'payment_id')::uuid;
  v_log := v_log || pg_temp.fc_ok(r->>'status' = 'declared_by_student', '7 B declare', r::text);
  r := public.app_short_training_checkout(v_s, 'ligdicash');
  v_log := v_log || pg_temp.fc_ok(r->>'error' = 'paiement_en_cours', '7 B bloque pendant verification', r::text);

  -- 8. Capacité 2 : A confirmé + B tenu → C refusé
  PERFORM pg_temp.fc_as(c_c);
  r := public.app_short_training_checkout(v_s, 'mobile_money', 'moov_money', 'PP231027.1234.A5');
  v_log := v_log || pg_temp.fc_ok(r->>'error' = 'complet', '8 complet', r::text);
  SELECT (x->>'seats_left')::int INTO v_n
  FROM jsonb_array_elements(public.app_list_public_short_training_sessions()) x
  WHERE (x->>'session_id')::uuid = v_s;
  v_log := v_log || pg_temp.fc_ok(v_n = 0, '8 places restantes = 0', v_n::text);

  -- 9. La page publique
  PERFORM pg_temp.fc_as(NULL, 'anon');
  SELECT count(*) INTO v_n
  FROM jsonb_array_elements(public.app_public_landing_content()->'short_training_highlights') x
  WHERE (x->>'session_id')::uuid = v_s;
  v_log := v_log || pg_temp.fc_ok(v_n = 1, '9 session sur la page publique');

  -- 10. L'admin valide le Mobile Money de B
  PERFORM pg_temp.fc_as(c_admin);
  r := public.app_admin_confirm_payment(v_pay);
  v_log := v_log || pg_temp.fc_ok((r->>'success')::boolean, '10 validation admin', r::text);
  SELECT status INTO v_txt FROM app.short_training_registrations WHERE session_id = v_s AND user_id = c_b;
  v_log := v_log || pg_temp.fc_ok(v_txt = 'confirmed', '10 inscription B confirmee', v_txt);
  SELECT pr.snapshot->'reglement'->>'reference_operateur' INTO v_txt FROM app.payment_receipts pr WHERE pr.payment_id = v_pay;
  v_log := v_log || pg_temp.fc_ok(v_txt = 'PP231027.1234.A5', '10 recu porte la reference operateur', v_txt);

  -- 11. Ancienne version de l'app : p_amount ignoré
  UPDATE app.short_training_sessions SET capacity = 3 WHERE id = v_s;
  INSERT INTO app.short_training_registrations (session_id, user_id, status)
  VALUES (v_s, c_c, 'registered') RETURNING id INTO v_reg;
  PERFORM pg_temp.fc_as(c_c);
  r := public.app_student_create_short_training_payment(v_reg, 5, 'mobile_money');
  v_log := v_log || pg_temp.fc_ok((r->>'amount')::numeric = 10000, '11 ancien appel : montant serveur', r::text);

  -- 12. Mes formations : le numéro de reçu remonte
  PERFORM pg_temp.fc_as(c_a);
  SELECT x->>'receipt_number' INTO v_txt
  FROM jsonb_array_elements(public.app_list_my_short_trainings()) x
  WHERE (x->>'session_id')::uuid = v_s;
  v_log := v_log || pg_temp.fc_ok(v_txt LIKE 'REC-%', '12 recu dans mes formations', v_txt);

  -- 13. Date limite passée
  UPDATE app.short_training_sessions SET registration_deadline = now() - interval '1 hour' WHERE id = v_s;
  PERFORM pg_temp.fc_as(c_c);
  r := public.app_short_training_checkout(v_s, 'ligdicash');
  v_log := v_log || pg_temp.fc_ok(r->>'error' = 'date_limite_depassee', '13 date limite', r::text);

  v_fail := (length(v_log) - length(replace(v_log, 'ECHEC', ''))) / 5;
  RAISE EXCEPTION 'ESSAI echecs=% %', v_fail, E'\n' || v_log;
END
$essai$;
