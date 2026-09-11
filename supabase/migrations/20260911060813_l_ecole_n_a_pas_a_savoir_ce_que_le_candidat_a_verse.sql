-- L'ecole n'a pas a savoir ce que le candidat a verse a Nexiom.
--
-- CE QUI A DECLENCHE CECI. Jocelyn, le 10/09 : « l'onglet paiement cote
-- universite recoit aussi le recu du paiement de l'interesse. » L'onglet a ete
-- masque le meme soir. MASQUER UN ECRAN NE RETIRE AUCUN DROIT SERVEUR : un
-- compte universite garde son jeton et peut appeler les fonctions directement.
-- Quatre portes restaient donc ouvertes. Mesurees, une par une.
--
--  1. `app_university_list_brokerage_vouchers` -- l'onglet « Mes documents »,
--     que Jocelyn veut GARDER -- renvoyait `b.snapshot` ENTIER. Le bloc
--     `courtage` de cet instantane porte `montant` et `reference`, c'est-a-dire
--     exactement `amount_paid` et `reference_code` du paiement fait a Nexiom.
--     Mesure : SELECT string_agg(k,', ') FROM jsonb_object_keys(snapshot->'courtage') k
--     -> acquitte_le, devise, montant, reference. Et 1 bon sur 1 en production
--     le porte.
--
--  2. `app_verifier_bon_de_courtage` -- le scan au guichet, l'autre chemin que
--     Jocelyn veut garder -- renvoie `'bon', v_b.snapshot` dans TROIS branches :
--     valide, deja_consomme, expire. Meme fuite, au moment meme du controle.
--
--  3. `app_university_list_payments` : SECURITY DEFINER, donc elle ignore la
--     RLS, executable par tout compte authentifie, et elle rend `amount_due`,
--     `amount_paid`, `reference_code`. C'est la source de l'onglet masque.
--     Un onglet masque dont la fonction reste ouverte n'est pas ferme.
--
--  4. Le declencheur `trg_uni_payment_notify` deposait `amount_paid`,
--     `amount_due` et `currency` dans la notification de l'ecole. Mesure :
--     53 evenements destines a des comptes universite portent le montant.
--
-- CE QUI, EN REVANCHE, NE FUYAIT PAS -- et il faut le dire, parce qu'une revue
-- l'avait signale comme la fuite la plus large. La lecture DIRECTE de
-- `app.application_payments` par PostgREST est fermee. La politique
-- `university_select_own_payments` teste `auth.jwt() ->> 'role' = 'university'`
-- et `auth.jwt() ->> 'university_id'` A LA RACINE du jeton ; or Supabase y met
-- `role = authenticated` et range le role metier dans `app_metadata`, et ce
-- projet n'a AUCUN hook de jeton personnalise (verifie : aucune fonction
-- `custom_access_token_hook`). Essai en transaction annulee, role `authenticated`
-- endosse :
--     jeton REEL                 -> 0 paiement, 0 recu visibles
--     jeton avec role a la racine -> 1 paiement
-- La porte est donc close, mais PAR ACCIDENT. La politique ne protege pas ;
-- elle ne s'applique simplement jamais. Ne pas la « reparer » sans se rendre
-- compte qu'on ouvrirait ce qui est aujourd'hui ferme.
-- `app.brokerage_vouchers` n'est de toute facon pas lisible par `authenticated`
-- (permission denied, mesure faite dans le meme essai).

-- ── 1. Un seul endroit decide de ce que l'ecole voit d'un bon ─────────────
-- Deux fonctions rendent ce bon ; si chacune filtrait de son cote, elles
-- divergeraient au premier ajout de champ. Le filtre vit donc ici, et elles
-- l'appellent toutes les deux.
--
-- CE QU'ON GARDE, ET POURQUOI. `acquitte_le` reste : l'ecole a besoin de savoir
-- que le courtage EST regle, sinon le bon ne prouve plus rien. `montant`,
-- `reference` et `devise` partent : ils disent COMBIEN, et cela ne la regarde
-- pas. C'est la ligne exacte que Jocelyn trace.
--
-- ON FILTRE A LA SORTIE, JAMAIS A L'EMISSION. L'instantane stocke ne doit pas
-- bouger : `app.empreinte_bon` en depend, et le declencheur `app.bon_immuable`
-- refuse toute ecriture dessus. Le document du candidat et celui de
-- l'administrateur gardent le montant ; seule la copie de l'ecole le perd.
CREATE OR REPLACE FUNCTION app.bon_vu_par_l_ecole(p_snapshot JSONB)
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
AS $function$
  SELECT CASE
    WHEN p_snapshot IS NULL THEN NULL
    ELSE p_snapshot #- '{courtage,montant}'
                    #- '{courtage,reference}'
                    #- '{courtage,devise}'
  END;
$function$;

COMMENT ON FUNCTION app.bon_vu_par_l_ecole(JSONB) IS
  'L''instantane d''un bon tel qu''un etablissement a le droit de le voir : '
  'sans le montant verse a Nexiom, sans la reference du paiement. '
  '`courtage.acquitte_le` est conserve -- l''ecole doit savoir que les frais '
  'sont regles, pas combien ils etaient.';

-- ── 2. L'onglet « Mes documents » de l'ecole ──────────────────────────────
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
    -- NI LE MONTANT NI LA REFERENCE DU VERSEMENT depuis le 11/09 : le
    -- commentaire ci-dessus ne retirait que les secrets, pas ce que le
    -- candidat a paye.
    SELECT b.id, b.voucher_number, b.issued_at, b.expires_at,
           b.consumed_at, b.transferred_at, b.signature_hash,
           app.bon_vu_par_l_ecole(b.snapshot) AS snapshot,
           (b.expires_at < NOW()) AS expire
    FROM app.brokerage_vouchers b
    WHERE b.destination_university_id = v_univ
      AND b.transferred_at IS NOT NULL
  ) t;

  RETURN jsonb_build_object('success', TRUE, 'vouchers', v_bons);
END;
$function$;

-- ── 3. Le scan au guichet ─────────────────────────────────────────────────
-- Le filtre ne s'applique qu'aux universites. Un administrateur qui verifie un
-- bon garde la vue complete : c'est lui qui a encaisse.
CREATE OR REPLACE FUNCTION public.app_verifier_bon_de_courtage(p_numero TEXT, p_code TEXT)
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
  v_vue    JSONB;
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

  -- LA VUE DEPEND DE QUI REGARDE, POSE LE 11/09. L'ecole ne voit pas ce que le
  -- candidat a verse a Nexiom ; l'administrateur, qui a encaisse, garde tout.
  v_vue := CASE WHEN v_role = 'university'
                THEN app.bon_vu_par_l_ecole(v_b.snapshot)
                ELSE v_b.snapshot END;

  IF v_b.consumed_at IS NOT NULL THEN
    SELECT COALESCE(NULLIF(u.email, ''), 'un compte de votre établissement')
      INTO v_conso FROM auth.users u WHERE u.id = v_b.consumed_by;
    INSERT INTO app.brokerage_voucher_checks (voucher_id, voucher_number, checked_by, university_id, resultat)
    VALUES (v_b.id, v_num, v_user, v_univ, 'deja_consomme');
    RETURN jsonb_build_object('success', FALSE, 'resultat', 'deja_consomme',
      'consomme_le', v_b.consumed_at, 'consomme_par', v_conso,
      'bon', v_vue,
      'message', 'Ce bon a déjà été accepté. Il ne peut pas servir deux fois.');
  END IF;

  IF v_b.expires_at < NOW() THEN
    INSERT INTO app.brokerage_voucher_checks (voucher_id, voucher_number, checked_by, university_id, resultat)
    VALUES (v_b.id, v_num, v_user, v_univ, 'expire');
    RETURN jsonb_build_object('success', FALSE, 'resultat', 'expire',
      'emis_le', v_b.issued_at, 'expire_le', v_b.expires_at,
      'bon', v_vue,
      'message', 'Ce bon est échu. Le candidat doit se rapprocher d''Academia '
              || 'pour en obtenir un nouveau.');
  END IF;

  INSERT INTO app.brokerage_voucher_checks (voucher_id, voucher_number, checked_by, university_id, resultat)
  VALUES (v_b.id, v_num, v_user, v_univ, 'valide');

  RETURN jsonb_build_object('success', TRUE, 'resultat', 'valide',
    'voucher_number', v_b.voucher_number,
    'emis_le', v_b.issued_at, 'expire_le', v_b.expires_at,
    'bon', v_vue,
    'peut_consommer', (v_role = 'university'),
    'message', 'Bon authentique, émis par Nexiom Group, et adressé à votre '
            || 'établissement. Comparez les informations ci-dessous à ce qui '
            || 'est imprimé sur le document.');
END;
$function$;

-- ── 4. La fonction de l'onglet masque ─────────────────────────────────────
-- Le jumeau serveur du masquage cote Flutter. Les deux se reactivent ensemble :
-- repasser `_ongletPaiementsVisible` a true dans
-- academia_app/lib/features/university/university_dashboard_screen.dart NE
-- SUFFIRA PAS -- il faudra aussi rendre ce droit. C'est voulu : un ecran qui
-- revient doit etre une decision, pas un oubli.
REVOKE ALL ON FUNCTION public.app_university_list_payments() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.app_university_list_payments() FROM anon, authenticated;

COMMENT ON FUNCTION public.app_university_list_payments() IS
  'REVOQUEE le 11/09/2026, en meme temps que le masquage de l''onglet '
  '« Paiements » cote universite. Elle rend le montant verse et la reference '
  'du paiement, ce que l''etablissement n''a pas a connaitre. Pour la '
  'reactiver : GRANT EXECUTE TO authenticated, ET repasser '
  '_ongletPaiementsVisible a true cote Flutter.';

-- ── 5. La notification de l'ecole ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.app_notify_university_payment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE v_uni_user RECORD; v_student_name TEXT; v_program_name TEXT; v_reason_label TEXT;
BEGIN
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
