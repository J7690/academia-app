#!/usr/bin/env python
"""SessionStart — donne l'etat REEL du depot au demarrage, pas l'etat suppose.

POURQUOI. CLAUDE.md decrit une intention ; il vieillit. Une session qui demarre
sur « le chantier en cours est X » alors que X est termine depuis trois semaines
part sur une fausse piste, et la fausse piste coute plus cher que l'ignorance.
Ce hook n'affirme que ce qu'il vient de mesurer : branche, avance sur origin,
fichiers non commités, et l'etat de mise en sommeil du studio.

IL ANNONCE AUSSI LES ACCES ET LES PROCEDURES OBLIGATOIRES (ajout du 11/08/2026).

Le 11/08, une session entiere a travaille sans le connecteur Supabase sans s'en
apercevoir : `SUPABASE_ACCESS_TOKEN` etait absent, le serveur MCP refusait de
demarrer, et le defaut n'a ete diagnostique qu'apres coup — apres avoir rendu des
conclusions en croyant avoir verifie la base. Un acces manquant doit se savoir a
la premiere seconde, pas a la centieme.

La meme session a rendu un chiffrage de latence faux d'un facteur dix parce que
les moyens n'avaient pas ete releves, et a propose comme neuve une solution deja
tranchee dans le depot. D'ou l'annonce des trois procedures.

CONTRAT DE SURETE : n'echoue jamais en bloquant (sortie 0 quoi qu'il arrive), et
ne fait AUCUN appel reseau ni SSH — un hook lent est un hook qu'on desactive.
Il verifie la PRESENCE d'un jeton, jamais sa valeur.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys


def git(*args: str, racine: str) -> str:
    try:
        r = subprocess.run(("git",) + args, cwd=racine, capture_output=True,
                           text=True, timeout=15)
        return r.stdout.strip()
    except Exception:
        return ""


def _lire(chemin: str, limite: int = 60000) -> str:
    try:
        with open(chemin, encoding="utf-8", errors="replace") as f:
            return f.read(limite)
    except Exception:
        return ""


def sections_de_l_etat(racine: str) -> list[str]:
    """Injecte les sections d'ETAT.md qui decident de la suite.

    On n'injecte PAS le fichier entier : un contexte trop long est un contexte
    survole. Trois sections suffisent a empecher de repartir sur une fausse
    piste — ou on en est, ce qui est casse, quoi ensuite. Le reste se lit a la
    demande, et le chemin est donne.
    """
    chemin = os.path.join(racine, "ETAT.md")
    texte = _lire(chemin)
    if not texte:
        return ["  ETAT.md ABSENT — aucune autorite ne dit ou en est le chantier. "
                "Le reconstituer AVANT d'agir : docs/ contient 219 fichiers et "
                "aucun ne fait foi."]

    voulues = ("1. Ou on en est", "1. Où on en est",
               "4. Ce qui est CASSE", "4. Ce qui est CASSÉ",
               "6. Prochain pas")
    sortie: list[str] = ["  ETAT.md — LE DOCUMENT QUI FAIT FOI (extraits) :"]
    garder = False
    for ligne in texte.splitlines():
        if ligne.startswith("## "):
            titre = ligne[3:].strip()
            garder = any(titre.startswith(v) for v in voulues)
            if garder:
                sortie.append(f"    ── {titre}")
            continue
        if garder and ligne.strip():
            sortie.append("    " + ligne.rstrip())
    sortie.append("    (integral : ETAT.md — il PRIME sur CLAUDE.md et sur docs/)")
    return sortie


def dernieres_lignes_du_journal(racine: str, combien: int = 8) -> list[str]:
    """Les derniers actes poses. « Ce qui a ete fait » ne se devine pas."""
    chemin = os.path.join(racine, "docs", "JOURNAL_INTERVENTIONS.md")
    texte = _lire(chemin)
    if not texte:
        return []
    # Un acte peut tenir sur plusieurs lignes physiques : on recolle les
    # continuations, sinon le journal s'affiche tronque en pleine phrase — et
    # une trace tronquee se relit comme une trace fausse.
    actes: list[str] = []
    for ligne in texte.splitlines():
        nue = ligne.strip()
        if nue.startswith("- ") and "·" in nue:
            actes.append(nue)
        elif actes and nue and not nue.startswith(("#", ">", "-", "|")):
            actes[-1] += " " + nue
    if not actes:
        return []
    return (["  DERNIERS ACTES POSES (docs/JOURNAL_INTERVENTIONS.md) :"]
            + ["  " + a for a in actes[:combien]])


def fraicheur_de_l_etat(racine: str, sales: list[str]) -> list[str]:
    """ETAT.md est-il plus vieux que le travail qu'il pretend decrire ?

    C'est le seul controle qui rende la mise a jour VERIFIABLE plutot que
    promise. Un document d'etat qui vieillit en silence redevient CLAUDE.md.
    """
    etat = os.path.join(racine, "ETAT.md")
    if not os.path.exists(etat) or not sales:
        return []
    try:
        age_etat = os.path.getmtime(etat)
    except Exception:
        return []

    plus_recents = 0
    for ligne in sales:
        rel = ligne[3:].strip().strip('"')
        chemin = os.path.join(racine, rel)
        try:
            if os.path.isfile(chemin) and os.path.getmtime(chemin) > age_etat:
                plus_recents += 1
        except Exception:
            continue

    if plus_recents >= 3:
        return [f"  ETAT.md EST EN RETARD : {plus_recents} fichier(s) modifie(s) "
                f"APRES lui. Le mettre a jour fait partie du travail, pas de sa "
                f"conclusion."]
    return []


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

        # ── LE GRAND CONTEXTE, RELU A CHAQUE INTERVENTION ─────────────────
        #
        # Ce bloc remplace une phrase codee en dur qui annoncait « STUDIO VISUEL :
        # en sommeil depuis le 05/08 ». Elle etait FAUSSE depuis le 05/08 lui-meme,
        # et elle a ete servie a chaque demarrage pendant huit jours. Un hook qui
        # recite une constante n'est pas une mesure : c'est CLAUDE.md deguise en
        # instrument.
        #
        # On lit donc ETAT.md, qui fait foi, et on en injecte les sections qui
        # decident de la suite : ou on en est, ce qui est casse, quoi ensuite.
        lignes.extend(sections_de_l_etat(racine))
        lignes.extend(dernieres_lignes_du_journal(racine))
        lignes.extend(fraicheur_de_l_etat(racine, sales))

        if len(sales) > 15:
            lignes.append(
                f"  ATTENTION : {len(sales)} fichiers non commités. Etablir ce qu'ils "
                f"contiennent AVANT de modifier quoi que ce soit — sans quoi une "
                f"regression sera indiscernable du travail deja en cours."
            )

        # ── ACCES ET OUTILS ───────────────────────────────────────────────
        # Verifie la PRESENCE, jamais la valeur. Aucun appel reseau : ce qui
        # est teste ici doit couter des millisecondes.
        manquants = []
        if not (os.environ.get("SUPABASE_ACCESS_TOKEN") or "").strip():
            manquants.append(
                "SUPABASE_ACCESS_TOKEN absent — le serveur MCP `supabase-lecture` "
                "NE DEMARRE PAS. Toute affirmation sur l'etat de la base est alors "
                "une supposition. Jocelyn doit le definir dans son environnement "
                "(cf. .mcp.json) ; ne jamais le demander en conversation.")
        for outil, pourquoi in (
            ("deno", "les tests de `whiteboard-generate-storyboard` ne peuvent pas etre executes"),
            ("flutter", "aucune compilation ni `flutter analyze` possible"),
        ):
            if shutil.which(outil) is None:
                manquants.append(f"{outil} absent — {pourquoi}")
        if manquants:
            lignes.append("  ACCES ET OUTILS MANQUANTS (releve a l'instant) :")
            lignes.extend(f"    - {m}" for m in manquants)

        # ── PROCEDURES OBLIGATOIRES ───────────────────────────────────────
        # Elles existent parce que chacune repare une faute reellement commise.
        lignes.append(
            "  PROCEDURES OBLIGATOIRES — charger la competence AVANT de conclure :\n"
            "    - `etat-des-moyens`        avant tout chiffrage de latence, de cout "
            "ou de capacite, et avant tout « on ne peut pas » / « il faudrait installer »\n"
            "    - `continuite-du-chantier` avant toute proposition touchant une couche "
            "non ecrite dans la seance (le depot contient des decisions motivees)\n"
            "    - `veille-externe`         avant toute decision d'architecture ou de "
            "composant : croiser litterature, plateformes, depots — puis REFUTER\n"
            "    - `studio-visuel-3d`       pour toute tache touchant studio_visuel/\n"
            "    - `ou-tourne-le-code`      avant tout « c'est corrige » / « c'est deploye » : "
            "trois machines, trois codes — LWS a tourne six jours en retard sans que ca se voie\n"
            "    - `tracer-la-valeur`       des qu'un symptome survit a un correctif, et AVANT "
            "toute deuxieme variante du meme correctif (le meme defaut s'est cache a huit couches)"
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
