#!/usr/bin/env python3
"""Execute une capsule de bout en bout sur le pod, puis DEPOSE le resultat.

Rendu -> sous-titres -> assemblage -> controle -> depot Supabase.

POURQUOI TOUT D'UN TRAIT. Deux lecons payees le 30/07 :

  1. Une capsule rendue avec succes a ete PERDUE parce que je la telechargeais
     a la main apres coup, et que le veilleur a supprime la machine entre-temps.
     `podTerminate` efface /workspace. Un resultat qui n'est pas sorti de la
     machine n'existe pas.
  2. Sur une machine de 66 minutes, 12 minutes de calcul : le reste attendait
     pendant que je reflechissais. Une ressource au compteur ne doit jamais
     servir d'atelier interactif.

D'ou ce script : on prepare tout hors ligne, on lance UNE fois, la machine fait
tout, depose, et peut mourir juste apres sans que rien ne soit perdu.

Usage :
  POD_ID=... POD_JETON=... SUPABASE_URL=... SUPABASE_ANON_KEY=... \\
  python3 executer_capsule.py capsule.json
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, "/workspace")

import academia_scene  # noqa: E402
import montage  # noqa: E402

def _trouver(nom: str, variable: str, candidats: tuple[str, ...]) -> str:
    """Trouve un executable ou un fichier LA OU IL EST, au lieu de le supposer.

    POURQUOI CETTE FONCTION EXISTE.

    Ces deux chemins pointaient en dur sur `/workspace/...`, l'emplacement de
    l'ancienne installation A CHAUD : avant l'image, `install_pod.sh` deposait
    Blender et le moteur dans le seul dossier qui survivait a un arret. L'image
    du 12/08 les met ailleurs -- Blender dans `/opt/blender/`, le moteur dans
    `/opt/moteur/` -- et `/workspace` est desormais VIDE au premier demarrage.

    Mesure du 12/08 20h32, travail afd29a95 : la capsule « Poussee d'Archimede »
    est arrivee sur la machine avec ses cinq scenes composees INTACTES, et le
    rendu est mort sur
        [Errno 2] No such file or directory: '/workspace/blender/blender'
    La machine s'etait pourtant declaree PRETE : la sonde verifie Chromium et
    WebGL, jamais Blender. Une readiness qui ne teste pas ce que la machine va
    faire ne vaut rien -- voir `sonde_pret.js`.

    L'ordre est deliberé : la variable d'environnement PRIME (elle permet de
    depanner une machine sans reconstruire l'image), puis le PATH, puis les
    emplacements connus. On garde `/workspace/...` en dernier recours pour les
    machines encore amorcees a l'ancienne.
    """
    impose = os.environ.get(variable)
    if impose:
        return impose
    trouve = shutil.which(nom)
    if trouve:
        return trouve
    for chemin in candidats:
        if os.path.exists(chemin):
            return chemin
    # On rend le nom nu plutot que rien : l'erreur d'execution nommera l'outil
    # manquant, ce qui reste plus lisible qu'un chemin invente.
    return nom


BLENDER = _trouver("blender", "BLENDER",
                   ("/opt/blender/blender", "/workspace/blender/blender"))
GENERATEUR = _trouver("generateur_scenes.py", "GENERATEUR",
                      ("/opt/moteur/generateur_scenes.py",
                       "/workspace/generateur_scenes.py"))
TRAVAIL = os.environ.get("TRAVAIL", "/workspace/capsule")

# Le moteur de rendu. `web` par defaut depuis le 18/08 ; `blender` reste
# joignable sans redeploiement, par la variable d'environnement du pod
# (`app.studio_config.env_pod`). On ne coupe pas un moteur eprouve le jour ou
# l'on en branche un neuf.
MOTEUR_RENDU = os.environ.get("MOTEUR_RENDU", "web").strip().lower()
RENDU_WEB = _trouver("rendre_capsule_web.js", "RENDU_WEB",
                     ("/opt/moteur/web/rendre_capsule_web.js",
                      "/workspace/web/rendre_capsule_web.js"))


def _env_rendu() -> dict:
    """L'environnement du sous-processus de rendu.

    `NODE_PATH` est indispensable : le script vit dans `/opt/moteur/web` et les
    modules dans `/opt/rendu/node_modules`. Node resout depuis le dossier du
    fichier vers le haut, il ne les trouverait donc jamais.
    """
    env = dict(os.environ)
    env.setdefault("NODE_PATH", "/opt/rendu/node_modules")
    return env
BUCKET = "studio-visuel"

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_ANON_KEY", "")


def journal(message: str) -> None:
    print(f"{time.strftime('%H:%M:%S')} {message}", flush=True)


def deposer(chemin: str, cle: str) -> tuple[bool, str]:
    """Depot dans le bucket prive. C'est l'etape qui fait EXISTER le resultat ;
    tout ce qui precede n'est que calcul jetable.

    PAS D'`x-upsert`. Il a coute une heure de diagnostic : l'ecrasement oblige
    Supabase a VERIFIER si l'objet existe, donc a le LIRE -- or la lecture du
    bucket est volontairement fermee, les videos ne sortant que par URL signee.
    Resultat : un 403 « row-level security » parfaitement trompeur, alors que
    la policy d'ecriture etait correcte.

    Le chemin horodate resout les deux problemes a la fois : plus besoin
    d'ecraser, et on conserve l'historique des rendus -- ce qui compte pour la
    validation editoriale, ou l'on veut pouvoir comparer deux versions.
    """
    if not (SUPABASE_URL and SUPABASE_KEY):
        return False, "configuration_supabase_absente"
    try:
        import urllib.request
        with open(chemin, "rb") as f:
            donnees = f.read()
        requete = urllib.request.Request(
            f"{SUPABASE_URL}/storage/v1/object/{BUCKET}/{cle}",
            data=donnees, method="POST",
            headers={
                "apikey": SUPABASE_KEY,
                "Authorization": f"Bearer {SUPABASE_KEY}",
                "Content-Type": "video/mp4",
            })
        with urllib.request.urlopen(requete, timeout=600) as reponse:
            return reponse.status < 300, str(reponse.status)
    except Exception as e:  # noqa: BLE001
        return False, str(e)[:200]


def recuperer_narration(capsule: dict) -> str | None:
    """Telecharge la bande produite par LWS, si elle existe.

    Degradation gracieuse : sans narration, la capsule est produite muette
    plutot que pas produite du tout. Le journal le dit clairement -- une
    capsule silencieuse par accident et une capsule silencieuse par choix ne
    doivent pas se ressembler.
    """
    # URL SIGNEE D'ABORD. Le pod n'a pas le droit de LIRE dans le bucket --
    # seule l'ecriture lui est ouverte, et c'est voulu. Sans URL signee, le
    # telechargement echouait en 403, la degradation gracieuse prenait le
    # relais, et la capsule sortait MUETTE sans que rien ne l'annonce.
    url = capsule.get("narration_url")
    if url:
        try:
            import urllib.request
            with urllib.request.urlopen(url, timeout=300) as reponse:
                donnees = reponse.read()
            chemin = os.path.join(TRAVAIL, "narration.wav")
            with open(chemin, "wb") as f:
                f.write(donnees)
            journal(f"NARRATION recuperee par URL signee — {len(donnees)//1024} Ko")
            return chemin
        except Exception as e:  # noqa: BLE001
            journal(f"NARRATION url signee inutilisable ({e}) — essai par cle")

    cle = capsule.get("narration_cle")
    if not cle:
        journal("NARRATION aucune bande annoncee — capsule muette")
        return None
    if not (SUPABASE_URL and SUPABASE_KEY):
        journal("NARRATION configuration absente — capsule muette")
        return None
    try:
        import urllib.request
        requete = urllib.request.Request(
            f"{SUPABASE_URL}/storage/v1/object/{BUCKET}/{cle}",
            headers={"apikey": SUPABASE_KEY,
                     "Authorization": f"Bearer {SUPABASE_KEY}"})
        with urllib.request.urlopen(requete, timeout=300) as reponse:
            donnees = reponse.read()
        chemin = os.path.join(TRAVAIL, "narration.wav")
        with open(chemin, "wb") as f:
            f.write(donnees)
        journal(f"NARRATION recuperee — {len(donnees)//1024} Ko")
        return chemin
    except Exception as e:  # noqa: BLE001
        journal(f"NARRATION indisponible ({e}) — capsule muette")
        return None


def executer(capsule: dict, travail: str | None = None) -> tuple[bool, str]:
    """Produit la capsule complete. Renvoie (succes, chemin_video | erreur).

    Extrait de `main` pour que le worker de la file l'appelle directement :
    sans cela, deux chemins de code auraient diverge -- l'un pour les rendus
    manuels, l'autre pour la file -- et un correctif applique a l'un aurait
    manque a l'autre. C'est exactement ainsi qu'on se retrouve avec une capsule
    muette d'un cote et sonore de l'autre.
    """
    global TRAVAIL
    if travail:
        TRAVAIL = travail

    capsule = academia_scene.normaliser(capsule)
    journal("CAPSULE " + academia_scene.resume(capsule))
    for correction in capsule["avertissements"]:
        journal(f"  correction: {correction}")

    images = os.path.join(TRAVAIL, "frames")
    os.makedirs(images, exist_ok=True)
    depart = time.time()

    # ── 1. Rendu, en DEUX voies ───────────────────────────────────────────
    # Les scenes `genere` passent par la generation d'images, les autres par
    # Blender. Une meme capsule melange donc structure et matiere -- ce qui est
    # tout l'interet : le raisonnement se lit dans la geometrie, l'emotion dans
    # la matiere.
    scenes_ia = [s for s in capsule["scenes"] if s["archetype"] in academia_scene.ARCHETYPES_IA]
    scenes_3d = [s for s in capsule["scenes"] if s["archetype"] not in academia_scene.ARCHETYPES_IA]

    if scenes_ia:
        journal(f"GENERATION IA — {len(scenes_ia)} scene(s)")
        import generateur_ia
        for scene in list(scenes_ia):
            produites = generateur_ia.rendre_scene(scene, capsule["format"], images)
            if produites == 0:
                # Degradation gracieuse : une scene qui n'a pas pu etre generee
                # devient `terrain`, qui illustre sans mentir. Mieux vaut une
                # capsule complete avec un plan de repli qu'un trou.
                journal(f"  {scene['id']} : generation impossible, repli sur `terrain`")
                scene["archetype"] = "terrain"
                scenes_3d.append(scene)

    if scenes_3d:
        journal(f"RENDU 3D — {len(scenes_3d)} scene(s)")
        partielle = dict(capsule, scenes=scenes_3d)
        with open(os.path.join(TRAVAIL, "capsule_normalisee.json"), "w", encoding="utf-8") as f:
            json.dump(partielle, f, ensure_ascii=False)

        # DEUX MOTEURS, UN SEUL CONTRAT.
        #
        # Les deux prennent un manifeste et un dossier, et y deposent des images
        # numerotees par scene. Tout ce qui suit -- sous-titres, voix, montage,
        # porte d'acceptation, depot -- ignore lequel a travaille.
        #
        # `web` est le defaut depuis le 18/08. Mesure sur la capsule « Poussee
        # d'Archimede », 5 scenes, 0 degradation : 1,069 s par image dans un
        # navigateur SANS carte graphique, contre ~1,3 s pour Blender sur une
        # RTX 4090 louee. L'ecart de vitesse est modeste ; ce qui disparait ne
        # l'est pas -- l'amorcage de 3 s a plus de 25 minutes selon l'hote, qui
        # a fait echouer la moitie des rendus de la semaine, la facturation a
        # l'heure, et les 4,47 Go a tirer avant chaque rendu.
        #
        # `MOTEUR_RENDU=blender` ramene l'ancien chemin sans rien redeployer :
        # on ne coupe pas un moteur eprouve le jour ou l'on en branche un neuf.
        if MOTEUR_RENDU == "blender":
            commande = [BLENDER, "-b", "--python", GENERATEUR, "--",
                        os.path.join(TRAVAIL, "capsule_normalisee.json"), images]
        else:
            commande = ["node", RENDU_WEB,
                        os.path.join(TRAVAIL, "capsule_normalisee.json"), images]
        journal(f"MOTEUR {MOTEUR_RENDU} — {commande[0]}")
        rendu = subprocess.run(commande, capture_output=True, text=True,
                               timeout=10800, env=_env_rendu())

        # COMPOSITION et DEGRADATION manquaient a cette liste, et ce sont les
        # deux seules lignes qui disent ce que la scene DECRITE est devenue.
        # Sans elles, une composition entierement degradee se lit exactement
        # comme une composition reussie.
        for ligne in rendu.stdout.splitlines():
            if ligne.startswith(("SCENE ", "GENERATEUR_", "CAPSULE ",
                                 "COMPOSITION ", "DEGRADATION ")):
                journal("  " + ligne)
    else:
        rendu = None

    # Blender depose des PNG, le navigateur des JPEG -- l'encodage PNG d'une
    # image 1080x1920 coute plus cher que son rendu. On accepte les deux : c'est
    # ffmpeg qui assemble, et il ne fait pas la difference.
    produites = [n for n in os.listdir(images)
                 if n.endswith(".png") or n.endswith(".jpg")]
    if not produites:
        # LA CAUSE DOIT REMONTER EN BASE, PAS MOURIR ICI.
        #
        # Le pod n'a ni sshd ni expedition de journaux : tout ce qui part sur la
        # sortie standard est perdu des que la machine s'eteint. Le 13/08, le
        # travail 962ddaf5 n'a laisse en base que « aucune_image_produite » --
        # exact, inutile, et impossible a diagnostiquer sans relouer un GPU.
        #
        # `erreur` est le SEUL canal qui survit a la machine. On y met donc les
        # lignes qui portent une cause, pas un resume rassurant.
        journal("ECHEC aucune image produite")
        detail = ""
        if rendu is not None:
            flux = f"{rendu.stderr or ''}\n{rendu.stdout or ''}"
            journal(flux[-1500:])
            marqueurs = ("Traceback", "Error:", "error:", "ModuleNotFound",
                         "ImportError", "Exception", "RuntimeError",
                         "DEGRADATION", "GENERATEUR_ECHEC")
            portantes = [l.strip() for l in flux.splitlines()
                         if any(m in l for m in marqueurs)]
            # Les DERNIERES lignes : sur une trace Python, la cause est en bas.
            detail = " | ".join(portantes[-6:])[:900]
            if not detail:
                detail = f"code {rendu.returncode}, sortie muette: " + \
                         " ".join(flux.split())[-300:]
        return False, f"aucune_image_produite — {detail}" if detail \
            else "aucune_image_produite — aucun rendu lance"
    journal(f"RENDU termine — {len(produites)} images en {int(time.time()-depart)}s")

    # ── 2. Sous-titres ────────────────────────────────────────────────────
    ass = os.path.join(TRAVAIL, "sous_titres.ass")
    nombre = montage.ecrire_sous_titres(capsule, ass)
    journal(f"SOUS-TITRES {nombre} ecrits")

    # ── 3. Narration ──────────────────────────────────────────────────────
    # Produite en amont sur LWS, deposee dans Storage, recuperee ici. Sans
    # cette etape la capsule sortait MUETTE : la voix existait, le montage
    # aussi, mais ils ne se rencontraient jamais -- et les deux journaux
    # affichaient un succes.
    bande = recuperer_narration(capsule)

    # ── 4. Assemblage ─────────────────────────────────────────────────────
    video = os.path.join(TRAVAIL, "capsule.mp4")
    ok, detail = montage.assembler(images, capsule, video, chemin_ass=ass, audio=bande)
    if not ok:
        journal(f"ECHEC assemblage: {detail}")
        return False, f"assemblage:{detail}"
    journal(f"ASSEMBLAGE termine — {os.path.getsize(video)//1024} Ko")

    # ── 4. Porte d'acceptation (etape 10 du cahier des charges) ───────────
    #
    # UN SEUL POINT DE PASSAGE, ET IL ECRIT TOUJOURS SES MESURES.
    # Les controles etaient auparavant disperses ici, chacun ne journalisant
    # que son propre echec. Une capsule ACCEPTEE ne laissait donc aucune trace
    # de ce qui avait ete verifie -- impossible, ensuite, de dire pourquoi elle
    # etait passee. `porte_acceptation` rend ses six mesures dans tous les cas.
    #
    # Ce qu'elle ajoute au controle precedent (mesure du 11/08) :
    #   - le SILENCE. `a_du_son` repondait True sur une piste de silence
    #     numerique : la moitie du defaut « noire et muette » du 05/08 n'etait
    #     pas mesuree du tout.
    #   - le FIGE. La camera recoit une cle a chaque image ; une image immobile
    #     plusieurs secondes est un rendu qui s'est arrete.
    #   - l'APLAT, une image uniforme qui passe le seuil de luminosite.
    #
    # Ce qu'elle NE change PAS : le son reste une ALERTE, jamais un refus. Les
    # sous-titres sont incrustes et la majorite des vues se font sans le son ;
    # refuser ferait perdre le cours entier pour la voix seule.
    #
    # Cout : trois passes ffmpeg supplementaires, quelques secondes -- a
    # comparer aux dizaines de minutes de rendu qu'elles protegent.
    verdict = montage.porte_acceptation(video, capsule)
    journal(f"CONTROLE {verdict['mesures']}")
    for avis in verdict["alertes"]:
        journal(f"ATTENTION {avis}")

    if not verdict["accepte"]:
        for motif in verdict["refus"]:
            journal(f"ECHEC {motif}")

        # ON GARDE CE QU'ON REFUSE. C'EST LA SEULE FACON DE SAVOIR SI ON A EU
        # RAISON DE REFUSER.
        #
        # Jusqu'ici la video refusee etait perdue avec la machine. Un refus
        # JUSTE et un refus FAUX se ressemblaient donc exactement : une ligne
        # d'erreur, et rien a regarder.
        #
        # Mesure du 18/08, travail 50b5236d « pluie » : 887 images rendues sur
        # 886 -- un rendu complet et sain -- refuse pour « image figee 3.16 s »
        # contre un seuil de 3,0. Faux refus tres probable, impossible a
        # prouver : le fichier n'existait plus.
        #
        # Le depot ne bloque JAMAIS : si Storage refuse, on le dit et on rend
        # quand meme le verdict. Perdre la preuve est un moindre mal ; perdre
        # le verdict serait pire.
        try:
            cle_refus = (f"refuses/{capsule['capsule_id']}/{int(depart)}/"
                         f"capsule.mp4")
            garde, detail_garde = deposer(video, cle_refus)
            journal(f"REFUS CONSERVE {'oui' if garde else 'non'} — "
                    f"{cle_refus if garde else detail_garde}")
        except Exception as e:  # noqa: BLE001
            journal(f"REFUS NON CONSERVE : {e}")
        # Code stable, pour que la cause reste lisible en base et dans les
        # journaux. L'ordre suit la gravite : illisible d'abord, puis ce qui
        # manque, puis ce qui est noir.
        premier = " ; ".join(verdict["refus"])
        for fragment, code in (
            ("illisible", "video_illisible"),
            ("tronquee", "duree_tronquee"),
            ("figee", "image_figee"),
            ("scene(s) noire(s)", "scenes_noires"),
            ("noire", "image_noire"),
        ):
            if fragment in premier:
                return False, f"{code}:{premier[:160]}"
        return False, f"refus:{premier[:160]}"

    # ── 5. Depot ──────────────────────────────────────────────────────────
    # Horodate : chaque rendu garde sa trace, et aucun ecrasement n'est
    # necessaire — voir `deposer`.
    cle = f"capsules/{capsule['capsule_id']}/{int(depart)}/capsule.mp4"
    depose, detail = deposer(video, cle)
    journal(f"DEPOT {'reussi' if depose else 'ECHEC'} — {cle} ({detail})")
    if not depose:
        return False, f"depot:{detail}"

    total = int(time.time() - depart)
    journal(f"TERMINE en {total}s — cout GPU estime {total/3600*0.44:.3f} USD")
    journal(f"RESULTAT {BUCKET}/{cle}")
    return True, cle


def main() -> int:
    if len(sys.argv) < 2:
        journal("ERREUR chemin_json_manquant")
        return 1
    with open(sys.argv[1], encoding="utf-8") as f:
        capsule = json.load(f)
    ok, detail = executer(capsule)
    if not ok:
        journal(f"ECHEC {detail}")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
