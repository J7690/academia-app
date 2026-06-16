#!/usr/bin/env python3
"""
Diagnostic approfondi LigdiCash:
- Enum payment_status (manque 'processing' ?)
- Contraintes sur application_payments
- Le paiement ab8dc18d bloque
- Test API LigdiCash via Edge Function helper
"""

import requests, json, time

SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6"
    "InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ"
    ".U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
)
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

def sql(query, label=""):
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": query},
        timeout=30,
    )
    try:
        data = r.json()
    except:
        data = r.text[:500]
    if label:
        ok = r.status_code == 200
        print(f"  {'[OK]' if ok else '[ERR]'} {label}")
        if not ok:
            print(f"       {str(data)[:300]}")
    return data

def ddl(query, label=""):
    r = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/execute_ddl",
        headers=HEADERS,
        json={"ddl_query": query},
        timeout=30,
    )
    try:
        data = r.json()
    except:
        data = r.text[:300]
    ok = r.status_code == 200
    if label:
        print(f"  {'[OK]' if ok else '[ERR]'} {label}: {str(data)[:200]}")
    return ok, data


print("=" * 65)
print("  DIAGNOSTIC LIGDICASH - ANALYSE APPROFONDIE")
print("=" * 65)

# 1. Enum payment_status
print("\n[1/8] Valeurs de l'enum payment_status...")
data = sql("""
SELECT e.enumlabel
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_namespace n ON t.typnamespace = n.oid
WHERE t.typname = 'payment_status'
ORDER BY e.enumsortorder
""", "payment_status enum values")
print(f"  -> {json.dumps(data, indent=2)}")
if isinstance(data, list):
    labels = [r.get("enumlabel") for r in data]
    print(f"  Valeurs: {labels}")
    if "processing" not in labels:
        print("  *** ALERTE: 'processing' N'EXISTE PAS dans l'enum! ***")
        print("  -> L'Edge Function ligdicash-initiate essaie de mettre status='processing'")
        print("  -> Cette mise a jour ECHOUE silencieusement!")

# 2. Enum payment_channel
print("\n[2/8] Valeurs de l'enum payment_channel...")
data = sql("""
SELECT e.enumlabel
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
JOIN pg_namespace n ON t.typnamespace = n.oid
WHERE t.typname = 'payment_channel'
ORDER BY e.enumsortorder
""", "payment_channel enum values")
if isinstance(data, list):
    labels = [r.get("enumlabel") for r in data]
    print(f"  Valeurs: {labels}")
    if "ligdicash" not in labels:
        print("  *** ALERTE: 'ligdicash' N'EXISTE PAS dans payment_channel! ***")

# 3. Colonne status - type exact
print("\n[3/8] Type exact de la colonne status dans application_payments...")
data = sql("""
SELECT column_name, data_type, udt_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'application_payments'
AND column_name IN ('status', 'channel', 'payment_method', 'phone_number')
ORDER BY column_name
""", "column types")
if isinstance(data, list):
    for row in data:
        print(f"  {row.get('column_name')}: type={row.get('udt_name')} nullable={row.get('is_nullable')}")

# 4. Check constraints
print("\n[4/8] Contraintes CHECK sur application_payments...")
data = sql("""
SELECT con.conname, pg_get_constraintdef(con.oid) AS def
FROM pg_constraint con
JOIN pg_class rel ON con.conrelid = rel.oid
JOIN pg_namespace nsp ON rel.relnamespace = nsp.oid
WHERE nsp.nspname = 'app' AND rel.relname = 'application_payments'
AND con.contype = 'c'
""", "check constraints")
if isinstance(data, list):
    for row in data:
        print(f"  {row.get('conname')}: {row.get('def')}")

# 5. Details du paiement bloque
print("\n[5/8] Detail du paiement ab8dc18d (credit_purchase 100F)...")
data = sql("""
SELECT *
FROM app.application_payments
WHERE id::text LIKE 'ab8dc18d%'
""", "payment detail")
if isinstance(data, list) and len(data) > 0:
    for k, v in data[0].items():
        print(f"  {k}: {v}")

# 6. RLS policies sur application_payments
print("\n[6/8] RLS policies sur application_payments...")
data = sql("""
SELECT polname, polcmd, pg_get_expr(polqual, polrelid) AS using_expr,
       pg_get_expr(polwithcheck, polrelid) AS check_expr
FROM pg_policy
JOIN pg_class ON pg_policy.polrelid = pg_class.oid
JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
WHERE pg_namespace.nspname = 'app' AND pg_class.relname = 'application_payments'
""", "RLS policies")
if isinstance(data, list):
    for row in data:
        print(f"  Policy: {row.get('polname')} cmd={row.get('polcmd')}")
        print(f"    using={row.get('using_expr','')[:150]}")
        print(f"    check={row.get('check_expr','')[:150]}")

# 7. Verifier si le payment_method est un enum aussi
print("\n[7/8] Type de payment_method...")
data = sql("""
SELECT column_name, udt_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app' AND table_name = 'application_payments'
AND column_name = 'payment_method'
""", "payment_method type")
if isinstance(data, list):
    for row in data:
        print(f"  payment_method: udt={row.get('udt_name')} data_type={row.get('data_type')}")

# 8. Tester manuellement une mise a jour du status
print("\n[8/8] Test: mettre status='processing' sur un paiement...")
data = sql("""
UPDATE app.application_payments
SET status = 'processing'
WHERE id::text LIKE 'ab8dc18d%'
RETURNING id, status
""", "test update to processing")
print(f"  -> {data}")

print("\n" + "=" * 65)
print("  FIN DIAGNOSTIC APPROFONDI")
print("=" * 65)
