"""
Audit direct des tables de référenciation
"""

import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== AUDIT DIRECT TABLES RÉFÉRENCIATION ===\n")

# Test 1: commission_rules (selon mémoire)
print("Test 1: COUNT app.commission_rules")
sql = "SELECT COUNT(*) as total FROM app.commission_rules;"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print(f"✅ Table existe - {data['rows'][0]['total']} enregistrements")
    else:
        print("❌ Table vide ou erreur")
print()

# Test 2: referral_commissions (selon mémoire)
print("Test 2: COUNT app.referral_commissions")
sql = "SELECT COUNT(*) as total FROM app.referral_commissions;"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print(f"✅ Table existe - {data['rows'][0]['total']} enregistrements")
    else:
        print("❌ Table vide ou erreur")
print()

# Test 3: commercial_profiles
print("Test 3: COUNT app.commercial_profiles")
sql = "SELECT COUNT(*) as total FROM app.commercial_profiles;"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print(f"✅ Table existe - {data['rows'][0]['total']} enregistrements")
    else:
        print("❌ Table vide ou erreur")
print()

# Test 4: students
print("Test 4: COUNT app.students")
sql = "SELECT COUNT(*) as total FROM app.students;"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print(f"✅ Table existe - {data['rows'][0]['total']} enregistrements")
    else:
        print("❌ Table vide ou erreur")
print()

# Test 5: Vérifier si students a une colonne referred_by
print("Test 5: SELECT referred_by FROM app.students LIMIT 1")
sql = "SELECT referred_by FROM app.students LIMIT 1;"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok"):
        print("✅ Colonne referred_by existe")
        if data.get("rows"):
            print(f"   Valeur exemple: {data['rows'][0]['referred_by']}")
        else:
            print("   (table vide)")
    else:
        print("❌ Colonne n'existe pas")
print()

# Test 6: Vérifier les données de referral_commissions
print("Test 6: SELECT * FROM app.referral_commissions LIMIT 5")
sql = "SELECT * FROM app.referral_commissions LIMIT 5;"
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Response: {resp.text}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print(f"✅ {len(data['rows'])} enregistrements trouvés")
        for row in data["rows"]:
            print(f"   {json.dumps(row, default=str)}")
    else:
        print("❌ Table vide ou erreur")
print()

print("=== AUDIT TERMINÉ ===")
