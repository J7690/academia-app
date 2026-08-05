#!/usr/bin/env python
"""PreToolUse — refuse les commandes qui liraient un secret ou toucheraient au reseau.

POURQUOI UN HOOK EN PLUS DES REGLES `deny`.
Les regles `deny` de settings.json filtrent sur la FORME de la commande. Un
`deny` sur `Bash(cat ~/.ssh/*)` ne voit pas passer `base64 ~/.ssh/id_ed25519`,
ni `ssh lws-nexiom "cat ~/.ssh/id_ed25519"`, ni un `tar` de tout le repertoire.
Ce hook regarde le CONTENU de la ligne de commande, quel que soit l'outil.

CLAUDE.md dit : « ne jamais lire ni committer la cle » et « ne touche pas au
pare-feu ». Ces deux phrases sont ici rendues executoires.

CONTRAT DE SURETE : en cas d'erreur interne, ce hook LAISSE PASSER (sortie 0).
Un garde-fou qui casse la session est un garde-fou qu'on desactive. Il ne
bloque que sur une correspondance positive et explicite.
"""

from __future__ import annotations

import json
import re
import sys

# Lecture d'une cle privee, sous n'importe quelle forme. On vise le NOM du
# fichier, pas la commande : c'est ce qui resiste aux variantes.
CLES_PRIVEES = re.compile(
    r"(id_ed25519(?!\.pub)|id_rsa(?!\.pub)|id_ecdsa(?!\.pub)"
    r"|\.ssh/[A-Za-z0-9_.-]*(?<!\.pub)\s*$"
    r"|-----BEGIN[A-Z ]*PRIVATE KEY-----)",
    re.IGNORECASE,
)

# Une cle publique, un `ssh-add -L`, un `chmod` : legitimes. On ne bloque que
# si la commande a l'air de vouloir en LIRE le contenu.
LECTURE = re.compile(
    r"\b(cat|less|more|head|tail|bat|base64|xxd|od|strings|cp|scp|curl|"
    r"tar|zip|gzip|type|Get-Content|gc)\b",
    re.IGNORECASE,
)

# CLAUDE.md : « Aucun port entrant n'est necessaire : ne touche pas au
# pare-feu. » Le worker sort vers Supabase en polling.
#
# EXIGE LA POSITION DE COMMANDE. Une premiere version cherchait le simple mot
# `ufw` n'importe ou dans la ligne : elle a bloque son propre test, et aurait
# bloque un `journalctl | grep ufw` parfaitement legitime. Un garde-fou qui
# mord sur du texte innocent finit desactive, donc inutile. On n'accepte donc
# la correspondance qu'en DEBUT de segment de commande : debut de chaine, ou
# apres ; && || | ( ou l'ouverture d'un `ssh hote "`.
PARE_FEU = re.compile(
    r"(?:^|[;&|(]|\bsudo\s+|[\"']\s*)\s*"
    r"(ufw|iptables|nft|firewall-cmd|netsh\s+advfirewall)\b",
    re.IGNORECASE,
)

# Ecrire un secret dans un fichier suivi par git est l'autre moitie du risque.
FUITE = re.compile(
    r"(SUPABASE_SERVICE_ROLE|service_role|RUNPOD_API_KEY|sk-or-v1-|hf_[A-Za-z0-9]{20,})",
)


def refuser(motif: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": motif,
        }
    }))
    sys.exit(0)


def main() -> int:
    try:
        evenement = json.load(sys.stdin)
    except Exception:
        return 0  # fail-open, cf. contrat de surete

    try:
        entree = evenement.get("tool_input") or {}
        commande = str(entree.get("command") or "")
        if not commande:
            return 0

        if PARE_FEU.search(commande):
            refuser(
                "Regle du projet (CLAUDE.md §3) : ne pas toucher au pare-feu. "
                "Le worker LWS SORT vers Supabase en polling ; aucun port entrant "
                "n'est necessaire. Si une ouverture est vraiment requise, elle se "
                "decide avec Jocelyn, pas dans une commande."
            )

        if CLES_PRIVEES.search(commande) and LECTURE.search(commande):
            refuser(
                "Regle du projet (CLAUDE.md §3) : ne jamais lire la cle privee SSH. "
                "Pour verifier qu'une cle existe ou ses droits, utiliser `ls -l` ou "
                "`Get-Acl` — jamais une commande qui en lit le contenu."
            )

        if FUITE.search(commande):
            refuser(
                "Cette commande contient ce qui ressemble a un secret en clair "
                "(service_role, cle RunPod, OpenRouter ou HuggingFace). Les secrets "
                "passent par les variables d'environnement ou les secrets Supabase, "
                "jamais par une ligne de commande — elle est journalisee."
            )
    except Exception:
        return 0  # fail-open

    return 0


if __name__ == "__main__":
    sys.exit(main())
