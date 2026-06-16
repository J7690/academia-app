#!/usr/bin/env python3
"""Audit Supabase Sprint 1 P3: video_assets, video_renditions, video_sources, transcode RPCs, Edge Functions."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    print(f"\n=== {label} ===")
    txt = json.dumps(d, indent=2, ensure_ascii=False, default=str)
    print(txt[:5000])
    return d

def main():
    m = SupabaseAutoManager()
    out = {}

    out["video_assets_cols"] = q(m, "1. Colonnes app.video_assets",
        """SELECT column_name, data_type, is_nullable, column_default
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='video_assets'
         ORDER BY ordinal_position""")

    out["video_renditions_cols"] = q(m, "2. Colonnes app.video_renditions",
        """SELECT column_name, data_type, is_nullable, column_default
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='video_renditions'
         ORDER BY ordinal_position""")

    out["video_sources_cols"] = q(m, "3. Colonnes app.video_sources",
        """SELECT column_name, data_type, is_nullable, column_default
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='video_sources'
         ORDER BY ordinal_position""")

    out["video_processing_jobs_cols"] = q(m, "4. Colonnes app.video_processing_jobs",
        """SELECT column_name, data_type, is_nullable, column_default
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='video_processing_jobs'
         ORDER BY ordinal_position""")

    out["rpcs_videoasset"] = q(m, "5. RPCs videoasset/transcode/rendition",
        """SELECT routine_name
         FROM information_schema.routines
         WHERE routine_schema='public'
           AND (routine_name LIKE '%videoasset%'
                OR routine_name LIKE '%rendition%'
                OR routine_name LIKE '%transcode%'
                OR routine_name LIKE '%processing%')
         ORDER BY routine_name""")

    out["sample_video_renditions"] = q(m, "6. Sample video_renditions (5 derniers)",
        """SELECT id, video_asset_id, label, codec, width, height,
                  bitrate_bps, storage_url, status
         FROM app.video_renditions
         ORDER BY created_at DESC LIMIT 5""")

    out["sample_video_assets"] = q(m, "7. Sample video_assets (5 derniers)",
        """SELECT id, status, origin, owner_id, mime_type,
                  duration_ms, width, height
         FROM app.video_assets
         ORDER BY created_at DESC LIMIT 5""")

    out["transcode_edge_fn"] = q(m, "8. Edge Function transcode-video test",
        """SELECT 'check_edge_functions' as note""")

    from pathlib import Path
    p = Path(__file__).parent / "logs" / "audit_sprint1_p3_supabase.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(out, indent=2, ensure_ascii=False, default=str), encoding="utf-8")
    print(f"\nSaved: {p}")

if __name__ == "__main__":
    main()
