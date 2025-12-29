#!/usr/bin/env python3
"""Applique les scripts SQL Academia (offres, candidatures, cours, Bobodo)
via la RPC admin_execute_sql exposée par Supabase.

Ce script respecte l'infra .windsurf en réutilisant SupabaseAutoManager
pour l'URL et les headers (service_role).
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import List

import requests

from supabase_auto_manager import SupabaseAutoManager


SQL_FILES: List[str] = [
    "supabase_student_offers.sql",
    "supabase_student_applications.sql",
    "supabase_student_courses.sql",
    "supabase_bobodo.sql",
]


def split_sql_script(script: str) -> List[str]:
    """Découpe un script SQL en statements individuels.

    - Respecte les blocs $$ ... $$ des fonctions PL/pgSQL
    - Utilise ';' comme séparateur uniquement hors des blocs $$
    - Ne split pas dans les commentaires SQL (--) ou (/* */)
    """
    statements: List[str] = []
    current: List[str] = []
    in_dollar = False
    in_line_comment = False
    in_block_comment = False
    i = 0
    length = len(script)

    while i < length:
        # Détection des blocs $$ (prioritaire)
        if not in_line_comment and not in_block_comment and script[i : i + 2] == "$$":
            in_dollar = not in_dollar
            current.append("$$")
            i += 2
            continue

        # Détection commentaires (hors $$)
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

    # Reste éventuel
    remainder = "".join(current).strip()
    if remainder:
        statements.append(remainder)

    return statements


def apply_sql_file(manager: SupabaseAutoManager, winds_dir: Path, filename: str) -> bool:
    path = winds_dir / filename
    if not path.exists():
        print(f"[ERROR] Fichier SQL introuvable dans .windsurf : {filename}")
        return False

    sql_text = path.read_text(encoding="utf-8")
    statements = split_sql_script(sql_text)

    if not statements:
        print(f"[WARN] Aucun statement SQL trouvé dans {filename}")
        return False

    print(f"\n=== Application via admin_execute_sql : {filename} ===")
    url = f"{manager.url}/rest/v1/rpc/admin_execute_sql"

    all_ok = True
    for idx, stmt in enumerate(statements, start=1):
        trimmed = stmt.strip()

        # Ignorer uniquement les statements qui sont 100% commentaires
        if not trimmed:
            continue

        lines = [ln.strip() for ln in trimmed.splitlines() if ln.strip()]
        if lines and all(ln.startswith("--") for ln in lines):
            continue

        print(f"\n[INFO] Statement {idx}/{len(statements)}...")
        try:
            response = requests.post(
                url,
                headers=manager.headers,
                json={"p_sql": stmt},
                timeout=30,
            )
        except Exception as exc:
            print(f"[ERROR] Erreur réseau pour le statement {idx}: {exc}")
            all_ok = False
            continue

        if response.status_code != 200:
            print(f"[ERROR] HTTP {response.status_code} pour le statement {idx}")
            print(response.text[:400])
            all_ok = False
            continue

        try:
            data = response.json()
        except json.JSONDecodeError:
            print("[WARN] Réponse non JSON, statement peut-être exécuté")
            continue

        if isinstance(data, dict) and not data.get("ok", True):
            print("[WARN] admin_execute_sql a renvoyé une erreur :")
            print(json.dumps(data, indent=2, ensure_ascii=False)[:600])
            all_ok = False
        else:
            print("[OK] Statement exécuté")

    return all_ok


def main() -> int:
    winds_dir = Path(__file__).parent
    print("Application du schéma Academia via admin_execute_sql")
    print("=" * 72)

    manager = SupabaseAutoManager()

    global_ok = True
    for filename in SQL_FILES:
        if not apply_sql_file(manager, winds_dir, filename):
            global_ok = False

    print("\n" + "=" * 72)
    if global_ok:
        print("[SUCCESS] Tous les scripts SQL Academia ont été appliqués (via admin_execute_sql).")
        return 0
    else:
        print("[WARN] Des erreurs sont survenues lors de l'application des scripts. Consulte les logs ci-dessus.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
