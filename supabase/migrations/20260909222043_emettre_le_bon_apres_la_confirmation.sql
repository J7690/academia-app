-- Le bon de courtage suit le paiement, automatiquement.
--
-- OÙ. Juste APRÈS l'émission du reçu, donc APRÈS le passage du paiement à
-- `confirmed`. L'ordre compte : le 02/09, le reçu écrit avant la confirmation
-- avait une empreinte fausse dès la ligne suivante.
--
-- SEULEMENT DEUX DES TROIS CHEMINS. `app_confirm_credit_purchase` ne concerne
-- pas le courtage. `app.emettre_bon` refuse de toute façon tout autre motif
-- (`motif_non_courtage`) : le garde-fou est donc double.
--
-- POURQUOI L'EXCEPTION EST RATTRAPÉE. Si l'émission du bon échouait et
-- remontait, elle annulerait LA CONFIRMATION DU PAIEMENT : l'étudiant perdrait
-- son argent ET son bon. C'est exactement le raisonnement qui a fait préférer
-- des vues à un déclencheur pour les reçus, le 02/09. On dégrade donc, mais on
-- ne se tait pas : l'échec est inscrit dans le registre des vérifications, et
-- `app.courtages_sans_bon` le montre. Une exception avalée en silence est le
-- défaut recensé sept fois dans ce dépôt.
--
-- POURQUOI PAR RÉÉCRITURE ET NON À LA MAIN. Ces deux fonctions font plusieurs
-- milliers de caractères. Les recopier pour ajouter six lignes, c'est prendre
-- le risque d'en perdre une au passage. On lit la définition en place, on
-- insère après un motif VÉRIFIÉ unique, et on réexécute. Le bloc refuse d'agir
-- si le motif n'est pas là où on le croit, et il est idempotent.

DO $$
DECLARE
  v_source  TEXT;
  v_nouveau TEXT;
  v_motif   TEXT;
  v_ajout   TEXT;
BEGIN
  -- ── 1. La confirmation par l'administrateur ──────────────────────────────
  SELECT pg_get_functiondef(p.oid) INTO v_source
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'app_admin_confirm_payment';
  IF v_source IS NULL THEN
    RAISE EXCEPTION 'app_admin_confirm_payment introuvable.';
  END IF;

  IF position('emettre_bon' IN v_source) = 0 THEN
    v_motif := '  v_recu := app.emettre_recu(p_payment_id, v_user_id);';
    IF (length(v_source) - length(replace(v_source, v_motif, ''))) / length(v_motif) <> 1 THEN
      RAISE EXCEPTION 'Motif absent ou multiple dans app_admin_confirm_payment.';
    END IF;
    v_ajout := v_motif || chr(10) || chr(10) ||
      '  BEGIN' || chr(10) ||
      '    PERFORM app.emettre_bon(p_payment_id, v_user_id, ''automatique'');' || chr(10) ||
      '  EXCEPTION WHEN OTHERS THEN' || chr(10) ||
      '    INSERT INTO app.brokerage_voucher_checks (voucher_number, checked_by, resultat)' || chr(10) ||
      '    VALUES (''(emission)'', v_user_id, ''echec_emission: '' || SQLERRM);' || chr(10) ||
      '  END;';
    v_nouveau := replace(v_source, v_motif, v_ajout);
    EXECUTE v_nouveau;
    RAISE NOTICE 'app_admin_confirm_payment : emission du bon branchee.';
  ELSE
    RAISE NOTICE 'app_admin_confirm_payment : deja branchee.';
  END IF;

  -- ── 2. La confirmation LigdiCash ─────────────────────────────────────────
  SELECT pg_get_functiondef(p.oid) INTO v_source
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'app_confirm_ligdicash_payment';
  IF v_source IS NULL THEN
    RAISE EXCEPTION 'app_confirm_ligdicash_payment introuvable.';
  END IF;

  IF position('emettre_bon' IN v_source) = 0 THEN
    v_motif := '      JSONB_BUILD_OBJECT(''rapprochement'', v_rappro));';
    IF (length(v_source) - length(replace(v_source, v_motif, ''))) / length(v_motif) <> 1 THEN
      RAISE EXCEPTION 'Motif absent ou multiple dans app_confirm_ligdicash_payment.';
    END IF;
    v_ajout := v_motif || chr(10) || chr(10) ||
      '    BEGIN' || chr(10) ||
      '      PERFORM app.emettre_bon(p_payment_id,' || chr(10) ||
      '        COALESCE(auth.uid(), v_payment.student_id), ''automatique'');' || chr(10) ||
      '    EXCEPTION WHEN OTHERS THEN' || chr(10) ||
      '      INSERT INTO app.brokerage_voucher_checks (voucher_number, checked_by, resultat)' || chr(10) ||
      '      VALUES (''(emission)'', v_payment.student_id, ''echec_emission: '' || SQLERRM);' || chr(10) ||
      '    END;';
    v_nouveau := replace(v_source, v_motif, v_ajout);
    EXECUTE v_nouveau;
    RAISE NOTICE 'app_confirm_ligdicash_payment : emission du bon branchee.';
  ELSE
    RAISE NOTICE 'app_confirm_ligdicash_payment : deja branchee.';
  END IF;
END $$;
