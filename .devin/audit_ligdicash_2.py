"""Audit LigdiCash partie 2 - checks critiques"""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
headers = {"Authorization": f"Bearer {SERVICE_KEY}", "apikey": SERVICE_KEY, "Content-Type": "application/json"}

def sql(query, label):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=headers, json={"sql_query": query}, timeout=30)
    print(f"\n{'='*60}\n[{label}]\n{'='*60}")
    if r.status_code != 200:
        print(f"ERROR {r.status_code}: {r.text[:500]}")
        return
    data = r.json()
    if isinstance(data, list):
        for row in data:
            print(json.dumps(row, indent=2, ensure_ascii=False))
    elif data is not None:
        print(json.dumps(data, indent=2, ensure_ascii=False))
    else:
        print("(null)")

# 1. TOUTES les valeurs de TOUS les enums payment dans app ET public
sql("""
SELECT n.nspname||'.'||t.typname AS full_type, 
       string_agg(e.enumlabel, ', ' ORDER BY e.enumsortorder) AS values
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
JOIN pg_namespace n ON t.typnamespace = n.oid
WHERE t.typname IN ('payment_status','payment_reason','payment_channel')
GROUP BY n.nspname, t.typname ORDER BY full_type
""", "ENUMS payment TOUS SCHEMAS")

# 2. Type exact de la colonne channel, status, payment_reason dans application_payments
sql("""
SELECT column_name, data_type, udt_schema, udt_name
FROM information_schema.columns
WHERE table_schema='app' AND table_name='application_payments'
AND column_name IN ('status','payment_reason','channel','payment_method','phone_number',
                     'ligdicash_token','ligdicash_transaction_id','ligdicash_operator')
ORDER BY column_name
""", "TYPES EXACTS colonnes LigdiCash")

# 3. app_confirm_ligdicash_payment - CODE SOURCE COMPLET
sql("""
SELECT pg_get_functiondef(p.oid) AS source
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_confirm_ligdicash_payment'
""", "RPC app_confirm_ligdicash_payment SOURCE")

# 4. app_student_purchase_credits - CODE SOURCE COMPLET
sql("""
SELECT pg_get_functiondef(p.oid) AS source
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'app_student_purchase_credits'
""", "RPC app_student_purchase_credits SOURCE")

# 5. Secrets (noms seulement, pas les valeurs)
sql("""
SELECT name FROM vault.decrypted_secrets 
WHERE name LIKE 'LIGDICASH%' 
ORDER BY name
""", "SECRETS LIGDICASH (noms)")

# 6. Vérifier si le paiement de 25000 est bloqué en 'processing'
sql("""
SELECT id, status, channel, payment_method, amount_due, phone_number, payment_reason,
       ligdicash_token, ligdicash_transaction_id, ligdicash_operator
FROM app.application_payments 
WHERE id = 'b4b8692e-60b6-446d-88d8-53a741a71ba6'
""", "PAIEMENT 25000 BLOQUE EN PROCESSING")

print("\n\nAUDIT PART 2 DONE")
