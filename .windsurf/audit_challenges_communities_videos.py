#!/usr/bin/env python3
"""Audit Supabase ciblé : Challenges, Communautés, Vidéos.

Compare les vrais noms de tables, RPCs, colonnes côté Supabase
avec ce que Flutter appelle, pour identifier les divergences.
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
    results = {}

    print("=" * 70)
    print("  AUDIT SUPABASE — Challenges, Communautés, Vidéos")
    print("=" * 70)

    # =========================================================================
    # PARTIE A : CHALLENGES & VIDÉOS
    # =========================================================================

    # A1. Tables challenge_* et video_* et free_video*
    r = run_sql(manager, "A1. Tables challenge_* / video_* / free_video*", """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
          AND (table_name ILIKE 'challenge%'
               OR table_name ILIKE 'video%'
               OR table_name ILIKE 'free_video%')
        ORDER BY table_name
    """)
    results["A1_tables"] = r.get("data", [])

    # A2. RPCs appelées par Flutter dans student_challenges_tab.dart
    # Flutter appelle : app_student_unified_video_feed, app_student_list_challenges,
    # app_student_list_video_comments, app_student_delete_video_comment,
    # app_student_list_user_videos, app_student_video_like, etc.
    r = run_sql(manager, "A2. RPCs challenge/video (proname ILIKE '%challenge%' OR '%video%' OR '%unified%feed%')", """
        SELECT n.nspname AS schema, p.proname AS function_name,
               pg_get_function_arguments(p.oid) AS arguments,
               pg_get_function_result(p.oid) AS return_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE (p.proname ILIKE '%challenge%'
               OR p.proname ILIKE '%video%'
               OR p.proname ILIKE '%unified%feed%')
          AND n.nspname NOT IN ('pg_catalog', 'information_schema')
        ORDER BY p.proname
    """)
    results["A2_rpcs"] = r.get("data", [])

    # A3. Colonnes de app.challenge_participations
    r = run_sql(manager, "A3. Colonnes de app.challenge_participations", """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'challenge_participations'
        ORDER BY ordinal_position
    """)
    results["A3_challenge_participations_cols"] = r.get("data", [])

    # A4. Colonnes de app.free_videos
    r = run_sql(manager, "A4. Colonnes de app.free_videos", """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'free_videos'
        ORDER BY ordinal_position
    """)
    results["A4_free_videos_cols"] = r.get("data", [])

    # A5. Colonnes de app.video_assets
    r = run_sql(manager, "A5. Colonnes de app.video_assets", """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'video_assets'
        ORDER BY ordinal_position
    """)
    results["A5_video_assets_cols"] = r.get("data", [])

    # A6. Colonnes de app.video_renditions
    r = run_sql(manager, "A6. Colonnes de app.video_renditions", """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'video_renditions'
        ORDER BY ordinal_position
    """)
    results["A6_video_renditions_cols"] = r.get("data", [])

    # A7. Source code de app_student_unified_video_feed (le RPC principal du feed)
    r = run_sql(manager, "A7. Source de app_student_unified_video_feed", """
        SELECT n.nspname AS schema, p.proname,
               pg_get_function_arguments(p.oid) AS args,
               pg_get_functiondef(p.oid) AS source
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE p.proname = 'app_student_unified_video_feed'
    """)
    results["A7_unified_feed_source"] = r.get("data", [])

    # A8. Nombre de lignes dans les tables vidéo/challenge
    r = run_sql(manager, "A8. Nombre de lignes tables challenge/vidéo", """
        SELECT 'challenges' AS tbl, COUNT(*) AS cnt FROM app.challenges
        UNION ALL SELECT 'challenge_participations', COUNT(*) FROM app.challenge_participations
        UNION ALL SELECT 'free_videos', COUNT(*) FROM app.free_videos
        UNION ALL SELECT 'video_assets', COUNT(*) FROM app.video_assets
        UNION ALL SELECT 'video_renditions', COUNT(*) FROM app.video_renditions
    """)
    results["A8_row_counts"] = r.get("data", [])

    # =========================================================================
    # PARTIE B : COMMUNAUTÉS
    # =========================================================================

    # B1. Tables communauté
    r = run_sql(manager, "B1. Tables communauté (community* / direct_*)", """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
          AND (table_name ILIKE 'communit%'
               OR table_name ILIKE 'direct_%')
        ORDER BY table_name
    """)
    results["B1_community_tables"] = r.get("data", [])

    # B2. RPCs communauté
    r = run_sql(manager, "B2. RPCs communauté", """
        SELECT n.nspname AS schema, p.proname AS function_name,
               pg_get_function_arguments(p.oid) AS arguments
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE (p.proname ILIKE '%communit%'
               OR p.proname ILIKE '%direct_message%'
               OR p.proname ILIKE '%dm_%')
          AND n.nspname NOT IN ('pg_catalog', 'information_schema')
        ORDER BY p.proname
    """)
    results["B2_community_rpcs"] = r.get("data", [])

    # B3. Colonnes de app.communities
    r = run_sql(manager, "B3. Colonnes de app.communities", """
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'communities'
        ORDER BY ordinal_position
    """)
    results["B3_communities_cols"] = r.get("data", [])

    # B4. Colonnes de app.community_memberships (ou community_members)
    r = run_sql(manager, "B4. Colonnes de app.community_memberships", """
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app'
          AND table_name IN ('community_memberships', 'community_members')
        ORDER BY ordinal_position
    """)
    results["B4_memberships_cols"] = r.get("data", [])

    # B5. Colonnes de app.community_posts
    r = run_sql(manager, "B5. Colonnes de app.community_posts", """
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'community_posts'
        ORDER BY ordinal_position
    """)
    results["B5_posts_cols"] = r.get("data", [])

    # B6. Nombre de lignes tables communauté
    r = run_sql(manager, "B6. Nombre de lignes tables communauté", """
        SELECT 'communities' AS tbl, COUNT(*) AS cnt FROM app.communities
        UNION ALL SELECT 'community_memberships', COUNT(*) FROM app.community_memberships
        UNION ALL SELECT 'community_posts', COUNT(*) FROM app.community_posts
    """)
    results["B6_community_row_counts"] = r.get("data", [])

    # B7. Tables stories
    r = run_sql(manager, "B7. Tables stories", """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
          AND table_name ILIKE '%stor%'
        ORDER BY table_name
    """)
    results["B7_stories_tables"] = r.get("data", [])

    # B8. Colonnes app.community_stories (si existe)
    r = run_sql(manager, "B8. Colonnes app.community_stories", """
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'community_stories'
        ORDER BY ordinal_position
    """)
    results["B8_stories_cols"] = r.get("data", [])

    # =========================================================================
    # PARTIE C : VÉRIFICATIONS CROISÉES FLUTTER ↔ SUPABASE
    # =========================================================================

    # C1. Vérifier que les RPCs appelées par Flutter existent bien
    flutter_rpcs = [
        'app_student_unified_video_feed',
        'app_student_list_challenges',
        'app_student_list_video_comments',
        'app_student_delete_video_comment',
        'app_student_list_user_videos',
        'app_student_video_like',
        'app_student_list_communities',
        'app_student_list_my_communities',
        'app_student_list_my_chats',
        'app_student_add_community_post',
        'app_student_list_community_posts',
        'app_student_create_group',
        'app_student_report_community',
        'app_student_edit_community_post',
        'app_student_pin_community_post',
        'app_student_list_community_members',
        'app_student_create_community_story',
        'app_student_list_community_stories',
        'app_student_get_or_create_dm_conversation',
        'app_student_send_direct_message',
        'app_student_list_direct_messages',
        'app_student_list_dm_conversations',
        'app_student_mark_dm_read',
        'app_videoasset_get_playback_manifest',
    ]
    rpc_list_str = ", ".join([f"'{r}'" for r in flutter_rpcs])

    r = run_sql(manager, "C1. RPCs Flutter → Supabase : lesquelles existent ?", f"""
        SELECT p.proname AS function_name,
               CASE WHEN p.proname IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END AS status
        FROM unnest(ARRAY[{rpc_list_str}]::text[]) AS expected(name)
        LEFT JOIN pg_proc p ON p.proname = expected.name
        LEFT JOIN pg_namespace n ON p.pronamespace = n.oid
            AND n.nspname NOT IN ('pg_catalog', 'information_schema')
        ORDER BY expected.name
    """)
    results["C1_flutter_rpcs_check"] = r.get("data", [])

    # C2. Buckets storage liés aux challenges/vidéos/communautés
    r = run_sql(manager, "C2. Buckets storage", """
        SELECT id, name, public, file_size_limit, allowed_mime_types
        FROM storage.buckets
        WHERE name ILIKE '%challenge%'
           OR name ILIKE '%video%'
           OR name ILIKE '%community%'
           OR name ILIKE '%media%'
        ORDER BY name
    """)
    results["C2_buckets"] = r.get("data", [])

    # =========================================================================
    # Sauvegarder les résultats
    # =========================================================================
    output_path = manager.windsurf_dir / "logs" / "audit_challenges_communities_videos.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False, default=str)

    print(f"\n{'='*70}")
    print(f"  AUDIT TERMINÉ — Résultats sauvegardés dans {output_path.name}")
    print(f"{'='*70}")


if __name__ == "__main__":
    main()
