"""
Vision v2 — Enregistrement vidéo d'une page HTML animée.

Remplace la capture d'UNE image par scène (qui produisait un diaporama) par un
ENREGISTREMENT de la page pendant que les animations CSS se jouent.

Coût du rendu : proportionnel à la durée de la vidéo (~1x le temps réel), au lieu de
~4-5x avec un moteur qui reconstruit chaque image (cf. l'abandon de Remotion, voir
docs/PLAN_REMPLACEMENT_MOTEUR_2026-07-25.md).

Garde-fou : la durée du fichier obtenu est comparée à la durée demandée. En cas d'écart
(images perdues sous charge), on échoue explicitement plutôt que de livrer une vidéo
saccadée à un étudiant.
"""

from __future__ import annotations

import json
import logging
import os
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import httpx

logger = logging.getLogger("whiteboard_video_capture")

VISION_DIR = Path("/opt/whiteboard-worker/vision_engine")
RECORD_SCRIPT = VISION_DIR / "record_scene.js"

# Repli local (développement)
if not RECORD_SCRIPT.exists():
    VISION_DIR = Path(__file__).parent
    RECORD_SCRIPT = VISION_DIR / "record_scene.js"

DEFAULT_FPS = 25
# Écart maximal toléré entre durée demandée et durée obtenue.
DURATION_TOLERANCE = 0.08
# Marge de sécurité du sous-processus : la durée d'enregistrement + le temps de
# lancement de Chromium et d'encodage.
OVERHEAD_SEC = 90

# Nombre de tranches filmées EN PARALLÈLE (cf. `record_page_parallel`).
# Mesuré le 26/07/2026 sur le serveur (4 cœurs) : trois enregistrements simultanés de
# 20 s coûtent 27 s au total contre 23 s pour un seul, sans perte d'image — trois fois
# le débit pour 17 % de surcoût. Au-delà de 3, on dépasse le nombre de cœurs et le
# risque de saccade apparaît. Réglable sans redéploiement.
PARALLEL_SLICES = int(os.getenv("WHITEBOARD_CAPTURE_SLICES", "3") or "3")
# En dessous de cette durée, découper coûte plus (3 lancements de Chromium) que ça ne
# rapporte : on filme d'une seule traite.
MIN_DURATION_FOR_SLICING = 30.0

# Durée de la TRANCHE D'APERÇU : la première tranche est volontairement courte pour
# être prête très vite (~20 s après le clic), sonorisée et envoyée à l'étudiant
# pendant que le reste du cours se fabrique. Elle fait partie de la vidéo finale :
# rien n'est filmé deux fois.
PREVIEW_SEC = 15.0
# En dessous de cette durée totale, l'aperçu n'a pas de sens : la vidéo complète
# arrivera de toute façon presque aussi vite.
MIN_DURATION_FOR_PREVIEW = 60.0

# ── Parallélisation MULTI-MACHINES (28/07/2026) ─────────────────────────────
# `PARALLEL_SLICES` distribue déjà les tranches sur les cœurs d'UNE machine. Au-delà
# de son nombre de cœurs, ajouter des tranches n'aide plus (cf. mesure du 26/07 :
# 17 % de surcoût par tranche). Le vrai levier, utilisé par les plateformes qui
# rendent vite (Remotion Lambda et consorts), est de distribuer sur PLUSIEURS
# machines. `WHITEBOARD_REMOTE_WORKERS` (URLs séparées par des virgules, ex.
# "http://31.207.x.x:8077,http://31.207.y.y:8077") ajoute des machines de capture
# (voir capture_agent.py + docs/PARALLELISATION_MULTI_MACHINES_2026-07-28.md).
# Vide par défaut : comportement inchangé, tout reste local.
REMOTE_WORKERS = [
    u.strip() for u in (os.getenv("WHITEBOARD_REMOTE_WORKERS") or "").split(",") if u.strip()
]
REMOTE_WORKER_KEY = os.getenv("WHITEBOARD_REMOTE_WORKER_KEY", "").strip()
REMOTE_CAPTURE_OVERHEAD_SEC = 120  # marge reseau/upload en plus du temps de capture


def _record_page_remote(
    worker_url: str,
    html_path: Path,
    output_path: Path,
    duration_sec: float,
    fps: int,
    start_sec: float,
) -> Path:
    """Delegue la capture d'une tranche a un agent distant (voir capture_agent.py)."""
    payload = {
        "html": html_path.read_text(encoding="utf-8"),
        "duration_sec": duration_sec,
        "fps": fps,
        "start_sec": start_sec,
    }
    timeout = duration_sec + REMOTE_CAPTURE_OVERHEAD_SEC
    logger.info(
        "[capture] tranche de %.1f s (depart %.1f s) deleguee a %s",
        duration_sec, start_sec, worker_url,
    )
    resp = httpx.post(
        f"{worker_url.rstrip('/')}/capture",
        json=payload,
        headers={"X-Capture-Key": REMOTE_WORKER_KEY},
        timeout=timeout,
    )
    if resp.status_code != 200:
        raise RuntimeError(
            f"agent distant {worker_url} a repondu {resp.status_code}: {resp.text[:300]}"
        )
    output_path.write_bytes(resp.content)
    return output_path


# Marge filmée EN PLUS de la durée demandée, puis jetée au rognage.
# Le fichier brut commence par une amorce (~1,2 s : le temps que Playwright ouvre la
# page) qu'il faut couper. Sans marge, la matière manque à la fin : mesuré le
# 26/07/2026, une tranche de 46,4 s demandée n'en rendait que 45,4 — la dernière
# seconde du cours était perdue. Deux secondes de marge coûtent deux secondes de
# rendu et garantissent une tranche complète.
TAIL_MARGIN_SEC = 2.0


def probe_duration_sec(path: Path) -> float:
    """Durée réelle d'un fichier vidéo (secondes), via ffprobe. 0.0 si illisible."""
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
            capture_output=True, text=True, timeout=30,
        )
        return float(out.stdout.strip())
    except Exception as exc:  # noqa: BLE001 - on veut juste dégrader proprement
        logger.warning("[capture] ffprobe illisible pour %s : %s", path, exc)
        return 0.0


def record_page(
    html_path: Path,
    output_path: Path,
    duration_sec: float,
    fps: int = DEFAULT_FPS,
    strict: bool = True,
    start_sec: float = 0.0,
) -> Path:
    """
    Enregistre la page HTML pendant `duration_sec`, animations comprises, puis
    produit un MP4 lisible sur mobile.

    Args:
        html_path: page HTML à filmer (contient toutes les scènes du cours).
        output_path: fichier vidéo de sortie (.mp4).
        duration_sec: durée d'animation demandée.
        fps: images par seconde (25 par défaut, marge pour tenir le temps réel).
        strict: si True, échoue quand la durée obtenue s'écarte de la demandée.
        start_sec: instant du cours où commence l'enregistrement. Non nul, on ne
            filme qu'une TRANCHE : les animations sont avancées à cet instant avant
            le début de la prise (voir `record_page_parallel`).

    Returns:
        Le chemin du MP4 produit.
    """
    html_path = Path(html_path)
    output_path = Path(output_path)
    if not html_path.exists():
        raise FileNotFoundError(f"HTML introuvable : {html_path}")

    # On filme un peu plus long que demandé : le surplus est jeté au rognage, mais il
    # garantit qu'après avoir coupé l'amorce il reste bien `duration_sec` de matière.
    record_ms = int((duration_sec + TAIL_MARGIN_SEC) * 1000)
    start_ms = int(start_sec * 1000)
    timeout = duration_sec + TAIL_MARGIN_SEC + OVERHEAD_SEC
    raw_path = output_path.with_suffix(".raw.webm")

    logger.info(
        "[capture] enregistrement de %.1f s a %d ips (depart %.1f s) -> %s",
        duration_sec, fps, start_sec, output_path.name,
    )
    try:
        result = subprocess.run(
            ["node", str(RECORD_SCRIPT), str(html_path.resolve()),
             str(raw_path.resolve()), str(record_ms), str(fps), str(start_ms)],
            capture_output=True, text=True, timeout=timeout, cwd=str(VISION_DIR),
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(
            f"record_scene.js depasse le delai ({timeout:.0f} s) — la machine est "
            f"probablement trop chargee pour un enregistrement en temps reel"
        ) from exc

    if result.returncode != 0:
        raise RuntimeError(f"record_scene.js a echoue : {result.stderr[:300]}")
    if not raw_path.exists():
        raise FileNotFoundError(f"video non produite : {raw_path}")

    lead_in_sec = 0.0
    try:
        info = json.loads(result.stdout.strip())
        lead_in_sec = float(info.get("lead_in_ms", 0)) / 1000.0
        logger.info("[capture] enregistre en %.1f s (%s octets), amorce mesuree %.2f s",
                    info.get("elapsed_ms", 0) / 1000.0, info.get("size", "?"), lead_in_sec)
    except (json.JSONDecodeError, AttributeError, TypeError, ValueError):
        logger.warning("[capture] amorce non communiquee par record_scene.js")

    raw_duration = probe_duration_sec(raw_path)
    if raw_duration <= 0:
        raise RuntimeError("enregistrement produit mais duree illisible (fichier corrompu ?)")

    # ── Rognage de l'amorce, à partir d'une MESURE ─────────────────────────
    # Playwright commence à filmer dès la création du contexte, donc avant le chargement
    # de la page : le fichier comporte une amorce. Il comporte AUSSI une traîne, le temps
    # que la vidéo soit finalisée après la fin de l'animation.
    #
    # Une première version rognait « les N dernières secondes ». Mesure faite : cela
    # décalait l'animation de ~0,93 s, précisément la durée de cette traîne — l'écart
    # était constant sur trois points de contrôle (8,7 / 9,3 / 9,6 %), ce qui a permis
    # de l'identifier.
    #
    # `record_scene.js` mesure donc désormais l'amorce réelle (temps entre le début de
    # l'enregistrement et le démarrage des animations) et on coupe EXACTEMENT là.
    if lead_in_sec <= 0:
        # Repli si la mesure manque : on estime l'amorce par différence.
        lead_in_sec = max(0.0, raw_duration - duration_sec)
        logger.warning("[capture] amorce estimee par difference : %.2f s", lead_in_sec)

    logger.info(
        "[capture] brut %.1f s -> coupe a %.2f s, sur %.1f s",
        raw_duration, lead_in_sec, duration_sec,
    )
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-v", "error",
             "-ss", f"{lead_in_sec:.3f}", "-i", str(raw_path), "-t", f"{duration_sec:.3f}",
             "-c:v", "libx264", "-profile:v", "main", "-level:v", "4.0",
             # `veryfast` : l'encodage était le vrai coût du rendu — 51 s de vidéo
             # enregistrées en 53 s (temps réel), mais 2 minutes au total à cause du
             # réencodage en préréglage par défaut. Ce préréglage divise ce temps par
             # trois environ, pour un fichier à peine plus gros à qualité égale.
             "-preset", "veryfast",
             "-pix_fmt", "yuv420p", "-crf", "21",
             "-r", str(fps),
             "-movflags", "+faststart",
             "-an",  # l'audio (narration) est ajouté plus tard par le worker
             str(output_path)],
            capture_output=True, text=True, timeout=max(120, int(duration_sec * 3)),
            check=True,
        )
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f"ffmpeg (rognage) a echoue : {exc.stderr[:300]}") from exc

    raw_path.unlink(missing_ok=True)

    # ── Contrôle qualité : la durée finale correspond-elle à la demande ? ───
    actual = probe_duration_sec(output_path)
    if actual <= 0:
        raise RuntimeError("MP4 produit mais duree illisible")

    ecart = abs(actual - duration_sec) / duration_sec
    logger.info(
        "[capture] duree demandee %.1f s / obtenue %.1f s (ecart %.1f %%)",
        duration_sec, actual, ecart * 100,
    )
    if strict and ecart > DURATION_TOLERANCE:
        raise RuntimeError(
            f"duree incoherente : {actual:.1f} s obtenues pour {duration_sec:.1f} s "
            f"demandees (ecart {ecart * 100:.0f} %). Des images ont probablement ete "
            f"perdues : la video serait saccadee. Rendu interrompu volontairement."
        )

    return output_path


def record_page_parallel(
    html_path: Path,
    output_path: Path,
    duration_sec: float,
    fps: int = DEFAULT_FPS,
    strict: bool = True,
    slices: int = PARALLEL_SLICES,
    on_preview=None,
) -> Path:
    """
    Filme la page en `slices` TRANCHES SIMULTANÉES, puis les met bout à bout.

    POURQUOI (26/07/2026) : la capture représentait 194 s des 250 s du rendu complet,
    parce qu'un enregistrement en temps réel coûte, par construction, la durée de la
    vidéo. Deux autres voies ont été mesurées puis écartées :
      - temps virtuel par `Page.captureScreenshot` : 91,5 ms/image en 1080x1920,
        soit 0,36x le temps réel (plus LENT) ;
      - `HeadlessExperimental.beginFrame` : 86,6 ms/image, 5 % de mieux seulement —
        la littérature annonçait 2 à 3x, mais sans GPU le coût reste celui de la
        composition de 2 millions de pixels.
    Les prototypes correspondants restent dans le dépôt (`proto_capture*.js`) pour le
    jour où une machine avec GPU serait disponible.

    Le parallélisme, lui, fonctionne : trois enregistrements simultanés de 20 s coûtent
    27 s (contre 23 s pour un seul), sans perte d'image. Chaque tranche démarre sur une
    image rigoureusement identique à celle d'un enregistrement continu, puisque les
    animations sont avancées à l'instant exact de son début.

    En cas d'échec d'une tranche, on retombe sur l'enregistrement d'une seule traite :
    mieux vaut un rendu lent qu'un rendu absent.

    `on_preview` : fonction appelée dès que la PREMIÈRE tranche est prête, avec son
    chemin. Cette première tranche est raccourcie à `PREVIEW_SEC` pour être disponible
    très vite : l'étudiant commence à regarder son cours pendant que la suite se
    fabrique. Elle reste un morceau de la vidéo finale, donc rien n'est filmé deux fois.
    Un échec du rappel n'interrompt jamais le rendu : l'aperçu est un confort, la vidéo
    est le livrable.
    """
    html_path = Path(html_path)
    output_path = Path(output_path)

    if slices <= 1 or duration_sec < MIN_DURATION_FOR_SLICING:
        return record_page(html_path, output_path, duration_sec, fps, strict)

    # Découpe. Avec aperçu : une première tranche courte, puis le reste à durées
    # égales. Sans aperçu : des tranches toutes égales. Dans les deux cas la somme
    # fait EXACTEMENT la durée demandée (la dernière absorbe l'arrondi).
    want_preview = on_preview is not None and duration_sec >= MIN_DURATION_FOR_PREVIEW
    if want_preview:
        rest = duration_sec - PREVIEW_SEC
        span = rest / slices
        bounds = [(0.0, PREVIEW_SEC)] + [
            (PREVIEW_SEC + i * span,
             span if i < slices - 1 else rest - i * span)
            for i in range(slices)
        ]
    else:
        span = duration_sec / slices
        bounds = [(i * span, span if i < slices - 1 else duration_sec - i * span)
                  for i in range(slices)]

    parts = [output_path.with_suffix(f".part{i}.mp4") for i in range(len(bounds))]

    def _one(i: int, start: float, dur: float) -> Path:
        return record_page(html_path, parts[i], dur, fps, strict, start)

    logger.info(
        "[capture] %d tranches en parallele (total %.1f s)%s",
        len(bounds), duration_sec,
        f", dont un apercu de {PREVIEW_SEC:.0f} s" if want_preview else "",
    )
    started = time.time()
    try:
        # L'aperçu est filmé SEUL, avant les autres. Mesuré le 27/07/2026 : lancé en
        # même temps que les trois autres tranches, il n'était prêt qu'au bout de 58 s,
        # car quatre Chromium et quatre encodages se disputaient les quatre cœurs.
        # Seul, il coûte une vingtaine de secondes et rend aussitôt la machine ; le
        # total ne s'allonge pas, les tranches suivantes retrouvant alors trois cœurs
        # pour trois tâches au lieu de quatre.
        if want_preview:
            apercu = _one(0, *bounds[0])
            logger.info("[capture] apercu pret en %.1f s", time.time() - started)
            try:
                on_preview(apercu)
            except Exception as exc:  # noqa: BLE001
                logger.warning("[capture] apercu non publie (%s) — rendu poursuivi", exc)

        reste = list(enumerate(bounds))[1:] if want_preview else list(enumerate(bounds))
        with ThreadPoolExecutor(max_workers=len(reste)) as pool:
            futures = [pool.submit(_one, i, start, dur) for i, (start, dur) in reste]
            for f in futures:
                f.result()  # propage la première erreur rencontrée
    except Exception as exc:  # noqa: BLE001
        logger.warning("[capture] tranches en echec (%s) -> repli d'une seule traite", exc)
        for p in parts:
            p.unlink(missing_ok=True)
            p.with_suffix(".raw.webm").unlink(missing_ok=True)
        return record_page(html_path, output_path, duration_sec, fps, strict)

    # Mise bout à bout sans réencodage : les tranches sortent du même encodeur, avec
    # les mêmes paramètres. Recopier les flux coûte une fraction de seconde.
    liste = output_path.with_suffix(".parts.txt")
    liste.write_text("\n".join(f"file '{p.resolve()}'" for p in parts), encoding="utf-8")
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0",
             "-i", str(liste), "-c", "copy", "-movflags", "+faststart",
             str(output_path)],
            capture_output=True, text=True, timeout=300, check=True,
        )
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f"concatenation des tranches echouee : {exc.stderr[:300]}") from exc
    finally:
        liste.unlink(missing_ok=True)
        for p in parts:
            p.unlink(missing_ok=True)

    actual = probe_duration_sec(output_path)
    ecart = abs(actual - duration_sec) / duration_sec if duration_sec else 1.0
    logger.info(
        "[capture] %d tranches assemblees en %.1f s : %.1f s obtenues pour %.1f s "
        "demandees (ecart %.1f %%)",
        len(bounds), time.time() - started, actual, duration_sec, ecart * 100,
    )
    if strict and ecart > DURATION_TOLERANCE:
        raise RuntimeError(
            f"duree incoherente apres assemblage : {actual:.1f} s pour "
            f"{duration_sec:.1f} s demandees (ecart {ecart * 100:.0f} %)"
        )
    return output_path


if __name__ == "__main__":
    import sys

    logging.basicConfig(level=logging.INFO)
    if len(sys.argv) < 4:
        print("Usage: python whiteboard_video_capture.py <html> <sortie.webm> <duree_s>")
        sys.exit(1)
    out = record_page(Path(sys.argv[1]), Path(sys.argv[2]), float(sys.argv[3]))
    print(f"OK -> {out}")
