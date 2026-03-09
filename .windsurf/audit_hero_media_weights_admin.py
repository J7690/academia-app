#!/usr/bin/env python3
from __future__ import annotations

import json
from typing import Any, Dict

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, sql: str, timeout: int = 60) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"http": resp.status_code, "ok": False, "raw": (resp.text or "")[:2000]}

    if isinstance(data, dict):
        # admin_execute_sql convention: top-level dict avec ok/error
        return {"http": resp.status_code, **data}

    if isinstance(data, list):
        # Mode SELECT brut
        return {"http": resp.status_code, "ok": True, "mode": "select", "rows": data}

    return {"http": resp.status_code, "ok": False, "error": "unexpected_json"}


def main() -> int:
    m = SupabaseAutoManager()

    sql = """
    WITH hp AS (
      SELECT slot, media_type, base_image_url, base_video_url, is_active, sort_order, title
      FROM app.hero_playlist
      WHERE slot IN ('landing_hero_main', 'student_home_hero_main')
      ORDER BY slot, sort_order
    ),
    hp_urls AS (
      SELECT
        slot,
        media_type,
        is_active,
        sort_order,
        title,
        base_image_url,
        base_video_url,
        COALESCE(NULLIF(base_video_url, ''), base_image_url) AS any_url
      FROM hp
    ),
    hp_storage AS (
      SELECT
        h.*,
        REGEXP_REPLACE(SPLIT_PART(h.any_url, '/object/public/', 2), '/.*$', '') AS bucket_id,
        REGEXP_REPLACE(h.any_url, '^.*?/object/public/[^/]+/', '') AS object_name
      FROM hp_urls h
      WHERE h.any_url LIKE 'https://%/storage/v1/object/public/%'
    )
    SELECT
      h.slot,
      h.media_type,
      h.is_active,
      h.sort_order,
      h.title,
      h.base_image_url,
      h.base_video_url,
      o.bucket_id,
      o.name AS storage_name,
      (o.metadata->>'size')::bigint AS size_bytes
    FROM hp_storage h
    LEFT JOIN storage.objects o
      ON o.bucket_id = h.bucket_id
     AND o.name = h.object_name
    ORDER BY h.slot, h.sort_order
    """.strip()

    result = run_sql(m, sql)
    print(json.dumps(result, ensure_ascii=False, indent=2)[:8000])
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
