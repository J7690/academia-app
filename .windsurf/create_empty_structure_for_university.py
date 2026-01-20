#!/usr/bin/env python3
"""
Crée une structure vide mais complète pour une nouvelle université :
- university_site_config : ligne vide (hero vide)
- university_site_blocks : 0 ligne (l'UI doit afficher "Ajouter un bloc")
- university_media : 0 ligne (l'UI doit afficher "Ajouter un média")
- university_site_banners : 0 ligne
- university_events : 0 ligne
- university_news : 0 ligne
- university_staff : 0 ligne
- programs : 0 ligne (l'UI doit afficher "Ajouter un programme")
- courses : 0 ligne
"""

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

    # Les autres tables restent vides ; l'UI doit afficher les boutons "Ajouter"
    print("Les autres tables restent vides. L'UI université doit afficher les sections 'Ajouter' même si vide.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python .windsurf/create_empty_structure_for_university.py <UNIVERSITY_ID>")
        sys.exit(1)
    create_empty_structure(sys.argv[1])
