"""
Script RPC administrateur pour diagnostiquer le schéma app
Mission Critique – Diagnostic RPC
"""

import requests
import json

# Configuration
url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== VÉRIFICATION SCHÉMA APP ===\n")

# Vérifier si le schéma app existe
sql = "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'app'"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if data.get("ok") and data.get("rows"):
    print("✅ Schéma app existe")
else:
    print("❌ Schéma app n'existe pas")

print("\n=== LISTE DES SCHÉMAS ===\n")

sql = "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('pg_catalog', 'information_schema') ORDER BY schema_name"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
if data.get("ok") and data.get("rows"):
    print("Schémas disponibles:")
    for row in data["rows"]:
        print(f"  {row['schema_name']}")
else:
    print("❌ Schémas non trouvés")

print("\n=== TEST : CREATE TABLE DANS SCHÉMA APP (SET SEARCH_PATH) ===\n")

# Test : créer une table dans le schéma app avec SET SEARCH_PATH
sql = "SET search_path TO app, public; CREATE TABLE whiteboard_test2 (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT)"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if data.get("ok"):
    print("✅ CREATE TABLE retourne ok")
else:
    print("❌ CREATE TABLE échoue")

# Vérifier si la table existe
sql = "SELECT table_name FROM information_schema.tables WHERE table_name = 'whiteboard_test2' AND table_schema = 'app'"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if data.get("ok") and data.get("rows"):
    print("✅ Table existe dans schéma app")
else:
    print("❌ Table n'existe pas dans schéma app")

print("\n=== TEST : CREATE TABLE DANS SCHÉMA APP (EXPLICIT) ===\n")

# Test : créer une table avec le schéma explicite
sql = "CREATE TABLE app.whiteboard_test3 (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT)"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if data.get("ok"):
    print("✅ CREATE TABLE retourne ok")
else:
    print("❌ CREATE TABLE échoue")

# Vérifier si la table existe
sql = "SELECT table_name FROM information_schema.tables WHERE table_name = 'whiteboard_test3' AND table_schema = 'app'"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if data.get("ok") and data.get("rows"):
    print("✅ Table existe dans schéma app")
else:
    print("❌ Table n'existe pas dans schéma app")

print("\n=== NETTOYAGE ===\n")

sql = "DROP TABLE IF EXISTS app.whiteboard_test2, app.whiteboard_test3"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("Status Code:", resp.status_code)
print("Response:", resp.text)
