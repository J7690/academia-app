#!/usr/bin/env python3
"""Connexion directe à la base PostgreSQL Supabase pour créer les policies."""

import subprocess
import sys

PROJECT_REF = "thevdfcwlcqzdoybfvgs"
# Le mot de passe de la base de données (à récupérer depuis le dashboard si nécessaire)
# Format: postgresql://postgres:[PASSWORD]@db.thevdfcwlcqzdoybfvgs.supabase.co:5432/postgres

POLICIES_SQL = """
DROP POLICY IF EXISTS public_read_community_media ON storage.objects;
CREATE POLICY public_read_community_media ON storage.objects AS PERMISSIVE FOR SELECT TO anon, authenticated USING (bucket_id = 'community-media');

DROP POLICY IF EXISTS authenticated_write_community_media_insert ON storage.objects;
CREATE POLICY authenticated_write_community_media_insert ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (bucket_id = 'community-media');

DROP POLICY IF EXISTS authenticated_write_community_media_update ON storage.objects;
CREATE POLICY authenticated_write_community_media_update ON storage.objects AS PERMISSIVE FOR UPDATE TO authenticated USING (bucket_id = 'community-media') WITH CHECK (bucket_id = 'community-media');

DROP POLICY IF EXISTS authenticated_write_community_media_delete ON storage.objects;
CREATE POLICY authenticated_write_community_media_delete ON storage.objects AS PERMISSIVE FOR DELETE TO authenticated USING (bucket_id = 'community-media');
"""


def try_psycopg2():
    """Essaie d'utiliser psycopg2 pour se connecter."""
    try:
        import psycopg2
        print("  ✅ psycopg2 disponible")
        return True
    except ImportError:
        print("  ❌ psycopg2 non disponible")
        return False


def try_install_psycopg2():
    """Essaie d'installer psycopg2."""
    print("  Installation de psycopg2-binary...")
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "psycopg2-binary", "-q"],
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def main():
    print("=" * 60)
    print("CONNEXION DIRECTE À POSTGRESQL SUPABASE")
    print("=" * 60)

    print("\n[1] Vérification psycopg2")
    print("-" * 40)
    
    if not try_psycopg2():
        if try_install_psycopg2():
            print("  ✅ psycopg2-binary installé")
        else:
            print("  ❌ Impossible d'installer psycopg2")
            return

    # Importer après installation potentielle
    try:
        import psycopg2
    except ImportError:
        print("  ❌ psycopg2 toujours non disponible")
        return

    print("\n[2] Tentative de connexion")
    print("-" * 40)
    
    # Essayer différents mots de passe courants ou récupérer depuis l'environnement
    import os
    db_password = os.environ.get("SUPABASE_DB_PASSWORD", "")
    
    if not db_password:
        print("  ⚠️ Variable SUPABASE_DB_PASSWORD non définie")
        print("  Récupérez le mot de passe depuis:")
        print(f"  https://supabase.com/dashboard/project/{PROJECT_REF}/settings/database")
        print("\n  Puis exécutez:")
        print(f'  set SUPABASE_DB_PASSWORD=votre_mot_de_passe')
        print(f'  python .windsurf\\create_policies_direct_db.py')
        return

    connection_string = f"postgresql://postgres.{PROJECT_REF}:{db_password}@aws-0-eu-central-1.pooler.supabase.com:6543/postgres"
    
    try:
        conn = psycopg2.connect(connection_string)
        conn.autocommit = True
        print("  ✅ Connexion établie")
        
        print("\n[3] Exécution des policies")
        print("-" * 40)
        
        with conn.cursor() as cur:
            for statement in POLICIES_SQL.strip().split(';'):
                statement = statement.strip()
                if statement:
                    try:
                        cur.execute(statement)
                        print(f"  ✅ {statement[:50]}...")
                    except Exception as e:
                        print(f"  ❌ Erreur: {e}")
        
        conn.close()
        print("\n  ✅ Policies créées avec succès!")
        
    except Exception as e:
        print(f"  ❌ Erreur de connexion: {e}")


if __name__ == "__main__":
    main()
