# D25_tools_benchmark.md — Outils d'analyse MP4 recommandés par l'industrie

## 1. ffprobe (FFmpeg)

**Usage industrie :** Outil universel #1 pour l'analyse de fichiers media.

| Capacité | Commande | Vérifie quoi |
|---|---|---|
| Durées | `ffprobe -show_format -show_streams input.mp4` | duration container + streams |
| Pistes audio | `ffprobe -show_streams -select_streams a input.mp4` | codec, sample_rate, channels |
| Compatibilité Android | `ffprobe -show_streams -select_streams v input.mp4` | profile, level, pix_fmt |
| Structure MP4 | `ffprobe -show_format input.mp4` | format_name, nb_streams |
| Faststart | `ffprobe -v verbose input.mp4 2>&1 \| grep moov` | position moov |
| Frames réels | `ffprobe -show_frames -select_streams v input.mp4` | nb_frames, pts timing |
| Erreurs decode | `ffmpeg -v error -i input.mp4 -f null -` | decode errors |
| VUI color | `ffprobe -v verbose input.mp4 2>&1 \| grep -i color` | bt709 / smpte170m |

**Disponible sur Kamatera :** OUI (`ffmpeg version 6.1.1-3ubuntu5`)

---

## 2. MediaInfo

**Usage industrie :** Outil GUI/CLI populaire, interface plus lisible que ffprobe.

```bash
mediainfo input.mp4
mediainfo --Output=JSON input.mp4
```

**Avantages vs ffprobe :**
- Détection automatique du profil codec (Constrained Baseline, High)
- Rapport lisible par des non-techniques
- Détaille `Writing library`, `Encoded date`, `Tagged date`

**Vérifie :**
- A. Durées : `Duration` par stream
- B. Pistes audio : `Audio #1: AAC LC, 44.1 kHz, Stereo`
- C. Compatibilité Android : `Profile: Constrained Baseline@L3.1`
- D. Structure MP4 : atom order (via verbose)
- E. Faststart : via `IsStreamable: Yes`

---

## 3. mp4dump (Bento4)

**Usage industrie :** Analyse chirurgicale de la structure ISO BMFF.

```bash
mp4dump --verbosity 3 input.mp4
```

**Vérifie :**
- D. Structure MP4 : arbre complet des atoms (`ftyp`, `moov`, `trak`, `mdia`, `mdhd`, `mdat`)
- E. Faststart : position du `moov` par rapport à `mdat`
- Durées : `duration` dans `mvhd`, `tkhd`, `mdhd` — en time_base units
- Présence `sidx` pour fragmented MP4

**Exemple output :**
```
[ftyp] size=8+24
[moov] size=8+43145
  [mvhd] size=12+96, timescale=1000, duration=49967
  [trak] ...
    [mdhd] duration=1499, timescale=30
  [trak] ...
    [mdhd] duration=2202619, timescale=44100
[mdat] size=8+295655
```

---

## 4. Bento4 (mp4info, mp4fragment, mp4dash)

**Usage industrie :** Packaging HLS/DASH, CMAF, vérification de compatibilité streaming.

```bash
mp4info input.mp4
mp4fragment input.mp4 fragmented.mp4
```

**Vérifie :**
- Compatibilité streaming (HLS, DASH)
- Durée exacte par track (ms)
- Synchronisation A/V
- Conformité ISO BMFF

---

## 5. AtomicParsley

**Usage industrie :** Métadonnées ID3/iTunes dans les MP4.

```bash
AtomicParsley input.mp4 -t
```

**Vérifie :**
- Métadonnées embedded (`©nam`, `©art`, `©alb`)
- Tags `encoder`, `creation_time`
- **Pas** pour vérifier la structure vidéo/audio

---

## 6. VLC (Android / Desktop)

**Usage industrie :** Lecteur de référence pour tests de compatibilité maximale.
- Lit pratiquement tous les formats (profile H.264 quelconque, audio optionnel)
- Test de base : si VLC lit, le container est syntaxiquement valide
- **Ne garantit pas** la compatibilité ExoPlayer (décodeurs OMX différents)

---

## 7. mpv

**Usage industrie :** Lecteur CPU-only, idéal pour tests sans GPU.
- Révèle les erreurs de décodage que les lecteurs permissifs cachent
- `mpv --msg-level=all=v input.mp4` pour log complet

---

## 8. ExoPlayer Demo App (Android)

**Usage industrie :** Test de compatibilité native Android Media3.

- Repository : https://github.com/google/ExoPlayer
- Permet de tester exactement le comportement d'un décodeur `OMX.qcom.*`
- Révèle les erreurs `MediaCodecVideoRenderer error` impossibles à reproduire hors device

---

## 9. Android Media Inspector / adb logcat

**Usage industrie :** Seul moyen de voir les erreurs OMX runtime.

```bash
adb logcat | grep -E "ExoPlayer|MediaCodec|OMX|VideoRenderer"
```

Révèle :
- `MediaCodecVideoRenderer error` (crash OMX)
- `format_supported=YES` vs `decoder_supported=NO`
- Erreur de surface / buffer

---

## 10. Google Media Compatibility Tests (CTS)

**Usage industrie :** Suite de tests de conformité Android.
- `android.media.cts.DecoderTest`
- `android.media.cts.MediaPlayerTest`
- Vérifie que H.264 Baseline/Main/High + AAC passent sur tous les devices certifiés

---

## Recommandation pipeline de validation

Pour valider la conformité ExoPlayer d'un MP4 produit :

```bash
# Étape 1 : structure + streams
ffprobe -v quiet -print_format json -show_format -show_streams output.mp4

# Étape 2 : atoms (faststart)
python3 -c "
data=open('output.mp4','rb').read()
off,atoms=0,[]
while off<len(data)-8:
    sz=int.from_bytes(data[off:off+4],'big')
    nm=data[off+4:off+8].decode('ascii',errors='?')
    atoms.append(nm)
    if sz<8: break
    off+=sz
print(' > '.join(atoms))
"

# Étape 3 : VUI color
ffprobe -v verbose output.mp4 2>&1 | grep -iE 'bt709|smpte|color'

# Étape 4 : decode errors
ffmpeg -v error -i output.mp4 -f null -

# Étape 5 : test device physique
adb shell am start -n com.google.android.exoplayer2.demo/.PlayerActivity --es uri "file:///sdcard/test.mp4"
```

---

## Tableau — Quelle plateforme utilise quel outil

| Plateforme | Outil principal | Usage |
|---|---|---|
| YouTube | ffprobe (interne) | Vérification durée, codec, audio |
| Netflix / Disney+ | Bento4 + Shaka Packager | CMAF packaging, DRM |
| TikTok | MediaInfo (interne) | Validation upload |
| Instagram | ffprobe (Meta interne) | Vérification specs |
| Android CTS | CTS Media Tests | Conformité décodeurs |
| Google / ExoPlayer | ExoPlayer Demo App | Tests device |

---

*Sources : Bento4 docs, pkglog.com 2026, WINK MP4 Showdown 2025, probe.dev ffprobe vs mediainfo.*
