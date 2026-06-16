-- Academia - droits sur le schéma app pour l'API REST
-- Objectif : permettre aux rôles anon / authenticated d'accéder aux tables app.* via PostgREST.

GRANT USAGE ON SCHEMA app TO anon, authenticated;
GRANT USAGE ON SCHEMA app TO service_role;
GRANT ALL ON SCHEMA app TO service_role;
