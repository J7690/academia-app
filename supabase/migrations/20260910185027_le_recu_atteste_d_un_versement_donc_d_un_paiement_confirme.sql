-- Le meme verrou interieur, sur la fabrique de recus.
--
-- Un recu porte la mention « Preuve de versement ». L'emettre sur un paiement
-- en attente, c'est signer la preuve d'un versement qui n'a pas eu lieu -- et
-- le document est ensuite indiscernable d'un vrai : meme numerotation, meme
-- empreinte, meme mise en page.
--
-- La garde est posee APRES le controle « deja emis » : un recu deja produit
-- reste consultable meme si le paiement est annule plus tard. On ne reecrit
-- pas l'histoire, on refuse seulement d'en ecrire une fausse.
--
-- `CREATE OR REPLACE` conserve les droits ; le REVOKE de la migration
-- precedente tient. Il est repose ici par prudence, pas par necessite.

CREATE OR REPLACE FUNCTION app.emettre_recu(
  p_payment_id    UUID,
  p_issued_by     UUID  DEFAULT NULL,
  p_complement    JSONB DEFAULT NULL,
  p_email_secours TEXT  DEFAULT NULL
) RETURNS JSONB
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
    ELSE 'Prestation Academia'
  END;

  v_designation := NULLIF(TRIM(BOTH ' ·' FROM CONCAT_WS(' · ',
      NULLIF(v_universite, ''),
      NULLIF(CONCAT_WS(' ', NULLIF(v_formation,''),
                            CASE WHEN COALESCE(v_niveau,'') <> ''
                                 THEN '(' || v_niveau || ')' END), ''),
      CASE WHEN v_pack_nom IS NOT NULL
           THEN 'Pack ' || v_pack_nom ||
                COALESCE(' · ' || v_credits::text || ' crédits', '') END
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
      'reference_operateur', NULLIF(v_p.ligdicash_transaction_id, ''))),
    'dossier', CASE WHEN v_p.application_id IS NOT NULL THEN jsonb_strip_nulls(
      jsonb_build_object('candidature_id', v_p.application_id,
                         'formation', v_formation, 'niveau', v_niveau,
                         'universite', v_universite)) END,
    'credits', CASE WHEN v_pack_code IS NOT NULL THEN
      jsonb_build_object('pack', v_pack_nom, 'code', v_pack_code,
                         'quantite', v_credits) END
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

REVOKE ALL ON FUNCTION app.emettre_recu(UUID, UUID, JSONB, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION app.emettre_recu(UUID, UUID, JSONB, TEXT) FROM anon, authenticated;
