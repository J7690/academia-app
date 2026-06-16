#!/usr/bin/env python3
"""Debug de seed pour app.bobodo_knowledge via les méthodes .windsurf.

- Utilise auto_supabase_import (config validée) pour récupérer SUPABASE_URL et API_HEADERS.
- Utilise l'API PostgREST (procédure secondaire dans procedures_supabase.md)
  pour insérer UNE seule connaissance et afficher la réponse brute
  (status_code + body) afin de comprendre pourquoi seed_bobodo_knowledge échoue.
"""

from __future__ import annotations

import json
import sys
from typing import Any, Dict

import requests

try:
    # Import du module validé .windsurf
    import auto_supabase_import as sup
except Exception as exc:  # pragma: no cover
    print("[ERROR] Impossible d'importer auto_supabase_import:", exc)
    sys.exit(1)

SUPABASE_URL: str = sup.SUPABASE_URL  # type: ignore[attr-defined]
API_HEADERS: Dict[str, Any] = sup.API_HEADERS  # type: ignore[attr-defined]


def main() -> int:
    # Exemple: on reprend exactement le premier KNOWLEDGE_ITEMS du seed officiel.
    item: Dict[str, Any] = {
        "category": "nexiom",
        "title": "Présentation de Nexiom Group",
        "content": (
            "Nexiom Group est une entreprise de droit burkinabè basée à Ouagadougou, "
            "dont le cœur de métier est le courtage dans le domaine de la formation. "
            "L'entreprise agit comme intermédiaire entre des structures de formation "
            "professionnelle ou universitaire et les personnes intéressées par leurs offres. "
            "Nexiom Group développe et exploite également des produits numériques, "
            "propose du conseil en orientation académique et conçoit, édite et diffuse "
            "des contenus pédagogiques."
        ),
        "tags": ["nexiom", "groupe", "burkina", "presentation"],
        "language": "fr",
        "is_active": True,
    }

    # Construction de la requête PostgREST conformément à auto_supabase_import._build_table_request
    url = f"{SUPABASE_URL}/rest/v1/bobodo_knowledge"
    headers = dict(API_HEADERS)
    # Cibler le schéma app
    headers["Accept-Profile"] = "app"
    headers["Content-Profile"] = "app"
    headers.setdefault("Content-Type", "application/json")

    print("[INFO] Insertion de test dans app.bobodo_knowledge...")
    print("[DEBUG] URL:", url)
    print("[DEBUG] Headers:", json.dumps(headers, indent=2))
    print("[DEBUG] Payload:", json.dumps(item, ensure_ascii=False, indent=2))

    try:
        resp = requests.post(url, headers=headers, json=item, timeout=15)
    except Exception as exc:  # pragma: no cover
        print("[ERROR] Exception réseau:", exc)
        return 1

    print("[RESULT] Status:", resp.status_code)
    print("[RESULT] Body:")
    try:
        print(json.dumps(resp.json(), ensure_ascii=False, indent=2))
    except Exception:
        print(resp.text)

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
