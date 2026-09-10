-- Le transfert : l'école reçoit une COPIE D'ANNONCE, la procédure ne change pas.
--
-- DEMANDE DE JOCELYN (10/09) : « l'administrateur doit avoir une copie de tous
-- les bons » et « il a la possibilité de transférer le bon numérique à
-- l'université, qui va le recevoir dans son onglet Mes documents ».
--
-- ET SA PRÉCISION, QUI COMMANDE TOUTE LA CONCEPTION : « l'étudiant doit quand
-- même aller au guichet pour le scan. On ne change pas la procédure. C'est
-- pour que l'école ait déjà une copie à son niveau. »
--
-- CONSÉQUENCE : LA COPIE TRANSMISE NE PORTE PAS LE SECRET.
-- `app_university_list_brokerage_vouchers` rend tout SAUF `verification_code`
-- et `scan_token`. Sans cette omission, une école qui reçoit le transfert
-- pourrait appeler `app_consommer_bon_de_courtage` avec le code et CLORE le
-- bon sans avoir vu le candidat — exactement le contraire de ce qui est
-- demandé. Le secret reste sur le papier que le candidat présente.
--
-- Le transfert est MANUEL (un acte de l'administrateur, jamais automatique) et
-- l'université est NOTIFIÉE.
--
-- ÉPROUVÉ LE 10/09, sept points, sessions réelles :
--   l'admin voit les 2 bons · l'université en voit 0 avant transfert ·
--   le transfert prévient 1 compte · l'université voit 1 bon SANS code ni
--   jeton · le bon d'une autre école reste invisible · un second transfert ne
--   fait rien · un étudiant est refusé.

-- ── 1. Trace du transfert ──────────────────────────────────────────────────
ALTER TABLE app.brokerage_vouchers
  ADD COLUMN IF NOT EXISTS transferred_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS transferred_by UUID;

COMMENT ON COLUMN app.brokerage_vouchers.transferred_at IS
  'Date a laquelle un administrateur a transmis la COPIE D''ANNONCE a '
  'l''etablissement. Ne vaut pas presentation : le candidat doit toujours se '
  'presenter avec son bon pour que l''ecole le verifie et le close.';

-- ── 2. L'immuabilité laisse passer le transfert, UNE SEULE FOIS ────────────
CREATE OR REPLACE FUNCTION app.bon_immuable()
RETURNS TRIGGER LANGUAGE plpgsql AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Un bon de courtage ne se supprime pas (%).', OLD.voucher_number;
  END IF;
  IF NEW.voucher_number IS DISTINCT FROM OLD.voucher_number
     OR NEW.application_id IS DISTINCT FROM OLD.application_id
     OR NEW.payment_id IS DISTINCT FROM OLD.payment_id
     OR NEW.destination_university_id IS DISTINCT FROM OLD.destination_university_id
     OR NEW.snapshot IS DISTINCT FROM OLD.snapshot
     OR NEW.signature_hash IS DISTINCT FROM OLD.signature_hash
     OR NEW.issued_at IS DISTINCT FROM OLD.issued_at
     OR NEW.expires_at IS DISTINCT FROM OLD.expires_at
     OR NEW.origin IS DISTINCT FROM OLD.origin
     OR NEW.scan_token IS DISTINCT FROM OLD.scan_token
     OR NEW.verification_code IS DISTINCT FROM OLD.verification_code THEN
    RAISE EXCEPTION 'Le contenu d''un bon de courtage est fige (%).', OLD.voucher_number;
  END IF;
  IF OLD.consumed_at IS NOT NULL AND NEW.consumed_at IS DISTINCT FROM OLD.consumed_at THEN
    RAISE EXCEPTION 'Ce bon a deja ete consomme le %.', OLD.consumed_at;
  END IF;
  -- Le transfert se fait une fois. Le refaire n'ajouterait rien et effacerait
  -- la date reelle de la premiere transmission.
  IF OLD.transferred_at IS NOT NULL AND NEW.transferred_at IS DISTINCT FROM OLD.transferred_at THEN
    RAISE EXCEPTION 'Ce bon a deja ete transmis le %.', OLD.transferred_at;
  END IF;
  RETURN NEW;
END;
$function$;

-- ── 3. L'administrateur voit TOUS les bons ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_admin_list_brokerage_vouchers()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user UUID := auth.uid();
  v_bons JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;
  IF COALESCE((SELECT raw_app_meta_data->>'role' FROM auth.users WHERE id = v_user), '')
     <> 'admin' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_admin');
  END IF;

  SELECT COALESCE(jsonb_agg(t ORDER BY t.issued_at DESC), '[]'::jsonb)
    INTO v_bons
  FROM (
    SELECT b.id, b.voucher_number, b.verification_code, b.scan_token,
           b.issued_at, b.expires_at, b.consumed_at, b.transferred_at,
           b.signature_hash, b.origin, b.snapshot,
           (b.expires_at < NOW()) AS expire,
           u.name  AS universite,
           s.full_name AS etudiant
    FROM app.brokerage_vouchers b
    LEFT JOIN app.universities u ON u.id = b.destination_university_id
    LEFT JOIN app.application_payments p ON p.id = b.payment_id
    LEFT JOIN app.students s ON s.id = p.student_id
  ) t;

  RETURN jsonb_build_object('success', TRUE, 'vouchers', v_bons);
END;
$function$;

-- ── 4. Le transfert ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_admin_transferer_bon(p_voucher_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user  UUID := auth.uid();
  v_b     app.brokerage_vouchers%ROWTYPE;
  v_nom   TEXT;
  v_compte RECORD;
  v_prevenus INTEGER := 0;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;
  IF COALESCE((SELECT raw_app_meta_data->>'role' FROM auth.users WHERE id = v_user), '')
     <> 'admin' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_admin');
  END IF;

  SELECT * INTO v_b FROM app.brokerage_vouchers WHERE id = p_voucher_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'bon_introuvable');
  END IF;

  IF v_b.transferred_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', TRUE, 'deja_transmis', TRUE,
      'transmis_le', v_b.transferred_at,
      'message', 'Ce bon a déjà été transmis à l''établissement.');
  END IF;

  SELECT name INTO v_nom FROM app.universities WHERE id = v_b.destination_university_id;

  UPDATE app.brokerage_vouchers
     SET transferred_at = NOW(), transferred_by = v_user
   WHERE id = p_voucher_id;

  -- LE COMPTE DE L'ECOLE SE TROUVE PAR `raw_app_meta_data`, source de
  -- confiance ancree le 09/09. Une ecole peut avoir plusieurs comptes : on
  -- previent chacun, et on compte -- si le compte est zero, l'administrateur
  -- doit le savoir plutot que de croire le bon transmis a quelqu'un.
  FOR v_compte IN
    SELECT u.id FROM auth.users u
     WHERE COALESCE(u.raw_app_meta_data->>'role', u.raw_user_meta_data->>'role') = 'university'
       AND NULLIF(COALESCE(u.raw_app_meta_data->>'university_id',
                           u.raw_user_meta_data->>'university_id'), '')::uuid
           = v_b.destination_university_id
       AND u.banned_until IS NULL
  LOOP
    PERFORM public.app_queue_notification_event(
      v_compte.id, 'university_documents', 'brokerage_voucher_transferred',
      jsonb_build_object(
        'voucher_id', v_b.id,
        'voucher_number', v_b.voucher_number,
        'candidat', v_b.snapshot->'candidat'->>'nom',
        'formation', v_b.snapshot->'formation'->>'titre',
        'expire_le', v_b.expires_at));
    v_prevenus := v_prevenus + 1;
  END LOOP;

  INSERT INTO app.admin_audit_log (admin_id, action_type, target_type, target_id, details)
  VALUES (v_user, 'transfer_brokerage_voucher', 'brokerage_voucher',
          p_voucher_id::text,
          jsonb_build_object('numero', v_b.voucher_number,
                             'universite', v_nom,
                             'comptes_prevenus', v_prevenus));

  RETURN jsonb_build_object('success', TRUE, 'deja_transmis', FALSE,
    'voucher_number', v_b.voucher_number,
    'universite', v_nom,
    'comptes_prevenus', v_prevenus,
    'message', CASE WHEN v_prevenus = 0
      THEN 'Bon transmis, mais AUCUN compte n''est rattaché à cet '
        || 'établissement : personne ne le verra tant qu''un compte ne sera '
        || 'pas créé.'
      ELSE 'Bon transmis à ' || COALESCE(v_nom, 'l''établissement') || '.' END);
END;
$function$;

-- ── 5. L'université lit ses copies, SANS LE SECRET ─────────────────────────
CREATE OR REPLACE FUNCTION public.app_university_list_brokerage_vouchers()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user UUID := auth.uid();
  v_role TEXT;
  v_univ UUID;
  v_bons JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT COALESCE(u.raw_app_meta_data->>'role', u.raw_user_meta_data->>'role')
    INTO v_role FROM auth.users u WHERE u.id = v_user;
  IF COALESCE(v_role, '') <> 'university' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'reserve_aux_universites');
  END IF;

  v_univ := app.universite_de_l_utilisateur(v_user);
  IF v_univ IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'university_not_configured');
  END IF;

  SELECT COALESCE(jsonb_agg(t ORDER BY t.transferred_at DESC), '[]'::jsonb)
    INTO v_bons
  FROM (
    -- NI `verification_code` NI `scan_token`. C'est la copie d'annonce : elle
    -- informe, elle n'autorise pas. Le secret voyage avec le candidat.
    SELECT b.id, b.voucher_number, b.issued_at, b.expires_at,
           b.consumed_at, b.transferred_at, b.signature_hash, b.snapshot,
           (b.expires_at < NOW()) AS expire
    FROM app.brokerage_vouchers b
    WHERE b.destination_university_id = v_univ
      AND b.transferred_at IS NOT NULL
  ) t;

  RETURN jsonb_build_object('success', TRUE, 'vouchers', v_bons);
END;
$function$;

REVOKE ALL ON FUNCTION public.app_admin_list_brokerage_vouchers() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_admin_transferer_bon(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_university_list_brokerage_vouchers() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_admin_list_brokerage_vouchers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_transferer_bon(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_university_list_brokerage_vouchers() TO authenticated;
