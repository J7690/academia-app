#!/usr/bin/env python3
"""Crée les comptes de développement (admin, université, étudiant) dans Supabase.

Utilise la clé service_role via SupabaseCredentialsManager.
Les mots de passe et emails ne doivent être utilisés que pour le développement.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import List

import requests

from supabase_credentials import SupabaseCredentialsManager


@dataclass
class DevUser:
  email: str
  password: str
  role: str  # 'admin' | 'university' | 'student'


DEV_USERS: List[DevUser] = [
  DevUser(email="wendenkoote@gmail.com", password="Wenden@Koote0", role="admin"),
  DevUser(email="hilbertwedraogo@gmail.com", password="Wenden@Koote1", role="university"),
  DevUser(email="nexiomgroup@gmail.com", password="Wenden@Koote3", role="student"),
]


def get_supabase_admin_config() -> tuple[str, str]:
  """Récupère (supabase_url, service_key) via SupabaseCredentialsManager."""
  manager = SupabaseCredentialsManager()
  cfg = manager.get_supabase_config()
  if not cfg:
    raise RuntimeError("Impossible de récupérer la configuration Supabase depuis supabase_credentials.")
  return cfg["supabaseUrl"], cfg["serviceKey"]


def create_user(base_url: str, service_key: str, user: DevUser) -> None:
  url = f"{base_url}/auth/v1/admin/users"
  headers = {
    "apikey": service_key,
    "Authorization": f"Bearer {service_key}",
    "Content-Type": "application/json",
  }
  payload = {
    "email": user.email,
    "password": user.password,
    "email_confirm": True,
    "user_metadata": {"role": user.role},
  }

  print(f"\n=== Création utilisateur {user.email} (role={user.role}) ===")
  resp = requests.post(url, headers=headers, json=payload, timeout=30)
  print(f"HTTP {resp.status_code}")

  try:
    data = resp.json()
  except json.JSONDecodeError:
    print(resp.text)
    return

  # Si l'utilisateur existe déjà, l'API renvoie une erreur 422
  if resp.status_code == 201:
    print("✅ Utilisateur créé avec succès")
  else:
    print("⚠️ Réponse Supabase:")
    print(json.dumps(data, indent=2, ensure_ascii=False))


def main() -> int:
  base_url, service_key = get_supabase_admin_config()
  print(f"Utilisation de Supabase: {base_url}")

  for user in DEV_USERS:
    create_user(base_url, service_key, user)

  print("\nTerminé.")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
