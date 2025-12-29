-- ========================================
-- ACADEMIA - PAYMENTS PHASE 2 (DETAIL & HISTORY VIEW)
-- Add declared_at column and admin RPC to fetch full payment detail
-- ========================================

CREATE SCHEMA IF NOT EXISTS app;

ALTER TABLE app.application_payments
  ADD COLUMN IF NOT EXISTS declared_at TIMESTAMPTZ;

UPDATE app.application_payments
SET declared_at = COALESCE(declared_at, updated_at, created_at)
WHERE status IN ('declared_by_student', 'under_verification', 'confirmed', 'rejected', 'cancelled')
  AND declared_at IS NULL;

CREATE OR REPLACE FUNCTION app_admin_get_payment_detail(
  p_payment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_result JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  IF p_payment_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_payment_id');
  END IF;

  SELECT JSONB_BUILD_OBJECT(
    'payment', JSONB_BUILD_OBJECT(
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
      'reference_code', p.reference_code,
      'external_reference', p.external_reference,
      'student_note', p.student_note,
      'created_at', p.created_at,
      'updated_at', p.updated_at,
      'declared_at', p.declared_at,
      'verified_at', p.verified_at,
      'confirmed_at', p.confirmed_at,
      'created_by', p.created_by,
      'verified_by', p.verified_by,
      'confirmed_by', p.confirmed_by,
      'program_id', a.program_id,
      'program_title', prog.title,
      'university_name', u.name
    ),
    'receipts', COALESCE((
      SELECT JSONB_AGG(
               JSONB_BUILD_OBJECT(
                 'receipt_id', r.id,
                 'receipt_number', r.receipt_number,
                 'issued_at', r.issued_at,
                 'issued_by', r.issued_by,
                 'snapshot', r.snapshot
               )
               ORDER BY r.issued_at
             )
      FROM app.payment_receipts r
      WHERE r.payment_id = p.id
    ), '[]'::JSONB),
    'proofs', COALESCE((
      SELECT JSONB_AGG(
               JSONB_BUILD_OBJECT(
                 'id', pr.id,
                 'proof_type', pr.proof_type,
                 'file_path', pr.file_path,
                 'uploaded_at', pr.uploaded_at,
                 'uploaded_by', pr.uploaded_by,
                 'note', pr.note
               )
               ORDER BY pr.uploaded_at
             )
      FROM app.payment_proofs pr
      WHERE pr.payment_id = p.id
    ), '[]'::JSONB)
  )
  INTO v_result
  FROM app.application_payments p
  LEFT JOIN app.applications a ON a.id = p.application_id
  LEFT JOIN app.programs prog ON prog.id = a.program_id
  LEFT JOIN app.universities u ON u.id = prog.university_id
  WHERE p.id = p_payment_id;

  IF v_result IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'payment_not_found');
  END IF;

  RETURN JSONB_BUILD_OBJECT('success', TRUE) || v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_get_payment_detail(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_get_payment_detail(UUID) TO service_role;
