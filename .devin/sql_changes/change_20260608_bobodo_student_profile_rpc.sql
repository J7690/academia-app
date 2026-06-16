-- ========================================
-- BOBODO – RPC Profil Étudiant pour Injection Prompt
-- ========================================

-- RPC pour récupérer le profil complet d'un étudiant pour Bobodo
CREATE OR REPLACE FUNCTION app_get_bobodo_student_profile(
    p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile JSONB;
    v_first_name TEXT;
    v_full_name TEXT;
BEGIN
    -- Récupérer le nom complet
    SELECT st.full_name INTO v_full_name
    FROM app.bobodo_sessions bs
    JOIN app.students st ON st.id = bs.student_id
    WHERE bs.id = p_session_id;
    
    -- Extraire le prénom (premier mot)
    v_first_name := NULLIF(TRIM(split_part(COALESCE(v_full_name, ''), ' ', 1)), '');
    
    -- Construire le profil JSON
    SELECT JSONB_BUILD_OBJECT(
        'first_name', v_first_name,
        'full_name', v_full_name,
        'bac_series', st.bac_series,
        'bac_year', st.bac_year,
        'bac_mention', st.bac_mention,
        'bac_institution', st.bac_institution,
        'bac_country', st.bac_country,
        'bepc_year', st.bepc_year,
        'bepc_mention', st.bepc_mention,
        'bepc_institution', st.bepc_institution,
        'bepc_country', st.bepc_country,
        'study_project', st.study_project_text,
        'country', st.country,
        'city', st.city,
        'bio', st.bio,
        'applications', (
            SELECT COALESCE(
                JSONB_AGG(
                    JSONB_BUILD_OBJECT(
                        'program_id', a.program_id,
                        'status', a.status,
                        'created_at', a.created_at
                    )
                ),
                '[]'::JSONB
            )
            FROM app.applications a
            WHERE a.student_id = st.id
            ORDER BY a.created_at DESC
            LIMIT 5
        )
    ) INTO v_profile
    FROM app.bobodo_sessions bs
    JOIN app.students st ON st.id = bs.student_id
    WHERE bs.id = p_session_id;
    
    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION app_get_bobodo_student_profile(UUID) TO service_role;
