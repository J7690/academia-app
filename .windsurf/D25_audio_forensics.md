# D25_audio_forensics.md — Audit forensique des pistes audio

## Render de référence
- render_id : `ad74ed9e-2133-4c79-9a84-29b33d9d8fb3`
- narration_mode : **tts** (storyboard JSON)

---

## RESPONSABILITÉ THÉORIQUE

| Composant | Responsable audio ? | Justification |
|---|---|---|
| Flutter | **NON** | UI display uniquement, ne génère aucun fichier media |
| Edge Function (whiteboard-generate-storyboard) | **NON** | Génère le storyboard JSON, pas de fichier audio |
| Supabase | **NON** | Stockage et routing, aucune génération media |
| **Kamatera Worker** | **OUI (orchestration)** | Appelle l'assembler FFmpeg, responsable de fournir l'audio |
| **FFmpeg Assembler** | **OUI (direct)** | Construit la commande FFmpeg avec ou sans `-c:a` |
| **TTS Service** | **OUI SI tts** | Doit générer le fichier narration.mp3/wav avant FFmpeg |

---

## RESPONSABILITÉ RÉELLE — PREUVES RUNTIME

### 1. Grep commandes FFmpeg réellement exécutées

Source : `/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py` (MD5: `1aef5f207a1491f2e0b2855ce63d4f59`)

```python
# Lignes contenant audio dans la commande FFmpeg réelle :
"-f", "lavfi",
"-i", "anullsrc=r=44100:cl=stereo",   # ← SOURCE AUDIO : générateur silence
"-c:a", "aac",                         # ← CODEC : AAC
"-b:a", "64k",                         # ← BITRATE : 64kbps
"-ar", "44100",                        # ← SAMPLE RATE : 44100Hz
"-ac", "2",                            # ← CANAUX : stéréo
"-shortest",                           # ← Durée = vidéo (pas audio infini)
```

### 2. Présence / absence des flags audio

| Flag | Présent | Valeur |
|---|---|---|
| `-c:a aac` | **OUI** | aac |
| `-b:a` | **OUI** | 64k |
| `-ar` | **OUI** | 44100 |
| `-ac` | **OUI** | 2 (stéréo) |
| `-an` | **NON** | — |
| `-i audio.mp3` | **NON** | — |
| `-i narration.wav` | **NON** | — |
| `-map 0:v` | **NON** | mapping auto |
| `anullsrc` | **OUI** | silence synthétique |
| `-i tts_output` | **NON** | — |

### 3. ffprobe -show_streams — résultat réel

```
nb_streams    : 2 (video=1, audio=1)

AUDIO STREAM :
  codec_name    : aac
  sample_rate   : 44100 Hz
  channels      : 2 (stereo)
  channel_layout: stereo
  nb_frames     : 2152
  duration      : 49.946009s
  time_base     : 1/44100
  duration_ts   : 2202619
  bit_rate      : 2091 bps
```

**→ VIDEO + AUDIO : OUI (audio AAC silencieux synthétique)**

---

## VERDICT : QUI AURAIT DÛ CRÉER L'AUDIO RÉEL (TTS) ?

### narration_mode = "tts"

Le storyboard indique `narration_mode: "tts"` — une voix TTS est attendue.

### Preuve : le worker n'appelle jamais un TTS

Source `whiteboard_render_worker.py` ligne 125 :
```python
png_paths = render_storyboard_to_pngs(storyboard_json, temp_path)
mp4_path = assemble_pngs_to_mp4(png_paths, temp_path)
```

**Aucun appel TTS entre les deux lignes.** Le worker passe directement de PNG → MP4 sans générer ni injecter de narration audio.

### Preuve : l'assembler ne reçoit pas de fichier audio

Signature actuelle :
```python
def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path) -> Path:
```
**Aucun paramètre `audio_path` ou `narration_path`.**

### Premier composant défaillant sur la chaîne audio TTS

```
storyboard_json (narration_mode="tts")
    ↓
whiteboard_render_worker.py
    — devrait appeler TTS API et obtenir narration.mp3
    — NE LE FAIT PAS
    ↓
whiteboard_ffmpeg_assembler.py
    — reçoit uniquement png_paths (pas d'audio)
    — génère anullsrc (silence) comme fallback
    ↓
MP4 produit : audio AAC SILENCIEUX (pas de voix)
```

**Responsable de l'absence de TTS : `whiteboard_render_worker.py`** — ne génère jamais la narration avant l'assemblage.

---

## Résumé audio

| Question | Réponse prouvée |
|---|---|
| Audio présent dans MP4 ? | **OUI** — AAC 44100Hz stéréo 64kbps |
| Audio réel (TTS) ? | **NON** — silence synthétique (anullsrc) |
| Responsable audio actuel | `whiteboard_ffmpeg_assembler.py` v7 (correction D.25 P1) |
| Responsable absence TTS | `whiteboard_render_worker.py` — aucun appel TTS |
| ExoPlayer compatible ? | **OUI** — AAC présent résout le crash OMX Qualcomm |
| Expérience utilisateur | Vidéo muette malgré narration_mode=tts |

---

*Toutes les valeurs sont issues de données runtime réelles (code source SSH, ffprobe Kamatera, Supabase SQL).*
