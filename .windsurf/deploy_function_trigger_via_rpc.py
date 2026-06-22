import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("DÉPLOIEMENT FONCTION ET TRIGGER VIA RPC")
print("=" * 80)

# Approche alternative: utiliser DO block pour créer la fonction
sql1 = """
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc 
    WHERE proname = 'cleanup_expired_upload_sessions'
  ) THEN
    CREATE FUNCTION app.cleanup_expired_upload_sessions()
    RETURNS void AS $$
    BEGIN
      UPDATE app.upload_sessions
      SET status = 'expired'
      WHERE status IN ('initialized', 'uploading')
        AND expires_at < NOW();
    END;
    $$ LANGUAGE plpgsql;
  END IF;
END $$;
"""
print("\n1. Création de la fonction via DO block...")
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print("   STATUS:", resp1.status_code)
print("   BODY:", resp1.text[:500])

# Vérifier si la fonction existe
sql2 = "SELECT proname FROM pg_proc WHERE proname = 'cleanup_expired_upload_sessions'"
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print("\n2. Vérification de la fonction:")
print("   STATUS:", resp2.status_code)
print("   BODY:", resp2.text[:500])

# Si la fonction existe, créer le trigger
if resp2.status_code == 200 and "cleanup_expired_upload_sessions" in resp2.text:
    print("\n   ✓ Fonction existe, création du trigger...")
    
    sql3 = """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_schema = 'app' 
          AND trigger_name = 'trigger_cleanup_expired_upload_sessions'
      ) THEN
        CREATE TRIGGER trigger_cleanup_expired_upload_sessions
          BEFORE SELECT OR INSERT OR UPDATE OR DELETE ON app.upload_sessions
          FOR EACH STATEMENT EXECUTE FUNCTION app.cleanup_expired_upload_sessions();
      END IF;
    END $$;
    """
    resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
    print("   STATUS:", resp3.status_code)
    print("   BODY:", resp3.text[:500])
    
    # Vérifier le trigger
    sql4 = """
    SELECT trigger_name FROM information_schema.triggers 
    WHERE trigger_schema = 'app' 
      AND trigger_name = 'trigger_cleanup_expired_upload_sessions'
    """
    resp4 = requests.post(url, headers=headers, json={"p_sql": sql4}, timeout=30)
    print("\n3. Vérification du trigger:")
    print("   STATUS:", resp4.status_code)
    print("   BODY:", resp4.text[:500])
else:
    print("\n   ⚠️  Fonction n'existe pas, essai approche alternative...")
    
    # Approche alternative: créer une Edge Function pour le cleanup
    print("\n   Suggestion: Créer une Edge Function pour le cleanup automatique")
    print("   Ou utiliser un cron job pg_cron pour le cleanup")

print("\n" + "=" * 80)
print("FIN DU DÉPLOIEMENT")
print("=" * 80)
