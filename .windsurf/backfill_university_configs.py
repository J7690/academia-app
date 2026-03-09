#!/usr/bin/env python3
"""Backfill: cree une config par defaut pour chaque universite qui n'en a pas."""

import sys, json
sys.path.insert(0, str(__import__('pathlib').Path(__file__).parent))

from supabase_auto_manager import SupabaseAutoManager


def main():
    m = SupabaseAutoManager()

    # Step 1: Lister les universites sans config
    find_sql = """
    SELECT u.id, u.name, u.slug
    FROM app.universities u
    WHERE NOT EXISTS (
        SELECT 1 FROM app.university_site_config c WHERE c.university_id = u.id
    )
    ORDER BY u.name
    """
    raw = m.execute_sql_auto(find_sql)
    result = raw.get("data", []) if isinstance(raw, dict) else []
    if not result:
        # Try direct approach
        import requests
        resp = requests.post(
            f"{m.url}/rest/v1/rpc/execute_sql",
            headers=m.headers,
            json={"sql_query": find_sql.strip()},
            timeout=30,
        )
        if resp.status_code == 200:
            data = resp.json()
            if isinstance(data, list):
                result = data

    if not result:
        print("Toutes les universites ont deja une config (ou erreur de lecture).")
        print(f"Raw: {raw}")
        return

    print(f"Universites sans config: {len(result)}")
    for row in result:
        print(f"  - {row.get('name')} ({row.get('slug')})")

    # Step 2: Inserer une config par defaut pour chacune
    success_count = 0
    for row in result:
        uid = row.get('id')
        name = row.get('name', 'Bienvenue')
        slug = row.get('slug', '')

        insert_sql = f"""
        INSERT INTO app.university_site_config (university_id, hero_title, hero_subtitle)
        VALUES ('{uid}', '{name.replace("'", "''")}', 'Decouvrez notre universite')
        ON CONFLICT (university_id) DO NOTHING
        """
        res = m.execute_sql_auto(insert_sql)
        if res.get("success"):
            success_count += 1
            print(f"  OK config creee pour {name} ({slug})")
        else:
            print(f"  ERREUR pour {name}: {res.get('error')}")

    print(f"\nResultat: {success_count}/{len(result)} configs creees.")


if __name__ == "__main__":
    main()
