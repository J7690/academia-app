import requests
import json

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

print("=" * 80)
print("DÉPLOIEMENT DE LA TABLE upload_sessions")
print("=" * 80)

# Étape 1: Créer la table
sql1 = """
CREATE TABLE IF NOT EXISTS app.upload_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket TEXT NOT NULL,
  path TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  content_type TEXT NOT NULL,
  uploaded_bytes BIGINT DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'initialized',
  final_path TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  metadata JSONB DEFAULT '{}'::jsonb
)
"""
print("\n1. Création de la table upload_sessions...")
resp1 = requests.post(url, headers=headers, json={"p_sql": sql1}, timeout=30)
print("   STATUS:", resp1.status_code)
print("   BODY:", resp1.text[:500])

# Étape 2: Créer les indexes
sql2 = """
CREATE INDEX IF NOT EXISTS idx_upload_sessions_user ON app.upload_sessions(user_id)
"""
print("\n2. Création de l'index idx_upload_sessions_user...")
resp2 = requests.post(url, headers=headers, json={"p_sql": sql2}, timeout=30)
print("   STATUS:", resp2.status_code)
print("   BODY:", resp2.text[:500])

sql3 = """
CREATE INDEX IF NOT EXISTS idx_upload_sessions_status ON app.upload_sessions(status)
"""
print("\n3. Création de l'index idx_upload_sessions_status...")
resp3 = requests.post(url, headers=headers, json={"p_sql": sql3}, timeout=30)
print("   STATUS:", resp3.status_code)
print("   BODY:", resp3.text[:500])

sql4 = """
CREATE INDEX IF NOT EXISTS idx_upload_sessions_expires_at ON app.upload_sessions(expires_at)
"""
print("\n4. Création de l'index idx_upload_sessions_expires_at...")
resp4 = requests.post(url, headers=headers, json={"p_sql": sql4}, timeout=30)
print("   STATUS:", resp4.status_code)
print("   BODY:", resp4.text[:500])

sql5 = """
CREATE INDEX IF NOT EXISTS idx_upload_sessions_created_at ON app.upload_sessions(created_at DESC)
"""
print("\n5. Création de l'index idx_upload_sessions_created_at...")
resp5 = requests.post(url, headers=headers, json={"p_sql": sql5}, timeout=30)
print("   STATUS:", resp5.status_code)
print("   BODY:", resp5.text[:500])

# Étape 3: Activer RLS
sql6 = """
ALTER TABLE app.upload_sessions ENABLE ROW LEVEL SECURITY
"""
print("\n6. Activation de RLS sur upload_sessions...")
resp6 = requests.post(url, headers=headers, json={"p_sql": sql6}, timeout=30)
print("   STATUS:", resp6.status_code)
print("   BODY:", resp6.text[:500])

# Étape 4: Créer les RLS policies (sans IF NOT EXISTS)
sql7 = """
DROP POLICY IF EXISTS "Users can view own upload sessions" ON app.upload_sessions
"""
print("\n7. Suppression de la policy existante 'Users can view own upload_sessions'...")
resp7 = requests.post(url, headers=headers, json={"p_sql": sql7}, timeout=30)
print("   STATUS:", resp7.status_code)
print("   BODY:", resp7.text[:500])

sql8 = """
CREATE POLICY "Users can view own upload sessions"
  ON app.upload_sessions FOR SELECT
  USING (auth.uid() = user_id)
"""
print("\n8. Création de la policy 'Users can view own upload_sessions'...")
resp8 = requests.post(url, headers=headers, json={"p_sql": sql8}, timeout=30)
print("   STATUS:", resp8.status_code)
print("   BODY:", resp8.text[:500])

sql9 = """
DROP POLICY IF EXISTS "Users can insert own upload sessions" ON app.upload_sessions
"""
print("\n9. Suppression de la policy existante 'Users can insert own upload_sessions'...")
resp9 = requests.post(url, headers=headers, json={"p_sql": sql9}, timeout=30)
print("   STATUS:", resp9.status_code)
print("   BODY:", resp9.text[:500])

sql10 = """
CREATE POLICY "Users can insert own upload sessions"
  ON app.upload_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id)
"""
print("\n10. Création de la policy 'Users can insert own upload_sessions'...")
resp10 = requests.post(url, headers=headers, json={"p_sql": sql10}, timeout=30)
print("   STATUS:", resp10.status_code)
print("   BODY:", resp10.text[:500])

sql11 = """
DROP POLICY IF EXISTS "Users can update own upload sessions" ON app.upload_sessions
"""
print("\n11. Suppression de la policy existante 'Users can update own upload_sessions'...")
resp11 = requests.post(url, headers=headers, json={"p_sql": sql11}, timeout=30)
print("   STATUS:", resp11.status_code)
print("   BODY:", resp11.text[:500])

sql12 = """
CREATE POLICY "Users can update own upload sessions"
  ON app.upload_sessions FOR UPDATE
  USING (auth.uid() = user_id)
"""
print("\n12. Création de la policy 'Users can update own upload_sessions'...")
resp12 = requests.post(url, headers=headers, json={"p_sql": sql12}, timeout=30)
print("   STATUS:", resp12.status_code)
print("   BODY:", resp12.text[:500])

sql13 = """
DROP POLICY IF EXISTS "Service role full access to upload_sessions" ON app.upload_sessions
"""
print("\n13. Suppression de la policy existante 'Service role full access to upload_sessions'...")
resp13 = requests.post(url, headers=headers, json={"p_sql": sql13}, timeout=30)
print("   STATUS:", resp13.status_code)
print("   BODY:", resp13.text[:500])

sql14 = """
CREATE POLICY "Service role full access to upload_sessions"
  ON app.upload_sessions FOR ALL
  USING (auth.role() = 'service_role')
"""
print("\n14. Création de la policy 'Service role full access to upload_sessions'...")
resp14 = requests.post(url, headers=headers, json={"p_sql": sql14}, timeout=30)
print("   STATUS:", resp14.status_code)
print("   BODY:", resp14.text[:500])

# Étape 5: Créer la fonction de cleanup (sans $$)
sql15 = """
CREATE OR REPLACE FUNCTION app.cleanup_expired_upload_sessions()
RETURNS void AS '
BEGIN
  UPDATE app.upload_sessions
  SET status = ''expired''
  WHERE status IN (''initialized'', ''uploading'')
    AND expires_at < NOW()
END
' LANGUAGE plpgsql
"""
print("\n15. Création de la fonction cleanup_expired_upload_sessions...")
resp15 = requests.post(url, headers=headers, json={"p_sql": sql15}, timeout=30)
print("   STATUS:", resp15.status_code)
print("   BODY:", resp15.text[:500])

# Étape 6: Créer le trigger
sql16 = """
DROP TRIGGER IF EXISTS trigger_cleanup_expired_upload_sessions ON app.upload_sessions
"""
print("\n16. Suppression du trigger existant (si any)...")
resp16 = requests.post(url, headers=headers, json={"p_sql": sql16}, timeout=30)
print("   STATUS:", resp16.status_code)
print("   BODY:", resp16.text[:500])

sql17 = """
CREATE TRIGGER trigger_cleanup_expired_upload_sessions
  BEFORE SELECT OR INSERT OR UPDATE OR DELETE ON app.upload_sessions
  FOR EACH STATEMENT EXECUTE FUNCTION app.cleanup_expired_upload_sessions()
"""
print("\n17. Création du trigger trigger_cleanup_expired_upload_sessions...")
resp17 = requests.post(url, headers=headers, json={"p_sql": sql17}, timeout=30)
print("   STATUS:", resp17.status_code)
print("   BODY:", resp17.text[:500])

# Étape 7: Ajouter le commentaire
sql18 = """
COMMENT ON TABLE app.upload_sessions IS 'Resumable upload sessions following YouTube/TikTok protocol with Content-Range headers'
"""
print("\n18. Ajout du commentaire sur la table...")
resp18 = requests.post(url, headers=headers, json={"p_sql": sql18}, timeout=30)
print("   STATUS:", resp18.status_code)
print("   BODY:", resp18.text[:500])

print("\n" + "=" * 80)
print("DÉPLOIEMENT TERMINÉ")
print("=" * 80)
