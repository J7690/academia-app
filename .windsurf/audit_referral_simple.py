"""
Audit simple du système de référenciation
"""

import requests
import json
import time

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== AUDIT SYSTÈME RÉFÉRENCIATION ===\n")

# Requête unique pour trouver toutes les tables liées aux références
sql = """
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
AND (table_name LIKE '%referral%' OR table_name LIKE '%ref%' OR table_name LIKE '%commission%')
ORDER BY table_name;
"""

print("Recherche des tables de référenciation...")
try:
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    print(f"Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        if data.get("ok") and data.get("rows"):
            print(f"Tables trouvées ({len(data['rows'])}):")
            for row in data["rows"]:
                print(f"  - {row['table_name']}")
        else:
            print("Aucune table trouvée")
            print(f"Response: {resp.text}")
    else:
        print(f"Erreur: {resp.text}")
except Exception as e:
    print(f"Exception: {e}")

time.sleep(2)

# Vérifier la structure de referral_commissions si elle existe
print("\n=== Vérification referral_commissions ===")
sql = """
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name = 'referral_commissions'
ORDER BY ordinal_position;
"""

try:
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    print(f"Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        if data.get("ok") and data.get("rows"):
            print("Colonnes de referral_commissions:")
            for row in data["rows"]:
                print(f"  - {row['column_name']}: {row['data_type']}")
        else:
            print("Table non trouvée ou vide")
    else:
        print(f"Erreur: {resp.text}")
except Exception as e:
    print(f"Exception: {e}")

time.sleep(2)

# Vérifier les colonnes de référenciation dans students
print("\n=== Colonnes de référenciation dans students ===")
sql = """
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name = 'students'
AND (column_name LIKE '%ref%' OR column_name LIKE '%commercial%')
ORDER BY column_name;
"""

try:
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    print(f"Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        if data.get("ok") and data.get("rows"):
            print("Colonnes trouvées:")
            for row in data["rows"]:
                print(f"  - {row['column_name']}: {row['data_type']}")
        else:
            print("Aucune colonne trouvée")
    else:
        print(f"Erreur: {resp.text}")
except Exception as e:
    print(f"Exception: {e}")

print("\n=== AUDIT TERMINÉ ===")
