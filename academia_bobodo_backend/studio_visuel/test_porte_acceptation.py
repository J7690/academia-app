#!/usr/bin/env python3
"""Prouve que la porte d'acceptation attrape chaque defaut, un par un.

POURQUOI CE TEST EXISTE. Une porte de controle qui n'a jamais vu passer un
defaut ne prouve rien. Le 05/08, une capsule noire et muette a ete livree a un
etudiant comme « prete » : le controle existait deja, il ne mesurait tout
simplement pas ce qui manquait.

Chaque cas ci-dessous FABRIQUE la maladie avec ffmpeg, puis verifie que la
porte la nomme. Ce ne sont pas des exemples : ce sont les quatre defauts
reellement observes.

    noire        capsule livree noire a un etudiant       (05/08)
    muette       `a_du_son` repond True sur du silence    (05/08)
    tronquee     « l'univers » : 908 images sur 1924      (07/08, app.studio_jobs)
    figee        le rendu s'arrete, la camera non         (par construction)

Usage : python3 test_porte_acceptation.py
Exige : ffmpeg et ffprobe dans le PATH.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import montage  # noqa: E402

LARGEUR, HAUTEUR, FPS, DUREE = 216, 384, 25, 4
# Le cadre cinema rend 62 % de la hauteur et laisse le reste noir : on le
# reproduit, sinon on mesurerait autre chose que ce que mesure la production.
UTILE = int(HAUTEUR * montage.PROPORTION_CINEMA)          # 238
MARGE = (HAUTEUR - UTILE) // 2                            # 73


def _ffmpeg(args: list[str]) -> None:
    r = subprocess.run(["ffmpeg", "-y", "-v", "error", *args],
                       capture_output=True, text=True, timeout=180)
    if r.returncode != 0:
        raise RuntimeError(f"ffmpeg a echoue : {r.stderr[-300:]}")


def fabriquer(chemin: str, image: str = "anime", son: str = "voix",
              duree: int = DUREE) -> str:
    """Fabrique une capsule d'essai. `image` et `son` choisissent la maladie."""
    sources, filtres = [], []

    if image == "anime":
        sources += ["-f", "lavfi", "-i",
                    f"testsrc2=s={LARGEUR}x{UTILE}:r={FPS}:d={duree}"]
    elif image == "figee":
        # Une seule image tenue : c'est le rendu qui s'est arrete.
        sources += ["-f", "lavfi", "-i",
                    f"color=c=0x2050c0:s={LARGEUR}x{UTILE}:r={FPS}:d={duree}"]
    elif image == "noire":
        sources += ["-f", "lavfi", "-i",
                    f"color=c=black:s={LARGEUR}x{UTILE}:r={FPS}:d={duree}"]
    elif image == "grise":
        sources += ["-f", "lavfi", "-i",
                    f"color=c=0x3a3a3a:s={LARGEUR}x{UTILE}:r={FPS}:d={duree}"]
    filtres.append(f"[0:v]pad={LARGEUR}:{HAUTEUR}:0:{MARGE}:black[v]")

    args = list(sources)
    audio = []
    if son == "voix":
        args += ["-f", "lavfi", "-i",
                 f"sine=frequency=320:sample_rate=44100:d={duree}"]
        audio = ["-map", "1:a", "-c:a", "aac"]
    elif son == "silence":
        # Une piste QUI EXISTE et ne contient rien : le cas que `a_du_son` rate.
        args += ["-f", "lavfi", "-i", f"anullsrc=r=44100:cl=mono:d={duree}"]
        audio = ["-map", "1:a", "-c:a", "aac"]

    _ffmpeg([*args, "-filter_complex", ";".join(filtres), "-map", "[v]",
             *audio, "-c:v", "libx264", "-preset", "ultrafast", "-crf", "26",
             "-pix_fmt", "yuv420p", "-t", str(duree), chemin])
    return chemin


def capsule(duree_attendue: float = DUREE, scenes: bool = True) -> dict:
    return {
        "duree_totale_s": duree_attendue,
        "scenes": ([{"id": "s1", "archetype": "reseau", "duree_s": duree_attendue}]
                   if scenes else []),
    }


# ── Les cas ───────────────────────────────────────────────────────────────

# `motif` attendu dans les REFUS ; `alerte` attendue dans les alertes.
# Le son est volontairement une ALERTE et non un refus : `executer_capsule` a
# tranche qu'une capsule muette reste regardable -- les sous-titres sont
# incrustes, et la majorite des vues se font sans le son. Ce que le test
# verifie, c'est que le silence est DETECTE, pas qu'il bloque.
CAS = [
    # (nom, image, son, duree_video, duree_attendue, doit_accepter, motif, alerte)
    ("capsule correcte",         "anime", "voix",    DUREE, DUREE, True,  None,       None),
    ("capsule NOIRE",            "noire", "voix",    DUREE, DUREE, False, "noire",    None),
    ("capsule TRONQUEE",         "anime", "voix",    DUREE, 10.0,  False, "tronquee", None),
    ("capsule FIGEE",            "figee", "voix",    DUREE, DUREE, False, "figee",    None),
    ("capsule MUETTE",           "anime", "silence", DUREE, DUREE, True,  None,       "muette"),
    ("capsule SANS PISTE AUDIO", "anime", "aucun",   DUREE, DUREE, True,  None,       "aucune piste audio"),
]


def main() -> int:
    dossier = tempfile.mkdtemp(prefix="porte_")
    echecs = 0

    print(f"Porte d'acceptation - {len(CAS)} cas")
    print("=" * 66)
    for nom, image, son, duree_v, duree_a, doit_accepter, motif, alerte in CAS:
        chemin = os.path.join(dossier, f"{image}_{son}_{duree_a:g}.mp4")
        if not os.path.isfile(chemin):
            fabriquer(chemin, image=image, son=son, duree=duree_v)

        verdict = montage.porte_acceptation(chemin, capsule(duree_a))
        accepte = verdict["accepte"]
        motifs = " | ".join(verdict["refus"]) or "(aucun)"
        avis = " | ".join(verdict["alertes"]) or "(aucune)"

        ok = (accepte == doit_accepter)
        if ok and motif:
            ok = any(motif in r for r in verdict["refus"])
        if ok and alerte:
            ok = any(alerte in a for a in verdict["alertes"])

        etat = "ok  " if ok else "ECHEC"
        if doit_accepter:
            attendu = f"accepter + alerte({alerte})" if alerte else "accepter"
        else:
            attendu = f"refuser ({motif})"
        print(f"[{etat}] {nom:28s} attendu={attendu:34s} "
              f"obtenu={'accepte' if accepte else 'refuse'}")
        if not ok:
            echecs += 1
            print(f"         refus   : {motifs}")
            print(f"         alertes : {avis}")
            print(f"         mesures : {verdict['mesures']}")
        elif not accepte:
            print(f"         -> refuse : {motifs}")
        else:
            m = verdict["mesures"]
            print(f"         -> luminosite={m['luminosite']} niveau={m['niveau_db']}dB "
                  f"fige={m['duree_figee_s']}s part={m.get('part_produite')}")
            if verdict["alertes"]:
                print(f"         -> alerte : {avis}")

    print("=" * 66)
    print(f"{len(CAS) - echecs}/{len(CAS)} cas conformes")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
