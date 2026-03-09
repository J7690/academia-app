#!/usr/bin/env python3
"""Backfill university_site_config via PostgREST direct (pas execute_sql_auto)."""

import sys, json, requests
sys.path.insert(0, str(__import__('pathlib').Path(__file__).parent))

from supabase_auto_manager import SupabaseAutoManager


def main():
    m = SupabaseAutoManager()

    # Step 1: Get universities without config
    find_sql = (
        "SELECT u.id, u.name, u.slug "
        "FROM app.universities u "
        "WHERE NOT EXISTS ("
        "  SELECT 1 FROM app.university_site_config c WHERE c.university_id = u.id"
        ") ORDER BY u.name"
    )
    resp = requests.post(
        f"{m.url}/rest/v1/rpc/execute_sql",
        headers=m.headers,
        json={"sql_query": find_sql},
        timeout=30,
    )
    if resp.status_code != 200:
        print(f"Erreur SELECT: {resp.status_code} {resp.text}")
        return

    universities = resp.json()
    if not isinstance(universities, list) or len(universities) == 0:
        print("Toutes les universites ont deja une config.")
        return

    print(f"{len(universities)} universites sans config:")
    for u in universities:
        print(f"  - {u['name']} ({u['slug']})")

    # Step 2: Insert via PostgREST table endpoint (schema app)
    headers_app = dict(m.headers)
    headers_app["Accept-Profile"] = "app"
    headers_app["Content-Profile"] = "app"
    headers_app["Prefer"] = "return=minimal"

    success = 0
    for u in universities:
        uid = u["id"]
        name = u["name"]
        payload = {
            "university_id": uid,
            "hero_title": name,
            "hero_subtitle": "Decouvrez notre universite",
        }
        r = requests.post(
            f"{m.url}/rest/v1/university_site_config",
            headers=headers_app,
            json=payload,
            timeout=15,
        )
        if r.status_code in (200, 201, 204):
            success += 1
            print(f"  OK {name}")
        else:
            print(f"  ERREUR {name}: {r.status_code} {r.text[:200]}")

    print(f"\nResultat: {success}/{len(universities)} configs creees.")

    # Step 3: Verify
    verify_sql = (
        "SELECT u.name, c.hero_title "
        "FROM app.universities u "
        "JOIN app.university_site_config c ON c.university_id = u.id "
        "WHERE u.is_active = TRUE ORDER BY u.name"
    )
    resp2 = requests.post(
        f"{m.url}/rest/v1/rpc/execute_sql",
        headers=m.headers,
        json={"sql_query": verify_sql},
        timeout=30,
    )
    if resp2.status_code == 200:
        data = resp2.json()
        if isinstance(data, list):
            print(f"\nVerification - universites actives avec config: {len(data)}")
            for row in data:
                print(f"  - {row.get('name')}: hero_title={row.get('hero_title')}")


if __name__ == "__main__":
    main()
