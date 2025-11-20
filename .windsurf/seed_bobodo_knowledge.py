#!/usr/bin/env python3
"""Seed de connaissances internes pour Bobodo (app.bobodo_knowledge).

Conformément aux procédures .windsurf, ce script utilise les méthodes
validées d'`auto_supabase_import` (API PostgREST) pour insérer des
entrées de base dans la table `app.bobodo_knowledge`.

- Table ciblée : app.bobodo_knowledge
- Réexécution sûre : si des connaissances existent déjà, le seed est ignoré.
"""

from __future__ import annotations

from typing import Any, Dict, List

import requests

import auto_supabase_import as sup


KNOWLEDGE_ITEMS: List[Dict[str, Any]] = [
    {
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
    },
    {
        "category": "nexiom",
        "title": "Le courtage en formation par Nexiom Group",
        "content": (
            "Dans le cadre du courtage, Nexiom Group fait la promotion des offres de "
            "formation de ses universités, instituts et centres de formation partenaires. "
            "Lorsqu'une personne est intéressée, Nexiom Group recueille ses besoins et "
            "ses contraintes, puis négocie avec la structure de formation concernée afin de "
            "trouver des conditions d'inscription favorables pour le demandeur. "
            "Un accord n'est possible qu'avec des établissements ayant un contrat formel "
            "avec l'entreprise, visibles dans la section 'Universités et structures partenaires' "
            "de la plateforme Academia."
        ),
        "tags": ["nexiom", "courtage", "formation", "partenaires"],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "academia",
        "title": "Rôle de la plateforme Academia",
        "content": (
            "Academia est la plateforme numérique utilisée par Nexiom Group pour organiser "
            "et piloter ses activités liées à la formation. "
            "Elle sert de vitrine pour présenter les offres de formation des partenaires, "
            "permet aux intéressés de postuler et de suivre leur demande, et centralise les "
            "échanges dans le cadre du courtage. "
            "La plateforme est également utilisée pour gérer les inscriptions, la "
            "programmation et la logistique des cours d'appui et des formations organisées "
            "par Nexiom Group."
        ),
        "tags": ["academia", "plateforme", "courtage", "inscription"],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "process",
        "title": "Processus général de courtage via Academia",
        "content": (
            "Une personne intéressée par une formation découvre l'offre et les activités de "
            "Nexiom Group, puis passe par la plateforme Academia pour se manifester. "
            "Elle précise les formations visées et, si nécessaire, certaines attentes ou "
            "contraintes. Nexiom Group analyse la demande, entre en discussion avec la "
            "structure de formation partenaire et négocie les conditions d'inscription. "
            "Lorsque des conditions compatibles sont trouvées, elles sont présentées au "
            "demandeur pour validation. Une fois la proposition validée et l'inscription "
            "effectuée, le rôle de Nexiom Group s'arrête : l'entreprise n'intervient pas dans "
            "le contenu pédagogique ni dans la délivrance du diplôme."
        ),
        "tags": ["processus", "courtage", "academia", "inscription"],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "process",
        "title": "Réductions négociées et absence de bourses d'études",
        "content": (
            "Nexiom Group ne propose pas de bourses d'études. "
            "Le rôle de l'entreprise est de faire du courtage et de négocier des réductions "
            "ou des conditions d'inscription plus favorables avec ses universités et centres "
            "de formation partenaires, au bénéfice des demandeurs. "
            "La notion de bourse ne doit pas être utilisée pour décrire ces avantages : "
            "il s'agit de réductions et d'aménagements obtenus par la négociation, et non "
            "de bourses financées par Nexiom Group."
        ),
        "tags": ["reduction", "pas-de-bourse", "courtage", "conditions"],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "nexiom",
        "title": "Ambition et couverture géographique de Nexiom Group",
        "content": (
            "Nexiom Group se positionne comme pionnier du courtage en formation au Burkina "
            "Faso, avec l'ambition d'étendre progressivement ses services à l'ensemble du "
            "territoire national puis à la sous-région. "
            "L'entreprise souhaite faciliter la mobilité des apprenants en travaillant avec "
            "des formations en présentiel, à distance ou en ligne, pour offrir des parcours "
            "adaptés aux besoins et défis du marché."
        ),
        "tags": ["nexiom", "ambition", "burkina", "sous-region"],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "process",
        "title": "Rôle et limites de Bobodo",
        "content": (
            "Bobodo est un assistant spécialisé sur Nexiom Group, la plateforme Academia, "
            "l'orientation et l'emploi. Il ne remplace pas un conseiller humain et ne doit pas "
            "donner d'avis médicaux, juridiques ou financiers. Pour toute question sensible ou "
            "engageante, il est recommandé de contacter directement l'équipe Nexiom ou les "
            "services officiels."
        ),
        "tags": ["bobodo", "limites", "processus"],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "academia",
        "title": "Cours d'appui organisés via Academia",
        "content": (
            "Nexiom Group propose des cours d'appui pour le niveau supérieur, dans différentes "
            "disciplines et pour plusieurs niveaux. Ces cours peuvent être organisés en individuel "
            "ou en groupe. Toutes les inscriptions et la gestion pratique (choix des sessions, "
            "paiements, suivi) se font via la plateforme Academia, en utilisant les options dédiées "
            "dans l'application."
        ),
        "tags": ["academia", "cours-d-appui", "inscription", "etudiants"],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "academia",
        "title": "Petites formations et ateliers via Academia",
        "content": (
            "En complément du courtage en formation, Nexiom Group organise régulièrement des "
            "petites formations et ateliers (par exemple en décoration, cuisine, préparation aux "
            "concours directs ou professionnels). Comme pour les autres activités, les personnes "
            "intéressées passent par la plateforme Academia pour consulter les offres, s'inscrire et "
            "suivre les informations pratiques."
        ),
        "tags": ["academia", "formations", "ateliers", "concours"],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "academia",
        "title": "Bibliothèque, conseil et orientation sur la plateforme",
        "content": (
            "La plateforme Academia intègre une bibliothèque de ressources ainsi que des services "
            "de conseil et d'orientation. L'utilisateur peut, depuis son espace, accéder aux contenus "
            "disponibles et demander un accompagnement ou un rendez-vous via les options prévues dans "
            "l'application. L'objectif est de permettre aux apprenants de bénéficier d'un appui structuré "
            "pour leurs choix de formation et de parcours."
        ),
        "tags": ["academia", "bibliotheque", "conseil", "orientation"],
        "language": "fr",
        "is_active": True,
    },
]


def call_admin_execute_sql(sql: str) -> bool:
    """Appelle la RPC admin_execute_sql avec une requête SQL arbitraire.

    Utilise la clé service_role validée par .windsurf.
    """
    url = f"{sup.SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"  # type: ignore[attr-defined]
    headers: Dict[str, Any] = {
        "apikey": sup.SUPABASE_SERVICE_KEY,  # type: ignore[attr-defined]
        "Authorization": f"Bearer {sup.SUPABASE_SERVICE_KEY}",  # type: ignore[attr-defined]
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    try:
        resp = requests.post(url, headers=headers, json={"p_sql": sql}, timeout=20)
    except Exception as exc:  # pragma: no cover
        print("[ERROR] Exception admin_execute_sql:", exc)
        return False

    if resp.status_code != 200:
        print("[ERROR] HTTP", resp.status_code, "admin_execute_sql")
        print(resp.text[:400])
        return False

    try:
        data = resp.json()
    except Exception:
        return True

    if isinstance(data, dict) and not data.get("ok", True):
        print("[WARN] admin_execute_sql logical error:")
        print(str(data)[:400])
        return False

    return True


def main() -> int:
    # Vérifier s'il y a déjà des connaissances : si oui, on ne reseed pas.
    check = sup.read("app.bobodo_knowledge", limit=1)
    if check.get("success") and check.get("data"):
        print("[INFO] Des connaissances existent déjà dans app.bobodo_knowledge, seed ignoré.")
        return 0

    print("[INFO] Aucune connaissance interne trouvée, démarrage du seed Bobodo (via admin_execute_sql)...")

    for item in KNOWLEDGE_ITEMS:
        title = str(item["title"])
        category = str(item["category"])
        content = str(item["content"])
        tags = [str(t) for t in item.get("tags", [])]
        language = str(item.get("language", "fr"))
        is_active = bool(item.get("is_active", True))

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

        if not call_admin_execute_sql(sql):
            print("[ERROR] Échec d'insertion connaissance via admin_execute_sql:", title)
            return 1

        print("[OK] Connaissance insérée:", title)

    print("[SUCCESS] Seed des connaissances Bobodo terminé.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
