-- Studio TV Premium : timeline JSON -> hero_overlays_tv
-- À appliquer via: python .windsurf/apply_one_sql_via_admin_rpc.py sql_changes/change_20251211_tv_timeline_json.sql

-- 1) Colonnes optionnelles sur app.hero_playlist pour suivre la timeline TV

ALTER TABLE app.hero_playlist
    ADD COLUMN IF NOT EXISTS tv_timeline_duration_seconds INTEGER,
    ADD COLUMN IF NOT EXISTS tv_timeline_version INTEGER;


-- 2) RPC ADMIN - Enregistrer une timeline TV complète au format JSON
--    Cette fonction prend un JSON du type :
--    {
--      "timeline": {
--        "duration": 15,
--        "overlays": [ { ... } ]
--      }
--    }
--    et le projette dans app.hero_overlays_tv.

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
    IF v_overlay_type = 'text' THEN
      v_overlay_type := 'text';
    ELSIF v_overlay_type = 'logo' THEN
      v_overlay_type := 'image';
    ELSIF v_overlay_type = 'image' THEN
      v_overlay_type := 'image';
    ELSIF v_overlay_type = 'lower_third' THEN
      v_overlay_type := 'banner';
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
      -- on enlève id/type pour les stocker en colonnes dédiées
      v_overlay - 'id' - 'type',
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


-- 3) RPC ADMIN - Lecture d'une timeline TV complète au format JSON

CREATE OR REPLACE FUNCTION public.app_admin_tv_get_timeline_json(
  p_playlist_item_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_duration INT;
  v_overlays JSONB;
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

  -- durée : d'abord depuis hero_playlist, sinon depuis la timeline TV, sinon valeur par défaut
  SELECT hp.tv_timeline_duration_seconds
    INTO v_duration
    FROM app.hero_playlist hp
   WHERE hp.id = p_playlist_item_id;

  IF v_duration IS NULL THEN
    SELECT CEIL(MAX(ho.end_at_seconds))::INT
      INTO v_duration
      FROM app.hero_overlays_tv ho
     WHERE ho.playlist_item_id = p_playlist_item_id;
  END IF;

  IF v_duration IS NULL THEN
    v_duration := 15;
  END IF;

  SELECT COALESCE(
           jsonb_agg(
             (jsonb_build_object(
                'id', ho.id,
                'type', ho.overlay_type,
                'start_at_seconds', ho.start_at_seconds,
                'end_at_seconds', ho.end_at_seconds,
                'sort_order', ho.sort_order
              ) || ho.config)
             ORDER BY ho.start_at_seconds, ho.sort_order, ho.created_at
           ),
           '[]'::jsonb
         )
    INTO v_overlays
    FROM app.hero_overlays_tv ho
   WHERE ho.playlist_item_id = p_playlist_item_id;

  RETURN jsonb_build_object(
    'success', true,
    'timeline', jsonb_build_object(
      'duration', v_duration,
      'overlays', v_overlays
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_tv_get_timeline_json(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.app_admin_tv_get_timeline_json(uuid) TO service_role;
