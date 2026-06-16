#!/usr/bin/env python3
"""Crée une RPC d'upload qui utilise l'extension http pour uploader vers Storage."""

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
    print("CRÉATION RPC D'UPLOAD COMMUNITY MEDIA")
    print("=" * 60)

    # 1. Vérifier si l'extension http est disponible
    print("\n[1] Vérification extension http")
    print("-" * 40)
    result = execute_sql("SELECT extname FROM pg_extension WHERE extname = 'http'")
    print(f"  Extension http: {json.dumps(result, indent=2)}")
    
    has_http = result and isinstance(result, list) and len(result) > 0

    if not has_http:
        print("  Extension http non disponible, tentative d'activation...")
        result = execute_admin_sql("CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions")
        print(f"  Résultat: {json.dumps(result, indent=2)}")

    # 2. Créer la fonction RPC d'upload
    print("\n[2] Création de la RPC app_upload_community_media")
    print("-" * 40)
    
    # Cette RPC utilise l'extension http pour faire un POST vers l'API Storage
    create_rpc = f"""
    CREATE OR REPLACE FUNCTION public.app_upload_community_media(
        p_file_path TEXT,
        p_file_bytes BYTEA,
        p_content_type TEXT DEFAULT 'application/octet-stream'
    )
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public, extensions
    AS $$
    DECLARE
        v_user_id UUID;
        v_response extensions.http_response;
        v_storage_url TEXT;
        v_service_key TEXT := '{SERVICE_KEY}';
        v_result JSONB;
    BEGIN
        -- Vérifier que l'utilisateur est authentifié
        v_user_id := auth.uid();
        IF v_user_id IS NULL THEN
            RETURN jsonb_build_object('ok', false, 'error', 'Not authenticated');
        END IF;
        
        -- Construire l'URL de l'API Storage
        v_storage_url := 'https://{PROJECT_REF}.supabase.co/storage/v1/object/community-media/' || p_file_path;
        
        -- Faire l'upload via l'extension http
        SELECT * INTO v_response FROM extensions.http((
            'POST',
            v_storage_url,
            ARRAY[
                extensions.http_header('apikey', v_service_key),
                extensions.http_header('Authorization', 'Bearer ' || v_service_key),
                extensions.http_header('Content-Type', p_content_type),
                extensions.http_header('x-upsert', 'true')
            ],
            p_content_type,
            p_file_bytes
        )::extensions.http_request);
        
        -- Vérifier le résultat
        IF v_response.status >= 200 AND v_response.status < 300 THEN
            v_result := jsonb_build_object(
                'ok', true,
                'url', 'https://{PROJECT_REF}.supabase.co/storage/v1/object/public/community-media/' || p_file_path
            );
        ELSE
            v_result := jsonb_build_object(
                'ok', false,
                'error', v_response.content,
                'status', v_response.status
            );
        END IF;
        
        RETURN v_result;
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
    END;
    $$;
    
    -- Accorder les permissions
    GRANT EXECUTE ON FUNCTION public.app_upload_community_media(TEXT, BYTEA, TEXT) TO authenticated;
    """
    
    result = execute_admin_sql(create_rpc)
    print(f"  Résultat: {json.dumps(result, indent=2)}")

    # 3. Tester la RPC
    print("\n[3] Test de la RPC (sans auth, devrait échouer)")
    print("-" * 40)
    
    # Test sans authentification
    resp = requests.post(
        f"{URL}/rest/v1/rpc/app_upload_community_media",
        headers=HEADERS,
        json={
            "p_file_path": "test/rpc_test.txt",
            "p_file_bytes": "\\x48656c6c6f",  # "Hello" en hex
            "p_content_type": "text/plain"
        },
        timeout=60,
    )
    print(f"  HTTP {resp.status_code}: {json.dumps(resp.json(), indent=2)}")

    print("\n" + "=" * 60)
    print("PROCHAINE ÉTAPE")
    print("=" * 60)
    print("""
Si la RPC fonctionne, modifier Flutter pour utiliser cette RPC
au lieu de l'appel direct au Storage SDK.
""")


if __name__ == "__main__":
    main()
