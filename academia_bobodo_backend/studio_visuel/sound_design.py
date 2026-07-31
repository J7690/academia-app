"""Sound design du Studio visuel — entierement synthetise, rien d'externe.

DECISION DU 30/07 : aucun abonnement a une bibliotheque musicale. Tout est
fabrique par ffmpeg a partir d'oscillateurs et de bruit. Trois consequences,
toutes bonnes :

  * aucune licence a negocier, aucun catalogue a payer ;
  * ce que nous produisons NOUS APPARTIENT reellement -- contrairement a une
    musique generee par IA, qui n'est protegee par aucun droit d'auteur dans la
    plupart des juridictions en 2026 et reste soumise aux conditions du
    fournisseur ;
  * c'est deterministe : la meme capsule sonne toujours pareil.

Le Smart Whiteboard procede deja ainsi pour ses seize bruitages. On reprend le
principe, avec une nappe adaptee au style sombre du Studio.

Trois regles de mixage qui font la difference entre « fini » et « amateur » :

  1. LA MUSIQUE S'EFFACE SOUS LA VOIX. `sidechaincompress` l'abaisse
     automatiquement des que la narration parle, et la laisse remonter dans les
     silences. Sans ca, il faut choisir entre une musique inaudible et une voix
     couverte.
  2. LES ACCENTS SONNENT SUR LES CHANGEMENTS, pas au hasard. Un souffle a
     chaque transition de scene : l'oreille anticipe la coupe, et le montage
     cesse de paraitre hache.
  3. LE NIVEAU EST BORNE. La nappe reste vingt fois sous la voix. Une musique
     qu'on remarque pendant une explication est une musique trop forte.
"""

from __future__ import annotations

import os
import subprocess

# Volumes relatifs a la voix, mesures a l'oreille sur le Smart Whiteboard.
VOL_NAPPE = 0.055
VOL_SOUFFLE = 0.22
VOL_IMPACT = 0.30

# Au-dela, ffmpeg devient instable et l'oreille sature. Un cours n'est pas un
# clip : la sobriete est un choix, pas une limite technique.
MAX_EVENEMENTS = 40


def _ffmpeg(args: list[str], delai: int = 300) -> bool:
    try:
        r = subprocess.run(["ffmpeg", "-y", "-v", "error", *args],
                           capture_output=True, text=True, timeout=delai)
        return r.returncode == 0
    except Exception:  # noqa: BLE001
        return False


def nappe(duree_s: float, sortie: str) -> bool:
    """Une nappe sombre : bourdon grave, quinte, et un souffle d'air.

    Les frequences ne sont pas prises au hasard -- 55 Hz (la), 82,4 (mi),
    110 (la) forment une quinte a l'octave, l'accord le plus stable qui soit.
    Il ne raconte rien et n'entre en conflit avec aucune musique que
    l'utilisateur pourrait ajouter ensuite : c'est exactement ce qu'on demande
    a une nappe pedagogique.

    Le tremolo tres lent evite l'effet « bourdonnement de frigo » d'un sinus
    parfaitement tenu.
    """
    d = max(1.0, duree_s)
    return _ffmpeg([
        "-f", "lavfi", "-i", f"sine=frequency=55:duration={d}",
        "-f", "lavfi", "-i", f"sine=frequency=82.41:duration={d}",
        "-f", "lavfi", "-i", f"sine=frequency=110:duration={d}",
        "-f", "lavfi", "-i", f"anoisesrc=d={d}:color=brown:amplitude=0.5",
        "-filter_complex",
        "[0:a]volume=0.5[a];"
        "[1:a]volume=0.30[b];"
        "[2:a]volume=0.18[c];"
        # Le souffle est filtre tres bas : il ajoute de l'air sans siffler.
        "[3:a]lowpass=f=520,volume=0.22[d];"
        "[a][b][c][d]amix=inputs=4:normalize=0[m];"
        "[m]tremolo=f=0.12:d=0.35,lowpass=f=1400,"
        f"afade=t=in:d=1.6,afade=t=out:st={max(0.0, d - 2.2):.2f}:d=2.2[out]",
        "-map", "[out]", "-ar", "48000", "-ac", "1", sortie,
    ])


def _banque(dossier: str) -> dict[str, str]:
    """Synthetise les accents une fois, puis les reutilise."""
    os.makedirs(dossier, exist_ok=True)
    recettes = {
        # Souffle de transition : bruit filtre en bande, monte et redescend.
        "souffle.wav": [
            "-f", "lavfi", "-i", "anoisesrc=d=0.7:color=pink:amplitude=0.8",
            "-af", "bandpass=f=750:w=900,afade=t=in:d=0.30,afade=t=out:st=0.34:d=0.36",
        ],
        # Impact de revelation : grave court, amorti vite. C'est le son qui
        # dit « regarde ici » sans crier.
        "impact.wav": [
            "-f", "lavfi", "-i", "sine=frequency=110:duration=0.35",
            "-af", "afade=t=in:d=0.004,afade=t=out:st=0.06:d=0.29,volume=1.2",
        ],
        # Scintillement : aigu tres bref, pour l'apparition d'un element fin.
        "scintille.wav": [
            "-f", "lavfi", "-i", "sine=frequency=2100:duration=0.20",
            "-af", "afade=t=in:d=0.006,afade=t=out:st=0.03:d=0.17,volume=0.55",
        ],
    }
    obtenus: dict[str, str] = {}
    for nom, args in recettes.items():
        chemin = os.path.join(dossier, nom)
        if os.path.isfile(chemin) or _ffmpeg([*args, "-ar", "48000", "-ac", "1", chemin], 90):
            obtenus[nom.replace(".wav", "")] = chemin
    return obtenus


def _evenements(capsule: dict) -> list[tuple[str, float]]:
    """Ou placer les accents. Sur les CHANGEMENTS, jamais au hasard.

    Un souffle juste avant chaque transition : l'oreille anticipe la coupe, et
    le montage cesse de paraitre hache. Un impact au tout debut : c'est
    l'accroche, et les trois premieres secondes decident de la moitie de
    l'audience.
    """
    evenements: list[tuple[str, float]] = [("impact", 0.15)]
    horloge = 0.0
    for indice, scene in enumerate(capsule["scenes"]):
        if indice > 0:
            # Legerement AVANT la coupe : un son qui arrive apres l'image est
            # percu comme un defaut de synchronisation.
            evenements.append(("souffle", max(0.0, horloge - 0.28)))
        if scene["archetype"] in ("titre", "silhouette", "comparaison"):
            evenements.append(("scintille", horloge + scene["duree_s"] * 0.42))
        horloge += scene["duree_s"]
    return evenements[:MAX_EVENEMENTS]


def melanger(voix: str | None, capsule: dict, dossier: str, sortie: str) -> tuple[bool, str]:
    """Voix + nappe attenuee + accents, en une seule passe ffmpeg.

    Degradation gracieuse a chaque etage : sans voix on garde la nappe, sans
    nappe on garde la voix, et si tout echoue on renvoie la voix telle quelle.
    Une capsule au son imparfait vaut mieux qu'une capsule sans son.
    """
    duree = float(capsule.get("duree_totale_s") or 0) or sum(
        s["duree_s"] for s in capsule["scenes"])

    chemin_nappe = os.path.join(dossier, "nappe.wav")
    if not nappe(duree, chemin_nappe):
        if voix and os.path.isfile(voix):
            return True, voix
        return False, "nappe_et_voix_indisponibles"

    banque = _banque(os.path.join(dossier, "sfx"))
    evenements = [(n, t) for n, t in _evenements(capsule) if n in banque]

    entrees: list[str] = []
    filtres: list[str] = []
    a_melanger: list[str] = []
    indice = 0

    if voix and os.path.isfile(voix):
        entrees += ["-i", voix]
        indice_voix = indice
        indice += 1
    else:
        indice_voix = None

    entrees += ["-i", chemin_nappe]
    indice_nappe = indice
    indice += 1

    if indice_voix is not None:
        # LA REGLE CENTRALE : la nappe s'abaisse des que la voix parle, et
        # remonte dans les silences. Sans ce reglage il faut choisir entre une
        # musique inaudible et une voix couverte.
        filtres.append(
            f"[{indice_nappe}:a]volume={VOL_NAPPE}[n0];"
            f"[{indice_voix}:a]asplit=2[v1][vsc];"
            f"[n0][vsc]sidechaincompress=threshold=0.02:ratio=9:attack=15:release=380[nd]")
        a_melanger += ["[v1]", "[nd]"]
    else:
        filtres.append(f"[{indice_nappe}:a]volume={VOL_NAPPE}[nd]")
        a_melanger.append("[nd]")

    for rang, (nom, instant) in enumerate(evenements):
        entrees += ["-i", banque[nom]]
        volume = VOL_IMPACT if nom == "impact" else VOL_SOUFFLE
        filtres.append(
            f"[{indice}:a]adelay={int(instant * 1000)}|{int(instant * 1000)},"
            f"volume={volume}[e{rang}]")
        a_melanger.append(f"[e{rang}]")
        indice += 1

    filtres.append(
        "".join(a_melanger) +
        f"amix=inputs={len(a_melanger)}:normalize=0:dropout_transition=0[mix];"
        # Un dernier loudnorm : le niveau final doit etre le meme d'une capsule
        # a l'autre, sinon l'abonne touche son volume a chaque video.
        "[mix]loudnorm=I=-16:TP=-1.5:LRA=11[out]")

    ok = _ffmpeg([
        *entrees, "-filter_complex", ";".join(filtres),
        "-map", "[out]", "-t", f"{duree:.3f}",
        "-ar", "48000", "-ac", "2", sortie,
    ], 900)

    if not ok or not os.path.isfile(sortie):
        if voix and os.path.isfile(voix):
            return True, voix          # repli : la voix seule
        return False, "melange_impossible"
    return True, sortie
