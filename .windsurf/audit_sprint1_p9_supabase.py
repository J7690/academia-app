#!/usr/bin/env python3
"""Audit Supabase Sprint 1 P9: upload pipeline, storage config, video_upload_events."""
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

    q(m, "1. Colonnes app.video_upload_events",
        """SELECT column_name, data_type, is_nullable, column_default
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='video_upload_events'
         ORDER BY ordinal_position""")

    q(m, "2. Colonnes app.video_sources",
        """SELECT column_name, data_type, is_nullable
         FROM information_schema.columns
         WHERE table_schema='app' AND table_name='video_sources'
         ORDER BY ordinal_position""")

    q(m, "3. Storage buckets config",
        """SELECT id, name, public, file_size_limit, allowed_mime_types
         FROM storage.buckets
         WHERE name IN ('video-assets', 'challenge-media')""")

    q(m, "4. RPCs upload intent/register",
        """SELECT routine_name
         FROM information_schema.routines
         WHERE routine_schema='public'
           AND (routine_name LIKE '%upload%' OR routine_name LIKE '%ingest%')
         ORDER BY routine_name""")

    q(m, "5. RPC create_upload_intent source code",
        """SELECT pg_get_functiondef(p.oid)
         FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
         WHERE n.nspname = 'public' AND p.proname = 'app_videoasset_create_upload_intent'
         LIMIT 1""")

    q(m, "6. Average video source size",
        """SELECT
           count(*) as total_sources,
           round(avg(file_size_bytes)/1024/1024, 1) as avg_mb,
           round(max(file_size_bytes)/1024/1024, 1) as max_mb,
           round(min(file_size_bytes)/1024/1024, 1) as min_mb
         FROM app.video_sources
         WHERE file_size_bytes IS NOT NULL""")

if __name__ == "__main__":
    main()
