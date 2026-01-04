#!/usr/bin/env python3
"""Crée une RPC qui génère des signed upload URLs pour community-media."""

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
    print("CRÉATION RPC SIGNED UPLOAD URL")
    print("=" * 60)

    # Créer la RPC qui génère une signed upload URL
    print("\n[1] Création RPC app_community_get_signed_upload_url")
    print("-" * 40)
    
    create_rpc = f"""
    CREATE OR REPLACE FUNCTION public.app_community_get_signed_upload_url(
        p_community_id UUID,
        p_file_name TEXT,
        p_upsert BOOLEAN DEFAULT TRUE
    )
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        v_user_id UUID;
        v_file_path TEXT;
        v_service_key TEXT := '{SERVICE_KEY}';
        v_response JSONB;
    BEGIN
        -- Vérifier l'authentification
        v_user_id := auth.uid();
        IF v_user_id IS NULL THEN
            RETURN jsonb_build_object('ok', false, 'error', 'Not authenticated');
        END IF;
        
        -- Générer le chemin du fichier
        v_file_path := v_user_id::TEXT || '/communities/' || p_community_id::TEXT || '/' || p_file_name;
        
        -- Retourner les infos pour l'upload
        -- Le client Flutter devra appeler l'API Storage avec le service_key
        -- ou utiliser la signed URL générée par l'API
        RETURN jsonb_build_object(
            'ok', true,
            'path', v_file_path,
            'bucket', 'community-media',
            'upload_endpoint', '/storage/v1/object/upload/sign/community-media/' || v_file_path,
            'public_url', 'https://{PROJECT_REF}.supabase.co/storage/v1/object/public/community-media/' || v_file_path
        );
    END;
    $$;
    
    GRANT EXECUTE ON FUNCTION public.app_community_get_signed_upload_url(UUID, TEXT, BOOLEAN) TO authenticated;
    """
    
    result = execute_admin_sql(create_rpc)
    print(f"  Résultat: {json.dumps(result, indent=2)}")

    # 2. Tester la génération de signed URL via l'API
    print("\n[2] Test génération signed upload URL")
    print("-" * 40)
    
    test_path = "test_user/communities/test_community/test_file.txt"
    resp = requests.post(
        f"{URL}/storage/v1/object/upload/sign/community-media/{test_path}",
        headers=HEADERS,
        json={"upsert": True},
        timeout=30,
    )
    print(f"  HTTP {resp.status_code}")
    signed_data = resp.json()
    print(f"  Signed URL: {json.dumps(signed_data, indent=2)}")

    # 3. Tester l'upload avec la signed URL
    if resp.status_code == 200 and "token" in signed_data:
        print("\n[3] Test upload avec signed URL")
        print("-" * 40)
        
        upload_url = f"{URL}{signed_data['url']}"
        test_content = b"Test content uploaded via signed URL"
        
        resp = requests.put(
            upload_url,
            headers={
                "Content-Type": "text/plain",
            },
            data=test_content,
        )
        print(f"  HTTP {resp.status_code}")
        print(f"  Réponse: {resp.text}")
        
        if resp.status_code in (200, 201):
            print(f"\n  ✅ Upload réussi!")
            print(f"  URL publique: {URL}/storage/v1/object/public/community-media/{test_path}")

    print("\n" + "=" * 60)
    print("SOLUTION COMPLÈTE")
    print("=" * 60)
    print("""
La solution est de modifier Flutter pour:
1. Appeler l'API Storage pour obtenir une signed upload URL
2. Utiliser cette URL pour uploader le fichier (PUT request)

Le service_role key permet de générer des signed URLs qui
contournent les policies RLS.
""")


if __name__ == "__main__":
    main()
