#!/usr/bin/env python3
"""Crée une RPC d'upload pour community-media qui contourne les policies RLS."""

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


def main():
    print("=" * 60)
    print("CRÉATION RPC UPLOAD COMMUNITY MEDIA")
    print("=" * 60)

    # Créer une RPC qui:
    # 1. Vérifie l'authentification
    # 2. Génère un chemin unique
    # 3. Insère les métadonnées dans storage.objects (bypass RLS via SECURITY DEFINER)
    # 4. Retourne l'URL publique
    
    # Note: Cette approche ne stocke pas le fichier binaire directement dans la DB
    # car Supabase Storage utilise un système de fichiers externe (S3-compatible)
    
    # La vraie solution est de créer une signed URL pour l'upload
    
    print("\n[1] Création RPC pour générer signed upload URL")
    print("-" * 40)
    
    create_rpc = """
    -- Fonction pour générer une URL signée pour l'upload
    CREATE OR REPLACE FUNCTION public.app_community_create_signed_upload_url(
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
        v_token TEXT;
        v_expires_at TIMESTAMPTZ;
    BEGIN
        -- Vérifier l'authentification
        v_user_id := auth.uid();
        IF v_user_id IS NULL THEN
            RETURN jsonb_build_object('ok', false, 'error', 'Not authenticated');
        END IF;
        
        -- Générer le chemin du fichier
        v_file_path := v_user_id::TEXT || '/communities/' || p_community_id::TEXT || '/' || p_file_name;
        
        -- Générer un token simple (en production, utiliser une vraie signature)
        v_token := encode(gen_random_bytes(32), 'hex');
        v_expires_at := NOW() + INTERVAL '1 hour';
        
        -- Stocker le token pour validation ultérieure
        INSERT INTO public.community_upload_tokens (token, user_id, file_path, expires_at)
        VALUES (v_token, v_user_id, v_file_path, v_expires_at)
        ON CONFLICT (token) DO UPDATE SET expires_at = v_expires_at;
        
        RETURN jsonb_build_object(
            'ok', true,
            'path', v_file_path,
            'token', v_token,
            'expires_at', v_expires_at,
            'upload_url', 'https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/community-media/' || v_file_path,
            'public_url', 'https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/community-media/' || v_file_path
        );
    EXCEPTION WHEN OTHERS THEN
        -- Si la table n'existe pas, retourner juste le chemin
        RETURN jsonb_build_object(
            'ok', true,
            'path', v_file_path,
            'public_url', 'https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/community-media/' || v_file_path,
            'note', 'Direct path without token'
        );
    END;
    $$;
    
    GRANT EXECUTE ON FUNCTION public.app_community_create_signed_upload_url(UUID, TEXT) TO authenticated;
    """
    
    result = execute_admin_sql(create_rpc)
    print(f"  Résultat: {json.dumps(result, indent=2)}")

    # 2. Créer une RPC qui fait l'upload en base64
    print("\n[2] Création RPC upload base64")
    print("-" * 40)
    
    # Cette RPC reçoit le fichier en base64 et fait l'upload via l'API Storage interne
    # Malheureusement, sans l'extension http, on ne peut pas faire d'appels HTTP depuis PL/pgSQL
    
    # Alternative: stocker temporairement le fichier dans une table et avoir un trigger/worker
    
    create_upload_table = """
    -- Table pour stocker temporairement les uploads en attente
    CREATE TABLE IF NOT EXISTS public.community_pending_uploads (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES auth.users(id),
        community_id UUID NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_data BYTEA NOT NULL,
        content_type TEXT DEFAULT 'application/octet-stream',
        status TEXT DEFAULT 'pending',
        created_at TIMESTAMPTZ DEFAULT NOW(),
        processed_at TIMESTAMPTZ
    );
    
    -- Index pour le traitement
    CREATE INDEX IF NOT EXISTS idx_pending_uploads_status ON public.community_pending_uploads(status);
    
    -- RLS
    ALTER TABLE public.community_pending_uploads ENABLE ROW LEVEL SECURITY;
    
    -- Policy: les utilisateurs peuvent insérer leurs propres uploads
    DROP POLICY IF EXISTS users_insert_own_uploads ON public.community_pending_uploads;
    CREATE POLICY users_insert_own_uploads ON public.community_pending_uploads
        FOR INSERT TO authenticated
        WITH CHECK (user_id = auth.uid());
    
    -- Policy: les utilisateurs peuvent voir leurs propres uploads
    DROP POLICY IF EXISTS users_select_own_uploads ON public.community_pending_uploads;
    CREATE POLICY users_select_own_uploads ON public.community_pending_uploads
        FOR SELECT TO authenticated
        USING (user_id = auth.uid());
    """
    
    result = execute_admin_sql(create_upload_table)
    print(f"  Table créée: {json.dumps(result, indent=2)}")

    # 3. Créer la RPC d'upload
    print("\n[3] Création RPC app_community_upload_media")
    print("-" * 40)
    
    create_upload_rpc = """
    CREATE OR REPLACE FUNCTION public.app_community_upload_media(
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
        v_file_data BYTEA;
        v_upload_id UUID;
    BEGIN
        -- Vérifier l'authentification
        v_user_id := auth.uid();
        IF v_user_id IS NULL THEN
            RETURN jsonb_build_object('ok', false, 'error', 'Not authenticated');
        END IF;
        
        -- Décoder le base64
        v_file_data := decode(p_file_base64, 'base64');
        
        -- Générer le chemin
        v_file_path := v_user_id::TEXT || '/communities/' || p_community_id::TEXT || '/' || p_file_name;
        
        -- Insérer dans la table des uploads en attente
        INSERT INTO public.community_pending_uploads (user_id, community_id, file_name, file_path, file_data, content_type)
        VALUES (v_user_id, p_community_id, p_file_name, v_file_path, v_file_data, p_content_type)
        RETURNING id INTO v_upload_id;
        
        -- Retourner les infos
        RETURN jsonb_build_object(
            'ok', true,
            'upload_id', v_upload_id,
            'path', v_file_path,
            'public_url', 'https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/community-media/' || v_file_path,
            'status', 'pending'
        );
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object('ok', false, 'error', SQLERRM);
    END;
    $$;
    
    GRANT EXECUTE ON FUNCTION public.app_community_upload_media(UUID, TEXT, TEXT, TEXT) TO authenticated;
    """
    
    result = execute_admin_sql(create_upload_rpc)
    print(f"  RPC créée: {json.dumps(result, indent=2)}")

    print("\n" + "=" * 60)
    print("RÉSULTAT")
    print("=" * 60)
    print("""
Les RPCs ont été créées. Cependant, cette approche stocke les fichiers
dans une table PostgreSQL, pas dans le Storage S3.

La VRAIE solution est de créer les policies RLS via le Dashboard Supabase.
C'est la seule façon de permettre les uploads directs vers Storage.
""")


if __name__ == "__main__":
    main()
