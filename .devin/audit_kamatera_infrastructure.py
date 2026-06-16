#!/usr/bin/env python3
"""Audit infrastructure Kamatera pour Bobodo Vocal"""

import json
import requests
from supabase_auto_manager import SupabaseAutoManager

manager = SupabaseAutoManager()

print("=" * 80)
print("AUDIT INFRASTRUCTURE KAMATERA - BOBODO VOCAL")
print("=" * 80)

url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"

# Vérifier les tables de monitoring/statistiques
print("\n--- Recherche de tables de monitoring ---")
sql_tables = """
    SELECT table_name, table_schema
    FROM information_schema.tables
    WHERE table_schema IN ('public', 'app')
      AND (table_name ILIKE '%monitor%' 
           OR table_name ILIKE '%metric%'
           OR table_name ILIKE '%stat%'
           OR table_name ILIKE '%usage%'
           OR table_name ILIKE '%load%')
    ORDER BY table_schema, table_name;
"""

response = requests.post(url, headers=manager.headers, json={"p_sql": sql_tables}, timeout=30)

if response.status_code == 200:
    data = response.json()
    if isinstance(data, dict) and data.get("mode") == "select" and "rows" in data:
        print(f"[OK] {len(data['rows'])} tables trouvees")
        for row in data["rows"]:
            print(f"   {row['table_schema']}.{row['table_name']}")
    else:
        print(f"[ERROR] Reponse inattendue : {data}")
else:
    print(f"[ERROR] Erreur HTTP {response.status_code} : {response.text}")

# Vérifier les Edge Functions
print("\n--- Recherche d'Edge Functions existantes ---")
sql_functions = """
    SELECT routine_name, routine_type
    FROM information_schema.routines
    WHERE routine_schema = 'app'
      AND routine_name ILIKE '%livekit%'
    ORDER BY routine_name;
"""

response = requests.post(url, headers=manager.headers, json={"p_sql": sql_functions}, timeout=30)

if response.status_code == 200:
    data = response.json()
    if isinstance(data, dict) and data.get("mode") == "select" and "rows" in data:
        print(f"[OK] {len(data['rows'])} fonctions trouvees")
        for row in data["rows"]:
            print(f"   {row['routine_name']} ({row['routine_type']})")
    else:
        print(f"[ERROR] Reponse inattendue : {data}")
else:
    print(f"[ERROR] Erreur HTTP {response.status_code} : {response.text}")

# Vérifier les tables liées à LiveKit
print("\n--- Recherche de tables LiveKit ---")
sql_livekit = """
    SELECT table_name, table_schema
    FROM information_schema.tables
    WHERE table_schema IN ('public', 'app')
      AND table_name ILIKE '%live%'
    ORDER BY table_schema, table_name;
"""

response = requests.post(url, headers=manager.headers, json={"p_sql": sql_livekit}, timeout=30)

if response.status_code == 200:
    data = response.json()
    if isinstance(data, dict) and data.get("mode") == "select" and "rows" in data:
        print(f"[OK] {len(data['rows'])} tables trouvees")
        for row in data["rows"]:
            print(f"   {row['table_schema']}.{row['table_name']}")
    else:
        print(f"[ERROR] Reponse inattendue : {data}")
else:
    print(f"[ERROR] Erreur HTTP {response.status_code} : {response.text}")

# Vérifier les tables de logs/audit
print("\n--- Recherche de tables de logs/audit ---")
sql_logs = """
    SELECT table_name, table_schema
    FROM information_schema.tables
    WHERE table_schema IN ('public', 'app')
      AND (table_name ILIKE '%log%'
           OR table_name ILIKE '%audit%'
           OR table_name ILIKE '%event%')
    ORDER BY table_schema, table_name;
"""

response = requests.post(url, headers=manager.headers, json={"p_sql": sql_logs}, timeout=30)

if response.status_code == 200:
    data = response.json()
    if isinstance(data, dict) and data.get("mode") == "select" and "rows" in data:
        print(f"[OK] {len(data['rows'])} tables trouvees")
        for row in data["rows"]:
            print(f"   {row['table_schema']}.{row['table_name']}")
    else:
        print(f"[ERROR] Reponse inattendue : {data}")
else:
    print(f"[ERROR] Erreur HTTP {response.status_code} : {response.text}")

print("\n" + "=" * 80)
print("AUDIT TERMINÉ")
print("=" * 80)
print("\nNOTE: Les informations détaillées sur le serveur Kamatera (vCPU, RAM, stockage)")
print("ne sont pas accessibles via Supabase. Elles doivent être obtenues via:")
print("- SSH direct sur le serveur: ssh root@185.167.97.144")
print("- Dashboard Kamatera")
print("- Documentation existante: academia_app/docs/INFRASTRUCTURE_KAMATERA.md")
