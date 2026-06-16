import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql(query):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": query})
    j = r.json()
    print(f"  -> ok={j.get('ok')} rows={j.get('affected_rows',0)}")
    return j

print("=" * 70)
print("F1: Deploy finance RPCs")
print("=" * 70)

# ─── RPC 1: app_admin_finance_overview ───
print("\n### 1. app_admin_finance_overview ###")
sql("""
CREATE OR REPLACE FUNCTION public.app_admin_finance_overview()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_total_payin NUMERIC;
  v_total_payout NUMERIC;
  v_month_payin NUMERIC;
  v_month_payout NUMERIC;
  v_month_payin_count INT;
  v_month_payout_count INT;
  v_pending_amount NUMERIC;
  v_pending_count INT;
  v_processing_count INT;
  v_completed_month INT;
  v_failed_month INT;
  v_payout_success_rate NUMERIC;
  v_by_reason JSONB;
  v_by_payout_actor JSONB;
  v_chart JSONB;
  v_active_subs INT;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_uid;
  IF v_role <> 'admin' THEN RETURN jsonb_build_object('success', false, 'error', 'not_admin'); END IF;

  -- Totals all time
  SELECT COALESCE(SUM(amount_paid),0) INTO v_total_payin FROM app.application_payments WHERE status='confirmed';
  SELECT COALESCE(SUM(amount),0) INTO v_total_payout FROM app.payout_queue WHERE status='completed';

  -- Month payin
  SELECT COALESCE(SUM(amount_paid),0), COUNT(*) INTO v_month_payin, v_month_payin_count
  FROM app.application_payments WHERE status='confirmed' AND confirmed_at >= date_trunc('month', NOW());

  -- Month payout
  SELECT COALESCE(SUM(amount),0), COUNT(*) INTO v_month_payout, v_month_payout_count
  FROM app.payout_queue WHERE status='completed' AND processed_at >= date_trunc('month', NOW());

  -- Pending payouts
  SELECT COALESCE(SUM(amount),0), COUNT(*) INTO v_pending_amount, v_pending_count
  FROM app.payout_queue WHERE status='pending';

  SELECT COUNT(*) INTO v_processing_count FROM app.payout_queue WHERE status='processing';

  -- Completed + failed this month
  SELECT COUNT(*) INTO v_completed_month FROM app.payout_queue
  WHERE status='completed' AND processed_at >= date_trunc('month', NOW());

  SELECT COUNT(*) INTO v_failed_month FROM app.payout_queue
  WHERE status='failed' AND created_at >= date_trunc('month', NOW());

  -- Success rate
  IF (v_completed_month + v_failed_month) > 0 THEN
    v_payout_success_rate := ROUND(v_completed_month::numeric / (v_completed_month + v_failed_month) * 100, 1);
  ELSE
    v_payout_success_rate := 100;
  END IF;

  -- By payment_reason (donut data)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'reason', payment_reason, 'amount', total, 'count', cnt
  )), '[]'::jsonb) INTO v_by_reason
  FROM (
    SELECT payment_reason::text, SUM(amount_paid) as total, COUNT(*) as cnt
    FROM app.application_payments WHERE status='confirmed'
    GROUP BY payment_reason ORDER BY total DESC
  ) t;

  -- By payout actor type (donut data)
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'actor_type', beneficiary_type, 'amount', total, 'count', cnt
  )), '[]'::jsonb) INTO v_by_payout_actor
  FROM (
    SELECT beneficiary_type, SUM(amount) as total, COUNT(*) as cnt
    FROM app.payout_queue WHERE status='completed'
    GROUP BY beneficiary_type ORDER BY total DESC
  ) t;

  -- Chart 30 days
  SELECT COALESCE(jsonb_agg(jsonb_build_object('d', d, 'pin', pin, 'pout', pout) ORDER BY d), '[]'::jsonb) INTO v_chart
  FROM (
    SELECT d,
      COALESCE((SELECT SUM(amount_paid) FROM app.application_payments
        WHERE status='confirmed' AND confirmed_at::date = d), 0) as pin,
      COALESCE((SELECT SUM(amount) FROM app.payout_queue
        WHERE status='completed' AND processed_at::date = d), 0) as pout
    FROM generate_series(CURRENT_DATE - 29, CURRENT_DATE, '1 day'::interval) d
  ) t;

  -- Active subscriptions
  SELECT COUNT(*) INTO v_active_subs FROM app.subscriptions WHERE status='active' AND (expires_at IS NULL OR expires_at > NOW());

  RETURN jsonb_build_object(
    'success', true,
    'total_payin', v_total_payin,
    'total_payout', v_total_payout,
    'month_payin', v_month_payin,
    'month_payout', v_month_payout,
    'month_payin_count', v_month_payin_count,
    'month_payout_count', v_month_payout_count,
    'pending_amount', v_pending_amount,
    'pending_count', v_pending_count,
    'processing_count', v_processing_count,
    'completed_month', v_completed_month,
    'failed_month', v_failed_month,
    'payout_success_rate', v_payout_success_rate,
    'by_reason', v_by_reason,
    'by_payout_actor', v_by_payout_actor,
    'chart_30d', v_chart,
    'active_subscriptions', v_active_subs
  );
END; $fn$;
""")

# ─── RPC 2: app_admin_finance_live_feed ───
print("\n### 2. app_admin_finance_live_feed ###")
sql("""
CREATE OR REPLACE FUNCTION public.app_admin_finance_live_feed(
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0,
  p_direction TEXT DEFAULT NULL,
  p_date_from TIMESTAMPTZ DEFAULT NULL,
  p_date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_result JSONB;
  v_total INT;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_uid;
  IF v_role <> 'admin' THEN RETURN jsonb_build_object('success', false, 'error', 'not_admin'); END IF;

  -- Count
  SELECT COUNT(*) INTO v_total FROM app.platform_ledger
  WHERE (p_direction IS NULL OR direction = p_direction)
    AND (p_date_from IS NULL OR created_at >= p_date_from)
    AND (p_date_to IS NULL OR created_at <= p_date_to);

  -- Entries with resolved actor names
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      pl.id, pl.transaction_type, pl.amount, pl.currency, pl.direction,
      pl.counterpart_type, pl.counterpart_id, pl.reference_id,
      pl.description, pl.balance_after, pl.created_at,
      CASE
        WHEN pl.counterpart_type = 'student' THEN (SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = pl.counterpart_id)
        WHEN pl.counterpart_type = 'instructor' THEN (SELECT full_name FROM app.instructors WHERE id = pl.counterpart_id)
        WHEN pl.counterpart_type = 'commercial' THEN (SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = pl.counterpart_id)
        WHEN pl.counterpart_type = 'merchant' THEN (SELECT name FROM app.marketplace_merchants WHERE owner_user_id = pl.counterpart_id LIMIT 1)
        ELSE NULL
      END AS actor_name,
      CASE
        WHEN pl.counterpart_type = 'student' THEN (SELECT email FROM auth.users WHERE id = pl.counterpart_id)
        ELSE NULL
      END AS actor_email
    FROM app.platform_ledger pl
    WHERE (p_direction IS NULL OR pl.direction = p_direction)
      AND (p_date_from IS NULL OR pl.created_at >= p_date_from)
      AND (p_date_to IS NULL OR pl.created_at <= p_date_to)
    ORDER BY pl.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t;

  RETURN jsonb_build_object('success', true, 'entries', v_result, 'total', v_total);
END; $fn$;
""")

# ─── RPC 3: app_admin_finance_payout_feed ───
print("\n### 3. app_admin_finance_payout_feed ###")
sql("""
CREATE OR REPLACE FUNCTION public.app_admin_finance_payout_feed(
  p_status TEXT DEFAULT NULL,
  p_beneficiary_type TEXT DEFAULT NULL,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_result JSONB;
  v_total INT;
  v_kpi JSONB;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_uid;
  IF v_role <> 'admin' THEN RETURN jsonb_build_object('success', false, 'error', 'not_admin'); END IF;

  -- KPIs
  SELECT jsonb_build_object(
    'pending_count', (SELECT COUNT(*) FROM app.payout_queue WHERE status='pending'),
    'pending_amount', (SELECT COALESCE(SUM(amount),0) FROM app.payout_queue WHERE status='pending'),
    'processing_count', (SELECT COUNT(*) FROM app.payout_queue WHERE status='processing'),
    'completed_count', (SELECT COUNT(*) FROM app.payout_queue WHERE status='completed'),
    'completed_amount', (SELECT COALESCE(SUM(amount),0) FROM app.payout_queue WHERE status='completed'),
    'failed_count', (SELECT COUNT(*) FROM app.payout_queue WHERE status='failed'),
    'failed_amount', (SELECT COALESCE(SUM(amount),0) FROM app.payout_queue WHERE status='failed'),
    'waiting_phone_count', (SELECT COUNT(*) FROM app.payout_queue WHERE status='waiting_phone')
  ) INTO v_kpi;

  -- Count filtered
  SELECT COUNT(*) INTO v_total FROM app.payout_queue pq
  WHERE (p_status IS NULL OR pq.status = p_status)
    AND (p_beneficiary_type IS NULL OR pq.beneficiary_type = p_beneficiary_type);

  -- Entries with resolved names
  SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.created_at DESC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT pq.*,
      CASE
        WHEN pq.beneficiary_type = 'instructor' THEN (SELECT full_name FROM app.instructors WHERE id = pq.beneficiary_user_id)
        WHEN pq.beneficiary_type = 'commercial' THEN (SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = pq.beneficiary_user_id)
        WHEN pq.beneficiary_type = 'merchant' THEN (SELECT name FROM app.marketplace_merchants WHERE owner_user_id = pq.beneficiary_user_id LIMIT 1)
        ELSE NULL
      END AS actor_name
    FROM app.payout_queue pq
    WHERE (p_status IS NULL OR pq.status = p_status)
      AND (p_beneficiary_type IS NULL OR pq.beneficiary_type = p_beneficiary_type)
    ORDER BY pq.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t;

  RETURN jsonb_build_object('success', true, 'kpi', v_kpi, 'payouts', v_result, 'total', v_total);
END; $fn$;
""")

# ─── RPC 4: app_admin_finance_actor_history ───
print("\n### 4. app_admin_finance_actor_history ###")
sql("""
CREATE OR REPLACE FUNCTION public.app_admin_finance_actor_history(
  p_actor_id UUID,
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_payouts JSONB;
  v_ledger JSONB;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'not_authenticated'); END IF;
  SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_uid;
  IF v_role <> 'admin' THEN RETURN jsonb_build_object('success', false, 'error', 'not_admin'); END IF;

  -- Payouts for this actor
  SELECT COALESCE(jsonb_agg(row_to_json(pq)::jsonb ORDER BY pq.created_at DESC), '[]'::jsonb)
  INTO v_payouts
  FROM (
    SELECT id, beneficiary_type, amount, currency, reason, status, error_message, retry_count, processed_at, created_at
    FROM app.payout_queue WHERE beneficiary_user_id = p_actor_id
    ORDER BY created_at DESC LIMIT p_limit OFFSET p_offset
  ) pq;

  -- Ledger entries referencing this actor
  SELECT COALESCE(jsonb_agg(row_to_json(pl)::jsonb ORDER BY pl.created_at DESC), '[]'::jsonb)
  INTO v_ledger
  FROM (
    SELECT id, transaction_type, amount, currency, direction, description, created_at
    FROM app.platform_ledger WHERE counterpart_id = p_actor_id
    ORDER BY created_at DESC LIMIT p_limit OFFSET p_offset
  ) pl;

  RETURN jsonb_build_object('success', true, 'payouts', v_payouts, 'ledger', v_ledger);
END; $fn$;
""")

print("\n### 5. Activate Realtime on finance tables ###")
sql("ALTER PUBLICATION supabase_realtime ADD TABLE app.platform_ledger;")
sql("ALTER PUBLICATION supabase_realtime ADD TABLE app.payout_queue;")

print("\nDone! 4 RPCs deployed + Realtime activated.")
