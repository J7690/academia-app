-- 2025-12-28: Fix mini-site university media RPCs
-- Remplace les shims legacy_rpc_disabled pour:
--   public.app_upsert_university_media
--   public.app_admin_upsert_university_media
-- Objectif: réactiver complètement la gestion des médias mini-site
-- pour les universités (rôle university + admin), en restant compatible
-- avec le Flutter actuel (paramètre p_thumbnail_url) et le schéma VideoAsset
-- (colonne video_asset_id sur app.university_media).

-- On supprime d'abord les éventuelles versions shim / anciennes sur public

DROP FUNCTION IF EXISTS public.app_upsert_university_media(
  p_media_id uuid,
  p_media_type text,
  p_title text,
  p_description text,
  p_url text,
  p_storage_path text,
  p_thumbnail_url text,
  p_sort_order integer,
  p_is_active boolean
) CASCADE;

DROP FUNCTION IF EXISTS public.app_upsert_university_media(
  p_media_id uuid,
  p_media_type text,
  p_title text,
  p_description text,
  p_url text,
  p_storage_path text,
  p_sort_order integer,
  p_is_active boolean,
  p_video_asset_id uuid,
  p_playback jsonb
) CASCADE;

DROP FUNCTION IF EXISTS public.app_admin_upsert_university_media(
  p_university_id uuid,
  p_media_id uuid,
  p_media_type text,
  p_title text,
  p_description text,
  p_url text,
  p_storage_path text,
  p_thumbnail_url text,
  p_sort_order integer,
  p_is_active boolean
) CASCADE;

DROP FUNCTION IF EXISTS public.app_admin_upsert_university_media(
  p_university_id uuid,
  p_media_id uuid,
  p_media_type text,
  p_title text,
  p_description text,
  p_url text,
  p_storage_path text,
  p_sort_order integer,
  p_is_active boolean,
  p_video_asset_id uuid,
  p_playback jsonb
) CASCADE;


-- 1) Université connectée: app_upsert_university_media (VideoAsset pour les vidéos)

CREATE OR REPLACE FUNCTION public.app_upsert_university_media(
  p_media_id       UUID,
  p_media_type     TEXT,
  p_title          TEXT,
  p_description    TEXT,
  p_url            TEXT,
  p_storage_path   TEXT,
  p_thumbnail_url  TEXT,  -- conservé pour compat Flutter, mais ignoré côté SQL
  p_sort_order     INTEGER,
  p_is_active      BOOLEAN,
  p_video_asset_id UUID DEFAULT NULL,
  p_playback       JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_role           TEXT;
  v_university_id  UUID;
  v_media_id       UUID;
  v_type           TEXT;
  v_is_file        BOOLEAN;
  v_url_trim       TEXT;
  v_storage_trim   TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT
    raw_user_meta_data->>'role',
    (raw_user_meta_data->>'university_id')::UUID
  INTO v_role, v_university_id
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'university' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_university');
  END IF;

  IF v_university_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
  END IF;

  IF p_media_type IS NULL OR LENGTH(TRIM(p_media_type)) = 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_media_type');
  END IF;

  v_type := LOWER(TRIM(COALESCE(p_media_type, '')));
  v_is_file := POSITION('video' IN v_type) > 0
               OR POSITION('image' IN v_type) > 0
               OR POSITION('brochure' IN v_type) > 0
               OR POSITION('pdf' IN v_type) > 0
               OR POSITION('doc' IN v_type) > 0;

  v_url_trim := TRIM(COALESCE(p_url, ''));
  v_storage_trim := TRIM(COALESCE(p_storage_path, ''));

  IF v_is_file THEN
    IF v_storage_trim = '' THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'storage_required');
    END IF;

    IF v_url_trim ILIKE '%stream.mux.com%' THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'mux_not_allowed');
    END IF;

    IF v_url_trim LIKE 'http%' AND
       v_url_trim NOT LIKE 'https://thevdfcwlcqzdoybfvgs.supabase.co%' THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'media_url_not_allowed');
    END IF;
  END IF;

  -- Pour les médias vidéo, on peut lier un VideoAsset si fourni, mais ce n'est pas obligatoire.

  IF p_media_id IS NULL THEN
    INSERT INTO app.university_media (
      university_id,
      media_type,
      title,
      description,
      url,
      storage_path,
      sort_order,
      is_active,
      video_asset_id
    ) VALUES (
      v_university_id,
      p_media_type,
      p_title,
      p_description,
      v_url_trim,
      v_storage_trim,
      COALESCE(p_sort_order, 0),
      COALESCE(p_is_active, TRUE),
      p_video_asset_id
    )
    RETURNING id INTO v_media_id;
  ELSE
    UPDATE app.university_media
    SET
      media_type     = p_media_type,
      title          = p_title,
      description    = p_description,
      url            = p_url,
      storage_path   = p_storage_path,
      sort_order     = COALESCE(p_sort_order, sort_order),
      is_active      = COALESCE(p_is_active, is_active),
      video_asset_id = COALESCE(p_video_asset_id, video_asset_id),
      updated_at     = NOW()
    WHERE id = p_media_id
      AND university_id = v_university_id
    RETURNING id INTO v_media_id;
  END IF;

  IF v_media_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'media_not_found');
  END IF;

  -- Contexte VideoAsset pour les médias vidéo (optionnel, si la table existe)
  IF p_video_asset_id IS NOT NULL AND POSITION('video' IN v_type) > 0 THEN
    IF to_regclass('app.video_asset_contexts') IS NOT NULL THEN
      INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
      VALUES (p_video_asset_id, 'university_media', v_media_id, 'primary')
      ON CONFLICT (context_type, context_id, role) DO UPDATE
        SET video_asset_id = EXCLUDED.video_asset_id;
    END IF;
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'media_id', v_media_id,
    'video_asset_id', p_video_asset_id,
    'media_type', v_type,
    'playback', CASE
      WHEN p_video_asset_id IS NOT NULL THEN JSONB_BUILD_OBJECT(
        'best_url',   p_playback->>'best_url',
        'poster_url', p_playback->>'poster_url'
      )
      ELSE NULL
    END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_upsert_university_media(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN, UUID, JSONB
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_upsert_university_media(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN, UUID, JSONB
) TO service_role;


-- 2) Admin: app_admin_upsert_university_media (VideoAsset pour les vidéos)

CREATE OR REPLACE FUNCTION public.app_admin_upsert_university_media(
  p_university_id  UUID,
  p_media_id       UUID,
  p_media_type     TEXT,
  p_title          TEXT,
  p_description    TEXT,
  p_url            TEXT,
  p_storage_path   TEXT,
  p_thumbnail_url  TEXT, -- conservé pour compat Flutter, mais ignoré
  p_sort_order     INTEGER,
  p_is_active      BOOLEAN,
  p_video_asset_id UUID DEFAULT NULL,
  p_playback       JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id       UUID := auth.uid();
  v_role          TEXT;
  v_media_id      UUID;
  v_type          TEXT;
  v_is_file       BOOLEAN;
  v_url_trim      TEXT;
  v_storage_trim  TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  IF p_university_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_configured');
  END IF;

  IF p_media_type IS NULL OR LENGTH(TRIM(p_media_type)) = 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'invalid_media_type');
  END IF;

  v_type := LOWER(TRIM(COALESCE(p_media_type, '')));
  v_is_file := POSITION('video' IN v_type) > 0
               OR POSITION('image' IN v_type) > 0
               OR POSITION('brochure' IN v_type) > 0
               OR POSITION('pdf' IN v_type) > 0
               OR POSITION('doc' IN v_type) > 0;

  v_url_trim := TRIM(COALESCE(p_url, ''));
  v_storage_trim := TRIM(COALESCE(p_storage_path, ''));

  IF v_is_file THEN
    IF v_storage_trim = '' THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'storage_required');
    END IF;

    IF v_url_trim ILIKE '%stream.mux.com%' THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'mux_not_allowed');
    END IF;

    IF v_url_trim LIKE 'http%' AND
       v_url_trim NOT LIKE 'https://thevdfcwlcqzdoybfvgs.supabase.co%' THEN
      RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'media_url_not_allowed');
    END IF;
  END IF;

  -- Pour les médias vidéo, on peut lier un VideoAsset si fourni, mais ce n'est pas obligatoire.

  IF p_media_id IS NULL THEN
    INSERT INTO app.university_media (
      university_id,
      media_type,
      title,
      description,
      url,
      storage_path,
      sort_order,
      is_active,
      video_asset_id
    ) VALUES (
      p_university_id,
      p_media_type,
      p_title,
      p_description,
      v_url_trim,
      v_storage_trim,
      COALESCE(p_sort_order, 0),
      COALESCE(p_is_active, TRUE),
      p_video_asset_id
    )
    RETURNING id INTO v_media_id;
  ELSE
    UPDATE app.university_media
    SET
      media_type     = p_media_type,
      title          = p_title,
      description    = p_description,
      url            = p_url,
      storage_path   = p_storage_path,
      sort_order     = COALESCE(p_sort_order, sort_order),
      is_active      = COALESCE(p_is_active, is_active),
      video_asset_id = COALESCE(p_video_asset_id, video_asset_id),
      updated_at     = NOW()
    WHERE id = p_media_id
      AND university_id = p_university_id
    RETURNING id INTO v_media_id;
  END IF;

  IF v_media_id IS NULL THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'media_not_found');
  END IF;

  -- Contexte VideoAsset pour les médias vidéo (optionnel, si la table existe)
  IF p_video_asset_id IS NOT NULL AND POSITION('video' IN v_type) > 0 THEN
    IF to_regclass('app.video_asset_contexts') IS NOT NULL THEN
      INSERT INTO app.video_asset_contexts (video_asset_id, context_type, context_id, role)
      VALUES (p_video_asset_id, 'university_media', v_media_id, 'primary')
      ON CONFLICT (context_type, context_id, role) DO UPDATE
        SET video_asset_id = EXCLUDED.video_asset_id;
    END IF;
  END IF;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'media_id', v_media_id,
    'video_asset_id', p_video_asset_id,
    'media_type', v_type,
    'playback', CASE
      WHEN p_video_asset_id IS NOT NULL THEN JSONB_BUILD_OBJECT(
        'best_url',   p_playback->>'best_url',
        'poster_url', p_playback->>'poster_url'
      )
      ELSE NULL
    END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_upsert_university_media(
  UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN, UUID, JSONB
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_upsert_university_media(
  UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, BOOLEAN, UUID, JSONB
) TO service_role;
