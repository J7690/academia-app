-- Test de bout en bout du marketplace, execute dans une transaction ANNULEE.
-- Rien n'est conserve : le bloc se termine par RAISE EXCEPTION 'E2E_RESULT ...'.
-- Variables a adapter : etudiant, marchand (proprietaire de l'annonce), admin, annonce payante.
DO $e2e$
DECLARE
  c_student  uuid := '31b29eeb-8aa8-4e2b-9478-3a15b2105e29';
  c_merchant uuid := '489bff02-d74f-460d-9adb-cc3215edc4c9';
  c_admin    uuid := '6e9012ae-2327-4f99-8d16-274763c4e975';
  c_listing  uuid := 'cb2cda58-de55-4af9-a1fa-b468864d115d';
  v_log text := '';
  v_fail int := 0;
  r jsonb;
  v_order uuid;
  v_pay uuid;
  v_amount numeric;
  v_status text;
  v_pstatus text;
  v_n int;
  v_scn text;
BEGIN
  CREATE FUNCTION pg_temp.e2e_as(p_uid uuid) RETURNS void LANGUAGE plpgsql AS $f$
  BEGIN
    IF p_uid IS NULL THEN
      PERFORM set_config('request.jwt.claims', '{"role":"service_role"}', true);
      PERFORM set_config('request.jwt.claim.sub', '', true);
    ELSE
      PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
      PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    END IF;
  END $f$;

  CREATE FUNCTION pg_temp.e2e_new_paid_order(p_student uuid, p_listing uuid, p_tx text, p_pay boolean)
  RETURNS jsonb LANGUAGE plpgsql AS $f$
  DECLARE r jsonb; o jsonb; c jsonb;
  BEGIN
    PERFORM pg_temp.e2e_as(p_student);
    r := public.app_student_cart_add_item(p_listing, 1);
    c := public.app_student_checkout_create_order_from_cart();
    o := c->'orders'->0;
    IF o IS NULL THEN
      RETURN jsonb_build_object('error', 'checkout', 'add', r, 'checkout', c);
    END IF;
    IF p_pay THEN
      PERFORM pg_temp.e2e_as(NULL);
      r := public.app_confirm_ligdicash_payment((o->>'marketplace_payment_id')::uuid, 'E2E', p_tx, 'test',
                                                'marketplace', (o->>'total_amount')::numeric);
      o := o || jsonb_build_object('confirm', r);
    END IF;
    RETURN o;
  END $f$;

  CREATE FUNCTION pg_temp.e2e_state(p_order uuid) RETURNS text LANGUAGE sql AS $f$
    SELECT o.status || '/' || COALESCE((SELECT p.status FROM app.marketplace_payments p
                                        WHERE p.order_id = o.id ORDER BY p.created_at DESC LIMIT 1), '-')
    FROM app.marketplace_orders o WHERE o.id = p_order
  $f$;

  -- ===== A : parcours nominal =====
  v_scn := 'A';
  r := pg_temp.e2e_new_paid_order(c_student, c_listing, 'E2E-A', true);
  v_order := (r->>'order_id')::uuid;
  v_log := v_log || 'A checkout+paiement: ' || COALESCE(r::text, 'null') || E'\n';
  IF pg_temp.e2e_state(v_order) <> 'paid/captured' THEN v_fail := v_fail + 1; v_log := v_log || '  ECHEC attendu paid/captured, obtenu ' || COALESCE(pg_temp.e2e_state(v_order), 'null') || E'\n'; END IF;

  PERFORM pg_temp.e2e_as(c_merchant);
  r := public.app_merchant_get_marketplace_order_detail(v_order);
  v_log := v_log || 'A detail marchand allowed_next=' || COALESCE(r->>'allowed_next', 'null') || ' deadlines=' || COALESCE(r->>'deadlines', 'null') || E'\n';
  FOREACH v_status IN ARRAY ARRAY['accepted', 'shipped', 'delivered'] LOOP
    r := public.app_merchant_update_marketplace_order_status(v_order, v_status, NULL);
    IF COALESCE(r->>'success', 'false') <> 'true' THEN v_fail := v_fail + 1; v_log := v_log || '  ECHEC marchand -> ' || v_status || ': ' || r::text || E'\n'; END IF;
  END LOOP;
  v_log := v_log || 'A apres livraison: ' || pg_temp.e2e_state(v_order) || E'\n';

  PERFORM pg_temp.e2e_as(c_student);
  r := public.app_student_get_marketplace_order_detail(v_order);
  v_log := v_log || 'A detail etudiant actions=' || COALESCE((r - 'order' - 'items' - 'events' - 'payment')::text, 'null') || E'\n';
  r := public.app_student_confirm_marketplace_order_received(v_order);
  v_log := v_log || 'A confirmation reception: ' || r::text || ' -> ' || pg_temp.e2e_state(v_order) || E'\n';
  IF pg_temp.e2e_state(v_order) <> 'completed/released' THEN v_fail := v_fail + 1; v_log := v_log || '  ECHEC attendu completed/released' || E'\n'; END IF;

  SELECT count(*) INTO v_n FROM app.payout_queue q WHERE q.created_at >= now();
  v_log := v_log || 'A versements crees: ' || v_n || E'\n';
  IF v_n = 0 THEN v_fail := v_fail + 1; v_log := v_log || '  ECHEC aucun versement en file' || E'\n'; END IF;

  PERFORM pg_temp.e2e_as(c_merchant);
  r := public.app_merchant_get_marketplace_earnings();
  v_log := v_log || 'A revenus marchand: ' || r::text || E'\n';

  -- ===== B : annulation sans motif refusee, puis litige rembourse =====
  v_scn := 'B';
  r := pg_temp.e2e_new_paid_order(c_student, c_listing, 'E2E-B', true);
  v_order := (r->>'order_id')::uuid;
  PERFORM pg_temp.e2e_as(c_merchant);
  r := public.app_merchant_update_marketplace_order_status(v_order, 'cancelled', NULL);
  v_log := v_log || 'B annulation marchand sans motif: ' || r::text || E'\n';
  IF r->>'error' IS DISTINCT FROM 'reason_required' THEN v_fail := v_fail + 1; v_log := v_log || '  ECHEC attendu reason_required' || E'\n'; END IF;
  r := public.app_merchant_update_marketplace_order_status(v_order, 'delivered', NULL);
  IF r->>'error' IS DISTINCT FROM 'invalid_transition' THEN v_fail := v_fail + 1; v_log := v_log || '  ECHEC saut paid->delivered accepte: ' || r::text || E'\n'; END IF;
  FOREACH v_status IN ARRAY ARRAY['accepted', 'shipped', 'delivered'] LOOP
    r := public.app_merchant_update_marketplace_order_status(v_order, v_status, NULL);
  END LOOP;
  PERFORM pg_temp.e2e_as(c_student);
  r := public.app_student_open_marketplace_dispute(v_order, 'Article non conforme (test E2E)');
  v_log := v_log || 'B reclamation: ' || r::text || ' -> ' || pg_temp.e2e_state(v_order) || E'\n';
  IF split_part(pg_temp.e2e_state(v_order), '/', 1) <> 'disputed' THEN v_fail := v_fail + 1; v_log := v_log || '  ECHEC attendu disputed' || E'\n'; END IF;
  PERFORM pg_temp.e2e_as(c_merchant);
  r := public.app_merchant_update_marketplace_order_status(v_order, 'completed', NULL);
  IF COALESCE(r->>'success', 'false') = 'true' THEN v_fail := v_fail + 1; v_log := v_log || '  ECHEC marchand a pu cloturer un litige' || E'\n'; END IF;
  PERFORM pg_temp.e2e_as(c_admin);
  r := public.app_admin_get_marketplace_order_detail(v_order);
  v_log := v_log || 'B detail admin actions=' || COALESCE(r->>'actions', 'null') || ' evenements=' || COALESCE(jsonb_array_length(r->'events')::text, 'null') || E'\n';
  r := public.app_admin_resolve_marketplace_dispute(v_order, 'refund', 'Remboursement test E2E');
  v_log := v_log || 'B arbitrage remboursement: ' || r::text || ' -> ' || pg_temp.e2e_state(v_order) || E'\n';
  IF pg_temp.e2e_state(v_order) <> 'refunded/refunded' THEN v_fail := v_fail + 1; v_log := v_log || '  ECHEC attendu refunded/refunded' || E'\n'; END IF;
  PERFORM pg_temp.e2e_as(NULL);
  SELECT p.id INTO v_pay FROM app.marketplace_payments p WHERE p.order_id = v_order;
  r := public.app_confirm_ligdicash_payment(v_pay, 'E2E', 'E2E-B2', 'test', 'marketplace', 100);
  v_log := v_log || 'B reconfirmation paiement rembourse: ' || r::text || ' -> ' || pg_temp.e2e_state(v_order) || E'\n';
  IF pg_temp.e2e_state(v_order) <> 'refunded/refunded' THEN v_fail := v_fail + 1; v_log := v_log || '  ECHEC idempotence refunded' || E'\n'; END IF;

  -- ===== C : annulation admin d'une commande payee =====
  v_scn := 'C';
  r := pg_temp.e2e_new_paid_order(c_student, c_listing, 'E2E-C', true);
  v_order := (r->>'order_id')::uuid;
  PERFORM pg_temp.e2e_as(c_admin);
  r := public.app_admin_cancel_marketplace_order(v_order, 'Annulation test E2E');
  v_log := v_log || 'C annulation admin: ' || r::text || ' -> ' || pg_temp.e2e_state(v_order) || E'\n';
  IF pg_temp.e2e_state(v_order) NOT IN ('cancelled/refunded') THEN v_fail := v_fail + 1; v_log := v_log || '  ECHEC attendu cancelled/refunded' || E'\n'; END IF;

  -- ===== D : annulation etudiant d'une commande non payee =====
  v_scn := 'D';
  r := pg_temp.e2e_new_paid_order(c_student, c_listing, 'E2E-D', false);
  v_order := (r->>'order_id')::uuid;
  PERFORM pg_temp.e2e_as(c_student);
  r := public.app_student_cancel_marketplace_order(v_order, NULL);
  v_log := v_log || 'D annulation etudiant (non payee): ' || r::text || ' -> ' || pg_temp.e2e_state(v_order) || E'\n';
  IF split_part(pg_temp.e2e_state(v_order), '/', 1) <> 'cancelled' THEN v_fail := v_fail + 1; v_log := v_log || '  ECHEC attendu cancelled' || E'\n'; END IF;

  -- ===== Securite : un autre utilisateur ne voit pas la commande =====
  PERFORM pg_temp.e2e_as(c_merchant);
  r := public.app_student_get_marketplace_order_detail(v_order);
  IF COALESCE(r->>'success', 'false') = 'true' THEN v_fail := v_fail + 1; v_log := v_log || 'ECHEC securite : le marchand lit la commande comme etudiant' || E'\n'; END IF;
  PERFORM pg_temp.e2e_as(c_student);
  r := public.app_admin_get_marketplace_order_detail(v_order);
  IF COALESCE(r->>'success', 'false') = 'true' THEN v_fail := v_fail + 1; v_log := v_log || 'ECHEC securite : l''etudiant accede au detail admin' || E'\n'; END IF;

  SELECT count(*) INTO v_n FROM app.marketplace_order_events e WHERE e.created_at >= now();
  v_log := v_log || 'Evenements journalises: ' || v_n || E'\n';

  RAISE EXCEPTION 'E2E_RESULT echecs=% %', v_fail, E'\n' || v_log;
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM LIKE 'E2E_RESULT%' THEN
    RAISE;
  END IF;
  RAISE EXCEPTION 'E2E_RESULT CRASH scenario=% : % (%)%', v_scn, SQLERRM, SQLSTATE, E'\n' || v_log;
END
$e2e$;
