#!/usr/bin/env python3
"""Insert UMET Burkina programs (Licence + Master) into app.programs.

- Uses admin_execute_sql RPC through SupabaseAutoManager.
- Idempotent: only inserts rows that do not already exist for the same (university_id, degree_level, title).

Important: admin_execute_sql treats SQL starting with WITH as "select" mode and wraps it.
So we avoid starting statements with WITH for inserts.

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

UMET_UNIVERSITY_ID = "07d5722b-d71b-498d-858e-140ff3458931"  # UMET-BURKINA
MODE = "presentiel"
CITY = "Ouagadougou"

LICENCE_PROGRAMS = [
    "Licence en Économie et Gestion des Entreprises et des Organisations (EGEO)",
    "Licence en Sciences de Gestion (SG)",
    "Licence en Comptabilité, contrôle, audit (CCA)",
    "Licence en Économie de Développement (ED)",
    "Licence en Marketing et Communication (MC)",
    "Licence en Logistique Internationale (LI)",
    "Licence en Droit privé",
    "Licence en Droit public",
]

MASTER_PROGRAMS = [
    "Master en Droit de l’Environnement et du Développement Durable",
    "Master en Droit public et relations internationales",
    "Master en Relations internationales et diplomatie",
    "Master en Droit de l’urbanisme et construction",
    "Master en Médiation-conflit, culture et paix",
    "Master en Droit international humanitaire",
    "Master en Droit des affaires et fiscalité",
    "Master en Gouvernance politique",
    "Master en Administration des affaires / Business Administration",
    "Master en Économie de développement",
    "Master en Contrôle de gestion et audit",
    "Master en Comptabilité, contrôle, audit",
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


def build_values_rows() -> List[Tuple[str, str]]:
    rows: List[Tuple[str, str]] = []
    for t in LICENCE_PROGRAMS:
        rows.append(("Licence", t))
    for t in MASTER_PROGRAMS:
        rows.append(("Master", t))
    return rows


def build_insert_sql() -> str:
    # Use INSERT ... SELECT ... FROM (VALUES ...) so statement begins with INSERT (exec mode)
    rows = build_values_rows()
    values_sql = ",\n      ".join(
        [
            "("
            + f"'{UMET_UNIVERSITY_ID}'::uuid, "
            + f"'{esc(title)}'::text, "
            + f"'{esc('Formation en ' + MODE + ' à ' + CITY + '.')}'::text, "
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

    insert_sql = build_insert_sql()
    res = exec_sql(m, insert_sql)
    print("[RESULT] Insert exec:")
    print(json.dumps({k: res.get(k) for k in ['ok','mode','affected_rows','error'] if k in res}, indent=2))

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
    print(f"[INFO] UMET formations now: {len(after)}")
    for r in after:
        print(f"  - {r['degree_level']}: {r['title']} (mode={r.get('mode')})")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
