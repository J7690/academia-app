#!/usr/bin/env python3
"""Backfill H.264 main videos for challenge participations.

Ce script parcourt les participations de challenges qui ont une `submission_url`
mais pas de `video_url`, télécharge la vidéo source, la transcode en H.264/AAC
via ffmpeg, l'upload dans le bucket `challenge-media` (dossier `renders/`),
insère une ligne dans `app.challenge_participation_videos` et met à jour
`app.challenge_participations.video_url`.

Il utilise la RPC `execute_sql` et les en-têtes définis dans `.windsurf/auto_supabase_import.py`.

ATTENTION :
- Nécessite ffmpeg installé et disponible dans le PATH.
- Modifie la base Supabase (INSERT/UPDATE). A utiliser d'abord sur un petit batch.
"""

from __future__ import annotations

import json
import os
import uuid
import tempfile
import subprocess
from typing import Any, Dict, List

import requests

from auto_supabase_import import SUPABASE_URL, SUPABASE_SERVICE_KEY, RPC_HEADERS
from supabase_auto_manager import SupabaseAutoManager

EXECUTE_SQL_URL = f"{SUPABASE_URL}/rest/v1/rpc/execute_sql"

_ADMIN_MANAGER = SupabaseAutoManager()
ADMIN_SQL_URL = f"{_ADMIN_MANAGER.url}/rest/v1/rpc/admin_execute_sql"
ADMIN_HEADERS = _ADMIN_MANAGER.headers


def execute_sql(label: str, sql: str) -> List[Dict[str, Any]]:
    """Exécute une requête SQL arbitraire via la RPC execute_sql.

    Retourne une liste de lignes (dictionnaires) en cas de SELECT/RETURNING.
    Lève une exception en cas d'erreur.
    """
    print(f"\n=== {label} ===")
    print(sql)

    resp = requests.post(
        EXECUTE_SQL_URL,
        headers=RPC_HEADERS,
        json={"sql_query": sql},
        timeout=120,
    )
    print("STATUS", resp.status_code)
    resp.raise_for_status()

    data = resp.json()
    # Suivant la version de execute_sql, la forme peut être une liste de lignes
    # ou un dict contenant une clé "error".
    if isinstance(data, dict) and "error" in data:
        raise RuntimeError(f"SQL error: {data}")
    if isinstance(data, list):
        return data
    # execute_sql peut retourner NULL (JSON null) quand il n'y a aucune ligne
    # -> on interprète cela comme "aucun résultat".
    if data is None:
        return []
    raise RuntimeError(f"Unexpected execute_sql response: {data!r}")


def admin_execute_sql(label: str, sql: str) -> None:
    """Exécute un statement SQL (DML/DDL) via admin_execute_sql.

    Utilisé pour les INSERT/UPDATE sur le schéma app, conformément aux
    patterns .windsurf (apply_academia_schema_via_admin_rpc).
    """
    print(f"\n=== ADMIN_SQL {label} ===")
    print(sql)
    resp = requests.post(
        ADMIN_SQL_URL,
        headers=ADMIN_HEADERS,
        json={"p_sql": sql},
        timeout=60,
    )
    print("ADMIN_STATUS", resp.status_code)
    if resp.status_code != 200:
        # On affiche le corps brut pour debug, puis on remonte une erreur.
        try:
            body = resp.json()
        except ValueError:
            body = {"raw": resp.text[:500]}
        raise RuntimeError(f"admin_execute_sql failed HTTP {resp.status_code}: {body}")


def fetch_participations_batch(limit: int = 5, exclude_ids: List[str] | None = None) -> List[Dict[str, Any]]:
    """Récupère un petit batch de participations à backfiller.

    exclude_ids permet d'éviter de retraiter plusieurs fois les mêmes
    participations au sein d'une même exécution, même en cas d'erreur.
    """

    exclude_clause = ""
    if exclude_ids:
        # Sécuriser les UUID dans la clause IN
        safe_ids = ",".join(f"'{pid.replace("'", "''")}'" for pid in exclude_ids)
        exclude_clause = f"      AND id NOT IN ({safe_ids})\n"

    sql = f"""
    SELECT id, submission_url
    FROM app.challenge_participations
    WHERE is_active = TRUE
      AND submission_url IS NOT NULL
      AND (video_url IS NULL OR video_url = submission_url)
{exclude_clause}    ORDER BY COALESCE(submitted_at, started_at) ASC
    LIMIT {limit}
    """
    return execute_sql("BATCH_PARTICIPATIONS", sql)


def download_source(url: str) -> str:
    """Télécharge la vidéo source dans un fichier temporaire et retourne son chemin."""
    url = (url or "").strip()
    if not url:
        raise ValueError("Empty source URL")

    resp = requests.get(url, timeout=600)
    if resp.status_code >= 400:
        raise RuntimeError(f"Download failed ({resp.status_code}) for {url}")

    tmp_dir = tempfile.mkdtemp(prefix="challenge_src_")
    input_path = os.path.join(tmp_dir, f"input_{uuid.uuid4().hex}.mp4")
    with open(input_path, "wb") as f:
        f.write(resp.content)
    return input_path


def transcode_to_h264(input_path: str) -> str:
    """Transcode la vidéo source en H.264/AAC .mp4 via ffmpeg et retourne le chemin de sortie."""
    tmp_dir = os.path.dirname(input_path)
    output_path = os.path.join(tmp_dir, f"rendered_{uuid.uuid4().hex}.mp4")

    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        input_path,
        # Limiter la résolution pour rester dans les capacités des décodeurs
        # mobiles (max ~1280px de large).
        "-vf",
        "scale='if(gt(iw,1280),1280,iw)':-2",
        "-c:v",
        "libx264",
        # Forcer un profil/level largement supporté par les SoC Android.
        "-profile:v",
        "baseline",
        "-level:v",
        "3.0",
        # Désactiver explicitement les options High Profile pour éviter que
        # le fichier sorte en High (avc1.64...) sur certains ffmpeg/x264.
        "-x264-params",
        "ref=1:bframes=0:cabac=0:deblock=0",
        "-preset",
        "veryfast",
        "-crf",
        "23",
        # Format de pixels universellement supporté.
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        "-b:a",
        "128k",
        output_path,
    ]

    proc = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"ffmpeg failed ({proc.returncode}): "
            f"{proc.stderr.decode(errors='ignore')[:500]}"
        )

    return output_path


def upload_rendered(participation_id: str, path: str) -> str:
    """Upload la vidéo rendue dans Supabase Storage et retourne l'URL publique."""
    object_key = f"renders/{participation_id}/{uuid.uuid4().hex}.mp4"
    bucket = "challenge-media"
    storage_url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{object_key}"

    headers = {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "video/mp4",
    }

    with open(path, "rb") as f:
        data = f.read()

    resp = requests.post(storage_url, headers=headers, data=data, timeout=600)
    if resp.status_code >= 400:
        try:
            body = resp.json()
        except ValueError:
            body = {"raw": resp.text}
        raise RuntimeError(f"Upload failed ({resp.status_code}): {body}")

    public_url = f"{SUPABASE_URL}/storage/v1/object/public/{bucket}/{object_key}"
    return public_url


def record_render_in_db(participation_id: str, rendered_url: str) -> None:
    """Insère la vidéo rendue et met à jour video_url pour la participation.

    Utilise l'API REST PostgREST avec le service_role, conformément aux
    procédures .windsurf (RPC pour le SQL complexe, REST pour le CRUD simple).
    """

    # 1) Insérer dans app.challenge_participation_videos (schéma app) via admin_execute_sql
    safe_url = rendered_url.replace("'", "''")
    safe_pid = participation_id.replace("'", "''")

    sql_insert = f"""
    INSERT INTO app.challenge_participation_videos (participation_id, video_url, thumbnail_url)
    VALUES ('{safe_pid}', '{safe_url}', NULL)
    """
    admin_execute_sql("INSERT_render_video", sql_insert)

    # 2) Mettre à jour app.challenge_participations.video_url
    sql_update = f"""
    UPDATE app.challenge_participations
    SET video_url = '{safe_url}'
    WHERE id = '{safe_pid}'
    """
    admin_execute_sql("UPDATE_main_video_url", sql_update)


def backfill_once(batch_size: int, attempted_ids: set[str]) -> int:
    """Traite un batch de participations.

    Retourne le nombre de participations traitées.
    """
    rows = fetch_participations_batch(limit=batch_size, exclude_ids=list(attempted_ids))
    if not rows:
        print("No more participations to backfill.")
        return 0

    for row in rows:
        pid = row.get("id")
        src = row.get("submission_url")
        print(f"\n--- Participation {pid} ---")

        # Marquer cette participation comme tentée pour ne pas la retraiter
        # lors de cette exécution, même si une erreur survient ensuite.
        if isinstance(pid, str):
            attempted_ids.add(pid)

        input_path = None
        output_path = None
        try:
            input_path = download_source(src)
            output_path = transcode_to_h264(input_path)
            final_url = upload_rendered(pid, output_path)
            record_render_in_db(pid, final_url)
            print(f"[OK] Rendered and updated participation {pid}")
        except Exception as exc:
            print(f"[ERROR] Failed for participation {pid}: {exc}")
        finally:
            # Nettoyage best-effort des fichiers temporaires
            for p in (input_path, output_path):
                if p and os.path.exists(p):
                    try:
                        os.remove(p)
                    except Exception:
                        pass

    return len(rows)


def main() -> int:
    total = 0
    attempted_ids: set[str] = set()
    while True:
        processed = backfill_once(batch_size=5, attempted_ids=attempted_ids)
        if processed == 0:
            break
        total += processed

    print(f"\nDone. Total participations processed: {total}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
