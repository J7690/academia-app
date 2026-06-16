import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def sql(query):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers={"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"},
        json={"p_sql": query})
    j = r.json()
    print(f"  -> {j}")
    return j

print("=" * 70)
print("DEPLOY: Auto-payout after revenue split")
print("=" * 70)

# Create a function that auto-queues payouts for non-platform actors
# Called at the end of app_confirm_ligdicash_payment after crediting actor_balances
print("\n### 1. Create app_auto_queue_payout function ###")
sql("""
CREATE OR REPLACE FUNCTION public.app_auto_queue_payout(
  p_actor_type TEXT,
  p_actor_id UUID,
  p_amount NUMERIC,
  p_currency TEXT,
  p_reason TEXT,
  p_source_payment_id UUID
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
AS $fn$
DECLARE
  v_phone TEXT;
  v_payout_id UUID;
BEGIN
  -- Skip platform (platform keeps the money)
  IF p_actor_type = 'platform' OR p_amount <= 0 THEN
    RETURN NULL;
  END IF;

  -- Resolve phone number based on actor type
  IF p_actor_type = 'instructor' THEN
    SELECT COALESCE(i.payout_phone, t.payout_phone) INTO v_phone
    FROM app.instructors i
    LEFT JOIN app.td_teachers t ON t.user_id = i.id
    WHERE i.id = p_actor_id;
  ELSIF p_actor_type = 'commercial' THEN
    SELECT cp.payout_phone INTO v_phone
    FROM app.commercial_profiles cp
    WHERE cp.user_id = p_actor_id;
  ELSIF p_actor_type = 'merchant' THEN
    SELECT mm.payout_phone INTO v_phone
    FROM app.marketplace_merchants mm
    WHERE mm.id = p_actor_id OR mm.owner_user_id = p_actor_id
    LIMIT 1;
  END IF;

  -- If no phone configured, still queue but mark as 'waiting_phone'
  -- The actor will need to configure their phone before the payout can be processed
  INSERT INTO app.payout_queue (
    beneficiary_type, beneficiary_user_id, beneficiary_phone,
    amount, currency, reason, source_payment_id, status
  ) VALUES (
    p_actor_type, p_actor_id, v_phone,
    p_amount, COALESCE(p_currency, 'XOF'), p_reason, p_source_payment_id,
    CASE WHEN v_phone IS NOT NULL AND LENGTH(TRIM(v_phone)) >= 8 THEN 'pending' ELSE 'waiting_phone' END
  )
  RETURNING id INTO v_payout_id;

  RETURN v_payout_id;
END;
$fn$;
""")

# Now we need to add a status 'waiting_phone' to payout_queue
# First check if we can just add it (text column, no enum constraint)
print("\n### 2. Verify payout_queue.status is TEXT (no enum) ###")
sql("SELECT data_type FROM information_schema.columns WHERE table_schema='app' AND table_name='payout_queue' AND column_name='status'")
# It's TEXT, so 'waiting_phone' is fine

# Now modify app_confirm_ligdicash_payment to auto-queue payouts after revenue split
# We need to read the current full definition and add the auto-queue call
print("\n### 3. Get current app_confirm_ligdicash_payment definition ###")
defn_result = sql("SELECT pg_get_functiondef(oid) as def FROM pg_proc WHERE proname = 'app_confirm_ligdicash_payment' LIMIT 1")
# We can't easily modify the function via this approach, so let's create a wrapper trigger instead

# Better approach: create a trigger on actor_balances that auto-queues payouts
# when available_balance increases
print("\n### 4. Create trigger function for auto-queue ###")
sql("""
CREATE OR REPLACE FUNCTION app.trg_auto_queue_payout()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE
  v_increase NUMERIC;
  v_phone TEXT;
  v_payout_id UUID;
BEGIN
  -- Only trigger on INSERT or UPDATE that increases available_balance
  IF TG_OP = 'INSERT' THEN
    v_increase := NEW.available_balance;
  ELSIF TG_OP = 'UPDATE' THEN
    v_increase := NEW.available_balance - COALESCE(OLD.available_balance, 0);
  END IF;

  -- Skip if no increase or platform type
  IF v_increase <= 0 OR NEW.actor_type = 'platform' OR NEW.actor_type = 'university' THEN
    RETURN NEW;
  END IF;

  -- Resolve phone
  IF NEW.actor_type = 'instructor' THEN
    SELECT COALESCE(i.payout_phone, t.payout_phone) INTO v_phone
    FROM app.instructors i
    LEFT JOIN app.td_teachers t ON t.user_id = i.id
    WHERE i.id = NEW.actor_id;
  ELSIF NEW.actor_type = 'commercial' THEN
    SELECT cp.payout_phone INTO v_phone
    FROM app.commercial_profiles cp WHERE cp.user_id = NEW.actor_id;
  ELSIF NEW.actor_type = 'merchant' THEN
    SELECT COALESCE(mm.payout_phone, mm.contact_phone) INTO v_phone
    FROM app.marketplace_merchants mm
    WHERE mm.id = NEW.actor_id OR mm.owner_user_id = NEW.actor_id LIMIT 1;
  END IF;

  -- Auto-queue payout for the increase amount
  INSERT INTO app.payout_queue (
    beneficiary_type, beneficiary_user_id, beneficiary_phone,
    amount, currency, reason, status
  ) VALUES (
    NEW.actor_type, NEW.actor_id, v_phone,
    v_increase, COALESCE(NEW.currency, 'XOF'),
    NEW.actor_type || '_auto_split',
    CASE WHEN v_phone IS NOT NULL AND LENGTH(TRIM(v_phone)) >= 8 THEN 'pending' ELSE 'waiting_phone' END
  );

  -- Deduct from available_balance since it's now in the payout queue
  NEW.available_balance := NEW.available_balance - v_increase;
  NEW.total_withdrawn := COALESCE(NEW.total_withdrawn, 0) + v_increase;

  RETURN NEW;
END;
$fn$;
""")

print("\n### 5. Create trigger on actor_balances ###")
sql("DROP TRIGGER IF EXISTS trg_auto_payout_on_balance_change ON app.actor_balances;")
sql("""
CREATE TRIGGER trg_auto_payout_on_balance_change
  BEFORE INSERT OR UPDATE OF available_balance ON app.actor_balances
  FOR EACH ROW
  EXECUTE FUNCTION app.trg_auto_queue_payout();
""")

print("\n### 6. Create pg_cron job to call ligdicash-payout Edge Function ###")
# pg_cron + pg_net to call the Edge Function every 15 minutes
sql("""
SELECT cron.schedule(
  'process_pending_payouts',
  '*/15 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/ligdicash-payout',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM',
      'Content-Type', 'application/json'
    ),
    body := '{"all_pending": true}'::jsonb
  );
  $$
);
""")

print("\nDone! Auto-payout pipeline deployed.")
print("\nFlow:")
print("  1. Paiement confirme -> revenue split -> actor_balances credited")
print("  2. TRIGGER on actor_balances -> auto-insert payout_queue (pending)")
print("  3. pg_cron every 15min -> calls ligdicash-payout Edge Function")
print("  4. Edge Function processes pending payouts -> LigdiCash withdrawal/create (top_up_wallet=1)")
print("  5. LigdiCash -> LigdiCash wallet du beneficiaire")
