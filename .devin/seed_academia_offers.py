#!/usr/bin/env python3
"""Seed de données de test pour le module Universités / Offres.

Conformément aux procédures .windsurf, ce script utilise les méthodes
validées d'`auto_supabase_import` (API PostgREST) pour insérer des
universités et programmes de démonstration dans le schéma `app`.

- Tables ciblées : app.universities, app.programs
- Réexécution sûre : si des universités existent déjà, le seed est ignoré.
"""

from __future__ import annotations

from typing import Any, Dict, List

import auto_supabase_import as sup


UNIVERSITIES: List[Dict[str, Any]] = [
    {
        "id": "11111111-1111-1111-1111-111111111111",
        "name": "Université Demo Europa",
        "slug": "demo-europa",
        "country": "France",
        "city": "Paris",
        "website_url": "https://demo-europa.example",
        "description": "Université de démonstration pour le projet Academia.",
        "is_active": True,
    },
    {
        "id": "22222222-2222-2222-2222-222222222222",
        "name": "Université Demo Africa",
        "slug": "demo-africa",
        "country": "Côte d'Ivoire",
        "city": "Abidjan",
        "website_url": "https://demo-africa.example",
        "description": "Partenaire académique de démonstration.",
        "is_active": True,
    },
]

PROGRAMS: List[Dict[str, Any]] = [
    {
        "university_id": "11111111-1111-1111-1111-111111111111",
        "title": "Licence Informatique",
        "description": "Parcours informatique général avec spécialisation web.",
        "degree_level": "Licence",
        "mode": "présentiel",
        "duration_months": 36,
        "tuition_fees": 2500,
        "highlighted": True,
        "is_active": True,
    },
    {
        "university_id": "11111111-1111-1111-1111-111111111111",
        "title": "Master Data Science",
        "description": "Master orienté IA et traitement de données.",
        "degree_level": "Master",
        "mode": "hybride",
        "duration_months": 24,
        "tuition_fees": 4500,
        "highlighted": False,
        "is_active": True,
    },
    {
        "university_id": "22222222-2222-2222-2222-222222222222",
        "title": "Licence Gestion",
        "description": "Formation en gestion et administration des entreprises.",
        "degree_level": "Licence",
        "mode": "en ligne",
        "duration_months": 36,
        "tuition_fees": 1800,
        "highlighted": True,
        "is_active": True,
    },
]


def main() -> int:
    # Vérifier s'il y a déjà des universités : si oui, on ne reseed pas.
    check = sup.read("app.universities", limit=1)
    if check.get("success") and check.get("data"):
        print("[INFO] Des universités existent déjà, seed ignoré.")
        return 0

    print("[INFO] Aucune université trouvée, démarrage du seed de données...")

    # Insérer les universités
    for uni in UNIVERSITIES:
        res = sup.insert("app.universities", uni)
        if not res.get("success"):
            print("[ERROR] Échec d'insertion université:", uni.get("slug"))
            print(res)
            return 1
        print("[OK] Université insérée:", uni.get("name"))

    # Insérer les programmes
    for prog in PROGRAMS:
        res = sup.insert("app.programs", prog)
        if not res.get("success"):
            print("[ERROR] Échec d'insertion programme:", prog.get("title"))
            print(res)
            return 1
        print("[OK] Programme inséré:", prog.get("title"))

    print("[SUCCESS] Seed des universités et programmes Academia terminé.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
