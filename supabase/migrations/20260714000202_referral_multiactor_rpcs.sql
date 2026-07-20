-- ============================================================
-- RPC : config de partage multi-acteurs + bibliothèque de contenus
-- Appliqué en prod le 2026-07-14 (version 20260714000202).
-- ============================================================

-- 1. Upsert config : owner + promoteur + créateur + plateforme = 100
CREATE OR REPLACE FUNCTION public.app_admin_upsert_commission_share_config(
    p_scenario_name text,
    p_owner_percentage numeric,
    p_promoter_percentage numeric,
    p_platform_percentage numeric DEFAULT 0,
    p_creator_percentage numeric DEFAULT 0,
    p_promoter_window_days integer DEFAULT 30,
    p_description text DEFAULT NULL,
    p_is_active boolean DEFAULT true,
    p_effective_from timestamptz DEFAULT now(),
    p_effective_until timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, app
AS $function$
DECLARE
    v_role TEXT;
    v_config_id UUID;
BEGIN
    SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = auth.uid();
    IF v_role IS NULL OR v_role NOT IN ('admin','super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authorized');
    END IF;

    IF (COALESCE(p_owner_percentage,0) + COALESCE(p_promoter_percentage,0)
        + COALESCE(p_creator_percentage,0) + COALESCE(p_platform_percentage,0)) <> 100 THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'percentages_must_sum_to_100');
    END IF;

    INSERT INTO app.commission_share_config (
        scenario_name, owner_percentage, promoter_percentage, platform_percentage,
        creator_percentage, promoter_window_days, description, is_active,
        effective_from, effective_until, created_by
    ) VALUES (
        p_scenario_name, p_owner_percentage, p_promoter_percentage, p_platform_percentage,
        p_creator_percentage, p_promoter_window_days, p_description, p_is_active,
        p_effective_from, p_effective_until, auth.uid()
    )
    ON CONFLICT (scenario_name) DO UPDATE SET
        owner_percentage     = EXCLUDED.owner_percentage,
        promoter_percentage  = EXCLUDED.promoter_percentage,
        platform_percentage  = EXCLUDED.platform_percentage,
        creator_percentage   = EXCLUDED.creator_percentage,
        promoter_window_days = EXCLUDED.promoter_window_days,
        description          = EXCLUDED.description,
        is_active            = EXCLUDED.is_active,
        effective_from       = EXCLUDED.effective_from,
        effective_until      = EXCLUDED.effective_until,
        updated_at           = NOW()
    RETURNING id INTO v_config_id;

    IF p_is_active THEN
        UPDATE app.commission_share_config SET is_active = FALSE
        WHERE id <> v_config_id AND is_active = TRUE;
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'config_id', v_config_id);
END;
$function$;

-- 2. Liste config : inclure créateur + fenêtre
CREATE OR REPLACE FUNCTION public.app_admin_list_commission_share_configs()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, app
AS $function$
DECLARE
    v_role TEXT;
    v_configs JSONB;
BEGIN
    SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = auth.uid();
    IF v_role IS NULL OR v_role NOT IN ('admin','super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authorized');
    END IF;

    SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB), '[]'::JSONB) INTO v_configs
    FROM (
        SELECT id, scenario_name, owner_percentage, promoter_percentage,
               platform_percentage, creator_percentage, promoter_window_days,
               description, is_active, effective_from, effective_until,
               created_by, created_at, updated_at
        FROM app.commission_share_config
        ORDER BY created_at DESC
    ) t;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'configs', v_configs);
END;
$function$;

-- 3. register_share : rattacher un visuel + résoudre son créateur
CREATE OR REPLACE FUNCTION public.app_register_share(
    p_student_id uuid,
    p_promoter_commercial_id uuid,
    p_share_source text,
    p_shared_item_type text,
    p_shared_item_id uuid DEFAULT NULL,
    p_shared_item_title text DEFAULT NULL,
    p_ref_code text DEFAULT NULL,
    p_utm_source text DEFAULT NULL,
    p_utm_medium text DEFAULT NULL,
    p_utm_campaign text DEFAULT NULL,
    p_content_asset_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, app
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_owner_id UUID;
    v_creator_id UUID;
    v_share_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    SELECT commercial_user_id INTO v_owner_id
    FROM app.user_referrals WHERE student_id = p_student_id LIMIT 1;

    IF p_content_asset_id IS NOT NULL THEN
        SELECT creator_user_id INTO v_creator_id
        FROM app.content_assets WHERE id = p_content_asset_id LIMIT 1;
    END IF;

    INSERT INTO app.share_tracking (
        student_id, owner_commercial_id, promoter_commercial_id,
        share_source, shared_item_type, shared_item_id, shared_item_title,
        ref_code, utm_source, utm_medium, utm_campaign,
        content_asset_id, creator_commercial_id
    ) VALUES (
        p_student_id, v_owner_id, p_promoter_commercial_id,
        p_share_source, p_shared_item_type, p_shared_item_id, p_shared_item_title,
        p_ref_code, p_utm_source, p_utm_medium, p_utm_campaign,
        p_content_asset_id, v_creator_id
    )
    RETURNING id INTO v_share_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'share_id', v_share_id,
                              'owner_commercial_id', v_owner_id,
                              'creator_commercial_id', v_creator_id);
END;
$function$;

-- 4. Créateur : créer / mettre à jour un visuel
CREATE OR REPLACE FUNCTION public.app_creator_upsert_content_asset(
    p_title text,
    p_asset_type text DEFAULT 'video',
    p_storage_path text DEFAULT NULL,
    p_external_url text DEFAULT NULL,
    p_thumbnail_url text DEFAULT NULL,
    p_description text DEFAULT NULL,
    p_asset_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, app
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;
    SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;
    IF v_role IS NULL OR v_role NOT IN ('content_creator','admin','super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_content_creator');
    END IF;

    IF p_asset_id IS NULL THEN
        INSERT INTO app.content_assets (creator_user_id, title, asset_type, storage_path, external_url, thumbnail_url, description)
        VALUES (v_user_id, p_title, p_asset_type, p_storage_path, p_external_url, p_thumbnail_url, p_description)
        RETURNING id INTO v_id;
    ELSE
        UPDATE app.content_assets
        SET title = COALESCE(p_title, title),
            asset_type = COALESCE(p_asset_type, asset_type),
            storage_path = COALESCE(p_storage_path, storage_path),
            external_url = COALESCE(p_external_url, external_url),
            thumbnail_url = COALESCE(p_thumbnail_url, thumbnail_url),
            description = COALESCE(p_description, description),
            updated_at = NOW()
        WHERE id = p_asset_id AND (creator_user_id = v_user_id OR v_role IN ('admin','super_admin'))
        RETURNING id INTO v_id;
        IF v_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'asset_not_found_or_forbidden');
        END IF;
    END IF;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'asset_id', v_id);
END;
$function$;

-- 5. Lister les visuels disponibles
CREATE OR REPLACE FUNCTION public.app_list_content_assets()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, app
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_assets JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;
    SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = v_user_id;

    SELECT COALESCE(JSONB_AGG(row_to_json(t)::JSONB ORDER BY (t).created_at DESC), '[]'::JSONB) INTO v_assets
    FROM (
        SELECT id, creator_user_id, title, asset_type, storage_path, external_url,
               thumbnail_url, description, is_active, approved_at, created_at
        FROM app.content_assets ca
        WHERE
            CASE
              WHEN v_role IN ('admin','super_admin') THEN TRUE
              WHEN v_role = 'content_creator' THEN ca.creator_user_id = v_user_id
              ELSE ca.is_active = TRUE AND ca.approved_at IS NOT NULL
            END
    ) t;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'assets', v_assets);
END;
$function$;

-- 6. Admin : approuver un visuel
CREATE OR REPLACE FUNCTION public.app_admin_approve_content_asset(p_asset_id uuid, p_approve boolean DEFAULT true)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, app
AS $function$
DECLARE
    v_role TEXT;
BEGIN
    SELECT raw_user_meta_data->>'role' INTO v_role FROM auth.users WHERE id = auth.uid();
    IF v_role IS NULL OR v_role NOT IN ('admin','super_admin') THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authorized');
    END IF;

    UPDATE app.content_assets
    SET approved_at = CASE WHEN p_approve THEN NOW() ELSE NULL END,
        approved_by = CASE WHEN p_approve THEN auth.uid() ELSE NULL END,
        is_active = COALESCE(p_approve, is_active),
        updated_at = NOW()
    WHERE id = p_asset_id;

    IF NOT FOUND THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'asset_not_found');
    END IF;
    RETURN JSONB_BUILD_OBJECT('success', TRUE);
END;
$function$;
