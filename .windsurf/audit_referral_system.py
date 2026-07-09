"""
Audit du système de référenciation des prospects commerciaux
Objectif: Vérifier la structure et les données de user_referrals
"""

import requests
import json
from datetime import datetime

# Configuration
url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

# Fichier de sortie
output_file = "logs/audit_referral_system_output.txt"
with open(output_file, "w", encoding="utf-8") as f:
    f.write("=" * 80 + "\n")
    f.write("AUDIT DU SYSTÈME DE RÉFÉRENCIATION DES PROSPECTS COMMERCIAUX\n")
    f.write(f"Date: {datetime.now().isoformat()}\n")
    f.write("=" * 80 + "\n\n")

# ÉTAPE 1: Vérifier la structure de la table user_referrals
print("\n=== ÉTAPE 1: STRUCTURE DE LA TABLE user_referrals ===\n")
sql = """
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name = 'user_referrals'
ORDER BY ordinal_position;
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print("Colonnes de user_referrals:")
        for row in data["rows"]:
            print(f"  - {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']})")
    else:
        print("❌ Erreur ou pas de données")
else:
    print(f"❌ Erreur HTTP: {resp.text}")

# ÉTAPE 2: Compter le nombre total de références
print("\n=== ÉTAPE 2: NOMBRE TOTAL DE RÉFÉRENCES ===\n")
sql = """
SELECT COUNT(*) as total_referrals
FROM app.user_referrals;
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print(f"Total références: {data['rows'][0]['total_referrals']}")
    else:
        print("❌ Erreur")
else:
    print(f"❌ Erreur HTTP: {resp.text}")

# ÉTAPE 3: Analyser les références par commercial
print("\n=== ÉTAPE 3: RÉFÉRENCES PAR COMMERCIAL ===\n")
sql = """
SELECT 
    cr.commercial_id,
    cp.display_name as commercial_name,
    COUNT(ur.id) as referral_count,
    COUNT(DISTINCT ur.prospect_id) as unique_prospects
FROM app.user_referrals ur
JOIN app.commercial_profiles cp ON cp.user_id = ur.commercial_id
JOIN app.commercial_referrals cr ON cr.referral_id = ur.id
GROUP BY cr.commercial_id, cp.display_name
ORDER BY referral_count DESC;
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print("Références par commercial:")
        for row in data["rows"]:
            print(f"  - {row['commercial_name']} (ID: {row['commercial_id']}): {row['referral_count']} références, {row['unique_prospects']} prospects uniques")
    else:
        print("❌ Erreur ou pas de données")
else:
    print(f"❌ Erreur HTTP: {resp.text}")

# ÉTAPE 4: Vérifier les duplications de prospects
print("\n=== ÉTAPE 4: DUPLICATIONS DE PROSPECTS ===\n")
sql = """
SELECT 
    prospect_id,
    COUNT(*) as referral_count,
    ARRAY_AGG(commercial_id) as commercial_ids
FROM app.user_referrals
GROUP BY prospect_id
HAVING COUNT(*) > 1
ORDER BY referral_count DESC;
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print(f"Prospects avec plusieurs références ({len(data['rows'])} trouvés):")
        for row in data["rows"]:
            print(f"  - Prospect ID: {row['prospect_id']}")
            print(f"    Nombre de références: {row['referral_count']}")
            print(f"    Commerciaux impliqués: {row['commercial_ids']}")
    else:
        print("✅ Aucune duplication détectée")
else:
    print(f"❌ Erreur HTTP: {resp.text}")

# ÉTAPE 5: Vérifier la structure de commercial_referrals
print("\n=== ÉTAPE 5: STRUCTURE DE LA TABLE commercial_referrals ===\n")
sql = """
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name = 'commercial_referrals'
ORDER BY ordinal_position;
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print("Colonnes de commercial_referrals:")
        for row in data["rows"]:
            print(f"  - {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']})")
    else:
        print("❌ Erreur ou pas de données")
else:
    print(f"❌ Erreur HTTP: {resp.text}")

# ÉTAPE 6: Comparer user_referrals vs commercial_referrals
print("\n=== ÉTAPE 6: COMPARAISON user_referrals vs commercial_referrals ===\n")
sql = """
SELECT 
    (SELECT COUNT(*) FROM app.user_referrals) as user_referrals_count,
    (SELECT COUNT(*) FROM app.commercial_referrals) as commercial_referrals_count;
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        row = data["rows"][0]
        print(f"user_referrals: {row['user_referrals_count']}")
        print(f"commercial_referrals: {row['commercial_referrals_count']}")
        if row['user_referrals_count'] != row['commercial_referrals_count']:
            print(f"⚠️  ÉCART DÉTECTÉ: {abs(row['user_referrals_count'] - row['commercial_referrals_count'])} enregistrements")
        else:
            print("✅ Comptes identiques")
    else:
        print("❌ Erreur")
else:
    print(f"❌ Erreur HTTP: {resp.text}")

# ÉTAPE 7: Vérifier les contraintes et index
print("\n=== ÉTAPE 7: CONTRAINTES ET INDEX SUR user_referrals ===\n")
sql = """
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_def
FROM pg_constraint
WHERE conrelid = (SELECT oid FROM pg_class WHERE relname = 'user_referrals' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'app'))
ORDER BY contype, conname;
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print("Contraintes sur user_referrals:")
        for row in data["rows"]:
            print(f"  - {row['constraint_name']} ({row['constraint_type']}): {row['constraint_def']}")
    else:
        print("❌ Pas de contraintes trouvées")
else:
    print(f"❌ Erreur HTTP: {resp.text}")

# ÉTAPE 8: Échantillon de données brutes
print("\n=== ÉTAPE 8: ÉCHANTILLON DE DONNÉES user_referrals ===\n")
sql = """
SELECT *
FROM app.user_referrals
LIMIT 10;
"""
resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
print(f"STATUS: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    if data.get("ok") and data.get("rows"):
        print("10 premiers enregistrements:")
        for row in data["rows"]:
            print(f"  {json.dumps(row, indent=2, default=str)}")
    else:
        print("❌ Pas de données")
else:
    print(f"❌ Erreur HTTP: {resp.text}")

print("\n" + "=" * 80)
print("AUDIT TERMINÉ")
print("=" * 80)
