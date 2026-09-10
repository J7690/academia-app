-- Courtage : pas de paiement tant que l'administrateur n'a pas fixé le taux.
--
-- LA SÉQUENCE VOULUE (Jocelyn, 09/09/2026) :
--   l'université donne son accord ou fait une contre-proposition
--   -> l'étudiant accepte
--   -> L'ADMINISTRATEUR INSCRIT LE TAUX OBTENU SUR LA CANDIDATURE
--   -> et seulement alors l'étudiant peut régler ses frais de courtage
--   -> le bon de courtage relira ce taux pour l'imprimer.
--
-- CE QUI CLOCHAIT, MESURÉ LE 09/09 :
--
--   1. LE TAUX N'EST PAS UN NOMBRE. `applications.discount_details` est du
--      texte libre : 24 candidatures sur 35 en portent un, de 2 à 354
--      caractères, l'une d'elles vaut simplement « 50% ». Un bon de courtage
--      qui imprime « 15 % de réduction » ne peut pas lire cette colonne sans
--      mentir. On ajoute donc un CHAMP NUMÉRIQUE, et le texte reste à côté
--      comme commentaire de négociation -- il n'est ni effacé ni réinterprété.
--
--   2. RIEN N'ORDONNE LE PAIEMENT. Aujourd'hui l'étudiant peut régler dès que
--      sa candidature est `accepted`, que le taux soit fixé ou non. La
--      plateforme encaisse donc un courtage avant de savoir ce qu'elle a
--      négocié, et le bon qui suivra n'aura rien à attester.
--
-- CE QUI EST PRÉSERVÉ, ET IL FAUT QUE ÇA LE RESTE :
--   * le verrou de prix du 02/09 -- le tarif du courtage vient du programme,
--     JAMAIS de l'appelant. Une clé publique dans l'APK avait permis de payer
--     1 FCFA un courtage à 25 000 ;
--   * le contrôle `not_owner`, qui manquait entièrement avant le 02/09.
-- Les deux sont recopiés à l'identique ci-dessous.

-- ── 1. Le taux, et qui l'a validé ──────────────────────────────────────────
ALTER TABLE app.applications
  ADD COLUMN IF NOT EXISTS discount_rate         NUMERIC(5,2),
  ADD COLUMN IF NOT EXISTS discount_validated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS discount_validated_by UUID REFERENCES auth.users(id);

-- Un taux hors de [0, 100] n'est pas une réduction, c'est une faute de saisie.
-- Zéro est permis, et volontairement : « négocié, rien obtenu » est un
-- résultat, et il doit pouvoir être enregistré pour débloquer le paiement.
ALTER TABLE app.applications
  DROP CONSTRAINT IF EXISTS applications_discount_rate_borne;
ALTER TABLE app.applications
  ADD CONSTRAINT applications_discount_rate_borne
  CHECK (discount_rate IS NULL OR (discount_rate >= 0 AND discount_rate <= 100));

COMMENT ON COLUMN app.applications.discount_rate IS
  'Taux de réduction obtenu auprès de l''établissement, en pourcentage. '
  'Fixé par un administrateur APRÈS accord des parties. Tant qu''il est NULL, '
  'aucun paiement de courtage n''est possible sur cette candidature. '
  'À ne pas confondre avec discount_details, qui reste du texte libre.';

-- ── 2. L'administrateur fixe le taux ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_admin_set_application_discount(
  p_application_id UUID,
  p_discount_rate  NUMERIC,
  p_note           TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_app     RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- Le rôle est lu dans `raw_app_meta_data`, que l'utilisateur ne peut pas
  -- modifier -- contrairement à `raw_user_meta_data`. C'est la garde posée
  -- le 03/09, et toute garde nouvelle s'y appuie.
  IF COALESCE((SELECT raw_app_meta_data->>'role' FROM auth.users WHERE id = v_user_id), '')
     <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  IF p_discount_rate IS NULL OR p_discount_rate < 0 OR p_discount_rate > 100 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'taux_invalide');
  END IF;

  SELECT * INTO v_app FROM app.applications WHERE id = p_application_id;
  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
  END IF;

  UPDATE app.applications
     SET discount_rate         = p_discount_rate,
         discount_validated_at = NOW(),
         discount_validated_by = v_user_id,
         discount_details      = COALESCE(NULLIF(TRIM(p_note), ''), discount_details),
         updated_at            = NOW()
   WHERE id = p_application_id;

  -- Le taux commande un encaissement : on trace qui l'a posé, et à quoi il
  -- succède. Une correction ultérieure doit rester lisible.
  INSERT INTO app.admin_audit_log (admin_id, action_type, target_type, target_id,
                                   target_user_id, details)
  VALUES (v_user_id, 'set_application_discount', 'application',
          p_application_id::text, v_app.student_id,
          JSONB_BUILD_OBJECT('taux', p_discount_rate,
                             'taux_precedent', v_app.discount_rate,
                             'note', p_note));

  RETURN JSONB_BUILD_OBJECT('success', TRUE,
                            'application_id', p_application_id,
                            'discount_rate', p_discount_rate);
END;
$function$;

REVOKE ALL ON FUNCTION public.app_admin_set_application_discount(UUID, NUMERIC, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_admin_set_application_discount(UUID, NUMERIC, TEXT) TO authenticated;

-- ── 3. Le verrou : pas de paiement de courtage sans taux ───────────────────
-- Recopie fidèle de la fonction du 02/09, avec UN seul ajout, signalé.
CREATE OR REPLACE FUNCTION public.app_create_application_payment(
  p_application_id UUID,
  p_payment_reason payment_reason,
  p_amount_due     NUMERIC DEFAULT NULL::numeric
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_app RECORD;
  v_role TEXT;
  v_amount NUMERIC;
  v_fee NUMERIC;
  v_student_id UUID;
  v_university_id UUID;
  v_payment_id UUID;
  v_reference_code TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  IF p_application_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_application_id');
  END IF;

  IF p_payment_reason IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_payment_reason');
  END IF;

  SELECT a.*, p.university_id, p.brokerage_fee
  INTO v_app
  FROM app.applications a
  JOIN app.programs p ON p.id = a.program_id
  WHERE a.id = p_application_id;

  IF NOT FOUND THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_not_found');
  END IF;

  v_student_id := v_app.student_id;
  v_university_id := v_app.university_id;

  IF v_student_id IS NULL OR v_university_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'application_links_invalid');
  END IF;

  -- QUI PEUT CREER CE PAIEMENT : le proprietaire du dossier, ou un admin.
  -- Ce controle manquait entierement.
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
  IF v_student_id <> v_user_id AND COALESCE(v_role, '') <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_owner');
  END IF;

  IF p_payment_reason = 'application_fee' THEN
    -- COURTAGE : le tarif vient du programme, JAMAIS de l'appelant.
    v_fee := COALESCE(v_app.brokerage_fee, 0);
    IF v_fee <= 0 THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'brokerage_fee_not_defined');
    END IF;

    -- ── L'AJOUT DU 09/09, ET LE SEUL ────────────────────────────────────
    -- L'étudiant achète une réduction négociée. Tant que personne n'a écrit
    -- ce qui a été obtenu, il n'y a rien à vendre : on refuse d'encaisser.
    -- Le motif est nommé, pour que l'écran puisse l'expliquer au lieu
    -- d'afficher un échec muet.
    IF v_app.discount_rate IS NULL THEN
      RETURN JSONB_BUILD_OBJECT(
        'success', FALSE,
        'error', 'taux_de_reduction_non_fixe',
        'message', 'La réduction négociée n''a pas encore été enregistrée par '
                || 'Academia. Le paiement s''ouvrira dès qu''elle le sera.');
    END IF;

    v_amount := v_fee;
  ELSE
    -- AUTRES MOTIFS : inchange, le montant transmis fait foi.
    -- Achat de credits, acces aux travaux diriges, abonnement : aucun taux
    -- n'est en jeu, et 19 paiements sur 33 sont dans ce cas.
    IF p_amount_due IS NULL OR p_amount_due <= 0 THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_amount_due');
    END IF;
    v_amount := p_amount_due;
  END IF;

  v_reference_code := 'AP-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                      SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);

  INSERT INTO app.application_payments (
    application_id, student_id, university_id, amount_due, currency,
    payment_reason, status, reference_code, created_by
  ) VALUES (
    p_application_id, v_student_id, v_university_id, v_amount, 'XOF',
    p_payment_reason, 'pending', v_reference_code, v_user_id
  )
  RETURNING id INTO v_payment_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'payment_id', v_payment_id,
    'reference_code', v_reference_code,
    'amount_due', v_amount,
    'currency', 'XOF',
    'payment_reason', p_payment_reason,
    'amount_imposed', p_payment_reason = 'application_fee',
    'discount_rate', v_app.discount_rate
  );
END;
$function$;

-- ── 4. Une vue de contrôle : les dossiers qui attendent leur taux ──────────
-- Le verrou bloque des étudiants. Il faut donc pouvoir voir QUI il bloque,
-- sans quoi la file grossit en silence -- c'est le défaut de la file de
-- courriels, restée à 3 entrées en attente depuis juillet sans que personne
-- le sache.
CREATE OR REPLACE VIEW app.candidatures_en_attente_de_taux AS
SELECT a.id            AS application_id,
       s.full_name     AS etudiant,
       u.name          AS universite,
       pr.title        AS formation,
       pr.brokerage_fee AS frais_courtage,
       a.status,
       a.discount_details AS negociation_texte_libre,
       a.updated_at
FROM app.applications a
JOIN app.programs pr        ON pr.id = a.program_id
LEFT JOIN app.universities u ON u.id = pr.university_id
LEFT JOIN app.students s     ON s.id = a.student_id
WHERE a.status = 'accepted'
  AND a.discount_rate IS NULL;

COMMENT ON VIEW app.candidatures_en_attente_de_taux IS
  'Dossiers acceptés dont le taux de réduction n''est pas fixé : l''étudiant '
  'ne peut pas payer. Doit rester court.';
