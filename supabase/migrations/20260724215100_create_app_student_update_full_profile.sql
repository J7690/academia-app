-- Migration Phase 3 : nouvelle RPC non surchargee pour la mise a jour du profil etudiant
-- Objectif : eliminer l'ambiguite PostgREST (PGRST203) causee par les 3 versions de public.app_update_student_profile
-- Regles : aucune suppression, aucune modification des anciennes fonctions, aucune modification de table.

CREATE OR REPLACE FUNCTION public.app_student_update_full_profile(
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
SET search_path TO 'public', 'app', 'auth'
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'not_authenticated');
    END IF;

    UPDATE app.students s
    SET
        full_name = COALESCE(p_full_name, s.full_name),
        phone = COALESCE(p_phone, s.phone),
        country = COALESCE(p_country, s.country),
        city = COALESCE(p_city, s.city),
        date_of_birth = COALESCE(p_date_of_birth, s.date_of_birth),
        avatar_url = COALESCE(p_avatar_url, s.avatar_url),
        bepc_year = COALESCE(p_bepc_year, s.bepc_year),
        bepc_institution = COALESCE(p_bepc_institution, s.bepc_institution),
        bepc_country = COALESCE(p_bepc_country, s.bepc_country),
        bepc_mention = COALESCE(p_bepc_mention, s.bepc_mention),
        bac_year = COALESCE(p_bac_year, s.bac_year),
        bac_series = COALESCE(p_bac_series, s.bac_series),
        bac_mention = COALESCE(p_bac_mention, s.bac_mention),
        bac_institution = COALESCE(p_bac_institution, s.bac_institution),
        bac_country = COALESCE(p_bac_country, s.bac_country),
        study_project_text = COALESCE(p_study_project_text, s.study_project_text),
        timezone = COALESCE(p_timezone, s.timezone),
        geo_latitude = COALESCE(p_geo_latitude, s.geo_latitude),
        geo_longitude = COALESCE(p_geo_longitude, s.geo_longitude),
        bio = COALESCE(p_bio, s.bio),
        website_url = COALESCE(p_website_url, s.website_url),
        updated_at = NOW()
    WHERE s.id = v_user_id;

    SELECT TO_JSONB(s)
    INTO v_profile
    FROM app.students s
    WHERE s.id = v_user_id;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'student_id', v_user_id,
        'profile', v_profile
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_student_update_full_profile(
  text, text, text, text, date, text, integer, text, text, text,
  integer, text, text, text, text, text, text, numeric, numeric, text, text
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.app_student_update_full_profile(
  text, text, text, text, date, text, integer, text, text, text,
  integer, text, text, text, text, text, text, numeric, numeric, text, text
) TO service_role;

COMMENT ON FUNCTION public.app_student_update_full_profile IS 'RPC unique de mise a jour complete du profil etudiant (Phase 3). Non surchargee, cible app.students, identifie via auth.uid().';
