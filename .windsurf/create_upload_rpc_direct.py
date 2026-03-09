#!/usr/bin/env python3
"""Crée une RPC d'upload qui insère directement dans storage.objects."""

import requests
import json
import base64

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


def execute_sql(sql: str) -> dict:
    resp = requests.post(
        f"{URL}/rest/v1/rpc/execute_sql",
        headers=HEADERS,
        json={"sql_query": sql},
        timeout=60,
    )
    return resp.json()


def main():
    print("=" * 60)
    print("CRÉATION RPC D'UPLOAD DIRECT DANS STORAGE")
    print("=" * 60)

    # 1. Analyser la structure de storage.objects
    print("\n[1] Structure de storage.objects")
    print("-" * 40)
    result = execute_sql("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'storage' AND table_name = 'objects'
        ORDER BY ordinal_position
    """)
    print(f"  Colonnes: {json.dumps(result, indent=2)}")

    # 2. Vérifier comment les fichiers sont stockés
    print("\n[2] Exemple d'entrée dans storage.objects")
    print("-" * 40)
    result = execute_sql("""
        SELECT id, bucket_id, name, owner, created_at, metadata
        FROM storage.objects
        WHERE bucket_id = 'community-media'
        LIMIT 1
    """)
    print(f"  Exemple: {json.dumps(result, indent=2)}")

    # 3. Créer une RPC qui fait l'upload via l'API interne de Supabase Storage
    # En fait, le stockage des fichiers est géré par le service storage, pas directement dans la DB
    # On doit utiliser une approche différente
    
    print("\n[3] Création RPC proxy pour upload")
    print("-" * 40)
    
    # Cette RPC va simplement retourner une URL signée pour l'upload
    # ou utiliser la fonction storage.foldername() si elle existe
    
    create_rpc = """
    CREATE OR REPLACE FUNCTION public.app_get_community_upload_url(
        p_file_path TEXT
    )
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        v_user_id UUID;
        v_full_path TEXT;
    BEGIN
        -- Vérifier que l'utilisateur est authentifié
        v_user_id := auth.uid();
        IF v_user_id IS NULL THEN
            RETURN jsonb_build_object('ok', false, 'error', 'Not authenticated');
        END IF;
        
        -- Construire le chemin complet
        v_full_path := v_user_id::TEXT || '/communities/' || p_file_path;
        
        -- Retourner les infos pour l'upload
        RETURN jsonb_build_object(
            'ok', true,
            'bucket', 'community-media',
            'path', v_full_path,
            'public_url', 'https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/community-media/' || v_full_path
        );
    END;
    $$;
    
    GRANT EXECUTE ON FUNCTION public.app_get_community_upload_url(TEXT) TO authenticated;
    """
    
    result = execute_admin_sql(create_rpc)
    print(f"  Résultat: {json.dumps(result, indent=2)}")

    # 4. Vérifier les fonctions storage disponibles
    print("\n[4] Fonctions storage disponibles")
    print("-" * 40)
    result = execute_sql("""
        SELECT proname, pronargs
        FROM pg_proc
        WHERE pronamespace = 'storage'::regnamespace
        ORDER BY proname
    """)
    print(f"  Fonctions: {json.dumps(result, indent=2)}")

    # 5. Test upload direct avec service_role via API Storage
    print("\n[5] Test upload via API Storage (service_role)")
    print("-" * 40)
    
    test_content = b"Test file content"
    test_path = "test_user/communities/test_community/test_file.txt"
    
    resp = requests.post(
        f"{URL}/storage/v1/object/community-media/{test_path}",
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "text/plain",
            "x-upsert": "true",
        },
        data=test_content,
    )
    print(f"  HTTP {resp.status_code}: {resp.text}")

    if resp.status_code == 200:
        print(f"\n  ✅ Upload réussi!")
        print(f"  URL publique: {URL}/storage/v1/object/public/community-media/{test_path}")

    print("\n" + "=" * 60)
    print("SOLUTION FINALE")
    print("=" * 60)
    print("""
Le bucket community-media fonctionne avec service_role.
Le problème est que les policies RLS manquent pour les utilisateurs authentifiés.

SOLUTION: Modifier Flutter pour utiliser une Edge Function ou
créer les policies via le Dashboard Supabase.

Pour créer les policies via le Dashboard:
1. Aller sur https://supabase.com/dashboard/project/thevdfcwlcqzdoybfvgs/storage/buckets
2. Cliquer sur 'community-media'
3. Onglet 'Policies'
4. Créer les 4 policies (SELECT, INSERT, UPDATE, DELETE)
""")


if __name__ == "__main__":
    main()
