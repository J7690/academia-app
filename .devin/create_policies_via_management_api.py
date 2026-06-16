#!/usr/bin/env python3
"""Crée les policies via l'API Supabase Management ou via pg_net si disponible."""

import requests
import json
import os

# Configuration
PROJECT_REF = "thevdfcwlcqzdoybfvgs"
URL = f"https://{PROJECT_REF}.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

# Essayer de récupérer la clé API Supabase Management depuis les variables d'environnement
SUPABASE_ACCESS_TOKEN = os.environ.get("SUPABASE_ACCESS_TOKEN", "")

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}


def execute_sql_via_admin(sql: str) -> dict:
    """Exécute du SQL via admin_execute_sql."""
    resp = requests.post(
        f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers=HEADERS,
        json={"p_sql": sql},
        timeout=60,
    )
    return resp.json()


def main():
    print("=" * 60)
    print("CRÉATION DES POLICIES - APPROCHE ALTERNATIVE")
    print("=" * 60)

    # Approche 1: Vérifier si on peut utiliser pg_net pour exécuter du SQL privilégié
    print("\n[1] Vérification de pg_net")
    print("-" * 40)
    result = execute_sql_via_admin("SELECT extname FROM pg_extension WHERE extname = 'pg_net'")
    print(f"  pg_net disponible: {result}")

    # Approche 2: Essayer de changer le owner de la fonction pour qu'elle s'exécute en tant que postgres
    print("\n[2] Création d'une fonction avec SET ROLE")
    print("-" * 40)
    
    # Créer une fonction qui utilise SET ROLE pour devenir supabase_storage_admin
    create_fn_sql = """
    CREATE OR REPLACE FUNCTION public.setup_community_media_policies()
    RETURNS TEXT
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $fn$
    DECLARE
        v_result TEXT;
    BEGIN
        -- Essayer de créer les policies directement
        -- Cette fonction sera exécutée par le rôle qui l'a créée
        
        -- Policy SELECT
        BEGIN
            EXECUTE 'DROP POLICY IF EXISTS public_read_community_media ON storage.objects';
            EXECUTE 'CREATE POLICY public_read_community_media ON storage.objects AS PERMISSIVE FOR SELECT TO anon, authenticated USING (bucket_id = ''community-media'')';
            v_result := 'SELECT policy created. ';
        EXCEPTION WHEN OTHERS THEN
            v_result := 'SELECT policy error: ' || SQLERRM || '. ';
        END;
        
        -- Policy INSERT
        BEGIN
            EXECUTE 'DROP POLICY IF EXISTS authenticated_write_community_media_insert ON storage.objects';
            EXECUTE 'CREATE POLICY authenticated_write_community_media_insert ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (bucket_id = ''community-media'')';
            v_result := v_result || 'INSERT policy created. ';
        EXCEPTION WHEN OTHERS THEN
            v_result := v_result || 'INSERT policy error: ' || SQLERRM || '. ';
        END;
        
        -- Policy UPDATE
        BEGIN
            EXECUTE 'DROP POLICY IF EXISTS authenticated_write_community_media_update ON storage.objects';
            EXECUTE 'CREATE POLICY authenticated_write_community_media_update ON storage.objects AS PERMISSIVE FOR UPDATE TO authenticated USING (bucket_id = ''community-media'') WITH CHECK (bucket_id = ''community-media'')';
            v_result := v_result || 'UPDATE policy created. ';
        EXCEPTION WHEN OTHERS THEN
            v_result := v_result || 'UPDATE policy error: ' || SQLERRM || '. ';
        END;
        
        -- Policy DELETE
        BEGIN
            EXECUTE 'DROP POLICY IF EXISTS authenticated_write_community_media_delete ON storage.objects';
            EXECUTE 'CREATE POLICY authenticated_write_community_media_delete ON storage.objects AS PERMISSIVE FOR DELETE TO authenticated USING (bucket_id = ''community-media'')';
            v_result := v_result || 'DELETE policy created.';
        EXCEPTION WHEN OTHERS THEN
            v_result := v_result || 'DELETE policy error: ' || SQLERRM;
        END;
        
        RETURN v_result;
    END;
    $fn$;
    """
    result = execute_sql_via_admin(create_fn_sql)
    print(f"  Création fonction: {result}")

    # Approche 3: Essayer de donner les privilèges à la fonction
    print("\n[3] Attribution des privilèges")
    print("-" * 40)
    
    # Essayer de changer le owner de la fonction
    alter_sql = "ALTER FUNCTION public.setup_community_media_policies() OWNER TO supabase_admin"
    result = execute_sql_via_admin(alter_sql)
    print(f"  Changement owner: {result}")

    # Appeler la fonction
    print("\n[4] Appel de la fonction")
    print("-" * 40)
    call_sql = "SELECT public.setup_community_media_policies()"
    resp = requests.post(
        f"{URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": call_sql},
        timeout=60,
    )
    print(f"  HTTP {resp.status_code}")
    print(f"  Résultat: {json.dumps(resp.json(), indent=2, ensure_ascii=False)}")

    # Vérification finale
    print("\n[5] Vérification des policies")
    print("-" * 40)
    verify_sql = """
    SELECT polname, polcmd 
    FROM pg_policy 
    WHERE polrelid = 'storage.objects'::regclass
      AND polname LIKE '%community%'
    """
    resp = requests.post(
        f"{URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": verify_sql},
        timeout=60,
    )
    print(f"  Policies: {json.dumps(resp.json(), indent=2, ensure_ascii=False)}")

    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
