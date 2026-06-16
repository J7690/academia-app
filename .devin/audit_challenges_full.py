#!/usr/bin/env python3
"""Audit complet du module Challenges — tables, RPCs, données.

Vérifie :
1. Tables challenge_* existantes et leurs colonnes
2. RPCs challenge_* (student + admin)
3. Comptages de données (challenges, participations, vidéos, likes, etc.)
4. Tables VideoAsset liées aux challenges
5. Buckets storage liés
"""

from __future__ import annotations
import json
from datetime import datetime
from supabase_auto_manager import SupabaseAutoManager


def run_query(manager, label, sql):
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"{'='*60}")
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
    ts = datetime.now().isoformat()
    results = {"timestamp": ts, "sections": {}}

    # 1. Tables challenge_* dans schema app
    r = run_query(manager, "1. Tables challenge_* dans schema app", """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'app'
          AND table_name LIKE 'challenge%'
        ORDER BY table_name
    """)
    results["sections"]["challenge_tables"] = r

    # 2. Colonnes de app.challenges
    r = run_query(manager, "2. Colonnes app.challenges", """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'challenges'
        ORDER BY ordinal_position
    """)
    results["sections"]["challenges_columns"] = r

    # 3. Colonnes de app.challenge_participations
    r = run_query(manager, "3. Colonnes app.challenge_participations", """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'challenge_participations'
        ORDER BY ordinal_position
    """)
    results["sections"]["challenge_participations_columns"] = r

    # 4. Colonnes de app.challenge_video_overlays
    r = run_query(manager, "4. Colonnes app.challenge_video_overlays", """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'challenge_video_overlays'
        ORDER BY ordinal_position
    """)
    results["sections"]["challenge_video_overlays_columns"] = r

    # 5. Colonnes de app.challenge_video_assets
    r = run_query(manager, "5. Colonnes app.challenge_video_assets", """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'challenge_video_assets'
        ORDER BY ordinal_position
    """)
    results["sections"]["challenge_video_assets_columns"] = r

    # 6. Colonnes de app.challenge_video_render_jobs (si existe)
    r = run_query(manager, "6. Colonnes app.challenge_video_render_jobs", """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'challenge_video_render_jobs'
        ORDER BY ordinal_position
    """)
    results["sections"]["challenge_video_render_jobs_columns"] = r

    # 7. Toutes les RPCs challenge_* (student + admin)
    r = run_query(manager, "7. RPCs challenge (student + admin)", """
        SELECT p.proname AS function_name,
               pg_get_function_arguments(p.oid) AS arguments,
               pg_get_function_result(p.oid) AS return_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname IN ('app', 'public')
          AND p.proname LIKE '%challenge%'
        ORDER BY p.proname
    """)
    results["sections"]["challenge_rpcs"] = r

    # 8. Comptages de données
    r = run_query(manager, "8. Comptages challenges", """
        SELECT
            (SELECT COUNT(*) FROM app.challenges) AS total_challenges,
            (SELECT COUNT(*) FROM app.challenges WHERE is_active = TRUE) AS active_challenges,
            (SELECT COUNT(*) FROM app.challenge_participations) AS total_participations,
            (SELECT COUNT(*) FROM app.challenge_participations WHERE is_active = TRUE) AS active_participations,
            (SELECT COUNT(*) FROM app.challenge_likes) AS total_likes,
            (SELECT COUNT(*) FROM app.challenge_favorites) AS total_favorites,
            (SELECT COUNT(*) FROM app.challenge_comments) AS total_comments,
            (SELECT COUNT(*) FROM app.challenge_reports) AS total_reports,
            (SELECT COUNT(*) FROM app.challenge_video_overlays) AS total_overlays,
            (SELECT COUNT(*) FROM app.challenge_video_assets) AS total_video_assets
    """)
    results["sections"]["counts"] = r

    # 9. Échantillon challenges
    r = run_query(manager, "9. Échantillon challenges (5 derniers)", """
        SELECT id, slug, title, challenge_type, difficulty, points,
               is_featured, is_active, start_at, end_at, created_at
        FROM app.challenges
        ORDER BY created_at DESC
        LIMIT 5
    """)
    results["sections"]["challenges_sample"] = r

    # 10. Échantillon participations
    r = run_query(manager, "10. Échantillon participations (5 dernières)", """
        SELECT id, challenge_id, user_id, status, score, rank,
               video_url, moderation_status, remix_type,
               started_at, submitted_at
        FROM app.challenge_participations
        ORDER BY started_at DESC
        LIMIT 5
    """)
    results["sections"]["participations_sample"] = r

    # 11. VideoAsset table (si existe — migration récente)
    r = run_query(manager, "11. Table video_assets (si existe)", """
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'video_assets'
        ORDER BY ordinal_position
    """)
    results["sections"]["video_assets_columns"] = r

    # 12. RPCs VideoAsset
    r = run_query(manager, "12. RPCs video_asset / videoasset", """
        SELECT p.proname AS function_name,
               pg_get_function_arguments(p.oid) AS arguments,
               pg_get_function_result(p.oid) AS return_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname IN ('app', 'public')
          AND (p.proname LIKE '%video_asset%' OR p.proname LIKE '%videoasset%')
        ORDER BY p.proname
    """)
    results["sections"]["videoasset_rpcs"] = r

    # 13. Storage buckets liés
    r = run_query(manager, "13. Buckets storage", """
        SELECT id, name, public, file_size_limit, allowed_mime_types
        FROM storage.buckets
        WHERE name LIKE '%challenge%' OR name LIKE '%video%' OR name LIKE '%media%'
        ORDER BY name
    """)
    results["sections"]["storage_buckets"] = r

    # Sauvegarde
    report_path = manager.windsurf_dir / "logs" / "audit_challenges_full.json"
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False, default=str)
    print(f"\n✅ Rapport sauvegardé: {report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
