"""
Phase C.3B.1 – Deploy Whiteboard RPCs
Déploie les RPCs spécifiques pour le worker whiteboard
"""

import requests

admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=== DÉPLOIEMENT RPCS WHITEBOARD ===\n")

# Lire le fichier SQL
with open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\sql_changes\change_20260623_whiteboard_worker_rpcs.sql", "r") as f:
    sql_content = f.read()

# Exécuter chaque RPC individuellement
rpcs = sql_content.split("-- RPC pour")[1:]

for i, rpc in enumerate(rpcs, 1):
    print(f"{i}. Déploiement RPC {i}...")
    sql = "-- RPC pour" + rpc
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    print(f"   Status : {resp.status_code}")
    print(f"   Résultat : {resp.json()}")
    print()

print("=== DÉPLOIEMENT TERMINÉ ===")
