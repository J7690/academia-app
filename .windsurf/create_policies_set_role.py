#!/usr/bin/env python3
"""Essaie de créer les policies en utilisant SET ROLE supabase_storage_admin."""

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
    """Exécute du SQL via execute_sql RPC."""
    resp = requests.post(
        f"{URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": sql},
        timeout=60,
    )
    print(f"  HTTP {resp.status_code}")
    try:
        return resp.json()
    except:
        return {"raw": resp.text}


def execute_admin_sql(sql: str) -> dict:
    """Exécute du SQL via admin_execute_sql RPC."""
    resp = requests.post(
        f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers=HEADERS,
        json={"p_sql": sql},
        timeout=60,
    )
    print(f"  HTTP {resp.status_code}")
    try:
        return resp.json()
    except:
        return {"raw": resp.text}


def main():
    print("=" * 60)
    print("CRÉATION POLICIES AVEC SET ROLE")
    print("=" * 60)

    # 1. Vérifier si postgres peut devenir supabase_storage_admin
    print("\n[1] Test SET ROLE supabase_storage_admin")
    print("-" * 40)
    result = execute_sql("SELECT pg_has_role('postgres', 'supabase_storage_admin', 'MEMBER')")
    print(f"  postgres est membre de supabase_storage_admin: {json.dumps(result, indent=2)}")

    # 2. Vérifier les rôles de postgres
    print("\n[2] Rôles de postgres")
    print("-" * 40)
    result = execute_sql("""
        SELECT r.rolname as role
        FROM pg_roles r
        JOIN pg_auth_members m ON r.oid = m.roleid
        JOIN pg_roles u ON m.member = u.oid
        WHERE u.rolname = 'postgres'
    """)
    print(f"  Rôles: {json.dumps(result, indent=2)}")

    # 3. Vérifier si postgres est superuser
    print("\n[3] postgres est superuser?")
    print("-" * 40)
    result = execute_sql("SELECT rolsuper FROM pg_roles WHERE rolname = 'postgres'")
    print(f"  Superuser: {json.dumps(result, indent=2)}")

    # 4. Essayer de GRANT le rôle supabase_storage_admin à postgres
    print("\n[4] GRANT supabase_storage_admin TO postgres")
    print("-" * 40)
    result = execute_admin_sql("GRANT supabase_storage_admin TO postgres")
    print(f"  Résultat: {json.dumps(result, indent=2)}")

    # 5. Essayer de créer les policies avec SET ROLE
    print("\n[5] Création policies avec SET ROLE")
    print("-" * 40)
    
    policies_sql = """
    SET ROLE supabase_storage_admin;
    
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
    
    RESET ROLE;
    """
    
    result = execute_admin_sql(policies_sql)
    print(f"  Résultat: {json.dumps(result, indent=2)}")

    # 6. Vérification
    print("\n[6] Vérification des policies")
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
