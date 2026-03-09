#!/usr/bin/env python3
from __future__ import annotations

"""Tests directs des RPC landing (public + admin) pour vérifier leur existence.

Utilise SupabaseAutoManager + service_role, comme les autres scripts .windsurf.
On s'attend à voir :
- pour les RPC publiques: des données ou un JSON success/error
- pour les RPC admin: souvent {"success": false, "error": "not_authenticated"}
  (car service_role ne représente pas un utilisateur auth.uid())
Mais l'objectif principal est de vérifier que les fonctions existent et répondent.
"""

import json
import requests

from supabase_auto_manager import SupabaseAutoManager


def main() -> int:
    m = SupabaseAutoManager()
    base = m.url
    headers = m.headers

    # 1) RPC publique: app_public_landing_content
    print("=== app_public_landing_content() ===")
    url1 = f"{base}/rest/v1/rpc/app_public_landing_content"
    r1 = requests.post(url1, headers=headers, json={}, timeout=30)
    print("HTTP", r1.status_code)
    try:
        print(json.dumps(r1.json(), indent=2, ensure_ascii=False)[:800])
    except Exception:
        print(r1.text[:800])

    # 2) RPC admin: app_admin_get_landing_content
    print("\n=== app_admin_get_landing_content() ===")
    url2 = f"{base}/rest/v1/rpc/app_admin_get_landing_content"
    r2 = requests.post(url2, headers=headers, json={}, timeout=30)
    print("HTTP", r2.status_code)
    try:
        print(json.dumps(r2.json(), indent=2, ensure_ascii=False)[:800])
    except Exception:
        print(r2.text[:800])

    # 3) RPC admin: app_admin_upsert_landing_video
    print("\n=== app_admin_upsert_landing_video(...) ===")
    url3 = f"{base}/rest/v1/rpc/app_admin_upsert_landing_video"
    payload3 = {
        "p_video_id": None,
        "p_video_url": "https://example.com/test.mp4",
        "p_title": "Test RPC Video",
        "p_sort_order": 1,
        "p_is_active": True,
    }
    r3 = requests.post(url3, headers=headers, json=payload3, timeout=30)
    print("HTTP", r3.status_code)
    try:
        print(json.dumps(r3.json(), indent=2, ensure_ascii=False)[:800])
    except Exception:
        print(r3.text[:800])

    # 4) RPC admin: app_admin_delete_landing_video
    print("\n=== app_admin_delete_landing_video(...) ===")
    url4 = f"{base}/rest/v1/rpc/app_admin_delete_landing_video"
    # ID arbitraire, ici l'objectif est uniquement de vérifier que la fonction répond.
    payload4 = {"p_video_id": "00000000-0000-0000-0000-000000000000"}
    r4 = requests.post(url4, headers=headers, json=payload4, timeout=30)
    print("HTTP", r4.status_code)
    try:
        print(json.dumps(r4.json(), indent=2, ensure_ascii=False)[:800])
    except Exception:
        print(r4.text[:800])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
