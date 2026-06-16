#!/usr/bin/env python3
"""Exécute la migration du cache sémantique Bobodo."""
from __future__ import annotations
import requests
from pathlib import Path
from supabase_auto_manager import SupabaseAutoManager

def exec_sql(m, label, sql):
    url = f"{m.url}/rest/v1/rpc/execute_sql"
    r = requests.post(url, headers=m.headers, json={"sql_query": sql}, timeout=60)
    if r.status_code != 200:
        print(f"  ❌ [{label}] HTTP {r.status_code}: {r.text[:300]}")
        return False
    data = r.json()
    if isinstance(data, dict) and "error" in data:
        print(f"  ❌ [{label}] SQL Error: {data['error']}")
        return False
    print(f"  ✅ [{label}] OK")
    return True

def main():
    m = SupabaseAutoManager()
    print("\n🚀 MIGRATION CACHE SÉMANTIQUE BOBODO\n")

    # Lire le fichier SQL
    sql_file = Path(__file__).parent / "sql_changes" / "20260325_bobodo_answer_cache.sql"
    full_sql = sql_file.read_text(encoding="utf-8")

    # Découper en statements individuels (séparés par ;)
    statements = [s.strip() for s in full_sql.split(";") if s.strip() and not s.strip().startswith("--")]

    for i, stmt in enumerate(statements, 1):
        # Ignorer les commentaires purs
        lines = [l for l in stmt.splitlines() if not l.strip().startswith("--")]
        clean = "\n".join(lines).strip()
        if not clean:
            continue
        # Label = première ligne non vide
        label = clean.splitlines()[0][:60]
        exec_sql(m, f"stmt {i}: {label}", clean)

    # Vérification post-migration
    print("\n📋 VÉRIFICATION POST-MIGRATION")
    url = f"{m.url}/rest/v1/rpc/execute_sql"

    checks = [
        ("Table créée",
         "SELECT COUNT(*) AS n FROM information_schema.tables "
         "WHERE table_schema='app' AND table_name='bobodo_answer_cache'"),
        ("RPC search",
         "SELECT routine_name FROM information_schema.routines "
         "WHERE routine_schema='app' AND routine_name='app_search_bobodo_answer_cache'"),
        ("RPC cache_hit",
         "SELECT routine_name FROM information_schema.routines "
         "WHERE routine_schema='app' AND routine_name='app_bobodo_cache_hit'"),
        ("RPC insert",
         "SELECT routine_name FROM information_schema.routines "
         "WHERE routine_schema='app' AND routine_name='app_insert_bobodo_answer_cache'"),
        ("RPC stats",
         "SELECT routine_name FROM information_schema.routines "
         "WHERE routine_schema='app' AND routine_name='app_admin_bobodo_cache_stats'"),
    ]

    for label, sql in checks:
        r = requests.post(url, headers=m.headers, json={"sql_query": sql}, timeout=30)
        data = r.json() if r.status_code == 200 else []
        found = bool(data and data[0])
        print(f"  {'✅' if found else '❌'} {label}")

    print("\n✅ Migration terminée.\n")

if __name__ == "__main__":
    main()
