#!/usr/bin/env python3
from __future__ import annotations

"""Tests directs des RPC d'accueil étudiant (public + admin) pour vérifier leur existence.

Utilise SupabaseAutoManager + service_role, comme les autres scripts .windsurf.
On s'attend à voir :
- pour la RPC publique: un JSON avec success/announcements/videos
- pour les RPC admin: souvent {"success": false, "error": "not_authenticated"}
  (car service_role ne représente pas un utilisateur auth.uid())
Mais l'objectif principal est de vérifier que les fonctions existent et répondent.
"""

import json
import requests

from supabase_auto_manager import SupabaseAutoManager


def call(name: str, payload: dict | None = None) -> None:
    m = SupabaseAutoManager()
    base = m.url
    headers = m.headers

    print(f"=== {name} ===")
    url = f"{base}/rest/v1/rpc/{name}"
    r = requests.post(url, headers=headers, json=payload or {}, timeout=30)
    print("HTTP", r.status_code)
    try:
        body = r.json()
        print(json.dumps(body, indent=2, ensure_ascii=False)[:800])
    except Exception:
        print(r.text[:800])
    print()


def main() -> int:
    # 1) RPC publique: contenu accueil étudiant
    call("app_public_student_home_content")

    # 2) RPC admin: lecture complète du contenu accueil étudiant
    call("app_admin_get_student_home_content")

    # 3) RPC admin: upsert vidéo (on s'attend souvent à not_authenticated avec service_role)
    call(
        "app_admin_upsert_student_home_video",
        {
            "p_video_id": None,
            "p_video_url": "https://example.com/test.mp4",
            "p_title": "Test RPC Video Student Home",
            "p_sort_order": 1,
            "p_is_active": True,
        },
    )

    # 4) RPC admin: upsert annonce
    call(
        "app_admin_upsert_student_home_announcement",
        {
            "p_announcement_id": None,
            "p_text": "Annonce test accueil étudiant",
            "p_sort_order": 1,
            "p_is_active": True,
        },
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
