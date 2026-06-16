#!/usr/bin/env python3
"""Audit complet des tables et fonctions communautés dans Supabase.

Utilise SupabaseAutoManager.execute_sql_auto() pour interroger
la base via la RPC execute_sql.
"""

from __future__ import annotations
import json
from supabase_auto_manager import SupabaseAutoManager


def run_sql(manager: SupabaseAutoManager, label: str, sql: str):
    """Execute SQL and print results."""
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"{'='*70}")
    result = manager.execute_sql_auto(sql)
    if result.get("success"):
        data = result.get("data", [])
        if data:
            print(json.dumps(data, indent=2, ensure_ascii=False, default=str))
        else:
            print("  (aucun résultat)")
    else:
        print(f"  ERREUR: {result.get('error', 'inconnue')}")
    return result


def main():
    manager = SupabaseAutoManager()
    print("=" * 70)
    print("  AUDIT COMMUNAUTÉS SUPABASE — Academia")
    print("=" * 70)

    # 1. Lister toutes les tables dans le schéma 'app' liées aux communautés
    run_sql(manager, "1. TABLES dans le schéma 'app' (communautés)", """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
          AND table_name ILIKE '%communit%'
        ORDER BY table_name
    """)

    # 2. Lister TOUTES les tables du schéma 'app'
    run_sql(manager, "2. TOUTES les tables du schéma 'app'", """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
        ORDER BY table_name
    """)

    # 3. Colonnes de app.communities
    run_sql(manager, "3. Colonnes de app.communities", """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'communities'
        ORDER BY ordinal_position
    """)

    # 4. Colonnes de app.community_members
    run_sql(manager, "4. Colonnes de app.community_members", """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'community_members'
        ORDER BY ordinal_position
    """)

    # 5. Colonnes de app.community_posts
    run_sql(manager, "5. Colonnes de app.community_posts", """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'community_posts'
        ORDER BY ordinal_position
    """)

    # 6. Colonnes de app.community_polls
    run_sql(manager, "6. Colonnes de app.community_polls", """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'community_polls'
        ORDER BY ordinal_position
    """)

    # 7. Chercher d'autres tables communautés (reactions, reports, etc.)
    run_sql(manager, "7. Autres tables communautés (reactions, reports, read_status...)", """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE (table_name ILIKE '%community%' OR table_name ILIKE '%communit%')
          AND table_schema NOT IN ('information_schema', 'pg_catalog')
        ORDER BY table_schema, table_name
    """)

    # 8. Toutes les fonctions RPC liées aux communautés
    run_sql(manager, "8. Fonctions RPC communautés (app_student_*community* + app_admin_*community*)", """
        SELECT n.nspname AS schema, p.proname AS function_name,
               pg_get_function_arguments(p.oid) AS arguments,
               pg_get_function_result(p.oid) AS return_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE p.proname ILIKE '%communit%'
        ORDER BY p.proname
    """)

    # 9. Toutes les fonctions dans le schéma 'app' ou 'public' qui contiennent 'community'
    run_sql(manager, "9. Fonctions contenant 'community' dans tous les schémas", """
        SELECT n.nspname AS schema, p.proname AS function_name
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE (p.proname ILIKE '%community%' OR p.proname ILIKE '%communit%')
          AND n.nspname NOT IN ('pg_catalog', 'information_schema')
        ORDER BY n.nspname, p.proname
    """)

    # 10. RLS policies sur les tables communautés
    run_sql(manager, "10. RLS policies sur les tables communautés", """
        SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
        FROM pg_policies
        WHERE tablename ILIKE '%communit%'
        ORDER BY schemaname, tablename, policyname
    """)

    # 11. Indexes sur les tables communautés
    run_sql(manager, "11. Indexes sur les tables communautés", """
        SELECT schemaname, tablename, indexname, indexdef
        FROM pg_indexes
        WHERE tablename ILIKE '%communit%'
          AND schemaname NOT IN ('pg_catalog', 'information_schema')
        ORDER BY tablename, indexname
    """)

    # 12. Triggers sur les tables communautés
    run_sql(manager, "12. Triggers sur les tables communautés", """
        SELECT trigger_schema, trigger_name, event_object_table, action_timing, event_manipulation, action_statement
        FROM information_schema.triggers
        WHERE event_object_table ILIKE '%communit%'
        ORDER BY event_object_table, trigger_name
    """)

    # 13. Nombre de lignes dans chaque table communauté
    run_sql(manager, "13. Nombre de lignes dans les tables communautés", """
        SELECT 'communities' AS table_name, COUNT(*) AS row_count FROM app.communities
        UNION ALL
        SELECT 'community_members', COUNT(*) FROM app.community_members
        UNION ALL
        SELECT 'community_posts', COUNT(*) FROM app.community_posts
        UNION ALL
        SELECT 'community_polls', COUNT(*) FROM app.community_polls
    """)

    # 14. Vérifier si des colonnes is_pinned, edited_at, role existent déjà
    run_sql(manager, "14. Colonnes spéciales (is_pinned, edited_at, role, is_announcement...)", """
        SELECT table_name, column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'app'
          AND table_name ILIKE '%communit%'
          AND column_name IN ('is_pinned', 'edited_at', 'role', 'is_announcement', 'is_admin', 'is_moderator', 'pinned_post_id', 'edited_content')
        ORDER BY table_name, column_name
    """)

    print("\n" + "=" * 70)
    print("  AUDIT TERMINÉ")
    print("=" * 70)


if __name__ == "__main__":
    main()
