#!/usr/bin/env python3
"""Vérifie que toute RPC appelée par le code Flutter existe côté Supabase.

Raison d'être — l'audit du 26 juillet 2026 a trouvé neuf RPC appelées par le
code Dart et absentes de la base, dont un fichier SQL écrit le 8 juin et oublié
pendant sept semaines. Rien dans la chaîne ne signalait l'écart : l'application
compilait, se déployait, et échouait seulement à l'exécution, sur l'écran de
l'utilisateur.

Ce script ferme cette boucle. À lancer en CI avant tout build.

    python tools/check_rpc_contract.py
    python tools/check_rpc_contract.py --json      # sortie machine
    python tools/check_rpc_contract.py --update-baseline

Code de sortie 0 si le contrat est respecté, 1 sinon.

Connexion : mêmes variables que verify_tables.py — SUPABASE_URL et
SUPABASE_SERVICE_KEY, lues depuis academia_bobodo_backend/.env.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

try:
    from dotenv import load_dotenv
except ImportError:  # dotenv facultatif : les variables peuvent venir de la CI
    def load_dotenv(env_path=None, override=False):
        """Repli minimal, sans dépendance : lit un .env simple."""
        if env_path is None or not Path(env_path).exists():
            return False
        for line in Path(env_path).read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key, value = key.strip(), value.strip().strip("'\"")
            if override or key not in os.environ:
                os.environ[key] = value
        return True

BASE_DIR = Path(__file__).resolve().parent.parent
LIB_DIR = BASE_DIR / "academia_app" / "lib"
BASELINE = Path(__file__).resolve().parent / "rpc_contract_baseline.json"

# `.rpc('nom'` ou `.rpc("nom"`, avec espaces et retours à la ligne tolérés.
RPC_CALL = re.compile(r"""\.rpc\(\s*['"]([A-Za-z0-9_]+)['"]""")

# Les Edge Functions appellent aussi des RPC : on les couvre également.
EDGE_DIR = BASE_DIR / "supabase" / "functions"
EDGE_CALL = re.compile(r"""\.rpc\(\s*['"]([A-Za-z0-9_]+)['"]""")


def scan_calls() -> dict[str, list[str]]:
    """Retourne {nom_rpc: [fichiers qui l'appellent]}."""
    found: dict[str, list[str]] = {}

    def scan(root: Path, suffixes: tuple[str, ...], pattern: re.Pattern) -> None:
        if not root.exists():
            return
        for path in root.rglob("*"):
            if path.suffix not in suffixes or not path.is_file():
                continue
            try:
                text = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for name in pattern.findall(text):
                found.setdefault(name, []).append(
                    str(path.relative_to(BASE_DIR)).replace("\\", "/")
                )

    scan(LIB_DIR, (".dart",), RPC_CALL)
    scan(EDGE_DIR, (".ts",), EDGE_CALL)
    return found


def fetch_db_functions() -> set[str]:
    """Liste les fonctions du schéma public exposées par PostgREST."""
    load_dotenv(BASE_DIR / "academia_bobodo_backend" / ".env", override=True)
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not url or not key:
        sys.exit(
            "SUPABASE_URL / SUPABASE_SERVICE_KEY manquants.\n"
            "Renseignez-les dans academia_bobodo_backend/.env ou dans "
            "l'environnement de la CI."
        )

    # PostgREST publie son schéma OpenAPI : les RPC y figurent sous /rpc/<nom>.
    request = urllib.request.Request(
        f"{url.rstrip('/')}/rest/v1/",
        headers={"apikey": key, "Authorization": f"Bearer {key}"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        paths = json.loads(response.read().decode("utf-8")).get("paths", {})
    return {p[len("/rpc/"):] for p in paths if p.startswith("/rpc/")}


def load_baseline() -> set[str]:
    if not BASELINE.exists():
        return set()
    return set(json.loads(BASELINE.read_text(encoding="utf-8")).get("known_missing", []))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="sortie machine")
    parser.add_argument(
        "--update-baseline",
        action="store_true",
        help="enregistre les manques actuels comme tolérés (chantiers planifiés)",
    )
    args = parser.parse_args()

    calls = scan_calls()
    db = fetch_db_functions()
    baseline = load_baseline()

    missing = {name: files for name, files in sorted(calls.items()) if name not in db}
    new_missing = {n: f for n, f in missing.items() if n not in baseline}
    resolved = sorted(baseline - set(missing))

    if args.update_baseline:
        BASELINE.write_text(
            json.dumps(
                {
                    "_comment": "RPC appelées par le code mais pas encore en base. "
                                "Chaque entrée doit correspondre à un chantier planifié.",
                    "known_missing": sorted(missing),
                },
                indent=2,
                ensure_ascii=False,
            )
            + "\n",
            encoding="utf-8",
        )
        print(f"Référence mise à jour : {len(missing)} manque(s) toléré(s).")
        return 0

    if args.json:
        print(json.dumps(
            {
                "scanned": len(calls),
                "db_functions": len(db),
                "missing": missing,
                "new_missing": new_missing,
                "resolved": resolved,
            },
            indent=2,
            ensure_ascii=False,
        ))
        return 1 if new_missing else 0

    print(f"RPC appelées par le code : {len(calls)}")
    print(f"Fonctions exposées par Supabase : {len(db)}")

    if resolved:
        print(f"\n{len(resolved)} RPC désormais présente(s), à retirer de la référence :")
        for name in resolved:
            print(f"  · {name}")

    if missing and not new_missing:
        print(f"\n{len(missing)} manque(s) connu(s) et toléré(s) :")
        for name in sorted(missing):
            print(f"  · {name}")

    if new_missing:
        print(f"\nÉCHEC — {len(new_missing)} RPC appelée(s) sans fonction correspondante :\n")
        for name, files in new_missing.items():
            print(f"  {name}")
            for f in sorted(set(files)):
                print(f"      {f}")
        print(
            "\nSoit la migration n'a pas été appliquée, soit le nom est erroné.\n"
            "Si le manque est volontaire et planifié : "
            "python tools/check_rpc_contract.py --update-baseline"
        )
        return 1

    print("\nContrat respecté.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
