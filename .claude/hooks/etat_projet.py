#!/usr/bin/env python
"""SessionStart — donne l'etat REEL du depot au demarrage, pas l'etat suppose.

POURQUOI. CLAUDE.md decrit une intention ; il vieillit. Une session qui demarre
sur « le chantier en cours est X » alors que X est termine depuis trois semaines
part sur une fausse piste, et la fausse piste coute plus cher que l'ignorance.
Ce hook n'affirme que ce qu'il vient de mesurer : branche, avance sur origin,
fichiers non commités, et l'etat de mise en sommeil du studio.

CONTRAT DE SURETE : n'echoue jamais en bloquant (sortie 0 quoi qu'il arrive).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys


def git(*args: str, racine: str) -> str:
    try:
        r = subprocess.run(("git",) + args, cwd=racine, capture_output=True,
                           text=True, timeout=15)
        return r.stdout.strip()
    except Exception:
        return ""


def main() -> int:
    try:
        evenement = json.load(sys.stdin)
    except Exception:
        evenement = {}

    try:
        racine = (evenement.get("cwd")
                  or os.environ.get("CLAUDE_PROJECT_DIR")
                  or os.getcwd())

        branche = git("rev-parse", "--abbrev-ref", "HEAD", racine=racine) or "?"
        sales = [l for l in git("status", "--porcelain", racine=racine).splitlines() if l.strip()]
        avance = git("rev-list", "--count", "origin/main..HEAD", racine=racine) or "?"
        dernier = git("log", "-1", "--pretty=%h %s", racine=racine)

        lignes = [
            "ETAT MESURE DU DEPOT (releve a l'instant, pas repris de CLAUDE.md) :",
            f"  branche {branche} | {len(sales)} fichier(s) non commité(s) | "
            f"{avance} commit(s) en avance sur origin/main",
            f"  dernier commit : {dernier}",
        ]

        # Le studio visuel est en sommeil depuis le 05/08/2026. Le rappeler
        # evite de relancer un orchestrateur qui facture.
        etat_studio = os.path.join(racine, "docs", "STUDIO_VISUEL_ETAT_2026-08-05.md")
        if os.path.exists(etat_studio):
            lignes.append(
                "  STUDIO VISUEL : en sommeil depuis le 05/08/2026. Ne rien relancer "
                "sans avoir lu docs/STUDIO_VISUEL_ETAT_2026-08-05.md — les scenes "
                "`genere` rendent du noir, cause NON ETABLIE."
            )

        if len(sales) > 15:
            lignes.append(
                f"  ATTENTION : {len(sales)} fichiers non commités. Etablir ce qu'ils "
                f"contiennent AVANT de modifier quoi que ce soit — sans quoi une "
                f"regression sera indiscernable du travail deja en cours."
            )

        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": "\n".join(lignes),
            }
        }))
    except Exception:
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
