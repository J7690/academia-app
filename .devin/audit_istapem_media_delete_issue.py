#!/usr/bin/env python3
"""Audit ciblé ISTAPEM: états des médias (actifs/inactifs) et derniers updates.

- Exécute des SELECT via admin_execute_sql et affiche toujours les rows.
"""

from __future__ import annotations

import json
import requests

from supabase_auto_manager import SupabaseAutoManager


def _run_select(m: SupabaseAutoManager, sql: str) -> None:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql.strip()}, timeout=30)
    print("\n=== SQL ===")
    print(sql.strip())
    print("HTTP", resp.status_code)
    if resp.status_code != 200:
        print(resp.text[:800])
        return
    try:
        payload = resp.json()
    except Exception:
        print(resp.text[:800])
        return
    print("Payload keys:", list(payload.keys()) if isinstance(payload, dict) else type(payload))
    print(json.dumps(payload, indent=2, ensure_ascii=False)[:12000])


def main() -> int:
    m = SupabaseAutoManager()

    _run_select(
        m,
        """
        SELECT id, slug, name
        FROM app.universities
        WHERE slug = 'istapem'
        LIMIT 1
        """,
    )

    _run_select(
        m,
        """
        SELECT
          id,
          media_type,
          title,
          is_active,
          sort_order,
          storage_path,
          url,
          created_at,
          updated_at
        FROM app.university_media
        WHERE university_id = (SELECT id FROM app.universities WHERE slug='istapem' LIMIT 1)
        ORDER BY updated_at DESC NULLS LAST, created_at DESC
        LIMIT 200
        """,
    )

    _run_select(
        m,
        """
        SELECT
          COUNT(*) FILTER (WHERE is_active IS TRUE)  AS active_count,
          COUNT(*) FILTER (WHERE is_active IS FALSE) AS inactive_count,
          COUNT(*) AS total_count
        FROM app.university_media
        WHERE university_id = (SELECT id FROM app.universities WHERE slug='istapem' LIMIT 1)
        """,
    )

    _run_select(
        m,
        """
        SELECT
          id,
          media_type,
          title,
          is_active,
          sort_order,
          storage_path,
          created_at,
          updated_at
        FROM app.university_media
        WHERE university_id = (SELECT id FROM app.universities WHERE slug='istapem' LIMIT 1)
          AND is_active IS FALSE
        ORDER BY updated_at DESC NULLS LAST, created_at DESC
        LIMIT 200
        """,
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
