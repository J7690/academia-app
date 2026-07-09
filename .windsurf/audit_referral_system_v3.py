"""
Audit du système de référenciation des prospects commerciaux
Objectif: Trouver les tables réelles pour le système de référenciation
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

# ÉTAPE 1: Lister toutes les tables du schéma app qui contiennent "referral" ou "ref"
data = execute_sql("""
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
AND (table_name LIKE '%referral%' OR table_name LIKE '%ref%')
ORDER BY table_name;
""", "ÉTAPE 1: TABLES AVEC 'referral' OU 'ref'")

if data and data.get("ok") and data.get("rows"):
    log_and_print("Tables trouvées:")
    for row in data["rows"]:
        log_and_print(f"  - {row['table_name']}")
elif data:
    log_and_print("❌ Aucune table trouvée")

# ÉTAPE 2: Lister toutes les tables liées aux commerciaux
data = execute_sql("""
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
AND (table_name LIKE '%commercial%' OR table_name LIKE '%commission%')
ORDER BY table_name;
""", "ÉTAPE 2: TABLES LIÉES AUX COMMERCIAUX")

if data and data.get("ok") and data.get("rows"):
    log_and_print("Tables trouvées:")
    for row in data["rows"]:
        log_and_print(f"  - {row['table_name']}")
elif data:
    log_and_print("❌ Aucune table trouvée")

# ÉTAPE 3: Vérifier la structure de commercial_profiles
data = execute_sql("""
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name = 'commercial_profiles'
ORDER BY ordinal_position;
""", "ÉTAPE 3: STRUCTURE DE commercial_profiles")

if data and data.get("ok") and data.get("rows"):
    log_and_print("Colonnes de commercial_profiles:")
    for row in data["rows"]:
        log_and_print(f"  - {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']})")
elif data:
    log_and_print("❌ Erreur ou pas de données")

# ÉTAPE 4: Chercher une colonne "referred_by" dans students
data = execute_sql("""
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name = 'students'
AND column_name LIKE '%ref%';
""", "ÉTAPE 4: COLONNES 'ref' DANS students")

if data and data.get("ok") and data.get("rows"):
    log_and_print("Colonnes de référenciation dans students:")
    for row in data["rows"]:
        log_and_print(f"  - {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']})")
elif data:
    log_and_print("❌ Aucune colonne trouvée")

# ÉTAPE 5: Vérifier s'il existe une table referral_commissions
data = execute_sql("""
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name = 'referral_commissions'
ORDER BY ordinal_position;
""", "ÉTAPE 5: STRUCTURE DE referral_commissions")

if data and data.get("ok") and data.get("rows"):
    log_and_print("Colonnes de referral_commissions:")
    for row in data["rows"]:
        log_and_print(f"  - {row['column_name']}: {row['data_type']} (nullable: {row['is_nullable']})")
elif data:
    log_and_print("❌ Table non trouvée")

# ÉTAPE 6: Lister toutes les tables du schéma app (limité à 50)
data = execute_sql("""
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
ORDER BY table_name
LIMIT 50;
""", "ÉTAPE 6: TOUTES LES TABLES DU SCHÉMA app (50 premières)")

if data and data.get("ok") and data.get("rows"):
    log_and_print("50 premières tables du schéma app:")
    for row in data["rows"]:
        log_and_print(f"  - {row['table_name']}")
elif data:
    log_and_print("❌ Erreur")

log_and_print("\n" + "=" * 80)
log_and_print("AUDIT TERMINÉ")
log_and_print("=" * 80)
log_and_print(f"\nRésultats sauvegardés dans: {output_file}")
