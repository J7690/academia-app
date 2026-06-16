#!/usr/bin/env python3
"""Dernière tentative : créer les policies via différentes approches."""

import requests
import json

PROJECT_REF = "thevdfcwlcqzdoybfvgs"
URL = f"https://{PROJECT_REF}.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}


def execute_sql(sql: str) -> dict:
    resp = requests.post(
        f"{URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": sql},
        timeout=60,
    )
    return resp.json()


def execute_admin_sql(sql: str) -> dict:
    resp = requests.post(
        f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers=HEADERS,
        json={"p_sql": sql},
        timeout=60,
    )
    return resp.json()


def main():
    print("=" * 60)
    print("DERNIÈRE TENTATIVE - APPROCHES ALTERNATIVES")
    print("=" * 60)

    # 1. Vérifier si on peut créer une fonction dans le schéma storage
    print("\n[1] Création fonction dans schéma storage")
    print("-" * 40)
    
    create_fn = """
    CREATE OR REPLACE FUNCTION storage.setup_community_policies()
    RETURNS TEXT
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    BEGIN
        DROP POLICY IF EXISTS public_read_community_media ON storage.objects;
        CREATE POLICY public_read_community_media ON storage.objects 
            AS PERMISSIVE FOR SELECT TO anon, authenticated 
            USING (bucket_id = 'community-media');
        
        DROP POLICY IF EXISTS authenticated_write_community_media_insert ON storage.objects;
        CREATE POLICY authenticated_write_community_media_insert ON storage.objects 
            AS PERMISSIVE FOR INSERT TO authenticated 
            WITH CHECK (bucket_id = 'community-media');
        
        DROP POLICY IF EXISTS authenticated_write_community_media_update ON storage.objects;
        CREATE POLICY authenticated_write_community_media_update ON storage.objects 
            AS PERMISSIVE FOR UPDATE TO authenticated 
            USING (bucket_id = 'community-media') 
            WITH CHECK (bucket_id = 'community-media');
        
        DROP POLICY IF EXISTS authenticated_write_community_media_delete ON storage.objects;
        CREATE POLICY authenticated_write_community_media_delete ON storage.objects 
            AS PERMISSIVE FOR DELETE TO authenticated 
            USING (bucket_id = 'community-media');
        
        RETURN 'OK';
    END;
    $$;
    """
    result = execute_admin_sql(create_fn)
    print(f"  Création: {json.dumps(result, indent=2)}")

    # 2. Changer le owner de la fonction
    print("\n[2] Changement owner vers supabase_storage_admin")
    print("-" * 40)
    result = execute_admin_sql("ALTER FUNCTION storage.setup_community_policies() OWNER TO supabase_storage_admin")
    print(f"  Résultat: {json.dumps(result, indent=2)}")

    # 3. Appeler la fonction
    print("\n[3] Appel de la fonction")
    print("-" * 40)
    result = execute_sql("SELECT storage.setup_community_policies()")
    print(f"  Résultat: {json.dumps(result, indent=2)}")

    # 4. Vérification
    print("\n[4] Vérification des policies")
    print("-" * 40)
    result = execute_sql("""
        SELECT polname, polcmd 
        FROM pg_policy 
        WHERE polrelid = 'storage.objects'::regclass
          AND polname LIKE '%community%'
    """)
    print(f"  Policies: {json.dumps(result, indent=2)}")

    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
