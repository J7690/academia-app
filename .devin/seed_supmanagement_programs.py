#!/usr/bin/env python3
"""Seed programmes for Sup' Management Burkina.

Source (public website):
- https://supmanagement.bf/formation.html

Behavior:
- Finds existing university row in app.universities by contact_email or slug/name.
- Updates basic fields idempotently (only fills if empty).
- Inserts programs idempotently into app.programs.

This mutates the database.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

import requests
from requests.exceptions import RequestException

# Ensure .windsurf is importable when running from repo root
sys.path.insert(0, str(Path(__file__).parent))
from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY  # noqa: E402
from supabase_credentials import get_supabase_auditor  # noqa: E402

SUPMGT_EMAIL = "supmgtburkina@supmanagement.bf"
NAME_HINT = "Sup"
SLUG_HINTS = ["supmanagement", "sup-management", "sup-management-burkina", "supmgt"]

CITY = "Ouagadougou"
COUNTRY = "Burkina Faso"
ADDRESS = "Sup' Management 01 BP 1964 Ouagadougou 01"
CONTACT_PHONE = "+226 78 30 05 21 / 76 15 92 78"
WEBSITE = "https://supmanagement.bf/"
TAGLINE = "Institut privé d'enseignement supérieur"
DESCRIPTION = (
    "Sup' Management Burkina, créé en 2008, membre du groupe Sup'Management basé au Maroc."
)

MODE = "présentiel"
DEFAULT_DESCRIPTION_LICENCE = "Cycle professionnalisé (BAC+3) en présentiel à Ouagadougou."
DEFAULT_DESCRIPTION_MASTER = "Cycle supérieur approfondi (BAC+5) en présentiel à Ouagadougou."

# Extracted from https://supmanagement.bf/formation.html
PROGRAMS: List[Tuple[str, str, str]] = [
    # --- Management (BAC+3)
    ("Finance Management", "Licence", DEFAULT_DESCRIPTION_LICENCE),
    ("Gestion de Projets", "Licence", DEFAULT_DESCRIPTION_LICENCE),
    ("Marketing - Communication", "Licence", DEFAULT_DESCRIPTION_LICENCE),
    ("Banque Microfinance", "Licence", DEFAULT_DESCRIPTION_LICENCE),
    ("Transport et Logistique", "Licence", DEFAULT_DESCRIPTION_LICENCE),
    ("Management des Ressources Humaines", "Licence", DEFAULT_DESCRIPTION_LICENCE),
    # --- Management (BAC+5)
    ("Banque et Microfinance", "Master", DEFAULT_DESCRIPTION_MASTER),
    ("Ingenierie Financière", "Master", DEFAULT_DESCRIPTION_MASTER),
    ("Ingenierie Commerciale, Marketing et Distribution", "Master", DEFAULT_DESCRIPTION_MASTER),
    ("Management des projets", "Master", DEFAULT_DESCRIPTION_MASTER),
    ("Ingenierie en Management des opérations et de la logistique", "Master", DEFAULT_DESCRIPTION_MASTER),
    ("Management de la Communication des Entreprises et des Institutions", "Master", DEFAULT_DESCRIPTION_MASTER),
    # --- Engineering (BAC+3)
    ("Ingenierie des Systèmes et Reseaux", "Licence", DEFAULT_DESCRIPTION_LICENCE),
    ("Ingenierie des Systèmes d'Information", "Licence", DEFAULT_DESCRIPTION_LICENCE),
    # --- Engineering (BAC+5)
    (
        "Ingenierie des Systèmes, Reseaux, Sécurité et Télécoms",
        "Master",
        DEFAULT_DESCRIPTION_MASTER,
    ),
    ("Ingenierie des Systèmes d'Information", "Master", DEFAULT_DESCRIPTION_MASTER),
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
        auditor = get_supabase_auditor()
        auditor.initialize()
        res = auditor.execute_sql(sql)
        if not res.get("success"):
            raise RuntimeError(f"Direct Postgres execute_sql failed: {res.get('error')}") from exc

        if res.get("type") == "select":
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


def find_university_id() -> str:
    rows = admin_select(
        f"""
        SELECT id, name, slug, contact_email
        FROM app.universities
        WHERE contact_email = '{_esc(SUPMGT_EMAIL)}'
        ORDER BY created_at DESC
        LIMIT 2
        """.strip()
    )
    if rows:
        return str(rows[0]["id"])

    for slug in SLUG_HINTS:
        rows_slug = admin_select(
            f"""
            SELECT id, name, slug
            FROM app.universities
            WHERE slug = '{_esc(slug)}'
            ORDER BY created_at DESC
            LIMIT 2
            """.strip()
        )
        if rows_slug:
            return str(rows_slug[0]["id"])

    rows_name = admin_select(
        f"""
        SELECT id, name, slug
        FROM app.universities
        WHERE name ILIKE '%{_esc(NAME_HINT)}%'
        ORDER BY created_at DESC
        LIMIT 10
        """.strip()
    )
    if len(rows_name) == 1:
        return str(rows_name[0]["id"])

    raise RuntimeError(
        "Sup'Management university not found in app.universities. "
        "Create it first (auth user + app.universities row) then re-run this script."
    )


def update_university_fields(university_id: str) -> None:
    uid = f"'{_esc(university_id)}'::uuid"
    sql = f"""
    UPDATE app.universities
    SET
      city = CASE WHEN city IS NULL OR BTRIM(city) = '' THEN '{_esc(CITY)}' ELSE city END,
      country = CASE WHEN country IS NULL OR BTRIM(country) = '' THEN '{_esc(COUNTRY)}' ELSE country END,
      address = CASE WHEN address IS NULL OR BTRIM(address) = '' THEN '{_esc(ADDRESS)}' ELSE address END,
      contact_email = CASE WHEN contact_email IS NULL OR BTRIM(contact_email) = '' THEN '{_esc(SUPMGT_EMAIL)}' ELSE contact_email END,
      contact_phone = CASE WHEN contact_phone IS NULL OR BTRIM(contact_phone) = '' THEN '{_esc(CONTACT_PHONE)}' ELSE contact_phone END,
      website_url = CASE WHEN website_url IS NULL OR BTRIM(website_url) = '' THEN '{_esc(WEBSITE)}' ELSE website_url END,
      tagline = CASE WHEN tagline IS NULL OR BTRIM(tagline) = '' THEN '{_esc(TAGLINE)}' ELSE tagline END,
      description = CASE WHEN description IS NULL OR BTRIM(description) = '' THEN '{_esc(DESCRIPTION)}' ELSE description END,
      updated_at = NOW()
    WHERE id = {uid};
    """.strip()
    admin_exec(sql)


def seed_programs(university_id: str) -> int:
    values_sql = ",\n      ".join(
        [
            "(" +
            f"'{_esc(university_id)}'::uuid, "
            f"'{_esc(title)}'::text, "
            f"'{_esc(desc)}'::text, "
            f"'{_esc(degree)}'::text, "
            f"'{_esc(MODE)}'::text, "
            "NULL::integer, "
            "NULL::numeric, "
            "false::boolean, "
            "true::boolean"
            + ")"
            for (title, degree, desc) in PROGRAMS
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
        AND p.degree_level = v.degree_level
        AND p.title = v.title
    );
    """.strip()

    res = admin_exec(insert_sql)
    affected = res.get("affected_rows")
    return int(affected) if isinstance(affected, int) else 0


def main() -> int:
    uni_id = find_university_id()
    print(f"[OK] Sup' Management university_id = {uni_id}")

    update_university_fields(uni_id)

    inserted = seed_programs(uni_id)
    print(f"[OK] Insert affected_rows = {inserted}")

    uni = admin_select(
        "\n".join(
            [
                "SELECT id, name, slug, city, country, contact_email, contact_phone, website_url",
                "FROM app.universities",
                f"WHERE id='{_esc(uni_id)}'::uuid",
            ]
        )
    )
    cnt = admin_select(
        f"SELECT COUNT(*)::int AS cnt FROM app.programs WHERE university_id='{_esc(uni_id)}'::uuid"
    )

    print("[SUMMARY] University:")
    print(json.dumps(uni[0] if uni else {}, indent=2, ensure_ascii=False))
    print("[SUMMARY] Programs count:")
    print(json.dumps(cnt[0] if cnt else {}, indent=2, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
