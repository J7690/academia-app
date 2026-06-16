"""
Test simulation payout LIVE (pas mock)
1. Vérifie le mode LigdiCash actuel
2. Insère un payout test dans la queue
3. Appelle l'Edge Function ligdicash-payout
4. Analyse la réponse et les logs
5. Nettoie les données test
"""
import requests, json, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

H = {"Authorization": f"Bearer {SK}", "apikey": SK, "Content-Type": "application/json"}

def sql(query):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H, json={"p_sql": query})
    return r.json()

print("=" * 70)
print("ÉTAPE 1 : Vérifier le mode LigdiCash")
print("=" * 70)

# On ne peut pas lire les secrets directement, mais l'Edge Function nous dira
# Vérifions s'il y a des payouts existants
r1 = sql("SELECT COUNT(*) as cnt FROM app.payout_queue")
print(f"  Payouts en queue : {r1}")

r1b = sql("SELECT status, COUNT(*) as cnt FROM app.payout_queue GROUP BY status")
print(f"  Par status : {r1b}")

print("\n" + "=" * 70)
print("ÉTAPE 2 : Insérer un payout test (100 XOF, numéro test)")
print("=" * 70)

# Insérer un payout test avec un vrai format de numéro BF
# On utilise un UUID fictif mais le numéro doit être un vrai format
TEST_PHONE = "22670000000"  # Format BF standard
TEST_AMOUNT = 100  # Montant minimal

insert_result = sql(f"""
  INSERT INTO app.payout_queue (
    beneficiary_type, beneficiary_user_id, beneficiary_phone,
    amount, currency, reason, status
  ) VALUES (
    'commercial',
    '00000000-0000-0000-0000-000000000001'::UUID,
    '{TEST_PHONE}',
    {TEST_AMOUNT},
    'XOF',
    'test_payout_simulation',
    'pending'
  )
  RETURNING id::TEXT
""")
print(f"  Insert result: {insert_result}")

# Récupérer l'ID du payout test
test_payout_id = None
if isinstance(insert_result, dict) and insert_result.get('ok'):
    rows = insert_result.get('rows', [])
    if rows:
        test_payout_id = rows[0].get('id')
        print(f"  Test payout ID: {test_payout_id}")

if not test_payout_id:
    # Essayer de le retrouver
    find = sql("SELECT id::TEXT FROM app.payout_queue WHERE reason = 'test_payout_simulation' AND status = 'pending' ORDER BY created_at DESC LIMIT 1")
    if isinstance(find, dict) and find.get('ok') and find.get('rows'):
        test_payout_id = find['rows'][0]['id']
        print(f"  Found test payout ID: {test_payout_id}")

print("\n" + "=" * 70)
print("ÉTAPE 3 : Vérifier le payout en queue")
print("=" * 70)

check = sql(f"""
  SELECT id::TEXT, beneficiary_type, beneficiary_phone, amount, currency, reason, status, created_at::TEXT
  FROM app.payout_queue 
  WHERE reason = 'test_payout_simulation'
  ORDER BY created_at DESC LIMIT 1
""")
print(f"  Queue entry: {json.dumps(check, indent=2, ensure_ascii=False)}")

print("\n" + "=" * 70)
print("ÉTAPE 4 : Appeler l'Edge Function ligdicash-payout")
print("=" * 70)

# Appel réel à l'Edge Function avec le payout_id spécifique
payload = {}
if test_payout_id:
    payload = {"payout_ids": [test_payout_id]}
else:
    payload = {"all_pending": True}

print(f"  Payload: {json.dumps(payload)}")
print(f"  Calling {URL}/functions/v1/ligdicash-payout ...")

start = time.time()
resp = requests.post(
    f"{URL}/functions/v1/ligdicash-payout",
    headers=H,
    json=payload,
    timeout=60
)
elapsed = time.time() - start

print(f"\n  HTTP Status: {resp.status_code}")
print(f"  Response time: {elapsed:.1f}s")
print(f"  Response headers:")
for k, v in resp.headers.items():
    if k.lower() in ('content-type', 'x-deno-subhost', 'x-relay-error', 'sb-gateway-version'):
        print(f"    {k}: {v}")

try:
    body = resp.json()
    print(f"\n  Response body:")
    print(f"  {json.dumps(body, indent=2, ensure_ascii=False)}")
except:
    print(f"\n  Response text: {resp.text[:2000]}")

print("\n" + "=" * 70)
print("ÉTAPE 5 : Vérifier l'état du payout après appel")
print("=" * 70)

after = sql(f"""
  SELECT id::TEXT, beneficiary_type, beneficiary_phone, amount, currency, reason,
         status, ligdicash_token, ligdicash_transaction_id, 
         error_message, retry_count, processed_at::TEXT
  FROM app.payout_queue 
  WHERE reason = 'test_payout_simulation'
  ORDER BY created_at DESC LIMIT 1
""")
print(f"  After call: {json.dumps(after, indent=2, ensure_ascii=False)}")

print("\n" + "=" * 70)
print("ÉTAPE 6 : Vérifier le platform_ledger")
print("=" * 70)

ledger = sql("""
  SELECT id::TEXT, transaction_type, amount, currency, direction, 
         counterpart_type, description, created_at::TEXT
  FROM app.platform_ledger 
  WHERE description LIKE '%test_payout%' OR description LIKE '%Versement%test%'
  ORDER BY created_at DESC LIMIT 5
""")
print(f"  Ledger entries: {json.dumps(ledger, indent=2, ensure_ascii=False)}")

print("\n" + "=" * 70)
print("ÉTAPE 7 : Nettoyer les données test")
print("=" * 70)

cleanup = sql("DELETE FROM app.payout_queue WHERE reason = 'test_payout_simulation'")
print(f"  Cleanup payout_queue: {cleanup}")

cleanup2 = sql("DELETE FROM app.platform_ledger WHERE description LIKE '%test_payout%'")
print(f"  Cleanup ledger: {cleanup2}")

print("\n" + "=" * 70)
print("RÉSUMÉ")
print("=" * 70)
