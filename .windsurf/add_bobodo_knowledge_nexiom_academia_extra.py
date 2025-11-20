#!/usr/bin/env python3
"""Ajout incrémental de connaissances internes Nexiom/Academia pour Bobodo.

Ce script respecte les procédures .windsurf :
- lecture via auto_supabase_import.read sur app.bobodo_knowledge
- insertion via la RPC admin_execute_sql (service_role), comme seed_bobodo_knowledge.py

Objectif : enrichir la base locale avec des fiches supplémentaires
strictement liées à Nexiom Group et à la plateforme Academia.
"""

from __future__ import annotations

from typing import Any, Dict, List

import auto_supabase_import as sup
import seed_bobodo_knowledge as seed


EXTRA_ITEMS: List[Dict[str, Any]] = [
    {
        "category": "nexiom",
        "title": "Offre de formation propre à Nexiom Group",
        "content": (
            "En plus de son rôle de courtier, Nexiom Group conçoit et met en "+
            "oeuvre ses propres activités de formation avec ses ressources internes. "
            "L'entreprise organise notamment des préparations aux concours directs "
            "de la fonction publique burkinabè, des préparations aux concours "
            "professionnels, des cours d'appui pour le supérieur et pour le "
            "secondaire, ainsi que des actions de sensibilisation et d'autres "
            "formations ponctuelles. "
            "Ces activités restent des prestations de formation et d'accompagnement "
            "proposées par une entreprise légalement constituée, et ne doivent pas "
            "être confondues avec des bourses d'études."
        ),
        "tags": [
            "nexiom",
            "formation",
            "concours",
            "cours-d-appui",
            "sensibilisation",
        ],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "nexiom",
        "title": "Formations et accompagnement sur les marchés publics",
        "content": (
            "Nexiom Group peut proposer des formations et un accompagnement "
            "spécifiques liés aux marchés publics et aux appels d'offres. "
            "Sur demande, l'entreprise peut aider des particuliers ou des "
            "organisations à comprendre les procédures de passation de marché, "
            "à préparer des dossiers d'appel d'offres et à structurer leurs "
            "candidatures, en collaboration avec ses partenaires."
        ),
        "tags": [
            "nexiom",
            "formation",
            "marches-publics",
            "appels-d-offres",
        ],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "nexiom",
        "title": "Formations non diplômantes et certifiantes sur demande",
        "content": (
            "En dehors des formations diplômantes, Nexiom Group peut organiser ou co-organiser "
            "des formations qui aboutissent à une attestation, à un certificat ou simplement "
            "à l'acquisition de compétences (préparation à un concours ou à un examen, "
            "formations pratiques, etc.). "
            "Suite aux demandes des utilisateurs exprimées via la plateforme Academia ou les "
            "autres canaux de communication du groupe, Nexiom Group peut proposer ces "
            "formations en interne ou, pour les formations certifiantes, en collaboration "
            "avec des structures partenaires, car l'entreprise ne délivre pas elle-même de "
            "certifications officielles. "
            "Si une personne a un compte normalement constitué et souhaite une formation qui "
            "n'apparaît pas dans la liste des offres actuelles, elle peut écrire à "
            "l'administrateur de la plateforme. L'administrateur étudiera la demande et, si "
            "la formation est non diplômante, cherchera une solution adaptée en indiquant les "
            "modalités et conditions."
        ),
        "tags": [
            "nexiom",
            "formation",
            "non-diplomante",
            "certificat",
            "demande",
        ],
        "language": "fr",
        "is_active": True,
    },
]


def main() -> int:
    # Lire les connaissances existantes pour éviter les doublons de titre
    existing = sup.read("app.bobodo_knowledge", limit=500)
    existing_titles = set()
    if existing.get("success") and isinstance(existing.get("data"), list):
        for row in existing["data"]:
            title = str(row.get("title") or "").strip()
            if title:
                existing_titles.add(title)

    if not existing.get("success"):
        print("[WARN] Lecture app.bobodo_knowledge échouée (méthode API), poursuite quand même.")

    for item in EXTRA_ITEMS:
        title = str(item["title"])
        category = str(item["category"])
        content = str(item["content"])
        tags = [str(t) for t in item.get("tags", [])]
        language = str(item.get("language", "fr"))
        is_active = bool(item.get("is_active", True))

        if title in existing_titles:
            print("[SKIP] Connaissance déjà présente, ignorée:", title)
            continue

        # Échapper les quotes simples pour le SQL
        def esc(value: str) -> str:
            return value.replace("'", "''")

        tags_sql = ", ".join(f"'{esc(t)}'" for t in tags)
        sql = f"""
INSERT INTO app.bobodo_knowledge (category, title, content, tags, language, is_active)
VALUES (
  '{esc(category)}',
  '{esc(title)}',
  '{esc(content)}',
  ARRAY[{tags_sql}],
  '{esc(language)}',
  {'TRUE' if is_active else 'FALSE'}
);
""".strip()

        if not seed.call_admin_execute_sql(sql):
            print("[ERROR] Échec d'insertion connaissance via admin_execute_sql:", title)
            return 1

        print("[OK] Connaissance insérée:", title)

    print("[SUCCESS] Ajout des connaissances Nexiom/Academia terminé.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
