#!/usr/bin/env python3
"""Etablit POURQUOI les scenes `genere` rendent du noir. Une seule session GPU.

POURQUOI CE FICHIER EXISTE SEPAREMENT.
Le noir des scenes generees n'a pas de cause etablie, et deux hypotheses ont
deja ete refutees :

  * le mouvement de camera et le montage -- elimines par reproduction locale
    avec une source coloree (luminosite 129,46/255) ;
  * le debordement du VAE en `bfloat16` -- refute par les sources datees
    (diffusers #9096 du 06/08/2024, FLUX.1-schnell #30 du 09/08/2024,
    InvokeAI #7208 du 26/10/2024) : toutes attribuent les images noires a
    `float16` et prescrivent `bfloat16` comme CORRECTIF, ce que le code fait
    deja.

On ne devinera donc pas une troisieme fois. Ce script MESURE, sur la machine,
ce que personne n'a encore regarde : la version de diffusers, le dtype
effectif de chaque sous-modele, l'etat des latents avant decodage, et la
luminosite obtenue pour trois variantes de reglages.

UNE MACHINE AU COMPTEUR N'EST PAS UN ATELIER. Tout est prepare hors ligne, on
lance une fois, on releve, on eteint.

Usage sur le pod :
    python3 diagnostic_genere.py [dossier_sortie]
"""

from __future__ import annotations

import json
import os
import sys
import time

SORTIE = sys.argv[1] if len(sys.argv) > 1 else "/workspace/diag_genere"
os.makedirs(SORTIE, exist_ok=True)

MODELE = os.environ.get("STUDIO_MODELE_IMAGE", "shuttleai/shuttle-3-diffusion")
SUJET = ("cross-section of a tall tree trunk, glowing water column rising, "
         "dark navy background, glowing cyan wireframe lines, volumetric fog, "
         "cinematic lighting, vertical composition")
LARGEUR, HAUTEUR = 528, 960


def journal(m: str) -> None:
    print(f"{time.strftime('%H:%M:%S')} [diag] {m}", flush=True)


def luminosite(image) -> float:
    from PIL import ImageStat
    return round(ImageStat.Stat(image.convert("L")).mean[0], 2)


def stats_latents(pipe, resultats: dict) -> None:
    """Accroche un mouchard sur la sortie du transformeur : si les latents
    contiennent des NaN ou des valeurs aberrantes AVANT le decodage, la cause
    est en amont du VAE ; s'ils sont sains et que l'image sort noire, elle est
    dans le VAE. C'est la mesure qui separe les deux, et elle n'a jamais ete
    prise."""
    import torch

    original = pipe.vae.decode

    def espion(latents, *a, **k):
        try:
            t = latents if isinstance(latents, torch.Tensor) else latents[0]
            resultats["latents"] = {
                "dtype": str(t.dtype),
                "forme": list(t.shape),
                "min": round(float(t.min()), 4),
                "max": round(float(t.max()), 4),
                "moyenne": round(float(t.mean()), 4),
                "nan": int(torch.isnan(t).sum()),
                "inf": int(torch.isinf(t).sum()),
            }
        except Exception as e:  # noqa: BLE001
            resultats["latents"] = {"erreur": str(e)[:120]}
        return original(latents, *a, **k)

    pipe.vae.decode = espion


def environnement() -> dict:
    infos = {}
    try:
        import torch
        infos["torch"] = torch.__version__
        infos["cuda"] = torch.version.cuda
        infos["gpu"] = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "AUCUN"
    except Exception as e:  # noqa: BLE001
        infos["torch"] = f"erreur: {e}"
    for module in ("diffusers", "transformers", "accelerate"):
        try:
            infos[module] = __import__(module).__version__
        except Exception as e:  # noqa: BLE001
            infos[module] = f"erreur: {e}"
    return infos


def dtypes(pipe) -> dict:
    d = {}
    for nom in ("transformer", "text_encoder", "text_encoder_2", "vae"):
        composant = getattr(pipe, nom, None)
        if composant is not None and hasattr(composant, "dtype"):
            d[nom] = str(composant.dtype)
    return d


def essai(pipe, libelle: str, **reglages) -> dict:
    import torch
    resultats: dict = {"variante": libelle, "reglages": {k: str(v) for k, v in reglages.items()}}
    stats_latents(pipe, resultats)
    depart = time.time()
    try:
        image = pipe(f"{SUJET}", height=HAUTEUR, width=LARGEUR,
                     generator=torch.Generator("cpu").manual_seed(7),
                     **reglages).images[0]
        chemin = os.path.join(SORTIE, f"{libelle}.png")
        image.save(chemin)
        resultats["luminosite"] = luminosite(image)
        resultats["fichier"] = chemin
        resultats["secondes"] = round(time.time() - depart, 1)
        resultats["verdict"] = "NOIRE" if resultats["luminosite"] < 6.0 else "VISIBLE"
    except Exception as e:  # noqa: BLE001
        resultats["erreur"] = str(e)[:300]
        resultats["verdict"] = "ERREUR"
    journal(f"{libelle:<22} {resultats.get('verdict'):<8} "
            f"luminosite={resultats.get('luminosite')} "
            f"latents={resultats.get('latents')}")
    return resultats


def main() -> int:
    rapport: dict = {"modele": MODELE, "environnement": environnement()}
    journal(f"environnement : {json.dumps(rapport['environnement'])}")

    import torch
    from diffusers import DiffusionPipeline

    t = time.time()
    pipe = DiffusionPipeline.from_pretrained(MODELE, torch_dtype=torch.bfloat16)
    pipe.enable_model_cpu_offload()
    journal(f"modele charge en {time.time()-t:.0f}s — classe {type(pipe).__name__}")
    rapport["classe_pipeline"] = type(pipe).__name__
    rapport["dtypes"] = dtypes(pipe)
    journal(f"dtypes : {json.dumps(rapport['dtypes'])}")

    essais = []

    # 1. EXACTEMENT ce que fait la production aujourd'hui.
    essais.append(essai(pipe, "1_production_actuelle",
                        num_inference_steps=4, guidance_scale=3.5))

    # 2. Sans guidage. FLUX schnell est distille : `guidance_scale` y est
    #    inerte ou nuisible selon les versions. Le reglage 3,5 n'a jamais ete
    #    justifie par une mesure.
    essais.append(essai(pipe, "2_sans_guidage",
                        num_inference_steps=4, guidance_scale=0.0))

    # 3. VAE en float32. C'est le correctif le plus souvent prescrit quand le
    #    decodage sature ; il coute de la memoire, pas de la qualite.
    try:
        pipe.vae.to(torch.float32)
        rapport["dtypes_apres_upcast"] = dtypes(pipe)
        essais.append(essai(pipe, "3_vae_float32",
                            num_inference_steps=4, guidance_scale=0.0))
    except Exception as e:  # noqa: BLE001
        essais.append({"variante": "3_vae_float32", "erreur": str(e)[:200]})

    rapport["essais"] = essais
    visibles = [e for e in essais if e.get("verdict") == "VISIBLE"]
    rapport["conclusion"] = (
        "aucune variante ne produit d'image" if not visibles
        else f"variante retenue : {visibles[0]['variante']} "
             f"(luminosite {visibles[0]['luminosite']})")
    journal("CONCLUSION " + rapport["conclusion"])

    chemin = os.path.join(SORTIE, "rapport.json")
    with open(chemin, "w", encoding="utf-8") as f:
        json.dump(rapport, f, ensure_ascii=False, indent=2)
    journal(f"RAPPORT {chemin}")
    print("DIAGNOSTIC_TERMINE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
