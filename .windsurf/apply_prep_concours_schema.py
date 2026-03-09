#!/usr/bin/env python3
"""Applique le schéma Préparation Concours (tables + RPCs) via admin_execute_sql.

Utilise SupabaseAutoManager pour l'URL et les headers (service_role).
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import List

import requests

from supabase_auto_manager import SupabaseAutoManager


SQL_FILES: List[str] = [
    "supabase_prep_concours_schema.sql",
    "supabase_prep_concours_rpcs.sql",
]


def split_sql_script(script: str) -> List[str]:
    """Découpe un script SQL en statements individuels.
    Respecte les blocs $$ ... $$ des fonctions PL/pgSQL.
    """
    statements: List[str] = []
    current: List[str] = []
    in_dollar = False
    in_line_comment = False
    in_block_comment = False
    i = 0
    length = len(script)

    while i < length:
        if not in_line_comment and not in_block_comment and script[i : i + 2] == "$$":
            in_dollar = not in_dollar
            current.append("$$")
            i += 2
            continue

        if not in_dollar and not in_block_comment and not in_line_comment and script[i : i + 2] == "--":
            in_line_comment = True
            current.append("--")
            i += 2
            continue

        if not in_dollar and not in_line_comment and not in_block_comment and script[i : i + 2] == "/*":
            in_block_comment = True
            current.append("/*")
            i += 2
            continue

        if in_block_comment and script[i : i + 2] == "*/":
            in_block_comment = False
            current.append("*/")
            i += 2
            continue

        ch = script[i]

        if in_line_comment and ch == "\n":
            in_line_comment = False
            current.append(ch)
            i += 1
            continue

        if ch == ";" and not in_dollar and not in_line_comment and not in_block_comment:
            stmt = "".join(current).strip()
            if stmt:
                statements.append(stmt)
            current = []
        else:
            current.append(ch)
        i += 1

    remainder = "".join(current).strip()
    if remainder:
        statements.append(remainder)

    return statements


def apply_sql_file(manager: SupabaseAutoManager, winds_dir: Path, filename: str) -> bool:
    path = winds_dir / filename
    if not path.exists():
        print(f"[ERROR] Fichier SQL introuvable: {filename}")
        return False

    sql_text = path.read_text(encoding="utf-8")
    statements = split_sql_script(sql_text)

    if not statements:
        print(f"[WARN] Aucun statement SQL dans {filename}")
        return False

    print(f"\n{'='*72}")
    print(f"Application: {filename} ({len(statements)} statements)")
    print(f"{'='*72}")

    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"
    all_ok = True

    for idx, stmt in enumerate(statements, start=1):
        trimmed = stmt.strip()
        if not trimmed:
            continue

        lines = [ln.strip() for ln in trimmed.splitlines() if ln.strip()]
        if lines and all(ln.startswith("--") for ln in lines):
            continue

        preview = trimmed[:80].replace('\n', ' ')
        print(f"\n[{idx}/{len(statements)}] {preview}...")

        try:
            response = requests.post(
                url,
                headers=manager.headers,
                json={"p_sql": stmt},
                timeout=30,
            )
        except Exception as exc:
            print(f"  [ERROR] Réseau: {exc}")
            all_ok = False
            continue

        if response.status_code != 200:
            print(f"  [ERROR] HTTP {response.status_code}")
            print(f"  {response.text[:300]}")
            all_ok = False
            continue

        try:
            data = response.json()
        except json.JSONDecodeError:
            print("  [OK] Exécuté (réponse non JSON)")
            continue

        if isinstance(data, dict):
            if not data.get("ok", True):
                print(f"  [WARN] Erreur: {json.dumps(data, indent=2, ensure_ascii=False)[:400]}")
                all_ok = False
            elif "data" in data and data["data"]:
                print(f"  [RESULT] {json.dumps(data['data'], ensure_ascii=False)[:200]}")
            else:
                print("  [OK] Exécuté")
        else:
            print("  [OK] Exécuté")

    return all_ok


def main() -> int:
    winds_dir = Path(__file__).parent
    print("=" * 72)
    print("PRÉPARATION CONCOURS — Application du schéma SQL")
    print("=" * 72)

    manager = SupabaseAutoManager()

    global_ok = True
    for filename in SQL_FILES:
        if not apply_sql_file(manager, winds_dir, filename):
            global_ok = False

    print("\n" + "=" * 72)
    if global_ok:
        print("[SUCCESS] Schéma Préparation Concours appliqué avec succès!")
    else:
        print("[WARN] Des erreurs sont survenues. Consulte les logs ci-dessus.")
    print("=" * 72)
    return 0 if global_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
