#!/usr/bin/env python3
"""Désactive tous les médias Mux (stream.mux.com) dans les tables app.*.

Objectif :
- Mettre is_active = FALSE sur les enregistrements qui pointent encore vers Mux,
  sans supprimer physiquement les lignes.
- Laisser le reste intact (les nouvelles règles SQL empêchent déjà d'ajouter du Mux).

Tables concernées :
- app.course_resources (storage_bucket / external_url / mux_playback_id)
- app.landing_videos (video_url)
- app.student_home_videos (video_url)
- app.university_media (url)

Ce script utilise admin_execute_sql via SupabaseAutoManager, conformément aux
patterns .windsurf.
"""

from __future__ import annotations

import json

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_update(label: str, sql: str) -> None:
    m = SupabaseAutoManager()
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"

    print(f"\n=== {label} ===")
    print(sql)

    try:
        r = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=30)
    except Exception as exc:
        print(f"❌ Erreur réseau: {exc}")
        return

    print("HTTP", r.status_code)
    try:
        data = r.json()
        print(json.dumps(data, indent=2, ensure_ascii=False)[:800])
    except Exception:
        print(r.text[:800])


def main() -> int:
    updates = [
        (
            "course_resources_mux_soft_delete",
            """UPDATE app.course_resources
                SET is_active = FALSE,
                    updated_at = NOW()
                WHERE COALESCE(external_url, '') ILIKE '%stream.mux.com%'
                   OR COALESCE(storage_bucket, '') ILIKE '%stream.mux.com%'""",
        ),
        (
            "landing_videos_mux_soft_delete",
            """UPDATE app.landing_videos
                SET is_active = FALSE,
                    updated_at = NOW()
                WHERE COALESCE(video_url, '') ILIKE '%stream.mux.com%'""",
        ),
        (
            "student_home_videos_mux_soft_delete",
            """UPDATE app.student_home_videos
                SET is_active = FALSE,
                    updated_at = NOW()
                WHERE COALESCE(video_url, '') ILIKE '%stream.mux.com%'""",
        ),
        (
            "university_media_mux_soft_delete",
            """UPDATE app.university_media
                SET is_active = FALSE,
                    updated_at = NOW()
                WHERE COALESCE(url, '') ILIKE '%stream.mux.com%'""",
        ),
    ]

    for label, sql in updates:
        run_update(label, sql)

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
