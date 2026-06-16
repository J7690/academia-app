#!/usr/bin/env python3
"""Corrige le compte dev nexiomgroup@gmail.com pour qu'il soit bien traité
comme étudiant (role="student") et non comme université.

- Utilise la clé service_role via auto_supabase_import (pattern .windsurf).
- Met à jour user_metadata via l'API admin Supabase.
"""

from __future__ import annotations

from typing import Any, Dict, Optional

import requests

from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY


TARGET_EMAIL = "nexiomgroup@gmail.com"

HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}


def find_user_by_email(email: str) -> Optional[Dict[str, Any]]:
    """Retourne le user Supabase (admin API) correspondant à l'email."""
    url = f"{SUPABASE_URL}/auth/v1/admin/users"
    try:
        resp = requests.get(url, headers=HEADERS, params={"email": email}, timeout=15)
    except Exception as exc:  # pragma: no cover - log réseau
        print(f"[ERROR] Erreur réseau lors de la recherche utilisateur: {exc}")
        return None

    if resp.status_code != 200:
        print(f"[ERROR] HTTP {resp.status_code} lors de la recherche utilisateur: {resp.text[:400]}")
        return None

    data = resp.json()
    # Selon l'environnement, on peut recevoir une liste ou un objet unique
    if isinstance(data, list):
        if not data:
            print("[ERROR] Aucun utilisateur trouvé pour cet email.")
            return None
        if len(data) > 1:
            print("[WARN] Plusieurs utilisateurs trouvés, utilisation du premier.")
        return data[0]

    if isinstance(data, dict):
        users = data.get("users")
        if isinstance(users, list) and users:
            if len(users) > 1:
                print("[WARN] Plusieurs utilisateurs trouvés (clé 'users'), utilisation du premier.")
            return users[0]

    return data or None


def update_user_metadata(user_id: str, new_metadata: Dict[str, Any]) -> bool:
    """Met à jour user_metadata pour l'utilisateur donné via l'API admin."""
    url = f"{SUPABASE_URL}/auth/v1/admin/users/{user_id}"
    payload = {"user_metadata": new_metadata}
    try:
        resp = requests.patch(url, headers=HEADERS, json=payload, timeout=15)
    except Exception as exc:  # pragma: no cover - log réseau
        print(f"[ERROR] Erreur réseau lors de la mise à jour metadata: {exc}")
        return False

    if resp.status_code not in (200, 201):
        print(
            f"[ERROR] HTTP {resp.status_code} lors de la mise à jour metadata: {resp.text[:400]}"
        )
        return False

    print("[OK] Métadonnées utilisateur mises à jour.")
    return True


def call_admin_execute_sql(sql: str) -> bool:
    """Appelle la RPC admin_execute_sql avec une requête SQL arbitraire.

    Fallback utilisé si l'API admin users/{id} ne permet pas le PATCH.
    """
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    try:
        resp = requests.post(url, headers=HEADERS, json={"p_sql": sql}, timeout=30)
    except Exception as exc:  # pragma: no cover - log réseau
        print(f"[ERROR] Erreur réseau admin_execute_sql: {exc}")
        return False

    if resp.status_code != 200:
        print(f"[ERROR] HTTP {resp.status_code} admin_execute_sql: {resp.text[:400]}")
        return False

    try:
        data = resp.json()
    except Exception:
        return True

    if isinstance(data, dict) and not data.get("ok", True):
        print("[WARN] admin_execute_sql a renvoyé une erreur logique:")
        print(str(data)[:400])
        return False

    return True


def main() -> int:
    print(f"[INFO] Recherche du compte étudiant à corriger: {TARGET_EMAIL}")
    user = find_user_by_email(TARGET_EMAIL)
    if not user:
        return 1

    user_id = user.get("id")
    if not user_id:
        print("[ERROR] Utilisateur sans id, impossible de continuer.")
        return 1

    # Récupérer les métadonnées existantes et les corriger
    meta = user.get("user_metadata") or user.get("user_meta_data") or {}
    if not isinstance(meta, dict):
        meta = {}

    # Forcer le rôle étudiant et retirer tout lien université éventuel
    meta["role"] = "student"
    if "university_id" in meta:
        del meta["university_id"]

    print(f"[INFO] Mise à jour du user {user_id} avec role=student (sans university_id)")
    if not update_user_metadata(user_id, meta):
        print("[WARN] Échec via l'API admin, tentative de mise à jour via admin_execute_sql.")
        # On force role=student et on enlève university_id au niveau de raw_user_meta_data
        sql_meta = f"""
        UPDATE auth.users
        SET raw_user_meta_data = (
          COALESCE(raw_user_meta_data, '{{}}'::jsonb)
          || '{{"role":"student"}}'::jsonb
        ) - 'university_id'
        WHERE email = '{TARGET_EMAIL}';
        """.strip()

        if not call_admin_execute_sql(sql_meta):
            print("[ERROR] Impossible de mettre à jour raw_user_meta_data via admin_execute_sql.")
            return 1

    print("[SUCCESS] Le compte nexiomgroup@gmail.com est maintenant configuré comme étudiant.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
