#!/usr/bin/env python3
"""Generation d'images et d'animations par IA — la voie « matiere » du Studio.

Complete `generateur_scenes.py`, qui fait la voie « structure ». Les deux
cohabitent dans une meme capsule, scene par scene :

    structure  reseaux, frises, comparaisons, flux de donnees
               deterministe, rejouable, porte le RAISONNEMENT
    matiere    corps, atmosphere, texture, vivant
               non deterministe, porte l'EMOTION et accroche l'oeil

MESURES DU 04/08/2026 SUR A40, qui commandent toute la conception :

    image fixe        30 s   23,8 Go de VRAM   0,004 $
    animation WAN    213 s pour 3 s de video   0,026 $  (71x le temps reel)
    mouvement ffmpeg   ~0 s                    ~0 $

LA DISTINCTION QUI DECIDE DU COUT. Une animation WAN coute 71 fois le temps
reel ; un travelling sur une image fixe ne coute rien. Or la plupart des plans
des references analysees sont exactement cela : une image somptueuse et une
camera qui avance lentement.

    => `mouvement` par defaut, `animation` seulement quand la matiere doit
       VIVRE -- de la fumee qui monte, un fluide qui coule.

Se tromper de mode multiplie la facture par cinquante sans rien apporter.
"""

from __future__ import annotations

import os
import subprocess
import sys
import time

# La grammaire commune. Chaque image la porte, quel que soit le sujet : c'est
# ce qui fait qu'une chaine garde son identite sur des themes sans rapport.
STYLE = ("dark navy background, glowing cyan wireframe lines, volumetric fog, "
         "cinematic lighting, holographic, orange red accent light, high detail, "
         "vertical composition")
NEGATIF = "blurry, distorted, text, watermark, logo, signature, washed out"

MODELE_IMAGE = os.environ.get("STUDIO_MODELE_IMAGE", "shuttleai/shuttle-3-diffusion")
MODELE_VIDEO = os.environ.get("STUDIO_MODELE_VIDEO", "Wan-AI/Wan2.2-TI2V-5B-Diffusers")

_pipe_image = None
_pipe_video = None


def journal(message: str) -> None:
    print(f"{time.strftime('%H:%M:%S')} [ia] {message}", flush=True)


def _charger_image():
    """Charge le modele UNE fois. Le rechargement coute 40 a 70 secondes, et
    une capsule de six scenes le paierait six fois."""
    global _pipe_image
    if _pipe_image is None:
        import torch
        from diffusers import DiffusionPipeline
        t = time.time()
        _pipe_image = DiffusionPipeline.from_pretrained(MODELE_IMAGE, torch_dtype=torch.bfloat16)
        _pipe_image.enable_model_cpu_offload()
        journal(f"modele d'images charge en {time.time()-t:.0f}s")
    return _pipe_image


def produire_image(sujet: str, chemin: str, largeur: int, hauteur: int, graine: int = 7) -> bool:
    try:
        import torch
        pipe = _charger_image()
        t = time.time()
        image = pipe(f"{sujet}, {STYLE}", negative_prompt=NEGATIF,
                     num_inference_steps=4, guidance_scale=3.5,
                     height=hauteur, width=largeur,
                     generator=torch.Generator("cpu").manual_seed(graine)).images[0]
        image.save(chemin)
        journal(f"image produite en {time.time()-t:.0f}s — {os.path.basename(chemin)}")
        return True
    except Exception as e:  # noqa: BLE001
        journal(f"image impossible : {e}")
        return False


def _sauver_images(sequence, dossier: str, prefixe: str) -> int:
    """Ecrit les images d'une sequence, qu'elles soient PIL ou numpy.

    Deviner le format a coute DEUX cycles de generation complets le 04/08 : le
    calcul reussissait, l'ecriture echouait, et il fallait tout recommencer.
    On gere donc les deux plutot que de supposer.
    """
    from PIL import Image
    import numpy as np

    os.makedirs(dossier, exist_ok=True)
    n = 0
    for i, img in enumerate(sequence):
        if not hasattr(img, "save"):
            a = np.asarray(img)
            if a.dtype != np.uint8:
                a = (a.clip(0, 1) * 255).astype(np.uint8)
            img = Image.fromarray(a)
        img.save(os.path.join(dossier, f"{prefixe}{i:04d}.png"))
        n += 1
    return n


def mouvement_camera(image: str, dossier: str, prefixe: str, images: int,
                     fps: int, largeur: int, hauteur: int, sens: str = "zoom") -> int:
    """Un travelling lent sur une image fixe. Cout : quasi nul.

    C'est le mode par defaut, et ce n'est pas un pis-aller : la plupart des
    plans des references sont exactement cela. Une image somptueuse et une
    camera qui avance. L'oeil lit du mouvement, la facture ne bouge pas.
    """
    os.makedirs(dossier, exist_ok=True)
    if sens == "pano":
        expr = (f"zoompan=z=1.12:x='iw*0.06*on/{images}':y='ih*0.03*on/{images}'"
                f":d=1:s={largeur}x{hauteur}:fps={fps}")
    elif sens == "recul":
        expr = (f"zoompan=z='1.18-0.16*on/{images}':x='iw/2-(iw/zoom/2)'"
                f":y='ih/2-(ih/zoom/2)':d=1:s={largeur}x{hauteur}:fps={fps}")
    else:   # zoom avant, le plus courant
        expr = (f"zoompan=z='1.0+0.16*on/{images}':x='iw/2-(iw/zoom/2)'"
                f":y='ih/2-(ih/zoom/2)':d=1:s={largeur}x{hauteur}:fps={fps}")

    r = subprocess.run([
        "ffmpeg", "-y", "-v", "error", "-loop", "1", "-i", image,
        "-vf", expr, "-frames:v", str(images),
        os.path.join(dossier, f"{prefixe}%04d.png"),
    ], capture_output=True, text=True, timeout=900)
    if r.returncode != 0:
        journal(f"mouvement impossible : {r.stderr[-200:]}")
        return 0
    produites = len([f for f in os.listdir(dossier) if f.startswith(prefixe)])
    journal(f"{produites} images de mouvement « {sens} »")
    return produites


def animer(image: str, dossier: str, prefixe: str, images: int, sujet: str,
           largeur: int, hauteur: int) -> int:
    """Vraie animation par WAN. 71x le temps reel — a n'employer que si la
    matiere doit VIVRE : fumee qui monte, fluide qui coule, particules."""
    global _pipe_video
    try:
        import torch
        from diffusers import AutoencoderKLWan, WanImageToVideoPipeline
        from diffusers.utils import load_image

        if _pipe_video is None:
            t = time.time()
            vae = AutoencoderKLWan.from_pretrained(MODELE_VIDEO, subfolder="vae",
                                                   torch_dtype=torch.float32)
            _pipe_video = WanImageToVideoPipeline.from_pretrained(
                MODELE_VIDEO, vae=vae, torch_dtype=torch.bfloat16)
            _pipe_video.enable_model_cpu_offload()
            journal(f"modele video charge en {time.time()-t:.0f}s")

        t = time.time()
        sortie = _pipe_video(
            image=load_image(image).resize((largeur, hauteur)),
            prompt=f"slow cinematic camera movement, {sujet}, {STYLE}",
            negative_prompt=NEGATIF,
            height=hauteur, width=largeur, num_frames=images,
            guidance_scale=5.0, num_inference_steps=25,
            generator=torch.Generator("cpu").manual_seed(7)).frames[0]
        journal(f"animation calculee en {time.time()-t:.0f}s pour {images} images")
        return _sauver_images(sortie, dossier, prefixe)
    except Exception as e:  # noqa: BLE001
        journal(f"animation impossible ({e}) — repli sur le mouvement de camera")
        return 0


def rendre_scene(scene: dict, format_capsule: dict, dossier: str) -> int:
    """Produit les images d'une scene `genere`. Renvoie leur nombre.

    Degradation gracieuse en cascade : si l'animation echoue on retombe sur le
    mouvement de camera, et si l'image elle-meme echoue on rend la main pour
    que l'appelant remplace la scene par un archetype procedural. Une capsule
    imparfaite vaut mieux qu'une capsule absente.
    """
    p = scene.get("parametres") or {}
    sujet = str(p.get("sujet") or scene.get("titre") or "abstract glowing structure")
    mode = str(p.get("mode") or "mouvement").lower()
    sens = str(p.get("sens") or "zoom").lower()

    fps = format_capsule["fps"]
    largeur, hauteur = format_capsule["largeur"], format_capsule["hauteur"]
    images = max(1, int(round(scene["duree_s"] * fps)))
    prefixe = scene["id"] + "_"

    # Le modele travaille sur une taille multiple de 16 ; on genere plus petit
    # et ffmpeg agrandit au montage. La difference ne se voit pas sur un
    # telephone, et le temps de calcul suit le carre de la resolution.
    lg_gen = (largeur // 32) * 16
    ht_gen = (hauteur // 32) * 16

    fixe = os.path.join(dossier, f"{scene['id']}_source.png")
    if not produire_image(sujet, fixe, lg_gen, ht_gen):
        return 0

    if mode == "animation":
        n = animer(fixe, dossier, prefixe, images, sujet, lg_gen, ht_gen)
        if n > 0:
            return n

    return mouvement_camera(fixe, dossier, prefixe, images, fps, largeur, hauteur, sens)
