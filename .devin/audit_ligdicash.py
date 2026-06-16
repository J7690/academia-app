"""
Audit complet du dispositif LigdiCash dans Supabase
- Enums payment_status, payment_reason, payment_channel
- Table application_payments: colonnes pertinentes
- RPC app_confirm_ligdicash_payment: existence + signature + code source
- Secrets Edge Functions (listés, pas les valeurs)
- Edge Functions déployées
"""
import requests, json, sys

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

headers = {
    "Authorization": f"Bearer {SERVICE_KEY}",
    "apikey": SERVICE_KEY,
    "Content-Type": "application/json",
}

def sql(query, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/execute_sql", headers=headers, json={"sql_query": query}, timeout=30)
    if r.status_code != 200:
        print(f"[ERROR] {label}: {r.status_code} {r.text[:300]}")
        return None
    data = r.json()
    print(f"\n{'='*60}")
    print(f"[{label}]")
    print(f"{'='*60}")
    if isinstance(data, list):
        for row in data:
            print(json.dumps(row, indent=2, ensure_ascii=False))
    elif data is not None:
        print(json.dumps(data, indent=2, ensure_ascii=False))
    else:
        print("(null)")
    return data

# 1. Enums payment
sql("""
SELECT n.nspname AS schema, t.typname AS enum_name, 
       string_agg(e.enumlabel, ', ' ORDER BY e.enumsortorder) AS values
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
JOIN pg_namespace n ON t.typnamespace = n.oid
WHERE n.nspname = 'app' AND t.typname IN ('payment_status','payment_reason','payment_channel')
GROUP BY n.nspname, t.typname
ORDER BY t.typname
""", "ENUMS payment (app schema)")

# 2. Colonnes application_payments
sql("""
SELECT column_name, data_type, udt_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'application_payments'
ORDER BY ordinal_position
""", "TABLE application_payments - colonnes")

# 3. RPC app_confirm_ligdicash_payment - existence + signature
sql("""
SELECT p.proname AS function_name,
       pg_get_function_arguments(p.oid) AS arguments,
       pg_get_function_result(p.oid) AS return_type,
       p.prosecdef AS security_definer
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname IN ('app','public') AND p.proname = 'app_confirm_ligdicash_payment'
""", "RPC app_confirm_ligdicash_payment - signature")

# 4. RPC app_confirm_ligdicash_payment - code source complet
sql("""
SELECT pg_get_functiondef(p.oid) AS source
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname IN ('app','public') AND p.proname = 'app_confirm_ligdicash_payment'
""", "RPC app_confirm_ligdicash_payment - CODE SOURCE")

# 5. RPC app_student_purchase_credits - existence + code
sql("""
SELECT pg_get_functiondef(p.oid) AS source
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname IN ('app','public') AND p.proname = 'app_student_purchase_credits'
""", "RPC app_student_purchase_credits - CODE SOURCE")

# 6. RPC app_student_create_profile_payment - existence + code
sql("""
SELECT pg_get_functiondef(p.oid) AS source
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname IN ('app','public') AND p.proname = 'app_student_create_profile_payment'
""", "RPC app_student_create_profile_payment - CODE SOURCE")

# 7. Paiements récents avec status
sql("""
SELECT id, status, payment_reason, channel, payment_method, amount_due, phone_number, 
       ligdicash_token, ligdicash_transaction_id, created_at, updated_at
FROM app.application_payments
ORDER BY created_at DESC
LIMIT 10
""", "10 derniers paiements application_payments")

# 8. Colonnes ligdicash-specific dans application_payments
sql("""
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'application_payments'
AND column_name LIKE '%ligdi%' OR column_name IN ('phone_number','payment_method','channel','reference_code')
ORDER BY column_name
""", "Colonnes LigdiCash dans application_payments")

# 9. Check if credit_purchase is in payment_reason enum
sql("""
SELECT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'app' AND t.typname = 'payment_reason' AND e.enumlabel = 'credit_purchase'
) AS credit_purchase_exists
""", "ENUM payment_reason contient 'credit_purchase' ?")

# 10. Check if 'ligdicash' is in payment_channel enum
sql("""
SELECT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'app' AND t.typname = 'payment_channel' AND e.enumlabel = 'ligdicash'
) AS ligdicash_channel_exists
""", "ENUM payment_channel contient 'ligdicash' ?")

# 11. Check if 'processing' is in payment_status enum
sql("""
SELECT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'app' AND t.typname = 'payment_status' AND e.enumlabel = 'processing'
) AS processing_status_exists
""", "ENUM payment_status contient 'processing' ?")

print("\n\n" + "="*60)
print("AUDIT TERMINÉ")
print("="*60)
