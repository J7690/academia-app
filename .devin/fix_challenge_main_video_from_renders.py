#!/usr/bin/env python3
"""Corrige app.challenge_participations.video_url / video_renditions
à partir des rendus existants dans app.challenge_participation_videos.

Objectif:
- Pour chaque participation active qui possède au moins une vidéo rendue
  dans app.challenge_participation_videos,
- et dont video_url est encore vide, égale à submission_url ou ne pointe
  pas vers un chemin /renders/,
- mettre à jour app.challenge_participations.video_url avec la dernière
  URL rendue (ordre created_at DESC),
- et assurer que video_renditions.default pointe sur cette URL rendue.

Ce script utilise uniquement la RPC admin_execute_sql via SupabaseAutoManager,
conformément aux procédures .windsurf. Il modifie la base (UPDATE), à utiliser
avec précaution.
"""

from __future__ import annotations

import json
from typing import Any

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_admin_sql(manager: SupabaseAutoManager, label: str, sql: str) -> Any:
    base = manager.url
    headers = manager.headers
    url = f"{base}/rest/v1/rpc/admin_execute_sql"

    print(f"\n=== {label} ===")
    print(sql)

    try:
        resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=60)
    except Exception as exc:  # Réseau / DNS / TLS
        print(f"[ERROR] Réseau admin_execute_sql ({label}): {exc}")
        return None

    print("HTTP", resp.status_code)
    try:
        data = resp.json()
    except Exception:
        print(resp.text[:2000])
        return None

    # Pour un SELECT, admin_execute_sql peut renvoyer un objet avec rows
    # ou directement une liste de lignes. On affiche un extrait lisible.
    if isinstance(data, dict):
        rows = data.get("rows")
        if rows is not None:
            print("rows (trunc):")
            print(json.dumps(rows, ensure_ascii=False, indent=2)[:2000])
        else:
            print(json.dumps(data, ensure_ascii=False, indent=2)[:2000])
    else:
        print(json.dumps(data, ensure_ascii=False, indent=2)[:2000])

    return data


def main() -> int:
    manager = SupabaseAutoManager()

    # 1) Prévisualiser les participations concernées (celles dont video_url
    #    est incohérente au regard des rendus existants).
    preview_sql = """
    SELECT
      cp.id,
      cp.status,
      cp.moderation_status,
      cp.submission_url,
      cp.video_url      AS main_video_url,
      v.video_url       AS last_render_url,
      COALESCE(cp.submitted_at, cp.started_at) AS ts
    FROM app.challenge_participations cp
    JOIN LATERAL (
      SELECT video_url
      FROM app.challenge_participation_videos v
      WHERE v.participation_id = cp.id
      ORDER BY created_at DESC
      LIMIT 1
    ) v ON TRUE
    WHERE cp.is_active = TRUE
      AND (
        cp.video_url IS NULL
        OR cp.video_url = cp.submission_url
        OR cp.video_url NOT LIKE '%/renders/%'
      )
    ORDER BY ts DESC
    LIMIT 20;
    """.strip()

    run_admin_sql(manager, "PREVIEW_fix_main_video_from_renders", preview_sql)

    # 2) Appliquer la correction : pour chaque participation active qui a au
    #    moins un rendu dans app.challenge_participation_videos, on prend la
    #    vidéo la plus récente (created_at DESC) et on met à jour
    #    challenge_participations.video_url et video_renditions.default.
    update_sql = """
    WITH chosen AS (
      SELECT DISTINCT ON (v.participation_id)
        v.participation_id,
        v.video_url
      FROM app.challenge_participation_videos v
      ORDER BY v.participation_id, v.created_at DESC
    )
    UPDATE app.challenge_participations cp
    SET
      video_url = c.video_url,
      video_renditions = jsonb_set(
        COALESCE(cp.video_renditions, '{}'::jsonb),
        '{default}',
        to_jsonb(c.video_url),
        TRUE
      )
    FROM chosen c
    WHERE cp.id = c.participation_id
      AND cp.is_active = TRUE
      AND (
        cp.video_url IS NULL
        OR cp.video_url = cp.submission_url
        OR cp.video_url NOT LIKE '%/renders/%'
      );
    """.strip()

    run_admin_sql(manager, "APPLY_fix_main_video_from_renders", update_sql)

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
