#!/usr/bin/env python3
"""Insert ISTAPEM (Licence) programs into app.programs.

- Uses admin_execute_sql via SupabaseAutoManager.
- Idempotent on (university_id, degree_level, title).

This mutates the database.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager

ISTAPEM_UNIVERSITY_SLUG = "istapem"
MODE = "presentiel"
CITY = "Ouagadougou"

LICENCE_PROGRAMS = [
    "Licence en Finance et Comptabilité",
    "Licence en Banque et Assurances",
    "Licence en Supply Chain Management (Transport Logistique)",
    "Licence en Banque Microfinance",
    "Licence en Marketing et Gestion Commerciale",
    "Licence en Communication d'Entreprise",
    "Licence en Gestion des Ressources Humaines",
]


def exec_sql(manager: SupabaseAutoManager, sql: str) -> Dict[str, Any]:
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    r = requests.post(url, headers=manager.headers, json={"p_sql": sql}, timeout=60)
    r.raise_for_status()
    data = r.json()
    if not isinstance(data, dict) or data.get("ok") is not True:
        raise RuntimeError(f"admin_execute_sql failed: {data}")
    return data


def select_rows(manager: SupabaseAutoManager, sql: str) -> List[Dict[str, Any]]:
    data = exec_sql(manager, sql)
    rows = data.get("rows")
    return rows if isinstance(rows, list) else []


def esc(s: str) -> str:
    return s.replace("'", "''")


def build_insert_sql(university_id: str) -> str:
    description = f"Cours dispensés en {MODE} à {CITY}."

    rows: List[Tuple[str, str]] = [("Licence", t) for t in LICENCE_PROGRAMS]

    values_sql = ",\n      ".join(
        [
            "("
            + f"'{university_id}'::uuid, "
            + f"'{esc(title)}'::text, "
            + f"'{esc(description)}'::text, "
            + f"'{esc(degree)}'::text, "
            + f"'{esc(MODE)}'::text, "
            + "NULL::integer, "
            + "NULL::numeric, "
            + "false::boolean, "
            + "true::boolean"
            + ")"
            for (degree, title) in rows
        ]
    )

    return f"""
    INSERT INTO app.programs (
      university_id,
      title,
      description,
      degree_level,
      mode,
      duration_months,
      tuition_fees,
      highlighted,
      is_active
    )
    SELECT
      v.university_id,
      v.title,
      v.description,
      v.degree_level,
      v.mode,
      v.duration_months,
      v.tuition_fees,
      v.highlighted,
      v.is_active
    FROM (
      VALUES
      {values_sql}
    ) AS v(
      university_id,
      title,
      description,
      degree_level,
      mode,
      duration_months,
      tuition_fees,
      highlighted,
      is_active
    )
    WHERE NOT EXISTS (
      SELECT 1
      FROM app.programs p
      WHERE p.university_id = v.university_id
        AND p.degree_level = v.degree_level
        AND p.title = v.title
    );
    """.strip()


def main() -> int:
    m = SupabaseAutoManager()

    uni = select_rows(
        m,
        f"""
        SELECT id, name, slug
        FROM app.universities
        WHERE slug = '{ISTAPEM_UNIVERSITY_SLUG}'
        LIMIT 1
        """.strip(),
    )
    if not uni:
        raise RuntimeError("ISTAPEM university not found by slug; aborting")

    university_id = uni[0]["id"]

    print("[INFO] University:")
    print(json.dumps(uni[0], indent=2, ensure_ascii=False))

    before = select_rows(
        m,
        f"""
        SELECT COUNT(*)::int AS cnt
        FROM app.programs
        WHERE university_id = '{university_id}'::uuid
          AND title ILIKE 'Licence en %'
        """.strip(),
    )
    print(f"[INFO] Licence programs before: {before[0]['cnt'] if before else '??'}")

    insert_sql = build_insert_sql(university_id)
    res = exec_sql(m, insert_sql)
    print("[RESULT] Insert exec:")
    print(json.dumps({k: res.get(k) for k in ['ok','mode','affected_rows','error'] if k in res}, indent=2))

    after = select_rows(
        m,
        f"""
        SELECT id, title, degree_level, mode, is_active
        FROM app.programs
        WHERE university_id = '{university_id}'::uuid
          AND title ILIKE 'Licence en %'
        ORDER BY title
        """.strip(),
    )
    print(f"[INFO] Licence programs now: {len(after)}")
    for r in after:
        print(f"  - {r['title']} (mode={r.get('mode')})")

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
