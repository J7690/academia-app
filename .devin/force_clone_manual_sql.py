#!/usr/bin/env python3
"""Force le clonage en injectant les INSERT manuellement via SupabaseAutoManager."""

from supabase_auto_manager import SupabaseAutoManager

def clone_university(target_university_id: str):
    m = SupabaseAutoManager()
    # 1. Récupérer l'ID du template Arbilo
    sql_template = f"""
    SELECT id FROM app.universities WHERE slug = 'universite-arbilo' AND is_active = TRUE LIMIT 1;
    """
    res_template = m.execute_sql_auto(sql_template)
    print("Template Arbilo ID:", res_template)
    if not res_template.get("data"):
        print("Template Arbilo non trouvé.")
        return
    template_id = res_template["data"][0]["id"]
    # 2. Cloner les blocs si vide
    sql_blocks = f"""
    INSERT INTO app.university_site_blocks (university_id, key, title, content, sort_order, is_active)
    SELECT '{target_university_id}'::UUID, b.key, b.title, b.content, b.sort_order, b.is_active
    FROM app.university_site_blocks b
    WHERE b.university_id = '{template_id}'::UUID
      AND NOT EXISTS (SELECT 1 FROM app.university_site_blocks b2 WHERE b2.university_id = '{target_university_id}'::UUID);
    """
    res_blocks = m.execute_sql_auto(sql_blocks)
    print("Clonage blocks:", res_blocks)
    # 3. Cloner les médias si vide
    sql_media = f"""
    INSERT INTO app.university_media (university_id, media_type, title, description, url, storage_path, sort_order, is_active, video_asset_id)
    SELECT '{target_university_id}'::UUID, m.media_type, m.title, m.description, m.url, m.storage_path, m.sort_order, m.is_active, m.video_asset_id
    FROM app.university_media m
    WHERE m.university_id = '{template_id}'::UUID
      AND NOT EXISTS (SELECT 1 FROM app.university_media m2 WHERE m2.university_id = '{target_university_id}'::UUID);
    """
    res_media = m.execute_sql_auto(sql_media)
    print("Clonage media:", res_media)
    # 4. Cloner les programmes si vide
    sql_programs = f"""
    INSERT INTO app.programs (university_id, title, description, degree_level, mode, duration_months, tuition_fees, structure, career_outcomes, highlighted, is_active)
    SELECT '{target_university_id}'::UUID, p.title, p.description, p.degree_level, p.mode, p.duration_months, p.tuition_fees, p.structure, p.career_outcomes, p.highlighted, p.is_active
    FROM app.programs p
    WHERE p.university_id = '{template_id}'::UUID
      AND NOT EXISTS (SELECT 1 FROM app.programs p2 WHERE p2.university_id = '{target_university_id}'::UUID);
    """
    res_programs = m.execute_sql_auto(sql_programs)
    print("Clonage programs:", res_programs)
    # 5. Cloner les cours (liés aux programmes)
    sql_courses = f"""
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
      );
    """
    res_courses = m.execute_sql_auto(sql_courses)
    print("Clonage courses:", res_courses)

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python .windsurf/force_clone_manual_sql.py <UNIVERSITY_ID>")
        sys.exit(1)
    clone_university(sys.argv[1])
