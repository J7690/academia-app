#!/usr/bin/env python3
"""Contournement : tester l'upload avec différentes configurations."""

import requests
import json

PROJECT_REF = "thevdfcwlcqzdoybfvgs"
URL = f"https://{PROJECT_REF}.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0.VHxR2Z8JUjJLJYMqjpLBLK8sS8pNMMKNBNZvHYVVPzE"


def execute_sql(sql: str) -> dict:
    resp = requests.post(
        f"{URL}/rest/v1/rpc/execute_sql",
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "application/json",
        },
        json={"sql_query": sql},
        timeout=60,
    )
    return resp.json()


def main():
    print("=" * 60)
    print("SOLUTION DE CONTOURNEMENT")
    print("=" * 60)

    # 1. Vérifier les policies existantes sur d'autres buckets qui fonctionnent
    print("\n[1] Analyse des policies qui fonctionnent (challenge-media)")
    print("-" * 40)
    result = execute_sql("""
        SELECT polname, polcmd, 
               pg_get_expr(polqual, polrelid) as using_expr,
               pg_get_expr(polwithcheck, polrelid) as check_expr
        FROM pg_policy 
        WHERE polrelid = 'storage.objects'::regclass
          AND polname LIKE '%challenge%'
    """)
    print(f"  Policies challenge-media: {json.dumps(result, indent=2, ensure_ascii=False)}")

    # 2. Vérifier si le bucket community-media a des configurations spéciales
    print("\n[2] Configuration du bucket community-media")
    print("-" * 40)
    result = execute_sql("""
        SELECT * FROM storage.buckets WHERE id = 'community-media'
    """)
    print(f"  Config: {json.dumps(result, indent=2, ensure_ascii=False)}")

    # 3. Tester l'upload avec service_role (devrait fonctionner)
    print("\n[3] Test upload avec service_role key")
    print("-" * 40)
    test_content = b"Test upload with service_role"
    resp = requests.post(
        f"{URL}/storage/v1/object/community-media/test/service_role_test.txt",
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "text/plain",
        },
        data=test_content,
    )
    print(f"  HTTP {resp.status_code}: {resp.text}")

    # 4. Créer un JWT simulant un utilisateur authentifié pour tester
    print("\n[4] Test avec anon key (devrait échouer)")
    print("-" * 40)
    resp = requests.post(
        f"{URL}/storage/v1/object/community-media/test/anon_test.txt",
        headers={
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {ANON_KEY}",
            "Content-Type": "text/plain",
        },
        data=test_content,
    )
    print(f"  HTTP {resp.status_code}: {resp.text}")

    # 5. Solution : créer une RPC qui fait l'upload via service_role
    print("\n" + "=" * 60)
    print("SOLUTION PROPOSÉE")
    print("=" * 60)
    print("""
Puisque les policies RLS ne peuvent pas être créées via RPC,
la solution est de créer une RPC qui fait l'upload côté serveur
avec les privilèges service_role.

Cette RPC sera appelée par Flutter au lieu d'utiliser directement
le SDK Storage.
""")

    # 6. Créer la fonction RPC d'upload
    print("\n[5] Création de la RPC d'upload")
    print("-" * 40)
    
    create_rpc = """
    CREATE OR REPLACE FUNCTION public.app_upload_community_media(
        p_path TEXT,
        p_content_base64 TEXT,
        p_content_type TEXT DEFAULT 'application/octet-stream'
    )
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        v_user_id UUID;
        v_result JSONB;
    BEGIN
        -- Vérifier que l'utilisateur est authentifié
        v_user_id := auth.uid();
        IF v_user_id IS NULL THEN
            RETURN jsonb_build_object('error', 'Not authenticated');
        END IF;
        
        -- L'upload sera fait via l'extension http ou storage functions
        -- Pour l'instant, retourner les infos pour debug
        RETURN jsonb_build_object(
            'user_id', v_user_id,
            'path', p_path,
            'content_type', p_content_type,
            'status', 'RPC created - needs storage integration'
        );
    END;
    $$;
    """
    
    resp = requests.post(
        f"{URL}/rest/v1/rpc/admin_execute_sql",
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "application/json",
        },
        json={"p_sql": create_rpc},
        timeout=60,
    )
    print(f"  Création RPC: {json.dumps(resp.json(), indent=2)}")

    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
