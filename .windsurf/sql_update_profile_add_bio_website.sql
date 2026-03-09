CREATE OR REPLACE FUNCTION public.app_update_student_profile(
  p_full_name text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_country text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_date_of_birth date DEFAULT NULL,
  p_avatar_url text DEFAULT NULL,
  p_bepc_year integer DEFAULT NULL,
  p_bepc_institution text DEFAULT NULL,
  p_bepc_country text DEFAULT NULL,
  p_bepc_mention text DEFAULT NULL,
  p_bac_year integer DEFAULT NULL,
  p_bac_series text DEFAULT NULL,
  p_bac_mention text DEFAULT NULL,
  p_bac_institution text DEFAULT NULL,
  p_bac_country text DEFAULT NULL,
  p_study_project_text text DEFAULT NULL,
  p_timezone text DEFAULT NULL,
  p_geo_latitude numeric DEFAULT NULL,
  p_geo_longitude numeric DEFAULT NULL,
  p_bio text DEFAULT NULL,
  p_website_url text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    UPDATE app.students
    SET
        full_name = COALESCE(p_full_name, full_name),
        phone = COALESCE(p_phone, phone),
        country = COALESCE(p_country, country),
        city = COALESCE(p_city, city),
        date_of_birth = COALESCE(p_date_of_birth, date_of_birth),
        avatar_url = COALESCE(p_avatar_url, avatar_url),
        bepc_year = COALESCE(p_bepc_year, bepc_year),
        bepc_institution = COALESCE(p_bepc_institution, bepc_institution),
        bepc_country = COALESCE(p_bepc_country, bepc_country),
        bepc_mention = COALESCE(p_bepc_mention, bepc_mention),
        bac_year = COALESCE(p_bac_year, bac_year),
        bac_series = COALESCE(p_bac_series, bac_series),
        bac_mention = COALESCE(p_bac_mention, bac_mention),
        bac_institution = COALESCE(p_bac_institution, bac_institution),
        bac_country = COALESCE(p_bac_country, bac_country),
        study_project_text = COALESCE(p_study_project_text, study_project_text),
        timezone = COALESCE(p_timezone, timezone),
        geo_latitude = COALESCE(p_geo_latitude, geo_latitude),
        geo_longitude = COALESCE(p_geo_longitude, geo_longitude),
        bio = COALESCE(p_bio, bio),
        website_url = COALESCE(p_website_url, website_url),
        updated_at = NOW()
    WHERE id = v_user_id;

    SELECT TO_JSONB(s)
    INTO v_profile
    FROM app.students s
    WHERE s.id = v_user_id;

    RETURN JSONB_BUILD_OBJECT('success', TRUE, 'profile', v_profile);
END;
$$;
