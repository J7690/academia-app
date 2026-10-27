-- Formations courtes, fin du lot 2 (27/10/2026) :
--   1. la fiche complète éditable par l'admin — affiche, organisateur,
--      avantages, mentions du reçu, contact, mise en avant, lien court (slug) ;
--      pour la session : lieu d'accueil, lieu de pratique, date limite ;
--   2. le TICKET : le reçu porte un QR « ACADEMIA-FC:<n° de reçu>:<12 car. de
--      l'empreinte> » ; à l'entrée, l'équipe le scanne et la présence est notée ;
--   3. le tableau de session compte les présents.
--
-- Contrôle admin : les trois anciennes fonctions lisaient `raw_user_meta_data`.
-- Le déclencheur `sync_role_from_app_metadata` le réécrit depuis
-- `raw_app_meta_data` à chaque mise à jour, ce n'était donc pas exploitable,
-- mais la règle de la maison (14/09) est de lire `raw_app_meta_data` :
-- `app.est_admin()` partout ici.
--
-- Compatibilité avec l'app installée : les nouveaux paramètres valent NULL
-- par défaut, et NULL veut dire « ne pas toucher » — une ancienne version qui
-- enregistre une formation n'efface pas son affiche. Une chaîne vide efface.

-- ─── 0. Lien court ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION app.formation_courte_slug(p_titre text, p_sauf uuid DEFAULT NULL)
RETURNS text
LANGUAGE plpgsql STABLE
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_base text;
  v_slug text;
  v_i    int := 1;
BEGIN
  v_base := lower(translate(COALESCE(p_titre, 'formation'),
              'àâäáãçéèêëíìîïñóòôöõúùûüýÿÀÂÄÁÃÇÉÈÊËÍÌÎÏÑÓÒÔÖÕÚÙÛÜÝ’''',
              'aaaaaceeeeiiiinooooouuuuyyAAAAACEEEEIIIINOOOOOUUUUY  '));
  v_base := trim(BOTH '-' FROM regexp_replace(v_base, '[^a-z0-9]+', '-', 'g'));
  v_base := left(NULLIF(v_base, ''), 60);
  v_base := COALESCE(v_base, 'formation');
  v_slug := v_base;
  WHILE EXISTS (SELECT 1 FROM app.short_trainings
                WHERE slug = v_slug AND id IS DISTINCT FROM p_sauf) LOOP
    v_i := v_i + 1;
    v_slug := v_base || '-' || v_i;
  END LOOP;
  RETURN v_slug;
END;
$$;

-- ─── 1. La fiche formation ─────────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.app_admin_upsert_short_training(uuid, text, text, text, text, text, integer, numeric, boolean);
CREATE FUNCTION public.app_admin_upsert_short_training(
  p_training_id       uuid    DEFAULT NULL,
  p_title             text    DEFAULT NULL,
  p_short_description text    DEFAULT NULL,
  p_full_description  text    DEFAULT NULL,
  p_category          text    DEFAULT NULL,
  p_modality          text    DEFAULT NULL,
  p_duration_days     integer DEFAULT NULL,
  p_price             numeric DEFAULT NULL,
  p_is_active         boolean DEFAULT true,
  p_poster_url        text    DEFAULT NULL,
  p_organizer_name    text    DEFAULT NULL,
  p_benefits          jsonb   DEFAULT NULL,
  p_receipt_mentions  text    DEFAULT NULL,
  p_contact_whatsapp  text    DEFAULT NULL,
  p_is_featured       boolean DEFAULT NULL,
  p_slug              text    DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_user_id     uuid := auth.uid();
  v_training_id uuid;
  v_slug        text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF NOT app.est_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;
  IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_title');
  END IF;
  IF p_benefits IS NOT NULL AND jsonb_typeof(p_benefits) <> 'array' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_benefits');
  END IF;

  IF p_slug IS NOT NULL AND trim(p_slug) <> '' THEN
    v_slug := app.formation_courte_slug(p_slug, p_training_id);
  END IF;

  IF p_training_id IS NULL THEN
    INSERT INTO app.short_trainings (
      title, short_description, full_description, category, modality,
      duration_days, price, is_active, created_by,
      poster_url, organizer_name, benefits, receipt_mentions,
      contact_whatsapp, is_featured, slug)
    VALUES (
      p_title, p_short_description, p_full_description, p_category, p_modality,
      p_duration_days, p_price, COALESCE(p_is_active, true), v_user_id,
      NULLIF(trim(p_poster_url), ''),
      COALESCE(NULLIF(trim(p_organizer_name), ''), 'Nexiom Group'),
      COALESCE(p_benefits, '[]'::jsonb),
      NULLIF(trim(p_receipt_mentions), ''),
      NULLIF(trim(p_contact_whatsapp), ''),
      COALESCE(p_is_featured, false),
      COALESCE(v_slug, app.formation_courte_slug(p_title)))
    RETURNING id INTO v_training_id;
  ELSE
    UPDATE app.short_trainings SET
      title             = p_title,
      short_description = p_short_description,
      full_description  = p_full_description,
      category          = p_category,
      modality          = p_modality,
      duration_days     = p_duration_days,
      price             = p_price,
      is_active         = COALESCE(p_is_active, is_active),
      poster_url        = CASE WHEN p_poster_url IS NULL THEN poster_url ELSE NULLIF(trim(p_poster_url), '') END,
      organizer_name    = CASE WHEN p_organizer_name IS NULL OR trim(p_organizer_name) = '' THEN organizer_name ELSE trim(p_organizer_name) END,
      benefits          = COALESCE(p_benefits, benefits),
      receipt_mentions  = CASE WHEN p_receipt_mentions IS NULL THEN receipt_mentions ELSE NULLIF(trim(p_receipt_mentions), '') END,
      contact_whatsapp  = CASE WHEN p_contact_whatsapp IS NULL THEN contact_whatsapp ELSE NULLIF(trim(p_contact_whatsapp), '') END,
      is_featured       = COALESCE(p_is_featured, is_featured),
      slug              = COALESCE(v_slug, slug, app.formation_courte_slug(p_title, p_training_id)),
      updated_at        = now()
    WHERE id = p_training_id
    RETURNING id, slug INTO v_training_id, v_slug;
  END IF;

  IF v_training_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'training_not_found');
  END IF;

  RETURN jsonb_build_object('success', true, 'training_id', v_training_id,
    'slug', (SELECT slug FROM app.short_trainings WHERE id = v_training_id));
END;
$$;

REVOKE ALL ON FUNCTION public.app_admin_upsert_short_training(uuid, text, text, text, text, text, integer, numeric, boolean, text, text, jsonb, text, text, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_upsert_short_training(uuid, text, text, text, text, text, integer, numeric, boolean, text, text, jsonb, text, text, boolean, text) TO authenticated;

DROP FUNCTION IF EXISTS public.app_admin_upsert_short_training_session(uuid, uuid, timestamptz, timestamptz, text, integer, text, boolean);
CREATE FUNCTION public.app_admin_upsert_short_training_session(
  p_session_id            uuid        DEFAULT NULL,
  p_training_id           uuid        DEFAULT NULL,
  p_start_at              timestamptz DEFAULT NULL,
  p_end_at                timestamptz DEFAULT NULL,
  p_location              text        DEFAULT NULL,
  p_capacity              integer     DEFAULT NULL,
  p_status                text        DEFAULT 'open',
  p_is_active             boolean     DEFAULT true,
  p_welcome_location      text        DEFAULT NULL,
  p_practice_location     text        DEFAULT NULL,
  p_registration_deadline timestamptz DEFAULT NULL,
  p_clear_deadline        boolean     DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_session_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF NOT app.est_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;
  IF p_training_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'training_required');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM app.short_trainings t WHERE t.id = p_training_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'training_not_found');
  END IF;
  IF p_start_at IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'start_at_required');
  END IF;
  IF p_end_at IS NOT NULL AND p_end_at < p_start_at THEN
    RETURN jsonb_build_object('success', false, 'error', 'end_before_start');
  END IF;
  IF p_status IS NULL OR length(trim(p_status)) = 0 THEN
    p_status := 'open';
  END IF;

  IF p_session_id IS NULL THEN
    INSERT INTO app.short_training_sessions (
      training_id, start_at, end_at, location, capacity, status, is_active,
      welcome_location, practice_location, registration_deadline)
    VALUES (
      p_training_id, p_start_at, p_end_at, p_location, p_capacity, p_status,
      COALESCE(p_is_active, true),
      NULLIF(trim(p_welcome_location), ''), NULLIF(trim(p_practice_location), ''),
      CASE WHEN p_clear_deadline THEN NULL ELSE p_registration_deadline END)
    RETURNING id INTO v_session_id;
  ELSE
    UPDATE app.short_training_sessions SET
      training_id           = p_training_id,
      start_at              = p_start_at,
      end_at                = p_end_at,
      location              = p_location,
      capacity              = p_capacity,
      status                = p_status,
      is_active             = COALESCE(p_is_active, is_active),
      welcome_location      = CASE WHEN p_welcome_location IS NULL THEN welcome_location ELSE NULLIF(trim(p_welcome_location), '') END,
      practice_location     = CASE WHEN p_practice_location IS NULL THEN practice_location ELSE NULLIF(trim(p_practice_location), '') END,
      registration_deadline = CASE WHEN p_clear_deadline THEN NULL
                                   ELSE COALESCE(p_registration_deadline, registration_deadline) END,
      updated_at            = now()
    WHERE id = p_session_id
    RETURNING id INTO v_session_id;
  END IF;

  IF v_session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'session_not_found');
  END IF;
  RETURN jsonb_build_object('success', true, 'session_id', v_session_id);
END;
$$;

REVOKE ALL ON FUNCTION public.app_admin_upsert_short_training_session(uuid, uuid, timestamptz, timestamptz, text, integer, text, boolean, text, text, timestamptz, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_upsert_short_training_session(uuid, uuid, timestamptz, timestamptz, text, integer, text, boolean, text, text, timestamptz, boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.app_admin_list_short_trainings()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF NOT app.est_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id', t.id, 'title', t.title, 'short_description', t.short_description,
      'full_description', t.full_description, 'category', t.category,
      'modality', t.modality, 'duration_days', t.duration_days, 'price', t.price,
      'is_active', t.is_active, 'created_at', t.created_at, 'updated_at', t.updated_at,
      'slug', t.slug, 'poster_url', t.poster_url, 'organizer_name', t.organizer_name,
      'benefits', t.benefits, 'receipt_mentions', t.receipt_mentions,
      'contact_whatsapp', t.contact_whatsapp, 'is_featured', t.is_featured,
      'sessions', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
                 'id', s.id, 'start_at', s.start_at, 'end_at', s.end_at,
                 'location', s.location, 'capacity', s.capacity, 'status', s.status,
                 'is_active', s.is_active, 'created_at', s.created_at, 'updated_at', s.updated_at,
                 'welcome_location', s.welcome_location, 'practice_location', s.practice_location,
                 'registration_deadline', s.registration_deadline)
               ORDER BY s.start_at ASC)
        FROM app.short_training_sessions s WHERE s.training_id = t.id), '[]'::jsonb)
    ) ORDER BY t.created_at DESC), '[]'::jsonb)
    INTO v_result
  FROM app.short_trainings t;

  RETURN jsonb_build_object('success', true, 'trainings', v_result);
END;
$$;

REVOKE ALL ON FUNCTION public.app_admin_list_short_trainings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_list_short_trainings() TO authenticated;

-- ─── 2. Le ticket à l'entrée ───────────────────────────────────────────────

ALTER TABLE app.short_training_registrations
  ADD COLUMN IF NOT EXISTS checked_in_at timestamptz,
  ADD COLUMN IF NOT EXISTS checked_in_by uuid;

-- Accepte le contenu du QR (« ACADEMIA-FC:REC-2026-000031:1a2b3c4d5e6f ») ou
-- le seul numéro de reçu tapé à la main. Avec le QR, l'extrait d'empreinte
-- doit correspondre : un reçu recopié à la main ne se fait pas passer pour un
-- QR. Un ticket d'une autre session, non confirmé ou déjà passé est refusé.
CREATE OR REPLACE FUNCTION public.app_admin_short_training_check_ticket(p_session_id uuid, p_code text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $$
DECLARE
  v_code    text := upper(trim(COALESCE(p_code, '')));
  v_numero  text;
  v_extrait text;
  v_recu    app.payment_receipts%ROWTYPE;
  v_reg     app.short_training_registrations%ROWTYPE;
  v_nom     text;
BEGIN
  IF NOT app.est_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  IF v_code LIKE 'ACADEMIA-FC:%' THEN
    v_numero  := split_part(v_code, ':', 2);
    v_extrait := lower(split_part(v_code, ':', 3));
  ELSE
    v_numero := v_code;
  END IF;

  SELECT * INTO v_recu FROM app.payment_receipts WHERE upper(receipt_number) = v_numero;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'resultat', 'inconnu',
      'message', 'Aucun reçu ne porte ce numéro.');
  END IF;
  IF v_extrait IS NOT NULL AND v_extrait <> ''
     AND left(lower(COALESCE(v_recu.signature_hash, '')), length(v_extrait)) <> v_extrait THEN
    RETURN jsonb_build_object('success', false, 'resultat', 'falsifie',
      'message', 'Le QR ne correspond pas à ce reçu : ticket refusé.');
  END IF;

  SELECT r.* INTO v_reg
  FROM app.application_payments p
  JOIN app.short_training_registrations r ON r.id = p.short_training_registration_id
  WHERE p.id = v_recu.payment_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'resultat', 'pas_une_formation',
      'message', 'Ce reçu ne correspond pas à une inscription de formation.');
  END IF;

  SELECT full_name INTO v_nom FROM app.students WHERE id = v_reg.user_id;

  IF v_reg.session_id <> p_session_id THEN
    RETURN jsonb_build_object('success', false, 'resultat', 'autre_session', 'nom', v_nom,
      'message', 'Ce ticket est valable pour une autre session.');
  END IF;
  IF v_reg.status <> 'confirmed' THEN
    RETURN jsonb_build_object('success', false, 'resultat', 'non_confirme', 'nom', v_nom,
      'message', 'Inscription non confirmée.');
  END IF;
  IF v_reg.checked_in_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'resultat', 'deja_present', 'nom', v_nom,
      'checked_in_at', v_reg.checked_in_at,
      'message', 'Déjà enregistré(e) à l''entrée.');
  END IF;

  UPDATE app.short_training_registrations
     SET checked_in_at = now(), checked_in_by = auth.uid(), updated_at = now()
   WHERE id = v_reg.id;

  RETURN jsonb_build_object('success', true, 'resultat', 'present', 'nom', v_nom,
    'receipt_number', v_recu.receipt_number, 'message', 'Bienvenue !');
END;
$$;

REVOKE ALL ON FUNCTION public.app_admin_short_training_check_ticket(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_short_training_check_ticket(uuid, text) TO authenticated;

-- ─── 3. Le tableau compte les présents ─────────────────────────────────────
-- Identique à la version du lot 2 (20261027150000), plus `checked_in_at` par
-- ligne et `presents` dans les totaux.

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
      'session_id', s.id, 'training_id', t.id, 'title', t.title, 'slug', t.slug,
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
        'checked_in_at', l.checked_in_at,
        'last_message_at', l.last_message_at, 'admin_last_read_at', l.admin_last_read_at)
      ORDER BY CASE l.etat WHEN 'a_valider' THEN 0 WHEN 'en_cours' THEN 1
                           WHEN 'confirmee' THEN 2 ELSE 3 END,
               l.full_name NULLS LAST), '[]'::jsonb),
    jsonb_build_object(
      'confirmes', count(*) FILTER (WHERE l.etat = 'confirmee'),
      'presents', count(*) FILTER (WHERE l.etat = 'confirmee' AND l.checked_in_at IS NOT NULL),
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
