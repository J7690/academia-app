#!/usr/bin/env python3
"""Create COSERFA university account + seed formations into app.programs.

- Creates (or finds) Supabase Auth user for COSERFA via Admin API.
- Uses user_id as app.universities.id (same pattern as seed_and_link_university_arbilo.py)
  to keep university dashboard mapping simple.
- Seeds professional formations into app.programs idempotently.

Security:
- Password is read from env var COSERFA_PASSWORD or via interactive prompt.
- Script never prints the password.

This mutates the database.
"""

from __future__ import annotations

import os
import sys
import json
import getpass
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests

# Use same constants as other .windsurf scripts
sys.path.insert(0, str(Path(__file__).parent))
from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY

COSERFA_EMAIL = "coserfaburkina@gmail.com"
COSERFA_SLUG = "coserfa"
COSERFA_NAME = "COSERFA"
COSERFA_WEBSITE = "https://coserfa.bf"
COSERFA_COUNTRY = "Burkina Faso"
COSERFA_CITY = "Ouagadougou / Bobo-Dioulasso"

MODE = "presentiel"
DEFAULT_DESCRIPTION = "Cours dispensés en presentiel à Ouagadougou et Bobo-Dioulasso. Durée: 6 à 12 mois."
DEFAULT_DEGREE_LEVEL = "Formation professionnelle"

# Filieres (from provided captures)
FORMATIONS: List[str] = [
    "Marketing",
    "Électricité",
    "Énergie solaire",
    "Délégué médical",
    "Transit douane",
    "Montage audio vidéo",
    "Comptabilité orientée",
    "Auxiliaire en pharmacie",
    "Conduite d'engins lourds",
    "Mécanique d'engins lourds",
    "Préparation au concours",
    "Caissier(e) / Gestionnaire de stock",
    "Décoration et l’événementiel",
    "Maintenance informatique",
    "Gestionnaire des hôpitaux",
    "Secrétaire comptable",
    "Secrétaire médicale",
    "Mines et carrières",
    "Dessin d'architecture",
    "Préparation au BEPC",
    "Préparation au BAC",
    "Pâtisserie",
    "Élevage",
    "Production agricole",
]

ADMIN_HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
}


def esc(s: str) -> str:
    return s.replace("'", "''")


# ---------- Auth Admin helpers ----------

def find_user_by_email(email: str) -> Optional[Dict[str, Any]]:
    url = f"{SUPABASE_URL}/auth/v1/admin/users"
    resp = requests.get(url, headers=ADMIN_HEADERS, params={"email": email}, timeout=20)
    if resp.status_code != 200:
        raise RuntimeError(f"find_user_by_email HTTP {resp.status_code}: {resp.text[:400]}")
    data = resp.json()

    if isinstance(data, list):
        for u in data:
            if isinstance(u, dict) and u.get("email") == email:
                return u
        return data[0] if data else None

    if isinstance(data, dict):
        users = data.get("users")
        if isinstance(users, list):
            for u in users:
                if isinstance(u, dict) and u.get("email") == email:
                    return u
            return users[0] if users else None

    return data if isinstance(data, dict) else None


def create_user(email: str, password: str) -> Dict[str, Any]:
    url = f"{SUPABASE_URL}/auth/v1/admin/users"
    payload = {
        "email": email,
        "password": password,
        "email_confirm": True,
        "user_metadata": {"role": "university"},
    }
    resp = requests.post(url, headers=ADMIN_HEADERS, json=payload, timeout=30)

    # Some Supabase deployments return 200 with the created user JSON.
    if resp.status_code in (200, 201):
        return resp.json()

    # If already exists, Supabase returns 422
    if resp.status_code == 422:
        existing = find_user_by_email(email)
        if not existing:
            raise RuntimeError("User already exists but could not be retrieved")
        return existing

    raise RuntimeError(f"create_user HTTP {resp.status_code}: {resp.text[:400]}")


def update_user_metadata(user_id: str, meta: Dict[str, Any]) -> None:
    url = f"{SUPABASE_URL}/auth/v1/admin/users/{user_id}"
    payload = {"user_metadata": meta}

    # Supabase Auth admin update method varies by deployment (PATCH vs PUT).
    resp = requests.patch(url, headers=ADMIN_HEADERS, json=payload, timeout=20)
    if resp.status_code in (200, 201, 204):
        return

    if resp.status_code == 405:
        resp2 = requests.put(url, headers=ADMIN_HEADERS, json=payload, timeout=20)
        if resp2.status_code in (200, 201, 204):
            return

        # Fallback: update raw metadata via SQL
        meta_json_escaped = json.dumps(meta, ensure_ascii=False).replace("'", "''")
        sql = (
            "UPDATE auth.users\n"
            "SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || "
            f"'{meta_json_escaped}'::jsonb\n"
            f"WHERE id = '{user_id}'::uuid;"
        )
        admin_exec(sql)
        return

    raise RuntimeError(f"update_user_metadata HTTP {resp.status_code}: {resp.text[:400]}")


# ---------- admin_execute_sql helpers ----------

def admin_exec(sql: str) -> Dict[str, Any]:
    url = f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=ADMIN_HEADERS, json={"p_sql": sql}, timeout=60)
    if resp.status_code != 200:
        raise RuntimeError(f"admin_execute_sql HTTP {resp.status_code}: {resp.text[:400]}")
    data = resp.json()
    if isinstance(data, dict) and data.get("ok") is True:
        return data
    raise RuntimeError(f"admin_execute_sql failed: {data}")


def admin_select(sql: str) -> List[Dict[str, Any]]:
    data = admin_exec(sql)
    rows = data.get("rows")
    return rows if isinstance(rows, list) else []


def seed_university(user_id: str) -> None:
    uid = f"'{user_id}'::uuid"

    # Safety: slug is unique. If a different university already owns slug=coserfa,
    # abort to avoid violating unique constraint or silently creating a mismatch.
    existing = admin_select(
        f"""
        SELECT id, name, slug
        FROM app.universities
        WHERE slug = '{esc(COSERFA_SLUG)}'
        LIMIT 2
        """.strip()
    )
    if existing:
        existing_id = existing[0].get("id")
        if existing_id and str(existing_id) != str(user_id):
            raise RuntimeError(
                "University slug conflict: app.universities already contains slug='coserfa' "
                f"with id={existing_id}. Please remove/rename that row before seeding COSERFA."
            )

    sql = f"""
    INSERT INTO app.universities (
      id, name, slug, country, city, website_url, description, contact_email, is_active
    )
    VALUES (
      {uid},
      '{esc(COSERFA_NAME)}',
      '{esc(COSERFA_SLUG)}',
      '{esc(COSERFA_COUNTRY)}',
      '{esc(COSERFA_CITY)}',
      '{esc(COSERFA_WEBSITE)}',
      'Centre de formation professionnelle (courte durée).',
      '{esc(COSERFA_EMAIL)}',
      TRUE
    )
    ON CONFLICT (id) DO UPDATE
      SET name = EXCLUDED.name,
          slug = EXCLUDED.slug,
          country = EXCLUDED.country,
          city = EXCLUDED.city,
          website_url = EXCLUDED.website_url,
          description = EXCLUDED.description,
          contact_email = EXCLUDED.contact_email,
          is_active = EXCLUDED.is_active;
    """.strip()
    admin_exec(sql)


def seed_formations(user_id: str) -> int:
    # Avoid starting SQL with WITH (admin_execute_sql will treat it as select mode).
    values_sql = ",\n      ".join(
        [
            "("
            + f"'{user_id}'::uuid, "
            + f"'{esc('Formation: ' + title)}'::text, "
            + f"'{esc(DEFAULT_DESCRIPTION)}'::text, "
            + f"'{esc(DEFAULT_DEGREE_LEVEL)}'::text, "
            + f"'{esc(MODE)}'::text, "
            + "NULL::integer, "
            + "NULL::numeric, "
            + "false::boolean, "
            + "true::boolean"
            + ")"
            for title in FORMATIONS
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
    password = os.environ.get("COSERFA_PASSWORD")
    if not password:
        password = getpass.getpass("COSERFA password (input hidden): ")
        password2 = getpass.getpass("Confirm COSERFA password (input hidden): ")
        if password != password2:
            raise RuntimeError("Passwords do not match. Please re-run and type the same password twice.")

    print("[STEP] Create/find auth user")
    user = create_user(COSERFA_EMAIL, password)
    user_id = user.get("id")
    if not user_id:
        raise RuntimeError("Auth user has no id")

    print(f"[OK] auth user_id = {user_id}")

    print("[STEP] Seed university (id=user_id)")
    seed_university(user_id)

    # Link metadata
    meta = user.get("user_metadata") or user.get("user_meta_data") or {}
    if not isinstance(meta, dict):
        meta = {}
    meta["role"] = "university"
    meta["university_id"] = user_id

    print("[STEP] Update user_metadata role/university_id")
    update_user_metadata(user_id, meta)

    print("[STEP] Seed formations")
    inserted = seed_formations(user_id)
    print(f"[OK] Insert affected_rows = {inserted}")

    # Summary
    uni = admin_select(f"SELECT id, name, slug, city, contact_email FROM app.universities WHERE id='{user_id}'::uuid")
    cnt = admin_select(f"SELECT COUNT(*)::int AS cnt FROM app.programs WHERE university_id='{user_id}'::uuid")
    print("[SUMMARY] University:")
    print(json.dumps(uni[0] if uni else {}, indent=2, ensure_ascii=False))
    print("[SUMMARY] Programs count:")
    print(json.dumps(cnt[0] if cnt else {}, indent=2, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
