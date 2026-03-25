#!/usr/bin/env python3
"""Audit Supabase complet: tables challenges, vidéos, video_assets, participations, RPCs."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    print(f"\n=== {label} ===")
    print(json.dumps(d, indent=2, ensure_ascii=False, default=str)[:6000])
    return d

def main():
    m = SupabaseAutoManager()
    out = {}

    out["challenge_tables"] = q(m, "1. Tables challenge/video dans schema app",
        """SELECT table_name,
              (SELECT count(*) FROM information_schema.columns c
               WHERE c.table_schema='app' AND c.table_name=t.table_name) as col_count
         FROM information_schema.tables t
         WHERE table_schema='app'
           AND (table_name LIKE '%challenge%' OR table_name LIKE '%video%'
                OR table_name LIKE '%free_video%' OR table_name LIKE '%participation%')
         ORDER BY table_name""")

    out["cols_challenges"] = q(m, "2. Colonnes app.challenges",
        """SELECT column_name, data_type, is_nullable, column_default
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='challenges'
         ORDER BY ordinal_position""")

    out["cols_challenge_participations"] = q(m, "3. Colonnes app.challenge_participations",
        """SELECT column_name, data_type, is_nullable
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='challenge_participations'
         ORDER BY ordinal_position""")

    out["cols_video_assets"] = q(m, "4. Colonnes app.video_assets",
        """SELECT column_name, data_type, is_nullable
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='video_assets'
         ORDER BY ordinal_position""")

    out["cols_video_asset_sources"] = q(m, "5. Colonnes app.video_asset_sources",
        """SELECT column_name, data_type, is_nullable
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='video_asset_sources'
         ORDER BY ordinal_position""")

    out["cols_free_videos"] = q(m, "6. Colonnes app.free_videos",
        """SELECT column_name, data_type, is_nullable
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='free_videos'
         ORDER BY ordinal_position""")

    out["cols_challenge_video_assets"] = q(m, "7. Colonnes app.challenge_video_assets",
        """SELECT column_name, data_type, is_nullable
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='challenge_video_assets'
         ORDER BY ordinal_position""")

    out["rpcs_challenge_video"] = q(m, "8. RPCs challenge/video/free",
        """SELECT routine_name
         FROM information_schema.routines
         WHERE routine_schema='public'
           AND (routine_name LIKE '%challenge%'
                OR routine_name LIKE '%video%'
                OR routine_name LIKE '%free_video%'
                OR routine_name LIKE '%videoasset%')
         ORDER BY routine_name""")

    out["data_counts"] = q(m, "9. Données existantes",
        """SELECT
          (SELECT count(*) FROM app.challenges) as challenges,
          (SELECT count(*) FROM app.challenge_participations) as participations,
          (SELECT count(*) FROM app.video_assets) as video_assets,
          (SELECT count(*) FROM app.free_videos) as free_videos""")

    out["storage_buckets"] = q(m, "10. Buckets storage liés vidéo",
        """SELECT id, name, public, file_size_limit, allowed_mime_types
         FROM storage.buckets
         WHERE name ILIKE '%video%' OR name ILIKE '%challenge%' OR name ILIKE '%media%'
         ORDER BY name""")

    out["cols_video_comments"] = q(m, "11. Colonnes app.video_comments",
        """SELECT column_name, data_type, is_nullable
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='video_comments'
         ORDER BY ordinal_position""")

    out["cols_video_likes"] = q(m, "12. Colonnes app.video_likes",
        """SELECT column_name, data_type, is_nullable
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='video_likes'
         ORDER BY ordinal_position""")

    out["cols_video_reports"] = q(m, "13. Colonnes app.video_reports",
        """SELECT column_name, data_type, is_nullable
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='video_reports'
         ORDER BY ordinal_position""")

    from pathlib import Path
    p = Path(__file__).parent / "logs" / "audit_challenge_studio_supabase.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(out, indent=2, ensure_ascii=False, default=str), encoding="utf-8")
    print(f"\nSaved: {p}")

if __name__ == "__main__":
    main()
