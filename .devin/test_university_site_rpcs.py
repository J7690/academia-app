#!/usr/bin/env python3
"""Tests rapides des RPC mini-site université.

- app_list_university_site_for_management (rôle université requis)
- app_public_university_site(slug)

Utilise SupabaseAutoManager et la clé service_role, conformément aux patterns .windsurf.
"""

from __future__ import annotations

import json

import requests

from supabase_auto_manager import SupabaseAutoManager


def main() -> int:
    m = SupabaseAutoManager()
    base = m.url
    headers = m.headers

    # 1) RPC de gestion (sera "not_authenticated" avec service_role, c'est attendu)
    print("=== app_list_university_site_for_management ===")
    url1 = f"{base}/rest/v1/rpc/app_list_university_site_for_management"
    r1 = requests.post(url1, headers=headers, json={}, timeout=30)
    print("HTTP", r1.status_code)
    try:
        print(json.dumps(r1.json(), indent=2, ensure_ascii=False)[:800])
    except Exception:
        print(r1.text[:800])

    # 2) RPC publique pour le mini-site
    print("\n=== app_public_university_site('universite-arbilo') ===")
    url2 = f"{base}/rest/v1/rpc/app_public_university_site"
    r2 = requests.post(url2, headers=headers, json={"p_slug": "universite-arbilo"}, timeout=30)
    print("HTTP", r2.status_code)
    try:
        print(json.dumps(r2.json(), indent=2, ensure_ascii=False)[:800])
    except Exception:
        print(r2.text[:800])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
