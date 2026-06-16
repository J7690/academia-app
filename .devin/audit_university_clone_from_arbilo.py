#!/usr/bin/env python3
"""Audit du clonage de mini-site & offres depuis Arbilo vers une nouvelle université.

- Vérifie que public.app_admin_clone_university_from_template existe.
- Compare les volumes de contenu (blocks, media, banners, events, news, staff,
  programs, courses) entre Arbilo (slug template) et une université cible.

Utilisation :
  python .windsurf/audit_university_clone_from_arbilo.py <TARGET_UNIVERSITY_ID>

La connexion se fait via SupabaseAutoManager (service_role + execute_sql).
"""

from __future__ import annotations

import json
import sys
from typing import Any, Dict

from supabase_auto_manager import SupabaseAutoManager


TEMPLATE_SLUG = "universite-arbilo"


def _exec_sql_json(m: SupabaseAutoManager, sql: str) -> Any:
    """Utilitaire léger pour exécuter une requête SQL via execute_sql et renvoyer le JSON.

    On s'appuie sur SupabaseAutoManager.execute_sql_auto qui appelle la RPC execute_sql.
    """

    result = m.execute_sql_auto(sql)
    if not result.get("success"):
        raise RuntimeError(f"SQL failed: {result.get('error')!r} for {sql!r}")
    data = result.get("data")
    if not data:
        return []
    # execute_sql renvoie déjà un tableau JSON ; on renvoie tel quel.
    return data


def _count_for_university(m: SupabaseAutoManager, university_id: str) -> Dict[str, int]:
    """Retourne les compteurs de contenu mini-site & offres pour une université donnée."""

    sql = f"""
    SELECT
      (SELECT COUNT(*) FROM app.university_site_blocks      b WHERE b.university_id = '{university_id}') AS blocks,
      (SELECT COUNT(*) FROM app.university_media            m WHERE m.university_id = '{university_id}') AS media,
      (SELECT COUNT(*) FROM app.university_site_banners     ban WHERE ban.university_id = '{university_id}') AS banners,
      (SELECT COUNT(*) FROM app.university_events           e WHERE e.university_id = '{university_id}') AS events,
      (SELECT COUNT(*) FROM app.university_news             n WHERE n.university_id = '{university_id}') AS news,
      (SELECT COUNT(*) FROM app.university_staff            s WHERE s.university_id = '{university_id}') AS staff,
      (SELECT COUNT(*) FROM app.programs                    p WHERE p.university_id = '{university_id}') AS programs,
      (SELECT COUNT(*) FROM app.courses                     c JOIN app.programs p2 ON p2.id = c.program_id AND p2.university_id = '{university_id}') AS courses
    ;
    """

    rows = _exec_sql_json(m, sql)
    if not rows:
        raise RuntimeError("No row returned for university counters")
    raw = rows[0]
    return {k: int(raw.get(k, 0)) for k in (
        "blocks",
        "media",
        "banners",
        "events",
        "news",
        "staff",
        "programs",
        "courses",
    )}


def _get_university_id_by_slug(m: SupabaseAutoManager, slug: str) -> str:
    sql = f"""
    SELECT id
    FROM app.universities
    WHERE slug = '{slug}'
    LIMIT 1;
    """
    rows = _exec_sql_json(m, sql)
    if not rows:
        raise RuntimeError(f"No university found for slug={slug!r}")
    return str(rows[0]["id"])


def _check_clone_function_exists(m: SupabaseAutoManager) -> None:
    sql = """
    SELECT 1 AS ok
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'app_admin_clone_university_from_template';
    """
    rows = _exec_sql_json(m, sql)
    if not rows:
        raise RuntimeError("La fonction public.app_admin_clone_university_from_template n'existe pas dans cette base.")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("Usage: python .windsurf/audit_university_clone_from_arbilo.py <TARGET_UNIVERSITY_ID>")
        return 1

    target_university_id = argv[1]

    m = SupabaseAutoManager()

    print("Vérification de l'existence de la fonction de clonage...")
    _check_clone_function_exists(m)
    print("OK: app_admin_clone_university_from_template est présente.\n")

    print(f"Récupération de l'université modèle pour le slug {TEMPLATE_SLUG!r}...")
    template_id = _get_university_id_by_slug(m, TEMPLATE_SLUG)
    print(f"Template Arbilo id = {template_id}")

    print("\nCompteurs de contenu pour Arbilo (template):")
    template_counts = _count_for_university(m, template_id)
    print(json.dumps(template_counts, indent=2, ensure_ascii=False))

    print("\nCompteurs de contenu pour l'université cible:")
    target_counts = _count_for_university(m, target_university_id)
    print(json.dumps(target_counts, indent=2, ensure_ascii=False))

    deltas: Dict[str, int] = {}
    for key in template_counts.keys():
        deltas[key] = template_counts[key] - target_counts.get(key, 0)

    print("\nDelta (template - cible):")
    print(json.dumps(deltas, indent=2, ensure_ascii=False))

    print("\nInterprétation rapide:")
    missing_any = False
    for key, delta in deltas.items():
        if delta > 0:
            missing_any = True
            print(f"- {key}: la cible a {target_counts.get(key, 0)} élément(s), Arbilo en a {template_counts[key]} → il manque potentiellement {delta} élément(s).")
    if not missing_any:
        print("Tous les compteurs sont >= à ceux de la cible ; le clonage semble complet au niveau des volumes.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
