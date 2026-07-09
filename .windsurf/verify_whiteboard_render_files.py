import paramiko
import requests

HOST = "185.167.97.144"
USER = "root"
PASS = "Nexiomgroup@Academia0"

print("=" * 80)
print("VÉRIFICATION FICHIERS GÉNÉRÉS PAR WHITEBOARD WORKER")
print("=" * 80)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS)

print(f"\n✅ Connexion SSH réussie à {HOST}")

# ÉTAPE 1: Vérifier les fichiers PNG temporaires
print("\n--- Fichiers PNG temporaires ---")
stdin, stdout, stderr = ssh.exec_command("ls -lh /tmp/whiteboard_*.png 2>/dev/null || echo 'NO_PNG_FILES'")
png_output = stdout.read().decode().strip()
if "NO_PNG_FILES" in png_output:
    print("⚠️ Aucun fichier PNG temporaire trouvé (peut-être nettoyé)")
else:
    print("✅ Fichiers PNG trouvés:")
    print(png_output)

# ÉTAPE 2: Vérifier les fichiers MP4 temporaires
print("\n--- Fichiers MP4 temporaires ---")
stdin, stdout, stderr = ssh.exec_command("ls -lh /tmp/whiteboard_*.mp4 2>/dev/null || echo 'NO_MP4_FILES'")
mp4_output = stdout.read().decode().strip()
if "NO_MP4_FILES" in mp4_output:
    print("⚠️ Aucun fichier MP4 temporaire trouvé (peut-être nettoyé)")
else:
    print("✅ Fichiers MP4 trouvés:")
    print(mp4_output)

# ÉTAPE 3: Vérifier le job traité dans les logs
print("\n--- Job traité (logs) ---")
stdin, stdout, stderr = ssh.exec_command("journalctl -u whiteboard-worker -n 30 --no-pager | grep -E '(job|MP4|PNG)'")
logs = stdout.read().decode()
print(logs)

ssh.close()

# ÉTAPE 4: Vérifier l'URL Storage
print("\n--- Vérification URL Storage ---")
storage_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/whiteboard-renders/renders/fd9e3969-be64-45a9-8e95-00606ac51446/99f1c7ef242a4961afc6dc27edc4d77b.mp4"
print(f"URL: {storage_url}")

try:
    resp = requests.head(storage_url, timeout=10)
    print(f"Status: {resp.status_code}")
    print(f"Content-Type: {resp.headers.get('Content-Type', 'N/A')}")
    print(f"Content-Length: {resp.headers.get('Content-Length', 'N/A')} bytes")
    
    if resp.status_code == 200:
        print("✅ MP4 accessible via Storage")
    else:
        print(f"❌ Erreur HTTP {resp.status_code}")
except Exception as e:
    print(f"❌ Erreur: {e}")

# ÉTAPE 5: Vérifier le job dans Supabase
print("\n--- Vérification job dans Supabase ---")
import requests

supabase_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

sql = """
SELECT id, project_id, status, video_url, duration_ms, error_message, created_at, started_at, completed_at
FROM app.whiteboard_renders
WHERE id = 'fd9e3969-be64-45a9-8e95-00606ac51446'
"""

resp = requests.post(supabase_url, headers=headers, json={"p_sql": sql}, timeout=30)
data = resp.json()

if data.get("ok") and data.get("rows"):
    print("✅ Job trouvé dans Supabase:")
    for row in data["rows"]:
        print(f"  ID: {row['id']}")
        print(f"  Status: {row['status']}")
        print(f"  Video URL: {row.get('video_url', 'N/A')}")
        print(f"  Duration: {row.get('duration_ms', 'N/A')} ms")
        print(f"  Created: {row['created_at']}")
        print(f"  Started: {row.get('started_at', 'N/A')}")
        print(f"  Completed: {row.get('completed_at', 'N/A')}")
elif data.get("ok") and data.get("affected_rows") > 0:
    print(f"✅ Job trouvé (affected_rows: {data['affected_rows']})")
else:
    print(f"❌ Job non trouvé")
    print(f"STATUS: {resp.status_code}")
    print(f"BODY: {resp.text}")

print("\n" + "=" * 80)
print("VÉRIFICATION TERMINÉE")
print("=" * 80)
