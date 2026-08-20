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

# ── Zone de mesure de la luminosite ───────────────────────────────────────
#
# MESURER L'IMAGE ENTIERE, C'EST MESURER AUTRE CHOSE QUE L'IMAGE.
# Deux elements occupent le cadre sans rien dire du rendu :
#
#   • les bandes noires du cadre cinema -- 38 % de la hauteur, noires PAR
#     CONSTRUCTION (voir `cadre_cinema`), donc un lest constant ;
#   • le sous-titre incruste, blanc vif sur fond noir, dont la contribution
#     suit la LONGUEUR DE LA PHRASE et non le contenu de la scene.
#
# Mesure du 05/08 sur les deux capsules reellement livrees : une scene noire
# portant deux lignes de sous-titre pese 4,18/255, la MEME noirceur avec trois
# lignes pese 5,91. Le seuil de 6,0 tombait entre les deux -- il separait des
# longueurs de phrase, pas des images. Il rejetait au passage quatre scenes
# visuellement correctes (`titre`, `carte`, `chronologie`, `ondes`, mesurees
# entre 5,05 et 5,99), c'est-a-dire une capsule entiere.
#
# On mesure donc la bande REELLEMENT RENDUE, sous-titre exclu. Sur les huit
# scenes disponibles, la separation devient franche : 1,34 pour une scene sans
# image, 4,18 pour la plus faible des scenes visibles.
#
# Limite assumee : la fenetre couvre le centre du cadre. La camera vise
# toujours l'origine (`_camera` place une cible en 0,0,0), donc le sujet y est.
# Un archetype qui composerait exclusivement dans le tiers bas y echapperait.
_HAUT_BANDE = (1.0 - PROPORTION_CINEMA) / 2.0          # 0,19 -- haut de l'image rendue
_BAS_SOUS_TITRE = _HAUT_BANDE + 0.09                   # 0,28 depuis le BAS, cf. `ecrire_sous_titres`
_HAUTEUR_TEXTE = 3 * 0.030 * 1.25                      # trois lignes au plus, interligne compris
_BAS_ZONE = 1.0 - _BAS_SOUS_TITRE - _HAUTEUR_TEXTE     # 0,6075
_FILTRE_MESURE = (
    f"crop=iw:ih*{_BAS_ZONE - _HAUT_BANDE:.4f}:0:ih*{_HAUT_BANDE:.4f},"
    "scale=64:47,format=gray"
)

# Seuils recalibres le 05/08 sur les huit scenes reelles, avec la fenetre
# ci-dessus. Plancher mesure sans image : 1,11 (le fond du style, seul). Plus
# faible scene visible : 3,87 (`carte`, un unique motif au centre). Le seuil se
# place au milieu GEOMETRIQUE des deux -- sqrt(1,11 x 3,87) = 2,07 -- et non au
# milieu arithmetique : ces valeurs se comparent en rapports, pas en ecarts.
#
# LE COUT DES DEUX ERREURS N'EST PAS LE MEME, et c'est ce qui tranche.
# Laisser passer une scene noire abime une capsule ; refuser a tort en fait
# perdre la TOTALITE, puisque `executer_capsule` ne depose alors rien. La
# contrainte « degradation gracieuse » du projet penche donc du cote qui livre.
SEUIL_SCENE_NOIRE = 2.0
SEUIL_CAPSULE_NOIRE = 2.0


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
      * `crf 24` AVEC UN PLAFOND DE DEBIT : la qualite tient a debit contenu,
        ce qui compte quand l'abonne paie ses donnees mobiles.

    LE PLAFOND N'EST PAS UN DETAIL, IL VIENT D'UNE MESURE.
    `crf 20` sans plafond a produit, le 20/08, une capsule de 39 s pesant
    75 Mo — soit 15,4 Mbit/s. Storage l'a refusee (`EntityTooLarge`) et QUATRE
    MINUTES DE RENDU ONT ETE PERDUES, deux fois de suite, sur le sujet
    « les nuages ».

    Le contenu explique le poids : des milliers d'aretes fines et mouvantes sur
    fond noir sont le pire cas pour x264. Une capsule au sujet plus calme
    (« le petrole », 46 Mo) passait de justesse ; la limite n'etait pas atteinte
    par chance, pas par conception.

    Et meme si Storage avait accepte : 75 Mo pour 39 s de cours est
    inutilisable pour un etudiant a Bobo-Dioulasso qui paie ses donnees. Le
    commentaire d'origine visait juste ; le reglage ne le servait pas.

    A 2500 kbit/s, 39 s pesent ~12 Mo, et meme une capsule de 150 s reste sous
    la limite. La nettete du texte incruste est preservee : le plafond mord sur
    le fourmillement des traits, pas sur les aplats.
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
    entrees: list[str] = []
    with open(liste, "w", encoding="utf-8") as f:
        fichiers: list[str] = []
        for scene in scenes:
            prefixe = scene["id"] + "_"
            # DEUX MOTEURS, DEUX EXTENSIONS. Blender depose des PNG, le moteur
            # navigateur des JPEG -- encoder du PNG en 1080x1920 coute plus cher
            # que rendre l'image. ffmpeg ne fait aucune difference entre les
            # deux ; ce filtre, si.
            #
            # Mesure du 18/08, travail b8ecc6c1 : le rendu navigateur a produit
            # ses images, et l'assemblage a repondu « No files to concat ».
            # J'avais elargi la DETECTION des images dans `executer_capsule`
            # sans elargir leur ASSEMBLAGE ici -- un seul des deux endroits qui
            # listent des fichiers. Le defaut classique de ce depot : on corrige
            # la couche qu'on regarde, pas celle qui suit.
            fichiers = sorted(n for n in os.listdir(dossier_images)
                              if n.startswith(prefixe)
                              and n.lower().endswith((".png", ".jpg", ".jpeg")))
            for nom in fichiers:
                f.write(f"file '{os.path.join(racine, nom)}'\n")
                f.write(f"duration {1.0 / fps}\n")
                entrees.append(nom)
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
        "-c:v", "libx264", "-preset", "slow", "-crf", "24",
        "-maxrate", "2500k", "-bufsize", "5000k",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart",
    ]
    if audio and os.path.isfile(audio):
        commande += ["-c:a", "aac", "-b:a", "160k", "-shortest"]
    commande.append(sortie)

    resultat = subprocess.run(commande, capture_output=True, text=True, timeout=3600)
    if resultat.returncode != 0 or not os.path.isfile(sortie):
        return False, resultat.stderr[-400:]

    # LE DEMULTIPLEXEUR `concat` S'ARRETE EN SILENCE, ET IL REND 0.
    #
    # Mesure du 06/08 : 1053 images rendues, 1053 entrees ecrites dans la
    # liste, et une video de 51 images -- 2,04 s au lieu de 42. ffmpeg avait
    # rencontre un PNG illisible (le volume du pod etait plein : le cache des
    # modeles en occupait 14 Go sur 20) ; il a journalise l'erreur, cesse de
    # lire la liste, ferme proprement le fichier et rendu le code 0.
    #
    # Le controle d'apres ne regardait que la luminosite et le son : il a
    # trouve les deux corrects sur ces deux secondes, et la capsule a ete
    # deposee. Huitieme occurrence du meme defaut -- un controle qui regarde
    # a cote.
    #
    # On compare donc ce qu'on a DEMANDE a ce qu'on a OBTENU.
    attendues = len(entrees)
    obtenues = _images_du_flux(sortie)
    if obtenues >= 0 and attendues > 0 and obtenues < attendues * 0.98:
        return False, (f"montage tronque : {obtenues} images dans la video pour "
                       f"{attendues} demandees. ffmpeg s'est arrete en silence — "
                       f"le plus souvent un fichier illisible, disque plein. "
                       f"Journal : {resultat.stderr[-200:]}")
    return True, ""


def _images_du_flux(chemin: str) -> int:
    """Nombre d'images du flux VIDEO. -1 si non mesurable.

    On interroge explicitement `v:0` : `verifier` lit tous les flux et se fait
    ecraser par l'audio quand il y en a un -- d'ou les `codec_name: aac` et
    `r_frame_rate: 0/0` observes dans les journaux de production.
    """
    try:
        r = subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "v:0",
             "-count_frames", "-show_entries", "stream=nb_read_frames",
             "-of", "default=nw=1:nk=1", chemin],
            capture_output=True, text=True, timeout=600)
        return int((r.stdout.strip() or "-1").splitlines()[0])
    except Exception:  # noqa: BLE001
        return -1


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
                 "-frames:v", "1", "-vf", _FILTRE_MESURE,
                 "-f", "rawvideo", "-"],
                capture_output=True, timeout=120).stdout
            if brut:
                valeurs.append(sum(brut) / len(brut))
        except Exception:  # noqa: BLE001
            continue
    return round(sum(valeurs) / len(valeurs), 2) if valeurs else -1.0


def _luminosite_a(chemin: str, instant: float) -> float:
    """Luminosite d'une image unique, prise a un instant donne. -1 si illisible.

    Mesuree sur la zone utile seulement -- voir `_FILTRE_MESURE`.
    """
    try:
        brut = subprocess.run(
            ["ffmpeg", "-v", "error", "-ss", f"{instant:.2f}", "-i", chemin,
             "-frames:v", "1", "-vf", _FILTRE_MESURE,
             "-f", "rawvideo", "-"],
            capture_output=True, timeout=120).stdout
        return round(sum(brut) / len(brut), 2) if brut else -1.0
    except Exception:  # noqa: BLE001
        return -1.0


def scenes_sombres(chemin: str, capsule: dict, seuil: float = SEUIL_SCENE_NOIRE,
                   par_scene: int = 3) -> list[dict]:
    """Repere les scenes noires UNE PAR UNE. Renvoie celles qui sont sous le seuil.

    OU L'ON MESURE COMPTE AUTANT QUE CE QU'ON MESURE (correctif du 05/08).
    La premiere version regardait l'image entiere avec un seuil de 6,0. Passee
    sur les deux capsules reellement livrees, elle condamnait quatre scenes
    visuellement correctes -- `titre`, `carte`, `chronologie` et `ondes`,
    mesurees entre 5,05 et 5,99 -- soit une capsule entiere refusee a
    l'etudiant. Elle ne mesurait ni le cadre cinema ni la scene, mais la
    quantite de texte incruste. Voir `_FILTRE_MESURE`.

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

    # Le seuil suit la meme recalibration que les scenes (voir en tete de
    # fichier). L'ancienne valeur de 6/255 etait mesuree sur l'image entiere :
    # elle donnait 6,38 a une capsule dont les QUATRE scenes sont correctes --
    # a 0,38 pres, tout etait refuse. Ce n'etait pas une marge, c'etait un
    # hasard.
    try:
        infos["image_visible"] = str(
            float(infos["luminosite"]) >= SEUIL_CAPSULE_NOIRE)
    except ValueError:
        infos["image_visible"] = "False"
    return infos


# ══ PORTE D'ACCEPTATION ═══════════════════════════════════════════════════
#
# POURQUOI ELLE EXISTE, ET CE QU'ELLE AJOUTE.
# Le controle ci-dessus couvre le NOIR, et il le couvre bien -- il a ete
# recalibre le 05/08 sur huit scenes reelles. Il ne couvre PAS trois defauts
# qui se sont produits depuis, et qui passent tous pour des succes :
#
#   1. LE MUET. `verifier()` pose `a_du_son` en constatant qu'une PISTE audio
#      existe. Une piste de silence numerique existe. Le defaut du 05/08 etait
#      « noire ET MUETTE » : la moitie n'etait pas mesuree.
#   2. L'INCOMPLET. Mesure du 07/08 dans `app.studio_jobs` : la capsule
#      « l'univers » est sortie de la chaine avec 908 images sur 1924 -- 47 %.
#      Rien dans le controle ne compare ce qui a ete produit a ce qui etait
#      attendu, donc une capsule tronquee est indiscernable d'une capsule
#      courte.
#   3. LE FIGE. La camera recoit une cle a CHAQUE image (`_camera`). Une image
#      qui ne bouge plus pendant plusieurs secondes n'est donc pas un choix de
#      mise en scene : c'est un rendu qui s'est arrete.
#
# ON MESURE, ON NE DEMANDE PAS. « Noir », « vide », « fige », « muet » sont des
# proprietes mesurables en millisecondes. Les soumettre a un modele couterait
# des secondes et une incertitude -- et un juge qui se trompe finirait par
# declarer prete une capsule qui ne l'est pas, c'est-a-dire par recreer le
# defaut avec une couche d'IA en plus.
#
# LE COUT DES DEUX ERREURS RESTE ASYMETRIQUE (cf. SEUIL_SCENE_NOIRE) : refuser
# a tort fait perdre la capsule ENTIERE a l'etudiant. D'ou deux niveaux :
# `refus` n'est prononce que sur une preuve franche, `alertes` est journalise
# et laisse passer.

# Silence numerique : ffmpeg rend -91 dB, et « -inf » quand la piste est vide.
# Une narration normale se situe entre -30 et -18 dB. Le plancher est place tres
# bas exprès : il ne doit attraper que le silence REEL, jamais une voix douce.
PLANCHER_RMS_DB = -60.0
# Duree figee toleree.
#
# LE SEUIL A ETE ECRIT POUR UN AUTRE REGIME DE MOUVEMENT, ET IL A REFUSE A TORT.
#
# Il valait 3,0 s, justifie ainsi : « la camera bouge a chaque image ». C'etait
# vrai du temps des dix archetypes, dont les cameras balayaient large. Depuis le
# 14/08, le compositeur pose une orbite VOLONTAIREMENT LENTE -- 14 degres sur
# toute une scene de comparaison, « travellings lents et rotations limitees ».
# Sur un objet a symetrie de revolution, deux images consecutives sont alors
# quasi identiques, et `freezedetect` a -55 dB les compte comme figees.
#
# Mesure du 18/08, travail 50b5236d « pluie » : 887 images rendues sur 886, un
# rendu complet et sain, REFUSE pour « image figee 3.16 s ». Zero virgule seize
# seconde au-dessus du seuil.
#
# On monte a 6 s : au-dela, meme une orbite lente aurait parcouru assez d'angle
# pour changer l'image, et un rendu reellement arrete depasse largement. Ce
# chiffre reste a confirmer sur des capsules acceptees -- il est choisi pour ne
# plus refuser a tort, pas pour laisser passer un rendu mort.
GEL_MAX_S = 6.0

# DEUX CHOSES DIFFERENTES, ET LES CONFONDRE REND LE DETECTEUR AVEUGLE.
#
# `GEL_MAX_S` dit a partir de quand on REFUSE. Cette constante-ci dit a partir
# de quand ffmpeg MESURE un gel. Elles etaient une seule et meme valeur : monter
# le seuil de refus montait aussi la fenetre de detection, et un gel de quatre
# secondes cessait d'etre vu -- `freezedetect` ne rapporte rien en dessous de
# `d=`. Le test `test_porte_acceptation` l'a attrape immediatement : une capsule
# entierement figee de 4 s ressortait avec `duree_figee_s = 0.0`.
#
# On mesure donc bas et on refuse haut. Entre les deux, le gel apparait dans les
# mesures sans faire echouer la capsule -- exactement ce qu'on veut pour choisir
# le bon seuil sur des chiffres plutot que sur une intuition.
GEL_DETECTION_S = 2.0
# En deca de cette part de la duree attendue, la capsule est tronquee.
# « l'univers » etait a 0,47.
PART_DUREE_MINIMALE = 0.90


def _sortie_ffmpeg(args: list[str], delai: int = 180) -> str:
    """Lance ffmpeg et rend son journal. Les filtres de mesure ecrivent leur
    resultat sur stderr, pas sur stdout."""
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=delai,
                           encoding="utf-8", errors="replace")
        return (r.stderr or "") + (r.stdout or "")
    except Exception:  # noqa: BLE001
        return ""


def niveau_sonore_db(chemin: str) -> float:
    """Niveau moyen reel de la piste audio, en dB.

    Rend -99.0 quand il n'y a pas de piste, ou qu'elle est du silence pur.
    C'est LA mesure qui manquait : `a_du_son` ne distingue pas une voix d'une
    piste vide, et le defaut du 05/08 etait autant le silence que le noir.
    """
    journal = _sortie_ffmpeg(
        ["ffmpeg", "-v", "info", "-i", chemin, "-af", "volumedetect",
         "-vn", "-f", "null", "-"])
    for ligne in journal.splitlines():
        if "mean_volume:" in ligne:
            try:
                return round(float(ligne.split("mean_volume:")[1].split("dB")[0]), 2)
            except (ValueError, IndexError):
                return -99.0
    return -99.0


def duree_video_s(chemin: str) -> float:
    """Duree reelle du conteneur. -1 si illisible."""
    try:
        return float(subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=nw=1:nk=1", chemin],
            capture_output=True, text=True, timeout=60).stdout.strip() or 0) or -1.0
    except Exception:  # noqa: BLE001
        return -1.0


def duree_figee_s(chemin: str, duree_minimale: float = GEL_DETECTION_S) -> float:
    """Duree cumulee pendant laquelle l'image ne bouge plus du tout.

    On mesure sur la ZONE UTILE, comme la luminosite : les bandes noires du
    cadre cinema sont figees par construction et feraient repondre « fige » a
    toute capsule correcte.

    LE PIEGE, MESURE LE 11/08 ET IL ANNULAIT TOUTE LA MESURE.
    `freezedetect` emet `freeze_start` a l'entree du gel et `freeze_duration`
    a la SORTIE. Quand le gel se poursuit jusqu'a la derniere image, il n'y a
    pas de sortie : le filtre n'emet donc JAMAIS de duree. Une premiere version
    ne lisait que `freeze_duration` et rendait 0,0 s sur une video entierement
    figee -- c'est-a-dire exactement le cas pour lequel elle avait ete ecrite.

    Or un rendu qui s'arrete ne degele pas : il fige jusqu'a la fin. La forme
    la plus probable du defaut etait la seule que la mesure ne voyait pas.

    On lit donc les DEBUTS, et tout debut sans fin court jusqu'au bout.
    """
    journal = _sortie_ffmpeg(
        ["ffmpeg", "-v", "info", "-i", chemin,
         "-vf", f"{_FILTRE_MESURE},freezedetect=n=-55dB:d={duree_minimale:g}",
         "-map", "0:v", "-f", "null", "-"])

    debuts: list[float] = []
    fins: list[float] = []
    for ligne in journal.splitlines():
        for cle, cible in (("freeze_start:", debuts), ("freeze_end:", fins)):
            if cle in ligne:
                try:
                    cible.append(float(ligne.split(cle)[1].split()[0]))
                except (ValueError, IndexError):
                    continue

    if not debuts:
        return 0.0

    fin_video = duree_video_s(chemin)
    total = 0.0
    for rang, debut in enumerate(debuts):
        fin = fins[rang] if rang < len(fins) else fin_video
        if fin > debut:
            total += fin - debut
    return round(total, 2)


def contraste_luminosite(chemin: str, echantillons: int = 6) -> float:
    """Ecart-type de la luminosite entre plusieurs instants.

    POURQUOI LA MOYENNE NE SUFFIT PAS -- deuxieme fois. `scenes_sombres` a deja
    montre qu'une moyenne cache une scene noire. Elle cache aussi l'inverse :
    une image UNIFORMEMENT grise -- un volume qui remplit tout le cadre, un
    brouillard trop dense -- passe le seuil de luminosite sans rien montrer.
    Un ecart-type nul sur toute la capsule signale une image sans structure.
    """
    try:
        reelle = float(subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=nw=1:nk=1", chemin],
            capture_output=True, text=True, timeout=60).stdout.strip() or 0)
    except Exception:  # noqa: BLE001
        return -1.0
    if reelle <= 0:
        return -1.0

    mesures = [v for v in (
        _luminosite_a(chemin, min(reelle * (i + 0.5) / echantillons, reelle - 0.05))
        for i in range(echantillons)) if v >= 0]
    if len(mesures) < 2:
        return -1.0
    moyenne = sum(mesures) / len(mesures)
    variance = sum((v - moyenne) ** 2 for v in mesures) / len(mesures)
    return round(variance ** 0.5, 2)


def porte_acceptation(chemin: str, capsule: dict | None = None) -> dict:
    """Le seul point par lequel une capsule a le droit de sortir.

    Rend TOUJOURS ses mesures, meme quand elle accepte : c'est ce qui permet de
    dire plus tard pourquoi une capsule est passee. Une porte qui n'ecrit rien
    quand tout va bien ne prouve rien le jour ou tout va mal.

    `refus` : preuve franche d'une capsule inutilisable.
    `alertes` : anomalie journalisee qui NE bloque PAS -- la contrainte de
    degradation gracieuse veut qu'un doute livre plutot qu'il ne prive.
    """
    capsule = capsule or {}
    mesures: dict = {}
    refus: list[str] = []
    alertes: list[str] = []

    # 1. Le fichier est-il lisible, et que contient-il ?
    infos = verifier(chemin)
    mesures["lisible"] = infos.get("lisible") == "True"
    mesures["duree_s"] = round(float(infos.get("duration") or 0), 2)
    mesures["luminosite"] = float(infos.get("luminosite") or -1)
    mesures["piste_audio"] = infos.get("a_du_son") == "True"
    if not mesures["lisible"]:
        return {"accepte": False, "refus": ["fichier illisible"],
                "alertes": [], "mesures": mesures}

    # 2. Le noir, capsule entiere puis scene par scene.
    mesures["image_visible"] = infos.get("image_visible") == "True"
    if not mesures["image_visible"]:
        refus.append(f"capsule noire (luminosite {mesures['luminosite']} "
                     f"< {SEUIL_CAPSULE_NOIRE})")
    sombres = scenes_sombres(chemin, capsule) if capsule.get("scenes") else []
    mesures["scenes_sombres"] = [s["id"] for s in sombres]
    if sombres:
        refus.append("scene(s) noire(s) : "
                     + ", ".join(f"{s['id']}={s['luminosite']}" for s in sombres))

    # 3. Le muet -- ce que `a_du_son` ne voyait pas.
    #
    # ALERTE ET NON REFUS, ET C'EST DELIBERE. `executer_capsule` a tranche que
    # « le son manquant ne bloque pas : une capsule muette reste regardable ».
    # Cette decision tient, et ce module la renforce meme : les sous-titres sont
    # INCRUSTES, et 60 a 85 % des vidcapsules verticales sont regardees sans le
    # son (cf. entete). Une capsule muette perd la voix, pas le cours ; la
    # refuser ferait perdre les deux, contre la contrainte de degradation
    # gracieuse.
    #
    # Ce qui change : le silence ne passe plus INAPERCU. `a_du_son` repondait
    # True sur une piste de silence numerique -- la moitie du defaut du 05/08
    # n'etait donc pas mesuree du tout. Elle l'est maintenant, et elle est
    # ecrite dans la ligne de rendu.
    mesures["niveau_db"] = niveau_sonore_db(chemin)
    if not mesures["piste_audio"]:
        alertes.append("aucune piste audio — la narration n'a pas ete jointe")
    elif mesures["niveau_db"] < PLANCHER_RMS_DB:
        alertes.append(f"capsule muette : piste presente mais silencieuse "
                       f"({mesures['niveau_db']} dB < {PLANCHER_RMS_DB} dB)")

    # 4. L'incomplet -- le defaut de « l'univers », 908 images sur 1924.
    attendue = float(capsule.get("duree_totale_s") or 0)
    if attendue <= 0:
        attendue = sum(float(s.get("duree_s") or 0)
                       for s in (capsule.get("scenes") or []))
    mesures["duree_attendue_s"] = round(attendue, 2)
    if attendue > 0:
        part = mesures["duree_s"] / attendue
        mesures["part_produite"] = round(part, 3)
        if part < PART_DUREE_MINIMALE:
            refus.append(f"capsule tronquee : {mesures['duree_s']} s produites "
                         f"sur {mesures['duree_attendue_s']} s attendues "
                         f"({part:.0%})")
    else:
        alertes.append("duree attendue inconnue — completude non verifiable")

    # 5. Le fige.
    mesures["duree_figee_s"] = duree_figee_s(chemin)
    if mesures["duree_figee_s"] >= GEL_MAX_S:
        refus.append(f"image figee {mesures['duree_figee_s']} s")

    # 6. L'aplat -- une image uniforme passe le seuil de luminosite.
    mesures["contraste"] = contraste_luminosite(chemin)
    if 0 <= mesures["contraste"] < 0.5:
        alertes.append(f"image quasi uniforme (ecart-type {mesures['contraste']})")

    return {"accepte": not refus, "refus": refus, "alertes": alertes,
            "mesures": mesures}
