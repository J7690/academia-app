"""
Script RPC administrateur pour diagnostiquer admin_execute_sql
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

print("=== ÉTAPE 1 : DÉFINITION DE ADMIN_EXECUTE_SQL ===\n")

# Vérifier la définition de l'RPC
sql = """
SELECT 
  routine_name,
  routine_type,
  data_type,
  external_language,
  security_type
FROM information_schema.routines 
WHERE routine_schema = 'app' 
AND routine_name = 'admin_execute_sql'
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if data.get("ok") and data.get("rows"):
    print("Définition trouvée:")
    for row in data["rows"]:
        print(f"  {row}")
else:
    print("❌ Définition non trouvée")

print("\n=== ÉTAPE 2 : CODE SOURCE DE ADMIN_EXECUTE_SQL ===\n")

# Vérifier le code source de l'RPC
sql = """
SELECT pg_get_functiondef(oid)
FROM pg_proc 
WHERE proname = 'admin_execute_sql'
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'app')
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if data.get("ok") and data.get("rows"):
    print("Code source:")
    for row in data["rows"]:
        print(f"  {row['pg_get_functiondef']}")
else:
    print("❌ Code source non trouvé")

print("\n=== ÉTAPE 3 : TEST MINIMAL - SELECT SIMPLE ===\n")

# Test minimal : SELECT simple
sql = "SELECT 1 as test"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if data.get("ok") and data.get("rows"):
    print("✅ SELECT simple fonctionne")
    print("Résultat:", data["rows"])
else:
    print("❌ SELECT simple échoue")

print("\n=== ÉTAPE 4 : TEST MINIMAL - SELECT CURRENT_USER ===\n")

# Test : vérifier l'utilisateur actuel
sql = "SELECT current_user, current_database(), current_schema()"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if data.get("ok") and data.get("rows"):
    print("✅ Contexte utilisateur:")
    for row in data["rows"]:
        print(f"  User: {row['current_user']}")
        print(f"  Database: {row['current_database']}")
        print(f"  Schema: {row['current_schema']}")
else:
    print("❌ Contexte utilisateur échoue")

print("\n=== ÉTAPE 5 : TEST MINIMAL - CREATE TEMP TABLE ===\n")

# Test : créer une table temporaire
sql = "CREATE TEMP TABLE diagnostic_test (id SERIAL PRIMARY KEY, name TEXT)"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if data.get("ok"):
    print("✅ CREATE TEMP TABLE retourne ok")
else:
    print("❌ CREATE TEMP TABLE échoue")

# Vérifier si la table temporaire existe
sql = "SELECT table_name FROM information_schema.tables WHERE table_name = 'diagnostic_test' AND table_schema = 'pg_temp'"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if data.get("ok") and data.get("rows"):
    print("✅ Table temporaire existe")
else:
    print("❌ Table temporaire n'existe pas")

print("\n=== ÉTAPE 6 : TEST MINIMAL - CREATE TABLE PERMANENTE ===\n")

# Test : créer une table permanente
sql = "CREATE TABLE app.diagnostic_test (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT)"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if data.get("ok"):
    print("✅ CREATE TABLE retourne ok")
else:
    print("❌ CREATE TABLE échoue")

# Vérifier si la table permanente existe
sql = "SELECT table_name FROM information_schema.tables WHERE table_name = 'diagnostic_test' AND table_schema = 'app'"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()
print("Status Code:", resp.status_code)
print("Response:", resp.text)
if data.get("ok") and data.get("rows"):
    print("✅ Table permanente existe")
else:
    print("❌ Table permanente n'existe pas")

print("\n=== ÉTAPE 7 : NETTOYAGE ===\n")

# Nettoyer
sql = "DROP TABLE IF EXISTS app.diagnostic_test"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print("Status Code:", resp.status_code)
print("Response:", resp.text)
