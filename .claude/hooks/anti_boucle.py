#!/usr/bin/env python
"""PostToolUse — compte les retouches d'un meme fichier et interrompt la boucle.

LE DEFAUT QU'IL VISE, ET IL EST DOCUMENTE.
`docs/STUDIO_VISUEL_ETAT_2026-08-05.md` recense sept defauts de la meme famille :
« conclure a partir d'une absence ». Le mecanisme est toujours le meme — on
retouche un fichier, on ne mesure pas, on retouche encore. Trois machines RunPod
ont ete perdues ainsi sur un probleme de fins de ligne, corrige deux fois au
mauvais endroit avant d'etre corrige au bon.

Ce hook ne juge pas la qualite d'une modification : il compte. A partir du
quatrieme passage sur le meme fichier sans qu'une commande de verification ait
tourne entre-temps, il le dit. C'est un compteur, pas un censeur.

CONTRAT DE SURETE : n'echoue jamais en bloquant (sortie 0 quoi qu'il arrive).
"""

from __future__ import annotations

import json
import os
import sys
import tempfile

SEUIL_ALERTE = 4      # 4e retouche du meme fichier : on le signale
SEUIL_INSISTANT = 7   # 7e : on le signale beaucoup plus fort

# Les outils qui prouvent qu'on a MESURE quelque chose. Leur passage remet le
# compteur du fichier a zero : retoucher apres avoir mesure est du travail
# normal ; retoucher sans mesurer est une boucle.
PREUVES = (
    "flutter analyze", "flutter test", "dart analyze", "dart test",
    "deno test", "deno check", "pytest", "py_compile",
    "ffprobe", "journalctl", "systemctl status",
)


def etat_chemin(session: str) -> str:
    dossier = os.path.join(tempfile.gettempdir(), "academia_hooks")
    os.makedirs(dossier, exist_ok=True)
    return os.path.join(dossier, f"{session or 'sans_session'}.json")


def lire(chemin: str) -> dict:
    try:
        with open(chemin, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def ecrire(chemin: str, etat: dict) -> None:
    try:
        with open(chemin, "w", encoding="utf-8") as f:
            json.dump(etat, f)
    except Exception:
        pass


def dire(message: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": message,
        }
    }))


def main() -> int:
    try:
        evenement = json.load(sys.stdin)
    except Exception:
        return 0

    try:
        outil = str(evenement.get("tool_name") or "")
        entree = evenement.get("tool_input") or {}
        chemin = etat_chemin(str(evenement.get("session_id") or ""))
        etat = lire(chemin)
        compteurs = etat.setdefault("retouches", {})

        # Une verification a tourne : tout le monde repart de zero.
        if outil == "Bash":
            commande = str(entree.get("command") or "").lower()
            if any(p in commande for p in PREUVES):
                if compteurs:
                    etat["retouches"] = {}
                    ecrire(chemin, etat)
            return 0

        if outil not in ("Edit", "Write", "NotebookEdit", "MultiEdit"):
            return 0

        fichier = str(entree.get("file_path") or entree.get("notebook_path") or "")
        if not fichier:
            return 0

        # Les fichiers de configuration Claude et la documentation ne sont pas
        # du code : on les ecrit d'un trait, les compter n'apprend rien.
        normalise = fichier.replace("\\", "/")
        if "/.claude/" in normalise or "/docs/" in normalise or normalise.endswith(".md"):
            return 0

        n = compteurs.get(fichier, 0) + 1
        compteurs[fichier] = n
        ecrire(chemin, etat)

        court = os.path.basename(fichier)

        if n == SEUIL_ALERTE:
            dire(
                f"ANTI-BOUCLE — {court} vient d'etre modifie {n} fois d'affilee sans "
                f"qu'aucune verification n'ait tourne entre-temps.\n"
                f"C'est le schema exact des sept defauts de "
                f"docs/STUDIO_VISUEL_ETAT_2026-08-05.md : retoucher sans mesurer.\n"
                f"Avant la modification suivante : faire tourner une verification "
                f"(flutter analyze, deno test, pytest...) ou aller LIRE la sortie "
                f"reelle du programme. Si la cause reste inconnue apres cela, le dire "
                f"a Jocelyn plutot que de tenter une cinquieme variante."
            )
        elif n >= SEUIL_INSISTANT:
            dire(
                f"ANTI-BOUCLE — {court} en est a {n} modifications sans mesure. "
                f"Arreter. Ce n'est plus un correctif, c'est une recherche a l'aveugle. "
                f"Enoncer a Jocelyn ce qui est etabli, ce qui ne l'est pas, et ce qu'il "
                f"faudrait mesurer pour trancher."
            )
    except Exception:
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
