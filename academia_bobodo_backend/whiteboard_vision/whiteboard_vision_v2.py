"""
Vision v2 — Point d'entrée unique pour le worker.

Enchaîne les trois briques validées le 25/07/2026 :
    1. construire UNE page HTML animée contenant tout le cours (whiteboard_page_builder)
    2. la FILMER pendant que les animations se jouent (whiteboard_video_capture)
    3. y coller la narration déjà produite

Différence avec Vision v1 : v1 prenait une capture d'écran par scène et assemblait des
images fixes (diaporama). v2 filme une page qui défile, écrit à la main, annote et
rappelle — le tout à ~1,5x le temps réel, mesuré.

ORDRE IMPORTANT : la narration est générée AVANT la page, car c'est elle qui fixe la
durée de chaque scène (la voix ne doit jamais être coupée). La page est ensuite calée
sur ces durées, et l'enregistrement dure exactement le temps prévu.
"""

from __future__ import annotations

import logging
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger("whiteboard_vision_v2")

try:  # imports tolérants : le module doit pouvoir être testé isolément
    from whiteboard_page_builder import write_page, plan, INTRO_SEC
    from whiteboard_video_capture import record_page_parallel
    from whiteboard_sound_design import build_full_mix
except ImportError:  # pragma: no cover
    from .whiteboard_page_builder import write_page, plan, INTRO_SEC  # type: ignore
    from .whiteboard_video_capture import record_page_parallel  # type: ignore
    from .whiteboard_sound_design import build_full_mix  # type: ignore


def planned_duration(
    storyboard: Dict[str, Any],
    narration: Optional[List[Dict[str, Any]]] = None,
) -> float:
    """Durée totale que fera la vidéo, d'après le storyboard et la narration."""
    return plan(storyboard, narration)[2]


MEASURE_SCRIPT = Path(__file__).with_name("measure_page.js")
if not MEASURE_SCRIPT.exists():  # pragma: no cover
    MEASURE_SCRIPT = Path("/opt/whiteboard-worker/vision_engine/measure_page.js")


def _measure(page: Path) -> Optional[List[Dict[str, int]]]:
    """
    Relève la position réelle de chaque bloc en ouvrant la page dans le navigateur.

    Retourne None en cas d'échec : on rendra alors avec les positions estimées, moins
    précises mais fonctionnelles — mieux vaut une caméra approximative qu'aucune vidéo.
    """
    import json as _json
    try:
        out = subprocess.run(
            ["node", str(MEASURE_SCRIPT), str(page.resolve())],
            capture_output=True, text=True, timeout=180,
            cwd=str(MEASURE_SCRIPT.parent),
        )
        if out.returncode != 0:
            logger.warning("[vision2] mesure echouee : %s", (out.stderr or "")[:200])
            return None
        data = _json.loads(out.stdout.strip())
        return data.get("boxes") or None
    except Exception as exc:  # noqa: BLE001
        logger.warning("[vision2] mesure impossible : %s", exc)
        return None


def _mux_audio(video: Path, audio: Path, output: Path) -> Path:
    """
    Colle la piste de narration sur la vidéo.

    `-shortest` n'est PAS utilisé : la vidéo est la référence. Si l'audio était plus
    court, une coupure prématurée tronquerait l'image ; on préfère un court silence
    final. Le suffixe `+faststart` permet la lecture en streaming sur mobile.
    """
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error",
         "-i", str(video), "-i", str(audio),
         "-map", "0:v:0", "-map", "1:a:0",
         "-c:v", "copy",
         "-c:a", "aac", "-b:a", "128k", "-ar", "44100", "-ac", "2",
         "-movflags", "+faststart",
         str(output)],
        capture_output=True, text=True, timeout=600, check=True,
    )
    return output


def render_storyboard_v2(
    storyboard: Dict[str, Any],
    work_dir: Path,
    narration: Optional[List[Dict[str, Any]]] = None,
    audio_path: Optional[Path] = None,
    on_preview=None,
) -> Path:
    """
    Produit le MP4 final du cours.

    Args:
        storyboard: le storyboard complet (scènes, blocs, annotations, rappels).
        work_dir: dossier de travail temporaire.
        narration: manifeste [{scene_index, audio_path, duration_sec}] — sert à caler
            la durée de chaque scène sur la voix.
        audio_path: piste audio complète à coller sur la vidéo (facultatif).
        on_preview: appelé avec le MP4 MUET des premières secondes dès qu'il est prêt,
            bien avant la fin du rendu. Sert à publier un aperçu regardable tout de
            suite (voir `record_page_parallel`).

    Returns:
        Le chemin du MP4 prêt à être envoyé.
    """
    work_dir = Path(work_dir)
    work_dir.mkdir(parents=True, exist_ok=True)

    page_path = work_dir / "cours.html"
    silent = work_dir / "cours_muet.mp4"
    final = work_dir / "cours.mp4"

    # ── DEUX PASSES : on MESURE avant de filmer ────────────────────────────
    # Les positions des blocs étaient estimées en Python (« environ 30 caractères par
    # ligne »). Sur du contenu réel — un diagramme, une définition longue — l'estimation
    # se trompait : les textes SE CHEVAUCHAIENT et la caméra visait à côté.
    #
    # Passe 1 : page sans défilement, blocs en flux naturel (donc sans chevauchement
    #           possible), qu'on ouvre pour relever les positions réelles.
    # Passe 2 : même page, avec les mouvements de caméra recalculés sur ces mesures.
    _, duration = write_page(storyboard, page_path, narration)
    measured = _measure(page_path)
    if measured:
        logger.info("[vision2] %d blocs mesures dans le navigateur", len(measured))
        _, duration = write_page(storyboard, page_path, narration, measured=measured)
    else:
        logger.warning("[vision2] mesure indisponible — positions estimees (moins precis)")

    logger.info("[vision2] page construite : %.1f s a filmer", duration)

    # Capture par tranches simultanées : la même page est filmée en trois morceaux
    # rendus en parallèle, puis assemblés. La capture représentait 194 s des 250 s du
    # rendu (mesuré le 26/07/2026) ; l'enregistrement d'une seule traite reste le repli
    # automatique en cas de problème.
    record_page_parallel(page_path, silent, duration, on_preview=on_preview)

    if audio_path and Path(audio_path).exists():
        # ── SOUND DESIGN (vague G) : bruitages calés sur le même plan() que la
        # mise en scène, plus lit musical éventuel. Toute erreur → narration seule.
        track = Path(audio_path)
        try:
            planned, _, total, _, _ = plan(storyboard, narration)
            mixed = build_full_mix(storyboard, planned, INTRO_SEC, total, track, work_dir)
            if mixed:
                track = mixed
        except Exception as exc:  # noqa: BLE001
            logger.warning("[vision2] sound design ignore (%s)", exc)

        logger.info("[vision2] ajout de la narration")
        try:
            return _mux_audio(silent, track, final)
        except subprocess.CalledProcessError as exc:
            # Une vidéo muette vaut mieux qu'un échec complet : l'étudiant a son cours.
            logger.warning("[vision2] collage audio impossible (%s) — video muette",
                           (exc.stderr or "")[:200])
            return silent

    return silent


if __name__ == "__main__":
    import json
    import sys

    logging.basicConfig(level=logging.INFO)
    if len(sys.argv) < 3:
        print("Usage: python whiteboard_vision_v2.py <storyboard.json> <dossier_travail>")
        sys.exit(1)
    sb = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    out = render_storyboard_v2(sb, Path(sys.argv[2]))
    print(f"OK -> {out}")
