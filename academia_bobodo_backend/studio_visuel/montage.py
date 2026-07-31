"""Montage d'une capsule : sous-titres incrustes, audio, encodage final.

POURQUOI LES SOUS-TITRES PASSENT AVANT LA VOIX. Entre 60 et 85 % des videos
verticales courtes sont regardees SANS LE SON sur TikTok et Reels, et les
sous-titres incrustes augmentent la retention de 15 a 25 %. Une narration,
aussi belle soit-elle, n'est entendue que par une minorite ; le texte, lui, est
lu par tout le monde. C'est le meilleur rapport valeur/effort de toute la
chaine -- et il ne coute aucun GPU.

POURQUOI L'ACCROCHE COMPTE AUTANT. 50 a 60 % des abandons se produisent dans
les TROIS PREMIERES SECONDES. Les plateformes mesurent la « retention d'intro »
et les meilleurs createurs tiennent 70 %. Une capsule qui s'ouvre sur un fondu
lent a deja perdu la moitie de son audience avant d'avoir commence.

Tout ce module tourne sur CPU. Il peut donc vivre sur LWS comme le prevoit le
cahier des charges, ou sur le pod juste apres le rendu -- ce qui evite de
transferer 800 images pour n'en assembler qu'une video.
"""

from __future__ import annotations

import os
import subprocess

# Zone basse protegee : le cahier des charges l'impose, et les interfaces de
# TikTok/Reels recouvrent le bas de l'ecran de boutons. Un sous-titre colle en
# bas est un sous-titre illisible.
PROPORTION_CINEMA = 0.62


def _echapper(texte: str) -> str:
    return str(texte).replace("\\", "").replace("{", "").replace("}", "").strip()


def _envelopper(texte: str, largeur_max: int) -> list[str]:
    mots = texte.split()
    lignes: list[str] = []
    courante = ""
    for mot in mots:
        essai = f"{courante} {mot}".strip()
        if len(essai) <= largeur_max or not courante:
            courante = essai
        else:
            lignes.append(courante)
            courante = mot
    if courante:
        lignes.append(courante)
    return lignes


def _decouper(texte: str) -> list[str]:
    """Deux lignes maximum, comme le prescrit le cahier des charges.

    Un sous-titre de trois lignes mange l'image et se lit mal en vertical.
    On elargit donc progressivement la ligne jusqu'a ce que la phrase tienne
    en deux -- plutot que de tronquer, ce qui ferait disparaitre du sens, ou
    d'empiler trois lignes, ce qui recouvre l'animation.
    """
    propre = _echapper(texte)
    for largeur in (42, 50, 58, 66):
        lignes = _envelopper(propre, largeur)
        if len(lignes) <= 2:
            return lignes
    # Phrase vraiment trop longue : on equilibre en deux lignes plutot que de
    # perdre la fin. C'est le storyboard qu'il faudra raccourcir.
    milieu = len(propre) // 2
    coupe = propre.rfind(" ", 0, milieu) or milieu
    return [propre[:coupe].strip(), propre[coupe:].strip()]


def _temps_ass(secondes: float) -> str:
    heures = int(secondes // 3600)
    minutes = int((secondes % 3600) // 60)
    reste = secondes % 60
    return f"{heures}:{minutes:02d}:{reste:05.2f}"


def ecrire_sous_titres(capsule: dict, chemin_ass: str) -> int:
    """Ecrit un fichier ASS. Pas du SRT : le SRT ne permet pas de fixer la
    police, la taille, le contour ni la position, et c'est precisement ce qui
    fait qu'un sous-titre est lu ou ignore.

    Renvoie le nombre de sous-titres ecrits.
    """
    hauteur = capsule["format"]["hauteur"]
    largeur = capsule["format"]["largeur"]

    # Le sous-titre doit tomber DANS la bande cinema, pas dans la bande noire.
    bas_bande = hauteur * (1 - PROPORTION_CINEMA) / 2
    marge_basse = int(bas_bande + hauteur * 0.09)

    taille = max(34, int(hauteur * 0.030))
    contour = max(2, int(taille * 0.10))

    entetes = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {largeur}
PlayResY: {hauteur}
WrapStyle: 2
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, OutlineColour, BackColour, Bold, Italic, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Academia,DejaVu Sans,{taille},&H00FFFFFF,&H00000000,&H80000000,-1,0,1,{contour},1,2,{int(largeur*0.07)},{int(largeur*0.07)},{marge_basse},1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""

    lignes: list[str] = []
    horloge = 0.0
    ecrits = 0

    for scene in capsule["scenes"]:
        duree = float(scene["duree_s"])
        narration = _echapper(scene.get("narration") or "")
        if narration:
            # Un sous-titre par phrase : on suit le rythme de la parole plutot
            # que d'afficher un pave pendant huit secondes.
            phrases = [p.strip() for p in narration.replace("!", ".").replace("?", ".").split(".")
                       if p.strip()]
            if not phrases:
                phrases = [narration]
            total_signes = sum(len(p) for p in phrases) or 1
            debut = horloge
            for phrase in phrases:
                part = len(phrase) / total_signes
                fin = debut + duree * part
                texte = "\\N".join(_decouper(phrase))
                lignes.append(
                    f"Dialogue: 0,{_temps_ass(debut)},{_temps_ass(fin)},Academia,,0,0,0,,{texte}")
                ecrits += 1
                debut = fin
        horloge += duree

    with open(chemin_ass, "w", encoding="utf-8") as f:
        f.write(entetes + "\n".join(lignes) + "\n")
    return ecrits


def assembler(dossier_images: str, capsule: dict, sortie: str,
              chemin_ass: str | None = None, audio: str | None = None) -> tuple[bool, str]:
    """Assemble la sequence en MP4, sous-titres incrustes.

    Trois choix d'encodage qui ne sont pas des details :
      * `yuv420p` : sans lui, les reseaux sociaux refusent purement et
        simplement la video ;
      * `+faststart` : sans lui la lecture ne demarre qu'apres telechargement
        complet -- fatal sur une connexion lente, c'est-a-dire notre public ;
      * `crf 20` avec `preset slow` : la qualite tient a debit contenu, ce qui
        compte quand l'abonne paie ses donnees mobiles.
    """
    fps = capsule["format"]["fps"]
    scenes = capsule["scenes"]

    # Les images sont nommees par scene ; on les concatene dans l'ordre du
    # storyboard via un fichier de liste, pour ne pas dependre d'une
    # numerotation globale continue.
    liste = os.path.join(os.path.dirname(sortie) or ".", "sequence.txt")
    # CHEMINS ABSOLUS, TOUJOURS. ffmpeg resout les chemins relatifs d'une liste
    # de concatenation par rapport au FICHIER DE LISTE, pas au repertoire
    # courant. Le defaut ne se manifeste que si l'appelant passe un chemin
    # relatif -- il a donc survecu a tous les essais, tous faits en absolu.
    racine = os.path.abspath(dossier_images)
    with open(liste, "w", encoding="utf-8") as f:
        fichiers: list[str] = []
        for scene in scenes:
            prefixe = scene["id"] + "_"
            fichiers = sorted(n for n in os.listdir(dossier_images)
                              if n.startswith(prefixe) and n.endswith(".png"))
            for nom in fichiers:
                f.write(f"file '{os.path.join(racine, nom)}'\n")
                f.write(f"duration {1.0 / fps}\n")
        # La derniere image est repetee : sans elle, ffmpeg ignore la duree du
        # dernier element et la video se termine une image trop tot.
        if fichiers:
            f.write(f"file '{os.path.join(racine, fichiers[-1])}'\n")

    filtres = []
    if chemin_ass and os.path.isfile(chemin_ass):
        # Le chemin passe dans un filtre ffmpeg : les deux-points et les
        # antislashs doivent etre neutralises, sinon le filtre est mal lu.
        echappe = chemin_ass.replace("\\", "/").replace(":", "\\:")
        filtres.append(f"subtitles='{echappe}'")

    commande = ["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", liste]
    if audio and os.path.isfile(audio):
        commande += ["-i", audio]
    if filtres:
        commande += ["-vf", ",".join(filtres)]
    commande += [
        "-r", str(fps),
        "-c:v", "libx264", "-preset", "slow", "-crf", "20",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart",
    ]
    if audio and os.path.isfile(audio):
        commande += ["-c:a", "aac", "-b:a", "160k", "-shortest"]
    commande.append(sortie)

    resultat = subprocess.run(commande, capture_output=True, text=True, timeout=3600)
    if resultat.returncode != 0 or not os.path.isfile(sortie):
        return False, resultat.stderr[-400:]
    return True, ""


def verifier(chemin: str) -> dict:
    """Controle automatique, comme le prevoit l'etape 10 du cahier des charges.

    Une video corrompue qui passe la chaine sans alerte est pire qu'un echec
    franc : elle arrive chez l'abonne.
    """
    sortie = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries",
         "format=duration,size:stream=codec_name,width,height,r_frame_rate",
         "-of", "default=noprint_wrappers=1", chemin],
        capture_output=True, text=True)
    infos: dict[str, str] = {}
    for ligne in sortie.stdout.splitlines():
        if "=" in ligne:
            cle, valeur = ligne.split("=", 1)
            infos[cle.strip()] = valeur.strip()
    infos["lisible"] = str(sortie.returncode == 0 and bool(infos.get("duration")))
    return infos
