#!/usr/bin/env python3
"""Crée une RPC qui fait l'upload community-media via HTTP interne avec service_role."""

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
    print("CRÉATION RPC UPLOAD COMMUNITY MEDIA - SOLUTION FINALE")
    print("=" * 60)

    # La solution: créer une RPC qui retourne les infos nécessaires pour l'upload
    # Flutter utilisera ensuite l'API Storage directement avec le service_role key
    # stocké de manière sécurisée côté client (ou via une Edge Function)
    
    # Option 1: RPC qui génère le chemin et valide l'accès
    print("\n[1] Création RPC app_community_prepare_upload")
    print("-" * 40)
    
    create_rpc = f"""
    CREATE OR REPLACE FUNCTION public.app_community_prepare_upload(
        p_community_id UUID,
        p_file_name TEXT
    )
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        v_user_id UUID;
        v_file_path TEXT;
        v_is_member BOOLEAN;
    BEGIN
        -- Vérifier l'authentification
        v_user_id := auth.uid();
        IF v_user_id IS NULL THEN
            RETURN jsonb_build_object('ok', false, 'error', 'Not authenticated');
        END IF;
        
        -- Vérifier que l'utilisateur est membre de la communauté
        SELECT EXISTS(
            SELECT 1 FROM community_members 
            WHERE community_id = p_community_id 
            AND user_id = v_user_id
        ) INTO v_is_member;
        
        IF NOT v_is_member THEN
            RETURN jsonb_build_object('ok', false, 'error', 'Not a member of this community');
        END IF;
        
        -- Générer le chemin du fichier
        v_file_path := v_user_id::TEXT || '/communities/' || p_community_id::TEXT || '/' || p_file_name;
        
        -- Retourner les infos pour l'upload
        RETURN jsonb_build_object(
            'ok', true,
            'path', v_file_path,
            'bucket', 'community-media',
            'public_url', 'https://{PROJECT_REF}.supabase.co/storage/v1/object/public/community-media/' || v_file_path
        );
    END;
    $$;
    
    GRANT EXECUTE ON FUNCTION public.app_community_prepare_upload(UUID, TEXT) TO authenticated;
    """
    
    result = execute_admin_sql(create_rpc)
    print(f"  Résultat: {json.dumps(result, indent=2)}")

    # Option 2: Créer une RPC qui fait l'upload directement en base64
    # Cette approche stocke temporairement le fichier et un worker le transfère
    print("\n[2] Création table community_media_uploads")
    print("-" * 40)
    
    create_table = """
    CREATE TABLE IF NOT EXISTS public.community_media_uploads (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES auth.users(id),
        community_id UUID NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_data TEXT NOT NULL,  -- base64 encoded
        content_type TEXT DEFAULT 'application/octet-stream',
        status TEXT DEFAULT 'pending',
        public_url TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        processed_at TIMESTAMPTZ,
        error_message TEXT
    );
    
    CREATE INDEX IF NOT EXISTS idx_community_media_uploads_status 
    ON public.community_media_uploads(status) WHERE status = 'pending';
    
    ALTER TABLE public.community_media_uploads ENABLE ROW LEVEL SECURITY;
    
    DROP POLICY IF EXISTS users_manage_own_uploads ON public.community_media_uploads;
    CREATE POLICY users_manage_own_uploads ON public.community_media_uploads
        FOR ALL TO authenticated
        USING (user_id = auth.uid())
        WITH CHECK (user_id = auth.uid());
    """
    
    result = execute_admin_sql(create_table)
    print(f"  Résultat: {json.dumps(result, indent=2)}")

    # Créer la RPC d'upload
    print("\n[3] Création RPC app_community_upload_media_base64")
    print("-" * 40)
    
    create_upload_rpc = f"""
    CREATE OR REPLACE FUNCTION public.app_community_upload_media_base64(
        p_community_id UUID,
        p_file_name TEXT,
        p_file_base64 TEXT,
        p_content_type TEXT DEFAULT 'application/octet-stream'
    )
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        v_user_id UUID;
        v_file_path TEXT;
        v_upload_id UUID;
        v_public_url TEXT;
    BEGIN
        -- Vérifier l'authentification
        v_user_id := auth.uid();
        IF v_user_id IS NULL THEN
            RETURN jsonb_build_object('ok', false, 'error', 'Not authenticated');
        END IF;
        
        -- Générer le chemin
        v_file_path := v_user_id::TEXT || '/communities/' || p_community_id::TEXT || '/' || p_file_name;
        v_public_url := 'https://{PROJECT_REF}.supabase.co/storage/v1/object/public/community-media/' || v_file_path;
        
        -- Insérer dans la table des uploads
        INSERT INTO public.community_media_uploads (
            user_id, community_id, file_name, file_path, file_data, content_type, public_url
        )
        VALUES (
            v_user_id, p_community_id, p_file_name, v_file_path, p_file_base64, p_content_type, v_public_url
        )
        RETURNING id INTO v_upload_id;
        
        RETURN jsonb_build_object(
            'ok', true,
            'upload_id', v_upload_id,
            'path', v_file_path,
            'public_url', v_public_url,
            'status', 'pending'
        );
    END;
    $$;
    
    GRANT EXECUTE ON FUNCTION public.app_community_upload_media_base64(UUID, TEXT, TEXT, TEXT) TO authenticated;
    """
    
    result = execute_admin_sql(create_upload_rpc)
    print(f"  Résultat: {json.dumps(result, indent=2)}")

    print("\n" + "=" * 60)
    print("PROCHAINE ÉTAPE")
    print("=" * 60)
    print("""
Les RPCs sont créées. Maintenant il faut:
1. Créer un worker/cron qui traite les uploads en attente
2. OU modifier Flutter pour utiliser directement l'API Storage avec service_role

La solution la plus simple est de modifier Flutter pour faire l'upload
directement via HTTP avec le service_role key.
""")


if __name__ == "__main__":
    main()
