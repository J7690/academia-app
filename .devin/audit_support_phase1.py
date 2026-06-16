#!/usr/bin/env python3
"""Phase 1 — Audit Supabase avant création du module Support.
Vérifie:
1. Existence éventuelle de tables support_* dans schema app
2. Liste des tables existantes dans schema app (pour éviter collisions)
3. Vérifie qu'admin_execute_sql fonctionne
4. Vérifie la structure de auth.users (colonnes utiles)
5. Vérifie app.students (full_name, id)
6. Vérifie s'il existe déjà des RPC support_*
"""

import json
import sys
import requests
from supabase_auto_manager import SupabaseAutoManager


def run_sql(manager, label, sql):
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    sql_clean = sql.strip().rstrip(";")
    try:
        r = requests.post(url, headers=manager.headers, json={"p_sql": sql_clean}, timeout=30)
        data = r.json() if r.text else {}
        print(f"\n{'='*60}")
        print(f"AUDIT: {label}")
        print(f"{'='*60}")
        if r.status_code == 200 and isinstance(data, dict) and data.get("ok") is True:
            rows = data.get("rows", [])
            if isinstance(rows, list):
                print(f"  ✅ {len(rows)} row(s)")
                for row in rows[:20]:
                    print(f"    {json.dumps(row, ensure_ascii=False, default=str)[:200]}")
            else:
                print(f"  ✅ OK (no rows)")
            return rows if isinstance(rows, list) else []
        else:
            print(f"  ⚠️ HTTP {r.status_code}: {json.dumps(data, ensure_ascii=False, default=str)[:400]}")
            return None
    except Exception as e:
        print(f"  ❌ Exception: {e}")
        return None


def main():
    m = SupabaseAutoManager()

    # 1. Test admin_execute_sql
    run_sql(m, "1. Test admin_execute_sql (SELECT 1)", "SELECT 1 AS test_ok")

    # 2. Check if support_* tables already exist
    run_sql(m, "2. Tables support_* dans schema app",
        """SELECT table_name FROM information_schema.tables
           WHERE table_schema = 'app' AND table_name LIKE 'support_%'
           ORDER BY table_name""")

    # 3. All tables in schema app (summary)
    run_sql(m, "3. Toutes les tables du schema app",
        """SELECT table_name FROM information_schema.tables
           WHERE table_schema = 'app'
           ORDER BY table_name""")

    # 4. Check auth.users columns (role in metadata)
    run_sql(m, "4. Colonnes utiles de auth.users",
        """SELECT column_name, data_type
           FROM information_schema.columns
           WHERE table_schema = 'auth' AND table_name = 'users'
           AND column_name IN ('id', 'email', 'raw_user_meta_data')""")

    # 5. Check app.students columns
    run_sql(m, "5. Colonnes de app.students (id, full_name, avatar_url)",
        """SELECT column_name, data_type
           FROM information_schema.columns
           WHERE table_schema = 'app' AND table_name = 'students'
           AND column_name IN ('id', 'full_name', 'avatar_url')""")

    # 6. Check existing RPC with 'support' in name
    run_sql(m, "6. RPC existantes contenant 'support'",
        """SELECT p.proname AS function_name
           FROM pg_catalog.pg_proc p
           JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
           WHERE n.nspname = 'public' AND p.proname LIKE '%support%'
           ORDER BY p.proname""")

    # 7. Check admin user(s) to know the admin user_id
    run_sql(m, "7. Utilisateurs admin (role='admin' dans metadata)",
        """SELECT id, email
           FROM auth.users
           WHERE raw_user_meta_data->>'role' = 'admin'
           LIMIT 5""")

    # 8. Check existing realtime publications
    run_sql(m, "8. Tables dans supabase_realtime publication",
        """SELECT schemaname, tablename
           FROM pg_publication_tables
           WHERE pubname = 'supabase_realtime'
           AND schemaname = 'app'
           ORDER BY tablename""")

    print(f"\n{'='*60}")
    print("AUDIT PHASE 1 TERMINÉ")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
