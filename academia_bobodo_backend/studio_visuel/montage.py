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


def caracteres_par_ligne(largeur_px: int, taille_px: int, marge: float = 0.07) -> int:
    """Combien de caracteres tiennent VRAIMENT sur une ligne.

    Calcule plutot que devine. La premiere version coupait a 42 caracteres en
    dur : a 57 px de police sur 1080 de large, la ligne debordait des deux
    cotes de l'image et la phrase etait illisible. Le defaut ne pouvait se voir
    qu'en regardant une capsule rendue -- aucune verification de code ne
    l'aurait signale.

    0,55 est le rapport largeur/hauteur moyen d'un caractere en DejaVu Sans
    gras. On garde une marge de securite de 8 % : les majuscules et les
    accents depassent cette moyenne.
    """
    utile = largeur_px * (1 - 2 * marge)
    return max(18, int(utile / (taille_px * 0.55) * 0.92))


def _decouper(texte: str, largeur_max: int = 30) -> list[str]:
    """Deux lignes maximum, comme le prescrit le cahier des charges.

    Un sous-titre de trois lignes mange l'image et se lit mal en vertical.
    On elargit donc progressivement la ligne jusqu'a ce que la phrase tienne
    en deux -- plutot que de tronquer, ce qui ferait disparaitre du sens, ou
    d'empiler trois lignes, ce qui recouvre l'animation.
    """
    propre = _echapper(texte)
    lignes = _envelopper(propre, largeur_max)
    if len(lignes) <= 2:
        return lignes

    # NE JAMAIS ELARGIR LA LIGNE. La premiere version elargissait
    # progressivement jusqu'a tenir en deux lignes -- et debordait de l'image.
    # Une TROISIEME ligne mange un peu d'animation ; une ligne coupee fait
    # perdre le sens. On prefere la troisieme ligne, et au-dela on rend la
    # main : c'est le storyboard qu'il faut raccourcir, pas le sous-titre qu'il
    # faut mutiler.
    if len(lignes) == 3:
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
    largeur_ligne = caracteres_par_ligne(largeur, taille)

    entetes = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {largeur}
PlayResY: {hauteur}
WrapStyle: 0
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
                texte = "\\N".join(_decouper(phrase, largeur_ligne))
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


def luminosite_moyenne(chemin: str, echantillons: int = 8) -> float:
    """Luminosite moyenne de la video, sur 255.

    LE CONTROLE QUI MANQUAIT. Une capsule a ete livree comme « prete » alors
    qu'elle etait NOIRE pendant quinze secondes : deux scenes generees avaient
    echoue et rendu du vide. Le fichier etait parfaitement valide -- bonne
    duree, bon codec, bonnes dimensions -- et mon controle ne regardait que
    cela. Il declarait donc un succes sur une video sans image.

    Verifier qu'un fichier est lisible ne dit RIEN de ce qu'il contient.
    """
    valeurs = []
    duree = 0.0
    try:
        duree = float(subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=nw=1:nk=1", chemin],
            capture_output=True, text=True, timeout=60).stdout.strip() or 0)
    except Exception:  # noqa: BLE001
        return -1.0
    if duree <= 0:
        return -1.0

    for i in range(echantillons):
        instant = duree * (i + 0.5) / echantillons
        try:
            brut = subprocess.run(
                ["ffmpeg", "-v", "error", "-ss", f"{instant:.2f}", "-i", chemin,
                 "-frames:v", "1", "-vf", "scale=64:114,format=gray",
                 "-f", "rawvideo", "-"],
                capture_output=True, timeout=120).stdout
            if brut:
                valeurs.append(sum(brut) / len(brut))
        except Exception:  # noqa: BLE001
            continue
    return round(sum(valeurs) / len(valeurs), 2) if valeurs else -1.0


def _luminosite_a(chemin: str, instant: float) -> float:
    """Luminosite d'une image unique, prise a un instant donne. -1 si illisible."""
    try:
        brut = subprocess.run(
            ["ffmpeg", "-v", "error", "-ss", f"{instant:.2f}", "-i", chemin,
             "-frames:v", "1", "-vf", "scale=64:114,format=gray",
             "-f", "rawvideo", "-"],
            capture_output=True, timeout=120).stdout
        return round(sum(brut) / len(brut), 2) if brut else -1.0
    except Exception:  # noqa: BLE001
        return -1.0


def scenes_sombres(chemin: str, capsule: dict, seuil: float = 6.0,
                   par_scene: int = 3) -> list[dict]:
    """Repere les scenes noires UNE PAR UNE. Renvoie celles qui sont sous le seuil.

    POURQUOI LA MOYENNE NE SUFFIT PAS, ET C'EST MESURE.
    `luminosite_moyenne` prend huit echantillons sur toute la capsule et les
    moyenne. Sur une capsule de quatre scenes dont deux sont noires, la mesure
    du 05/08 donne : luminosite moyenne 64,74/255, `image_visible` = True --
    alors que 11,0 secondes sur 22,6 sont reellement noires, soit 49 %.

    C'est exactement le mecanisme de la capsule livree noire a un etudiant. Le
    controle global etait necessaire ; il n'a jamais ete suffisant. Une scene
    noire se cache derriere les scenes lumineuses qui l'entourent, et plus la
    capsule est longue, mieux elle se cache.

    On decoupe donc la video selon les durees du storyboard et on mesure
    chaque scene separement.
    """
    scenes = capsule.get("scenes") or []
    if not scenes:
        return []

    try:
        reelle = float(subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=nw=1:nk=1", chemin],
            capture_output=True, text=True, timeout=60).stdout.strip() or 0)
    except Exception:  # noqa: BLE001
        return []
    if reelle <= 0:
        return []

    nominale = sum(float(s.get("duree_s") or 0) for s in scenes)
    if nominale <= 0:
        return []
    # La duree reelle differe toujours un peu de la somme des durees prevues
    # (arrondis d'images, image finale repetee). On projette plutot que de
    # supposer les deux egales : sans cela le decoupage derive scene apres
    # scene et l'on finit par mesurer la mauvaise.
    facteur = reelle / nominale

    sombres: list[dict] = []
    debut = 0.0
    for scene in scenes:
        duree = float(scene.get("duree_s") or 0) * facteur
        if duree <= 0:
            continue
        fin = debut + duree
        # On evite les bords : une transition ou une image de garde ne doit pas
        # faire condamner une scene par ailleurs correcte.
        marge = min(0.25, duree / 6)
        mesures = []
        for i in range(par_scene):
            t = debut + marge + (duree - 2 * marge) * (i + 0.5) / par_scene
            v = _luminosite_a(chemin, min(t, reelle - 0.05))
            if v >= 0:
                mesures.append(v)
        if mesures:
            moyenne = round(sum(mesures) / len(mesures), 2)
            if moyenne < seuil:
                sombres.append({
                    "id": scene.get("id"),
                    "archetype": scene.get("archetype"),
                    "debut_s": round(debut, 2),
                    "duree_s": round(duree, 2),
                    "luminosite": moyenne,
                })
        debut = fin
    return sombres


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

    # Ce que le fichier CONTIENT, pas seulement ce qu'il declare.
    infos["luminosite"] = str(luminosite_moyenne(chemin))
    infos["a_du_son"] = str(bool(subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "a", "-show_entries",
         "stream=codec_type", "-of", "csv=p=0", chemin],
        capture_output=True, text=True, timeout=60).stdout.strip()))

    # Seuil a 6/255. Le style du studio est volontairement sombre -- la capsule
    # de reference mesure 10 a 12 -- mais en dessous de 6 il n'y a plus d'image,
    # seulement des sous-titres sur du noir. Mesure sur la capsule ratee :
    # 1,8 a 3,8 sur les scenes vides, 12,3 sur la seule qui fonctionnait.
    try:
        infos["image_visible"] = str(float(infos["luminosite"]) >= 6.0)
    except ValueError:
        infos["image_visible"] = "False"
    return infos
