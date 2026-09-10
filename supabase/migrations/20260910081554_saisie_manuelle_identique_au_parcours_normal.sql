-- Saisie manuelle par l'administrateur : MÊME CHEMIN QUE LE PARCOURS NORMAL.
--
-- ⚠ CORRIGÉE LE MÊME JOUR PAR `20260910082315_saisie_manuelle_le_candidat_a_un_compte.sql`.
-- La fonction créée ici ne pouvait PAS fonctionner : elle insérait une fiche
-- `app.students` pour une personne sans compte, alors que `students_id_fkey`
-- référence `auth.users(id)`. Le commentaire ci-dessous qui affirme le
-- contraire est FAUX ; il est conservé tel quel parce qu'il dit d'où vient la
-- faute, et la migration suivante dit comment on l'a vue. Ce qui reste valable
-- ici : la colonne `manual_entry_by`, et le paramètre `p_email_secours` ajouté
-- à `app.emettre_recu`.
--
-- L'EXIGENCE, mot pour mot (Jocelyn, 09/09/2026) :
--   « Je veux que pour la version manuelle, où c'est l'administrateur qui
--     saisit un certain nombre de données et qui a la possibilité de générer
--     et le reçu et le bon de courtage, que l'application le considère comme
--     si ça avait suivi le processus normal. Même pour la vérification de
--     l'université, que ce soit exactement comme si c'était le processus
--     normal. »
--
-- CE QUE ÇA INTERDIT, ET C'EST TOUT L'INTÉRÊT DE CE FICHIER. Il aurait été
-- bien plus court d'écrire un deuxième générateur de documents « pour les
-- saisies manuelles ». On aurait alors deux formats de numéro, deux façons de
-- calculer l'empreinte, deux tables à interroger au guichet -- et le jour où
-- l'université scanne un bon manuel, un code qui n'a jamais été exercé.
-- Ici, RIEN n'est réécrit : la fonction ci-dessous fabrique les MÊMES lignes
-- que le parcours étudiant, puis appelle `app.emettre_recu` et
-- `app.emettre_bon`, les mêmes que celles qu'appelle
-- `public.app_admin_confirm_payment`. Le bon manuel se vérifie donc par
-- `public.app_verifier_bon_de_courtage`, se consomme par
-- `public.app_consommer_bon_de_courtage`, se transfère par
-- `public.app_admin_transferer_bon`, sans une ligne de code de plus.
--
-- CE QUI REND LA CHOSE POSSIBLE, MESURÉ AVANT D'ÉCRIRE. `app.students` n'a
-- AUCUNE clé étrangère vers `auth.users` : une personne sans compte peut donc
-- avoir une fiche. Vérifié le 10/09 sur `pg_constraint` -- les seules clés
-- étrangères de la chaîne candidature/paiement pointent vers `app.students`,
-- `app.applications`, `app.universities`. La seule qui vise `auth.users` est
-- `applications.discount_validated_by`, et celle-là porte l'administrateur,
-- pas le candidat.
--
-- CE QUI AURAIT CASSÉ SANS CETTE MESURE : `app.notification_events.user_id`,
-- LUI, référence `auth.users`. Un déclencheur qui notifierait le candidat
-- ferait échouer toute la saisie sur une violation de clé étrangère. Vérifié :
-- les déclencheurs qui partent à l'INSERT (`trg_admin_payment_declared_notify`,
-- `trg_uni_payment_notify`, `trg_admin_new_application_notify`,
-- `trg_uni_new_application_notify`) réveillent des ADMINISTRATEURS et des
-- UNIVERSITÉS -- des comptes réels. Celui qui vise l'étudiant,
-- `trg_student_payment_status_notify`, ne part qu'à l'UPDATE ; on insère le
-- paiement déjà confirmé, donc il ne part pas.

-- ── 1. Reconnaître une fiche ouverte par un administrateur ────────────────
-- Sans cette marque, un candidat saisi au comptoir est indiscernable d'un
-- étudiant inscrit, et personne ne peut répondre à « combien de dossiers sont
-- passés hors plateforme ? ». Deux colonnes nullables : aucune requête
-- existante ne change de résultat.
ALTER TABLE app.students
  ADD COLUMN IF NOT EXISTS manual_entry_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS manual_entry_at TIMESTAMPTZ;

COMMENT ON COLUMN app.students.manual_entry_by IS
  'Administrateur qui a ouvert cette fiche au comptoir, pour une personne sans '
  'compte. NULL pour toute personne inscrite elle-même. Ne vaut PAS dispense : '
  'la candidature, le paiement, le reçu et le bon qui suivent sont ceux du '
  'parcours normal.';

-- ── 2. Le reçu doit pouvoir porter un courriel saisi à la main ────────────
-- `app.emettre_recu` lit le courriel dans `auth.users`. Un candidat sans
-- compte n'y est pas : `payment_receipts.student_email` resterait NULL, et
-- c'est PRÉCISÉMENT la colonne que lira l'envoi par courriel demandé par
-- Jocelyn. Plutôt que de dupliquer la construction du reçu -- ce que ce
-- fichier s'interdit -- on ajoute un paramètre de repli à la fonction
-- existante. Une seule ligne du corps change ; elle est signalée.
--
-- Il faut SUPPRIMER l'ancienne signature avant de créer la nouvelle : avec un
-- quatrième paramètre à valeur par défaut, les deux coexisteraient et tout
-- appel à trois arguments deviendrait ambigu. Les trois appelants
-- (`app_admin_confirm_payment`, `app_confirm_credit_purchase`,
-- `app_confirm_ligdicash_payment`) n'en passent qu'un ou deux : ils sont
-- inchangés.
DROP FUNCTION IF EXISTS app.emettre_recu(UUID, UUID, JSONB);

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

  SELECT s.full_name, s.phone, s.city, s.country
    INTO v_nom, v_tel, v_ville, v_pays
  FROM app.students s WHERE s.id = v_p.student_id;

  SELECT u.email INTO v_email FROM auth.users u WHERE u.id = v_p.student_id;

  -- ── LA SEULE LIGNE AJOUTÉE LE 10/09 ────────────────────────────────────
  -- Le compte fait foi quand il existe ; le courriel saisi ne sert que
  -- lorsqu'il n'y a pas de compte. Dans cet ordre, une saisie manuelle ne
  -- peut pas écraser l'adresse authentifiée d'un étudiant réel.
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

-- ── 3. La saisie au comptoir ──────────────────────────────────────────────
-- Elle fabrique, dans cet ordre, ce que le parcours normal fabrique :
--   fiche candidat  ->  candidature acceptée AVEC SON TAUX  ->  paiement
--   confirmé  ->  reçu  ->  bon de courtage.
--
-- L'ORDRE N'EST PAS DÉCORATIF. Le verrou du 09/09 refuse d'encaisser un
-- courtage tant que `applications.discount_rate` est NULL ; `app.emettre_bon`
-- refuse d'émettre pour la même raison. Poser le taux AVANT le paiement, c'est
-- respecter le verrou au lieu de le contourner -- et c'est pour ça que le
-- paramètre du taux est OBLIGATOIRE ici, sans valeur par défaut.
CREATE OR REPLACE FUNCTION public.app_admin_emettre_documents_manuels(
  p_nom            TEXT,
  p_program_id     UUID,
  p_taux           NUMERIC,
  p_telephone      TEXT    DEFAULT NULL,
  p_email          TEXT    DEFAULT NULL,
  p_ville          TEXT    DEFAULT NULL,
  p_pays           TEXT    DEFAULT 'Burkina Faso',
  p_date_naissance DATE    DEFAULT NULL,
  p_montant        NUMERIC DEFAULT NULL,
  p_canal          TEXT    DEFAULT 'cash',
  p_reference      TEXT    DEFAULT NULL,
  p_note           TEXT    DEFAULT NULL,
  p_mode_etude     TEXT    DEFAULT NULL,
  p_student_id     UUID    DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_admin      UUID := auth.uid();
  v_nom        TEXT := NULLIF(TRIM(p_nom), '');
  v_prog       RECORD;
  v_canal      public.payment_channel;
  v_montant    NUMERIC;
  v_student    UUID;
  v_nouveau    BOOLEAN := FALSE;
  v_app_id     UUID;
  v_pay_id     UUID;
  v_reference  TEXT;
  v_recu       JSONB;
  v_bon        JSONB;
BEGIN
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;

  -- Le rôle se lit dans `raw_app_meta_data`, que l'utilisateur ne peut pas
  -- écrire -- contrairement à `raw_user_meta_data`. Garde posée le 03/09.
  IF COALESCE((SELECT raw_app_meta_data->>'role' FROM auth.users WHERE id = v_admin), '')
     <> 'admin' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_admin');
  END IF;

  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'nom_manquant');
  END IF;

  IF p_taux IS NULL OR p_taux < 0 OR p_taux > 100 THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'taux_invalide',
      'message', 'Le pourcentage négocié est obligatoire, et compris entre 0 et 100.');
  END IF;

  SELECT pr.id, pr.title, pr.university_id, pr.brokerage_fee
    INTO v_prog
  FROM app.programs pr WHERE pr.id = p_program_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'formation_introuvable');
  END IF;
  IF v_prog.university_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'programme_sans_etablissement');
  END IF;

  -- Le montant par défaut est CELUI DU PROGRAMME, comme dans le parcours
  -- normal où l'appelant ne choisit rien. Une valeur explicite reste possible
  -- -- au comptoir, un règlement partiel ou négocié existe -- mais elle est
  -- alors tracée dans le journal d'audit ci-dessous.
  v_montant := COALESCE(NULLIF(p_montant, 0), v_prog.brokerage_fee);
  IF v_montant IS NULL OR v_montant <= 0 THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'montant_indeterminable',
      'message', 'Cette formation n''a pas de frais de courtage défini : '
              || 'saisir le montant encaissé.');
  END IF;

  BEGIN
    v_canal := COALESCE(NULLIF(TRIM(p_canal), ''), 'cash')::public.payment_channel;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'canal_invalide');
  END;

  -- ── La fiche du candidat ────────────────────────────────────────────────
  IF p_student_id IS NOT NULL THEN
    SELECT id INTO v_student FROM app.students WHERE id = p_student_id;
    IF v_student IS NULL THEN
      RETURN jsonb_build_object('success', FALSE, 'error', 'candidat_introuvable');
    END IF;
  ELSE
    v_student := gen_random_uuid();
    v_nouveau := TRUE;
    INSERT INTO app.students (id, full_name, phone, city, country, date_of_birth,
                              manual_entry_by, manual_entry_at)
    VALUES (v_student, v_nom,
            NULLIF(TRIM(p_telephone), ''),
            NULLIF(TRIM(p_ville), ''),
            COALESCE(NULLIF(TRIM(p_pays), ''), 'Burkina Faso'),
            p_date_naissance,
            v_admin, NOW());
  END IF;

  -- ── La candidature, acceptée et TAUX POSÉ ───────────────────────────────
  INSERT INTO app.applications (
    student_id, program_id, status, submitted_at,
    requested_study_mode, discount_requested, discount_rate,
    discount_validated_at, discount_validated_by, discount_details,
    sent_to_university, sent_to_university_at)
  VALUES (
    v_student, v_prog.id, 'accepted', NOW(),
    NULLIF(TRIM(p_mode_etude), ''), TRUE, p_taux,
    NOW(), v_admin, NULLIF(TRIM(p_note), ''),
    TRUE, NOW())
  RETURNING id INTO v_app_id;

  -- ── Le paiement, déjà encaissé HORS PLATEFORME ──────────────────────────
  -- Même forme de référence que le parcours normal : au guichet, personne ne
  -- doit avoir à savoir par où le dossier est passé.
  v_reference := 'AP-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' ||
                 SUBSTR(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6);

  INSERT INTO app.application_payments (
    application_id, student_id, university_id, amount_due, amount_paid,
    currency, payment_reason, channel, status, reference_code,
    external_reference, payment_method, phone_number,
    declared_at, confirmed_at, confirmed_by, created_by)
  VALUES (
    v_app_id, v_student, v_prog.university_id, v_montant, v_montant,
    'XOF', 'application_fee'::public.payment_reason, v_canal,
    'confirmed'::public.payment_status, v_reference,
    NULLIF(TRIM(p_reference), ''), 'manual', NULLIF(TRIM(p_telephone), ''),
    NOW(), NOW(), v_admin, v_admin)
  RETURNING id INTO v_pay_id;

  -- ── Les deux documents, par les fonctions du parcours normal ────────────
  v_recu := app.emettre_recu(v_pay_id, v_admin, NULL, p_email);
  IF COALESCE((v_recu->>'success')::boolean, FALSE) IS NOT TRUE THEN
    RAISE EXCEPTION 'emission_recu_refusee: %', COALESCE(v_recu->>'error', 'inconnu');
  END IF;

  v_bon := app.emettre_bon(v_pay_id, v_admin, 'saisie_manuelle');
  IF COALESCE((v_bon->>'success')::boolean, FALSE) IS NOT TRUE THEN
    RAISE EXCEPTION 'emission_bon_refusee: %', COALESCE(v_bon->>'error', 'inconnu');
  END IF;

  INSERT INTO app.admin_audit_log (admin_id, action_type, target_type, target_id,
                                   target_user_id, details)
  VALUES (v_admin, 'emettre_documents_manuels', 'application', v_app_id::text,
          v_student,
          jsonb_build_object(
            'candidat', v_nom, 'fiche_creee', v_nouveau,
            'formation', v_prog.title, 'universite_id', v_prog.university_id,
            'taux', p_taux,
            'montant', v_montant,
            'montant_impose_par_le_programme', v_prog.brokerage_fee,
            'montant_saisi', p_montant,
            'canal', v_canal::text,
            'reference_externe', NULLIF(TRIM(p_reference), ''),
            'recu', v_recu->>'receipt_number',
            'bon', v_bon->>'voucher_number'));

  RETURN jsonb_build_object(
    'success', TRUE,
    'student_id', v_student,
    'fiche_creee', v_nouveau,
    'application_id', v_app_id,
    'payment_id', v_pay_id,
    'montant', v_montant,
    'taux', p_taux,
    'receipt_id', v_recu->>'receipt_id',
    'receipt_number', v_recu->>'receipt_number',
    'voucher_id', v_bon->>'voucher_id',
    'voucher_number', v_bon->>'voucher_number',
    'verification_code', v_bon->>'verification_code',
    'expire_le', v_bon->>'expire_le');
END;
$function$;

REVOKE ALL ON FUNCTION public.app_admin_emettre_documents_manuels(
  TEXT, UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, DATE, NUMERIC, TEXT, TEXT, TEXT, TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_admin_emettre_documents_manuels(
  TEXT, UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, DATE, NUMERIC, TEXT, TEXT, TEXT, TEXT, UUID) TO authenticated;

COMMENT ON FUNCTION public.app_admin_emettre_documents_manuels(
  TEXT, UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, DATE, NUMERIC, TEXT, TEXT, TEXT, TEXT, UUID) IS
  'Saisie au comptoir pour une personne sans compte. Fabrique les mêmes lignes '
  'que le parcours étudiant, puis appelle app.emettre_recu et app.emettre_bon. '
  'Le bon produit se vérifie, se consomme et se transfère exactement comme un '
  'bon issu du parcours normal ; seul app.brokerage_vouchers.origin le '
  'distingue.';

-- ── 4. Voir ce qui est passé par le comptoir ──────────────────────────────
-- Un dispositif manuel sans compteur devient une zone d'ombre. La file de
-- courriels l'a montré : 3 entrées en attente depuis juillet, découvertes en
-- septembre parce que rien ne les affichait.
CREATE OR REPLACE VIEW app.saisies_manuelles AS
SELECT s.id                AS student_id,
       s.full_name         AS candidat,
       s.manual_entry_at   AS saisi_le,
       s.manual_entry_by   AS saisi_par,
       a.id                AS application_id,
       a.discount_rate     AS taux,
       pr.title            AS formation,
       u.name              AS universite,
       p.id                AS payment_id,
       p.amount_paid       AS montant,
       r.receipt_number    AS recu,
       b.voucher_number    AS bon,
       b.transferred_at    AS transmis_le,
       b.consumed_at       AS consomme_le
FROM app.students s
JOIN app.applications a          ON a.student_id = s.id
JOIN app.programs pr             ON pr.id = a.program_id
LEFT JOIN app.universities u     ON u.id = pr.university_id
LEFT JOIN app.application_payments p ON p.application_id = a.id
LEFT JOIN app.payment_receipts r ON r.payment_id = p.id
LEFT JOIN app.brokerage_vouchers b ON b.payment_id = p.id
WHERE s.manual_entry_by IS NOT NULL;

COMMENT ON VIEW app.saisies_manuelles IS
  'Dossiers ouverts au comptoir par un administrateur, avec les documents '
  'qu''ils ont produits. À rapprocher de app.brokerage_vouchers WHERE '
  'origin = ''saisie_manuelle''.';
