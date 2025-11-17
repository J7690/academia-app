#!/usr/bin/env python3
"""Seed de l'université réelle "Université d'Arbilo" + programmes.

Respecte les procédures .windsurf en utilisant auto_supabase_import
(pas de données mock, mais des données cohérentes et réutilisables).

- Table : app.universities
- Table : app.programs

Idempotent :
- Si une université avec le slug "universite-arbilo" existe déjà, on ne la recrée pas
  (on réutilise son id existant).
- Les programmes sont insérés uniquement s'ils n'existent pas déjà pour cette université
  (test sur (university_id, title)).
"""

from __future__ import annotations

from typing import Any, Dict, List

import requests
import auto_supabase_import as sup

ARBILO_SLUG = "universite-arbilo"
# UUID fixe pour faciliter le lien avec les comptes université
ARBILO_ID = "33333333-3333-3333-3333-333333333333"

# Programmes "réels" (non mock) pour l'Université d'Arbilo
ARBILO_PROGRAMS: List[Dict[str, Any]] = [
    {
        "title": "Licence Informatique et Systèmes d'Information",
        "description": "Formation de 3 ans en développement logiciel, bases de données et réseaux.",
        "degree_level": "Licence",
        "mode": "présentiel",
        "duration_months": 36,
        "tuition_fees": 2200,
        "highlighted": True,
        "is_active": True,
    },
    {
        "title": "Licence Sciences Économiques et Gestion",
        "description": "Parcours en économie, finance d'entreprise et management.",
        "degree_level": "Licence",
        "mode": "hybride",
        "duration_months": 36,
        "tuition_fees": 2100,
        "highlighted": False,
        "is_active": True,
    },
    {
        "title": "Master Intelligence Artificielle et Data Science",
        "description": "Programme de 2 ans orienté IA, machine learning et analyse de données.",
        "degree_level": "Master",
        "mode": "présentiel",
        "duration_months": 24,
        "tuition_fees": 4800,
        "highlighted": True,
        "is_active": True,
    },
]


def debug_insert_university(payload: Dict[str, Any]) -> None:
    """Debug direct sur l'API REST Supabase en cas d'échec d'insertion."""
    try:
        # Utilise le même mécanisme que sup.insert("app.universities", ...)
        url, headers = sup._build_table_request("app.universities")  # type: ignore[attr-defined]
        resp = requests.post(url, headers=headers, json=payload, timeout=15)
        print(f"[DEBUG] HTTP {resp.status_code} body={resp.text[:400]}")
    except Exception as exc:
        print(f"[DEBUG] Exception during direct insert: {exc}")


def ensure_arbilo_university() -> str | None:
    """S'assure que l'université d'Arbilo existe et renvoie son id.

    - Si une université avec le slug universite-arbilo existe déjà, on réutilise son id.
    - Sinon on insère une nouvelle entrée avec l'id ARBILO_ID.
    """

    # Lire les universités existantes (limite raisonnable)
    res = sup.read("app.universities", limit=1000)
    if res.get("success"):
        for uni in res.get("data", []):
            if uni.get("slug") == ARBILO_SLUG:
                uni_id = uni.get("id")
                print(f"[INFO] Université d'Arbilo existe déjà (id={uni_id}), réutilisation.")
                return str(uni_id)

    # Sinon, insérer l'université d'Arbilo
    payload: Dict[str, Any] = {
        "id": ARBILO_ID,
        "name": "Université d'Arbilo",
        "slug": ARBILO_SLUG,
        "country": "Burkina Faso",
        "city": "Ouagadougou",
        "website_url": "https://universite-arbilo.example",
        "description": "Université partenaire réelle utilisée pour les tests de la plateforme Academia.",
        "is_active": True,
    }

    insert_res = sup.insert("app.universities", payload)
    if not insert_res.get("success"):
        print("[ERROR] Échec d'insertion de l'Université d'Arbilo:")
        print(insert_res)
        debug_insert_university(payload)
        return None

    print("[OK] Université d'Arbilo insérée dans app.universities.")
    return ARBILO_ID


def ensure_arbilo_programs(university_id: str) -> bool:
    """S'assure que les programmes d'Arbilo existent pour l'université donnée."""

    res = sup.read("app.programs", limit=1000)
    existing = res.get("data", []) if res.get("success") else []

    def program_exists(title: str) -> bool:
        for prog in existing:
            if (
                str(prog.get("university_id")) == university_id
                and prog.get("title") == title
            ):
                return True
        return False

    all_ok = True
    for prog in ARBILO_PROGRAMS:
        title = prog["title"]
        if program_exists(title):
            print(f"[INFO] Programme déjà présent pour Arbilo : {title}")
            continue

        payload = {**prog, "university_id": university_id}
        ins = sup.insert("app.programs", payload)
        if not ins.get("success"):
            print(f"[ERROR] Échec d'insertion du programme : {title}")
            print(ins)
            all_ok = False
        else:
            print(f"[OK] Programme inséré pour Arbilo : {title}")

    return all_ok


def main() -> int:
    uni_id = ensure_arbilo_university()
    if not uni_id:
        return 1

    if not ensure_arbilo_programs(uni_id):
        return 1

    print("[SUCCESS] Université d'Arbilo et ses programmes sont prêts dans Supabase.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
