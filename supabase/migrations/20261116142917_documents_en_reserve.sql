-- DOCUMENTS EN RÉSERVE : le reçu et le bon existent, mais seul
-- l'administrateur les voit, jusqu'à ce que l'argent arrive.
--
-- LE CAS QUI L'A OUVERT (14/11/2026). Une candidate choisit une formation et
-- veut payer directement au numéro de Jocelyn, hors de l'application. Il faut
-- pouvoir PRÉPARER son reçu et son bon de réduction tout de suite, puis les
-- lui rendre visibles d'un geste, le jour où l'argent est reçu.
--
-- CE QUI EST RÉUTILISÉ, ET RIEN N'EST RÉÉCRIT. La préparation appelle
-- `public.app_admin_emettre_documents_manuels` (la saisie au comptoir du
-- 10/09), qui elle-même appelle `app.emettre_recu` et `app.emettre_bon` : le
-- reçu et le bon sont donc EXACTEMENT ceux du parcours normal (même
-- numérotation, même empreinte, même vérification au guichet). La seule
-- chose ajoutée est une RÉSERVE : une ligne dans `app.documents_en_reserve`
-- tant que `published_at` est nul.
--
-- CE QUE LA RÉSERVE CACHE, MESURÉ AVANT D'ÉCRIRE (14/11) :
--   — à l'étudiante : la candidature (RLS + `app_list_student_applications`),
--     le paiement (RLS), le reçu (RLS), le bon (`app_list_my_brokerage_vouchers`).
--     L'application lit ces quatre sources et aucune autre
--     (`student_application_payments_provider.dart`, `student_applications_provider.dart`).
--   — à l'école : la candidature (`sent_to_university` remis à FALSE ; la
--     liste de l'école ne montre que les TRUE), le paiement (RLS), et le
--     transfert du bon (refusé tant que la réserve tient).
--   — les alertes qui partiraient à l'INSERT : courriel du reçu
--     (`app.email_queue`), « nouvelle candidature » et « paiement » à l'école,
--     « paiement » aux administrateurs (qui diraient « confirmé » alors que
--     l'argent n'est pas arrivé). Elles se taisent par un drapeau LOCAL À LA
--     TRANSACTION (`set_config(..., true)`) : il meurt avec elle, aucun autre
--     appel n'en hérite.
--
-- CE QUE LA PUBLICATION FAIT : lève la réserve, rend la candidature à
-- l'école, met le reçu dans la file des courriels, et prévient l'étudiante
-- par la notification déjà connue de l'application et de
-- send-push-notifications (`student_payments` / `payment_status_changed` /
-- `confirmed` → « ✅ Paiement confirmé ! », ouvre l'écran des paiements).
-- Aucune Edge Function à redéployer.
--
-- CE QUI RESTE VRAI ET QU'IL FAUT SAVOIR : le reçu est immuable, il porte la
-- date du jour de PRÉPARATION comme date d'encaissement. Le paiement est
-- enregistré « confirmé » dès la préparation (c'est ce que fait la saisie au
-- comptoir) ; il compte donc dans les totaux de l'administrateur avant que
-- l'argent ne soit là.

-- ── 1. La réserve ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS app.documents_en_reserve (
  payment_id     UUID PRIMARY KEY REFERENCES app.application_payments(id),
  application_id UUID NOT NULL REFERENCES app.applications(id),
  student_id     UUID NOT NULL,
  prepared_by    UUID NOT NULL,
  prepared_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  published_by   UUID,
  published_at   TIMESTAMPTZ,
  note           TEXT
);
CREATE INDEX IF NOT EXISTS documents_en_reserve_candidature_idx
  ON app.documents_en_reserve (application_id) WHERE published_at IS NULL;

ALTER TABLE app.documents_en_reserve ENABLE ROW LEVEL SECURITY;
-- Aucune politique : la table ne se lit et ne s'écrit que par les fonctions
-- ci-dessous, comme les reçus et les bons.
REVOKE ALL ON app.documents_en_reserve FROM anon, authenticated;

COMMENT ON TABLE app.documents_en_reserve IS
  'Reçu et bon préparés pour un paiement HORS application, invisibles pour '
  'l''étudiant et l''école tant que published_at est nul. Préparés par '
  'app_admin_preparer_documents_en_reserve, publiés par '
  'app_admin_publier_documents_en_reserve.';

-- ── 2. Les questions que posent les politiques ────────────────────────────
-- SECURITY DEFINER : elles sont évaluées avec les droits de l'étudiant, qui
-- n'a aucun accès à la table. Elles ne rendent qu'un booléen.
CREATE OR REPLACE FUNCTION app.paiement_en_reserve(p_payment_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'app', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM app.documents_en_reserve r
                 WHERE r.payment_id = p_payment_id AND r.published_at IS NULL);
$function$;

CREATE OR REPLACE FUNCTION app.candidature_en_reserve(p_application_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'app', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM app.documents_en_reserve r
                 WHERE r.application_id = p_application_id AND r.published_at IS NULL);
$function$;

-- Le drapeau de préparation : vrai seulement dans la transaction qui prépare.
CREATE OR REPLACE FUNCTION app.preparation_en_reserve()
RETURNS BOOLEAN
LANGUAGE sql STABLE
AS $function$
  SELECT COALESCE(current_setting('app.documents_en_reserve', TRUE), '') = 'on';
$function$;

REVOKE ALL ON FUNCTION app.paiement_en_reserve(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION app.candidature_en_reserve(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app.paiement_en_reserve(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app.candidature_en_reserve(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app.preparation_en_reserve() TO authenticated;

-- ── 3. Ce que voit l'étudiante, et l'école ────────────────────────────────
DROP POLICY IF EXISTS student_select_own_payments ON app.application_payments;
CREATE POLICY student_select_own_payments ON app.application_payments
  FOR SELECT
  USING (student_id = auth.uid() AND NOT app.paiement_en_reserve(id));

DROP POLICY IF EXISTS university_select_own_payments ON app.application_payments;
CREATE POLICY university_select_own_payments ON app.application_payments
  FOR SELECT
  USING (CASE
    WHEN ((auth.jwt() ? 'role') AND ((auth.jwt() ->> 'role') = 'university'))
    THEN (((auth.jwt() ->> 'university_id'))::uuid = university_id
          AND NOT app.paiement_en_reserve(id))
    ELSE FALSE
  END);

DROP POLICY IF EXISTS student_select_own_applications ON app.applications;
CREATE POLICY student_select_own_applications ON app.applications
  FOR SELECT
  USING (student_id = auth.uid() AND NOT app.candidature_en_reserve(id));

DROP POLICY IF EXISTS student_update_own_applications ON app.applications;
CREATE POLICY student_update_own_applications ON app.applications
  FOR UPDATE
  USING (student_id = auth.uid() AND NOT app.candidature_en_reserve(id));

DROP POLICY IF EXISTS recu_lisible_par_son_proprietaire ON app.payment_receipts;
CREATE POLICY recu_lisible_par_son_proprietaire ON app.payment_receipts
  FOR SELECT TO authenticated
  USING ((EXISTS (SELECT 1 FROM app.application_payments p
                  WHERE p.id = payment_receipts.payment_id
                    AND p.student_id = auth.uid()
                    AND NOT app.paiement_en_reserve(p.id)))
         OR app_is_admin_user());

-- ── 4. Les deux listes de l'étudiante ─────────────────────────────────────
-- Corps relevés en production le 14/11, recopiés à l'identique ; seule la
-- clause signalée « RÉSERVE » est ajoutée.
CREATE OR REPLACE FUNCTION public.app_list_student_applications()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', a.id,
                'program_id', a.program_id,
                'status', a.status,
                'motivation_text', a.motivation_text,
                'submitted_at', a.submitted_at,
                'created_at', a.created_at,
                'updated_at', a.updated_at,
                'last_message_at', a.last_message_at,
                'requested_degree_level', a.requested_degree_level,
                'requested_study_mode', a.requested_study_mode,
                'requested_schedule', a.requested_schedule,
                'discount_requested', a.discount_requested,
                'discount_details', a.discount_details,
                'discount_rate', a.discount_rate,
                'discount_validated_at', a.discount_validated_at,
                'payment_deadline_at', a.payment_deadline_at,
                'student_comment', a.student_comment,
                'program_title', p.title,
                'degree_level', p.degree_level,
                'university_id', u.id,
                'university_name', u.name,
                'has_unread_for_student',
                    CASE
                        WHEN a.last_message_at IS NULL THEN FALSE
                        WHEN a.last_student_read_at IS NULL THEN TRUE
                        ELSE a.last_message_at > a.last_student_read_at
                    END
            )
            ORDER BY a.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM app.applications a
    JOIN app.programs p ON p.id = a.program_id
    JOIN app.universities u ON u.id = p.university_id
    WHERE a.student_id = auth.uid()
      AND NOT app.candidature_en_reserve(a.id);   -- RÉSERVE (14/11)

    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_list_my_brokerage_vouchers()
 RETURNS jsonb
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

  SELECT COALESCE(jsonb_agg(t ORDER BY t.issued_at DESC), '[]'::jsonb)
    INTO v_bons
  FROM (
    SELECT b.id,
           b.voucher_number,
           b.verification_code,
           b.scan_token,
           b.issued_at,
           b.expires_at,
           b.consumed_at,
           b.signature_hash,
           b.origin,
           b.snapshot,
           (b.expires_at < NOW()) AS expire,
           u.name AS universite
    FROM app.brokerage_vouchers b
    JOIN app.application_payments p ON p.id = b.payment_id
    LEFT JOIN app.universities u ON u.id = b.destination_university_id
    WHERE p.student_id = v_user
      AND NOT app.paiement_en_reserve(b.payment_id)   -- RÉSERVE (14/11)
  ) t;

  RETURN jsonb_build_object('success', TRUE, 'vouchers', v_bons);
END;
$function$;

-- ── 5. La liste de l'administrateur dit ce qui est en réserve ─────────────
CREATE OR REPLACE FUNCTION public.app_admin_list_brokerage_vouchers()
 RETURNS jsonb
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
           s.full_name AS etudiant,
           -- RÉSERVE (14/11) : l'écran en tire la puce et le bouton « Publier ».
           b.payment_id,
           app.paiement_en_reserve(b.payment_id) AS en_reserve
    FROM app.brokerage_vouchers b
    LEFT JOIN app.universities u ON u.id = b.destination_university_id
    LEFT JOIN app.application_payments p ON p.id = b.payment_id
    LEFT JOIN app.students s ON s.id = p.student_id
  ) t;

  RETURN jsonb_build_object('success', TRUE, 'vouchers', v_bons);
END;
$function$;

-- ── 6. Pas de transfert à l'école tant que la réserve tient ───────────────
CREATE OR REPLACE FUNCTION public.app_admin_transferer_bon(p_voucher_id uuid)
 RETURNS jsonb
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

  -- RÉSERVE (14/11) : l'école n'apprend rien avant que l'argent soit reçu.
  IF app.paiement_en_reserve(v_b.payment_id) THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'bon_en_reserve',
      'message', 'Ce bon est en réserve : publiez-le d''abord, une fois '
              || 'l''argent reçu.');
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

-- ── 7. Les alertes qui partiraient à la préparation se taisent ────────────
-- Une ligne ajoutée en tête de chacune, signalée « RÉSERVE ». Le reste est
-- le corps relevé en production le 14/11.
CREATE OR REPLACE FUNCTION app.trigger_payment_receipts_email()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- RÉSERVE (14/11) : le courriel part à la publication, pas avant.
    IF app.preparation_en_reserve() THEN RETURN NEW; END IF;

    -- Ajouter à la queue d'emails
    INSERT INTO app.email_queue (receipt_id, status)
    VALUES (NEW.id, 'pending');

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_notify_university_new_application()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_uni_user RECORD; v_uni_id UUID; v_student_name TEXT; v_program_name TEXT;
BEGIN
    -- RÉSERVE (14/11) : l'école est prévenue à la publication.
    IF app.preparation_en_reserve() THEN RETURN NEW; END IF;

    IF TG_OP = 'INSERT' THEN
        SELECT p.university_id, p.title INTO v_uni_id, v_program_name FROM app.programs p WHERE p.id = NEW.program_id;
        SELECT s.full_name INTO v_student_name FROM app.students s WHERE s.id = NEW.student_id;
        IF v_uni_id IS NOT NULL THEN
            FOR v_uni_user IN
                SELECT u.id AS user_id FROM auth.users u
                WHERE u.raw_user_meta_data->>'role' = 'university'
                  AND (u.raw_user_meta_data->>'university_id')::UUID = v_uni_id
                  AND u.banned_until IS NULL
            LOOP
                PERFORM public.app_queue_notification_event(v_uni_user.user_id, 'university_applications', 'new_application',
                    JSONB_BUILD_OBJECT('application_id', NEW.id, 'student_name', COALESCE(v_student_name,''), 'program_name', COALESCE(v_program_name,'')));
            END LOOP;
        END IF;
    END IF;
    RETURN NEW;
END; $function$;

CREATE OR REPLACE FUNCTION public.app_notify_university_payment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_uni_user RECORD; v_student_name TEXT; v_program_name TEXT; v_reason_label TEXT;
BEGIN
    -- RÉSERVE (14/11) : rien à l'école tant que l'argent n'est pas reçu.
    IF app.preparation_en_reserve() THEN RETURN NEW; END IF;

    IF NEW.university_id IS NULL THEN
        RETURN NEW;
    END IF;

    IF NOT (
         (TG_OP = 'INSERT' AND NEW.status IN ('declared_by_student', 'confirmed'))
      OR (TG_OP = 'UPDATE' AND NEW.status IN ('declared_by_student', 'confirmed')
                           AND OLD.status IS DISTINCT FROM NEW.status)
    ) THEN
        RETURN NEW;
    END IF;

    SELECT s.full_name INTO v_student_name FROM app.students s WHERE s.id = NEW.student_id;
    SELECT p.title INTO v_program_name FROM app.programs p
        JOIN app.applications a ON a.program_id = p.id
        WHERE a.id = NEW.application_id;

    v_reason_label := CASE NEW.payment_reason
        WHEN 'application_fee'  THEN 'Frais de dossier'
        WHEN 'registration_fee' THEN 'Frais d''inscription'
        WHEN 'tuition_deposit'  THEN 'Acompte scolarité'
        WHEN 'td_access'        THEN 'Accès TD'
        WHEN 'credit_purchase'  THEN 'Achat de crédits'
        ELSE 'Paiement'
    END;

    FOR v_uni_user IN
        SELECT u.id AS user_id FROM auth.users u
        WHERE u.raw_user_meta_data->>'role' = 'university'
          AND (u.raw_user_meta_data->>'university_id')::UUID = NEW.university_id
          AND u.banned_until IS NULL
    LOOP
        -- NI `amount_paid` NI `amount_due` NI `currency` DEPUIS LE 11/09.
        -- Le texte pousse ne les affichait deja pas (la branche
        -- `university_payments` de send-push-notifications n'utilise que le nom,
        -- le statut et le libelle) -- mais le PAYLOAD STOCKE les portait, et
        -- l'application peut le lire. 53 evenements en base etaient dans ce cas.
        -- L'ecole apprend QUE c'est regle, pas COMBIEN.
        PERFORM public.app_queue_notification_event(v_uni_user.user_id, 'university_payments', 'payment_update',
            JSONB_BUILD_OBJECT(
                'payment_id', NEW.id,
                'student_name', COALESCE(v_student_name,''),
                'program_name', COALESCE(v_program_name,''),
                'status', NEW.status,
                'payment_reason', NEW.payment_reason,
                'reason_label', v_reason_label
            ));
    END LOOP;
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_notify_admin_payment_declared()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_admin RECORD; v_student_name TEXT; v_program_name TEXT; v_reason_label TEXT;
BEGIN
    -- RÉSERVE (14/11) : un « paiement confirmé » serait faux, l'argent n'est
    -- pas encore arrivé. C'est l'administrateur qui prépare : il le sait.
    IF app.preparation_en_reserve() THEN RETURN NEW; END IF;

    -- Seuls une declaration et un encaissement reveillent un administrateur.
    IF NOT (
         (TG_OP = 'INSERT' AND NEW.status IN ('declared_by_student', 'confirmed'))
      OR (TG_OP = 'UPDATE' AND NEW.status IN ('declared_by_student', 'confirmed')
                           AND OLD.status IS DISTINCT FROM NEW.status)
    ) THEN
        RETURN NEW;
    END IF;

    SELECT s.full_name INTO v_student_name FROM app.students s WHERE s.id = NEW.student_id;
    SELECT p.title INTO v_program_name FROM app.programs p
        JOIN app.applications a ON a.program_id = p.id
        WHERE a.id = NEW.application_id;

    v_reason_label := CASE NEW.payment_reason
        WHEN 'application_fee'  THEN 'Frais de dossier'
        WHEN 'registration_fee' THEN 'Frais d''inscription'
        WHEN 'tuition_deposit'  THEN 'Acompte scolarité'
        WHEN 'td_access'        THEN 'Accès TD'
        WHEN 'credit_purchase'  THEN 'Achat de crédits'
        ELSE 'Paiement'
    END;

    FOR v_admin IN
        SELECT u.id AS user_id FROM auth.users u
        WHERE u.raw_user_meta_data->>'role' = 'admin' AND u.banned_until IS NULL
    LOOP
        PERFORM public.app_queue_notification_event(v_admin.user_id, 'admin_payments', 'payment',
            JSONB_BUILD_OBJECT(
                'payment_id', NEW.id,
                'student_name', COALESCE(v_student_name,''),
                'program_name', COALESCE(v_program_name,''),
                'status', NEW.status,
                'payment_reason', NEW.payment_reason,
                'reason_label', v_reason_label,
                'amount_paid', COALESCE(NEW.amount_paid, 0),
                'amount_due', NEW.amount_due,
                'currency', NEW.currency
            ));
    END LOOP;
    RETURN NEW;
END;
$function$;

-- ── 8. Préparer ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_admin_preparer_documents_en_reserve(
  p_student_id UUID,
  p_program_id UUID,
  p_taux       NUMERIC,
  p_montant    NUMERIC DEFAULT NULL,
  p_canal      TEXT    DEFAULT 'orange_money',
  p_reference  TEXT    DEFAULT NULL,
  p_note       TEXT    DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_admin UUID := auth.uid();
  v_r     JSONB;
BEGIN
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;
  IF COALESCE((SELECT raw_app_meta_data->>'role' FROM auth.users WHERE id = v_admin), '')
     <> 'admin' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_admin');
  END IF;

  -- Le drapeau vit le temps de cette transaction (troisième argument TRUE).
  PERFORM set_config('app.documents_en_reserve', 'on', TRUE);

  -- LA SAISIE AU COMPTOIR, TELLE QUELLE : candidature acceptée au taux
  -- négocié, paiement, reçu et bon par les fonctions du parcours normal.
  v_r := public.app_admin_emettre_documents_manuels(
    p_student_id, p_program_id, p_taux,
    NULL, NULL, NULL, NULL, NULL, NULL,
    p_montant, p_canal, p_reference, p_note, NULL, FALSE);

  PERFORM set_config('app.documents_en_reserve', 'off', TRUE);

  IF COALESCE((v_r->>'success')::boolean, FALSE) IS NOT TRUE THEN
    RETURN v_r;
  END IF;

  INSERT INTO app.documents_en_reserve (payment_id, application_id, student_id,
                                        prepared_by, note)
  VALUES ((v_r->>'payment_id')::uuid, (v_r->>'application_id')::uuid,
          p_student_id, v_admin, NULLIF(TRIM(p_note), ''));

  -- La saisie au comptoir annonce le dossier à l'école ; la réserve le retire.
  UPDATE app.applications
     SET sent_to_university = FALSE, sent_to_university_at = NULL
   WHERE id = (v_r->>'application_id')::uuid;

  INSERT INTO app.admin_audit_log (admin_id, action_type, target_type, target_id,
                                   target_user_id, details)
  VALUES (v_admin, 'preparer_documents_en_reserve', 'application_payment',
          v_r->>'payment_id', p_student_id,
          jsonb_build_object('recu', v_r->>'receipt_number',
                             'bon', v_r->>'voucher_number',
                             'taux', p_taux, 'montant', v_r->'montant'));

  RETURN v_r || jsonb_build_object('en_reserve', TRUE);
END;
$function$;

REVOKE ALL ON FUNCTION public.app_admin_preparer_documents_en_reserve(
  UUID, UUID, NUMERIC, NUMERIC, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_preparer_documents_en_reserve(
  UUID, UUID, NUMERIC, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;

-- ── 9. Publier : le geste du jour où l'argent arrive ──────────────────────
CREATE OR REPLACE FUNCTION public.app_admin_publier_documents_en_reserve(
  p_payment_id UUID
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_admin   UUID := auth.uid();
  v_res     app.documents_en_reserve%ROWTYPE;
  v_p       app.application_payments%ROWTYPE;
  v_nom     TEXT;
  v_prog    TEXT;
  v_uni     UUID;
  v_recu    UUID;
  v_compte  RECORD;
BEGIN
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;
  IF COALESCE((SELECT raw_app_meta_data->>'role' FROM auth.users WHERE id = v_admin), '')
     <> 'admin' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_admin');
  END IF;

  SELECT * INTO v_res FROM app.documents_en_reserve
   WHERE payment_id = p_payment_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'reserve_introuvable');
  END IF;
  IF v_res.published_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', TRUE, 'deja_publie', TRUE,
      'publie_le', v_res.published_at,
      'message', 'Ces documents sont déjà visibles par le candidat.');
  END IF;

  SELECT * INTO v_p FROM app.application_payments WHERE id = p_payment_id;
  SELECT s.full_name INTO v_nom FROM app.students s WHERE s.id = v_res.student_id;
  SELECT pr.title, pr.university_id INTO v_prog, v_uni
    FROM app.applications a JOIN app.programs pr ON pr.id = a.program_id
   WHERE a.id = v_res.application_id;

  -- 1. La réserve tombe : RLS et listes rendent tout à l'étudiante.
  UPDATE app.documents_en_reserve
     SET published_at = NOW(), published_by = v_admin
   WHERE payment_id = p_payment_id;

  -- 2. L'école retrouve le dossier, comme après une saisie au comptoir, et
  --    reçoit les deux alertes que la préparation avait tues.
  UPDATE app.applications
     SET sent_to_university = TRUE, sent_to_university_at = NOW()
   WHERE id = v_res.application_id;

  IF v_uni IS NOT NULL THEN
    FOR v_compte IN
      SELECT u.id FROM auth.users u
       WHERE u.raw_user_meta_data->>'role' = 'university'
         AND (u.raw_user_meta_data->>'university_id')::UUID = v_uni
         AND u.banned_until IS NULL
    LOOP
      PERFORM public.app_queue_notification_event(v_compte.id,
        'university_applications', 'new_application',
        jsonb_build_object('application_id', v_res.application_id,
                           'student_name', COALESCE(v_nom, ''),
                           'program_name', COALESCE(v_prog, '')));
      PERFORM public.app_queue_notification_event(v_compte.id,
        'university_payments', 'payment_update',
        jsonb_build_object('payment_id', p_payment_id,
                           'student_name', COALESCE(v_nom, ''),
                           'program_name', COALESCE(v_prog, ''),
                           'status', v_p.status,
                           'payment_reason', v_p.payment_reason,
                           'reason_label', 'Frais de dossier'));
    END LOOP;
  END IF;

  -- 3. Le reçu entre dans la file des courriels (inerte tant qu'aucune clé
  --    d'envoi n'est posée : l'étudiante le voit dans l'application).
  SELECT id INTO v_recu FROM app.payment_receipts WHERE payment_id = p_payment_id;
  IF v_recu IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM app.email_queue WHERE receipt_id = v_recu) THEN
    INSERT INTO app.email_queue (receipt_id, status) VALUES (v_recu, 'pending');
  END IF;

  -- 4. L'étudiante est prévenue par la notification qu'elle connaît déjà :
  --    « ✅ Paiement confirmé ! », qui ouvre l'écran de ses paiements, où
  --    sont le reçu et le bon.
  PERFORM public.app_queue_notification_event(v_res.student_id,
    'student_payments', 'payment_status_changed',
    jsonb_build_object(
      'payment_id', p_payment_id,
      'old_status', 'en_reserve',
      'new_status', 'confirmed',
      'payment_reason', v_p.payment_reason,
      'reason_label', 'Frais de courtage',
      'amount_paid', COALESCE(v_p.amount_paid, 0),
      'amount_due', v_p.amount_due,
      'currency', v_p.currency,
      'program_name', COALESCE(v_prog, ''),
      'reference_code', COALESCE(v_p.reference_code, '')));

  INSERT INTO app.admin_audit_log (admin_id, action_type, target_type, target_id,
                                   target_user_id, details)
  VALUES (v_admin, 'publier_documents_en_reserve', 'application_payment',
          p_payment_id::text, v_res.student_id,
          jsonb_build_object('prepare_le', v_res.prepared_at,
                             'candidat', v_nom, 'formation', v_prog));

  RETURN jsonb_build_object('success', TRUE, 'deja_publie', FALSE,
    'candidat', v_nom,
    'message', 'Reçu et bon publiés dans l''espace de '
            || COALESCE(v_nom, 'la candidate') || ', qui a été notifiée.');
END;
$function$;

REVOKE ALL ON FUNCTION public.app_admin_publier_documents_en_reserve(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.app_admin_publier_documents_en_reserve(UUID) TO authenticated;
