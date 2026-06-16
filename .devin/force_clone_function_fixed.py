#!/usr/bin/env python3
"""Crée la fonction de clonage corrigée (sans thumbnail_url)."""

from supabase_auto_manager import SupabaseAutoManager

def main():
    m = SupabaseAutoManager()
    sql = """
    DROP FUNCTION IF EXISTS public.app_admin_clone_university_from_template(TEXT, UUID);
    """
    print("DROP (si existe)...")
    r1 = m.execute_sql_auto(sql)
    print(r1)
    sql2 = """
    CREATE FUNCTION public.app_admin_clone_university_from_template(
        p_template_slug TEXT,
        p_target_university_id UUID
    )
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        v_template_university_id UUID;
        v_blocks_cloned   INTEGER := 0;
        v_media_cloned    INTEGER := 0;
        v_banners_cloned  INTEGER := 0;
        v_events_cloned   INTEGER := 0;
        v_news_cloned     INTEGER := 0;
        v_staff_cloned    INTEGER := 0;
        v_programs_cloned INTEGER := 0;
        v_courses_cloned  INTEGER := 0;
        v_last_count INTEGER := 0;
        rec_program app.programs%ROWTYPE;
        v_new_program_id UUID;
    BEGIN
        SELECT u.id INTO v_template_university_id
        FROM app.universities u
        WHERE u.slug = p_template_slug AND u.is_active = TRUE LIMIT 1;
        IF v_template_university_id IS NULL THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'template_university_not_found', 'template_slug', p_template_slug);
        END IF;
        PERFORM 1 FROM app.universities u WHERE u.id = p_target_university_id;
        IF NOT FOUND THEN
            RETURN JSONB_BUILD_OBJECT('success', FALSE, 'error', 'target_university_not_found', 'target_university_id', p_target_university_id);
        END IF;
        INSERT INTO app.university_site_config (university_id, hero_title, hero_subtitle, hero_primary_color, hero_secondary_color, hero_poster_media_id)
        SELECT p_target_university_id, c.hero_title, c.hero_subtitle, c.hero_primary_color, c.hero_secondary_color, c.hero_poster_media_id
        FROM app.university_site_config c
        WHERE c.university_id = v_template_university_id
          AND NOT EXISTS (SELECT 1 FROM app.university_site_config c2 WHERE c2.university_id = p_target_university_id);
        IF NOT EXISTS (SELECT 1 FROM app.university_site_blocks b WHERE b.university_id = p_target_university_id) THEN
            INSERT INTO app.university_site_blocks (university_id, key, title, content, sort_order, is_active)
            SELECT p_target_university_id, b.key, b.title, b.content, b.sort_order, b.is_active
            FROM app.university_site_blocks b WHERE b.university_id = v_template_university_id;
            GET DIAGNOSTICS v_blocks_cloned = ROW_COUNT;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM app.university_media m WHERE m.university_id = p_target_university_id) THEN
            INSERT INTO app.university_media (university_id, media_type, title, description, url, storage_path, sort_order, is_active, video_asset_id)
            SELECT p_target_university_id, m.media_type, m.title, m.description, m.url, m.storage_path, m.sort_order, m.is_active, m.video_asset_id
            FROM app.university_media m WHERE m.university_id = v_template_university_id;
            GET DIAGNOSTICS v_media_cloned = ROW_COUNT;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM app.university_site_banners ban WHERE ban.university_id = p_target_university_id) THEN
            INSERT INTO app.university_site_banners (university_id, position, title, subtitle, media_id, sort_order, is_active)
            SELECT p_target_university_id, ban.position, ban.title, ban.subtitle, ban.media_id, ban.sort_order, ban.is_active
            FROM app.university_site_banners ban WHERE ban.university_id = v_template_university_id;
            GET DIAGNOSTICS v_banners_cloned = ROW_COUNT;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM app.university_events e WHERE e.university_id = p_target_university_id) THEN
            INSERT INTO app.university_events (university_id, title, description, event_type, start_at, end_at, location, is_highlighted, is_active)
            SELECT p_target_university_id, e.title, e.description, e.event_type, e.start_at, e.end_at, e.location, e.is_highlighted, e.is_active
            FROM app.university_events e WHERE e.university_id = v_template_university_id;
            GET DIAGNOSTICS v_events_cloned = ROW_COUNT;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM app.university_news n WHERE n.university_id = p_target_university_id) THEN
            INSERT INTO app.university_news (university_id, title, slug, summary, content, published_at, hero_media_id, is_active)
            SELECT p_target_university_id, n.title, n.slug, n.summary, n.content, n.published_at, n.hero_media_id, n.is_active
            FROM app.university_news n WHERE n.university_id = v_template_university_id;
            GET DIAGNOSTICS v_news_cloned = ROW_COUNT;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM app.university_staff s WHERE s.university_id = p_target_university_id) THEN
            INSERT INTO app.university_staff (university_id, full_name, role, bio, photo_media_id, email, phone, sort_order, is_active)
            SELECT p_target_university_id, s.full_name, s.role, s.bio, s.photo_media_id, s.email, s.phone, s.sort_order, s.is_active
            FROM app.university_staff s WHERE s.university_id = v_template_university_id;
            GET DIAGNOSTICS v_staff_cloned = ROW_COUNT;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM app.programs p WHERE p.university_id = p_target_university_id) THEN
            FOR rec_program IN SELECT * FROM app.programs p WHERE p.university_id = v_template_university_id LOOP
                INSERT INTO app.programs (university_id, title, description, degree_level, mode, duration_months, tuition_fees, structure, career_outcomes, highlighted, is_active)
                VALUES (p_target_university_id, rec_program.title, rec_program.description, rec_program.degree_level, rec_program.mode, rec_program.duration_months, rec_program.tuition_fees, rec_program.structure, rec_program.career_outcomes, rec_program.highlighted, rec_program.is_active)
                RETURNING id INTO v_new_program_id;
                v_programs_cloned := v_programs_cloned + 1;
                INSERT INTO app.courses (program_id, title, description, credits, prerequisites, instructor, is_active)
                SELECT v_new_program_id, c.title, c.description, c.credits, c.prerequisites, c.instructor, c.is_active
                FROM app.courses c WHERE c.program_id = rec_program.id;
                GET DIAGNOSTICS v_last_count = ROW_COUNT;
                v_courses_cloned := v_courses_cloned + v_last_count;
            END LOOP;
        END IF;
        RETURN JSONB_BUILD_OBJECT(
            'success', TRUE,
            'template_university_id', v_template_university_id,
            'target_university_id', p_target_university_id,
            'cloned', JSONB_BUILD_OBJECT('blocks', v_blocks_cloned, 'media', v_media_cloned, 'banners', v_banners_cloned, 'events', v_events_cloned, 'news', v_news_cloned, 'staff', v_staff_cloned, 'programs', v_programs_cloned, 'courses', v_courses_cloned)
        );
    END;
    $$;
    """
    print("CREATE FUNCTION corrigée...")
    r2 = m.execute_sql_auto(sql2)
    print(r2)
    sql3 = """
    GRANT EXECUTE ON FUNCTION public.app_admin_clone_university_from_template(TEXT, UUID) TO service_role;
    """
    print("GRANT EXECUTE...")
    r3 = m.execute_sql_auto(sql3)
    print(r3)

if __name__ == "__main__":
    main()
