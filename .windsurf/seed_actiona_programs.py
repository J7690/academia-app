#!/usr/bin/env python3
"""Seed programmes for existing ACTIONA university.

- Finds ACTIONA university id in app.universities.
- Inserts programs idempotently into app.programs.
- Uses admin_execute_sql (service_role) like other .windsurf scripts.

This mutates the database.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests
from requests.exceptions import RequestException

# Ensure .windsurf is importable when running from repo root
sys.path.insert(0, str(Path(__file__).parent))
from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY  # noqa: E402
from supabase_credentials import get_supabase_auditor  # noqa: E402

ACTIONA_EMAIL = "actiona2024@gmail.com"
ACTIONA_NAME_HINT = "ACTIONA"

# From the provided screenshot
CITY = "Ouagadougou"
COUNTRY = "Burkina Faso"
CONTACT_PHONE = "+226 78 39 33 69 / 76 16 82 97"
TAGLINE = "Académie Commerciale Technologique Industrielle et Orientation Numérique"
UNIVERSITY_DESCRIPTION = "Rejoignez-nous pour différentes formations professionnelles."
MODE = "présentiel"
DEGREE_LEVEL = "Formation professionnelle"
DEFAULT_DESCRIPTION = "Formation professionnelle en présentiel à Ouagadougou."

PROGRAM_TITLES: List[str] = [
    "Secrétariat bureautique",
    "Transit & Déclarant en douane",
    "Tourisme & Hôtellerie",
    "Auxiliaire de pharmacie",
    "Secrétariat médical",
    "Agent de bureau",
    "Infographie",
    "Caissière",
    "Receptionniste",
    "Magasinier",
]

ADMIN_HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}


def _esc(s: str) -> str:
    return s.replace("'", "''")


def admin_exec(sql: str) -> Dict[str, Any]:
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    try:
        resp = requests.post(url, headers=ADMIN_HEADERS, json={"p_sql": sql}, timeout=60)
        if resp.status_code != 200:
            raise RuntimeError(f"admin_execute_sql HTTP {resp.status_code}: {resp.text[:400]}")
        data = resp.json()
        if isinstance(data, dict) and data.get("ok") is True:
            return data
        raise RuntimeError(f"admin_execute_sql failed: {data}")
    except RequestException as exc:
        # Fallback to direct Postgres connection (avoids HTTPS/SSL issues).
        auditor = get_supabase_auditor()
        auditor.initialize()
        res = auditor.execute_sql(sql)
        if not res.get("success"):
            raise RuntimeError(f"Direct Postgres execute_sql failed: {res.get('error')}") from exc
 
        if res.get("type") == "select":
            # Normalize to admin_execute_sql-like shape
            cols = res.get("columns") or []
            out_rows = []
            for row in res.get("rows") or []:
                if isinstance(row, (list, tuple)) and len(cols) == len(row):
                    out_rows.append({str(cols[i]): row[i] for i in range(len(cols))})
                else:
                    out_rows.append({"value": row})
            return {"ok": True, "rows": out_rows, "data": out_rows}
 
        return {"ok": True, "affected_rows": res.get("affected_rows")}


def admin_select(sql: str) -> List[Dict[str, Any]]:
    data = admin_exec(sql)
    rows = data.get("rows")
    return rows if isinstance(rows, list) else []


def find_actiona_university_id() -> str:
    # 1) Prefer exact contact_email match.
    rows = admin_select(
        f"""
        SELECT id, name, slug, contact_email
        FROM app.universities
        WHERE contact_email = '{_esc(ACTIONA_EMAIL)}'
        ORDER BY created_at DESC
        LIMIT 2
        """.strip()
    )
    if rows:
        return str(rows[0]["id"])

    # 2) Fallback by name contains ACTIONA.
    rows2 = admin_select(
        f"""
        SELECT id, name, slug, contact_email
        FROM app.universities
        WHERE name ILIKE '%{_esc(ACTIONA_NAME_HINT)}%'
        ORDER BY created_at DESC
        LIMIT 2
        """.strip()
    )
    if rows2:
        return str(rows2[0]["id"])

    raise RuntimeError(
        "Could not find ACTIONA university in app.universities by contact_email or name. "
        "Please set app.universities.contact_email='actiona2024@gmail.com' or provide the slug to update this script."
    )


def seed_programs(university_id: str) -> int:
    values_sql = ",\n      ".join(
        [
            "(" +
            f"'{_esc(university_id)}'::uuid, "
            f"'{_esc(title)}'::text, "
            f"'{_esc(DEFAULT_DESCRIPTION)}'::text, "
            f"'{_esc(DEGREE_LEVEL)}'::text, "
            f"'{_esc(MODE)}'::text, "
            "NULL::integer, "
            "NULL::numeric, "
            "false::boolean, "
            "true::boolean"
            + ")"
            for title in PROGRAM_TITLES
        ]
    )

    insert_sql = f"""
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
        AND p.title = v.title
    );
    """.strip()

    res = admin_exec(insert_sql)
    affected = res.get("affected_rows")
    return int(affected) if isinstance(affected, int) else 0


def update_university_fields(university_id: str) -> None:
    uid = f"'{_esc(university_id)}'::uuid"
    sql = f"""
    UPDATE app.universities
    SET
      city = CASE
        WHEN city IS NULL OR BTRIM(city) = '' THEN '{_esc(CITY)}'
        ELSE city
      END,
      country = CASE
        WHEN country IS NULL OR BTRIM(country) = '' THEN '{_esc(COUNTRY)}'
        ELSE country
      END,
      contact_phone = CASE
        WHEN contact_phone IS NULL OR BTRIM(contact_phone) = '' THEN '{_esc(CONTACT_PHONE)}'
        ELSE contact_phone
      END,
      tagline = CASE
        WHEN tagline IS NULL OR BTRIM(tagline) = '' THEN '{_esc(TAGLINE)}'
        ELSE tagline
      END,
      description = CASE
        WHEN description IS NULL OR BTRIM(description) = '' THEN '{_esc(UNIVERSITY_DESCRIPTION)}'
        ELSE description
      END,
      updated_at = NOW()
    WHERE id = {uid};
    """.strip()
    admin_exec(sql)


def main() -> int:
    uni_id = find_actiona_university_id()
    print(f"[OK] ACTIONA university_id = {uni_id}")

    update_university_fields(uni_id)

    inserted = seed_programs(uni_id)
    print(f"[OK] Insert affected_rows = {inserted}")

    uni = admin_select(
        f"SELECT id, name, slug, city, contact_email FROM app.universities WHERE id='{_esc(uni_id)}'::uuid"
    )
    cnt = admin_select(
        f"SELECT COUNT(*)::int AS cnt FROM app.programs WHERE university_id='{_esc(uni_id)}'::uuid"
    )
    progs = admin_select(
        f"SELECT title, degree_level, mode, is_active FROM app.programs WHERE university_id='{_esc(uni_id)}'::uuid ORDER BY created_at ASC"
    )

    print("[SUMMARY] University:")
    print(json.dumps(uni[0] if uni else {}, indent=2, ensure_ascii=False))
    print("[SUMMARY] Programs count:")
    print(json.dumps(cnt[0] if cnt else {}, indent=2, ensure_ascii=False))
    print("[SUMMARY] Programs:")
    print(json.dumps(progs, indent=2, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
