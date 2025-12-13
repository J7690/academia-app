--- ========================================
--- ACADEMIA - MODULE PRÉPARATION CONCOURS
--- Admin: création de matière (prep_subjects)
--- Application via .windsurf/apply_one_sql_via_admin_rpc.py (admin_execute_sql)
--- ========================================

CREATE OR REPLACE FUNCTION app_admin_prep_create_subject(
  p_title TEXT,
  p_slug TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_sort_order INTEGER DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_slug TEXT;
  v_id UUID;
BEGIN
  SELECT raw_user_meta_data->>'role'
  INTO v_role
  FROM auth.users
  WHERE id = v_user_id;

  IF v_role <> 'admin' THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_admin');
  END IF;

  IF p_title IS NULL OR LENGTH(BTRIM(p_title)) = 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'title_required');
  END IF;

  v_slug := COALESCE(NULLIF(BTRIM(p_slug), ''), lower(regexp_replace(BTRIM(p_title), '[^a-zA-Z0-9]+', '-', 'g')));
  v_slug := regexp_replace(v_slug, '(^-+|-+$)', '', 'g');

  IF v_slug IS NULL OR LENGTH(BTRIM(v_slug)) = 0 THEN
    RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'slug_required');
  END IF;

  INSERT INTO app.prep_subjects (slug, title, description, sort_order, is_active)
  VALUES (v_slug, BTRIM(p_title), NULLIF(BTRIM(p_description), ''), p_sort_order, COALESCE(p_is_active, TRUE))
  RETURNING id INTO v_id;

  RETURN JSONB_BUILD_OBJECT(
    'success', TRUE,
    'subject', JSONB_BUILD_OBJECT(
      'id', v_id,
      'slug', v_slug,
      'title', BTRIM(p_title),
      'description', NULLIF(BTRIM(p_description), ''),
      'sort_order', p_sort_order,
      'is_active', COALESCE(p_is_active, TRUE)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION app_admin_prep_create_subject(TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION app_admin_prep_create_subject(TEXT, TEXT, TEXT, INTEGER, BOOLEAN) TO service_role;
