-- Formations courtes : PAYER, C'EST S'INSCRIRE (lot 1, 27/10/2026).
--
-- Ce que cette migration répare, mesuré en production le 27/10 :
--   * `app_student_create_short_training_payment` écrivait dans `user_id`,
--     `payment_type`, `reference_id`, `amount` — QUATRE colonnes absentes de
--     `app.application_payments`. Le paiement en ligne échouait à chaque appel
--     depuis sa création, et le montant venait du téléphone (`p_amount`).
--   * L'inscription était une réservation (`registered`) ; le paiement n'était
--     proposé qu'à qui choisissait « Mobile money » dans un formulaire.
--   * L'inscription ne passait à `confirmed` que si le téléphone rappelait
--     `app_confirm_short_training_payment` après le paiement.
--   * `app_public_landing_content` ne renvoyait pas `short_training_highlights` :
--     la section de la page publique ne s'affichait jamais.
--   * Le reçu n'avait pas de cas « formation courte » (« Prestation Academia »).
--
-- Ce qu'elle établit :
--   1. une fiche formation complète (affiche, organisateur, avantages, deux
--      lieux, date limite, mentions du reçu, mise en avant) ;
--   2. UNE fonction d'inscription-paiement, `app_short_training_checkout`, pour
--      les deux moyens en ligne : LigdiCash (place tenue 30 min) et Mobile
--      Money au 66 66 05 38 déclaré avec son n° de transaction (place tenue
--      48 h, validée par l'admin via `app_admin_confirm_payment`, inchangée) ;
--      le montant est TOUJOURS le prix de la formation, lu ici ;
--   3. la confirmation de l'inscription PAR LE SERVEUR, dès que le paiement
--      passe à `confirmed`, quel que soit le chemin (LigdiCash, admin) ;
--   4. un reçu propre à la formation (bloc `formation_courte` + mentions) ;
--   5. les formations courtes sur la page publique.
--
-- Règle de la maison (Jocelyn, 27/10) : aucun remboursement après le début de
-- la formation. C'est la mention par défaut du reçu.

-- ─── 1. La fiche formation ─────────────────────────────────────────────────

ALTER TABLE app.short_trainings
  ADD COLUMN IF NOT EXISTS slug             text,
  ADD COLUMN IF NOT EXISTS poster_url       text,
  ADD COLUMN IF NOT EXISTS organizer_name   text    NOT NULL DEFAULT 'Nexiom Group',
  ADD COLUMN IF NOT EXISTS benefits         jsonb   NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS receipt_mentions text,
  ADD COLUMN IF NOT EXISTS contact_whatsapp text,
  ADD COLUMN IF NOT EXISTS is_featured      boolean NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS short_trainings_slug_key
  ON app.short_trainings (slug) WHERE slug IS NOT NULL;

ALTER TABLE app.short_training_sessions
  ADD COLUMN IF NOT EXISTS welcome_location      text,
  ADD COLUMN IF NOT EXISTS practice_location     text,
  ADD COLUMN IF NOT EXISTS registration_deadline timestamptz;

-- Une place « tenue » le temps du paiement ; passé ce délai, elle se libère
-- d'elle-même (aucune tâche planifiée : on compare à now() au comptage).
ALTER TABLE app.short_training_registrations
  ADD COLUMN IF NOT EXISTS hold_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS answers         jsonb;

-- Le lien du paiement vers SON inscription. `short_training_registrations.
-- payment_id` ne pointe que vers le DERNIER paiement : un paiement LigdiCash
-- abandonné puis confirmé tardivement doit quand même retrouver son inscription.
ALTER TABLE app.application_payments
  ADD COLUMN IF NOT EXISTS short_training_registration_id uuid
    REFERENCES app.short_training_registrations(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS application_payments_short_training_reg_idx
  ON app.application_payments (short_training_registration_id)
  WHERE short_training_registration_id IS NOT NULL;

-- ─── 1 bis. Créer une session échouait ─────────────────────────────────────
-- Trouvé par l'essai du 27/10 : le déclencheur de notification lisait
-- `short_training_registrations.training_id`, colonne qui n'existe pas. Toute
-- création de session tombait en erreur « column r.training_id does not
-- exist » — aucune session créée depuis le 28/11/2025. Les anciens inscrits
-- d'une formation se retrouvent par leur session.

CREATE OR REPLACE FUNCTION public.app_notify_short_training_session()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE v_student RECORD; v_training_title TEXT;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_active = TRUE THEN
        SELECT title INTO v_training_title FROM app.short_trainings WHERE id = NEW.training_id;
        FOR v_student IN
            SELECT DISTINCT r.user_id
            FROM app.short_training_registrations r
            JOIN app.short_training_sessions s ON s.id = r.session_id
            WHERE s.training_id = NEW.training_id AND r.user_id IS NOT NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_student.user_id, 'student_short_trainings', 'new_session',
                JSONB_BUILD_OBJECT('training_id', NEW.training_id, 'training_title', COALESCE(v_training_title,''), 'session_id', NEW.id));
        END LOOP;
    END IF;
    RETURN NEW;
END; $function$;

-- ─── 2. Places prises ──────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION app.formation_courte_places_prises(
  p_session_id uuid, p_sauf_user uuid DEFAULT NULL)
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
  SELECT count(*)::int
  FROM app.short_training_registrations r
  WHERE r.session_id = p_session_id
    AND r.user_id IS DISTINCT FROM p_sauf_user
    AND (r.status = 'confirmed'
         OR (r.status = 'pending_payment' AND r.hold_expires_at > now()));
$$;

REVOKE ALL ON FUNCTION app.formation_courte_places_prises(uuid, uuid) FROM PUBLIC, anon, authenticated;

-- ─── 3. L'inscription-paiement ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.app_short_training_checkout(
  p_session_id      uuid,
  p_method          text  DEFAULT 'ligdicash',
  p_operator        text  DEFAULT NULL,
  p_transaction_ref text  DEFAULT NULL,
  p_answers         jsonb DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_uid        uuid := auth.uid();
  v_s          app.short_training_sessions%ROWTYPE;
  v_t          app.short_trainings%ROWTYPE;
  v_reg        app.short_training_registrations%ROWTYPE;
  v_pay        app.application_payments%ROWTYPE;
  v_phone      text;
  v_payment_id uuid;
  v_ref        text;
  v_hold       timestamptz;
  v_status     public.payment_status;
  v_tx         text := NULLIF(upper(regexp_replace(COALESCE(p_transaction_ref, ''), '\s', '', 'g')), '');
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated',
      'message', 'Connectez-vous pour vous inscrire.');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM app.students WHERE id = v_uid) THEN
    RETURN jsonb_build_object('success', false, 'error', 'profil_etudiant_absent',
      'message', 'Votre compte n''a pas de profil étudiant.');
  END IF;

  IF p_method NOT IN ('ligdicash', 'mobile_money') THEN
    RETURN jsonb_build_object('success', false, 'error', 'moyen_invalide',
      'message', 'Moyen de paiement non reconnu.');
  END IF;

  -- Verrou sur la session : deux paiements simultanés ne prennent pas la
  -- dernière place tous les deux.
  SELECT * INTO v_s FROM app.short_training_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_introuvable',
      'message', 'Cette session n''existe plus.');
  END IF;

  SELECT * INTO v_t FROM app.short_trainings WHERE id = v_s.training_id;

  IF NOT (v_s.is_active AND v_s.status = 'open' AND v_t.is_active) THEN
    RETURN jsonb_build_object('success', false, 'error', 'inscriptions_fermees',
      'message', 'Les inscriptions à cette session sont fermées.');
  END IF;
  IF v_s.start_at <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'formation_commencee',
      'message', 'Les inscriptions sont closes : la formation a commencé.');
  END IF;
  IF v_s.registration_deadline IS NOT NULL AND v_s.registration_deadline < now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'date_limite_depassee',
      'message', 'La date limite d''inscription est passée.');
  END IF;
  IF COALESCE(v_t.price, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'tarif_absent',
      'message', 'Le tarif de cette formation n''est pas encore fixé.');
  END IF;

  SELECT * INTO v_reg FROM app.short_training_registrations
  WHERE session_id = p_session_id AND user_id = v_uid FOR UPDATE;

  IF FOUND THEN
    IF v_reg.status = 'confirmed' THEN
      RETURN jsonb_build_object('success', true, 'deja_inscrit', true,
        'registration_id', v_reg.id, 'payment_id', v_reg.payment_id,
        'title', v_t.title,
        'message', 'Vous êtes déjà inscrit(e) : votre place est confirmée.');
    END IF;

    IF v_reg.payment_id IS NOT NULL THEN
      SELECT * INTO v_pay FROM app.application_payments WHERE id = v_reg.payment_id;
      IF FOUND THEN
        IF v_pay.status IN ('declared_by_student', 'under_verification')
           OR (v_pay.status = 'processing' AND v_pay.updated_at > now() - interval '30 minutes') THEN
          RETURN jsonb_build_object('success', false, 'error', 'paiement_en_cours',
            'registration_id', v_reg.id, 'payment_id', v_pay.id,
            'status', v_pay.status::text,
            'message', CASE WHEN v_pay.status = 'processing'
              THEN 'Un paiement est en cours pour cette inscription. Validez-le sur votre téléphone ou réessayez dans 30 minutes.'
              ELSE 'Votre paiement est en cours de vérification par l''équipe. Votre place est tenue en attendant.' END);
        END IF;
        -- Jamais lancé : on l'annule, un neuf le remplace. Un paiement
        -- `processing` ancien n'est PAS annulé : s'il aboutit plus tard, le
        -- déclencheur retrouvera l'inscription par `short_training_registration_id`.
        IF v_pay.status = 'pending' THEN
          UPDATE app.application_payments SET status = 'cancelled', updated_at = now()
          WHERE id = v_pay.id;
        END IF;
      END IF;
    END IF;
  END IF;

  IF v_s.capacity IS NOT NULL
     AND app.formation_courte_places_prises(p_session_id, v_uid) >= v_s.capacity THEN
    RETURN jsonb_build_object('success', false, 'error', 'complet',
      'message', 'Cette session est complète.');
  END IF;

  IF p_method = 'mobile_money' THEN
    IF COALESCE(p_operator, '') NOT IN ('orange_money', 'moov_money', 'telecel_money') THEN
      RETURN jsonb_build_object('success', false, 'error', 'operateur_invalide',
        'message', 'Choisissez l''opérateur utilisé (Orange, Moov ou Telecel).');
    END IF;
    IF v_tx IS NULL OR length(v_tx) < 6 THEN
      RETURN jsonb_build_object('success', false, 'error', 'reference_transaction_requise',
        'message', 'Saisissez la référence de transaction reçue par SMS.');
    END IF;
    IF EXISTS (SELECT 1 FROM app.application_payments
               WHERE upper(external_reference) = v_tx
                 AND channel IN ('orange_money', 'moov_money', 'telecel_money')) THEN
      RETURN jsonb_build_object('success', false, 'error', 'reference_deja_utilisee',
        'message', 'Cette référence de transaction a déjà été déclarée.');
    END IF;
  END IF;

  SELECT COALESCE(NULLIF(s.whatsapp_phone, ''), NULLIF(s.phone, ''), NULLIF(u.phone, ''))
    INTO v_phone
  FROM app.students s JOIN auth.users u ON u.id = s.id
  WHERE s.id = v_uid;

  v_hold := LEAST(
    now() + CASE WHEN p_method = 'ligdicash' THEN interval '30 minutes' ELSE interval '48 hours' END,
    v_s.start_at);

  INSERT INTO app.short_training_registrations AS r
    (session_id, user_id, status, contact_phone, payment_method,
     payment_status, amount_due, hold_expires_at, answers)
  VALUES
    (p_session_id, v_uid, 'pending_payment', v_phone, p_method,
     'pending', v_t.price, v_hold, p_answers)
  ON CONFLICT (session_id, user_id) DO UPDATE SET
    status          = 'pending_payment',
    payment_method  = EXCLUDED.payment_method,
    payment_status  = 'pending',
    amount_due      = EXCLUDED.amount_due,
    hold_expires_at = EXCLUDED.hold_expires_at,
    answers         = COALESCE(EXCLUDED.answers, r.answers),
    contact_phone   = COALESCE(r.contact_phone, EXCLUDED.contact_phone),
    updated_at      = now()
  RETURNING * INTO v_reg;

  v_ref := 'FC-' || to_char(now(), 'YYYYMMDDHH24MISS') || '-'
           || substr(replace(gen_random_uuid()::text, '-', ''), 1, 6);

  IF p_method = 'ligdicash' THEN
    v_status := 'pending';
    INSERT INTO app.application_payments
      (student_id, payment_reason, amount_due, currency, status, channel,
       payment_method, reference_code, phone_number, short_training_registration_id)
    VALUES
      (v_uid, 'short_training', v_t.price, 'XOF', v_status, 'ligdicash',
       'ligdicash_otp', v_ref, v_phone, v_reg.id)
    RETURNING id INTO v_payment_id;
  ELSE
    v_status := 'declared_by_student';
    INSERT INTO app.application_payments
      (student_id, payment_reason, amount_due, amount_paid, currency, status,
       channel, payment_method, reference_code, external_reference, phone_number,
       declared_at, student_note, short_training_registration_id)
    VALUES
      (v_uid, 'short_training', v_t.price, v_t.price, 'XOF', v_status,
       p_operator::public.payment_channel, 'mobile_money_manuel', v_ref, v_tx, v_phone,
       now(), 'Formation courte « ' || v_t.title || ' » — Mobile Money envoyé au 66 66 05 38 (Nexiom)',
       v_reg.id)
    RETURNING id INTO v_payment_id;
  END IF;

  UPDATE app.short_training_registrations
     SET payment_id = v_payment_id, payment_status = v_status::text, updated_at = now()
   WHERE id = v_reg.id;

  RETURN jsonb_build_object(
    'success', true,
    'registration_id', v_reg.id,
    'payment_id', v_payment_id,
    'amount', v_t.price,
    'currency', 'XOF',
    'reference', v_ref,
    'status', v_status::text,
    'hold_expires_at', v_hold,
    'title', v_t.title);
END;
$$;

REVOKE ALL ON FUNCTION public.app_short_training_checkout(uuid, text, text, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_short_training_checkout(uuid, text, text, text, jsonb) TO authenticated;

-- L'ancienne entrée, gardée pour les versions de l'application déjà installées.
-- `p_amount` est IGNORÉ : le prix fait foi.
CREATE OR REPLACE FUNCTION public.app_student_create_short_training_payment(
  p_registration_id uuid DEFAULT NULL::uuid,
  p_amount numeric DEFAULT 0,
  p_payment_method text DEFAULT 'mobile_money'::text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_session uuid;
BEGIN
  SELECT session_id INTO v_session
  FROM app.short_training_registrations
  WHERE id = p_registration_id AND user_id = auth.uid();

  IF v_session IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'registration_not_found');
  END IF;

  RETURN public.app_short_training_checkout(v_session, 'ligdicash');
END;
$$;

REVOKE ALL ON FUNCTION public.app_student_create_short_training_payment(uuid, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_student_create_short_training_payment(uuid, numeric, text) TO authenticated;

REVOKE ALL ON FUNCTION public.app_confirm_short_training_payment(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_confirm_short_training_payment(uuid, text) TO authenticated;

-- ─── 4. La confirmation par le serveur ─────────────────────────────────────

CREATE OR REPLACE FUNCTION app.formation_courte_suivre_paiement()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
BEGIN
  IF NEW.short_training_registration_id IS NULL
     OR NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  IF NEW.status = 'confirmed' THEN
    -- L'argent est encaissé : la place est confirmée, même si le délai de
    -- garde est dépassé. On ne garde jamais l'argent sans la place.
    UPDATE app.short_training_registrations
       SET status = 'confirmed', payment_status = 'confirmed',
           payment_id = NEW.id, hold_expires_at = NULL, updated_at = now()
     WHERE id = NEW.short_training_registration_id;
  ELSIF NEW.status IN ('rejected', 'cancelled') THEN
    UPDATE app.short_training_registrations
       SET payment_status = NEW.status::text,
           hold_expires_at = LEAST(COALESCE(hold_expires_at, now()), now()),
           updated_at = now()
     WHERE id = NEW.short_training_registration_id
       AND payment_id = NEW.id AND status <> 'confirmed';
  ELSE
    UPDATE app.short_training_registrations
       SET payment_status = NEW.status::text, updated_at = now()
     WHERE id = NEW.short_training_registration_id
       AND payment_id = NEW.id AND status <> 'confirmed';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_formation_courte_suivre_paiement ON app.application_payments;
CREATE TRIGGER trg_formation_courte_suivre_paiement
  AFTER UPDATE OF status ON app.application_payments
  FOR EACH ROW EXECUTE FUNCTION app.formation_courte_suivre_paiement();

-- ─── 5. Les listes ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.app_list_public_short_training_sessions()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(x.item ORDER BY x.is_featured DESC, x.start_at ASC), '[]'::jsonb)
    INTO v_result
  FROM (
    SELECT t.is_featured, s.start_at,
      jsonb_build_object(
        'session_id', s.id,
        'training_id', t.id,
        'slug', t.slug,
        'title', t.title,
        'short_description', t.short_description,
        'full_description', t.full_description,
        'category', t.category,
        'modality', t.modality,
        'organizer_name', t.organizer_name,
        'poster_url', t.poster_url,
        'benefits', t.benefits,
        'contact_whatsapp', t.contact_whatsapp,
        'is_featured', t.is_featured,
        'start_at', s.start_at,
        'end_at', s.end_at,
        'location', s.location,
        'welcome_location', s.welcome_location,
        'practice_location', s.practice_location,
        'registration_deadline', s.registration_deadline,
        'capacity', s.capacity,
        'seats_left', CASE WHEN s.capacity IS NULL THEN NULL
                           ELSE GREATEST(s.capacity - app.formation_courte_places_prises(s.id), 0) END,
        'registration_open', (s.registration_deadline IS NULL OR s.registration_deadline >= now())
                             AND COALESCE(t.price, 0) > 0,
        'status', s.status,
        'price', t.price
      ) AS item
    FROM app.short_training_sessions s
    JOIN app.short_trainings t ON t.id = s.training_id
    WHERE s.is_active = TRUE
      AND t.is_active = TRUE
      AND s.status = 'open'
      AND s.start_at >= now()
  ) x;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_list_public_short_training_sessions() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.app_list_my_short_trainings()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_result  jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'registration_id', r.id,
        'session_id', s.id,
        'training_id', t.id,
        'title', t.title,
        'short_description', t.short_description,
        'category', t.category,
        'modality', t.modality,
        'organizer_name', t.organizer_name,
        'start_at', s.start_at,
        'end_at', s.end_at,
        'location', s.location,
        'welcome_location', s.welcome_location,
        'practice_location', s.practice_location,
        'price', t.price,
        'status', r.status,
        'payment_status', r.payment_status,
        'payment_id', r.payment_id,
        'amount_due', r.amount_due,
        'hold_expires_at', r.hold_expires_at,
        'receipt_number', (SELECT pr.receipt_number FROM app.payment_receipts pr
                           WHERE pr.payment_id = r.payment_id),
        'created_at', r.created_at,
        'last_message_at', r.last_message_at,
        'student_last_read_at', r.student_last_read_at,
        'admin_last_read_at', r.admin_last_read_at
      ) ORDER BY s.start_at ASC), '[]'::jsonb)
    INTO v_result
  FROM app.short_training_registrations r
  JOIN app.short_training_sessions s ON s.id = r.session_id
  JOIN app.short_trainings t ON t.id = s.training_id
  WHERE r.user_id = v_user_id;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.app_list_my_short_trainings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_list_my_short_trainings() TO authenticated;

-- ─── 6. La page publique ───────────────────────────────────────────────────
-- Identique à la version en production, plus `short_training_highlights`,
-- la clé que `LandingContentProvider` lit depuis toujours.

CREATE OR REPLACE FUNCTION public.app_public_landing_content()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_config JSONB;
    v_announcements JSONB;
    v_partners JSONB;
    v_why_cards JSONB;
    v_videos JSONB;
    v_short_trainings JSONB;
BEGIN
    SELECT COALESCE(
      TO_JSONB(c)
      || JSONB_BUILD_OBJECT(
        'playback', JSONB_BUILD_OBJECT(
          'best_url', COALESCE(
            (
              SELECT r.public_url_hint
              FROM app.video_renditions r
              WHERE r.video_asset_id = c.video_asset_id
                AND r.status = 'ready'
                AND r.kind IN ('hls','mp4')
              ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
              LIMIT 1
            ),
            c.hero_video_url
          ),
          'poster_url', (
            SELECT r.public_url_hint
            FROM app.video_renditions r
            WHERE r.video_asset_id = c.video_asset_id
              AND r.status = 'ready'
              AND r.kind IN ('poster','thumbnail')
            ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
            LIMIT 1
          )
        )
      ),
      '{}'::JSONB
    )
    INTO v_config
    FROM app.landing_config c
    ORDER BY c.created_at DESC
    LIMIT 1;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(a) ORDER BY a.sort_order, a.created_at),
        '[]'::JSONB
    )
    INTO v_announcements
    FROM app.landing_announcements a
    WHERE a.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(p) ORDER BY p.sort_order, p.created_at),
        '[]'::JSONB
    )
    INTO v_partners
    FROM app.landing_partners p
    WHERE p.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(w) ORDER BY w.sort_order, w.created_at),
        '[]'::JSONB
    )
    INTO v_why_cards
    FROM app.landing_why_cards w
    WHERE w.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(
          (
            TO_JSONB(v)
            || JSONB_BUILD_OBJECT(
              'playback', JSONB_BUILD_OBJECT(
                'best_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = v.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('hls','mp4')
                  ORDER BY (r.kind = 'hls') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                ),
                'poster_url', (
                  SELECT r.public_url_hint
                  FROM app.video_renditions r
                  WHERE r.video_asset_id = v.video_asset_id
                    AND r.status = 'ready'
                    AND r.kind IN ('poster','thumbnail')
                  ORDER BY (r.kind = 'poster') DESC, COALESCE(r.width, 0) DESC
                  LIMIT 1
                )
              )
            )
          )
          ORDER BY v.sort_order, v.created_at
        ),
        '[]'::JSONB
    )
    INTO v_videos
    FROM app.landing_videos v
    WHERE v.is_active = TRUE;

    v_short_trainings := public.app_list_public_short_training_sessions();

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'config', v_config,
        'announcements', v_announcements,
        'partners', v_partners,
        'why_cards', v_why_cards,
        'videos', v_videos,
        'short_training_highlights', v_short_trainings
    );
END;
$function$;

-- ─── 7. Le reçu ────────────────────────────────────────────────────────────
-- Identique à la version en production (relevée le 27/10), plus le cas
-- `short_training` : libellé, désignation datée, bloc `formation_courte`
-- (organisateur, dates, deux lieux, avantages, mentions). Les mentions sont
-- figées dans l'instantané : un reçu ne change jamais après émission.

CREATE OR REPLACE FUNCTION app.emettre_recu(p_payment_id uuid, p_issued_by uuid DEFAULT NULL::uuid, p_complement jsonb DEFAULT NULL::jsonb, p_email_secours text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_p            app.application_payments%ROWTYPE;
  v_existant     app.payment_receipts%ROWTYPE;
  v_numero       TEXT;
  v_recu_id      UUID;
  v_emetteur     UUID;
  v_nom          TEXT;
  v_tel          TEXT;
  v_email        TEXT;
  v_ville        TEXT;
  v_pays         TEXT;
  v_formation    TEXT;
  v_niveau       TEXT;
  v_universite   TEXT;
  v_pack_nom     TEXT;
  v_pack_code    TEXT;
  v_credits      INTEGER;
  v_libelle      TEXT;
  v_designation  TEXT;
  v_montant      NUMERIC;
  v_source_mt    TEXT;
  v_moyen        TEXT;
  v_encaisse_le  TIMESTAMPTZ;
  v_snapshot     JSONB;
  v_empreinte    TEXT;
  v_fc           JSONB;
  v_fc_dates     TEXT;
BEGIN
  IF p_payment_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'payment_id_manquant');
  END IF;

  SELECT * INTO v_p FROM app.application_payments WHERE id = p_payment_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'paiement_introuvable');
  END IF;

  SELECT * INTO v_existant FROM app.payment_receipts WHERE payment_id = p_payment_id;
  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', TRUE, 'deja_emis', TRUE,
      'receipt_id', v_existant.id, 'receipt_number', v_existant.receipt_number);
  END IF;

  -- ── LE VERROU INTERIEUR, POSE LE 10/09 ──────────────────────────────────
  IF v_p.status <> 'confirmed'::public.payment_status THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'paiement_non_confirme',
      'statut', v_p.status::text);
  END IF;

  SELECT s.full_name, s.phone, s.city, s.country
    INTO v_nom, v_tel, v_ville, v_pays
  FROM app.students s WHERE s.id = v_p.student_id;

  SELECT u.email INTO v_email FROM auth.users u WHERE u.id = v_p.student_id;

  -- Le compte fait foi quand il existe ; le courriel saisi ne sert que
  -- lorsqu'il n'y a pas de compte. Dans cet ordre, une saisie manuelle ne
  -- peut pas ecraser l'adresse authentifiee d'un etudiant reel.
  v_email := COALESCE(v_email, NULLIF(TRIM(p_email_secours), ''));

  v_tel := COALESCE(NULLIF(v_p.phone_number, ''), v_tel);

  IF v_p.application_id IS NOT NULL THEN
    SELECT pr.title, pr.degree_level, un.name
      INTO v_formation, v_niveau, v_universite
    FROM app.applications a
    JOIN app.programs pr          ON pr.id = a.program_id
    LEFT JOIN app.universities un ON un.id = pr.university_id
    WHERE a.id = v_p.application_id;
  END IF;

  IF v_universite IS NULL AND v_p.university_id IS NOT NULL THEN
    SELECT name INTO v_universite FROM app.universities WHERE id = v_p.university_id;
  END IF;

  IF v_p.payment_reason = 'credit_purchase'::public.payment_reason THEN
    SELECT cp.name, cp.code, cp.credits
      INTO v_pack_nom, v_pack_code, v_credits
    FROM app.credit_packs cp WHERE cp.code = v_p.external_reference;
  END IF;

  -- Formation courte (27/10) : le reçu dit QUOI, QUAND, OÙ, et à quelles
  -- conditions. C'est aussi le ticket présenté le jour de la formation.
  IF v_p.payment_reason = 'short_training'::public.payment_reason
     AND v_p.short_training_registration_id IS NOT NULL THEN
    SELECT
      t.title,
      CASE
        WHEN s.end_at IS NULL
          OR (s.end_at AT TIME ZONE 'Africa/Ouagadougou')::date
             = (s.start_at AT TIME ZONE 'Africa/Ouagadougou')::date
        THEN 'le ' || TO_CHAR(s.start_at AT TIME ZONE 'Africa/Ouagadougou', 'DD/MM/YYYY')
        ELSE 'du ' || TO_CHAR(s.start_at AT TIME ZONE 'Africa/Ouagadougou', 'DD/MM/YYYY')
             || ' au ' || TO_CHAR(s.end_at AT TIME ZONE 'Africa/Ouagadougou', 'DD/MM/YYYY')
      END,
      jsonb_strip_nulls(jsonb_build_object(
        'inscription_id', r.id,
        'titre', t.title,
        'organisateur', t.organizer_name,
        'debut', s.start_at,
        'fin', s.end_at,
        'lieu_accueil', NULLIF(COALESCE(s.welcome_location, s.location), ''),
        'lieu_pratique', NULLIF(s.practice_location, ''),
        'avantages', CASE WHEN jsonb_typeof(t.benefits) = 'array'
                           AND jsonb_array_length(t.benefits) > 0 THEN t.benefits END,
        'contact', NULLIF(t.contact_whatsapp, ''),
        'mentions', COALESCE(NULLIF(TRIM(t.receipt_mentions), ''),
          'Aucun remboursement après le début de la formation. '
          || 'Ce reçu est à présenter le jour de la formation.')))
      INTO v_formation, v_fc_dates, v_fc
    FROM app.short_training_registrations r
    JOIN app.short_training_sessions s ON s.id = r.session_id
    JOIN app.short_trainings t         ON t.id = s.training_id
    WHERE r.id = v_p.short_training_registration_id;

    IF v_fc IS NOT NULL THEN
      v_fc := v_fc || jsonb_build_object('dates', v_fc_dates);
    END IF;
  END IF;

  v_libelle := CASE v_p.payment_reason::text
    WHEN 'application_fee'          THEN 'Frais de courtage — candidature universitaire'
    WHEN 'registration_fee'         THEN 'Frais d''inscription'
    WHEN 'tuition_deposit'          THEN 'Acompte sur frais de scolarité'
    WHEN 'td_access'                THEN 'Accès aux travaux dirigés'
    WHEN 'subscription'             THEN 'Abonnement Academia'
    WHEN 'credit_purchase'          THEN 'Achat de crédits'
    WHEN 'online_course'            THEN 'Cours en ligne'
    WHEN 'orientation_consultation' THEN 'Consultation d''orientation'
    WHEN 'prep_concours'            THEN 'Préparation aux concours'
    WHEN 'marketplace_purchase'     THEN 'Achat sur la place de marché'
    WHEN 'short_training'           THEN 'Inscription — formation pratique'
    ELSE 'Prestation Academia'
  END;

  v_designation := NULLIF(TRIM(BOTH ' ·' FROM CONCAT_WS(' · ',
      NULLIF(v_universite, ''),
      NULLIF(CONCAT_WS(' ', NULLIF(v_formation,''),
                            CASE WHEN COALESCE(v_niveau,'') <> ''
                                 THEN '(' || v_niveau || ')' END), ''),
      CASE WHEN v_pack_nom IS NOT NULL
           THEN 'Pack ' || v_pack_nom ||
                COALESCE(' · ' || v_credits::text || ' crédits', '') END,
      NULLIF(v_fc_dates, '')
    )), '');

  IF v_p.amount_paid IS NOT NULL AND v_p.amount_paid > 0 THEN
    v_montant := v_p.amount_paid;  v_source_mt := 'encaisse';
  ELSE
    v_montant := v_p.amount_due;   v_source_mt := 'attendu';
  END IF;

  v_moyen := app.libelle_moyen_paiement(
    v_p.channel::text, v_p.payment_method, v_p.ligdicash_operator);

  v_encaisse_le := COALESCE(v_p.confirmed_at, v_p.declared_at, v_p.created_at);
  v_emetteur    := COALESCE(p_issued_by, auth.uid(), v_p.confirmed_by, v_p.student_id);
  v_numero      := 'REC-' || TO_CHAR(NOW(), 'YYYY') || '-'
                   || LPAD(NEXTVAL('app.recu_numero_seq')::text, 6, '0');

  v_snapshot := jsonb_strip_nulls(jsonb_build_object(
    'version', 2,
    'numero', v_numero,
    'emis_le', NOW(),
    'motif', v_p.payment_reason::text,
    'libelle', v_libelle,
    'designation', v_designation,
    'montant', v_montant,
    'montant_source', v_source_mt,
    'devise', COALESCE(NULLIF(v_p.currency, ''), 'XOF'),
    'emetteur', jsonb_build_object(
      'raison_sociale', 'NEXIOM GROUP',
      'ville', 'Ouagadougou', 'pays', 'Burkina Faso',
      'rccm', 'BF-OUA-01-2025-B13-13341', 'ifu', '00281802P',
      'telephone', '73 93 43 92', 'email', 'contact@academiea.com',
      'site', 'www.app.academiea.com'),
    'payeur', jsonb_strip_nulls(jsonb_build_object(
      'id', v_p.student_id, 'nom', v_nom, 'telephone', v_tel,
      'email', v_email, 'ville', v_ville, 'pays', v_pays)),
    'reglement', jsonb_strip_nulls(jsonb_build_object(
      'canal', v_p.channel::text,
      'moyen', v_moyen,
      'operateur', NULLIF(v_p.ligdicash_operator, ''),
      'encaisse_le', v_encaisse_le,
      'reference_academia', v_p.reference_code,
      'reference_operateur', COALESCE(NULLIF(v_p.ligdicash_transaction_id, ''),
                                      CASE WHEN v_p.payment_reason = 'short_training'::public.payment_reason
                                           THEN NULLIF(v_p.external_reference, '') END))),
    'dossier', CASE WHEN v_p.application_id IS NOT NULL THEN jsonb_strip_nulls(
      jsonb_build_object('candidature_id', v_p.application_id,
                         'formation', v_formation, 'niveau', v_niveau,
                         'universite', v_universite)) END,
    'credits', CASE WHEN v_pack_code IS NOT NULL THEN
      jsonb_build_object('pack', v_pack_nom, 'code', v_pack_code,
                         'quantite', v_credits) END,
    'formation_courte', v_fc
  )) || COALESCE(p_complement, '{}'::jsonb);

  v_empreinte := app.empreinte_recu(v_numero, v_p.id);

  INSERT INTO app.payment_receipts (
    payment_id, receipt_number, issued_by, issued_at, snapshot,
    student_name, student_phone, student_email,
    training_name, credit_pack_name, signature_hash)
  VALUES (
    v_p.id, v_numero, v_emetteur, NOW(), v_snapshot,
    v_nom, v_tel, v_email,
    NULLIF(CONCAT_WS(' — ', NULLIF(v_universite,''), NULLIF(v_formation,'')), ''),
    v_pack_nom, v_empreinte)
  RETURNING id INTO v_recu_id;

  RETURN jsonb_build_object(
    'success', TRUE, 'deja_emis', FALSE,
    'receipt_id', v_recu_id, 'receipt_number', v_numero,
    'signature_hash', v_empreinte);
END;
$function$;
