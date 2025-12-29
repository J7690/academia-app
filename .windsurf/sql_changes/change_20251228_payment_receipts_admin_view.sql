-- ========================================
-- ACADEMIA - PAYMENTS PHASE 2 (ADMIN RECEIPTS VIEW)
-- RPC pour lister les reçus de paiement avec contexte complet côté admin.
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

CREATE OR REPLACE FUNCTION app_admin_list_payment_receipts_with_context()
RETURNS SETOF JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'admin' THEN
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
    'reference_code', p.reference_code,
    'external_reference', p.external_reference,
    'student_id', p.student_id,
    'application_id', p.application_id,
    'university_id', p.university_id,
    'program_id', a.program_id,
    'program_title', prog.title,
    'university_name', u.name,
    'snapshot', r.snapshot
  )
  FROM app.payment_receipts r
  JOIN app.application_payments p ON p.id = r.payment_id
  LEFT JOIN app.applications a ON a.id = p.application_id
  LEFT JOIN app.programs prog ON prog.id = a.program_id
  LEFT JOIN app.universities u ON u.id = prog.university_id
  ORDER BY r.issued_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_list_payment_receipts_with_context() TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_list_payment_receipts_with_context() TO service_role;
