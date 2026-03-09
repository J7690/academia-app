#!/usr/bin/env python3
"""
Audit du module Opportunités - Tables, RPC, Données
Interroge Supabase pour voir l'état réel du backend
"""

import json
from typing import Any, Dict, List, Tuple
import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, label: str, sql: str, timeout: int = 120) -> Dict[str, Any]:
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=timeout)
    try:
        data = resp.json()
    except Exception:
        return {"label": label, "http": resp.status_code, "ok": False, "raw": (resp.text or "")[:2000]}

    if isinstance(data, dict):
        rows = data.get("rows")
        return {
            "label": label,
            "http": resp.status_code,
            "ok": bool(data.get("ok")),
            "mode": data.get("mode"),
            "rows_count": len(rows) if isinstance(rows, list) else 0,
            "rows": rows if isinstance(rows, list) else [],
            "error": data.get("error"),
            "sqlstate": data.get("sqlstate"),
        }

    if isinstance(data, list):
        return {
            "label": label,
            "http": resp.status_code,
            "ok": True,
            "mode": "select",
            "rows_count": len(data),
            "rows": data,
            "error": None,
            "sqlstate": None,
        }

    return {
        "label": label,
        "http": resp.status_code,
        "ok": False,
        "mode": None,
        "rows_count": 0,
        "rows": [],
        "error": "unexpected_json_type",
        "sqlstate": None,
    }


def main() -> int:
    m = SupabaseAutoManager()

    queries: List[Tuple[str, str]] = [
        # 1. Vérifier si les tables opportunities existent
        (
            "OPPORTUNITIES_TABLES_EXIST",
            """
            SELECT table_schema, table_name, table_type
            FROM information_schema.tables
            WHERE table_schema = 'app'
              AND table_name IN ('opportunities', 'opportunity_applications', 'opportunity_types')
            ORDER BY table_name
            """.strip(),
        ),
        # 2. Structure de la table opportunities
        (
            "OPPORTUNITIES_TABLE_COLUMNS",
            """
            SELECT table_name, column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'opportunities'
            ORDER BY ordinal_position
            """.strip(),
        ),
        # 3. Structure de la table opportunity_applications
        (
            "OPPORTUNITY_APPLICATIONS_COLUMNS",
            """
            SELECT table_name, column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'opportunity_applications'
            ORDER BY ordinal_position
            """.strip(),
        ),
        # 4. Structure de la table opportunity_types
        (
            "OPPORTUNITY_TYPES_COLUMNS",
            """
            SELECT table_name, column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app'
              AND table_name = 'opportunity_types'
            ORDER BY ordinal_position
            """.strip(),
        ),
        # 5. Fonctions RPC liées aux opportunités
        (
            "OPPORTUNITIES_RPC_FUNCTIONS",
            """
            SELECT routine_schema, routine_name, routine_type, data_type
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND (routine_name ILIKE '%opportunit%' OR routine_name ILIKE '%opportunity%')
            ORDER BY routine_name
            """.strip(),
        ),
        # 6. Définitions des fonctions RPC opportunités
        (
            "OPPORTUNITIES_RPC_DEFINITIONS",
            """
            SELECT n.nspname AS schema,
                   p.proname AS name,
                   pg_get_functiondef(p.oid) AS def
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public'
              AND (p.proname ILIKE '%opportunit%' OR p.proname ILIKE '%opportunity%')
            ORDER BY p.proname
            """.strip(),
        ),
        # 7. Policies RLS sur les tables opportunités
        (
            "OPPORTUNITIES_RLS_POLICIES",
            """
            SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
            FROM pg_policies
            WHERE schemaname = 'app'
              AND tablename IN ('opportunities', 'opportunity_applications', 'opportunity_types')
            ORDER BY tablename, policyname
            """.strip(),
        ),
        # 8. Compter les données existantes
        (
            "OPPORTUNITIES_DATA_COUNT",
            """
            SELECT 
                (SELECT COUNT(*) FROM app.opportunities) AS opportunities_count,
                (SELECT COUNT(*) FROM app.opportunity_applications) AS applications_count,
                (SELECT COUNT(*) FROM app.opportunity_types) AS types_count
            """.strip(),
        ),
        # 9. Lister les types d'opportunités existants
        (
            "OPPORTUNITY_TYPES_DATA",
            """
            SELECT id, code, label, sort_order, is_active, created_at
            FROM app.opportunity_types
            ORDER BY sort_order, label
            """.strip(),
        ),
        # 10. Échantillon d'opportunités existantes
        (
            "OPPORTUNITIES_SAMPLE",
            """
            SELECT id, title, type, organization_name, city, country, status, is_active, is_featured, created_at
            FROM app.opportunities
            ORDER BY created_at DESC
            LIMIT 10
            """.strip(),
        ),
        # 11. Bucket storage pour les CVs
        (
            "STORAGE_BUCKETS_CV",
            """
            SELECT id, name, public, created_at
            FROM storage.buckets
            WHERE name ILIKE '%application%' OR name ILIKE '%cv%' OR name ILIKE '%file%'
            ORDER BY name
            """.strip(),
        ),
        # 12. Policies storage pour les fichiers de candidature
        (
            "STORAGE_POLICIES_APPLICATION_FILES",
            """
            SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
            FROM pg_policies
            WHERE schemaname = 'storage'
              AND tablename = 'objects'
              AND (policyname ILIKE '%application%' OR policyname ILIKE '%cv%')
            ORDER BY policyname
            """.strip(),
        ),
    ]

    results: Dict[str, Any] = {}

    for label, sql in queries:
        print(f"Exécution: {label}...")
        res = run_sql(m, label, sql)
        rows = res.get("rows")
        if not isinstance(rows, list):
            rows = []
        results[label] = {
            "http": res.get("http"),
            "ok": res.get("ok"),
            "mode": res.get("mode"),
            "rows_count": res.get("rows_count"),
            "rows": rows,  # Garder toutes les lignes pour cet audit
            "error": res.get("error"),
            "sqlstate": res.get("sqlstate"),
        }
        if res.get("ok"):
            print(f"  ✓ {label}: {res.get('rows_count')} lignes")
        else:
            print(f"  ✗ {label}: erreur - {res.get('error')}")

    out_path = ".windsurf/logs/audit_opportunities_module.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n[OK] Résultats sauvegardés dans {out_path}")
    
    # Résumé
    print("\n" + "=" * 60)
    print("RÉSUMÉ DE L'AUDIT MODULE OPPORTUNITÉS")
    print("=" * 60)
    
    # Tables
    tables_result = results.get("OPPORTUNITIES_TABLES_EXIST", {})
    if tables_result.get("ok") and tables_result.get("rows"):
        print(f"\n📊 TABLES TROUVÉES: {len(tables_result['rows'])}")
        for row in tables_result["rows"]:
            print(f"   - {row.get('table_schema')}.{row.get('table_name')}")
    else:
        print("\n⚠️ TABLES: Aucune table opportunités trouvée ou erreur")
    
    # RPC Functions
    rpc_result = results.get("OPPORTUNITIES_RPC_FUNCTIONS", {})
    if rpc_result.get("ok") and rpc_result.get("rows"):
        print(f"\n🔧 FONCTIONS RPC: {len(rpc_result['rows'])}")
        for row in rpc_result["rows"]:
            print(f"   - {row.get('routine_name')}")
    else:
        print("\n⚠️ RPC: Aucune fonction RPC opportunités trouvée ou erreur")
    
    # Data counts
    count_result = results.get("OPPORTUNITIES_DATA_COUNT", {})
    if count_result.get("ok") and count_result.get("rows"):
        row = count_result["rows"][0] if count_result["rows"] else {}
        print(f"\n📈 DONNÉES:")
        print(f"   - Opportunités: {row.get('opportunities_count', 'N/A')}")
        print(f"   - Candidatures: {row.get('applications_count', 'N/A')}")
        print(f"   - Types: {row.get('types_count', 'N/A')}")
    
    # Types
    types_result = results.get("OPPORTUNITY_TYPES_DATA", {})
    if types_result.get("ok") and types_result.get("rows"):
        print(f"\n🏷️ TYPES D'OPPORTUNITÉS:")
        for row in types_result["rows"]:
            active = "✓" if row.get("is_active") else "✗"
            print(f"   [{active}] {row.get('code')}: {row.get('label')}")
    
    # Storage
    storage_result = results.get("STORAGE_BUCKETS_CV", {})
    if storage_result.get("ok") and storage_result.get("rows"):
        print(f"\n📁 BUCKETS STORAGE:")
        for row in storage_result["rows"]:
            public = "public" if row.get("public") else "private"
            print(f"   - {row.get('name')} ({public})")
    else:
        print("\n⚠️ STORAGE: Aucun bucket pour les fichiers de candidature trouvé")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
