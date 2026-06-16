-- Marketplace listing media management RPCs (merchant + admin)

CREATE OR REPLACE FUNCTION public.app_merchant_list_marketplace_listing_media(
  p_listing_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_role text;
  v_base_url text := 'https://thevdfcwlcqzdoybfvgs.supabase.co';
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  IF p_listing_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'listing_id_required');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM app.marketplace_listings l
    WHERE l.id = p_listing_id
      AND l.merchant_id = v_user
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_owner');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', ml.id,
            'listing_id', ml.listing_id,
            'media_type', ml.media_type,
            'title', ml.title,
            'description', ml.description,
            'storage_bucket', ml.storage_bucket,
            'storage_path', ml.storage_path,
            'external_url', ml.external_url,
            'sort_order', ml.sort_order,
            'is_active', ml.is_active,
            'created_at', ml.created_at,
            'url', COALESCE(
              NULLIF(ml.external_url, ''),
              CASE
                WHEN ml.storage_path IS NOT NULL AND ml.storage_path <> ''
                THEN (v_base_url || '/storage/v1/object/public/' || ml.storage_bucket || '/' || ml.storage_path)
                ELSE NULL
              END
            )
          )
          ORDER BY ml.sort_order ASC, ml.created_at ASC
        ),
        '[]'::jsonb
      )
      FROM app.marketplace_listing_media ml
      WHERE ml.listing_id = p_listing_id
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_list_marketplace_listing_media(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.app_merchant_disable_marketplace_listing_media(
  p_media_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_role text;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'merchant' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_merchant');
  END IF;

  IF p_media_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'media_id_required');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM app.marketplace_listing_media ml
    JOIN app.marketplace_listings l ON l.id = ml.listing_id
    WHERE ml.id = p_media_id
      AND l.merchant_id = v_user
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_owner');
  END IF;

  UPDATE app.marketplace_listing_media
  SET is_active = false,
      updated_at = now()
  WHERE id = p_media_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_merchant_disable_marketplace_listing_media(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.app_admin_list_marketplace_listing_media(
  p_listing_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_role text;
  v_base_url text := 'https://thevdfcwlcqzdoybfvgs.supabase.co';
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  IF p_listing_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'listing_id_required');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', ml.id,
            'listing_id', ml.listing_id,
            'media_type', ml.media_type,
            'title', ml.title,
            'description', ml.description,
            'storage_bucket', ml.storage_bucket,
            'storage_path', ml.storage_path,
            'external_url', ml.external_url,
            'sort_order', ml.sort_order,
            'is_active', ml.is_active,
            'created_at', ml.created_at,
            'url', COALESCE(
              NULLIF(ml.external_url, ''),
              CASE
                WHEN ml.storage_path IS NOT NULL AND ml.storage_path <> ''
                THEN (v_base_url || '/storage/v1/object/public/' || ml.storage_bucket || '/' || ml.storage_path)
                ELSE NULL
              END
            )
          )
          ORDER BY ml.sort_order ASC, ml.created_at ASC
        ),
        '[]'::jsonb
      )
      FROM app.marketplace_listing_media ml
      WHERE ml.listing_id = p_listing_id
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_list_marketplace_listing_media(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.app_admin_disable_marketplace_listing_media(
  p_media_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_role text;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  IF p_media_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'media_id_required');
  END IF;

  UPDATE app.marketplace_listing_media
  SET is_active = false,
      updated_at = now()
  WHERE id = p_media_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_disable_marketplace_listing_media(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.app_admin_add_marketplace_listing_media(
  p_listing_id uuid,
  p_storage_path text,
  p_sort_order integer DEFAULT 0,
  p_media_type text DEFAULT 'image',
  p_external_url text DEFAULT NULL,
  p_title text DEFAULT NULL,
  p_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_role text;
  v_media_id uuid;
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  v_role := public.app_get_current_role();
  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  IF p_listing_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_listing_id');
  END IF;

  INSERT INTO app.marketplace_listing_media(
    listing_id,
    media_type,
    title,
    description,
    storage_bucket,
    storage_path,
    external_url,
    sort_order,
    is_active,
    updated_at
  ) VALUES (
    p_listing_id,
    COALESCE(NULLIF(trim(p_media_type), ''), 'image'),
    p_title,
    p_description,
    'landing-media',
    NULLIF(trim(p_storage_path), ''),
    NULLIF(trim(p_external_url), ''),
    COALESCE(p_sort_order, 0),
    true,
    now()
  )
  RETURNING id INTO v_media_id;

  RETURN jsonb_build_object('success', true, 'media_id', v_media_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_add_marketplace_listing_media(uuid, text, integer, text, text, text, text) TO authenticated;
