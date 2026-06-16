#!/usr/bin/env python3
"""Corrige l'item bancal de hero student_home_hero_main.

- L'item 72f03530-9a89-4036-ab26-fb84a3c98e1d a media_type='image' mais une URL vidéo (.mov)
- On le bascule en media_type='video', en déplaçant l'URL vers base_video_url.

À exécuter une seule fois via:
  python .windsurf/hero_fix_student_home_hero_main.py
"""

from __future__ import annotations

import sys
from textwrap import dedent

import requests

from supabase_auto_manager import SupabaseAutoManager


def main() -> int:
    manager = SupabaseAutoManager()
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"

    sql = dedent(
        """
        UPDATE app.hero_playlist
        SET
          media_type = 'video',
          base_video_url = base_image_url,
          base_image_url = NULL,
          updated_at = NOW()
        WHERE id = '72f03530-9a89-4036-ab26-fb84a3c98e1d'::uuid
        RETURNING id, slot, media_type, is_active, sort_order, base_video_url, base_image_url;
        """
    ).strip().rstrip(";")

    try:
        resp = requests.post(
            url,
            headers=manager.headers,
            json={"p_sql": sql},
            timeout=30,
        )
    except Exception as exc:  # pragma: no cover
        print("[ERROR] Network error:", exc)
        return 1

    print("HTTP", resp.status_code)
    print(resp.text)
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
