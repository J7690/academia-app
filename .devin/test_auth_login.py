#!/usr/bin/env python3
"""Audit ciblé de l'auth Supabase (grant_type=password) via les procédures .windsurf.

- Vérifie l'accès général Supabase via SupabasePermanentAccess
- Teste le login email/mot de passe pour les 3 rôles de dev

Ce script NE MODIFIE PAS la base, il ne fait que des appels HTTP.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import List, Tuple

import requests

# Import des outils d'accès permanent validés
from supabase_permanent_access import SupabasePermanentAccess

# Import éventuel des credentials (si disponibles)
try:
    from supabase_credentials import SupabaseCredentialsManager  # type: ignore
except Exception:  # pragma: no cover - fallback si non dispo
    SupabaseCredentialsManager = None  # type: ignore


DEV_USERS: List[Tuple[str, str, str]] = [
    ("admin", "wendenkoote@gmail.com", "Wenden@Koote0"),
    ("university", "hilbertwedraogo@gmail.com", "Wenden@Koote1"),
    ("student", "nexiomgroup@gmail.com", "Wenden@Koote3"),
]


def get_supabase_auth_config() -> tuple[str, str]:
    """Récupère (url, anon_key) en priorité via SupabaseCredentialsManager.

    Fallback: valeurs figées validées dans .windsurf / Flutter.
    """
    # 1) Essayer via SupabaseCredentialsManager (stockage sécurisé)
    if SupabaseCredentialsManager is not None:
        mgr = SupabaseCredentialsManager()
        cfg = mgr.get_supabase_config()
        if cfg and cfg.get("supabaseUrl") and cfg.get("supabaseKey"):
            return cfg["supabaseUrl"], cfg["supabaseKey"]

    # 2) Fallback: config permanente .windsurf
    access = SupabasePermanentAccess()
    permanent = access.get_permanent_config()
    url = permanent.get("url", "https://thevdfcwlcqzdoybfvgs.supabase.co")

    # L'anon public n'est pas stocké dans permanent_config, on prend la valeur
    # utilisée côté Flutter (supabase_config.dart), validée par .windsurf.
    anon_key = (
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwNTY1NjAsImV4cCI6MjA3ODYzMjU2MH0.8Zm6i6UaOrEOUvOafHOXOf0UiPOdp7on-aajYASOdk8"
    )
    return url, anon_key


def health_check() -> None:
    access = SupabasePermanentAccess()
    health = access.verify_permanent_access()
    print("HEALTH_CHECK:", json.dumps(health, indent=2, ensure_ascii=False))


def test_logins() -> None:
    base_url, anon_key = get_supabase_auth_config()
    print(f"Utilisation de Supabase AUTH: {base_url}")

    for role, email, password in DEV_USERS:
        try:
            resp = requests.post(
                f"{base_url}/auth/v1/token?grant_type=password",
                headers={
                    "apikey": anon_key,
                    "Content-Type": "application/json",
                },
                json={"email": email, "password": password},
                timeout=15,
            )
            summary: dict = {
                "role": role,
                "email": email,
                "status_code": resp.status_code,
            }
            if not resp.ok:
                try:
                    body = resp.json()
                    summary["error"] = body.get("error") or body.get("message") or body
                except Exception:
                    summary["error"] = resp.text[:200]
            else:
                summary["result"] = "success"
            print("LOGIN_TEST:", json.dumps(summary, ensure_ascii=False))
        except Exception as e:  # réseau, DNS, etc.
            print("LOGIN_TEST_EXCEPTION:", json.dumps({
                "role": role,
                "email": email,
                "exception": str(e),
            }, ensure_ascii=False))


def main() -> int:
    health_check()
    test_logins()
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
