import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("CONFIGURATION CRON JOB POUR CLEANUP AUTOMATIQUE")
print("=" * 80)

# Vérifier si pg_cron est installé
sql1 = "SELECT extname FROM pg_extension WHERE extname = 'pg_cron'"
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print("\n1. Vérification de pg_cron:")
print("   STATUS:", resp1.status_code)
print("   BODY:", resp1.text[:500])

if resp1.status_code == 200 and "pg_cron" in resp1.text:
    print("   ✓ pg_cron est installé")
    
    # Supprimer le cron job existant s'il y en a un
    sql2 = "SELECT cron.schedule('cleanup-upload-sessions', '*/30 * * * *', 'SELECT net.http_post(url := ''https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/cleanup-expired-upload-sessions'', headers := ''{\"Content-Type\": \"application/json\"}''::jsonb)')"
    print("\n2. Création du cron job (toutes les 30 minutes)...")
    resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
    print("   STATUS:", resp2.status_code)
    print("   BODY:", resp2.text[:500])
    
    # Vérifier le cron job
    sql3 = "SELECT * FROM cron.job WHERE jobname = 'cleanup-upload-sessions'"
    resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
    print("\n3. Vérification du cron job:")
    print("   STATUS:", resp3.status_code)
    print("   BODY:", resp3.text[:500])
else:
    print("   ⚠️  pg_cron n'est pas installé")
    print("   Solution alternative: Appeler l'Edge Function manuellement ou via un autre scheduler")
    print("\n   Edge Function URL: https://thevdfcwlcqzdoybfvgs.supabase.co/functions/v1/cleanup-expired-upload-sessions")
    print("   Méthode: POST")
    print("   Headers: Authorization: Bearer <service_role_key>")

print("\n" + "=" * 80)
print("FIN DE LA CONFIGURATION")
print("=" * 80)
