"""
Sound design du Smart Whiteboard — vague G (27/07/2026).

C'est LE marqueur « montage professionnel » : whoosh du générique et des
plaquettes, pop des badges, gratté du stylo pendant l'écriture, tampon de la
correction, et lit musical discret sous la voix (ducking).

CHOIX D'ARCHITECTURE
    - Tout se joue en POST-PRODUCTION ffmpeg : zéro impact sur la capture ni
      sur la synchronisation. Les instants viennent du même `plan()` qui a
      construit la page — image et son sont donc calés à la même horloge.
    - Les bruitages sont SYNTHÉTISÉS par ffmpeg au premier usage (bruit rose
      filtré, sinus amortis) puis mis en cache : aucun fichier à télécharger,
      aucune question de licence.
    - Le lit musical est OPTIONNEL : si `sfx/music_bed.mp3` existe (déposer
      n'importe quel morceau libre), il est mixé à bas volume avec compression
      sidechain sous la narration. Sinon, pas de musique.
    - Toute erreur est non fatale : on retourne None et la vidéo garde sa
      narration seule (comportement d'avant la vague G).
"""

from __future__ import annotations

import logging
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger("whiteboard_sound_design")

SFX_DIR = Path(__file__).with_name("sfx")

# Volumes relatifs (la voix reste la référence à 1.0).
VOL_WHOOSH = 0.32
VOL_POP = 0.26
VOL_STAMP = 0.40
VOL_SCRATCH = 0.10
VOL_MUSIC = 0.10

# Un cours n'est pas un clip : on borne le nombre d'événements sonores pour ne
# jamais fatiguer l'oreille ni dépasser les limites d'entrées ffmpeg.
MAX_EVENTS = 120

# Recettes de synthèse (nom -> [args ffmpeg]). Chaque son est court et doux.
_RECIPES: Dict[str, List[str]] = {
    # Balayage d'air : bruit rose filtré en bande, fondu entrant/sortant.
    "whoosh.wav": [
        "-f", "lavfi", "-i", "anoisesrc=d=0.6:color=pink:amplitude=0.7",
        "-af", "bandpass=f=900:w=700,afade=t=in:d=0.22,afade=t=out:st=0.32:d=0.28",
    ],
    # Petit pop de badge : sinus bref qui chute, très court.
    "pop.wav": [
        "-f", "lavfi", "-i", "sine=frequency=820:duration=0.12",
        "-af", "afade=t=in:d=0.004,afade=t=out:st=0.04:d=0.08",
    ],
    # Tampon : coup sourd grave, amorti vite.
    "stamp.wav": [
        "-f", "lavfi", "-i", "sine=frequency=150:duration=0.18",
        "-af", "afade=t=in:d=0.002,afade=t=out:st=0.05:d=0.13",
    ],
    # Gratté de stylo : bruit rose aigu très doux, bouclé pendant l'écriture.
    "scratch.wav": [
        "-f", "lavfi", "-i", "anoisesrc=d=1.0:color=pink:amplitude=0.45",
        "-af", "highpass=f=1400,lowpass=f=4200",
    ],
}


def _ensure_bank() -> bool:
    """Synthétise les bruitages manquants. Retourne False si ffmpeg échoue."""
    try:
        SFX_DIR.mkdir(exist_ok=True)
        for name, args in _RECIPES.items():
            out = SFX_DIR / name
            if out.exists():
                continue
            subprocess.run(
                ["ffmpeg", "-y", "-v", "error", *args, "-ar", "44100", "-ac", "2", str(out)],
                capture_output=True, text=True, timeout=60, check=True,
            )
            logger.info("[sfx] synthetise %s", name)
        return True
    except Exception as exc:  # noqa: BLE001
        logger.warning("[sfx] banque indisponible (%s) — pas de sound design", exc)
        return False


def _collect_events(storyboard: Dict[str, Any], planned: List[Any],
                    intro_sec: float) -> Tuple[List[Tuple[str, float]], List[Tuple[float, float]]]:
    """
    Déduit les événements sonores des mêmes données que la mise en scène.

    Retourne (events, scratches) :
        events    = [(nom_sfx, instant_s)]
        scratches = [(debut_s, duree_s)] — plages d'écriture manuscrite
    """
    scenes = storyboard.get("scenes") or []
    recap_scenes = {si for si, sc in enumerate(scenes)
                    if isinstance(sc, dict) and sc.get("beat") == "recap"}

    events: List[Tuple[str, float]] = [
        ("whoosh.wav", 0.05),                        # entrée de la carte-titre
        ("whoosh.wav", max(0.0, intro_sec - 0.6)),   # balayage de sortie
    ]
    scratches: List[Tuple[float, float]] = []

    for pb in planned:
        b = pb.block
        btype = b.get("type", "paragraph")
        if btype == "title":
            events.append(("whoosh.wav", pb.start))
        elif btype in ("definition", "exercise"):
            events.append(("pop.wav", pb.start))
        elif btype == "correction":
            events.append(("pop.wav", pb.start))
            events.append(("stamp.wav", pb.write_end + 0.25))
        elif btype in ("formula", "graph"):
            events.append(("pop.wav", pb.start))
        elif btype == "paragraph" and pb.scene_index in recap_scenes:
            events.append(("pop.wav", pb.start))     # coche de la carte récap

        # Gratté du stylo : uniquement le texte écrit à la main.
        if btype in ("title", "paragraph", "definition", "exercise", "correction"):
            dur = max(0.0, pb.write_end - pb.start)
            if dur > 0.4:
                scratches.append((pb.start, dur))

    return events[:MAX_EVENTS], scratches[:MAX_EVENTS]


def build_full_mix(
    storyboard: Dict[str, Any],
    planned: List[Any],
    intro_sec: float,
    total_sec: float,
    narration_audio: Path,
    work_dir: Path,
) -> Optional[Path]:
    """
    Produit la piste audio COMPLÈTE : narration + bruitages + musique éventuelle.

    Retourne None si quoi que ce soit échoue — l'appelant garde alors la
    narration seule, comme avant.
    """
    if not _ensure_bank():
        return None
    try:
        events, scratches = _collect_events(storyboard, planned, intro_sec)
        if not events and not scratches:
            return None

        vols = {"whoosh.wav": VOL_WHOOSH, "pop.wav": VOL_POP, "stamp.wav": VOL_STAMP}
        music = SFX_DIR / "music_bed.mp3"
        has_music = music.exists()

        # ── Construction des entrées et du graphe de filtres ────────────────
        cmd: List[str] = ["ffmpeg", "-y", "-v", "error", "-i", str(narration_audio)]
        filters: List[str] = []
        mix_labels: List[str] = ["[voice]"]
        filters.append("[0:a]anull[voice]")
        idx = 1

        for name, t in events:
            cmd += ["-i", str(SFX_DIR / name)]
            ms = max(0, int(t * 1000))
            filters.append(
                f"[{idx}:a]volume={vols[name]},adelay={ms}|{ms}[e{idx}]")
            mix_labels.append(f"[e{idx}]")
            idx += 1

        for t, dur in scratches:
            cmd += ["-stream_loop", "-1", "-t", f"{dur:.2f}", "-i", str(SFX_DIR / "scratch.wav")]
            ms = max(0, int(t * 1000))
            filters.append(
                f"[{idx}:a]volume={VOL_SCRATCH},"
                f"afade=t=in:d=0.15,afade=t=out:st={max(0.0, dur - 0.2):.2f}:d=0.2,"
                f"adelay={ms}|{ms}[s{idx}]")
            mix_labels.append(f"[s{idx}]")
            idx += 1

        if has_music:
            cmd += ["-stream_loop", "-1", "-t", f"{total_sec:.2f}", "-i", str(music)]
            # Le lit musical s'efface sous la voix (compression sidechain), avec
            # fondu d'entrée et de sortie.
            filters.append(
                f"[{idx}:a]volume={VOL_MUSIC},"
                f"afade=t=in:d=1.5,afade=t=out:st={max(0.0, total_sec - 2.5):.2f}:d=2.5[bgm]")
            filters.append("[bgm][voice]sidechaincompress=threshold=0.03:ratio=8:attack=80:release=600[duck]")
            mix_labels.append("[duck]")
            idx += 1

        n = len(mix_labels)
        filters.append(
            "".join(mix_labels) + f"amix=inputs={n}:normalize=0:duration=first[out]")

        out = Path(work_dir) / "narration_sfx.m4a"
        cmd += ["-filter_complex", ";".join(filters), "-map", "[out]",
                "-c:a", "aac", "-b:a", "160k", "-ar", "44100", "-ac", "2", str(out)]
        subprocess.run(cmd, capture_output=True, text=True, timeout=600, check=True)
        logger.info("[sfx] mixage : %d evenements, %d grattes, musique=%s",
                    len(events), len(scratches), has_music)
        return out
    except subprocess.CalledProcessError as exc:
        logger.warning("[sfx] mixage echoue (%s) — narration seule",
                       (exc.stderr or "")[:300])
        return None
    except Exception as exc:  # noqa: BLE001
        logger.warning("[sfx] mixage impossible (%s) — narration seule", exc)
        return None
