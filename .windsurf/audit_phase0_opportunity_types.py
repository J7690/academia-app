#!/usr/bin/env python3
"""
Audit Phase 0 - Module Opportunités Mini-Facebook
Vérifie l'état actuel des tables et données avant correction des types.
"""

from __future__ import annotations

import json
from typing import Any, Dict, List, Tuple
from pathlib import Path

import requests

from supabase_auto_manager import SupabaseAutoManager


def run_sql(m: SupabaseAutoManager, label: str, sql: str, timeout: int = 60) -> Dict[str, Any]:
    """Exécute une requête SQL via admin_execute_sql et retourne le résultat structuré."""
    url = f"{m.url}/rest/v1/rpc/admin_execute_sql"
    try:
        resp = requests.post(url, headers=m.headers, json={"p_sql": sql}, timeout=timeout)
    except Exception as e:
        return {"label": label, "http": 0, "ok": False, "error": str(e), "rows": []}

    try:
        data = resp.json()
    except Exception:
        return {"label": label, "http": resp.status_code, "ok": False, "raw": (resp.text or "")[:2000], "rows": []}

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
        "rows": [],
        "error": "unexpected_json_type",
    }


def main() -> int:
    m = SupabaseAutoManager()

    queries: List[Tuple[str, str]] = [
        # 1. Structure de la table opportunity_types
        (
            "OPPORTUNITY_TYPES_STRUCTURE",
            """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app' AND table_name = 'opportunity_types'
            ORDER BY ordinal_position
            """.strip(),
        ),
        # 2. Données actuelles des types
        (
            "OPPORTUNITY_TYPES_DATA",
            """
            SELECT id, code, label, sort_order, is_active, created_at
            FROM app.opportunity_types
            ORDER BY sort_order, code
            """.strip(),
        ),
        # 3. Structure de la table opportunities
        (
            "OPPORTUNITIES_STRUCTURE",
            """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app' AND table_name = 'opportunities'
            ORDER BY ordinal_position
            """.strip(),
        ),
        # 4. Valeurs distinctes du champ type dans opportunities
        (
            "OPPORTUNITIES_TYPE_VALUES",
            """
            SELECT DISTINCT type, COUNT(*) as count
            FROM app.opportunities
            GROUP BY type
            ORDER BY type
            """.strip(),
        ),
        # 5. Données actuelles des opportunités
        (
            "OPPORTUNITIES_DATA",
            """
            SELECT id, title, type, status, is_active, organization_name, city, country
            FROM app.opportunities
            ORDER BY created_at DESC
            LIMIT 10
            """.strip(),
        ),
        # 6. Structure de la table opportunity_applications
        (
            "OPPORTUNITY_APPLICATIONS_STRUCTURE",
            """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'app' AND table_name = 'opportunity_applications'
            ORDER BY ordinal_position
            """.strip(),
        ),
        # 7. Compteurs
        (
            "OPPORTUNITIES_COUNTS",
            """
            SELECT
                (SELECT COUNT(*) FROM app.opportunities) AS opportunities_count,
                (SELECT COUNT(*) FROM app.opportunity_applications) AS applications_count,
                (SELECT COUNT(*) FROM app.opportunity_types) AS types_count
            """.strip(),
        ),
        # 8. RPC existantes liées aux opportunités
        (
            "OPPORTUNITY_RPCS",
            """
            SELECT routine_name, data_type
            FROM information_schema.routines
            WHERE routine_schema = 'public'
              AND routine_name ILIKE '%opportunit%'
            ORDER BY routine_name
            """.strip(),
        ),
        # 9. Policies RLS sur les tables opportunités
        (
            "OPPORTUNITY_POLICIES",
            """
            SELECT tablename, policyname, cmd, qual, with_check
            FROM pg_policies
            WHERE schemaname = 'app'
              AND tablename ILIKE '%opportunit%'
            ORDER BY tablename, policyname
            """.strip(),
        ),
    ]

    results: Dict[str, Any] = {}

    print("=" * 60)
    print("AUDIT PHASE 0 - MODULE OPPORTUNITÉS")
    print("=" * 60)

    for label, sql in queries:
        print(f"\nExécution: {label}...")
        res = run_sql(m, label, sql)
        results[label] = res
        
        if res.get("ok"):
            print(f"  ✓ {label}: {res.get('rows_count', 0)} lignes")
        else:
            print(f"  ✗ {label}: ERREUR - {res.get('error', 'unknown')}")

    # Sauvegarder les résultats
    out_path = Path(__file__).parent / "logs" / "audit_phase0_opportunity_types.json"
    out_path.parent.mkdir(exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n[OK] Résultats sauvegardés dans {out_path}")

    # Afficher un résumé
    print("\n" + "=" * 60)
    print("RÉSUMÉ DE L'AUDIT PHASE 0")
    print("=" * 60)

    # Types existants
    types_data = results.get("OPPORTUNITY_TYPES_DATA", {}).get("rows", [])
    print(f"\n📊 TYPES D'OPPORTUNITÉS EXISTANTS: {len(types_data)}")
    for t in types_data:
        print(f"   - code: '{t.get('code')}', label: '{t.get('label')}', sort_order: {t.get('sort_order')}, active: {t.get('is_active')}")

    # Valeurs type dans opportunities
    type_values = results.get("OPPORTUNITIES_TYPE_VALUES", {}).get("rows", [])
    print(f"\n📊 VALEURS 'type' UTILISÉES DANS OPPORTUNITIES:")
    for tv in type_values:
        print(f"   - '{tv.get('type')}': {tv.get('count')} opportunité(s)")

    # Compteurs
    counts = results.get("OPPORTUNITIES_COUNTS", {}).get("rows", [{}])[0] if results.get("OPPORTUNITIES_COUNTS", {}).get("rows") else {}
    print(f"\n📊 COMPTEURS:")
    print(f"   - Opportunités: {counts.get('opportunities_count', 0)}")
    print(f"   - Candidatures: {counts.get('applications_count', 0)}")
    print(f"   - Types: {counts.get('types_count', 0)}")

    # RPC existantes
    rpcs = results.get("OPPORTUNITY_RPCS", {}).get("rows", [])
    print(f"\n📊 RPC EXISTANTES: {len(rpcs)}")
    for r in rpcs:
        print(f"   - {r.get('routine_name')}")

    # Analyse des incohérences
    print("\n" + "=" * 60)
    print("ANALYSE DES INCOHÉRENCES")
    print("=" * 60)
    
    issues = []
    
    # Vérifier si code/label sont inversés
    for t in types_data:
        code = t.get('code', '')
        label = t.get('label', '')
        if code == 'vendeur' and label == 'emploi':
            issues.append(f"Type incohérent: code='{code}' devrait être 'job', label='{label}' devrait être 'Emploi'")
    
    # Vérifier les types manquants
    expected_types = {'job', 'service', 'product'}
    existing_codes = {t.get('code', '') for t in types_data}
    missing = expected_types - existing_codes
    if missing:
        issues.append(f"Types manquants: {missing}")

    if issues:
        print("\n⚠️ PROBLÈMES DÉTECTÉS:")
        for issue in issues:
            print(f"   - {issue}")
    else:
        print("\n✅ Aucune incohérence détectée")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
