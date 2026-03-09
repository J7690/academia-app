import pathlib
import sys
import requests

# Utilise la config validée dans auto_supabase_import
winds = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(winds))
import auto_supabase_import as a  # type: ignore

URL = f"{a.SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
HEADERS = a.RPC_HEADERS

SQL_CREATE_FUNCTION = """
CREATE OR REPLACE FUNCTION public.app_public_university_site(
    p_slug TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_university_id UUID;
    v_university JSONB;
    v_config JSONB;
    v_blocks JSONB;
    v_media JSONB;
    v_programs JSONB;
    v_courses JSONB;
    v_banners JSONB;
    v_events JSONB;
    v_news JSONB;
    v_staff JSONB;
BEGIN
    SELECT u.id
    INTO v_university_id
    FROM app.universities u
    WHERE u.slug = p_slug
      AND u.is_active = TRUE
    LIMIT 1;

    IF v_university_id IS NULL THEN
        RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'university_not_found');
    END IF;

    SELECT JSONB_BUILD_OBJECT(
        'id', u.id,
        'name', u.name,
        'slug', u.slug,
        'logo_url', u.logo_url,
        'country', u.country,
        'city', u.city,
        'website_url', u.website_url,
        'description', u.description,
        'tagline', u.tagline,
        'banner_image_url', u.banner_image_url,
        'contact_email', u.contact_email,
        'contact_phone', u.contact_phone,
        'address', u.address,
        'social_links', u.social_links,
        'mission', u.mission,
        'vision', u.vision,
        'key_figures', u.key_figures
    )
    INTO v_university
    FROM app.universities u
    WHERE u.id = v_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(b) ORDER BY b.sort_order, b.created_at),
        '[]'::JSONB
    )
    INTO v_blocks
    FROM app.university_site_blocks b
    WHERE b.university_id = v_university_id
      AND b.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(m) ORDER BY m.sort_order, m.created_at),
        '[]'::JSONB
    )
    INTO v_media
    FROM app.university_media m
    WHERE m.university_id = v_university_id
      AND m.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', p.id,
                'title', p.title,
                'description', p.description,
                'degree_level', p.degree_level,
                'mode', p.mode,
                'duration_months', p.duration_months,
                'tuition_fees', p.tuition_fees,
                'highlighted', p.highlighted,
                'is_active', p.is_active,
                'created_at', p.created_at,
                'updated_at', p.updated_at
            ) ORDER BY p.highlighted DESC, p.created_at DESC
        ),
        '[]'::JSONB
    )
    INTO v_programs
    FROM app.programs p
    WHERE p.university_id = v_university_id
      AND p.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id', c.id,
                'program_id', c.program_id,
                'title', c.title,
                'description', c.description,
                'credits', c.credits,
                'prerequisites', c.prerequisites,
                'instructor', c.instructor,
                'is_active', c.is_active,
                'created_at', c.created_at,
                'updated_at', c.updated_at
            ) ORDER BY c.created_at DESC
        ),
        '[]'::JSONB
    )
    INTO v_courses
    FROM app.courses c
    JOIN app.programs p2 ON p2.id = c.program_id
    WHERE p2.university_id = v_university_id
      AND c.is_active = TRUE;

    SELECT COALESCE(TO_JSONB(c), '{}'::JSONB)
    INTO v_config
    FROM app.university_site_config c
    WHERE c.university_id = v_university_id;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(ban) ORDER BY ban.sort_order, ban.created_at),
        '[]'::JSONB
    )
    INTO v_banners
    FROM app.university_site_banners ban
    WHERE ban.university_id = v_university_id
      AND ban.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(e) ORDER BY e.start_at NULLS LAST, e.created_at DESC),
        '[]'::JSONB
    )
    INTO v_events
    FROM app.university_events e
    WHERE e.university_id = v_university_id
      AND e.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(n) ORDER BY n.published_at DESC NULLS LAST, n.created_at DESC),
        '[]'::JSONB
    )
    INTO v_news
    FROM app.university_news n
    WHERE n.university_id = v_university_id
      AND n.is_active = TRUE;

    SELECT COALESCE(
        JSONB_AGG(TO_JSONB(s) ORDER BY s.sort_order, s.created_at),
        '[]'::JSONB
    )
    INTO v_staff
    FROM app.university_staff s
    WHERE s.university_id = v_university_id
      AND s.is_active = TRUE;

    RETURN JSONB_BUILD_OBJECT(
        'success', TRUE,
        'university', v_university,
        'config', v_config,
        'blocks', v_blocks,
        'media', v_media,
        'programs', v_programs,
        'courses', v_courses,
        'banners', v_banners,
        'events', v_events,
        'news', v_news,
        'staff', v_staff
    );
END;
$$;
"""

SQL_GRANT = """
GRANT EXECUTE ON FUNCTION public.app_public_university_site(TEXT) TO anon, authenticated, service_role;
"""


def call_sql(sql: str) -> None:
    sql = sql.strip()
    print("\n=== admin_execute_sql ===")
    print(sql)
    r = requests.post(URL, headers=HEADERS, json={"p_sql": sql}, timeout=60)
    print("status", r.status_code)
    try:
        print("json:", r.json())
    except Exception:
        print("text:", r.text)


def main() -> None:
    # 1) Remplacer la fonction stub par la vraie implémentation
    call_sql(SQL_CREATE_FUNCTION)
    # 2) S'assurer que les droits d'exécution sont corrects
    call_sql(SQL_GRANT)
    # 3) Vérifier le résultat pour universite-arbilo
    call_sql("select public.app_public_university_site('universite-arbilo') as site")


if __name__ == "__main__":
    main()
