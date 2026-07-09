import requests
import json
from datetime import datetime

base_url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
service_role_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

headers = {
    "apikey": service_role_key,
    "Authorization": f"Bearer {service_role_key}",
    "Content-Type": "application/json",
}

print("=" * 80)
print("AUDIT FIREBASE VIA POSTGREST API")
print("=" * 80)

# ========================================
# 1. Tenter de lire les tables de notification dans le schéma app
# ========================================
print("\n" + "=" * 80)
print("1. TEST LECTURE TABLES DANS SCHÉMA APP")
print("=" * 80)

tables_to_test = [
    "user_device_tokens",
    "notification_events",
    "user_notification_state"
]

for table in tables_to_test:
    print(f"\n--- Table: app.{table} ---")
    url = f"{base_url}/rest/v1/{table}?select=*&limit=1"
    resp = requests.get(url, headers=headers, timeout=30)
    print(f"  STATUS: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"  ✓ Table accessible, {len(data)} enregistrement(s) retourné(s)")
        if len(data) > 0:
            print(f"  Exemple de structure: {list(data[0].keys())}")
    else:
        print(f"  ✗ Erreur: {resp.text[:200]}")

# ========================================
# 2. Tenter de lire les tables dans le schéma public
# ========================================
print("\n" + "=" * 80)
print("2. TEST LECTURE TABLES DANS SCHÉMA PUBLIC")
print("=" * 80)

for table in tables_to_test:
    print(f"\n--- Table: public.{table} ---")
    url = f"{base_url}/rest/v1/{table}?select=*&limit=1"
    resp = requests.get(url, headers=headers, timeout=30)
    print(f"  STATUS: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        print(f"  ✓ Table accessible, {len(data)} enregistrement(s) retourné(s)")
    else:
        print(f"  ✗ Erreur: {resp.text[:200]}")

# ========================================
# 3. Lister les tables disponibles via pg_tables (via RPC)
# ========================================
print("\n" + "=" * 80)
print("3. LISTER LES TABLES VIA pg_tables")
print("=" * 80)

admin_url = f"{base_url}/rest/v1/rpc/admin_execute_sql"
sql = """
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename
LIMIT 50;
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
print(f"RESPONSE: {resp.text}")

# ========================================
# 4. Tester les RPCs de notification
# ========================================
print("\n" + "=" * 80)
print("4. TEST RPCs DE NOTIFICATION")
print("=" * 80)

rpcs_to_test = [
    "app_register_device_token",
    "app_unregister_device_token"
]

for rpc in rpcs_to_test:
    print(f"\n--- RPC: {rpc} ---")
    url = f"{base_url}/rest/v1/rpc/{rpc}"
    # Test avec des paramètres vides pour voir si la RPC existe
    resp = requests.post(url, headers=headers, json={}, timeout=30)
    print(f"  STATUS: {resp.status_code}")
    if resp.status_code == 200:
        print(f"  ✓ RPC existe")
    elif resp.status_code == 404:
        print(f"  ✗ RPC n'existe pas (404)")
    else:
        print(f"  ✗ Erreur: {resp.text[:200]}")

# ========================================
# 5. Rechercher les tables contenant "token" ou "notification"
# ========================================
print("\n" + "=" * 80)
print("5. RECHERCHE TABLES AVEC 'token' OU 'notification'")
print("=" * 80)

sql_search = """
SELECT 
    table_schema,
    table_name
FROM information_schema.tables
WHERE (table_name LIKE '%token%' OR table_name LIKE '%notification%' OR table_name LIKE '%device%')
AND table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name;
"""

resp = requests.post(admin_url, headers=headers, json={"p_sql": sql_search}, timeout=30)
print(f"STATUS: {resp.status_code}")
print(f"RESPONSE: {resp.text}")
