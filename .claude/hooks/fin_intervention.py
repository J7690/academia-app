#!/usr/bin/env python
"""Stop — refuse de laisser une intervention se terminer sans laisser de trace.

POURQUOI CE HOOK EXISTE.

Le 13/08/2026, Jocelyn a formule le defaut ainsi : « il y a perte de memoire,
il y a manque de documentation, on dirait qu'a chaque fois tu inventes sans
tenir compte de ce qui etait prevu, de ce qui a ete fait et de ce qui restait
a faire. »

La mesure prise ce jour-la a donne raison au constat et deplace la cause :

    docs/                              219 fichiers .md
    dont s'annoncant « etat »/« plan »  10
    travail de la semaine dans git      0   (63 fichiers non commites)
    memoire persistante                 3 entrees, dont UNE FAUSSE
                                        (« studio visuel en sommeil »,
                                         dementi depuis huit jours)

Ce n'etait donc pas un manque d'ecrits : c'etait une absence d'AUTORITE. Rien
ne disait quel document etait vrai aujourd'hui, et l'etat reel ne survivait
qu'a l'interieur d'une session.

CE QUE CE HOOK FAIT, ET CE QU'IL NE FAIT PAS.

Il compare la date d'`ETAT.md` et de `docs/JOURNAL_INTERVENTIONS.md` a celle
des fichiers modifies. Si le depot a bouge et qu'aucun des deux n'a ete touche,
il le DIT — dans le transcript, la ou ca se voit.

Il ne bloque pas. Un garde-fou qui casse une session est un garde-fou qu'on
desactive au bout de deux jours ; c'est la regle commune des trois autres hooks
du depot. Il echoue donc toujours en laissant passer (sortie 0 quoi qu'il
arrive), et ne fait aucun appel reseau.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

# En dessous de ce nombre de fichiers touches, on se tait : corriger une coquille
# ne merite pas une ligne de journal, et un hook bavard finit ignore.
SEUIL = 2


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
        # `stop_hook_active` : on ne se rappelle pas a soi-meme en boucle.
        if evenement.get("stop_hook_active"):
            return 0

        racine = (evenement.get("cwd")
                  or os.environ.get("CLAUDE_PROJECT_DIR")
                  or os.getcwd())

        etat = os.path.join(racine, "ETAT.md")
        journal = os.path.join(racine, "docs", "JOURNAL_INTERVENTIONS.md")

        dates = []
        for chemin in (etat, journal):
            try:
                dates.append(os.path.getmtime(chemin))
            except Exception:
                dates.append(0.0)
        plus_recent_suivi = max(dates)

        # Les fichiers reellement modifies, et leur age. On ignore ETAT.md et le
        # journal eux-memes : ce sont eux qu'on cherche a voir bouger.
        sales = [l for l in git("status", "--porcelain", racine=racine).splitlines()
                 if l.strip()]
        depasses = []
        for ligne in sales:
            rel = ligne[3:].strip().strip('"')
            if rel in ("ETAT.md", "docs/JOURNAL_INTERVENTIONS.md"):
                continue
            chemin = os.path.join(racine, rel)
            try:
                if os.path.isfile(chemin) and os.path.getmtime(chemin) > plus_recent_suivi:
                    depasses.append(rel)
            except Exception:
                continue

        if len(depasses) < SEUIL:
            return 0

        apercu = ", ".join(sorted(depasses)[:6])
        if len(depasses) > 6:
            apercu += f", … (+{len(depasses) - 6})"

        message = (
            f"FIN D'INTERVENTION — {len(depasses)} fichier(s) modifie(s) APRES la "
            f"derniere mise a jour de l'etat : {apercu}\n"
            f"Avant de rendre la main, mettre a jour :\n"
            f"  - ETAT.md  §1 (ou on en est), §3 (ce qui marche, MESURE), "
            f"§4 (ce qui est casse), §6 (prochain pas)\n"
            f"  - docs/JOURNAL_INTERVENTIONS.md  une ligne par acte : deploiement, "
            f"migration, image, mesure chiffree, decision, defaut, depense\n"
            f"Sans cela, la prochaine intervention repartira de zero — c'est "
            f"exactement le defaut signale le 13/08."
        )

        # `additionalContext` et non `decision: block` : on informe, on n'arrete
        # pas. Voir l'en-tete.
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "Stop",
                "additionalContext": message,
            }
        }))
    except Exception:
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
