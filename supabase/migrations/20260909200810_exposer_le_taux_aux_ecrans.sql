-- Le taux doit arriver jusqu'aux écrans, sinon le verrou est muet.
--
-- POURQUOI. `app_create_application_payment` refuse désormais un paiement de
-- courtage tant que `applications.discount_rate` est NULL. Mais les deux écrans
-- qui doivent en parler ne reçoivent pas ce champ :
--   * l'écran ADMINISTRATEUR ne peut ni afficher le taux en vigueur ni montrer
--     qu'il manque -- donc l'administrateur ne sait pas qu'il bloque quelqu'un ;
--   * l'écran ÉTUDIANT ne peut pas expliquer pourquoi le paiement est fermé,
--     et un refus sans motif se lit comme une panne.
-- Mesure du 09/09 : les deux RPC exposent `discount_details` (le texte libre)
-- et PAS `discount_rate`.
--
-- POURQUOI PAR RÉÉCRITURE PLUTÔT QU'À LA MAIN. Ces deux fonctions font ~3 000
-- caractères chacune. Les recopier pour ajouter deux clés, c'est prendre le
-- risque d'en perdre une ligne au passage. On lit donc la définition en place,
-- on insère les deux clés après un motif VÉRIFIÉ unique, et on réexécute. Les
-- gardes ci-dessous refusent d'agir si le motif n'est pas là où on le croit.
--
-- CE QUI N'EST PAS TOUCHÉ, ET C'EST VOULU. `app_list_university_applications`
-- et `app_get_university_application_detail` exposent aussi la négociation,
-- mais l'université n'a pas à connaître le taux par cette voie : elle le lit
-- sur le BON DE COURTAGE, qu'elle vérifie par son code. C'est le canal prévu
-- par la maquette validée le 02/09, et le seul qui prouve quelque chose.

DO $$
DECLARE
  v_nom     TEXT;
  v_source  TEXT;
  v_nouveau TEXT;
  v_motif   TEXT := '''discount_details'', a.discount_details';
BEGIN
  FOREACH v_nom IN ARRAY ARRAY['app_list_admin_applications',
                               'app_list_student_applications'] LOOP

    SELECT pg_get_functiondef(p.oid) INTO v_source
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_nom;

    IF v_source IS NULL THEN
      RAISE EXCEPTION 'Fonction % introuvable : rien n''est modifié.', v_nom;
    END IF;

    -- Idempotent : rejouer la migration ne duplique pas les clés.
    IF position('discount_rate' IN v_source) > 0 THEN
      RAISE NOTICE '% porte déjà le taux, ignorée.', v_nom;
      CONTINUE;
    END IF;

    -- On refuse d'agir à l'aveugle : le motif doit être là, et une seule fois.
    IF (length(v_source) - length(replace(v_source, v_motif, '')))
       / length(v_motif) <> 1 THEN
      RAISE EXCEPTION 'Motif absent ou multiple dans % : rien n''est modifié.', v_nom;
    END IF;

    v_nouveau := replace(
      v_source,
      v_motif,
      v_motif || ',' || chr(10) ||
      '                ''discount_rate'', a.discount_rate,' || chr(10) ||
      '                ''discount_validated_at'', a.discount_validated_at'
    );

    EXECUTE v_nouveau;
    RAISE NOTICE '% : taux exposé.', v_nom;
  END LOOP;
END $$;
