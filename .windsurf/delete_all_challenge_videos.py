import requests
import sys

# Configuration Supabase
base_url = "https://thevdfcwlcqzdoybfvgs.supabase.co"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 70)
print("SUPPRESSION DE TOUTES LES VIDÉOS DE CHALLENGES")
print("=" * 70)

# ÉTAPE 1: Suppression directe via SQL admin_execute_sql
print("\n[1] Suppression des fichiers via SQL...")

sql_delete_challenge_media = """
DELETE FROM storage.objects
WHERE bucket_id = 'challenge-media'
"""

sql_delete_video_assets = """
DELETE FROM storage.objects
WHERE bucket_id = 'video-assets'
"""

url_rpc = f"{base_url}/rest/v1/rpc/admin_execute_sql"

# Supprimer challenge-media
print("  Suppression challenge-media...")
resp = requests.post(url_rpc, headers=headers, json={"p_sql": sql_delete_challenge_media}, timeout=30)
if resp.status_code != 200:
    print(f"ERREUR challenge-media: {resp.status_code} - {resp.text}")
else:
    result = resp.json()
    print(f"  ✅ challenge-media: {result.get('affected_rows', 0)} fichiers supprimés")

# Supprimer video-assets
print("  Suppression video-assets...")
resp = requests.post(url_rpc, headers=headers, json={"p_sql": sql_delete_video_assets}, timeout=30)
if resp.status_code != 200:
    print(f"ERREUR video-assets: {resp.status_code} - {resp.text}")
else:
    result = resp.json()
    print(f"  ✅ video-assets: {result.get('affected_rows', 0)} fichiers supprimés")

# ÉTAPE 2: Vérification
print("\n[2] Vérification après suppression...")

sql_verify = """
SELECT bucket_id, COUNT(*) as file_count
FROM storage.objects
WHERE bucket_id IN ('challenge-media', 'video-assets')
GROUP BY bucket_id
"""

resp = requests.post(url_rpc, headers=headers, json={"p_sql": sql_verify}, timeout=30)
if resp.status_code == 200:
    result = resp.json()
    if isinstance(result, list):
        for row in result:
            bucket = row['bucket_id']
            count = row['file_count']
            print(f"  {bucket}: {count} fichiers restants")
        if not result:
            print("  ✅ Tous les buckets sont vides")
    else:
        print(f"  Format de réponse: {result}")
else:
    print(f"ERREUR vérification: {resp.status_code} - {resp.text}")

print("\n" + "=" * 70)
print("SUPPRESSION TERMINÉE")
print("=" * 70)
