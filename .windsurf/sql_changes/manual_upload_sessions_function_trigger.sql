-- Instructions: Exécuter ce fichier manuellement dans l'éditeur SQL Supabase
-- https://supabase.com/dashboard/project/thevdfcwlcqzdoybfvgs/sql/new

-- Créer la fonction de cleanup des sessions expirées
CREATE OR REPLACE FUNCTION app.cleanup_expired_upload_sessions()
RETURNS void AS $$
BEGIN
  UPDATE app.upload_sessions
  SET status = 'expired'
  WHERE status IN ('initialized', 'uploading')
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Créer le trigger pour exécuter la fonction automatiquement
-- Note: PostgreSQL ne supporte pas BEFORE SELECT, seulement INSERT/UPDATE/DELETE
DROP TRIGGER IF EXISTS trigger_cleanup_expired_upload_sessions ON app.upload_sessions;

CREATE TRIGGER trigger_cleanup_expired_upload_sessions
  BEFORE INSERT OR UPDATE OR DELETE ON app.upload_sessions
  FOR EACH STATEMENT EXECUTE FUNCTION app.cleanup_expired_upload_sessions();

-- Vérifier que tout est bien créé
SELECT 
  'Table' as object_type, 
  tablename as name 
FROM pg_tables 
WHERE schemaname = 'app' AND tablename = 'upload_sessions'
UNION ALL
SELECT 
  'Function' as object_type, 
  proname as name 
FROM pg_proc 
WHERE proname = 'cleanup_expired_upload_sessions'
UNION ALL
SELECT 
  'Trigger' as object_type, 
  trigger_name as name 
FROM information_schema.triggers 
WHERE trigger_schema = 'app' AND trigger_name = 'trigger_cleanup_expired_upload_sessions';
