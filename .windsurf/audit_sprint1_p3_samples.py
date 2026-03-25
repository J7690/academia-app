#!/usr/bin/env python3
"""Sprint 1 P3: samples corriges + Edge Function transcode-video source."""
import json, requests
from supabase_auto_manager import SupabaseAutoManager

def q(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=60)
    d = r.json() if r.text else {}
    print(f"\n=== {label} ===")
    print(json.dumps(d, indent=2, ensure_ascii=False, default=str)[:4000])
    return d

def main():
    m = SupabaseAutoManager()

    q(m, "Sample video_renditions",
        """SELECT id, video_asset_id, rendition_key, kind, width, height,
                  bitrate_kbps, codec, storage_bucket, storage_path, status
         FROM app.video_renditions
         ORDER BY created_at DESC LIMIT 3""")

    q(m, "Sample video_assets",
        """SELECT id, status, origin, mime_type, duration_ms, width, height
         FROM app.video_assets
         ORDER BY created_at DESC LIMIT 3""")

    q(m, "Sample video_sources",
        """SELECT id, video_asset_id, storage_bucket, storage_path, mime_type, file_size_bytes
         FROM app.video_sources
         ORDER BY created_at DESC LIMIT 3""")

    q(m, "Count renditions par rendition_key",
        """SELECT rendition_key, count(*) as cnt
         FROM app.video_renditions
         GROUP BY rendition_key ORDER BY cnt DESC""")

    q(m, "Count video_assets par status",
        """SELECT status, count(*) as cnt
         FROM app.video_assets
         GROUP BY status ORDER BY cnt DESC""")

    q(m, "RPC playback manifest source (1er param)",
        """SELECT pg_get_functiondef(p.oid)
         FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
         WHERE n.nspname = 'public' AND p.proname = 'app_videoasset_get_playback_manifest'
         LIMIT 1""")

if __name__ == "__main__":
    main()
