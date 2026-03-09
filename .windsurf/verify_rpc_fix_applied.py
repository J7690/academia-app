#!/usr/bin/env python3
"""Vérifie si les corrections RPC ont bien été appliquées."""

import json
from supabase_auto_manager import SupabaseAutoManager


def main():
    m = SupabaseAutoManager()

    # 1. Combien de surcharges de app_student_list_community_posts ?
    print("=== SURCHARGES app_student_list_community_posts ===")
    r = m.execute_sql_auto("""
    SELECT p.oid, n.nspname AS schema,
           pg_catalog.pg_get_function_arguments(p.oid) AS args,
           pg_catalog.pg_get_function_result(p.oid) AS ret
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_list_community_posts'
    """)
    print(json.dumps(r.get("data", []), indent=2, ensure_ascii=False))

    # 2. Source de CHAQUE surcharge
    print("\n=== SOURCE CHAQUE SURCHARGE ===")
    r2 = m.execute_sql_auto("""
    SELECT p.oid,
           pg_catalog.pg_get_function_arguments(p.oid) AS args,
           pg_catalog.pg_get_functiondef(p.oid) AS source
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_list_community_posts'
    ORDER BY p.oid
    """)
    if r2.get("data"):
        for item in r2["data"]:
            src = item.get("source", "")
            has_author_dn = "author_display_name" in src
            has_full_name = "full_name" in src
            print(f"  OID={item.get('oid')} args={item.get('args')}")
            print(f"    author_display_name: {'✅' if has_author_dn else '❌'}")
            print(f"    full_name: {'✅' if has_full_name else '❌'}")
            # Show first 200 chars of source for debug
            print(f"    source (first 300): {src[:300]}")
            print()

    # 3. Vérifier si execute_sql retourne quelque chose pour un CREATE OR REPLACE simple
    print("\n=== TEST: execute_sql avec CREATE OR REPLACE retourne quoi ? ===")
    r3 = m.execute_sql_auto("""
    SELECT 1 AS test_value
    """)
    print(json.dumps(r3, indent=2, ensure_ascii=False))

    # 4. Vérifier list_direct_messages
    print("\n=== SURCHARGES app_student_list_direct_messages ===")
    r4 = m.execute_sql_auto("""
    SELECT p.oid,
           pg_catalog.pg_get_function_arguments(p.oid) AS args,
           pg_catalog.pg_get_functiondef(p.oid) AS source
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
    WHERE p.proname = 'app_student_list_direct_messages'
    ORDER BY p.oid
    """)
    if r4.get("data"):
        for item in r4["data"]:
            src = item.get("source", "")
            has_full_name = "full_name" in src
            has_first_name = "first_name" in src
            print(f"  OID={item.get('oid')} args={item.get('args')}")
            print(f"    full_name: {'✅' if has_full_name else '❌'}")
            print(f"    first_name (old): {'❌ still present' if has_first_name else '✅ gone'}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
