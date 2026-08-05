#!/usr/bin/env python3
"""Narration d'une capsule — voix OpenRouter, mesuree puis imposee a l'image.

CE MODULE TOURNE SUR LWS, PAS SUR LE POD. Trois raisons :

  1. `whiteboard-tts` exige le role `service_role`. Le pod ne detient que son
     jeton -- il tourne sur une machine louee dont nous ne controlons pas
     l'hote, et lui confier la cle de service serait un recul de securite.
     LWS, lui, possede deja cette cle dans /opt/whiteboard-worker/.env.
  2. La synthese vocale ne demande aucun GPU. La faire tourner sur une machine
     facturee 0,44 $/h serait du gaspillage pur.
  3. Le cahier des charges place la narration et le montage sur LWS.

LE RENVERSEMENT QUE CE MODULE OPERE. Jusqu'ici la duree d'une scene etait
DEDUITE du nombre de mots -- 2,5 mots par seconde, une estimation. Desormais la
voix est synthetisee D'ABORD, sa duree reelle est MESUREE, et c'est elle qui
fixe la duree de la scene.

C'est la regle d'or du Smart Whiteboard portee a l'exact :
    « la voix commande l'image, jamais l'inverse »
Une phrase ne peut plus etre coupee, puisque l'image est calee sur l'audio qui
existe deja.

Usage :
  python3 narration.py capsule.json sortie/
    -> sortie/narration.wav          la bande complete
    -> sortie/capsule_calee.json     les durees REELLES mesurees
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import academia_scene  # noqa: E402
import sound_design  # noqa: E402

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")
VOIX = os.environ.get("STUDIO_VOIX", "fr_marie_neutral")

# Mesure du Smart Whiteboard : au debit natif la voix est trop rapide pour du
# pedagogique. 0,88 laisse le temps de comprendre sans donner l'impression que
# ca traine.
TEMPO = float(os.environ.get("STUDIO_TEMPO", "0.88"))

# Respiration apres chaque phrase. Sans elle, les scenes s'enchainent sans
# reprise et l'oreille sature -- defaut classique des videos automatiques.
SILENCE_FIN_S = float(os.environ.get("STUDIO_SILENCE", "0.45"))

MAX_CARACTERES = 1200   # limite imposee par l'Edge Function


def journal(message: str) -> None:
    print(f"{time.strftime('%H:%M:%S')} {message}", flush=True)


def synthetiser(texte: str, sortie_mp3: str, essais: int = 3) -> bool:
    """Appelle `whiteboard-tts`. Reessaie : une coupure reseau ne doit pas
    faire perdre toute une capsule."""
    corps = json.dumps({"input": texte[:MAX_CARACTERES], "voice": VOIX}).encode("utf-8")
    for tentative in range(1, essais + 1):
        try:
            requete = urllib.request.Request(
                f"{SUPABASE_URL}/functions/v1/whiteboard-tts",
                data=corps, method="POST",
                headers={
                    "Authorization": f"Bearer {SERVICE_KEY}",
                    "Content-Type": "application/json",
                })
            with urllib.request.urlopen(requete, timeout=120) as reponse:
                audio = reponse.read()
            if not audio:
                journal(f"  tentative {tentative}: audio vide")
                continue
            with open(sortie_mp3, "wb") as f:
                f.write(audio)
            return True
        except urllib.error.HTTPError as e:
            journal(f"  tentative {tentative}: HTTP {e.code} {e.read()[:160]!r}")
        except Exception as e:  # noqa: BLE001
            journal(f"  tentative {tentative}: {e}")
        time.sleep(2 * tentative)
    return False


def mesurer(chemin: str) -> float:
    sortie = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", chemin],
        capture_output=True, text=True)
    try:
        return float(sortie.stdout.strip())
    except ValueError:
        return 0.0


def _traiter(mp3: str, wav: str) -> float:
    """Ralentit, normalise, et ajoute la respiration finale.

    `loudnorm` n'est pas un luxe : sans lui le niveau varie d'une capsule a
    l'autre et l'abonne doit toucher son volume a chaque video. C'est le genre
    de detail qui fait « amateur » sans qu'on sache dire pourquoi.
    """
    subprocess.run([
        "ffmpeg", "-y", "-i", mp3,
        "-filter:a", f"atempo={TEMPO},loudnorm=I=-16:TP=-1.5:LRA=11,"
                     f"apad=pad_dur={SILENCE_FIN_S}",
        "-ar", "48000", "-ac", "1", wav,
    ], capture_output=True, timeout=300)
    return mesurer(wav)


def preparer(capsule: dict, dossier: str) -> tuple[dict, str | None]:
    """Synthetise scene par scene, mesure, et RECALE la capsule sur le reel.

    Renvoie la capsule calee et le chemin de la bande son complete. Si la voix
    echoue totalement, on renvoie la capsule inchangee et None : degradation
    gracieuse -- une capsule muette vaut mieux qu'aucune capsule.
    """
    os.makedirs(dossier, exist_ok=True)
    clips: list[str] = []
    obtenues = 0

    for scene in capsule["scenes"]:
        narration = (scene.get("narration") or "").strip()
        if not narration:
            clips.append("")
            continue

        mp3 = os.path.join(dossier, f"{scene['id']}.mp3")
        wav = os.path.join(dossier, f"{scene['id']}.wav")

        if not synthetiser(narration, mp3):
            journal(f"  {scene['id']}: voix indisponible, duree estimee conservee")
            clips.append("")
            continue

        duree = _traiter(mp3, wav)
        if duree <= 0:
            clips.append("")
            continue

        clips.append(wav)
        obtenues += 1
        ancienne = scene["duree_s"]
        # LA VOIX COMMANDE L'IMAGE : la duree mesuree remplace l'estimation.
        scene["duree_s"] = round(max(academia_scene.DUREE_MIN_S,
                                     min(academia_scene.DUREE_MAX_S, duree)), 2)
        # Marque la duree comme MESUREE : elle ne devra plus jamais etre
        # remplacee par une estimation, sous peine de desynchroniser la voix.
        scene["mesuree"] = True
        journal(f"  {scene['id']}: {ancienne}s estimee -> {scene['duree_s']}s mesuree")

    if obtenues == 0:
        journal("AUCUNE voix obtenue — capsule muette, durees estimees conservees")
        return capsule, None

    # Recalcule les totaux sur les durees reelles.
    total = sum(s["duree_s"] for s in capsule["scenes"])
    capsule["duree_totale_s"] = round(total, 2)
    capsule["images_total"] = int(round(total * capsule["format"]["fps"]))

    bande = os.path.join(dossier, "narration.wav")
    if not _coller(clips, capsule, bande):
        return capsule, None
    journal(f"NARRATION {obtenues}/{len(capsule['scenes'])} scenes, "
            f"{capsule['duree_totale_s']}s au total")
    return capsule, bande


def _coller(clips: list[str], capsule: dict, sortie: str) -> bool:
    """Colle les clips bout a bout, en comblant par du silence les scenes sans
    voix -- sinon l'audio glisse et se desynchronise de l'image pour toute la
    suite de la capsule."""
    morceaux = os.path.join(os.path.dirname(sortie), "morceaux.txt")
    silences: list[str] = []

    with open(morceaux, "w", encoding="utf-8") as f:
        for indice, (clip, scene) in enumerate(zip(clips, capsule["scenes"])):
            if clip and os.path.isfile(clip):
                # CHEMIN ABSOLU, TOUJOURS. ffmpeg resout les chemins relatifs
                # d'une liste de concatenation par rapport au FICHIER DE LISTE,
                # pas au repertoire courant : « p4bis/ouverture.wav » devenait
                # « p4bis/p4bis/ouverture.wav ». Le defaut ne se manifestait que
                # si l'appelant passait un chemin relatif -- il avait donc
                # survecu a tous les essais precedents, faits en absolu.
                f.write(f"file '{os.path.abspath(clip)}'\n")
            else:
                blanc = os.path.join(os.path.dirname(sortie), f"silence_{indice}.wav")
                subprocess.run([
                    "ffmpeg", "-y", "-f", "lavfi",
                    "-i", f"anullsrc=r=48000:cl=mono",
                    "-t", str(scene["duree_s"]), blanc,
                ], capture_output=True, timeout=120)
                silences.append(blanc)
                f.write(f"file '{os.path.abspath(blanc)}'\n")

    resultat = subprocess.run([
        "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", morceaux,
        "-ar", "48000", "-ac", "1", sortie,
    ], capture_output=True, timeout=600)

    for blanc in silences:
        try:
            os.remove(blanc)
        except OSError:
            pass
    return resultat.returncode == 0 and os.path.isfile(sortie)


def signer(cle: str, heures: int = 48) -> str | None:
    """Cree une URL signee pour que le pod puisse telecharger sans droit de
    lecture sur le bucket. Quarante-huit heures : largement au-dela de la duree
    d'un rendu, bien en deca d'une fuite durable."""
    try:
        requete = urllib.request.Request(
            f"{SUPABASE_URL}/storage/v1/object/sign/studio-visuel/{cle}",
            data=json.dumps({"expiresIn": heures * 3600}).encode("utf-8"),
            method="POST",
            headers={"Authorization": f"Bearer {SERVICE_KEY}",
                     "Content-Type": "application/json"})
        with urllib.request.urlopen(requete, timeout=60) as reponse:
            d = json.loads(reponse.read())
        chemin_signe = d.get("signedURL") or d.get("signedUrl") or ""
        return f"{SUPABASE_URL}/storage/v1{chemin_signe}" if chemin_signe else None
    except Exception as e:  # noqa: BLE001
        journal(f"signature impossible : {e}")
        return None


def deposer_bande(chemin: str, capsule_id: str) -> str | None:
    """Depose la narration dans Storage pour que le pod la recupere.

    LE DEFAUT QUE CECI CORRIGE. La voix etait produite ici, sur LWS, et le
    montage se faisait la-bas, sur le pod : les deux ne se rejoignaient jamais,
    et la capsule deposee etait MUETTE. Le defaut ne se voyait pas dans les
    journaux -- chaque moitie de la chaine fonctionnait parfaitement.

    Un fichier descend, un fichier monte, et le resultat est complet du premier
    coup. Le pod n'a pas besoin de la cle de service : la bande passe par le
    bucket, ou l'ecriture lui est ouverte sous `capsules/`.
    """
    cle = f"capsules/{capsule_id}/{int(time.time())}/narration.wav"
    try:
        with open(chemin, "rb") as f:
            donnees = f.read()
        requete = urllib.request.Request(
            f"{SUPABASE_URL}/storage/v1/object/studio-visuel/{cle}",
            data=donnees, method="POST",
            headers={
                "apikey": SERVICE_KEY,
                "Authorization": f"Bearer {SERVICE_KEY}",
                "Content-Type": "audio/wav",
            })
        with urllib.request.urlopen(requete, timeout=600) as reponse:
            if reponse.status < 300:
                return cle
            journal(f"depot bande refuse: HTTP {reponse.status}")
    except Exception as e:  # noqa: BLE001
        journal(f"depot bande impossible: {e}")
    return None


def main() -> int:
    if len(sys.argv) < 3:
        journal("usage: narration.py capsule.json dossier_sortie/")
        return 1
    if not (SUPABASE_URL and SERVICE_KEY):
        journal("ERREUR SUPABASE_URL ou SUPABASE_SERVICE_KEY absent")
        return 2

    with open(sys.argv[1], encoding="utf-8") as f:
        capsule = academia_scene.normaliser(json.load(f))
    dossier = sys.argv[2]

    journal("CAPSULE " + academia_scene.resume(capsule))
    capsule, bande = preparer(capsule, dossier)

    # ── Sound design ──────────────────────────────────────────────────────
    # On depose la bande COMPLETE -- voix, nappe attenuee et accents -- et non
    # la voix seule.
    #
    # LE RACCORD QUI MANQUAIT. `sound_design` etait ecrit, teste, et jamais
    # appele : la chaine automatique produisait des capsules avec la voix mais
    # sans musique. Meme defaut qu'hier avec la narration, ou les deux moities
    # fonctionnaient sans jamais se rencontrer.
    #
    # Ici plutot que sur le pod, pour deux raisons : le mixage ne demande aucun
    # GPU -- le faire a 0,44 $/h serait du gaspillage -- et c'est ici que la
    # capsule calee et la voix existent deja.
    if bande:
        complete = os.path.join(dossier, "bande_complete.wav")
        ok, resultat = sound_design.melanger(bande, capsule,
                                             os.path.join(dossier, "son"), complete)
        if ok and resultat != bande:
            journal("SON nappe et accents ajoutes")
            bande = resultat
        else:
            # Degradation gracieuse : la voix seule vaut mieux que pas de son.
            journal(f"SON indisponible ({resultat}) — voix seule")

    # La capsule emporte le chemin de sa bande : le pod saura ou la chercher,
    # sans qu'aucune information ne transite par un canal parallele.
    if bande:
        cle = deposer_bande(bande, capsule["capsule_id"])
        if cle:
            capsule["narration_cle"] = cle
            # URL SIGNEE, et non simple chemin. Le pod ne peut pas LIRE dans le
            # bucket : seule l'ecriture lui est ouverte, et c'est voulu -- les
            # capsules ne doivent sortir que par URL signee. Le telechargement
            # de la narration echouait donc en silence, et la degradation
            # gracieuse livrait une capsule MUETTE sans que rien ne l'annonce.
            # LWS, qui detient la cle de service, signe l'acces pour lui.
            capsule["narration_url"] = signer(cle) or ""

            journal(f"BANDE deposee — {cle}")
        else:
            journal("BANDE non deposee — le pod produira une capsule muette")

    chemin_json = os.path.join(dossier, "capsule_calee.json")
    with open(chemin_json, "w", encoding="utf-8") as f:
        json.dump(capsule, f, ensure_ascii=False, indent=2)

    journal(f"CALEE {chemin_json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
