#!/usr/bin/env python3
from __future__ import annotations

import json

from supabase_auto_manager import SupabaseAutoManager


def main() -> int:
    manager = SupabaseAutoManager()

    print("=== storage.buckets (ALL) ===")
    sql_buckets = """
    SELECT id, name, public
    FROM storage.buckets
    ORDER BY id;
    """.strip()
    res_buckets = manager.execute_sql_auto(sql_buckets)
    print(json.dumps(res_buckets, indent=2, ensure_ascii=False))

    print("\n=== storage.objects policies ===")
    sql_policies = """
    SELECT policyname, roles, cmd, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
    ORDER BY policyname;
    """.strip()
    res_policies = manager.execute_sql_auto(sql_policies)
    print(json.dumps(res_policies, indent=2, ensure_ascii=False))

    print("\n=== app.landing_config (latest) ===")
    sql_landing_config = """
    SELECT *
    FROM app.landing_config
    ORDER BY created_at DESC
    LIMIT 1;
    """.strip()
    res_landing_config = manager.execute_sql_auto(sql_landing_config)
    print(json.dumps(res_landing_config, indent=2, ensure_ascii=False))

    print("\n=== app.landing_partners (all) ===")
    sql_landing_partners = """
    SELECT id, name, logo_url, website_url, sort_order, is_active
    FROM app.landing_partners
    ORDER BY sort_order NULLS LAST, created_at;
    """.strip()
    res_landing_partners = manager.execute_sql_auto(sql_landing_partners)
    print(json.dumps(res_landing_partners, indent=2, ensure_ascii=False))

    print("\n=== app.university_media (all) ===")
    sql_university_media = """
    SELECT id, university_id, media_type, title, description, storage_path, media_url, is_active
    FROM app.university_media
    ORDER BY created_at DESC
    LIMIT 20;
    """.strip()
    res_university_media = manager.execute_sql_auto(sql_university_media)
    print(json.dumps(res_university_media, indent=2, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
