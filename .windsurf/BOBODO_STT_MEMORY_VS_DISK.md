# BOBODO_STT_MEMORY_VS_DISK

## Mission 5 — Traitement en mémoire vs fichiers temporaires

---

### Date
2026-06-13

---

### Question

L'audio est-il traité :
- **en mémoire vive** (RAM uniquement)
- **via fichiers temporaires sur disque** (I/O disque)

---

### Preuve 1 : Le buffer audio est en mémoire

**Fichier :** `stt_service.py`, ligne 30

```python
self.audio_buffer = bytearray()  # Buffer global en mémoire
```

**Accumulation :** `stt_service.py`, ligne 166

```python
self.audio_buffer.extend(audio_bytes)  # Accumulation RAM
```

Le buffer `bytearray` est alloué en mémoire vive. Il accumule tous les chunks audio reçus par WebSocket jusqu'à détection de silence.

---

### Preuve 2 : La conversion WAV est en mémoire

**Fichier :** `stt_service.py`, lignes 63-99

```python
def _add_wav_header(self, raw_pcm: bytes) -> bytes:
    # Calcul entièrement en mémoire
    data_size = len(raw_pcm)
    total_size = 36 + data_size
    # ... struct.pack ...
    wav_data = header + fmt_chunk + data_chunk_header + raw_pcm
    return wav_data  # Retourne bytes en mémoire
```

Le header WAV est construit en mémoire via `struct.pack`. Aucun accès disque pendant cette phase.

---

### Preuve 3 : L'écriture sur disque se produit avant transcription

**Fichier :** `stt_service.py`, lignes 127-132

```python
with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
    temp_file.write(wav_data)      # ÉCRITURE DISQUE
    temp_path = temp_file.name
```

**Fichier :** `stt_service.py`, lignes 134-138

```python
result = await self.transcribe_file(temp_path)  # Lecture DISQUE par Whisper
# ...
os.unlink(temp_path)  # Suppression DISQUE
```

L'audio complet (PCM + WAV header) est **écrit sur disque** avant d'être passé à Faster Whisper.

---

### Preuve 4 : Mesure du coût disque

**Performance disque mesurée :**
```
dd if=/dev/zero of=/tmp/test_write bs=1M count=10
→ 10 MB copied, 0.0185 s, 566 MB/s
```

**Taille du fichier temporaire :**
- Test "long" : 159 788 bytes = ~156 KB
- Test "medium" : ~132 KB

**Coût écriture :**
```
156 KB / 566 000 KB/s = 0.00028 s = 0.28 ms
```

**Mesure réelle via logs :**
- `[STT_TEMP_FILE_CREATED]` → `[STT_TRANSCRIPTION_START]` = **2 ms**
- `[STT_TEMP_FILE_CLEANED]` = **0 ms** (asynchrone)

---

### Preuve 5 : Faster Whisper lit depuis le fichier

**Fichier :** `stt_service.py`, ligne 235

```python
segments, info = self.model.transcribe(
    audio_path,  # <-- Chemin fichier, pas bytes
    language="fr",
    beam_size=5,
    vad_filter=False
)
```

Faster Whisper reçoit un **chemin de fichier** (`str`), pas des bytes en mémoire. La librairie charge elle-même le fichier depuis le disque.

---

### Synthèse du flux

```
[WebSocket audio chunks] → bytearray (RAM)
                                    ↓
                         [Silence detected]
                                    ↓
                         WAV header + PCM (RAM)
                                    ↓
                    Écriture /tmp/tmpXXXX.wav (DISQUE, ~2ms)
                                    ↓
                    Faster Whisper lit le fichier (DISQUE→RAM, ~9s)
                                    ↓
                    Suppression /tmp/tmpXXXX.wav (DISQUE, ~0ms)
```

---

### Conclusion

| Étape | Support | Coût |
|---|---|---|
| Réception + buffer | **RAM** | ~0 ms |
| Construction WAV | **RAM** | ~0 ms |
| Écriture fichier temp | **DISQUE** | **~2 ms** |
| Inférence Whisper | **RAM** (après lecture disque) | **~9128 ms** |
| Suppression fichier | **DISQUE** | ~0 ms |

**Le traitement est hybride :**
- Les étapes préparatoires se font en **mémoire**
- L'inférence Whisper nécessite un **fichier temporaire sur disque**
- Le coût disque total est **~2 ms (<0.1%)**
- Le coût mémoire/CPU (inférence) est **~9128 ms (>99%)**

**Le disque n'est pas un goulot d'étranglement.**
