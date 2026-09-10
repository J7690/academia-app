-- L'ÉMISSION DU BON : une seule fonction, deux portes d'entrée.
--
-- Le parcours normal (confirmation d'un paiement de courtage) et la saisie
-- manuelle de l'administrateur appellent LA MÊME fonction. Le document produit
-- est identique, le numéro vient de la même série, l'empreinte du même calcul,
-- et l'université qui vérifie ne sait pas — et n'a pas à savoir — par quelle
-- porte le bon est entré. C'est l'exigence posée par Jocelyn le 09/09.
--
-- ─── NOTE DE LECTURE, IMPORTANTE ───────────────────────────────────────────
-- Cette migration a AUSSI créé `app_verifier_bon_de_courtage` et
-- `app_consommer_bon_de_courtage`. Huit minutes plus tard, la migration
-- `20260909222746_verification_du_bon_normalisation_et_etranglement` les a
-- remplacées pour y ajouter la normalisation du code saisi et l'étranglement
-- des tentatives, à la suite de la relecture de sécurité.
--
-- Ces deux versions intermédiaires ne sont PAS recopiées ici : elles n'ont
-- jamais servi en dehors de la séance, et les recopier ferait croire qu'il
-- existe deux définitions concurrentes. La migration 222746 utilise
-- `CREATE OR REPLACE` : rejouer la suite depuis une base vierge produit donc
-- le bon état final, dans le bon ordre. **C'est 222746 qui fait foi** pour la
-- vérification et la consommation.

CREATE OR REPLACE FUNCTION app.emettre_bon(p_payment_id UUID,
                                           p_issued_by  UUID DEFAULT NULL,
                                           p_origine    TEXT DEFAULT 'automatique',
                                           p_complement JSONB DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'app', 'public', 'pg_temp'
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

  -- IDEMPOTENCE. Réémettre rend le bon existant. Le 02/09 a coûté cher parce
  -- que trois fonctions écrivaient chacune leur reçu.
  SELECT * INTO v_existant FROM app.brokerage_vouchers WHERE payment_id = p_payment_id;
  IF FOUND THEN
    RETURN jsonb_build_object('success', TRUE, 'deja_emis', TRUE,
      'voucher_id', v_existant.id, 'voucher_number', v_existant.voucher_number,
      'verification_code', v_existant.verification_code);
  END IF;

  IF v_p.application_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'paiement_sans_candidature');
  END IF;

  SELECT * INTO v_a FROM app.applications WHERE id = v_p.application_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'candidature_introuvable');
  END IF;

  -- LE BON IMPRIME UN TAUX : sans taux, il n'a rien à attester.
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
  -- Quatorze jours, comme l'annonce la maquette validée le 02/09.
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

  v_empreinte := app.empreinte_bon(v_numero, v_a.id, v_snapshot);

  INSERT INTO app.brokerage_vouchers (
    application_id, payment_id, destination_university_id, voucher_number,
    verification_code, issued_by, expires_at, snapshot, signature_hash, origin)
  VALUES (
    v_a.id, v_p.id, v_univ_id, v_numero, v_code, v_emetteur, v_echeance,
    v_snapshot, v_empreinte,
    CASE WHEN p_origine = 'saisie_manuelle' THEN 'saisie_manuelle' ELSE 'automatique' END)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', TRUE, 'deja_emis', FALSE,
    'voucher_id', v_id, 'voucher_number', v_numero,
    'verification_code', v_code, 'expire_le', v_echeance,
    'signature_hash', v_empreinte);
END;
$function$;

-- Les REVOKE / GRANT sur `app_verifier_bon_de_courtage` et
-- `app_consommer_bon_de_courtage` ne sont PAS ici : ces deux fonctions sont
-- créées par la migration 222746. Les laisser dans ce fichier le ferait
-- échouer sur une base vierge, où elles n'existent pas encore.
