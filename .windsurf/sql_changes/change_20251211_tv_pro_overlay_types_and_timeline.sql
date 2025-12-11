-- TV PRO : extension des types d'overlays et mise à jour de app_admin_tv_upsert_timeline_json
-- À appliquer via :
--   python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251211_tv_pro_overlay_types_and_timeline.sql

-- 1) Étendre les types autorisés pour overlay_type (ajout de background, pip, video)

ALTER TABLE app.hero_overlays_tv
    DROP CONSTRAINT IF EXISTS hero_overlays_tv_overlay_type_check;

ALTER TABLE app.hero_overlays_tv
    ADD CONSTRAINT hero_overlays_tv_overlay_type_check
    CHECK (overlay_type IN (
        'text',
        'image',
        'banner',
        'ticker',
        'shape',
        'background',
        'pip',
        'video'
    ));


-- 2) Mise à jour de app_admin_tv_upsert_timeline_json pour conserver les types PRO

CREATE OR REPLACE FUNCTION public.app_admin_tv_upsert_timeline_json(
  p_playlist_item_id uuid,
  p_timeline jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_duration INT;
  v_overlay JSONB;
  v_overlay_type TEXT;
BEGIN
  IF p_playlist_item_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'PLAYLIST_ITEM_ID_REQUIRED');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM app.hero_playlist hp
    WHERE hp.id = p_playlist_item_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'PLAYLIST_ITEM_NOT_FOUND');
  END IF;

  IF p_timeline IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'TIMELINE_REQUIRED');
  END IF;

  -- durée globale de la timeline (en secondes)
  v_duration := NULL;
  BEGIN
    v_duration := (p_timeline->'timeline'->>'duration')::INT;
  EXCEPTION WHEN others THEN
    v_duration := NULL;
  END;

  UPDATE app.hero_playlist
     SET tv_timeline_duration_seconds = v_duration,
         tv_timeline_version = COALESCE(tv_timeline_version, 0) + 1,
         updated_at = NOW()
   WHERE id = p_playlist_item_id;

  -- on remplace entièrement les overlays TV existants pour cet item
  DELETE FROM app.hero_overlays_tv
   WHERE playlist_item_id = p_playlist_item_id;

  -- recréation des overlays à partir du JSON
  FOR v_overlay IN
    SELECT jsonb_array_elements(COALESCE(p_timeline->'timeline'->'overlays', '[]'::jsonb))
  LOOP
    v_overlay_type := lower(COALESCE(v_overlay->>'type', 'text'));

    -- Mapping des types JSON vers overlay_type pour TV PRO
    IF v_overlay_type = 'text' THEN
      v_overlay_type := 'text';
    ELSIF v_overlay_type = 'logo' THEN
      v_overlay_type := 'image';
    ELSIF v_overlay_type = 'image' THEN
      v_overlay_type := 'image';
    ELSIF v_overlay_type = 'lower_third' THEN
      v_overlay_type := 'banner';
    ELSIF v_overlay_type = 'background' THEN
      v_overlay_type := 'background';
    ELSIF v_overlay_type = 'pip' THEN
      v_overlay_type := 'pip';
    ELSIF v_overlay_type = 'video' THEN
      v_overlay_type := 'video';
    ELSE
      v_overlay_type := 'shape';
    END IF;

    INSERT INTO app.hero_overlays_tv (
      playlist_item_id,
      overlay_type,
      config,
      start_at_seconds,
      end_at_seconds,
      sort_order
    )
    VALUES (
      p_playlist_item_id,
      v_overlay_type,
      -- Pour les types PRO (background, pip, video), on conserve le champ "type" dans config
      CASE
        WHEN v_overlay_type IN ('background', 'pip', 'video') THEN
          v_overlay - 'id'
        ELSE
          v_overlay - 'id' - 'type'
      END,
      COALESCE((v_overlay->>'start_at_seconds')::NUMERIC, 0),
      COALESCE((v_overlay->>'end_at_seconds')::NUMERIC, COALESCE(v_duration, 0)),
      COALESCE((v_overlay->>'sort_order')::INT, 0)
    );
  END LOOP;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_tv_upsert_timeline_json(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_tv_upsert_timeline_json(uuid, jsonb) TO service_role;
