-- Les deux fabriques de documents étaient appelables par n'importe qui.
--
-- ⚠ LE `SET search_path` ÉCRIT PLUS BAS EST FAUX, et corrigé le jour même par
-- `20260910185151_rendre_a_emettre_bon_le_schema_extensions_dans_son_chemin.sql`.
-- Je l'avais recopié de mémoire au lieu de le relever : le schéma `extensions`
-- y manquait, donc `gen_random_bytes`, donc le jeton de scan. Conservé tel quel
-- parce que c'est ce qui a été appliqué.
--
-- MESURE DU 10/09/2026, avant correction :
--
--   fonction                  proacl                       authenticated  anon
--   app.emettre_recu          NULL (= EXECUTE à PUBLIC)    oui            oui
--   app.emettre_bon           NULL (= EXECUTE à PUBLIC)    oui            oui
--   app.code_verification_bon NULL (= EXECUTE à PUBLIC)    oui            oui
--
-- Et le schéma `app` est atteignable depuis le client : 40 appels
-- `client.schema('app')` dans academia_app/lib. PostgREST expose donc aussi
-- `POST /rest/v1/rpc/emettre_bon` avec l'en-tête `Content-Profile: app`.
--
-- CE QUE ÇA PERMETTAIT. `app.emettre_bon` ne vérifie NI l'identité de
-- l'appelant NI le statut du paiement : elle exige un motif `application_fee`,
-- une candidature, et un `discount_rate` non nul. Un étudiant dont
-- l'administrateur vient de fixer le taux pouvait donc, sans payer, appeler
-- directement la fabrique et obtenir un bon de courtage authentique --
-- numéroté, signé, avec son QR et son code, indiscernable au guichet d'un bon
-- régulier. C'est exactement le verrou posé le 09/09 (« pas de paiement
-- possible tant que l'administrateur n'a pas validé le pourcentage »)
-- contourné par la porte de service. Idem pour `app.emettre_recu` : un reçu de
-- versement pour un versement qui n'a pas eu lieu.
--
-- POURQUOI C'ÉTAIT OUVERT. Une fonction PostgreSQL est, par défaut, exécutable
-- par PUBLIC. Les RPC de `public` portent toutes un REVOKE explicite ; ces
-- deux-là, écrites les 02/09 et 09/09, n'en ont jamais eu. Le
-- `ALTER DEFAULT PRIVILEGES` du 04/08 (« fermer par défaut les fonctions
-- futures ») ne les a pas couvertes.
--
-- DEUX VERROUS PLUTÔT QU'UN. Le REVOKE ferme la porte ; la garde de statut la
-- verrouille de l'intérieur. Un futur enrobage étourdi retrouverait sinon le
-- même défaut sans que rien ne le signale.
--
-- CE QUI N'EST PAS TOUCHÉ, ET POURQUOI. Les quatre appelants
-- (`app_admin_confirm_payment`, `app_confirm_credit_purchase`,
-- `app_confirm_ligdicash_payment`, `app_admin_emettre_documents_manuels`) sont
-- tous SECURITY DEFINER et appartiennent à `postgres`, qui conserve EXECUTE :
-- le parcours normal ne change pas. Vérifié avant d'écrire, pas supposé.
--
-- RESTE OUVERT, ET C'EST DÉLIBÉRÉ : `app.empreinte_recu` et `app.empreinte_bon`
-- sont appelées par `app.trigger_payment_receipts_signature`, un déclencheur
-- SECURITY INVOKER. Les révoquer risquerait de casser une insertion faite par
-- un autre chemin. Elles ne calculent qu'un condensé de données que l'appelant
-- possède déjà ; le vrai défaut de l'empreinte -- elle n'est pas clefée, donc
-- quiconque a l'instantané la recalcule -- se corrige par une clef, pas par un
-- droit, et cette décision revient à Jocelyn.

REVOKE ALL ON FUNCTION app.emettre_recu(UUID, UUID, JSONB, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION app.emettre_recu(UUID, UUID, JSONB, TEXT) FROM anon, authenticated;

REVOKE ALL ON FUNCTION app.emettre_bon(UUID, UUID, TEXT, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION app.emettre_bon(UUID, UUID, TEXT, JSONB) FROM anon, authenticated;

REVOKE ALL ON FUNCTION app.code_verification_bon() FROM PUBLIC;
REVOKE ALL ON FUNCTION app.code_verification_bon() FROM anon, authenticated;

-- ── Le verrou intérieur du bon ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION app.emettre_bon(
  p_payment_id UUID,
  p_issued_by  UUID  DEFAULT NULL,
  p_origine    TEXT  DEFAULT 'automatique',
  p_complement JSONB DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_p          app.application_payments%ROWTYPE;
  v_a          app.applications%ROWTYPE;
  v_existant   app.brokerage_vouchers%ROWTYPE;
  v_univ_id    UUID;
  v_univ_nom   TEXT;
  v_univ_ville TEXT;
  v_formation  TEXT;
  v_niveau     TEXT;
  v_nom        TEXT;
  v_naissance  DATE;
  v_tel        TEXT;
  v_ville      TEXT;
  v_numero     TEXT;
  v_code       TEXT;
  v_jeton      TEXT;
  v_echeance   TIMESTAMPTZ;
  v_snapshot   JSONB;
  v_empreinte  TEXT;
  v_id         UUID;
  v_emetteur   UUID;
BEGIN
  IF p_payment_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'payment_id_manquant');
  END IF;

  SELECT * INTO v_p FROM app.application_payments WHERE id = p_payment_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'paiement_introuvable');
  END IF;

  IF v_p.payment_reason <> 'application_fee'::public.payment_reason THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'motif_non_courtage');
  END IF;

  SELECT * INTO v_existant FROM app.brokerage_vouchers WHERE payment_id = p_payment_id;
  IF FOUND THEN
    RETURN jsonb_build_object('success', TRUE, 'deja_emis', TRUE,
      'voucher_id', v_existant.id, 'voucher_number', v_existant.voucher_number,
      'verification_code', v_existant.verification_code,
      'scan_token', v_existant.scan_token);
  END IF;

  -- ── LE VERROU INTERIEUR, POSE LE 10/09 ──────────────────────────────────
  -- Un bon atteste d'un courtage ACQUITTE. L'emettre sur un paiement en
  -- attente, c'est fabriquer la preuve d'un versement qui n'a pas eu lieu.
  -- La garde est ici, et pas seulement chez l'appelant, parce que le droit
  -- d'appel a deja ete ouvert une fois par oubli.
  IF v_p.status <> 'confirmed'::public.payment_status THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'paiement_non_confirme',
      'statut', v_p.status::text);
  END IF;

  IF v_p.application_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'paiement_sans_candidature');
  END IF;

  SELECT * INTO v_a FROM app.applications WHERE id = v_p.application_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'candidature_introuvable');
  END IF;

  IF v_a.discount_rate IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'taux_de_reduction_non_fixe');
  END IF;

  SELECT pr.title, pr.degree_level, pr.university_id
    INTO v_formation, v_niveau, v_univ_id
  FROM app.programs pr WHERE pr.id = v_a.program_id;

  IF v_univ_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'programme_sans_etablissement');
  END IF;

  SELECT u.name, u.city INTO v_univ_nom, v_univ_ville
  FROM app.universities u WHERE u.id = v_univ_id;

  SELECT s.full_name, s.date_of_birth, s.phone, s.city
    INTO v_nom, v_naissance, v_tel, v_ville
  FROM app.students s WHERE s.id = v_p.student_id;

  v_tel      := COALESCE(NULLIF(v_p.phone_number, ''), v_tel);
  v_emetteur := COALESCE(p_issued_by, auth.uid(), v_p.confirmed_by, v_p.student_id);
  v_numero   := 'BC-' || TO_CHAR(NOW(), 'YYYY') || '-'
                || LPAD(NEXTVAL('app.bon_numero_seq')::text, 6, '0');
  v_code     := app.code_verification_bon();
  -- 16 octets = 128 bits. Le QR le lit, personne ne le tape.
  v_jeton    := encode(gen_random_bytes(16), 'hex');
  v_echeance := NOW() + INTERVAL '14 days';

  v_snapshot := jsonb_strip_nulls(jsonb_build_object(
    'version', 1,
    'numero', v_numero,
    'emis_le', NOW(),
    'expire_le', v_echeance,
    'origine', p_origine,
    'emetteur', jsonb_build_object(
      'raison_sociale', 'NEXIOM GROUP',
      'ville', 'Ouagadougou', 'pays', 'Burkina Faso',
      'rccm', 'BF-OUA-01-2025-B13-13341', 'ifu', '00281802P',
      'telephone', '73 93 43 92', 'site', 'www.app.academiea.com'),
    'destinataire', jsonb_strip_nulls(jsonb_build_object(
      'universite_id', v_univ_id, 'nom', v_univ_nom, 'ville', v_univ_ville)),
    'formation', jsonb_strip_nulls(jsonb_build_object(
      'titre', v_formation, 'niveau', v_niveau,
      'mode', NULLIF(v_a.requested_study_mode, ''),
      'horaires', NULLIF(v_a.requested_schedule, ''))),
    'candidat', jsonb_strip_nulls(jsonb_build_object(
      'nom', v_nom, 'date_de_naissance', v_naissance,
      'telephone', v_tel, 'ville', v_ville,
      'candidature_id', v_a.id)),
    'reduction', jsonb_strip_nulls(jsonb_build_object(
      'taux', v_a.discount_rate,
      'validee_le', v_a.discount_validated_at,
      'note', NULLIF(v_a.discount_details, ''))),
    'courtage', jsonb_strip_nulls(jsonb_build_object(
      'montant', COALESCE(v_p.amount_paid, v_p.amount_due),
      'devise', COALESCE(NULLIF(v_p.currency, ''), 'XOF'),
      'acquitte_le', COALESCE(v_p.confirmed_at, v_p.declared_at, v_p.created_at),
      'reference', v_p.reference_code))
  )) || COALESCE(p_complement, '{}'::jsonb);

  -- L'EMPREINTE NE PORTE PAS LES SECRETS. Elle atteste du CONTENU du document ;
  -- y meler le jeton la rendrait invalidable par une rotation de secret.
  v_empreinte := app.empreinte_bon(v_numero, v_a.id, v_snapshot);

  INSERT INTO app.brokerage_vouchers (
    application_id, payment_id, destination_university_id, voucher_number,
    verification_code, scan_token, issued_by, expires_at, snapshot,
    signature_hash, origin)
  VALUES (
    v_a.id, v_p.id, v_univ_id, v_numero, v_code, v_jeton, v_emetteur, v_echeance,
    v_snapshot, v_empreinte,
    CASE WHEN p_origine = 'saisie_manuelle' THEN 'saisie_manuelle' ELSE 'automatique' END)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', TRUE, 'deja_emis', FALSE,
    'voucher_id', v_id, 'voucher_number', v_numero,
    'verification_code', v_code, 'scan_token', v_jeton,
    'expire_le', v_echeance, 'signature_hash', v_empreinte);
END;
$function$;

REVOKE ALL ON FUNCTION app.emettre_bon(UUID, UUID, TEXT, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION app.emettre_bon(UUID, UUID, TEXT, JSONB) FROM anon, authenticated;
