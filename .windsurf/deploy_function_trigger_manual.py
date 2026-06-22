import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("DÉPLOIEMENT FONCTION ET TRIGGER CORRIGÉ")
print("=" * 80)

# Étape 1: Créer la fonction
sql1 = """
CREATE OR REPLACE FUNCTION app.cleanup_expired_upload_sessions()
RETURNS void AS $$
BEGIN
  UPDATE app.upload_sessions
  SET status = 'expired'
  WHERE status IN ('initialized', 'uploading')
    AND expires_at < NOW()
END
$$ LANGUAGE plpgsql
"""
print("\n1. Création de la fonction cleanup_expired_upload_sessions...")
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print("   STATUS:", resp1.status_code)
print("   BODY:", resp1.text[:500])

# Vérifier la fonction
sql2 = "SELECT proname FROM pg_proc WHERE proname = 'cleanup_expired_upload_sessions'"
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print("\n2. Vérification de la fonction:")
print("   STATUS:", resp2.status_code)
print("   BODY:", resp2.text[:500])

# Étape 2: Supprimer le trigger existant
sql3 = "DROP TRIGGER IF EXISTS trigger_cleanup_expired_upload_sessions ON app.upload_sessions"
print("\n3. Suppression du trigger existant...")
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print("   STATUS:", resp3.status_code)
print("   BODY:", resp3.text[:500])

# Étape 3: Créer le trigger (sans BEFORE SELECT)
sql4 = """
CREATE TRIGGER trigger_cleanup_expired_upload_sessions
  BEFORE INSERT OR UPDATE OR DELETE ON app.upload_sessions
  FOR EACH STATEMENT EXECUTE FUNCTION app.cleanup_expired_upload_sessions()
"""
print("\n4. Création du trigger (sans BEFORE SELECT)...")
resp4 = requests.post(url, headers=headers, json={"p_sql": sql4}, timeout=30)
print("   STATUS:", resp4.status_code)
print("   BODY:", resp4.text[:500])

# Vérifier le trigger
sql5 = """
SELECT trigger_name FROM information_schema.triggers 
WHERE trigger_schema = 'app' 
  AND trigger_name = 'trigger_cleanup_expired_upload_sessions'
"""
resp5 = requests.post(url, headers=headers, json={"p_sql": sql5}, timeout=30)
print("\n5. Vérification du trigger:")
print("   STATUS:", resp5.status_code)
print("   BODY:", resp5.text[:500])

print("\n" + "=" * 80)
print("FIN DU DÉPLOIEMENT")
print("=" * 80)
