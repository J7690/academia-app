"""
Audit du système de référenciation des prospects commerciaux
Objectif: Vérifier la structure et les données de user_referrals
"""

import requests
import json
from datetime import datetime
import os

# Configuration
url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

# Créer le dossier logs si nécessaire
os.makedirs("logs", exist_ok=True)

# Fichier de sortie
output_file = "logs/audit_referral_system_output.txt"
with open(output_file, "w", encoding="utf-8") as f:
    f.write("=" * 80 + "\n")
    f.write("AUDIT DU SYSTÈME DE RÉFÉRENCIATION DES PROSPECTS COMMERCIAUX\n")
    f.write(f"Date: {datetime.now().isoformat()}\n")
    f.write("=" * 80 + "\n\n")

def log_and_print(text):
    """Écrire dans le fichier et imprimer à l'écran"""
    print(text)
    with open(output_file, "a", encoding="utf-8") as f:
        f.write(text + "\n")

def execute_sql(sql, description):
    """Exécuter une requête SQL et retourner le résultat"""
    log_and_print(f"\n=== {description} ===\n")
    resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=30)
    log_and_print(f"STATUS: {resp.status_code}")
    if resp.status_code == 200:
        try:
            data = resp.json()
            return data
        except:
            log_and_print(f"❌ Erreur de parsing JSON: {resp.text}")
            return None
    else:
        log_and_print(f"❌ Erreur HTTP: {resp.text}")
        return None

# ÉTAPE 1: Vérifier la structure de la table user_referrals
data = execute_sql("""
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name = 'user_referrals'
ORDER BY ordinal_position;
""", "ÉTAPE 1: STRUCTURE DE LA TABLE user_referrals")

if data and data.get("ok") and data.get("rows"):
    log_and_print("Colonnes de user_referrals:")
    for row in data["rows"]:
        log_and_print(f"  - {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']})")
elif data:
    log_and_print("❌ Erreur ou pas de données")

# ÉTAPE 2: Compter le nombre total de références
data = execute_sql("""
SELECT COUNT(*) as total_referrals
FROM app.user_referrals;
""", "ÉTAPE 2: NOMBRE TOTAL DE RÉFÉRENCES")

if data and data.get("ok") and data.get("rows"):
    log_and_print(f"Total références: {data['rows'][0]['total_referrals']}")
elif data:
    log_and_print("❌ Erreur")

# ÉTAPE 3: Analyser les références par commercial
data = execute_sql("""
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
""", "ÉTAPE 3: RÉFÉRENCES PAR COMMERCIAL")

if data and data.get("ok") and data.get("rows"):
    log_and_print("Références par commercial:")
    for row in data["rows"]:
        log_and_print(f"  - {row['commercial_name']} (ID: {row['commercial_id']}): {row['referral_count']} références, {row['unique_prospects']} prospects uniques")
elif data:
    log_and_print("❌ Erreur ou pas de données")

# ÉTAPE 4: Vérifier les duplications de prospects
data = execute_sql("""
SELECT 
    prospect_id,
    COUNT(*) as referral_count,
    ARRAY_AGG(commercial_id) as commercial_ids
FROM app.user_referrals
GROUP BY prospect_id
HAVING COUNT(*) > 1
ORDER BY referral_count DESC;
""", "ÉTAPE 4: DUPLICATIONS DE PROSPECTS")

if data and data.get("ok") and data.get("rows"):
    log_and_print(f"Prospects avec plusieurs références ({len(data['rows'])} trouvés):")
    for row in data["rows"]:
        log_and_print(f"  - Prospect ID: {row['prospect_id']}")
        log_and_print(f"    Nombre de références: {row['referral_count']}")
        log_and_print(f"    Commerciaux impliqués: {row['commercial_ids']}")
elif data:
    log_and_print("✅ Aucune duplication détectée")

# ÉTAPE 5: Vérifier la structure de commercial_referrals
data = execute_sql("""
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name = 'commercial_referrals'
ORDER BY ordinal_position;
""", "ÉTAPE 5: STRUCTURE DE LA TABLE commercial_referrals")

if data and data.get("ok") and data.get("rows"):
    log_and_print("Colonnes de commercial_referrals:")
    for row in data["rows"]:
        log_and_print(f"  - {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']})")
elif data:
    log_and_print("❌ Erreur ou pas de données")

# ÉTAPE 6: Comparer user_referrals vs commercial_referrals
data = execute_sql("""
SELECT 
    (SELECT COUNT(*) FROM app.user_referrals) as user_referrals_count,
    (SELECT COUNT(*) FROM app.commercial_referrals) as commercial_referrals_count;
""", "ÉTAPE 6: COMPARAISON user_referrals vs commercial_referrals")

if data and data.get("ok") and data.get("rows"):
    row = data["rows"][0]
    log_and_print(f"user_referrals: {row['user_referrals_count']}")
    log_and_print(f"commercial_referrals: {row['commercial_referrals_count']}")
    if row['user_referrals_count'] != row['commercial_referrals_count']:
        log_and_print(f"⚠️  ÉCART DÉTECTÉ: {abs(row['user_referrals_count'] - row['commercial_referrals_count'])} enregistrements")
    else:
        log_and_print("✅ Comptes identiques")
elif data:
    log_and_print("❌ Erreur")

# ÉTAPE 7: Vérifier les contraintes et index
data = execute_sql("""
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_def
FROM pg_constraint
WHERE conrelid = (SELECT oid FROM pg_class WHERE relname = 'user_referrals' AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'app'))
ORDER BY contype, conname;
""", "ÉTAPE 7: CONTRAINTES ET INDEX SUR user_referrals")

if data and data.get("ok") and data.get("rows"):
    log_and_print("Contraintes sur user_referrals:")
    for row in data["rows"]:
        log_and_print(f"  - {row['constraint_name']} ({row['constraint_type']}): {row['constraint_def']}")
elif data:
    log_and_print("❌ Pas de contraintes trouvées")

# ÉTAPE 8: Échantillon de données brutes
data = execute_sql("""
SELECT *
FROM app.user_referrals
LIMIT 10;
""", "ÉTAPE 8: ÉCHANTILLON DE DONNÉES user_referrals")

if data and data.get("ok") and data.get("rows"):
    log_and_print("10 premiers enregistrements:")
    for row in data["rows"]:
        log_and_print(f"  {json.dumps(row, indent=2, default=str)}")
elif data:
    log_and_print("❌ Pas de données")

# ÉTAPE 9: Vérifier si la table existe vraiment
data = execute_sql("""
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'app' 
AND table_name IN ('user_referrals', 'commercial_referrals');
""", "ÉTAPE 9: VÉRIFICATION DE L'EXISTENCE DES TABLES")

if data and data.get("ok") and data.get("rows"):
    log_and_print("Tables trouvées:")
    for row in data["rows"]:
        log_and_print(f"  - {row['table_name']}")
elif data:
    log_and_print("❌ Tables non trouvées")

log_and_print("\n" + "=" * 80)
log_and_print("AUDIT TERMINÉ")
log_and_print("=" * 80)
log_and_print(f"\nRésultats sauvegardés dans: {output_file}")
