#!/usr/bin/env python3
"""Lie un compte Supabase existant à l'Université d'Arbilo.

- Rôle ciblé : compte université (email exact à configurer ci-dessous)
- Action : mettre à jour user_metadata avec role="university" et
  university_id="33333333-3333-3333-3333-333333333333".

Ce script utilise la clé service déjà validée dans auto_supabase_import
et l'API admin Supabase, conformément aux procédures .windsurf.
"""

from __future__ import annotations

from typing import Any, Dict, Optional

import requests

from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY

# Email exact du compte université dans Supabase
TARGET_EMAIL = "hilbertwedraogo@gmail.com"
ARBILO_ID = "33333333-3333-3333-3333-333333333333"

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
    except Exception as exc:
        print(f"[ERROR] Erreur réseau lors de la recherche utilisateur: {exc}")
        return None

    if resp.status_code != 200:
        print(f"[ERROR] HTTP {resp.status_code} lors de la recherche utilisateur: {resp.text[:400]}")
        return None

    data = resp.json()
    if isinstance(data, list):
        if not data:
            print("[ERROR] Aucun utilisateur trouvé pour cet email.")
            return None
        if len(data) > 1:
            print("[WARN] Plusieurs utilisateurs trouvés, utilisation du premier.")
        return data[0]

    # Certains environnements peuvent renvoyer un objet unique
    return data or None


def update_user_metadata(user_id: str, new_metadata: Dict[str, Any]) -> bool:
    """Met à jour user_metadata pour l'utilisateur donné."""
    url = f"{SUPABASE_URL}/auth/v1/admin/users/{user_id}"
    payload = {"user_metadata": new_metadata}
    try:
        resp = requests.patch(url, headers=HEADERS, json=payload, timeout=15)
    except Exception as exc:
        print(f"[ERROR] Erreur réseau lors de la mise à jour metadata: {exc}")
        return False

    if resp.status_code not in (200, 201):
        print(f"[ERROR] HTTP {resp.status_code} lors de la mise à jour metadata: {resp.text[:400]}")
        return False

    print("[OK] Métadonnées utilisateur mises à jour.")
    return True


def main() -> int:
    print(f"[INFO] Recherche du compte université: {TARGET_EMAIL}")
    user = find_user_by_email(TARGET_EMAIL)
    if not user:
        return 1

    user_id = user.get("id")
    if not user_id:
        print("[ERROR] Utilisateur sans id, impossible de continuer.")
        return 1

    # Récupérer les métadonnées existantes et les enrichir
    meta = user.get("user_metadata") or user.get("user_meta_data") or {}
    if not isinstance(meta, dict):
        meta = {}

    meta["role"] = "university"
    meta["university_id"] = ARBILO_ID

    print(f"[INFO] Mise à jour du user {user_id} avec role=university, university_id={ARBILO_ID}")
    if not update_user_metadata(user_id, meta):
        return 1

    print("[SUCCESS] Le compte université est maintenant lié à l'Université d'Arbilo.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
