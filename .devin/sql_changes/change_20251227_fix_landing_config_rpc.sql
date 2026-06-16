-- Fix legacy landing config RPC to work after dropping app.landing_config.video_url
-- This keeps the old p_video_url parameter for Flutter compatibility but ignores it.

CREATE OR REPLACE FUNCTION public.app_admin_upsert_landing_config(
  p_config_id uuid,
  p_hero_badge_text text,
  p_hero_title text,
  p_hero_subtitle text,
  p_video_url text,
  p_primary_color text,
  p_secondary_color text,
  p_accent_color text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id   uuid := auth.uid();
  v_role      text;
  v_config_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_admin');
  END IF;

  -- p_video_url is accepted for compatibility but IGNORED:
  -- app.landing_config no longer has a video_url column.
  IF p_config_id IS NULL THEN
    INSERT INTO app.landing_config (
      hero_badge_text,
      hero_title,
      hero_subtitle,
      primary_color,
      secondary_color,
      accent_color
    ) VALUES (
      p_hero_badge_text,
      p_hero_title,
      p_hero_subtitle,
      p_primary_color,
      p_secondary_color,
      p_accent_color
    )
    RETURNING id INTO v_config_id;
  ELSE
    UPDATE app.landing_config
    SET
      hero_badge_text = p_hero_badge_text,
      hero_title      = p_hero_title,
      hero_subtitle   = p_hero_subtitle,
      primary_color   = p_primary_color,
      secondary_color = p_secondary_color,
      accent_color    = p_accent_color,
      updated_at      = NOW()
    WHERE id = p_config_id
    RETURNING id INTO v_config_id;
  END IF;

  IF v_config_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'config_not_saved');
  END IF;

  RETURN jsonb_build_object('success', true, 'config_id', v_config_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_admin_upsert_landing_config(
  uuid, text, text, text, text, text, text, text
) TO authenticated, service_role;
