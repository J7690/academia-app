#!/usr/bin/env python3
"""Worker du Studio visuel, tournant sur le pod GPU.

Il interroge `app.studio_jobs` vers l'exterieur, exactement comme le worker
Smart Whiteboard interroge `whiteboard_renders` : aucun port entrant, aucun
tunnel, rien a ouvrir sur le pare-feu, et l'adresse changeante du pod n'a
aucune importance.

LA REGLE QUI A ETE PAYEE. Le 30/07, une capsule a ete rendue avec succes puis
PERDUE : le veilleur a supprime la machine pendant qu'on telechargeait le
fichier a la main, et `podTerminate` efface /workspace. Un resultat qui n'est
pas sorti de la machine n'existe pas.
    => Le depot dans Supabase Storage fait partie du travail. Le job n'est
       marque termine QU'APRES l'upload, jamais avant.

Le pod s'authentifie par son jeton, jamais par la cle de service : il tourne
sur une machine louee dont nous ne controlons pas l'hote.

Variables attendues : POD_ID, POD_JETON, SUPABASE_URL, SUPABASE_ANON_KEY
"""

import json
import os
import pathlib
import shutil
import subprocess
import sys
import time

import requests

POD_ID = os.environ.get("POD_ID", "")
POD_JETON = os.environ.get("POD_JETON", "")
SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_ANON_KEY", "")

BLENDER = "/workspace/blender/blender"
TRAVAIL = pathlib.Path("/workspace/travaux")
BUCKET = "studio-visuel"
INTERVALLE = int(os.environ.get("INTERVALLE_FILE", "20"))

# Le rendu peut durer une heure : une coupure reseau ne doit pas tuer le job.
DELAI_HTTP = 30


def journal(message: str) -> None:
    print(f"{time.strftime('%Y-%m-%dT%H:%M:%S')} {message}", flush=True)


def rpc(nom: str, corps: dict):
    """Appel d'une fonction SECURITY DEFINER. Renvoie None plutot que de lever :
    un worker ne doit pas mourir parce que le reseau a hoquete."""
    try:
        r = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/{nom}",
            headers={
                "apikey": SUPABASE_KEY,
                "Authorization": f"Bearer {SUPABASE_KEY}",
                "Content-Type": "application/json",
            },
            json=corps,
            timeout=DELAI_HTTP,
        )
        if r.status_code >= 300:
            journal(f"rpc {nom} -> HTTP {r.status_code} {r.text[:200]}")
            return None
        return r.json()
    except Exception as e:  # noqa: BLE001
        journal(f"rpc {nom} -> {e}")
        return None


def deposer(chemin: pathlib.Path, cle: str) -> bool:
    """Depose un fichier dans le bucket prive. C'est l'etape qui fait exister
    le resultat -- tout le reste n'est que calcul jetable."""
    try:
        with chemin.open("rb") as f:
            r = requests.post(
                f"{SUPABASE_URL}/storage/v1/object/{BUCKET}/{cle}",
                headers={
                    "apikey": SUPABASE_KEY,
                    "Authorization": f"Bearer {SUPABASE_KEY}",
                    "Content-Type": "video/mp4",
                },
                data=f,
                timeout=600,
            )
        if r.status_code >= 300:
            journal(f"depot refuse HTTP {r.status_code} {r.text[:200]}")
            return False
        return True
    except Exception as e:  # noqa: BLE001
        journal(f"depot impossible : {e}")
        return False


def rendre(job: dict, dossier: pathlib.Path) -> tuple[str | None, str | None]:
    """Delegue a `executer_capsule`, qui sait tout faire : rendu, sous-titres,
    narration, montage, controle et depot.

    Le worker ne refait PAS le travail lui-meme. Il l'a fait un temps, avec son
    propre ffmpeg et son propre schema de manifeste -- et les deux chemins ont
    diverge : l'un produisait des capsules sonores, l'autre des capsules
    muettes. Un seul chemin de code, un seul correctif a appliquer.

    Le manifeste EST la definition de capsule, telle que LWS l'a calee sur la
    voix reelle.
    """
    import executer_capsule

    manifeste = job.get("manifeste") or {}
    if not manifeste.get("scenes"):
        return None, "manifeste_sans_scenes"

    ok, detail = executer_capsule.executer(manifeste, str(dossier))
    return (detail, None) if ok else (None, detail)


def traiter(job: dict) -> None:
    journal(f"job {job['id']} — {job.get('titre')}")
    dossier = TRAVAIL / str(job["id"])
    if dossier.exists():
        shutil.rmtree(dossier, ignore_errors=True)
    dossier.mkdir(parents=True, exist_ok=True)

    debut = time.time()
    cle, erreur = rendre(job, dossier)

    if erreur:
        journal(f"echec : {erreur}")
        rpc("studio_terminer_job", {
            "p_job_id": job["id"], "p_pod_id": POD_ID, "p_jeton": POD_JETON,
            "p_erreur": erreur,
        })
        shutil.rmtree(dossier, ignore_errors=True)
        return

    rpc("studio_terminer_job", {
        "p_job_id": job["id"], "p_pod_id": POD_ID, "p_jeton": POD_JETON,
        "p_chemin_video": cle,
        "p_secondes_rendu": int(time.time() - debut),
    })
    journal(f"job {job['id']} depose : {cle}")
    shutil.rmtree(dossier, ignore_errors=True)


def main() -> int:
    for nom, valeur in (("POD_ID", POD_ID), ("POD_JETON", POD_JETON),
                        ("SUPABASE_URL", SUPABASE_URL), ("SUPABASE_ANON_KEY", SUPABASE_KEY)):
        if not valeur:
            journal(f"variable manquante : {nom}")
            return 1

    TRAVAIL.mkdir(parents=True, exist_ok=True)
    journal(f"worker demarre sur {POD_ID}")

    while True:
        reponse = rpc("studio_prendre_job", {"p_pod_id": POD_ID, "p_jeton": POD_JETON})
        job = (reponse or {}).get("job") if isinstance(reponse, dict) else None
        if job:
            try:
                traiter(job)
            except Exception as e:  # noqa: BLE001
                journal(f"exception : {e}")
                rpc("studio_terminer_job", {
                    "p_job_id": job["id"], "p_pod_id": POD_ID, "p_jeton": POD_JETON,
                    "p_erreur": f"exception:{e}"[:300],
                })
        else:
            time.sleep(INTERVALLE)


if __name__ == "__main__":
    sys.exit(main())
