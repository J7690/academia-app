-- Formations courtes, lot 2 (27/10/2026) : le GUICHET et le TABLEAU de session.
--
-- 1. `app_admin_find_students_by_phone` : retrouver au guichet le compte d'une
--    personne par son numéro (les numéros sont stockés « 226XXXXXXXX »).
-- 2. `app_admin_short_training_cash` : encaisser en espèces au siège en un
--    geste — paiement `cash` confirmé par l'admin, place confirmée par le
--    déclencheur du lot 1, reçu émis. Même verrou de capacité que l'inscription
--    en ligne ; l'admin peut le lever explicitement (`p_allow_over_capacity`).
-- 3. `app_admin_short_training_session_board` : tout ce que l'équipe doit voir
--    d'une session — inscrits, état lisible, moyen, référence, reçu, totaux.
--
-- Valider ou refuser un Mobile Money déclaré passe par les fonctions qui
-- existent déjà : `app_admin_confirm_payment` et `app_admin_verify_payment`
-- (décision `invalid` → `rejected`, et le déclencheur libère la place).
--
-- Contrôle admin : `raw_app_meta_data->>'role'` (cf. correctif du 14/09 dans
-- `app_admin_confirm_payment`), jamais `raw_user_meta_data`, que l'utilisateur
-- peut écrire lui-même.

CREATE OR REPLACE FUNCTION app.formation_courte_est_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
  SELECT COALESCE(
    (SELECT raw_app_meta_data->>'role' IN ('admin', 'super_admin')
       FROM auth.users WHERE id = auth.uid()),
    false);
$$;

REVOKE ALL ON FUNCTION app.formation_courte_est_admin() FROM PUBLIC, anon, authenticated;

-- ─── 1. Recherche par téléphone ────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.app_admin_find_students_by_phone(p_phone text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_digits text := regexp_replace(COALESCE(p_phone, ''), '\D', '', 'g');
  v_full   text;
  v_local  text;
  v_result jsonb;
BEGIN
  IF NOT app.formation_courte_est_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;
  IF length(v_digits) = 8 THEN
    v_full := '226' || v_digits;
  ELSE
    v_full := v_digits;
  END IF;
  v_local := right(v_full, 8);
  IF length(v_local) < 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'numero_invalide',
      'message', 'Saisissez un numéro à 8 chiffres.');
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'student_id', s.id,
           'full_name', s.full_name,
           'phone', COALESCE(NULLIF(u.phone, ''), s.phone),
           'email', u.email,
           'created_at', s.created_at) ORDER BY s.created_at), '[]'::jsonb)
    INTO v_result
  FROM app.students s
  JOIN auth.users u ON u.id = s.id
  WHERE u.phone IN (v_full, v_local)
     OR regexp_replace(COALESCE(s.phone, ''), '\D', '', 'g') IN (v_full, v_local)
     OR regexp_replace(COALESCE(s.whatsapp_phone, ''), '\D', '', 'g') IN (v_full, v_local);

  RETURN jsonb_build_object('success', true, 'phone', v_full, 'students', v_result);
END;
$$;

REVOKE ALL ON FUNCTION public.app_admin_find_students_by_phone(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_find_students_by_phone(text) TO authenticated;

-- ─── 2. L'encaissement au guichet ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.app_admin_short_training_cash(
  p_session_id          uuid,
  p_student_id          uuid,
  p_note                text    DEFAULT NULL,
  p_allow_over_capacity boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_admin      uuid := auth.uid();
  v_s          app.short_training_sessions%ROWTYPE;
  v_t          app.short_trainings%ROWTYPE;
  v_reg        app.short_training_registrations%ROWTYPE;
  v_pay        app.application_payments%ROWTYPE;
  v_phone      text;
  v_payment_id uuid;
  v_ref        text;
  v_recu       jsonb;
BEGIN
  IF NOT app.formation_courte_est_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  SELECT * INTO v_s FROM app.short_training_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_introuvable',
      'message', 'Cette session n''existe plus.');
  END IF;
  SELECT * INTO v_t FROM app.short_trainings WHERE id = v_s.training_id;

  IF NOT v_s.is_active THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_inactive',
      'message', 'Cette session est désactivée.');
  END IF;
  -- Au guichet, on encaisse jusqu'à la fin de la formation (retardataires du
  -- premier jour), pas seulement jusqu'à son début.
  IF COALESCE(v_s.end_at, v_s.start_at + interval '1 day') < now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'formation_terminee',
      'message', 'Cette formation est terminée.');
  END IF;
  IF COALESCE(v_t.price, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'tarif_absent',
      'message', 'Le tarif de cette formation n''est pas fixé.');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM app.students WHERE id = p_student_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'etudiant_introuvable',
      'message', 'Ce compte n''a pas de profil étudiant.');
  END IF;

  SELECT * INTO v_reg FROM app.short_training_registrations
  WHERE session_id = p_session_id AND user_id = p_student_id FOR UPDATE;

  IF FOUND THEN
    IF v_reg.status = 'confirmed' THEN
      RETURN jsonb_build_object('success', false, 'error', 'deja_inscrit',
        'registration_id', v_reg.id,
        'message', 'Cette personne est déjà inscrite : sa place est confirmée.');
    END IF;
    IF v_reg.payment_id IS NOT NULL THEN
      SELECT * INTO v_pay FROM app.application_payments WHERE id = v_reg.payment_id;
      IF FOUND THEN
        -- Un Mobile Money déclaré attend une décision : on ne l'encaisse pas une
        -- deuxième fois en espèces sans l'avoir tranché.
        IF v_pay.status IN ('declared_by_student', 'under_verification') THEN
          RETURN jsonb_build_object('success', false, 'error', 'paiement_declare_en_attente',
            'payment_id', v_pay.id,
            'message', 'Un paiement Mobile Money déclaré attend votre validation : validez-le ou refusez-le d''abord.');
        END IF;
        IF v_pay.status = 'processing' AND v_pay.updated_at > now() - interval '30 minutes' THEN
          RETURN jsonb_build_object('success', false, 'error', 'paiement_en_ligne_en_cours',
            'payment_id', v_pay.id,
            'message', 'Un paiement en ligne est en cours pour cette personne. Réessayez dans quelques minutes.');
        END IF;
        IF v_pay.status = 'pending' THEN
          UPDATE app.application_payments SET status = 'cancelled', updated_at = now()
          WHERE id = v_pay.id;
        END IF;
      END IF;
    END IF;
  END IF;

  IF v_s.capacity IS NOT NULL AND NOT COALESCE(p_allow_over_capacity, false)
     AND app.formation_courte_places_prises(p_session_id, p_student_id) >= v_s.capacity THEN
    RETURN jsonb_build_object('success', false, 'error', 'complet',
      'message', 'La session est complète. Cochez « dépasser la capacité » pour encaisser quand même.');
  END IF;

  SELECT COALESCE(NULLIF(s.whatsapp_phone, ''), NULLIF(s.phone, ''), NULLIF(u.phone, ''))
    INTO v_phone
  FROM app.students s JOIN auth.users u ON u.id = s.id
  WHERE s.id = p_student_id;

  INSERT INTO app.short_training_registrations AS r
    (session_id, user_id, status, contact_phone, payment_method,
     payment_status, amount_due, hold_expires_at, notes)
  VALUES
    (p_session_id, p_student_id, 'pending_payment', v_phone, 'especes',
     'pending', v_t.price, now() + interval '10 minutes', NULLIF(TRIM(p_note), ''))
  ON CONFLICT (session_id, user_id) DO UPDATE SET
    status          = 'pending_payment',
    payment_method  = 'especes',
    payment_status  = 'pending',
    amount_due      = EXCLUDED.amount_due,
    hold_expires_at = EXCLUDED.hold_expires_at,
    notes           = COALESCE(EXCLUDED.notes, r.notes),
    contact_phone   = COALESCE(r.contact_phone, EXCLUDED.contact_phone),
    updated_at      = now()
  RETURNING * INTO v_reg;

  v_ref := 'FC-G-' || to_char(now(), 'YYYYMMDDHH24MISS') || '-'
           || substr(replace(gen_random_uuid()::text, '-', ''), 1, 6);

  INSERT INTO app.application_payments
    (student_id, payment_reason, amount_due, amount_paid, currency, status,
     channel, payment_method, reference_code, phone_number, created_by,
     student_note, short_training_registration_id)
  VALUES
    (p_student_id, 'short_training', v_t.price, v_t.price, 'XOF', 'pending',
     'cash', 'especes', v_ref, v_phone, v_admin,
     COALESCE(NULLIF(TRIM(p_note), ''), 'Encaissé en espèces au guichet'), v_reg.id)
  RETURNING id INTO v_payment_id;

  UPDATE app.short_training_registrations
     SET payment_id = v_payment_id, updated_at = now()
   WHERE id = v_reg.id;

  -- Le passage à `confirmed` déclenche la confirmation de la place.
  UPDATE app.application_payments
     SET status = 'confirmed', confirmed_by = v_admin, confirmed_at = now(), updated_at = now()
   WHERE id = v_payment_id;

  v_recu := app.emettre_recu(v_payment_id, v_admin);

  -- Commissions : même générateur que la validation d'un paiement déclaré.
  PERFORM app_generate_commission_split_for_payment(v_payment_id, NULL);

  RETURN jsonb_build_object(
    'success', true,
    'registration_id', v_reg.id,
    'payment_id', v_payment_id,
    'reference', v_ref,
    'amount', v_t.price,
    'receipt_id', v_recu->>'receipt_id',
    'receipt_number', v_recu->>'receipt_number');
END;
$$;

REVOKE ALL ON FUNCTION public.app_admin_short_training_cash(uuid, uuid, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_short_training_cash(uuid, uuid, text, boolean) TO authenticated;

-- ─── 3. Le tableau de session ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.app_admin_short_training_session_board(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_session jsonb;
  v_rows    jsonb;
  v_totals  jsonb;
BEGIN
  IF NOT app.formation_courte_est_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  SELECT jsonb_build_object(
      'session_id', s.id, 'training_id', t.id, 'title', t.title,
      'organizer_name', t.organizer_name, 'price', t.price,
      'start_at', s.start_at, 'end_at', s.end_at,
      'location', s.location, 'welcome_location', s.welcome_location,
      'practice_location', s.practice_location,
      'registration_deadline', s.registration_deadline,
      'capacity', s.capacity, 'status', s.status, 'is_active', s.is_active,
      'seats_taken', app.formation_courte_places_prises(s.id))
    INTO v_session
  FROM app.short_training_sessions s
  JOIN app.short_trainings t ON t.id = s.training_id
  WHERE s.id = p_session_id;

  IF v_session IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_introuvable');
  END IF;

  WITH lignes AS (
    SELECT r.*, st.full_name, u.email,
           COALESCE(NULLIF(r.contact_phone, ''), NULLIF(st.whatsapp_phone, ''),
                    NULLIF(st.phone, ''), u.phone) AS tel,
           p.status::text AS pay_status, p.channel::text AS pay_channel,
           p.external_reference, p.amount_paid, p.amount_due AS pay_due,
           p.confirmed_at, p.declared_at, p.reference_code,
           (SELECT pr.receipt_number FROM app.payment_receipts pr WHERE pr.payment_id = p.id) AS recu,
           CASE
             WHEN r.status = 'confirmed' THEN 'confirmee'
             WHEN p.status IN ('declared_by_student', 'under_verification') THEN 'a_valider'
             WHEN p.status = 'rejected' THEN 'refusee'
             WHEN r.status = 'pending_payment' AND r.hold_expires_at > now() THEN 'en_cours'
             WHEN r.status = 'pending_payment' THEN 'expiree'
             ELSE 'ancienne'
           END AS etat
    FROM app.short_training_registrations r
    LEFT JOIN app.students st ON st.id = r.user_id
    LEFT JOIN auth.users u ON u.id = r.user_id
    LEFT JOIN app.application_payments p ON p.id = r.payment_id
    WHERE r.session_id = p_session_id
  )
  SELECT
    COALESCE(jsonb_agg(jsonb_build_object(
        'registration_id', l.id, 'user_id', l.user_id,
        'full_name', l.full_name, 'phone', l.tel, 'email', l.email,
        'etat', l.etat, 'status', l.status, 'payment_status', l.pay_status,
        'payment_method', l.payment_method, 'channel', l.pay_channel,
        'external_reference', l.external_reference,
        'payment_id', l.payment_id, 'reference_code', l.reference_code,
        'amount', COALESCE(l.amount_paid, l.pay_due, l.amount_due),
        'receipt_number', l.recu, 'answers', l.answers, 'notes', l.notes,
        'hold_expires_at', l.hold_expires_at, 'declared_at', l.declared_at,
        'confirmed_at', l.confirmed_at, 'created_at', l.created_at,
        'last_message_at', l.last_message_at, 'admin_last_read_at', l.admin_last_read_at)
      ORDER BY CASE l.etat WHEN 'a_valider' THEN 0 WHEN 'en_cours' THEN 1
                           WHEN 'confirmee' THEN 2 ELSE 3 END,
               l.full_name NULLS LAST), '[]'::jsonb),
    jsonb_build_object(
      'confirmes', count(*) FILTER (WHERE l.etat = 'confirmee'),
      'a_valider', count(*) FILTER (WHERE l.etat = 'a_valider'),
      'en_cours', count(*) FILTER (WHERE l.etat = 'en_cours'),
      'encaisse', COALESCE(sum(l.amount_paid) FILTER (WHERE l.etat = 'confirmee'), 0),
      'encaisse_especes', COALESCE(sum(l.amount_paid) FILTER (WHERE l.etat = 'confirmee' AND l.pay_channel = 'cash'), 0),
      'encaisse_ligdicash', COALESCE(sum(l.amount_paid) FILTER (WHERE l.etat = 'confirmee' AND l.pay_channel = 'ligdicash'), 0),
      'encaisse_mobile_money', COALESCE(sum(l.amount_paid) FILTER (WHERE l.etat = 'confirmee'
                                 AND l.pay_channel IN ('orange_money', 'moov_money', 'telecel_money')), 0))
    INTO v_rows, v_totals
  FROM lignes l;

  RETURN jsonb_build_object('success', true, 'session', v_session,
                            'totals', v_totals, 'registrations', v_rows);
END;
$$;

REVOKE ALL ON FUNCTION public.app_admin_short_training_session_board(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_short_training_session_board(uuid) TO authenticated;
