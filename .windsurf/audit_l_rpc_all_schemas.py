import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== RECHERCHE RPCs DANS TOUS LES SCHÉMAS ===\n")

# Schémas à vérifier
schemas = ['public', 'app', 'storage', 'auth', 'extensions']

# Fonctions à chercher
functions = ['app_videoasset_create_upload_intent', 'app_videoasset_register_uploaded_source']

for schema in schemas:
    print(f"--- SCHÉMA: {schema} ---")
    for func in functions:
        sql = f"""
        SELECT pg_get_functiondef(oid) as definition
        FROM pg_proc 
        WHERE proname = '{func.replace('app_', '')}'
        AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = '{schema}')
        """
        resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
        if resp.status_code == 200:
            data = resp.json()
            if data.get("ok") and data.get("rows"):
                print(f"  {func}: TROUVÉ")
                print(f"  Définition: {data['rows'][0]['definition'][:200]}...")
            else:
                print(f"  {func}: NON TROUVÉ")
        else:
            print(f"  {func}: ERREUR {resp.status_code}")
    print()

# Recherche alternative sans restriction de schéma
print("=== RECHERCHE SANS RESTRICTION DE SCHÉMA ===\n")
for func in functions:
    sql = f"""
    SELECT pg_get_functiondef(oid) as definition, 
           n.nspname as schema_name
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = '{func.replace('app_', '')}'
    """
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    if resp.status_code == 200:
        data = resp.json()
        if data.get("ok") and data.get("rows"):
            print(f"{func}: TROUVÉ dans schéma {data['rows'][0]['schema_name']}")
        else:
            print(f"{func}: NON TROUVÉ dans aucun schéma")
    else:
        print(f"{func}: ERREUR {resp.status_code}")
