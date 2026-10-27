-- Marketplace : sequestre, cycle de commande, delais, litiges, notifications.
-- Reference : academia_app/docs/marketplace_regles_metier.md
--
-- Avant : la confirmation LigdiCash versait 90 % au marchand des l'encaissement,
-- avant toute livraison ; aucune annulation, aucun remboursement, aucun delai.
-- Apres : fonds en sequestre jusqu'a `completed`, remboursement integral sur
-- annulation ou litige, delais controles par cron, notifications a chaque etape.

-- ===========================================================================
-- 1. Schema
-- ===========================================================================
ALTER TABLE app.marketplace_orders
  ADD COLUMN IF NOT EXISTS paid_at timestamptz,
  ADD COLUMN IF NOT EXISTS accepted_at timestamptz,
  ADD COLUMN IF NOT EXISTS shipped_at timestamptz,
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancelled_by text,
  ADD COLUMN IF NOT EXISTS cancel_reason text,
  ADD COLUMN IF NOT EXISTS disputed_at timestamptz,
  ADD COLUMN IF NOT EXISTS dispute_reason text,
  ADD COLUMN IF NOT EXISTS dispute_resolution text,
  ADD COLUMN IF NOT EXISTS dispute_resolved_at timestamptz,
  ADD COLUMN IF NOT EXISTS dispute_resolved_by uuid,
  ADD COLUMN IF NOT EXISTS accept_reminder_sent_at timestamptz;

ALTER TABLE app.marketplace_payments
  ADD COLUMN IF NOT EXISTS captured_at timestamptz,
  ADD COLUMN IF NOT EXISTS refunded_at timestamptz,
  ADD COLUMN IF NOT EXISTS refund_payout_id uuid;

CREATE TABLE IF NOT EXISTS app.marketplace_order_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES app.marketplace_orders(id) ON DELETE CASCADE,
  from_status text,
  to_status text NOT NULL,
  actor_id uuid,
  actor_role text NOT NULL,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_order_events_order
  ON app.marketplace_order_events(order_id, created_at);

ALTER TABLE app.marketplace_order_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON app.marketplace_order_events FROM anon, authenticated;

-- ===========================================================================
-- 2. Utilitaires internes
-- ===========================================================================
CREATE OR REPLACE FUNCTION app.mp_order_ref(p_order_id uuid)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $$ SELECT '#' || upper(left(p_order_id::text, 8)) $$;

CREATE OR REPLACE FUNCTION app.mp_fmt_amount(p_amount numeric, p_currency text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $$
  SELECT replace(to_char(round(COALESCE(p_amount, 0)), 'FM999,999,999,990'), ',', ' ')
         || ' '
         || CASE WHEN COALESCE(p_currency, 'XOF') IN ('XOF', 'FCFA') THEN 'FCFA' ELSE p_currency END
$$;

CREATE OR REPLACE FUNCTION app.mp_notify(
  p_user uuid, p_domain text, p_event text, p_title text, p_body text, p_payload jsonb DEFAULT '{}'::jsonb
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_user IS NULL THEN
    RETURN;
  END IF;
  PERFORM public.app_queue_notification_event(
    p_user, p_domain, p_event,
    COALESCE(p_payload, '{}'::jsonb) || jsonb_build_object('push_title', p_title, 'push_body', p_body)
  );
END;
$$;

CREATE OR REPLACE FUNCTION app.mp_notify_admins(
  p_event text, p_title text, p_body text, p_payload jsonb DEFAULT '{}'::jsonb
)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_admin record;
BEGIN
  FOR v_admin IN
    SELECT u.id
    FROM auth.users u
    WHERE COALESCE(u.raw_app_meta_data->>'role', u.raw_user_meta_data->>'role') IN ('admin', 'super_admin')
      AND (u.banned_until IS NULL OR u.banned_until < now())
  LOOP
    PERFORM app.mp_notify(v_admin.id, 'admin_marketplace', p_event, p_title, p_body, p_payload);
  END LOOP;
END;
$$;

-- Transitions ouvertes au marchand (source unique : RPC de mise a jour + detail).
CREATE OR REPLACE FUNCTION app.mp_merchant_allowed_next(p_status text)
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE
AS $$
  SELECT CASE p_status
    WHEN 'pending'   THEN ARRAY['cancelled']
    WHEN 'paid'      THEN ARRAY['accepted', 'cancelled']
    WHEN 'confirmed' THEN ARRAY['accepted']
    WHEN 'accepted'  THEN ARRAY['shipped', 'cancelled']
    WHEN 'shipped'   THEN ARRAY['delivered']
    ELSE ARRAY[]::text[]
  END
$$;

-- ===========================================================================
-- 3. Argent : versement et remboursement
-- ===========================================================================

-- Verse au marchand le net d'un paiement en sequestre (une seule fois).
-- Le credit de actor_balances declenche trg_auto_queue_payout -> payout_queue.
CREATE OR REPLACE FUNCTION app.mp_release_funds(p_order_id uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_p app.marketplace_payments%ROWTYPE;
  v_cur text;
  v_comm numeric;
  v_net numeric;
BEGIN
  SELECT * INTO v_p
  FROM app.marketplace_payments
  WHERE order_id = p_order_id AND status = 'captured'
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  v_cur := COALESCE(v_p.currency, 'XOF');
  v_comm := ROUND(v_p.gross_amount * COALESCE(v_p.commission_rate, 0), 2);
  v_net := v_p.gross_amount - v_comm;

  UPDATE app.marketplace_payments
  SET status = 'released',
      commission_amount = v_comm,
      net_amount = v_net,
      escrow_released_at = now(),
      updated_at = now()
  WHERE id = v_p.id;

  IF v_net > 0 THEN
    UPDATE app.actor_balances
    SET available_balance = available_balance + v_net,
        total_earned = total_earned + v_net,
        updated_at = now()
    WHERE actor_type = 'merchant' AND actor_id = v_p.merchant_id;

    IF NOT FOUND THEN
      INSERT INTO app.actor_balances(actor_type, actor_id, available_balance, pending_balance, total_earned, currency)
      VALUES ('merchant', v_p.merchant_id, v_net, 0, v_net, v_cur);
    END IF;

    INSERT INTO app.platform_ledger(transaction_type, amount, currency, direction, counterpart_type, counterpart_id, reference_id, description)
    VALUES ('revenue_split', v_net, v_cur, 'debit', 'merchant', v_p.merchant_id, v_p.id,
            'Versement marchand commande ' || app.mp_order_ref(p_order_id)
            || ' (commission ' || v_comm::text || ' ' || v_cur || ')');
  END IF;

  RETURN v_net;
END;
$$;

-- Rembourse integralement un paiement encaisse, sur le numero qui a paye.
CREATE OR REPLACE FUNCTION app.mp_refund_payment(p_payment_id uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_p app.marketplace_payments%ROWTYPE;
  v_cur text;
  v_payout uuid;
BEGIN
  SELECT * INTO v_p
  FROM app.marketplace_payments
  WHERE id = p_payment_id AND status = 'captured'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  v_cur := COALESCE(v_p.currency, 'XOF');

  INSERT INTO app.payout_queue(
    beneficiary_type, beneficiary_user_id, beneficiary_phone,
    amount, currency, reason, source_marketplace_payment_id, status
  )
  VALUES (
    'buyer_refund', v_p.buyer_id, v_p.phone_number,
    v_p.gross_amount, v_cur, 'marketplace_refund', v_p.id,
    CASE WHEN length(btrim(COALESCE(v_p.phone_number, ''))) >= 8 THEN 'pending' ELSE 'waiting_phone' END
  )
  RETURNING id INTO v_payout;

  UPDATE app.marketplace_payments
  SET status = 'refunded',
      refunded_at = now(),
      refund_payout_id = v_payout,
      updated_at = now()
  WHERE id = v_p.id;

  INSERT INTO app.platform_ledger(transaction_type, amount, currency, direction, counterpart_type, counterpart_id, reference_id, description)
  VALUES ('escrow_refund', v_p.gross_amount, v_cur, 'debit', 'student', v_p.buyer_id, v_p.id,
          'Remboursement commande ' || app.mp_order_ref(v_p.order_id));

  RETURN v_p.gross_amount;
END;
$$;

-- Rembourse tout ce qui a ete encaisse sur une commande et clot les tentatives en cours.
CREATE OR REPLACE FUNCTION app.mp_refund_order(p_order_id uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_total numeric := 0;
  v_id uuid;
BEGIN
  UPDATE app.marketplace_payments
  SET status = 'cancelled', updated_at = now()
  WHERE order_id = p_order_id AND status IN ('pending', 'processing');

  FOR v_id IN
    SELECT id FROM app.marketplace_payments WHERE order_id = p_order_id AND status = 'captured'
  LOOP
    v_total := v_total + app.mp_refund_payment(v_id);
  END LOOP;

  RETURN v_total;
END;
$$;

-- ===========================================================================
-- 4. Moteur de transition (seul point d'ecriture du statut de commande)
--    Les appelants verifient les droits et la transition ; le moteur applique
--    l'horodatage, le journal, les mouvements d'argent et les notifications.
-- ===========================================================================
CREATE OR REPLACE FUNCTION app.mp_transition(
  p_order_id uuid, p_to text, p_actor uuid, p_role text, p_note text DEFAULT NULL
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_o app.marketplace_orders%ROWTYPE;
  v_from text;
  v_owner uuid;
  v_ref text;
  v_amount text;
  v_reason text := NULLIF(btrim(COALESCE(p_note, '')), '');
  v_refund numeric := 0;
  v_net numeric := 0;
  v_payload jsonb;
BEGIN
  SELECT * INTO v_o FROM app.marketplace_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  v_from := v_o.status;
  IF v_from = p_to THEN
    RETURN jsonb_build_object('success', true, 'status', v_from, 'unchanged', true);
  END IF;

  UPDATE app.marketplace_orders SET
    status = p_to,
    updated_at = now(),
    paid_at = CASE WHEN p_to = 'paid' THEN now() ELSE paid_at END,
    accepted_at = CASE WHEN p_to = 'accepted' THEN now() ELSE accepted_at END,
    shipped_at = CASE WHEN p_to = 'shipped' THEN now() ELSE shipped_at END,
    delivered_at = CASE WHEN p_to = 'delivered' THEN now() ELSE delivered_at END,
    completed_at = CASE WHEN p_to = 'completed' THEN now() ELSE completed_at END,
    cancelled_at = CASE WHEN p_to IN ('cancelled', 'refunded') THEN now() ELSE cancelled_at END,
    cancelled_by = CASE WHEN p_to IN ('cancelled', 'refunded') THEN p_role ELSE cancelled_by END,
    cancel_reason = CASE WHEN p_to = 'cancelled' THEN v_reason ELSE cancel_reason END,
    disputed_at = CASE WHEN p_to = 'disputed' THEN now() ELSE disputed_at END,
    dispute_reason = CASE WHEN p_to = 'disputed' THEN v_reason ELSE dispute_reason END,
    dispute_resolution = CASE
      WHEN v_from = 'disputed' AND p_to = 'completed' THEN 'release'
      WHEN v_from = 'disputed' AND p_to = 'refunded' THEN 'refund'
      ELSE dispute_resolution END,
    dispute_resolved_at = CASE WHEN v_from = 'disputed' THEN now() ELSE dispute_resolved_at END,
    dispute_resolved_by = CASE WHEN v_from = 'disputed' THEN p_actor ELSE dispute_resolved_by END
  WHERE id = p_order_id;

  INSERT INTO app.marketplace_order_events(order_id, from_status, to_status, actor_id, actor_role, note)
  VALUES (p_order_id, v_from, p_to, p_actor, p_role, v_reason);

  IF p_to = 'completed' THEN
    v_net := app.mp_release_funds(p_order_id);
  ELSIF p_to IN ('cancelled', 'refunded') THEN
    v_refund := app.mp_refund_order(p_order_id);
  END IF;

  SELECT owner_user_id INTO v_owner FROM app.marketplace_merchants WHERE id = v_o.merchant_id;
  v_ref := app.mp_order_ref(p_order_id);
  v_amount := app.mp_fmt_amount(v_o.total_amount, v_o.currency);
  v_payload := jsonb_build_object('order_id', p_order_id, 'status', p_to, 'from_status', v_from);

  IF p_to = 'paid' THEN
    PERFORM app.mp_notify(v_o.student_id, 'student_marketplace', 'order_paid',
      '✅ Paiement confirmé',
      'Commande ' || v_ref || ' (' || v_amount || ') payée. Le vendeur a 48 h pour l''accepter.', v_payload);
    PERFORM app.mp_notify(v_owner, 'merchant_marketplace', 'order_paid',
      '🛒 Nouvelle commande payée',
      'Commande ' || v_ref || ' — ' || v_amount || '. Acceptez-la sous 48 h, sinon elle sera annulée.', v_payload);
    PERFORM app.mp_notify_admins('order_paid', '🛒 Commande payée',
      'Commande ' || v_ref || ' — ' || v_amount, v_payload);

  ELSIF p_to = 'accepted' THEN
    PERFORM app.mp_notify(v_o.student_id, 'student_marketplace', 'order_accepted',
      '📦 Commande acceptée',
      'Le vendeur prépare votre commande ' || v_ref || '.', v_payload);

  ELSIF p_to = 'shipped' THEN
    PERFORM app.mp_notify(v_o.student_id, 'student_marketplace', 'order_shipped',
      '🚚 Commande expédiée',
      'Votre commande ' || v_ref || ' est en route.', v_payload);

  ELSIF p_to = 'delivered' THEN
    PERFORM app.mp_notify(v_o.student_id, 'student_marketplace', 'order_delivered',
      '📬 Commande livrée',
      'Confirmez la réception de ' || v_ref || '. Sans réclamation sous 72 h, elle sera validée automatiquement.', v_payload);

  ELSIF p_to = 'completed' THEN
    PERFORM app.mp_notify(v_owner, 'merchant_marketplace', 'order_completed',
      '💰 Fonds versés',
      CASE WHEN v_net > 0
        THEN 'Commande ' || v_ref || ' validée : ' || app.mp_fmt_amount(v_net, v_o.currency) || ' vous sont versés.'
        ELSE 'Commande ' || v_ref || ' validée.' END, v_payload);
    PERFORM app.mp_notify(v_o.student_id, 'student_marketplace', 'order_completed',
      '⭐ Commande terminée',
      'Merci ! Donnez votre avis sur la commande ' || v_ref || '.', v_payload);

  ELSIF p_to = 'cancelled' THEN
    PERFORM app.mp_notify(v_o.student_id, 'student_marketplace', 'order_cancelled',
      '❌ Commande annulée',
      'Commande ' || v_ref || ' annulée' || COALESCE(' : ' || v_reason, '')
      || CASE WHEN v_refund > 0
           THEN '. Remboursement de ' || app.mp_fmt_amount(v_refund, v_o.currency) || ' en cours sur votre numéro.'
           ELSE '.' END, v_payload);
    IF p_role <> 'merchant' AND v_from <> 'pending' THEN
      PERFORM app.mp_notify(v_owner, 'merchant_marketplace', 'order_cancelled',
        '❌ Commande annulée',
        'Commande ' || v_ref || ' annulée' || COALESCE(' : ' || v_reason, '') || '.', v_payload);
    END IF;

  ELSIF p_to = 'disputed' THEN
    PERFORM app.mp_notify(v_owner, 'merchant_marketplace', 'order_disputed',
      '⚠️ Réclamation ouverte',
      'L''acheteur signale un problème sur ' || v_ref || COALESCE(' : ' || v_reason, '') || '. Les fonds sont gelés.', v_payload);
    PERFORM app.mp_notify_admins('order_disputed', '⚠️ Litige à arbitrer',
      'Commande ' || v_ref || ' — ' || COALESCE(v_reason, 'réclamation'), v_payload);

  ELSIF p_to = 'refunded' THEN
    PERFORM app.mp_notify(v_o.student_id, 'student_marketplace', 'dispute_refunded',
      '💸 Remboursement accordé',
      'Réclamation ' || v_ref || ' tranchée en votre faveur : '
      || app.mp_fmt_amount(v_refund, v_o.currency) || ' remboursés sur votre numéro.', v_payload);
    PERFORM app.mp_notify(v_owner, 'merchant_marketplace', 'dispute_refunded',
      '⚖️ Litige clos',
      'Réclamation ' || v_ref || ' : l''acheteur est remboursé.' || COALESCE(' Motif : ' || v_reason, ''), v_payload);
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'status', p_to,
    'from', v_from,
    'refunded_amount', v_refund,
    'released_amount', v_net
  );
END;
$$;

-- Appele par la confirmation LigdiCash une fois le paiement passe en `captured`.
CREATE OR REPLACE FUNCTION app.mp_on_payment_captured(p_payment_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_p app.marketplace_payments%ROWTYPE;
  v_o app.marketplace_orders%ROWTYPE;
  v_refund numeric;
BEGIN
  SELECT * INTO v_p FROM app.marketplace_payments WHERE id = p_payment_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT * INTO v_o FROM app.marketplace_orders WHERE id = v_p.order_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_o.status = 'pending' THEN
    PERFORM app.mp_transition(v_o.id, 'paid', NULL, 'system', 'Paiement LigdiCash confirmé');
    RETURN;
  END IF;

  -- Paiement tardif (commande annulee entre-temps) ou doublon : remboursement immediat.
  v_refund := app.mp_refund_payment(p_payment_id);
  INSERT INTO app.marketplace_order_events(order_id, from_status, to_status, actor_id, actor_role, note)
  VALUES (v_o.id, v_o.status, v_o.status, NULL, 'system', 'Paiement reçu hors délai : remboursé automatiquement');
  PERFORM app.mp_notify(v_o.student_id, 'student_marketplace', 'late_payment_refunded',
    '💸 Paiement remboursé',
    'Votre paiement pour la commande ' || app.mp_order_ref(v_o.id)
    || ' est arrivé après sa clôture : ' || app.mp_fmt_amount(v_refund, v_p.currency) || ' vous sont remboursés.',
    jsonb_build_object('order_id', v_o.id, 'status', v_o.status));
END;
$$;

-- ===========================================================================
-- 5. Confirmation LigdiCash : la branche marketplace ne verse plus le marchand.
--    Seule la branche marketplace change (version de production du 06/10/2026).
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.app_confirm_ligdicash_payment(p_payment_id uuid, p_ligdicash_token text DEFAULT NULL::text, p_ligdicash_transaction_id text DEFAULT NULL::text, p_ligdicash_operator text DEFAULT NULL::text, p_payment_type text DEFAULT 'application'::text, p_amount_paid numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'app'
AS $function$
DECLARE
  v_payment app.application_payments%ROWTYPE;
  v_mp_payment app.marketplace_payments%ROWTYPE;
  v_recu JSONB;
  v_split JSONB;
  v_split_rules JSONB;
  v_split_rule JSONB;
  v_split_amount NUMERIC;
  v_total_amount NUMERIC;
  v_payment_reason TEXT;
  v_beneficiary_type TEXT;
  v_beneficiary_pct NUMERIC;
  v_actor_id UUID;
  v_commercial_user_id UUID;
  v_montant_encaisse NUMERIC;
  v_rappro JSONB;
  v_i INTEGER;
BEGIN
  PERFORM public.app_confirm_ligdicash_payment_guard();

  IF p_payment_type IN ('application', 'subscription', 'td', 'short_training') THEN

    SELECT * INTO v_payment FROM app.application_payments WHERE id = p_payment_id;
    IF v_payment IS NULL THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'payment_not_found');
    END IF;

    IF v_payment.status = 'confirmed' THEN
      RETURN JSONB_BUILD_OBJECT('success', TRUE, 'already_confirmed', TRUE);
    END IF;

    IF v_payment.status NOT IN ('pending', 'declared_by_student', 'under_verification', 'processing') THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_status');
    END IF;

    v_rappro := app.rapprocher_montant(v_payment.amount_due, p_amount_paid);

    IF (v_rappro->>'conforme')::boolean IS FALSE THEN
      -- Un ecart materiel, ou un montant inconnu, n'est pas une confirmation.
      -- On ne confirme pas, on n'emet pas de recu, on ne genere aucune
      -- commission. Le paiement passe sous les yeux d'un humain.
      UPDATE app.application_payments
         SET status = 'under_verification',
             -- ON N'INVENTE PAS CE QU'ON N'A PAS VU. `LEAST` ignorant les NULL,
             -- l'ancienne ecriture inscrivait le montant DU comme montant RECU
             -- quand le prestataire n'avait rien renvoye.
             amount_paid = CASE
               WHEN p_amount_paid IS NULL THEN amount_paid
               ELSE LEAST(p_amount_paid, amount_due)
             END,
             ligdicash_token = COALESCE(p_ligdicash_token, ligdicash_token),
             ligdicash_transaction_id = COALESCE(p_ligdicash_transaction_id, ligdicash_transaction_id),
             ligdicash_operator = COALESCE(p_ligdicash_operator, ligdicash_operator),
             updated_at = NOW()
       WHERE id = p_payment_id;

      RETURN JSONB_BUILD_OBJECT(
        'success', FALSE,
        'error', 'amount_mismatch',
        'rapprochement', v_rappro,
        'message', CASE v_rappro->>'sens'
          WHEN 'sous_paiement'  THEN 'Le montant reçu est inférieur au montant dû. Le paiement est mis en vérification.'
          WHEN 'sur_paiement'   THEN 'Le montant reçu dépasse le montant dû. Le paiement est mis en vérification.'
          WHEN 'montant_absent' THEN 'Le montant encaissé n''a pas pu être vérifié auprès de l''opérateur. Le paiement est mis en vérification : ton argent n''est pas perdu.'
          ELSE 'Écart de montant : le paiement est mis en vérification.'
        END
      );
    END IF;

    v_montant_encaisse := LEAST(
      COALESCE(p_amount_paid, v_payment.amount_paid, v_payment.amount_due),
      v_payment.amount_due
    );

    UPDATE app.application_payments SET
      status = 'confirmed',
      payment_method = 'ligdicash_otp',
      amount_paid = v_montant_encaisse,
      ligdicash_token = COALESCE(p_ligdicash_token, ligdicash_token),
      ligdicash_transaction_id = COALESCE(p_ligdicash_transaction_id, ligdicash_transaction_id),
      ligdicash_operator = COALESCE(p_ligdicash_operator, ligdicash_operator),
      confirmed_at = NOW(),
      confirmed_by = NULL,
      updated_at = NOW()
    WHERE id = p_payment_id;

    SELECT * INTO v_payment FROM app.application_payments WHERE id = p_payment_id;

    v_recu := app.emettre_recu(
      p_payment_id,
      COALESCE(auth.uid(), v_payment.student_id),
      JSONB_BUILD_OBJECT('rapprochement', v_rappro));

    BEGIN
      PERFORM app.emettre_bon(p_payment_id,
        COALESCE(auth.uid(), v_payment.student_id), 'automatique');
    EXCEPTION WHEN OTHERS THEN
      INSERT INTO app.brokerage_voucher_checks (voucher_number, checked_by, resultat)
      VALUES ('(emission)', v_payment.student_id, 'echec_emission: ' || SQLERRM);
    END;

    INSERT INTO app.platform_ledger (transaction_type, amount, currency, direction, counterpart_type, counterpart_id, reference_id, description)
    VALUES ('payin', COALESCE(v_payment.amount_paid, v_payment.amount_due), v_payment.currency, 'credit', 'student', v_payment.student_id, p_payment_id,
            'Paiement ' || v_payment.payment_reason::TEXT || ' via LigdiCash');

    v_split := app_generate_commission_split_for_payment(p_payment_id, NULL);

    SELECT ur.commercial_user_id INTO v_commercial_user_id
    FROM app.user_referrals ur WHERE ur.student_id = v_payment.student_id LIMIT 1;

    v_total_amount := COALESCE(v_payment.amount_paid, v_payment.amount_due, 0);
    v_payment_reason := v_payment.payment_reason::TEXT;
    v_split_rules := app_resolve_revenue_split(v_payment_reason);

    IF v_split_rules IS NOT NULL AND jsonb_array_length(v_split_rules) > 0 THEN
      FOR v_i IN 0..jsonb_array_length(v_split_rules) - 1 LOOP
        v_split_rule := v_split_rules->v_i;
        v_beneficiary_type := v_split_rule->>'beneficiary_type';
        v_beneficiary_pct := (v_split_rule->>'percentage')::NUMERIC;
        v_split_amount := ROUND(v_total_amount * v_beneficiary_pct, 2);

        IF v_split_rule->>'max_amount' IS NOT NULL AND v_split_amount > (v_split_rule->>'max_amount')::NUMERIC THEN
          v_split_amount := (v_split_rule->>'max_amount')::NUMERIC;
        END IF;

        IF v_split_amount > 0 AND v_beneficiary_type <> 'platform' THEN
          v_actor_id := NULL;

          IF v_beneficiary_type = 'commercial' AND v_commercial_user_id IS NOT NULL THEN
            v_actor_id := v_commercial_user_id;
          ELSIF v_beneficiary_type = 'university' THEN
            SELECT u.id INTO v_actor_id
            FROM app.applications a
            JOIN app.programs p ON p.id = a.program_id
            JOIN app.universities u ON u.id = p.university_id
            WHERE a.id = v_payment.application_id LIMIT 1;
          ELSIF v_beneficiary_type = 'instructor' THEN
            IF p_payment_type = 'td' THEN
              SELECT te.assigned_teacher_id INTO v_actor_id
              FROM app.td_enrollments te WHERE te.payment_id = p_payment_id LIMIT 1;
            END IF;
          ELSIF v_beneficiary_type = 'merchant' THEN
            CONTINUE;
          END IF;

          IF v_actor_id IS NOT NULL THEN
            INSERT INTO app.actor_balances (actor_type, actor_id, available_balance, pending_balance, total_earned, currency)
            VALUES (v_beneficiary_type, v_actor_id, v_split_amount, 0, v_split_amount, COALESCE(v_payment.currency, 'XOF'))
            ON CONFLICT (actor_type, actor_id) DO UPDATE SET
              available_balance = app.actor_balances.available_balance + v_split_amount,
              total_earned = app.actor_balances.total_earned + v_split_amount,
              updated_at = NOW();

            INSERT INTO app.platform_ledger (transaction_type, amount, currency, direction, counterpart_type, counterpart_id, reference_id, description)
            VALUES ('revenue_split', v_split_amount, COALESCE(v_payment.currency, 'XOF'), 'debit', v_beneficiary_type, v_actor_id, p_payment_id,
                    'Split ' || v_beneficiary_type || ' (' || (v_beneficiary_pct * 100)::TEXT || '%) pour ' || v_payment_reason);
          END IF;
        END IF;
      END LOOP;
    END IF;

    IF p_payment_type = 'subscription' THEN
      UPDATE app.subscriptions SET
        status = 'active', started_at = NOW(), payment_id = p_payment_id, updated_at = NOW()
      WHERE payment_id = p_payment_id OR (student_id = v_payment.student_id AND status = 'pending_payment');
    END IF;

    IF p_payment_type = 'td' THEN
      UPDATE app.td_enrollments SET
        access_status = 'waiting_admin', updated_at = NOW()
      WHERE payment_id = p_payment_id AND access_status = 'pending_payment';
    END IF;

    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE,
      'receipt_number', v_recu->>'receipt_number',
      'receipt_id', v_recu->>'receipt_id',
      'amount_paid', v_montant_encaisse,
      'rapprochement', v_rappro,
      'commission_split', v_split
    );

  ELSIF p_payment_type = 'marketplace' THEN

    SELECT * INTO v_mp_payment FROM app.marketplace_payments WHERE id = p_payment_id;
    IF v_mp_payment IS NULL THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'marketplace_payment_not_found');
    END IF;

    IF v_mp_payment.status NOT IN ('pending', 'processing', 'cancelled') THEN
      IF v_mp_payment.status IN ('paid', 'captured', 'released', 'refunded') THEN
        RETURN JSONB_BUILD_OBJECT('success', TRUE, 'already_confirmed', TRUE);
      END IF;
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_marketplace_payment_status');
    END IF;

    v_rappro := app.rapprocher_montant(v_mp_payment.gross_amount, p_amount_paid);
    IF (v_rappro->>'conforme')::boolean IS FALSE THEN
      RETURN JSONB_BUILD_OBJECT(
        'success', FALSE, 'error', 'amount_mismatch', 'rapprochement', v_rappro,
        'message', CASE v_rappro->>'sens'
          WHEN 'montant_absent' THEN 'Le montant encaissé n''a pas pu être vérifié auprès de l''opérateur.'
          ELSE 'Le montant reçu ne correspond pas à la commande.'
        END);
    END IF;

    UPDATE app.marketplace_payments SET
      status = 'captured', captured_at = NOW(), payment_provider = 'ligdicash',
      payment_provider_ref = p_ligdicash_transaction_id,
      ligdicash_token = p_ligdicash_token,
      ligdicash_transaction_id = p_ligdicash_transaction_id,
      updated_at = NOW()
    WHERE id = p_payment_id;

    INSERT INTO app.platform_ledger (transaction_type, amount, currency, direction, counterpart_type, counterpart_id, reference_id, description)
    VALUES ('escrow_hold', v_mp_payment.gross_amount, v_mp_payment.currency, 'credit', 'student', v_mp_payment.buyer_id, p_payment_id,
            'Paiement marketplace commande #' || v_mp_payment.order_id::TEXT);

    -- Sequestre : aucun versement ici. Passage a `paid` (ou remboursement si
    -- la commande est deja close) ; le marchand est verse a `completed`.
    PERFORM app.mp_on_payment_captured(p_payment_id);

    RETURN JSONB_BUILD_OBJECT(
      'success', TRUE, 'status', 'captured',
      'gross_amount', v_mp_payment.gross_amount,
      'rapprochement', v_rappro);

  ELSE
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'unknown_payment_type');
  END IF;
END;
$function$;


-- ===========================================================================
-- 6. Delais de service (cron toutes les 15 minutes)
-- ===========================================================================
CREATE OR REPLACE FUNCTION app.mp_run_sla()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  r record;
  v_unpaid int := 0;
  v_not_accepted int := 0;
  v_not_shipped int := 0;
  v_auto_completed int := 0;
  v_reminders int := 0;
  v_errors int := 0;
BEGIN
  FOR r IN
    SELECT id FROM app.marketplace_orders
    WHERE status = 'pending' AND created_at < now() - interval '24 hours'
  LOOP
    BEGIN
      PERFORM app.mp_transition(r.id, 'cancelled', NULL, 'system', 'Paiement non reçu sous 24 h');
      v_unpaid := v_unpaid + 1;
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
    END;
  END LOOP;

  FOR r IN
    SELECT id FROM app.marketplace_orders
    WHERE status = 'paid' AND COALESCE(paid_at, updated_at) < now() - interval '48 hours'
  LOOP
    BEGIN
      PERFORM app.mp_transition(r.id, 'cancelled', NULL, 'system', 'Vendeur sans réponse sous 48 h');
      v_not_accepted := v_not_accepted + 1;
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
    END;
  END LOOP;

  FOR r IN
    SELECT o.id, o.paid_at, o.updated_at, m.owner_user_id
    FROM app.marketplace_orders o
    JOIN app.marketplace_merchants m ON m.id = o.merchant_id
    WHERE o.status = 'paid'
      AND o.accept_reminder_sent_at IS NULL
      AND COALESCE(o.paid_at, o.updated_at) < now() - interval '24 hours'
  LOOP
    PERFORM app.mp_notify(r.owner_user_id, 'merchant_marketplace', 'accept_reminder',
      '⏰ Commande en attente de votre réponse',
      'Acceptez la commande ' || app.mp_order_ref(r.id) || ' avant le '
      || to_char((COALESCE(r.paid_at, r.updated_at) + interval '48 hours') AT TIME ZONE 'Africa/Ouagadougou', 'DD/MM à HH24:MI')
      || ', sinon elle sera annulée et l''acheteur remboursé.',
      jsonb_build_object('order_id', r.id, 'status', 'paid'));
    UPDATE app.marketplace_orders SET accept_reminder_sent_at = now() WHERE id = r.id;
    v_reminders := v_reminders + 1;
  END LOOP;

  FOR r IN
    SELECT id FROM app.marketplace_orders
    WHERE status = 'accepted' AND COALESCE(accepted_at, updated_at) < now() - interval '5 days'
  LOOP
    BEGIN
      PERFORM app.mp_transition(r.id, 'cancelled', NULL, 'system', 'Non expédiée sous 5 jours');
      v_not_shipped := v_not_shipped + 1;
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
    END;
  END LOOP;

  FOR r IN
    SELECT id FROM app.marketplace_orders
    WHERE status = 'delivered' AND COALESCE(delivered_at, updated_at) < now() - interval '72 hours'
  LOOP
    BEGIN
      PERFORM app.mp_transition(r.id, 'completed', NULL, 'system', 'Validation automatique : 72 h sans réclamation');
      v_auto_completed := v_auto_completed + 1;
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'unpaid_cancelled', v_unpaid,
    'not_accepted_cancelled', v_not_accepted,
    'not_shipped_cancelled', v_not_shipped,
    'auto_completed', v_auto_completed,
    'reminders', v_reminders,
    'errors', v_errors
  );
END;
$$;

-- ===========================================================================
-- 7. RPC etudiant
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.app_student_cancel_marketplace_order(p_order_id uuid, p_reason text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_status text;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT status INTO v_status
  FROM app.marketplace_orders
  WHERE id = p_order_id AND student_id = v_user
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  IF v_status NOT IN ('pending', 'paid') THEN
    RETURN jsonb_build_object('success', false, 'error', 'cancel_not_allowed', 'status', v_status,
      'message', 'La commande a déjà été acceptée par le vendeur. Contactez-le ou ouvrez une réclamation après expédition.');
  END IF;

  RETURN app.mp_transition(p_order_id, 'cancelled', v_user, 'student',
    COALESCE(NULLIF(btrim(COALESCE(p_reason, '')), ''), 'Annulée par l''acheteur'));
END;
$$;

CREATE OR REPLACE FUNCTION public.app_student_confirm_marketplace_order_received(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_status text;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT status INTO v_status
  FROM app.marketplace_orders
  WHERE id = p_order_id AND student_id = v_user
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  IF v_status NOT IN ('shipped', 'delivered') THEN
    RETURN jsonb_build_object('success', false, 'error', 'confirm_not_allowed', 'status', v_status);
  END IF;

  RETURN app.mp_transition(p_order_id, 'completed', v_user, 'student', 'Réception confirmée par l''acheteur');
END;
$$;

CREATE OR REPLACE FUNCTION public.app_student_open_marketplace_dispute(p_order_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_o app.marketplace_orders%ROWTYPE;
  v_reason text := btrim(COALESCE(p_reason, ''));
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF length(v_reason) < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'reason_required',
      'message', 'Décrivez le problème (10 caractères minimum).');
  END IF;

  SELECT * INTO v_o
  FROM app.marketplace_orders
  WHERE id = p_order_id AND student_id = v_user
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  IF NOT (
    (v_o.status = 'delivered' AND COALESCE(v_o.delivered_at, v_o.updated_at) > now() - interval '72 hours')
    OR (v_o.status = 'shipped' AND COALESCE(v_o.shipped_at, v_o.updated_at) < now() - interval '7 days')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'dispute_not_allowed', 'status', v_o.status,
      'message', 'Réclamation possible dans les 72 h suivant la livraison, ou 7 jours après l''expédition si rien n''est arrivé.');
  END IF;

  RETURN app.mp_transition(p_order_id, 'disputed', v_user, 'student', v_reason);
END;
$$;

-- Detail etudiant : commande, articles, paiement, journal, delais, actions permises.
CREATE OR REPLACE FUNCTION public.app_student_get_marketplace_order_detail(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_o app.marketplace_orders%ROWTYPE;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF p_order_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_order_id');
  END IF;

  SELECT * INTO v_o
  FROM app.marketplace_orders o
  WHERE o.id = p_order_id AND o.student_id = v_user;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'order', to_jsonb(v_o),
    'payment', (
      SELECT jsonb_build_object('id', p.id, 'status', p.status, 'gross_amount', p.gross_amount,
                                'currency', p.currency, 'refunded_at', p.refunded_at)
      FROM app.marketplace_payments p
      WHERE p.order_id = p_order_id
      ORDER BY p.created_at DESC
      LIMIT 1
    ),
    'actions', jsonb_build_object(
      'can_pay', v_o.status = 'pending',
      'can_cancel', v_o.status IN ('pending', 'paid'),
      'can_confirm', v_o.status IN ('shipped', 'delivered'),
      'can_dispute',
        (v_o.status = 'delivered' AND COALESCE(v_o.delivered_at, v_o.updated_at) > now() - interval '72 hours')
        OR (v_o.status = 'shipped' AND COALESCE(v_o.shipped_at, v_o.updated_at) < now() - interval '7 days')
    ),
    'deadlines', jsonb_build_object(
      'pay_before', CASE WHEN v_o.status = 'pending' THEN v_o.created_at + interval '24 hours' END,
      'accept_before', CASE WHEN v_o.status = 'paid' THEN COALESCE(v_o.paid_at, v_o.updated_at) + interval '48 hours' END,
      'ship_before', CASE WHEN v_o.status = 'accepted' THEN COALESCE(v_o.accepted_at, v_o.updated_at) + interval '5 days' END,
      'auto_complete_at', CASE WHEN v_o.status = 'delivered' THEN COALESCE(v_o.delivered_at, v_o.updated_at) + interval '72 hours' END,
      'dispute_from', CASE WHEN v_o.status = 'shipped' THEN COALESCE(v_o.shipped_at, v_o.updated_at) + interval '7 days' END
    ),
    'events', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'to_status', e.to_status, 'actor_role', e.actor_role, 'note', e.note, 'created_at', e.created_at
      ) ORDER BY e.created_at), '[]'::jsonb)
      FROM app.marketplace_order_events e
      WHERE e.order_id = p_order_id
    ),
    'items', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', i.id, 'product_id', i.product_id, 'quantity', i.quantity,
        'unit_price', i.unit_price, 'currency', i.currency, 'title', l.title
      ) ORDER BY i.id), '[]'::jsonb)
      FROM app.marketplace_order_items i
      JOIN app.marketplace_listings l ON l.id = i.product_id
      WHERE i.order_id = p_order_id
    )
  );
END;
$$;

-- ===========================================================================
-- 8. RPC marchand
-- ===========================================================================
DROP FUNCTION IF EXISTS public.app_merchant_update_marketplace_order_status(uuid, text);

CREATE OR REPLACE FUNCTION public.app_merchant_update_marketplace_order_status(
  p_order_id uuid, p_status text, p_note text DEFAULT NULL
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_status text;
  v_current text;
  v_allowed text[];
  v_note text := NULLIF(btrim(COALESCE(p_note, '')), '');
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF p_order_id IS NULL OR p_status IS NULL OR btrim(p_status) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_params');
  END IF;
  IF public.app_get_current_role() <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  v_status := lower(btrim(p_status));
  IF v_status = 'canceled' THEN
    v_status := 'cancelled';
  END IF;

  SELECT o.status INTO v_current
  FROM app.marketplace_orders o
  WHERE o.id = p_order_id
    AND o.merchant_id IN (SELECT m.id FROM app.marketplace_merchants m WHERE m.owner_user_id = v_user)
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  IF v_current = v_status THEN
    RETURN jsonb_build_object('success', true, 'status', v_current, 'unchanged', true);
  END IF;

  v_allowed := app.mp_merchant_allowed_next(v_current);
  IF NOT (v_status = ANY (v_allowed)) THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_transition',
      'from', v_current, 'to', v_status, 'allowed', to_jsonb(v_allowed));
  END IF;

  IF v_status = 'cancelled' AND v_current IN ('paid', 'accepted') AND v_note IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'reason_required',
      'message', 'Indiquez le motif de l''annulation : il sera communiqué à l''acheteur.');
  END IF;

  RETURN app.mp_transition(p_order_id, v_status, v_user, 'merchant',
    COALESCE(v_note, CASE WHEN v_status = 'cancelled' THEN 'Annulée par le vendeur' END));
END;
$$;

CREATE OR REPLACE FUNCTION public.app_merchant_get_marketplace_order_detail(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_o app.marketplace_orders%ROWTYPE;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF p_order_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_order_id');
  END IF;
  IF public.app_get_current_role() <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  SELECT * INTO v_o
  FROM app.marketplace_orders o
  WHERE o.id = p_order_id
    AND o.merchant_id IN (SELECT m.id FROM app.marketplace_merchants m WHERE m.owner_user_id = v_user);

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'order', to_jsonb(v_o),
    'allowed_next', to_jsonb(app.mp_merchant_allowed_next(v_o.status)),
    'deadlines', jsonb_build_object(
      'accept_before', CASE WHEN v_o.status = 'paid' THEN COALESCE(v_o.paid_at, v_o.updated_at) + interval '48 hours' END,
      'ship_before', CASE WHEN v_o.status = 'accepted' THEN COALESCE(v_o.accepted_at, v_o.updated_at) + interval '5 days' END,
      'auto_complete_at', CASE WHEN v_o.status = 'delivered' THEN COALESCE(v_o.delivered_at, v_o.updated_at) + interval '72 hours' END
    ),
    'payment', (
      SELECT jsonb_build_object('status', p.status, 'gross_amount', p.gross_amount,
                                'commission_amount', ROUND(p.gross_amount * COALESCE(p.commission_rate, 0), 2),
                                'net_amount', p.gross_amount - ROUND(p.gross_amount * COALESCE(p.commission_rate, 0), 2),
                                'currency', p.currency)
      FROM app.marketplace_payments p
      WHERE p.order_id = p_order_id
      ORDER BY p.created_at DESC
      LIMIT 1
    ),
    'events', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'to_status', e.to_status, 'actor_role', e.actor_role, 'note', e.note, 'created_at', e.created_at
      ) ORDER BY e.created_at), '[]'::jsonb)
      FROM app.marketplace_order_events e
      WHERE e.order_id = p_order_id
    ),
    'items', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', i.id, 'product_id', i.product_id, 'quantity', i.quantity,
        'unit_price', i.unit_price, 'currency', i.currency, 'title', l.title
      ) ORDER BY i.id), '[]'::jsonb)
      FROM app.marketplace_order_items i
      JOIN app.marketplace_listings l ON l.id = i.product_id
      WHERE i.order_id = p_order_id
    )
  );
END;
$$;

-- Revenus marchand calcules sur les paiements reels et la file de versements.
CREATE OR REPLACE FUNCTION public.app_merchant_get_marketplace_earnings()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_ids uuid[];
  v_pay jsonb;
  v_out jsonb;
  v_phone text;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT array_agg(m.id), max(COALESCE(m.payout_phone, m.contact_phone))
  INTO v_ids, v_phone
  FROM app.marketplace_merchants m
  WHERE m.owner_user_id = v_user;

  SELECT jsonb_build_object(
    'in_escrow', COALESCE(sum(p.gross_amount - ROUND(p.gross_amount * COALESCE(p.commission_rate, 0), 2))
                          FILTER (WHERE p.status = 'captured'), 0),
    'orders_in_escrow', count(*) FILTER (WHERE p.status = 'captured'),
    'total_earned', COALESCE(sum(p.net_amount) FILTER (WHERE p.status = 'released'), 0),
    'total_commission', COALESCE(sum(p.commission_amount) FILTER (WHERE p.status = 'released'), 0),
    'total_refunded', COALESCE(sum(p.gross_amount) FILTER (WHERE p.status = 'refunded'), 0)
  )
  INTO v_pay
  FROM app.marketplace_payments p
  WHERE p.merchant_id = ANY (COALESCE(v_ids, ARRAY[]::uuid[]));

  SELECT jsonb_build_object(
    'paid_out', COALESCE(sum(q.amount) FILTER (WHERE q.status = 'completed'), 0),
    'payout_in_progress', COALESCE(sum(q.amount) FILTER (WHERE q.status IN ('pending', 'processing')), 0),
    'payout_waiting_phone', COALESCE(sum(q.amount) FILTER (WHERE q.status = 'waiting_phone'), 0),
    'payout_failed', COALESCE(sum(q.amount) FILTER (WHERE q.status = 'failed'), 0)
  )
  INTO v_out
  FROM app.payout_queue q
  WHERE q.beneficiary_type = 'merchant'
    AND q.beneficiary_user_id = ANY (COALESCE(v_ids, ARRAY[]::uuid[]));

  RETURN jsonb_build_object('success', true, 'currency', 'XOF', 'payout_phone', v_phone) || v_pay || v_out;
END;
$$;

-- ===========================================================================
-- 9. RPC admin
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.app_admin_resolve_marketplace_dispute(
  p_order_id uuid, p_decision text, p_note text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_status text;
  v_note text := NULLIF(btrim(COALESCE(p_note, '')), '');
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF public.app_get_current_role() NOT IN ('admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;
  IF p_decision NOT IN ('refund', 'release') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_decision');
  END IF;
  IF v_note IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'reason_required');
  END IF;

  SELECT status INTO v_status FROM app.marketplace_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;
  IF v_status <> 'disputed' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_disputed', 'status', v_status);
  END IF;

  RETURN app.mp_transition(p_order_id,
    CASE p_decision WHEN 'refund' THEN 'refunded' ELSE 'completed' END,
    v_user, 'admin', v_note);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_admin_cancel_marketplace_order(p_order_id uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_status text;
  v_reason text := NULLIF(btrim(COALESCE(p_reason, '')), '');
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF public.app_get_current_role() NOT IN ('admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;
  IF v_reason IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'reason_required');
  END IF;

  SELECT status INTO v_status FROM app.marketplace_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;
  IF v_status IN ('completed', 'cancelled', 'refunded', 'disputed') THEN
    RETURN jsonb_build_object('success', false, 'error', 'cancel_not_allowed', 'status', v_status);
  END IF;

  RETURN app.mp_transition(p_order_id, 'cancelled', v_user, 'admin', v_reason);
END;
$$;

CREATE OR REPLACE FUNCTION public.app_admin_get_marketplace_order_detail(p_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_o app.marketplace_orders%ROWTYPE;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF public.app_get_current_role() NOT IN ('admin', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  SELECT * INTO v_o FROM app.marketplace_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'order', to_jsonb(v_o),
    'student_name', (SELECT s.full_name FROM app.students s WHERE s.id = v_o.student_id),
    'merchant_name', (SELECT m.name FROM app.marketplace_merchants m WHERE m.id = v_o.merchant_id),
    'actions', jsonb_build_object(
      'can_resolve', v_o.status = 'disputed',
      'can_cancel', v_o.status NOT IN ('completed', 'cancelled', 'refunded', 'disputed')
    ),
    'payments', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', p.id, 'status', p.status, 'gross_amount', p.gross_amount,
        'commission_rate', p.commission_rate, 'phone_number', p.phone_number,
        'created_at', p.created_at, 'refunded_at', p.refunded_at, 'released_at', p.escrow_released_at
      ) ORDER BY p.created_at), '[]'::jsonb)
      FROM app.marketplace_payments p
      WHERE p.order_id = p_order_id
    ),
    'events', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'from_status', e.from_status, 'to_status', e.to_status, 'actor_role', e.actor_role,
        'note', e.note, 'created_at', e.created_at
      ) ORDER BY e.created_at), '[]'::jsonb)
      FROM app.marketplace_order_events e
      WHERE e.order_id = p_order_id
    ),
    'items', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', i.id, 'product_id', i.product_id, 'quantity', i.quantity,
        'unit_price', i.unit_price, 'currency', i.currency, 'title', l.title
      ) ORDER BY i.id), '[]'::jsonb)
      FROM app.marketplace_order_items i
      JOIN app.marketplace_listings l ON l.id = i.product_id
      WHERE i.order_id = p_order_id
    )
  );
END;
$$;

-- ===========================================================================
-- 10. Notifications hors commande
-- ===========================================================================
CREATE OR REPLACE FUNCTION app.mp_trg_listing_review_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_payload jsonb := jsonb_build_object('listing_id', NEW.id, 'review_status', NEW.review_status);
BEGIN
  IF NEW.review_status IS NOT DISTINCT FROM OLD.review_status THEN
    RETURN NEW;
  END IF;

  IF NEW.review_status = 'pending_review' THEN
    PERFORM app.mp_notify_admins('listing_submitted', '🆕 Annonce à valider',
      COALESCE(NULLIF(NEW.title, ''), 'Nouvelle annonce') || ' attend votre validation.', v_payload);
  ELSIF NEW.review_status = 'approved' THEN
    PERFORM app.mp_notify(NEW.merchant_id, 'merchant_marketplace', 'listing_approved',
      '✅ Annonce publiée',
      '« ' || COALESCE(NEW.title, 'Votre annonce') || ' » est validée et visible des étudiants.', v_payload);
  ELSIF NEW.review_status = 'rejected' THEN
    PERFORM app.mp_notify(NEW.merchant_id, 'merchant_marketplace', 'listing_rejected',
      '❌ Annonce refusée',
      '« ' || COALESCE(NEW.title, 'Votre annonce') || ' »'
      || COALESCE(' — motif : ' || NULLIF(btrim(NEW.review_reason), ''), '') || '. Corrigez-la puis soumettez-la à nouveau.',
      v_payload);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mp_listing_review_notify ON app.marketplace_listings;
CREATE TRIGGER trg_mp_listing_review_notify
  AFTER UPDATE OF review_status ON app.marketplace_listings
  FOR EACH ROW EXECUTE FUNCTION app.mp_trg_listing_review_notify();

CREATE OR REPLACE FUNCTION app.mp_trg_inquiry_created_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_title text;
BEGIN
  IF NEW.listing_id IS NULL OR NEW.merchant_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT title INTO v_title FROM app.marketplace_listings WHERE id = NEW.listing_id;

  PERFORM app.mp_notify(NEW.merchant_id, 'merchant_marketplace', 'new_inquiry',
    '❓ Nouvelle question' || COALESCE(' — ' || v_title, ''),
    COALESCE(NULLIF(left(btrim(NEW.message), 140), ''), 'Un étudiant vous a posé une question.'),
    jsonb_build_object('inquiry_id', NEW.id, 'listing_id', NEW.listing_id));

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mp_inquiry_created_notify ON app.opportunity_inquiries;
CREATE TRIGGER trg_mp_inquiry_created_notify
  AFTER INSERT ON app.opportunity_inquiries
  FOR EACH ROW EXECUTE FUNCTION app.mp_trg_inquiry_created_notify();

CREATE OR REPLACE FUNCTION app.mp_trg_review_created_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
DECLARE
  v_owner uuid;
  v_title text;
BEGIN
  SELECT merchant_id, title INTO v_owner, v_title
  FROM app.marketplace_listings WHERE id = NEW.listing_id;

  PERFORM app.mp_notify(v_owner, 'merchant_marketplace', 'new_review',
    '⭐ Nouvel avis (' || NEW.rating::text || '/5)',
    COALESCE(v_title, 'Votre annonce') || COALESCE(' — « ' || NULLIF(left(btrim(NEW.content), 100), '') || ' »', ''),
    jsonb_build_object('review_id', NEW.id, 'listing_id', NEW.listing_id));

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mp_review_created_notify ON app.marketplace_reviews;
CREATE TRIGGER trg_mp_review_created_notify
  AFTER INSERT ON app.marketplace_reviews
  FOR EACH ROW EXECUTE FUNCTION app.mp_trg_review_created_notify();

-- L'admin etait notifie a la creation (avant paiement) : remplace par `order_paid`.
DROP TRIGGER IF EXISTS trg_admin_marketplace_order_notify ON app.marketplace_orders;

-- ===========================================================================
-- 11. Securite
-- ===========================================================================
-- Ancienne liberation de sequestre : executable par tout utilisateur, y compris anonyme.
REVOKE ALL ON FUNCTION public.app_marketplace_release_escrow(uuid) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION app.mp_notify(uuid, text, text, text, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION app.mp_notify_admins(text, text, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION app.mp_release_funds(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION app.mp_refund_payment(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION app.mp_refund_order(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION app.mp_transition(uuid, text, uuid, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION app.mp_on_payment_captured(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION app.mp_run_sla() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION app.mp_trg_listing_review_notify() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION app.mp_trg_inquiry_created_notify() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION app.mp_trg_review_created_notify() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.app_student_cancel_marketplace_order(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.app_student_confirm_marketplace_order_received(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.app_student_open_marketplace_dispute(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.app_merchant_update_marketplace_order_status(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.app_merchant_get_marketplace_earnings() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.app_admin_resolve_marketplace_dispute(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.app_admin_cancel_marketplace_order(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.app_admin_get_marketplace_order_detail(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.app_student_cancel_marketplace_order(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_confirm_marketplace_order_received(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_student_open_marketplace_dispute(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_merchant_update_marketplace_order_status(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_merchant_get_marketplace_earnings() TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_resolve_marketplace_dispute(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_cancel_marketplace_order(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_get_marketplace_order_detail(uuid) TO authenticated;

-- ===========================================================================
-- 12. Cron
-- ===========================================================================
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'marketplace_sla';
SELECT cron.schedule('marketplace_sla', '*/15 * * * *', 'SELECT app.mp_run_sla();');
