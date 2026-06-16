#!/usr/bin/env python3
"""Crée une structure vide mais complète pour une nouvelle université via RPC execute_sql."""

import sys
from supabase_auto_manager import SupabaseAutoManager

def create_empty_structure(university_id: str):
    m = SupabaseAutoManager()
    # 1. Créer une ligne vide dans university_site_config pour que la zone hero s'affiche
    sql_config = f"""
    INSERT INTO app.university_site_config (university_id, hero_title, hero_subtitle, hero_primary_color, hero_secondary_color, hero_poster_media_id)
    VALUES ('{university_id}'::UUID, NULL, NULL, NULL, NULL, NULL)
    ON CONFLICT (university_id) DO NOTHING;
    """
    res_config = m.execute_sql_auto(sql_config)
    print("university_site_config (ligne vide):", res_config)

    # 2. Vérifier que la ligne a bien été insérée
    sql_check = f"""
    SELECT * FROM app.university_site_config WHERE university_id = '{university_id}'::UUID;
    """
    res_check = m.execute_sql_auto(sql_check)
    print("Vérification university_site_config:", res_check)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python .windsurf/create_empty_structure_rpc.py <UNIVERSITY_ID>")
        sys.exit(1)
    create_empty_structure(sys.argv[1])
