#!/usr/bin/env python3
"""Test d'accès REST à app.universities via le schéma app.

Ce script vérifie si l'API REST Supabase voit la table app.universities
via le profil de schéma `app` (Accept-Profile/Content-Profile).
"""

from __future__ import annotations

import requests

import auto_supabase_import as sup


def main() -> int:
    url = f"{sup.SUPABASE_URL}/rest/v1/universities"
    headers = dict(sup.API_HEADERS)
    headers["Accept-Profile"] = "app"
    headers["Content-Profile"] = "app"

    try:
        resp = requests.get(url + "?limit=1", headers=headers, timeout=15)
    except Exception as exc:
        print(f"[ERROR] Exception réseau: {exc}")
        return 1

    print(f"HTTP {resp.status_code}")
    print(resp.text[:600])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
