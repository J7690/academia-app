#!/usr/bin/env python3
from __future__ import annotations

"""Tests des RPC de bibliothèque de cours (étudiant + admin).

Ce script suit les patterns .windsurf :
- utilise SupabaseAutoManager (service_role)
- appelle directement les RPC via /rest/v1/rpc
- ne modifie aucune donnée de manière dangereuse (upsert uniquement en exemple)
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
  # 1) RPC étudiant : liste de la bibliothèque (on s'attend souvent à not_authenticated
  # avec service_role, l'objectif est de vérifier que la fonction répond).
  call("app_list_course_library")

  # 2) RPC admin : liste complète de la bibliothèque
  call("app_admin_list_course_library")

  # 3) RPC admin : upsert de domaine (peut renvoyer not_admin avec service_role,
  # le but est de valider la fonction et la forme de la réponse).
  call(
    "app_admin_upsert_course_domain",
    {
      "p_domain_id": None,
      "p_title": "Test Domaine Bibliothèque",
      "p_description": "Domaine créé pour tester les RPC de bibliothèque.",
      "p_sort_order": 999,
      "p_is_active": True,
    },
  )

  return 0


if __name__ == "__main__":
  raise SystemExit(main())
