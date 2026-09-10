-- Les trois documents d'un paiement, en un seul appel.
--
-- POURQUOI. Après une saisie au comptoir, l'administrateur doit pouvoir
-- imprimer TOUT DE SUITE le reçu et le bon. Les deux fabriques de PDF côté
-- Flutter attendent des objets précis :
--
--   `construirePdfRecu(payment:, receipt:)`  lit `receipt['snapshot']` d'abord,
--       et retombe sur `payment['program_title']`, `payment['university_name']`,
--       `payment['channel']`… quand l'instantané ne dit rien ;
--   `construirePdfBonCourtage(bon:)`          lit la forme rendue par
--       `app_admin_list_brokerage_vouchers` -- snapshot, scan_token, universite.
--
-- Sans cette fonction, l'écran devrait recharger la liste complète des
-- paiements ET celle des bons pour retrouver deux lignes qu'il vient de créer.
-- Elle sert aussi à réimprimer un document plus tard : c'est le même geste.
--
-- CE QU'ELLE NE FAIT PAS : elle ne crée rien, ne modifie rien, et refuse tout
-- appelant qui n'est pas administrateur. Le jeton de scan en fait partie --
-- c'est ce que porte le QR -- et c'est justement pourquoi elle est réservée.
CREATE OR REPLACE FUNCTION public.app_admin_documents_du_paiement(p_payment_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'app', 'pg_temp'
AS $function$
DECLARE
  v_user    UUID := auth.uid();
  v_paiement JSONB;
  v_recu     JSONB;
  v_bon      JSONB;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_authenticated');
  END IF;
  IF COALESCE((SELECT raw_app_meta_data->>'role' FROM auth.users WHERE id = v_user), '')
     <> 'admin' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'not_admin');
  END IF;

  -- Mêmes clés que `app_admin_list_payments_with_context`, pour que l'écran
  -- n'ait pas deux formes de « paiement » à connaître.
  SELECT jsonb_build_object(
           'id', p.id,
           'application_id', p.application_id,
           'student_id', p.student_id,
           'university_id', p.university_id,
           'amount_due', p.amount_due,
           'amount_paid', p.amount_paid,
           'currency', p.currency,
           'payment_reason', p.payment_reason,
           'status', p.status,
           'channel', p.channel,
           'payment_method', p.payment_method,
           'ligdicash_operator', p.ligdicash_operator,
           'reference_code', p.reference_code,
           'external_reference', p.external_reference,
           'created_at', p.created_at,
           'declared_at', p.declared_at,
           'confirmed_at', p.confirmed_at,
           'program_id', a.program_id,
           'program_title', prog.title,
           'university_name', u.name)
    INTO v_paiement
  FROM app.application_payments p
  LEFT JOIN app.applications a  ON a.id = p.application_id
  LEFT JOIN app.programs prog   ON prog.id = a.program_id
  LEFT JOIN app.universities u  ON u.id = prog.university_id
  WHERE p.id = p_payment_id;

  IF v_paiement IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'paiement_introuvable');
  END IF;

  SELECT jsonb_build_object(
           'id', r.id, 'receipt_number', r.receipt_number,
           'issued_at', r.issued_at, 'snapshot', r.snapshot,
           'student_name', r.student_name, 'student_phone', r.student_phone,
           'student_email', r.student_email, 'training_name', r.training_name,
           'credit_pack_name', r.credit_pack_name,
           'signature_hash', r.signature_hash)
    INTO v_recu
  FROM app.payment_receipts r WHERE r.payment_id = p_payment_id;

  -- Même forme que `app_admin_list_brokerage_vouchers` : une seule lecture à
  -- apprendre côté Flutter, et le générateur de PDF ne change pas.
  SELECT jsonb_build_object(
           'id', b.id, 'voucher_number', b.voucher_number,
           'verification_code', b.verification_code, 'scan_token', b.scan_token,
           'issued_at', b.issued_at, 'expires_at', b.expires_at,
           'consumed_at', b.consumed_at, 'transferred_at', b.transferred_at,
           'signature_hash', b.signature_hash, 'origin', b.origin,
           'snapshot', b.snapshot,
           'expire', (b.expires_at < NOW()),
           'universite', u.name,
           'etudiant', s.full_name)
    INTO v_bon
  FROM app.brokerage_vouchers b
  LEFT JOIN app.universities u ON u.id = b.destination_university_id
  LEFT JOIN app.students s     ON s.id = (SELECT student_id FROM app.application_payments
                                          WHERE id = b.payment_id)
  WHERE b.payment_id = p_payment_id;

  RETURN jsonb_build_object('success', TRUE,
                            'payment', v_paiement,
                            'receipt', v_recu,
                            'voucher', v_bon);
END;
$function$;

REVOKE ALL ON FUNCTION public.app_admin_documents_du_paiement(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_admin_documents_du_paiement(UUID) TO authenticated;
