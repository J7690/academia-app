#!/usr/bin/env python3
"""Utilise l'API Supabase Management pour exécuter du SQL en tant que postgres."""

import requests
import json
import subprocess
import sys

PROJECT_REF = "thevdfcwlcqzdoybfvgs"

# Le SQL à exécuter
POLICIES_SQL = """
-- Policy SELECT
DROP POLICY IF EXISTS public_read_community_media ON storage.objects;
CREATE POLICY public_read_community_media ON storage.objects AS PERMISSIVE FOR SELECT TO anon, authenticated USING (bucket_id = 'community-media');

-- Policy INSERT
DROP POLICY IF EXISTS authenticated_write_community_media_insert ON storage.objects;
CREATE POLICY authenticated_write_community_media_insert ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (bucket_id = 'community-media');

-- Policy UPDATE
DROP POLICY IF EXISTS authenticated_write_community_media_update ON storage.objects;
CREATE POLICY authenticated_write_community_media_update ON storage.objects AS PERMISSIVE FOR UPDATE TO authenticated USING (bucket_id = 'community-media') WITH CHECK (bucket_id = 'community-media');

-- Policy DELETE
DROP POLICY IF EXISTS authenticated_write_community_media_delete ON storage.objects;
CREATE POLICY authenticated_write_community_media_delete ON storage.objects AS PERMISSIVE FOR DELETE TO authenticated USING (bucket_id = 'community-media');
"""


def check_supabase_cli():
    """Vérifie si Supabase CLI est installé."""
    try:
        result = subprocess.run(["supabase", "--version"], capture_output=True, text=True)
        return result.returncode == 0
    except FileNotFoundError:
        return False


def run_sql_via_cli(sql: str) -> tuple[bool, str]:
    """Exécute du SQL via Supabase CLI."""
    try:
        result = subprocess.run(
            ["supabase", "db", "execute", "--project-ref", PROJECT_REF, "-c", sql],
            capture_output=True,
            text=True,
            timeout=60,
        )
        return result.returncode == 0, result.stdout + result.stderr
    except Exception as e:
        return False, str(e)


def main():
    print("=" * 60)
    print("CRÉATION DES POLICIES VIA SUPABASE CLI")
    print("=" * 60)

    # Vérifier si Supabase CLI est disponible
    print("\n[1] Vérification Supabase CLI")
    print("-" * 40)
    if check_supabase_cli():
        print("  ✅ Supabase CLI disponible")
        
        print("\n[2] Exécution du SQL")
        print("-" * 40)
        success, output = run_sql_via_cli(POLICIES_SQL)
        print(f"  Succès: {success}")
        print(f"  Output: {output}")
    else:
        print("  ❌ Supabase CLI non disponible")
        print("\n  Installation requise:")
        print("  npm install -g supabase")
        print("  ou")
        print("  scoop install supabase")
        
        # Alternative: essayer npx
        print("\n[2] Tentative via npx supabase")
        print("-" * 40)
        try:
            result = subprocess.run(
                ["npx", "supabase", "--version"],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if result.returncode == 0:
                print(f"  ✅ npx supabase disponible: {result.stdout.strip()}")
            else:
                print(f"  ❌ npx supabase non disponible")
        except Exception as e:
            print(f"  ❌ Erreur: {e}")

    print("\n" + "=" * 60)
    print("ALTERNATIVE: Connexion directe à PostgreSQL")
    print("=" * 60)
    print("""
Si vous avez accès à la chaîne de connexion PostgreSQL du projet,
vous pouvez exécuter le SQL directement:

1. Récupérer la connection string depuis:
   https://supabase.com/dashboard/project/{}/settings/database

2. Exécuter:
   psql "postgresql://postgres:[PASSWORD]@db.{}.supabase.co:5432/postgres" -c "..."

Ou utiliser le SQL Editor du Dashboard:
   https://supabase.com/dashboard/project/{}/sql/new
""".format(PROJECT_REF, PROJECT_REF, PROJECT_REF))


if __name__ == "__main__":
    main()
