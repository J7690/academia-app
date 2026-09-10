-- LA VÉRIFICATION D'UN BON : version qui fait foi.
--
-- Cette migration crée `app_verifier_bon_de_courtage` et
-- `app_consommer_bon_de_courtage` dans leur forme définitive. Une première
-- version avait été posée par la migration 221936 ; celle-ci la remplace pour
-- y ajouter deux choses issues de la relecture de sécurité.
--
-- 1. NORMALISATION DU CODE SAISI. Le code est lu sur un papier, parfois
--    recopié à la main, parfois dicté. `app.normaliser_code_bon` (migration
--    222643) retire casse et séparateurs et applique les substitutions de
--    Crockford (O→0, I et L→1).
--
-- 2. ÉTRANGLEMENT. Le code fait 8 caractères sur un alphabet de 32, soit
--    40 bits. C'est la longueur de la maquette validée le 02/09, et celle de
--    diplome.gouv.fr ; on ne la change pas sans décision produit. On rend donc
--    la recherche par essais inutile autrement : au-delà de 20 échecs
--    « introuvable » par compte et par heure, on refuse. À ce rythme, épuiser
--    l'espace demanderait plus de cinquante milliards d'heures.
--    Le compteur s'appuie sur le registre des vérifications, qui existe déjà :
--    aucune table de plus, et l'étranglement est lui-même tracé.
--
-- ─── LES SIX RÉPONSES, arrêtées avec Jocelyn le 09/09 ──────────────────────
--   valide ..................... l'école destinataire voit tout, et peut clore
--   deja_consomme .............. quand, et par qui
--   expire ..................... les dates, et quoi faire
--   pas_le_destinataire ........ « émis par Nexiom Group, mais pas adressé à
--                                 votre établissement ». RIEN d'autre, pas
--                                 même le nom de l'école destinataire.
--   introuvable ................ UNE SEULE réponse pour « numéro inconnu » et
--                                 « code faux ». Les distinguer permettrait de
--                                 retrouver les codes en essayant.
--   reserve_aux_universites .... tout autre rôle
--
-- L'ADMINISTRATEUR PEUT VÉRIFIER, MAIS PAS CLORE. Chemin de secours mesuré le
-- 09/09 : un compte université sur trente n'a pas d'identifiant d'école et ne
-- pourrait vérifier aucun bon, pas même le sien. Clore, en revanche, c'est
-- accepter l'inscription : cela n'appartient qu'à l'établissement.

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

  SELECT * INTO v_b FROM app.brokerage_vouchers
   WHERE voucher_number = v_num AND verification_code = v_code;

  IF NOT FOUND THEN
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
   WHERE voucher_number = v_num AND verification_code = v_code;
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

-- Les droits vivent ici, avec les fonctions qu'ils concernent.
REVOKE ALL ON FUNCTION public.app_verifier_bon_de_courtage(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_consommer_bon_de_courtage(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_verifier_bon_de_courtage(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_consommer_bon_de_courtage(TEXT, TEXT) TO authenticated;
