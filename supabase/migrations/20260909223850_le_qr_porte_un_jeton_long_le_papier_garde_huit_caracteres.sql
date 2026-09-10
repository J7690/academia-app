-- Deux secrets pour deux usages, au lieu d'un compromis pour les deux.
--
-- LE PROBLÈME. La relecture de sécurité demandait d'allonger le code à 10-12
-- caractères pour monter l'entropie. Écarté : 8 caractères, c'est la maquette
-- validée par Jocelyn le 02/09, et c'est aussi diplome.gouv.fr. Mais ce refus
-- laissait 40 bits, compensés seulement par un étranglement.
--
-- CE QU'ON FAIT À LA PLACE, ET QUI EST STRICTEMENT MEILLEUR. Le bon porte
-- désormais DEUX secrets, parce qu'il a DEUX lecteurs :
--
--   * le CODE À 8 CARACTÈRES reste imprimé, pour l'oeil et pour la saisie à la
--     main. 40 bits, étranglé à 20 essais par heure et par compte ;
--   * un JETON DE SCAN de 128 bits, invisible sur le papier, encodé dans le QR.
--     Une machine le lit : sa longueur ne coûte rien à personne.
--
-- Le QR devient /v/<numéro>/<jeton long> au lieu de /v/<numéro>/<8 car.>.
-- **Le document imprimé ne change pas d'un pixel.**
--
-- CONSÉQUENCE SUR L'ÉTRANGLEMENT. Il ne gêne plus le chemin normal : une
-- vérification qui RÉUSSIT n'est plus comptée ni bloquée. Seuls les échecs
-- sont étranglés. Une école qui scanne son bon passe toujours, même si
-- quelqu'un a mal recopié dix codes avant elle.
--
-- Aucun bon n'existait au moment de ce changement : rien à rattraper.

ALTER TABLE app.brokerage_vouchers
  ADD COLUMN IF NOT EXISTS scan_token TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS brokerage_vouchers_scan_token_idx
  ON app.brokerage_vouchers (scan_token) WHERE scan_token IS NOT NULL;

COMMENT ON COLUMN app.brokerage_vouchers.scan_token IS
  'Secret long (128 bits) encodé dans le QR. N''est JAMAIS imprimé en clair : '
  'le papier porte verification_code, lisible à l''oeil. Deux lecteurs, deux '
  'secrets.';

CREATE OR REPLACE FUNCTION app.emettre_bon(p_payment_id UUID,
                                           p_issued_by  UUID DEFAULT NULL,
                                           p_origine    TEXT DEFAULT 'automatique',
                                           p_complement JSONB DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'app', 'public', 'extensions', 'pg_temp'
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

CREATE OR REPLACE FUNCTION public.app_verifier_bon_de_courtage(p_numero TEXT,
                                                               p_code   TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user   UUID := auth.uid();
  v_role   TEXT;
  v_univ   UUID;
  v_b      app.brokerage_vouchers%ROWTYPE;
  v_num    TEXT := UPPER(TRIM(COALESCE(p_numero, '')));
  v_brut   TEXT := LOWER(TRIM(COALESCE(p_code, '')));
  v_code   TEXT := app.normaliser_code_bon(p_code);
  v_conso  TEXT;
  v_echecs INTEGER;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'resultat', 'non_authentifie');
  END IF;

  SELECT COALESCE(u.raw_app_meta_data->>'role', u.raw_user_meta_data->>'role')
    INTO v_role FROM auth.users u WHERE u.id = v_user;
  v_univ := app.universite_de_l_utilisateur(v_user);

  IF v_role IS NULL OR v_role NOT IN ('university', 'admin') THEN
    INSERT INTO app.brokerage_voucher_checks (voucher_number, checked_by, resultat)
    VALUES (v_num, v_user, 'reserve_aux_universites');
    RETURN jsonb_build_object('success', FALSE, 'resultat', 'reserve_aux_universites',
      'message', 'La vérification d''un bon de courtage est réservée aux '
              || 'établissements destinataires.');
  END IF;

  -- ON CHERCHE D'ABORD, ON ETRANGLE ENSUITE. Une verification qui REUSSIT n'a
  -- pas a etre penalisee parce que quelqu'un a mal recopie dix codes avant.
  -- Le jeton du QR (128 bits) et le code du papier (40 bits) ouvrent la meme
  -- porte ; seul le second peut se deviner, et seuls les echecs sont comptes.
  SELECT * INTO v_b FROM app.brokerage_vouchers
   WHERE voucher_number = v_num
     AND (verification_code = v_code OR scan_token = v_brut);

  IF NOT FOUND THEN
    SELECT COUNT(*) INTO v_echecs
      FROM app.brokerage_voucher_checks
     WHERE checked_by = v_user AND resultat = 'introuvable'
       AND checked_at > NOW() - INTERVAL '1 hour';
    IF v_echecs >= 20 THEN
      INSERT INTO app.brokerage_voucher_checks (voucher_number, checked_by, university_id, resultat)
      VALUES (v_num, v_user, v_univ, 'trop_de_tentatives');
      RETURN jsonb_build_object('success', FALSE, 'resultat', 'trop_de_tentatives',
        'message', 'Trop de codes erronés ont été essayés depuis ce compte. '
                || 'Réessayez dans une heure.');
    END IF;
    INSERT INTO app.brokerage_voucher_checks (voucher_number, checked_by, university_id, resultat)
    VALUES (v_num, v_user, v_univ, 'introuvable');
    RETURN jsonb_build_object('success', FALSE, 'resultat', 'introuvable',
      'message', 'Aucun bon de courtage ne correspond à ce code.');
  END IF;

  IF v_role = 'university' AND (v_univ IS NULL OR v_univ <> v_b.destination_university_id) THEN
    INSERT INTO app.brokerage_voucher_checks (voucher_id, voucher_number, checked_by, university_id, resultat)
    VALUES (v_b.id, v_num, v_user, v_univ, 'pas_le_destinataire');
    RETURN jsonb_build_object('success', FALSE, 'resultat', 'pas_le_destinataire',
      'emetteur', 'NEXIOM GROUP',
      'message', 'Ce bon a bien été émis par Nexiom Group, mais il n''est pas '
              || 'adressé à votre établissement. Vous n''êtes pas autorisé à '
              || 'inscrire ce candidat sur la base de ce document.');
  END IF;

  IF v_b.consumed_at IS NOT NULL THEN
    SELECT COALESCE(NULLIF(u.email, ''), 'un compte de votre établissement')
      INTO v_conso FROM auth.users u WHERE u.id = v_b.consumed_by;
    INSERT INTO app.brokerage_voucher_checks (voucher_id, voucher_number, checked_by, university_id, resultat)
    VALUES (v_b.id, v_num, v_user, v_univ, 'deja_consomme');
    RETURN jsonb_build_object('success', FALSE, 'resultat', 'deja_consomme',
      'consomme_le', v_b.consumed_at, 'consomme_par', v_conso,
      'bon', v_b.snapshot,
      'message', 'Ce bon a déjà été accepté. Il ne peut pas servir deux fois.');
  END IF;

  IF v_b.expires_at < NOW() THEN
    INSERT INTO app.brokerage_voucher_checks (voucher_id, voucher_number, checked_by, university_id, resultat)
    VALUES (v_b.id, v_num, v_user, v_univ, 'expire');
    RETURN jsonb_build_object('success', FALSE, 'resultat', 'expire',
      'emis_le', v_b.issued_at, 'expire_le', v_b.expires_at,
      'bon', v_b.snapshot,
      'message', 'Ce bon est échu. Le candidat doit se rapprocher d''Academia '
              || 'pour en obtenir un nouveau.');
  END IF;

  INSERT INTO app.brokerage_voucher_checks (voucher_id, voucher_number, checked_by, university_id, resultat)
  VALUES (v_b.id, v_num, v_user, v_univ, 'valide');

  RETURN jsonb_build_object('success', TRUE, 'resultat', 'valide',
    'voucher_number', v_b.voucher_number,
    'emis_le', v_b.issued_at, 'expire_le', v_b.expires_at,
    'bon', v_b.snapshot,
    'peut_consommer', (v_role = 'university'),
    'message', 'Bon authentique, émis par Nexiom Group, et adressé à votre '
            || 'établissement. Comparez les informations ci-dessous à ce qui '
            || 'est imprimé sur le document.');
END;
$function$;

CREATE OR REPLACE FUNCTION public.app_consommer_bon_de_courtage(p_numero TEXT,
                                                                p_code   TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user UUID := auth.uid();
  v_role TEXT;
  v_univ UUID;
  v_b    app.brokerage_vouchers%ROWTYPE;
  v_num  TEXT := UPPER(TRIM(COALESCE(p_numero, '')));
  v_brut TEXT := LOWER(TRIM(COALESCE(p_code, '')));
  v_code TEXT := app.normaliser_code_bon(p_code);
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'resultat', 'non_authentifie');
  END IF;

  SELECT COALESCE(u.raw_app_meta_data->>'role', u.raw_user_meta_data->>'role')
    INTO v_role FROM auth.users u WHERE u.id = v_user;
  v_univ := app.universite_de_l_utilisateur(v_user);

  IF COALESCE(v_role, '') <> 'university' THEN
    RETURN jsonb_build_object('success', FALSE, 'resultat', 'reserve_aux_universites',
      'message', 'Seul l''établissement destinataire peut clore un bon.');
  END IF;

  SELECT * INTO v_b FROM app.brokerage_vouchers
   WHERE voucher_number = v_num
     AND (verification_code = v_code OR scan_token = v_brut);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'resultat', 'introuvable',
      'message', 'Aucun bon de courtage ne correspond à ce code.');
  END IF;

  IF v_univ IS NULL OR v_univ <> v_b.destination_university_id THEN
    INSERT INTO app.brokerage_voucher_checks (voucher_id, voucher_number, checked_by, university_id, resultat)
    VALUES (v_b.id, v_num, v_user, v_univ, 'pas_le_destinataire');
    RETURN jsonb_build_object('success', FALSE, 'resultat', 'pas_le_destinataire',
      'emetteur', 'NEXIOM GROUP',
      'message', 'Ce bon a bien été émis par Nexiom Group, mais il n''est pas '
              || 'adressé à votre établissement.');
  END IF;

  IF v_b.consumed_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'resultat', 'deja_consomme',
      'consomme_le', v_b.consumed_at,
      'message', 'Ce bon a déjà été accepté.');
  END IF;

  IF v_b.expires_at < NOW() THEN
    RETURN jsonb_build_object('success', FALSE, 'resultat', 'expire',
      'expire_le', v_b.expires_at,
      'message', 'Ce bon est échu et ne peut plus être accepté.');
  END IF;

  UPDATE app.brokerage_vouchers
     SET consumed_at = NOW(), consumed_by = v_user
   WHERE id = v_b.id;

  INSERT INTO app.brokerage_voucher_checks (voucher_id, voucher_number, checked_by, university_id, resultat)
  VALUES (v_b.id, v_num, v_user, v_univ, 'consomme');

  RETURN jsonb_build_object('success', TRUE, 'resultat', 'consomme',
    'voucher_number', v_b.voucher_number, 'consomme_le', NOW(),
    'message', 'Bon accepté et clos. Il ne pourra plus être présenté.');
END;
$function$;
