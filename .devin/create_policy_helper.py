#!/usr/bin/env python3
"""Crée une fonction helper SECURITY DEFINER pour créer les policies storage."""

import requests
import json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}


def execute_rpc(rpc_name: str, params: dict) -> dict:
    """Exécute une RPC."""
    resp = requests.post(
        f"{URL}/rest/v1/rpc/{rpc_name}",
        headers=HEADERS,
        json=params,
        timeout=60,
    )
    print(f"  HTTP {resp.status_code}")
    try:
        return resp.json()
    except:
        return {"raw": resp.text}


def main():
    print("=" * 60)
    print("CRÉATION FONCTION HELPER POUR POLICIES STORAGE")
    print("=" * 60)

    # 1. Créer une fonction helper qui crée les policies
    # Cette fonction doit être créée par un superuser
    print("\n[1] Création de la fonction helper")
    print("-" * 40)
    
    create_helper_sql = """
    CREATE OR REPLACE FUNCTION admin_create_storage_policies_for_community_media()
    RETURNS TEXT
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = storage, public
    AS $$
    BEGIN
        -- Drop existing policies if any
        DROP POLICY IF EXISTS public_read_community_media ON storage.objects;
        DROP POLICY IF EXISTS authenticated_write_community_media_insert ON storage.objects;
        DROP POLICY IF EXISTS authenticated_write_community_media_update ON storage.objects;
        DROP POLICY IF EXISTS authenticated_write_community_media_delete ON storage.objects;
        
        -- Create SELECT policy
        CREATE POLICY public_read_community_media
        ON storage.objects
        AS PERMISSIVE
        FOR SELECT
        TO anon, authenticated
        USING (bucket_id = 'community-media');
        
        -- Create INSERT policy
        CREATE POLICY authenticated_write_community_media_insert
        ON storage.objects
        AS PERMISSIVE
        FOR INSERT
        TO authenticated
        WITH CHECK (bucket_id = 'community-media');
        
        -- Create UPDATE policy
        CREATE POLICY authenticated_write_community_media_update
        ON storage.objects
        AS PERMISSIVE
        FOR UPDATE
        TO authenticated
        USING (bucket_id = 'community-media')
        WITH CHECK (bucket_id = 'community-media');
        
        -- Create DELETE policy
        CREATE POLICY authenticated_write_community_media_delete
        ON storage.objects
        AS PERMISSIVE
        FOR DELETE
        TO authenticated
        USING (bucket_id = 'community-media');
        
        RETURN 'Policies created successfully for community-media';
    END;
    $$;
    """
    
    result = execute_rpc("admin_execute_sql", {"p_sql": create_helper_sql})
    print(f"  Résultat création fonction: {json.dumps(result, indent=2)}")

    # 2. Appeler la fonction helper
    print("\n[2] Appel de la fonction helper")
    print("-" * 40)
    result = execute_rpc("admin_create_storage_policies_for_community_media", {})
    print(f"  Résultat: {json.dumps(result, indent=2)}")

    # 3. Vérification
    print("\n[3] Vérification des policies créées")
    print("-" * 40)
    verify_sql = """
    SELECT polname, polcmd 
    FROM pg_policy 
    WHERE polrelid = 'storage.objects'::regclass
      AND polname LIKE '%community%'
    """
    result = execute_rpc("execute_sql", {"sql_query": verify_sql})
    print(f"  Policies: {json.dumps(result, indent=2)}")

    print("\n" + "=" * 60)
    print("FIN")
    print("=" * 60)


if __name__ == "__main__":
    main()
