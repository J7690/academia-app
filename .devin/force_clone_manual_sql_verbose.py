#!/usr/bin/env python3
"""Force le clonage en injectant les INSERT manuellement via SupabaseAutoManager, avec retour du nombre de lignes."""

from supabase_auto_manager import SupabaseAutoManager

def clone_university(target_university_id: str):
    m = SupabaseAutoManager()
    template_id = "caa0d821-45e4-4148-86a4-bf16c7fc3bb1"  # Arbilo actif
    # 1. Cloner les blocs si vide
    sql_blocks = f"""
    WITH inserted AS (
        INSERT INTO app.university_site_blocks (university_id, key, title, content, sort_order, is_active)
        SELECT '{target_university_id}'::UUID, b.key, b.title, b.content, b.sort_order, b.is_active
        FROM app.university_site_blocks b
        WHERE b.university_id = '{template_id}'::UUID
          AND NOT EXISTS (SELECT 1 FROM app.university_site_blocks b2 WHERE b2.university_id = '{target_university_id}'::UUID)
        RETURNING *
    )
    SELECT COUNT(*) AS inserted FROM inserted;
    """
    res_blocks = m.execute_sql_auto(sql_blocks)
    print("Clonage blocks (nombre inséré):", res_blocks)
    # 2. Cloner les médias si vide
    sql_media = f"""
    WITH inserted AS (
        INSERT INTO app.university_media (university_id, media_type, title, description, url, storage_path, sort_order, is_active, video_asset_id)
        SELECT '{target_university_id}'::UUID, m.media_type, m.title, m.description, m.url, m.storage_path, m.sort_order, m.is_active, m.video_asset_id
        FROM app.university_media m
        WHERE m.university_id = '{template_id}'::UUID
          AND NOT EXISTS (SELECT 1 FROM app.university_media m2 WHERE m2.university_id = '{target_university_id}'::UUID)
        RETURNING *
    )
    SELECT COUNT(*) AS inserted FROM inserted;
    """
    res_media = m.execute_sql_auto(sql_media)
    print("Clonage media (nombre inséré):", res_media)
    # 3. Cloner les bannières si vide
    sql_banners = f"""
    WITH inserted AS (
        INSERT INTO app.university_site_banners (university_id, position, title, subtitle, media_id, sort_order, is_active)
        SELECT '{target_university_id}'::UUID, ban.position, ban.title, ban.subtitle, ban.media_id, ban.sort_order, ban.is_active
        FROM app.university_site_banners ban
        WHERE ban.university_id = '{template_id}'::UUID
          AND NOT EXISTS (SELECT 1 FROM app.university_site_banners ban2 WHERE ban2.university_id = '{target_university_id}'::UUID)
        RETURNING *
    )
    SELECT COUNT(*) AS inserted FROM inserted;
    """
    res_banners = m.execute_sql_auto(sql_banners)
    print("Clonage banners (nombre inséré):", res_banners)
    # 4. Cloner les événements si vide
    sql_events = f"""
    WITH inserted AS (
        INSERT INTO app.university_events (university_id, title, description, event_type, start_at, end_at, location, is_highlighted, is_active)
        SELECT '{target_university_id}'::UUID, e.title, e.description, e.event_type, e.start_at, e.end_at, e.location, e.is_highlighted, e.is_active
        FROM app.university_events e
        WHERE e.university_id = '{template_id}'::UUID
          AND NOT EXISTS (SELECT 1 FROM app.university_events e2 WHERE e2.university_id = '{target_university_id}'::UUID)
        RETURNING *
    )
    SELECT COUNT(*) AS inserted FROM inserted;
    """
    res_events = m.execute_sql_auto(sql_events)
    print("Clonage events (nombre inséré):", res_events)
    # 5. Cloner les actualités si vide
    sql_news = f"""
    WITH inserted AS (
        INSERT INTO app.university_news (university_id, title, slug, summary, content, published_at, hero_media_id, is_active)
        SELECT '{target_university_id}'::UUID, n.title, n.slug, n.summary, n.content, n.published_at, n.hero_media_id, n.is_active
        FROM app.university_news n
        WHERE n.university_id = '{template_id}'::UUID
          AND NOT EXISTS (SELECT 1 FROM app.university_news n2 WHERE n2.university_id = '{target_university_id}'::UUID)
        RETURNING *
    )
    SELECT COUNT(*) AS inserted FROM inserted;
    """
    res_news = m.execute_sql_auto(sql_news)
    print("Clonage news (nombre inséré):", res_news)
    # 6. Cloner les programmes si vide
    sql_programs = f"""
    WITH inserted AS (
        INSERT INTO app.programs (university_id, title, description, degree_level, mode, duration_months, tuition_fees, structure, career_outcomes, highlighted, is_active)
        SELECT '{target_university_id}'::UUID, p.title, p.description, p.degree_level, p.mode, p.duration_months, p.tuition_fees, p.structure, p.career_outcomes, p.highlighted, p.is_active
        FROM app.programs p
        WHERE p.university_id = '{template_id}'::UUID
          AND NOT EXISTS (SELECT 1 FROM app.programs p2 WHERE p2.university_id = '{target_university_id}'::UUID)
        RETURNING *
    )
    SELECT COUNT(*) AS inserted FROM inserted;
    """
    res_programs = m.execute_sql_auto(sql_programs)
    print("Clonage programs (nombre inséré):", res_programs)
    # 7. Cloner les cours (liés aux programmes)
    sql_courses = f"""
    WITH inserted AS (
        INSERT INTO app.courses (program_id, title, description, credits, prerequisites, instructor, is_active)
        SELECT p_new.id, c.title, c.description, c.credits, c.prerequisites, c.instructor, c.is_active
        FROM app.courses c
        JOIN app.programs p_old ON p_old.id = c.program_id
        JOIN app.programs p_new ON p_new.title = p_old.title AND p_new.university_id = '{target_university_id}'::UUID
        WHERE p_old.university_id = '{template_id}'::UUID
          AND NOT EXISTS (
            SELECT 1 FROM app.courses c2
            JOIN app.programs p_check ON p_check.id = c2.program_id
            WHERE p_check.university_id = '{target_university_id}'::UUID
          )
        RETURNING *
    )
    SELECT COUNT(*) AS inserted FROM inserted;
    """
    res_courses = m.execute_sql_auto(sql_courses)
    print("Clonage courses (nombre inséré):", res_courses)

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python .windsurf/force_clone_manual_sql_verbose.py <UNIVERSITY_ID>")
        sys.exit(1)
    clone_university(sys.argv[1])
