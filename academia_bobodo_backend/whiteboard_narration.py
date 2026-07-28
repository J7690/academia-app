"""
Whiteboard Narration - Phase G
Génère une narration audio (TTS) synchronisée avec les scènes du storyboard.

Moteur TTS : gTTS (Google Translate TTS) - gratuit, voix française, pas de clé API.
Mixage : FFmpeg (déjà présent sur le VPS).

Flux :
1. Pour chaque scène, on extrait un texte lisible depuis les blocs.
2. On génère un MP3 par scène via gTTS.
3. On mesure la durée de chaque MP3 (ffprobe).
4. On calcule la durée effective de chaque scène = max(durée storyboard, audio + padding).
5. On construit une piste audio unique où chaque segment de scène est complété
   par du silence jusqu'à la durée effective de la scène.
6. Le worker assemble la vidéo avec ces durées, puis mux la piste audio.
"""

from __future__ import annotations

import hashlib
import logging
import os
import re
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import httpx

logger = logging.getLogger("whiteboard_narration")

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")
WHITEBOARD_TTS_URL = f"{SUPABASE_URL}/functions/v1/whiteboard-tts" if SUPABASE_URL else ""

try:
    from gtts import gTTS
    _HAS_GTTS = True
except ImportError:
    _HAS_GTTS = False

# Verbalisation française des maths (« f de x », « l'intégrale de a à b »...).
try:
    from math_speech_fr import verbalize
    _HAS_MATH_SPEECH = True
except ImportError:  # pragma: no cover - repli si le module n'est pas déployé
    _HAS_MATH_SPEECH = False

# Verbalisation par Speech Rule Engine (ClearSpeak français) : couvre TOUTES les
# maths (fractions imbriquées, matrices, intégrales multiples...) là où les regex
# maison plafonnent. Repli automatique sur `math_speech_fr` en cas d'indisponibilité.
try:
    from math_speech_sre import verbalize_text, verbalize_formula
    _HAS_SRE = True
except ImportError:  # pragma: no cover
    _HAS_SRE = False

# Padding de silence ajouté après chaque narration (secondes).
# Abaissé de 0,8 à 0,35 s le 25/07/2026 : c'est une respiration entre deux idées, pas
# un blanc. Cumulé sur 8 scènes, l'ancien réglage ajoutait ~6 s de silence perçu.
SCENE_PADDING_SEC = 0.35
# Durée minimale d'une scène sans texte (secondes)
MIN_SCENE_SEC = 2.0
# Longueur maximale de texte narré par scène (caractères) pour éviter des audios interminables
MAX_NARRATION_CHARS = 600


def is_available() -> bool:
    """Indique si au moins un fournisseur TTS est utilisable."""
    return bool(WHITEBOARD_TTS_URL and SUPABASE_SERVICE_KEY) or _HAS_GTTS


def _generate_openrouter_tts(text: str, output_path: Path, language: str) -> None:
    """Génère un MP3 via l'Edge Function interne et les crédits OpenRouter."""
    if not WHITEBOARD_TTS_URL or not SUPABASE_SERVICE_KEY:
        raise RuntimeError("Supabase credentials unavailable for OpenRouter TTS")

    response = httpx.post(
        WHITEBOARD_TTS_URL,
        headers={
            "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
            "apikey": SUPABASE_SERVICE_KEY,
            "Content-Type": "application/json",
        },
        # NOTE 26/07/2026 : le paramètre `speed` était envoyé ici mais l'Edge Function
        # déployée l'IGNORAIT (vérifié empiriquement : même durée à 0,5x et 1,0x).
        # Le ralenti est désormais appliqué côté worker, par ffmpeg `atempo`, dans
        # `_generate_tts` : garanti de fonctionner, quel que soit le fournisseur.
        json={"input": text},
        timeout=120.0,
    )
    if not response.is_success:
        raise RuntimeError(
            f"OpenRouter TTS HTTP {response.status_code}: {response.text[:500]}"
        )
    if not response.content:
        raise RuntimeError("OpenRouter TTS returned empty audio")
    output_path.write_bytes(response.content)
    logger.info(
        f"[narration] OpenRouter TTS generated {len(response.content)} bytes "
        f"({response.headers.get('X-TTS-Model', 'unknown model')})"
    )


def _postprocess_tts(src: Path, dst_wav: Path) -> None:
    """
    Post-traite un segment TTS brut en UNE passe ffmpeg :
      - `atempo`  : rythme académique réel (le paramètre `speed` de l'Edge Function
        était silencieusement ignoré — vérifié le 26/07/2026 : mêmes durées à 0,5x
        et 1,0x). Côté worker, le ralenti est vérifiable et indépendant du fournisseur ;
      - `loudnorm` : voix à -16 LUFS dès le segment (mesuré -29,2 LUFS en sortie de
        TTS, ~13 dB sous la norme des plateformes — cause du « peu audible »).
        Normalisé ICI plutôt qu'au mux : le mux repasse en simple encodage (~3x plus
        rapide, mesuré 23,9 s -> ~8 s) et chaque segment sort au même niveau.

    Sortie en WAV : la durée d'un WAV est exacte, alors que ffprobe ESTIME celle des
    MP3 d'OpenRouter (8,05 s annoncés pour 6,97 s réels, mesuré le 26/07/2026). Or ces
    durées pilotent la synchronisation voix/écriture : elles doivent être justes.
    """
    filters = []
    if abs(TTS_SPEED - 1.0) >= 0.01:
        filters.append(f"atempo={TTS_SPEED:.3f}")
    filters.append("loudnorm=I=-16:TP=-1.5:LRA=11")
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", str(src),
         "-af", ",".join(filters), "-ar", "44100", "-ac", "2", str(dst_wav)],
        capture_output=True, text=True, timeout=120, check=True,
    )


def _generate_tts(text: str, output_path: Path, language: str) -> str:
    """Génère l'audio BRUT : OpenRouter en priorité, gTTS en repli."""
    try:
        _generate_openrouter_tts(text, output_path, language)
        return "openrouter"
    except Exception as openrouter_error:
        logger.warning(f"[narration] OpenRouter TTS unavailable: {openrouter_error}")
        if not _HAS_GTTS:
            raise
        tts = gTTS(text=text, lang=language)
        tts.save(str(output_path))
        logger.info("[narration] gTTS fallback generated audio")
        return "gtts"


# ── Cache TTS ────────────────────────────────────────────────────────────────
# Un bloc réédité ne change qu'une phrase : les autres segments sont identiques d'un
# rendu à l'autre. On les réutilise (empreinte texte + vitesse + langue) au lieu de
# rappeler le TTS — une régénération après retouche devient quasi gratuite.
TTS_CACHE_DIR = Path(os.getenv("WHITEBOARD_TTS_CACHE", "/opt/whiteboard-worker/tts_cache"))
TTS_CACHE_MAX_AGE_DAYS = 14
# Requêtes TTS simultanées : mesuré 31,5 s en séquentiel pour 14 blocs (26/07/2026).
# Les appels sont des attentes réseau : 6 en parallèle les ramènent à ~5 s.
TTS_PARALLEL = int(os.getenv("WHITEBOARD_TTS_PARALLEL", "6") or "6")


def _prune_tts_cache() -> None:
    """Efface les segments non réutilisés depuis TTS_CACHE_MAX_AGE_DAYS jours."""
    try:
        cutoff = time.time() - TTS_CACHE_MAX_AGE_DAYS * 86400
        for f in TTS_CACHE_DIR.glob("*.wav"):
            if f.stat().st_mtime < cutoff:
                f.unlink(missing_ok=True)
    except OSError:  # cache indisponible : on génère sans lui, jamais bloquant
        pass


def _tts_cached(text: str, language: str = "fr") -> Path:
    """Retourne le WAV post-traité du texte, depuis le cache ou en le générant."""
    key = hashlib.sha1(f"{language}|{TTS_SPEED:.3f}|{text}".encode("utf-8")).hexdigest()
    cached = TTS_CACHE_DIR / f"{key}.wav"
    if cached.exists():
        cached.touch()  # marque la réutilisation pour la purge par ancienneté
        return cached
    TTS_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    raw = cached.with_suffix(".raw.mp3")
    tmp = cached.with_suffix(".tmp.wav")
    try:
        _generate_tts(text, raw, language)
        _postprocess_tts(raw, tmp)
        tmp.replace(cached)  # renommage atomique : jamais de segment à moitié écrit
    finally:
        raw.unlink(missing_ok=True)
        tmp.unlink(missing_ok=True)
    return cached


def _clean_latex(text: str) -> str:
    """
    Convertit du LaTeX en texte prononçable en français.

    Depuis le 25/07/2026, on délègue à `math_speech_fr.verbalize`, qui sait dire
    « f de x », « l'intégrale de a à b », « la limite quand x tend vers 1 par valeurs
    inférieures », les lettres grecques, les dérivées... L'ancienne version se
    contentait d'effacer les barres obliques, ce qui donnait une lecture inaudible
    des formules. On garde ici un repli minimal si le module n'est pas déployé.
    """
    if not text:
        return ""
    if _HAS_SRE:
        return verbalize_text(text)
    if _HAS_MATH_SPEECH:
        return verbalize(text)
    t = re.sub(r"[\\{}$^_]", " ", text)
    return re.sub(r"\s+", " ", t).strip()


def _clean_formula(latex: str) -> str:
    """LaTeX PUR (bloc formule) -> parole. SRE d'abord, regex maison en repli."""
    if not latex:
        return ""
    if _HAS_SRE:
        return verbalize_formula(latex)
    return _clean_latex(latex)


def _scene_text(scene: Dict[str, Any]) -> str:
    """
    Construit le texte à narrer pour une scène.

    PRIORITÉ au champ `narration` produit par le générateur IA : c'est une phrase de
    professeur, rédigée en français naturel et sans LaTeX. Le moteur Remotion l'utilise
    déjà (`narrate.py`) — c'est ce qui explique que ses vidéos sonnent juste. Ce chemin
    (moteur Vision) l'ignorait et récitait le contenu brut des blocs, formules LaTeX
    comprises. Correctif du 25/07/2026.
    """
    narration = scene.get("narration")
    if isinstance(narration, str) and narration.strip():
        return _clean_latex(narration.strip())[:MAX_NARRATION_CHARS]

    parts: List[str] = []
    title = scene.get("title")
    if isinstance(title, str) and title.strip():
        parts.append(title.strip())

    for block in scene.get("blocks", []) or []:
        if not isinstance(block, dict):
            continue
        if not block.get("visible", True):
            continue
        btype = block.get("type")
        if btype in ("diagram", "graph"):
            # Non narrés (contenu structurel/visuel)
            continue
        if btype == "formula":
            content = _clean_formula(block.get("content", ""))
            if content:
                parts.append(content)
            continue
        if btype == "definition":
            term = block.get("term", "")
            definition = block.get("definition", block.get("content", ""))
            frag = ". ".join(x for x in [term, definition] if x)
            if frag:
                parts.append(frag)
            continue
        if btype == "exercise":
            q = block.get("question", block.get("content", ""))
            if q:
                parts.append(q)
            continue
        if btype == "correction":
            expl = block.get("explanation", block.get("content", ""))
            steps = block.get("steps", []) or []
            frag = ". ".join([str(s) for s in steps] + ([expl] if expl else []))
            if frag:
                parts.append(frag)
            continue
        # title, paragraph et autres : contenu brut
        content = block.get("content", "")
        if isinstance(content, str) and content.strip():
            parts.append(content.strip())

    text = ". ".join(parts).strip()
    text = re.sub(r"\s+", " ", text)
    if len(text) > MAX_NARRATION_CHARS:
        text = text[:MAX_NARRATION_CHARS].rsplit(" ", 1)[0] + "."
    return text


def _probe_duration_sec(audio_path: Path) -> float:
    """Retourne la durée d'un fichier audio via ffprobe (secondes)."""
    try:
        out = subprocess.run(
            [
                "ffprobe", "-v", "error", "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1", str(audio_path),
            ],
            capture_output=True, text=True, timeout=30,
        )
        return float(out.stdout.strip())
    except Exception as e:
        logger.warning(f"[narration] ffprobe failed for {audio_path}: {e}")
        return 0.0


def _pad_audio(src: Path, dst: Path, target_sec: float, language: str = "fr") -> None:
    """Complète un audio avec du silence pour atteindre target_sec, réencode en WAV 44.1k stéréo."""
    subprocess.run(
        [
            "ffmpeg", "-y", "-i", str(src),
            "-af", f"apad=whole_dur={target_sec:.3f}",
            "-ar", "44100", "-ac", "2",
            str(dst),
        ],
        capture_output=True, text=True, timeout=120, check=True,
    )


def _silence_wav(dst: Path, target_sec: float) -> None:
    """Génère un WAV de silence de target_sec secondes."""
    subprocess.run(
        [
            "ffmpeg", "-y", "-f", "lavfi",
            "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
            "-t", f"{target_sec:.3f}",
            str(dst),
        ],
        capture_output=True, text=True, timeout=60, check=True,
    )


# ═══════════════════════════════════════════════════════════════════════════
# NARRATION PAR BLOC — synchronisation réelle voix / écriture
#
# POURQUOI (25/07/2026) : jusqu'ici, une narration par SCÈNE commentait trois ou
# quatre blocs écrits successivement. La voix parlait donc d'un contenu pendant qu'un
# autre s'écrivait. Défaut signalé : « l'audio et l'écriture ne disent pas la même
# chose au même moment ».
#
# C'est le principe de CONTIGUÏTÉ TEMPORELLE (Mayer) : on apprend plus profondément
# quand le commentaire et le visuel correspondant sont présentés SIMULTANÉMENT plutôt
# que successivement. Formulé autrement par 3Blue1Brown : chaque élément visuel doit
# dire la même chose que la narration, au lieu de rivaliser avec elle pour l'attention.
#
# On produit donc UN segment audio PAR BLOC. La durée d'écriture du bloc devient
# exactement la durée de son segment : ce qui s'écrit est ce qui se dit.
# ═══════════════════════════════════════════════════════════════════════════

# Rythme de parole. La recherche situe la compréhension optimale entre 100 et 130 mots
# par minute pour du contenu technique (contre ~150 en parole courante, et un déclin
# marqué au-delà de 200). On vise donc le bas de cette fourchette : un cours doit
# pouvoir être suivi ET retenu, pas seulement entendu.
ACADEMIC_WPM = 115
# Respiration entre deux blocs : le temps de poser l'idée avant la suivante.
# Portée de 0,6 à 1,1 s : les blocs s'enchaînaient sans laisser le temps de digérer.
# Les pauses marquent les transitions entre idées et réduisent la charge cognitive.
BLOCK_BREATH_SEC = 1.1

# Vitesse de la voix (1.0 = rythme naturel du moteur, ~150 mots/min).
# 0.88 -> ~132 mots/min : un léger ralenti, naturel à l'oreille. L'ancien 0,80 n'avait
# jamais été réellement appliqué (paramètre ignoré par l'Edge Function) ; maintenant
# que le ralenti agit VRAIMENT (atempo côté worker), 0,80 traînerait.
# Ajustable sans redéploiement via WHITEBOARD_TTS_SPEED.
TTS_SPEED = float((os.getenv("WHITEBOARD_TTS_SPEED") or "0.88").strip() or "0.88")


def _block_speech_text(block: Dict[str, Any]) -> str:
    """
    Ce que le professeur DIT pendant qu'il écrit ce bloc.

    Priorité au champ `narration` du bloc (rédigé par le générateur). À défaut, on lit
    le contenu lui-même, débarrassé de son LaTeX : mieux vaut une voix qui accompagne
    l'écriture qu'un silence.
    """
    narration = block.get("narration")
    if isinstance(narration, str) and narration.strip():
        return _clean_latex(narration.strip())[:MAX_NARRATION_CHARS]
    content = block.get("content") or ""
    if block.get("type") in ("image", "diagram"):
        return ""
    # Un bloc formule sans narration rédigée : son contenu est du LaTeX PUR.
    if block.get("type") in ("formula", "graph"):
        return _clean_formula(content)[:MAX_NARRATION_CHARS]
    return _clean_latex(content)[:MAX_NARRATION_CHARS]


def build_block_narration(
    storyboard: Dict[str, Any],
    work_dir: Path,
    language: str = "fr",
) -> Optional[Tuple[Path, List[List[float]]]]:
    """
    Produit UNE piste audio et la durée de parole de CHAQUE bloc.

    Returns:
        (chemin_audio, durées[scène][bloc]) — la durée d'un bloc est exactement celle
        de son segment de voix, respiration comprise. Le moteur de page utilise ces
        durées comme temps d'écriture : la synchronisation est donc exacte par
        construction, et non approchée après coup.
    """
    if not is_available():
        logger.warning("[narration] aucun fournisseur TTS -> pas de narration par bloc")
        return None

    scenes = storyboard.get("scenes") or []
    if not scenes:
        return None

    work_dir = Path(work_dir)
    _prune_tts_cache()

    # ── 1. Collecte des textes à dire, bloc par bloc ──────────────────────
    per_scene_blocks: List[List[Dict[str, Any]]] = [
        [b for b in (scene.get("blocks") or []) if isinstance(b, dict)]
        for scene in scenes
    ]
    speech: Dict[Tuple[int, int], str] = {
        (si, bi): _block_speech_text(block)
        for si, blocks in enumerate(per_scene_blocks)
        for bi, block in enumerate(blocks)
    }

    # ── 2. TTS en PARALLÈLE, avec cache ─────────────────────────────────
    # Les appels TTS sont des attentes réseau indépendantes : les faire l'un après
    # l'autre coûtait 31,5 s pour 14 blocs (mesuré). Six à la fois -> ~5 s.
    audio_files: Dict[Tuple[int, int], Optional[Path]] = {}
    to_generate = [(k, t) for k, t in speech.items() if t]
    with ThreadPoolExecutor(max_workers=TTS_PARALLEL) as pool:
        futures = {pool.submit(_tts_cached, t, language): k for k, t in to_generate}
        for fut in as_completed(futures):
            k = futures[fut]
            try:
                audio_files[k] = fut.result()
            except Exception as exc:  # noqa: BLE001
                logger.warning("[narration] TTS echec scene %d bloc %d : %s",
                               k[0], k[1], exc)
                audio_files[k] = None

    # ── 3. Assemblage séquentiel, dans l'ordre exact d'écriture ──────────────
    segments: List[Path] = []
    durations: List[List[float]] = []
    index = 0

    for si, blocks in enumerate(per_scene_blocks):
        scene_durations: List[float] = []

        for bi, _block in enumerate(blocks):
            text = speech[(si, bi)]
            src = audio_files.get((si, bi))
            seg = work_dir / f"seg_{index:03d}.wav"
            index += 1

            if not text:
                # Bloc sans parole (illustration) : un temps court, pas un blanc gênant.
                dur = 1.6
                _silence_wav(seg, dur)
            elif src is None:
                # TTS en échec : on réserve un temps d'écriture proportionnel au
                # texte, calculé au rythme académique. Le bloc reste lisible.
                dur = max(2.0, len(text.split()) / ACADEMIC_WPM * 60.0)
                _silence_wav(seg, dur)
            else:
                spoken = _probe_duration_sec(src)
                if spoken <= 0:
                    spoken = max(2.0, len(text.split()) / ACADEMIC_WPM * 60.0)
                dur = spoken + BLOCK_BREATH_SEC
                try:
                    _pad_audio(src, seg, dur, language)
                except Exception as exc:  # noqa: BLE001
                    logger.warning("[narration] pad echec bloc %d : %s", index, exc)
                    _silence_wav(seg, dur)

            segments.append(seg)
            scene_durations.append(dur)

        durations.append(scene_durations)

    if not segments:
        return None

    # Concaténation dans l'ordre exact d'écriture.
    liste = work_dir / "segments.txt"
    liste.write_text("\n".join(f"file '{p.resolve()}'" for p in segments), encoding="utf-8")
    final = work_dir / "narration_blocs.wav"
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0",
             "-i", str(liste), "-ar", "44100", "-ac", "2", str(final)],
            capture_output=True, text=True, timeout=600, check=True,
        )
    except subprocess.CalledProcessError as exc:
        logger.error("[narration] concatenation echouee : %s", (exc.stderr or "")[:300])
        return None

    total_sec = sum(sum(s) for s in durations)
    logger.info(
        "[narration] %d segments, %.1f s de parole (rythme academique %d mots/min)",
        len(segments), total_sec, ACADEMIC_WPM,
    )
    return final, durations


def build_narration(
    storyboard: Dict[str, Any],
    base_scene_durations_sec: List[float],
    work_dir: Path,
    language: str = "fr",
) -> Optional[Tuple[Path, List[float]]]:
    """
    Génère la piste de narration et les durées de scène ajustées.

    Args:
        storyboard: le storyboard JSON (dict).
        base_scene_durations_sec: durées initiales par scène (issues du storyboard).
        work_dir: répertoire de travail temporaire.
        language: langue TTS (défaut 'fr').

    Returns:
        (chemin_audio_narration, durées_ajustées_sec) ou None si indisponible.
    """
    # Correctif 25/07/2026 : on n'exigeait que gTTS ici, si bien qu'un serveur sans le
    # paquet Python `gTTS` produisait des vidéos MUETTES — même quand le fournisseur
    # premium (OpenRouter via l'Edge Function `whiteboard-tts`) était parfaitement
    # disponible. On accepte désormais dès qu'AU MOINS UN fournisseur est utilisable.
    if not is_available():
        logger.warning(
            "[narration] aucun fournisseur TTS disponible "
            "(ni WHITEBOARD_TTS_URL+SUPABASE_SERVICE_KEY, ni gTTS) -> narration ignorée"
        )
        return None

    scenes = storyboard.get("scenes", []) or []
    if not scenes:
        return None

    segment_paths: List[Path] = []
    adjusted_durations: List[float] = []

    for idx, scene in enumerate(scenes):
        base_dur = base_scene_durations_sec[idx] if idx < len(base_scene_durations_sec) else MIN_SCENE_SEC
        text = _scene_text(scene if isinstance(scene, dict) else {})

        seg_path = work_dir / f"narration_scene_{idx:03d}.wav"

        if not text:
            # Aucune narration : silence de la durée de base
            target = max(base_dur, MIN_SCENE_SEC)
            _silence_wav(seg_path, target)
            adjusted_durations.append(target)
            segment_paths.append(seg_path)
            continue

        # 1. Générer le segment (cache + rythme + loudness), OpenRouter puis gTTS
        try:
            mp3_path = _tts_cached(text, language)
            provider = "cache/tts"
        except Exception as e:
            logger.warning(f"[narration] TTS échec scène {idx}: {e}")
            target = max(base_dur, MIN_SCENE_SEC)
            _silence_wav(seg_path, target)
            adjusted_durations.append(target)
            segment_paths.append(seg_path)
            continue

        # 2. Mesurer la durée de la narration
        audio_dur = _probe_duration_sec(mp3_path)
        # 3. Durée effective : LA VOIX MÈNE LE RYTHME.
        #
        # Correctif 25/07/2026 (« on a l'impression que la vidéo s'arrête ») : on faisait
        # target = max(base_dur, audio + padding). Or le générateur IA annonce des durées
        # généreuses (20 s par scène). Une narration de 7 s laissait donc 13 s de silence
        # sur une image fixe — d'où la sensation de vidéo bloquée entre chaque bloc.
        #
        # On cale désormais la scène sur la voix, avec deux garde-fous :
        #  - un plancher de lisibilité proportionnel à la quantité de texte affiché,
        #    pour laisser le temps de lire ce qui est à l'écran ;
        #  - un plafond : on ne dépasse pas la durée annoncée par le storyboard.
        readable_floor = min(base_dur, MIN_SCENE_SEC + len(text) / 55.0)
        target = max(audio_dur + SCENE_PADDING_SEC, readable_floor, MIN_SCENE_SEC)
        target = min(target, max(base_dur, audio_dur + SCENE_PADDING_SEC))
        # 4. Padder l'audio avec du silence jusqu'à target
        try:
            _pad_audio(mp3_path, seg_path, target, language)
        except Exception as e:
            logger.warning(f"[narration] pad échec scène {idx}: {e}")
            _silence_wav(seg_path, target)

        adjusted_durations.append(target)
        segment_paths.append(seg_path)
        logger.info(
            f"[narration] scène {idx}: provider={provider} text={len(text)}c "
            f"audio={audio_dur:.1f}s target={target:.1f}s"
        )

    # 5. Concaténer tous les segments en une piste unique
    concat_list = work_dir / "narration_concat.txt"
    with open(concat_list, "w", encoding="utf-8") as f:
        for p in segment_paths:
            f.write(f"file '{p.as_posix()}'\n")

    narration_path = work_dir / "narration_full.wav"
    try:
        subprocess.run(
            [
                "ffmpeg", "-y", "-f", "concat", "-safe", "0",
                "-i", str(concat_list),
                "-ar", "44100", "-ac", "2",
                str(narration_path),
            ],
            capture_output=True, text=True, timeout=180, check=True,
        )
    except subprocess.CalledProcessError as e:
        logger.error(f"[narration] concat échec: {e.stderr[:400] if e.stderr else e}")
        return None

    logger.info(f"[narration] piste générée: {narration_path} ({len(scenes)} scènes)")
    return narration_path, adjusted_durations


def mux_audio_into_video(video_path: Path, audio_path: Path, out_path: Path) -> Path:
    """
    Injecte la piste de narration dans la vidéo (qui n'a pas d'audio).

    Pas de filtre ici : chaque segment est déjà normalisé à -16 LUFS à la source
    (`_postprocess_tts`). Le mux se réduit à l'encodage AAC — mesuré 23,9 s avec
    loudnorm au mux, ~8 s sans (26/07/2026).
    """
    subprocess.run(
        [
            "ffmpeg", "-y",
            "-i", str(video_path),
            "-i", str(audio_path),
            "-map", "0:v",
            "-map", "1:a",
            "-c:v", "copy",
            "-c:a", "aac",
            "-b:a", "192k",
            "-shortest",
            str(out_path),
        ],
        capture_output=True, text=True, timeout=300, check=True,
    )
    return out_path
