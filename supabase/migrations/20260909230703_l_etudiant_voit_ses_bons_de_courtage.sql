-- L'étudiant lit SES bons, et rien d'autre.
--
-- POURQUOI UNE FONCTION PLUTÔT QU'UNE POLITIQUE RLS. `app.brokerage_vouchers`
-- a RLS active et AUCUNE politique : la table ne se lit que par des fonctions
-- SECURITY DEFINER. C'est le choix déjà fait pour les reçus le 02/09, et il
-- tient pour la même raison : le bon porte le secret qui permet de le
-- vérifier. Une politique de lecture, même juste, exposerait la table entière
-- à la moindre erreur de jointure PostgREST ; une fonction ne rend que ce
-- qu'on lui a fait rendre.
--
-- L'ÉTUDIANT VOIT SON JETON DE SCAN, ET C'EST NORMAL : c'est lui qui détient
-- le document. Le jeton sert à fabriquer le QR de son propre bon. Ce qu'il ne
-- doit pas pouvoir faire, c'est lire le bon d'un autre — d'où le filtre sur
-- `student_id`, pris sur `auth.uid()` et JAMAIS sur un paramètre.
--
-- ÉPROUVÉ LE 09/09 avec trois sessions réelles : le propriétaire voit ses deux
-- bons avec leur jeton, un autre étudiant en voit zéro, une université en voit
-- zéro.

CREATE OR REPLACE FUNCTION public.app_list_my_brokerage_vouchers()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user UUID := auth.uid();
  v_bons JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT COALESCE(jsonb_agg(t ORDER BY t.issued_at DESC), '[]'::jsonb)
    INTO v_bons
  FROM (
    SELECT b.id,
           b.voucher_number,
           b.verification_code,
           b.scan_token,
           b.issued_at,
           b.expires_at,
           b.consumed_at,
           b.signature_hash,
           b.origin,
           b.snapshot,
           (b.expires_at < NOW()) AS expire,
           u.name AS universite
    FROM app.brokerage_vouchers b
    JOIN app.application_payments p ON p.id = b.payment_id
    LEFT JOIN app.universities u ON u.id = b.destination_university_id
    WHERE p.student_id = v_user
  ) t;

  RETURN jsonb_build_object('success', TRUE, 'vouchers', v_bons);
END;
$function$;

REVOKE ALL ON FUNCTION public.app_list_my_brokerage_vouchers() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_list_my_brokerage_vouchers() TO authenticated;
