# BOBODO_STT_INTERNAL_TIMING

## Mission 3 — Timing interne de stt_service.py

---

### Date
2026-06-13

---

### Méthode

Analyse des logs `journalctl` pour le test "long" (4.99s audio, 159744 bytes PCM) avec extraction des timestamps précis de chaque phase interne.

---

### Séquence chronologique des événements internes

Test "long" — Phrase : "Explique moi la photosynthese en termes simples pour un eleve de college"

| # | Événement | Timestamp | Delta (ms) | Code source |
|---|---|---|---|---|
| 1 | Audio reçu par WS | 07:37:36,304 | — | `websocket_handler.py` → `stt_service.transcribe()` |
| 2 | `[STT_AUDIO_RECEIVED]` | 07:37:36,304 | 0 | `stt_service.py:163` |
| 3 | `[STT_BUFFER]` accumulation | 07:37:36,304 | 0 | `stt_service.py:168` |
| 4 | `[STT_SILENCE_CANCELLED]` | 07:37:37,305 | 1001 | `stt_service.py:176` (nouvelle tâche silencce) |
| 5 | `[STT_SILENCE_DETECTED]` déclenché | 07:37:37,305 | 0 | `stt_service.py:107` |
| 6 | `[STT_SILENCE_DETECTED]` buffer 4.13s | 07:37:37,305 | 0 | `stt_service.py:108` |
| 7 | `[STT_SILENCE_DETECTED]` start transcription | 07:37:37,305 | 0 | `stt_service.py:118` |
| 8 | `[STT_WAV_HEADER]` Adding WAV header | 07:37:37,305 | 0 | `stt_service.py:76` |
| 9 | `[STT_WAV_HEADER]` WAV file created | 07:37:37,305 | 0 | `stt_service.py:98` |
| 10 | `[STT_TEMP_FILE_CREATED]` | 07:37:37,307 | 2 | `stt_service.py:131` |
| 11 | `[STT_TEMP_FILE_SIZE]` 159788 bytes | 07:37:37,307 | 0 | `stt_service.py:132` |
| 12 | `[STT_TRANSCRIPTION_START]` | 07:37:37,307 | 0 | `stt_service.py:230` |
| 13 | `[STT_TRANSCRIPTION_START]` File exists | 07:37:37,307 | 0 | `stt_service.py:231` |
| 14 | `[STT_TRANSCRIPTION_START]` File size | 07:37:37,307 | 0 | `stt_service.py:232` |
| 15 | `[faster_whisper]` Processing audio | 07:37:37,401 | 94 | `stt_service.py:235-240` |
| 16 | `[STT_TRANSCRIPTION_INFO]` Lang: fr, Dur: 4.99s | 07:37:37,410 | 9 | `stt_service.py:242` |
| 17 | `[STT_TRANSCRIPTION_SUCCESS]` | 07:37:46,435 | 9025 | `stt_service.py:251` |
| 18 | `[STT_TRANSCRIPTION_RESULT]` | 07:37:46,436 | 1 | `stt_service.py:252` |
| 19 | `[STT_TEMP_FILE_CLEANED]` | 07:37:46,436 | 0 | `stt_service.py:138` |
| 20 | `[STT_CALLBACK]` | 07:37:46,436 | 0 | `stt_service.py:143` |

---

### Timing par fonction

| Fonction | Lignes | Durée (ms) | % du temps STT |
|---|---|---|---|
| `transcribe()` (réception + buffer) | 148-187 | ~1 | <0.1% |
| `_wait_for_silence()` | 189-213 | **1001** | **9.9%** |
| `_detect_silence()` (préparation) | 101-146 | ~4 | <0.1% |
| `_add_wav_header()` | 63-99 | ~0 | 0% |
| Écriture fichier temporaire | 127-132 | ~2 | <0.1% |
| `transcribe_file()` → `model.transcribe()` | 215-253 | **9128** | **89.9%** |
| Cleanup + callback | 138,143 | ~1 | <0.1% |
| **TOTAL** | — | **10,137** | **100%** |

---

### Détail du goulot d'étranglement

La fonction `model.transcribe()` (ligne 235-240) consomme **9128 ms** pour un audio de 4.99 secondes.

**Code exact :**
```python
# stt_service.py:235-240
segments, info = self.model.transcribe(
    audio_path,
    language="fr",
    beam_size=5,
    vad_filter=False
)
```

**Paramètres utilisés :**
- `beam_size=5` : Décodeur beam search avec 5 chemins
- `vad_filter=False` : Pas de filtrage VAD (Voice Activity Detection)
- `language="fr"` : Forçage langue française

**Le paramètre `beam_size=5` est coûteux.** En inférence CPU, beam_size=1 (greedy) serait ~3-5x plus rapide.

---

### Vérification : le modèle est-il en mémoire ?

**Preuve :** Le processus Python consomme **1.7 GB RAM** (vu via `ps aux` : `1709256` résident).

```
root 148819 1.5 16.7 6122444 1709256 ? Ssl 07:22 0:10 /opt/bobodo-vocal/venv/bin/python main.py
```

Le modèle Faster Whisper medium (~1.5 GB sur disque) est chargé en mémoire au démarrage du service et y reste. Aucun chargement disque ne se produit pendant la transcription.

---

### Vérification : traitement en mémoire vs fichier temporaire

**Preuve directe du code :**

```python
# stt_service.py:127-132
with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
    temp_file.write(wav_data)
    temp_path = temp_file.name

# stt_service.py:235
segments, info = self.model.transcribe(audio_path, ...)
```

**Conclusion :** L'audio est écrit sur **disque** (fichier temporaire `/tmp/tmpXXXXXX.wav`) avant d'être passé à Faster Whisper. Le traitement n'est **pas** entièrement en mémoire.

**Coût mesuré :**
- Écriture WAV 159788 bytes : ~2 ms
- Lecture par Faster Whisper : incluse dans les 9128 ms
- Suppression fichier : ~0 ms

Le coût disque est **négligeable** (<0.1%) car le disque Kamatera fait 566 MB/s en écriture séquentielle.
