# D25_final_responsibility_matrix.md — Matrice de responsabilité finale

## Render de référence

- render_id : `ad74ed9e-2133-4c79-9a84-29b33d9d8fb3`
- Storyboard : 9 scènes, 69 000ms attendus
- MP4 produit : 49.967s, AAC silencieux, 338 856 bytes

---

## RESPONSABILITÉ DE LA DURÉE VIDÉO

### Composant responsable
**`whiteboard_ffmpeg_assembler.py`** (MD5: `1aef5f207a1491f2e0b2855ce63d4f59`)
Secondairement : **`whiteboard_render_worker.py`** (duration_ms Supabase faux)

### Preuves runtime

**Fichier** : `/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py`

```python
# Ligne 18 — CAUSE RACINE
SECONDS_PER_SCENE = 5   # Hardcodé — ignore duration_ms du storyboard

# Lignes 31–37 — APPLICATION
for p in png_paths:
    f.write(f"file '{safe}'\n")
    f.write(f"duration {SECONDS_PER_SCENE}\n")  # 5s fixe
```

**Fichier** : `/opt/whiteboard-worker/whiteboard_render_worker.py`

```python
# Ligne 139
duration_ms = len(scenes) * 5000  # Estimation fausse (45000ms)
```

### Calcul démonstration
```
9 scènes × 5s/scène = 45.000s (concat.txt)
+ correction FFmpeg concat demuxer = 49.967s réel
vs storyboard = 69.000s (durées réelles 6–10s/scène)
Écart = -19.033s
```

### Conclusion
Le storyboard JSON contient les durées correctes par scène. L'assembler les ignore totalement, utilisant `SECONDS_PER_SCENE = 5` comme valeur fixe depuis la création du projet. La responsabilité est **exclusive à `whiteboard_ffmpeg_assembler.py` ligne 18** et à `whiteboard_render_worker.py` ligne 139 pour `duration_ms` Supabase.

---

## RESPONSABILITÉ DE LA PISTE AUDIO

### Composant responsable (audio présent)
**`whiteboard_ffmpeg_assembler.py` v7** — génère une piste AAC silencieuse via `anullsrc`

### Composant responsable (audio TTS absent)
**`whiteboard_render_worker.py`** — n'appelle jamais un service TTS malgré `narration_mode="tts"`

### Preuves runtime

```python
# whiteboard_render_worker.py lignes 124–133
png_paths = render_storyboard_to_pngs(storyboard_json, temp_path)
# ← ICI devrait être : audio_path = call_tts_service(storyboard_json)
mp4_path = assemble_pngs_to_mp4(png_paths, temp_path)
# ← assemble_pngs_to_mp4 ne reçoit JAMAIS de fichier audio
```

```python
# whiteboard_ffmpeg_assembler.py — signature
def assemble_pngs_to_mp4(png_paths: List[Path], output_dir: Path) -> Path:
# Pas de paramètre audio_path ou narration_path
```

```python
# Commande FFmpeg réelle — audio source
"-f", "lavfi",
"-i", "anullsrc=r=44100:cl=stereo",  # Silence synthétique
```

```
# ffprobe résultat
AUDIO: codec=aac sr=44100 channels=2 bit_rate=2091bps  ← 2 kbps (quasi-silence)
```

### Verdict
- Audio **présent** dans le MP4 (correction P1 D.25 appliquée) → ExoPlayer compatible
- Audio **silencieux** (narration_mode="tts" ignoré) → expérience utilisateur dégradée
- TTS jamais implémenté dans le worker

---

## RESPONSABILITÉ DE LA COMPATIBILITÉ EXOPLAYER

### Composant responsable initial (crash)
**`whiteboard_ffmpeg_assembler.py` avant v7** — produisait des MP4 video-only (sans `-c:a`)

### Composant responsable résolution (v7)
**`whiteboard_ffmpeg_assembler.py` v7** — ajoute `-c:a aac` via `anullsrc`

### Preuves runtime

**Avant v7 :** MP4 sans piste audio → `MediaCodecVideoRenderer error` sur OMX Qualcomm
**Après v7 :** MP4 avec AAC → ExoPlayer initialise correctement

```
ffprobe streams v7 :
  VIDEO: h264 Constrained Baseline level=31 bt709 yuv420p has_b_frames=0
  AUDIO: aac 44100Hz stereo 2152 frames
  
ffmpeg decode : AUCUNE erreur
VUI : bt709 pur, 0 smpte170m
atoms : ftyp > moov > free > mdat (faststart OK)
```

### Conformité ExoPlayer — 13/13 critères validés (test d25_final_validate.py)

---

## PREMIER POINT DE NON-CONFORMITÉ UNIQUE

### Le premier. Celui qui casse toute la chaîne.

**Fichier :** `/opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py`

**Ligne :** `18`

**Code :**
```python
SECONDS_PER_SCENE = 5
```

**Preuve runtime :**
- Storyboard : scènes de 6000ms à 10000ms (moy. 7666ms)
- Réalité produite : toutes les scènes = 5000ms exactement
- Résultat : 9 scènes × 5s = 45s → 49.97s réel vs 69s attendu

**Cause :**
Lors de la création du pipeline (Phase C.3), la durée par scène a été hardcodée à 5 secondes comme simplification temporaire ("V1 — on estime 5 secondes par scène", commentaire ligne 135 du worker).

**Conséquences :**
1. **Durée vidéo toujours fausse** — -19s pour ce projet, ±N×1.x pour tout autre
2. **duration_ms Supabase erroné** — Flutter affiche une barre de progression fausse
3. **Expérience pédagogique dégradée** — le contenu défile trop vite (5s) ou trop lentement selon la densité de la scène
4. **Le TTS (s'il était implémenté) serait désynchronisé** — la durée audio TTS ne correspond pas à la durée vidéo

---

## Matrice globale tous composants

| Composant | Durée vidéo | Audio présent | Audio TTS | Compat ExoPlayer |
|---|---|---|---|---|
| Storyboard JSON | Source vérité ✓ | N/A | Déclare tts ✓ | N/A |
| Flutter | Affiche ✓ | Affiche ✓ | N/A | Appelle ✓ |
| Edge Function | N/A | N/A | N/A | N/A |
| Supabase RPC | Stocke (faux) ✗ | N/A | N/A | N/A |
| **whiteboard_png_renderer.py** | Indépendant | N/A | N/A | N/A |
| **whiteboard_render_worker.py** | Calcul faux ✗ | Orchestre | **TTS absent** ✗ | Orchestre |
| **whiteboard_ffmpeg_assembler.py** | **5s fixe** ✗ | **AAC silence** ⚠ | Pas reçu | **Compatible v7** ✓ |
| FFmpeg 6.1.1 | Fidèle concat | Encode AAC | N/A | Produit conforme |

---

*Toutes les conclusions sont appuyées par des preuves runtime réelles :*
*code source SSH, ffprobe Kamatera, logs systemd, Supabase SQL.*
*Aucune déduction théorique.*
