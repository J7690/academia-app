-- La copie qu'un administrateur télécharge doit valoir celle de l'étudiant.
--
-- CE QUI CLOCHAIT, MESURÉ LE 10/09. `app_admin_list_payment_receipts_with_context`
-- rendait l'instantané du reçu mais PAS ses colonnes de repli :
-- `signature_hash`, `student_name`, `student_phone`, `student_email`,
-- `training_name`, `credit_pack_name`. Or `construirePdfRecu` n'imprime le
-- bloc « L'empreinte ci-dessous permet de vérifier que ce document n'a pas été
-- modifié » que si `receipt['signature_hash']` est non vide, et retombe sur
-- `receipt['student_name']` quand l'instantané ne nomme pas le payeur.
--
-- Conséquence concrète : la copie de l'administrateur sortait SANS empreinte de
-- vérification, et sur les 18 reçus de production -- tous antérieurs à
-- l'instantané version 2, tous avec `student_name` NULL -- sans le nom du
-- payeur non plus. Deux documents différents pour un même reçu, selon qui le
-- télécharge. C'est exactement ce que Jocelyn demande d'éviter en voulant que
-- l'administrateur « puisse les télécharger » lui aussi.
--
-- LE COALESCE SUR LE NOM EST UNE RÉPARATION, ET IL FAUT LA CONNAÎTRE. Pour les
-- 18 reçus anciens, `r.student_name` est NULL : le nom vient alors de
-- `app.students`, lu au moment de la lecture. Deux téléchargements espacés
-- d'un an peuvent donc porter deux noms si la personne modifie son profil. Le
-- repli ne se déclenche JAMAIS sur un reçu récent, dont la colonne est
-- remplie à l'émission et figée. Sans lui, ces 18 documents nomment leur
-- payeur « Étudiant Academia » -- un reçu qui ne nomme personne ne prouve rien
-- à celui qui le détient. Mesure après correction : 18 reçus, 0 sans nom.
--
-- CE QUE ÇA NE RÉPARE PAS : ces 18 reçus n'ont pas non plus d'empreinte
-- (`signature_hash` NULL sur 18/18), et aucune lecture ne peut l'inventer. La
-- recalculer et l'écrire suppose de lever le déclencheur `payment_receipts_no_update`
-- qui interdit toute modification d'un reçu émis. C'est une décision, pas un
-- détail : elle revient à Jocelyn.
--
-- UNE SEULE SOURCE POUR « QUI EST ADMINISTRATEUR ». Cette fonction lisait
-- `raw_user_meta_data->>'role'` ; celles des bons lisent `raw_app_meta_data`.
-- Les deux familles se rejoignent aujourd'hui parce que les 7 comptes admin
-- portent la valeur dans les deux champs -- vérifié, pas supposé -- mais un
-- compte créé par un chemin qui n'alimente qu'un seul des deux verrait un
-- onglet répondre `not_admin` et l'autre fonctionner. On lit désormais
-- `raw_app_meta_data` en premier, qui est la source de confiance (le titulaire
-- ne peut pas l'écrire), avec `raw_user_meta_data` en repli pour ne casser
-- aucun compte existant.

CREATE OR REPLACE FUNCTION public.app_admin_list_payment_receipts_with_context()
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT COALESCE(raw_app_meta_data->>'role', raw_user_meta_data->>'role')
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF COALESCE(v_role, '') NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'not_admin';
  END IF;

  RETURN QUERY
  SELECT JSONB_BUILD_OBJECT(
    'receipt_id', r.id,
    'receipt_number', r.receipt_number,
    'issued_at', r.issued_at,
    'issued_by', r.issued_by,
    'payment_id', r.payment_id,
    'payment_status', p.status,
    'amount_due', p.amount_due,
    'amount_paid', p.amount_paid,
    'currency', p.currency,
    'payment_reason', p.payment_reason,
    'channel', p.channel,
    'payment_method', p.payment_method,
    'ligdicash_operator', p.ligdicash_operator,
    'confirmed_at', p.confirmed_at,
    'declared_at', p.declared_at,
    'created_at', p.created_at,
    'reference_code', p.reference_code,
    'external_reference', p.external_reference,
    'ligdicash_transaction_id', p.ligdicash_transaction_id,
    'student_id', p.student_id,
    'application_id', p.application_id,
    'university_id', p.university_id,
    'program_id', a.program_id,
    'program_title', prog.title,
    'university_name', u.name,
    'snapshot', r.snapshot,
    -- LES SIX COLONNES AJOUTEES LE 10/09 : ce sont exactement celles dont le
    -- generateur de PDF a besoin quand l'instantane est muet.
    'signature_hash', r.signature_hash,
    'student_name', COALESCE(r.student_name, s.full_name),
    'student_phone', COALESCE(r.student_phone, s.phone),
    'student_email', COALESCE(r.student_email, au.email),
    'training_name', r.training_name,
    'credit_pack_name', r.credit_pack_name
  )
  FROM app.payment_receipts r
  JOIN app.application_payments p ON p.id = r.payment_id
  LEFT JOIN app.applications a  ON a.id = p.application_id
  LEFT JOIN app.programs prog   ON prog.id = a.program_id
  LEFT JOIN app.universities u  ON u.id = prog.university_id
  LEFT JOIN app.students s      ON s.id = p.student_id
  LEFT JOIN auth.users au       ON au.id = p.student_id
  ORDER BY r.issued_at DESC;
END;
$function$;

REVOKE ALL ON FUNCTION public.app_admin_list_payment_receipts_with_context() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_admin_list_payment_receipts_with_context() TO authenticated;
