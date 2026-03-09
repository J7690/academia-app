#!/usr/bin/env python3
"""Insert UMET Burkina programs (Licence + Master) into app.programs.

- Uses admin_execute_sql RPC through SupabaseAutoManager.
- Idempotent: only inserts rows that do not already exist for the same (university_id, degree_level, title).

This mutates the database.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List

import requests

sys.path.insert(0, str(Path(__file__).parent))
from supabase_auto_manager import SupabaseAutoManager

UMET_UNIVERSITY_ID = "07d5722b-d71b-498d-858e-140ff3458931"  # UMET-BURKINA
MODE = "presentiel"
CITY = "Ouagadougou"

LICENCE_PROGRAMS = [
    "Économie et Gestion des Entreprises et des Organisations (EGEO)",
    "Sciences de Gestion (SG)",
    "Comptabilité, contrôle, audit (CCA)",
    "Économie de Développement (ED)",
    "Marketing et Communication (MC)",
    "Logistique Internationale (LI)",
    "Droit privé",
    "Droit public",
]

MASTER_PROGRAMS = [
    "Droit de l’Environnement et du Développement Durable",
    "Droit public et relations internationales",
    "Relations internationales et diplomatie",
    "Droit de l’urbanisme et construction",
    "Médiation-conflit, culture et paix",
    "Droit international humanitaire",
    "Droit des affaires et fiscalité",
    "Gouvernance politique",
    "Administration des affaires / Business Administration",
    "Économie de développement",
    "Contrôle de gestion et audit",
    "Comptabilité, contrôle, audit",
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


def build_insert_sql() -> str:
    def row(degree: str, title: str) -> str:
        description = f"Formation en {MODE} à {CITY}."
        return (
            "SELECT "
            f"'{UMET_UNIVERSITY_ID}'::uuid AS university_id, "
            f"'{esc(title)}'::text AS title, "
            f"'{esc(description)}'::text AS description, "
            f"'{esc(degree)}'::text AS degree_level, "
            f"'{esc(MODE)}'::text AS mode, "
            "NULL::integer AS duration_months, "
            "NULL::numeric AS tuition_fees, "
            "false::boolean AS highlighted, "
            "true::boolean AS is_active"
        )

    selects: List[str] = []
    for t in LICENCE_PROGRAMS:
        selects.append(row("Licence", f"Licence en {t}"))
    for t in MASTER_PROGRAMS:
        selects.append(row("Master", f"Master en {t}"))

    values_cte = "\nUNION ALL\n".join(selects)

    # Insert only missing (university_id, degree_level, title)
    return f"""
    WITH new_rows AS (
      {values_cte}
    )
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
      n.university_id,
      n.title,
      n.description,
      n.degree_level,
      n.mode,
      n.duration_months,
      n.tuition_fees,
      n.highlighted,
      n.is_active
    FROM new_rows n
    WHERE NOT EXISTS (
      SELECT 1
      FROM app.programs p
      WHERE p.university_id = n.university_id
        AND p.degree_level = n.degree_level
        AND p.title = n.title
    );

    SELECT
      COUNT(*)::int AS inserted_count
    FROM app.programs p
    WHERE p.university_id = '{UMET_UNIVERSITY_ID}'::uuid
      AND (p.title ILIKE 'Licence en %' OR p.title ILIKE 'Master en %');
    """.strip()


def main() -> int:
    m = SupabaseAutoManager()

    # Sanity check university exists
    uni = select_rows(
        m,
        f"""
        SELECT id, name, slug
        FROM app.universities
        WHERE id = '{UMET_UNIVERSITY_ID}'::uuid
        """.strip(),
    )
    if not uni:
        raise RuntimeError("UMET university not found by id; aborting")

    print("[INFO] University:")
    print(json.dumps(uni[0], indent=2, ensure_ascii=False))

    before = select_rows(
        m,
        f"""
        SELECT COUNT(*)::int AS cnt
        FROM app.programs
        WHERE university_id = '{UMET_UNIVERSITY_ID}'::uuid
        """.strip(),
    )
    print(f"[INFO] Programs before (total for UMET): {before[0]['cnt'] if before else '??'}")

    sql = build_insert_sql()
    res = exec_sql(m, sql)

    print("[RESULT] admin_execute_sql response summary:")
    print(json.dumps({k: res.get(k) for k in ['ok','mode','row_count','error'] if k in res}, indent=2))

    # Dump last SELECT rows if any
    rows = res.get("rows")
    if isinstance(rows, list):
        print("[RESULT] Rows:")
        print(json.dumps(rows, indent=2, ensure_ascii=False))

    after = select_rows(
        m,
        f"""
        SELECT id, title, degree_level, mode, is_active
        FROM app.programs
        WHERE university_id = '{UMET_UNIVERSITY_ID}'::uuid
          AND (title ILIKE 'Licence en %' OR title ILIKE 'Master en %')
        ORDER BY degree_level, title
        """.strip(),
    )
    print(f"[INFO] Inserted/Existing UMET formations count: {len(after)}")
    for r in after:
        print(f"  - {r['degree_level']}: {r['title']} (mode={r.get('mode')})")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
