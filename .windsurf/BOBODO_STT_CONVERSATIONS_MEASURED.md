# BOBODO_STT_CONVERSATIONS_MEASURED

## Mission 2 — 5 conversations réelles avec métriques audio

---

### Date
2026-06-13

---

### Test 1

| Métrique | Valeur |
|---|---|
| Phrase | "Bonjour Bobodo, comment ça va ?" |
| Durée audio | 2.38s |
| Taille PCM | 76 032 bytes |
| Taille MP3 source | 19 008 bytes |
| Format | PCM16 16kHz mono (gTTS → ffmpeg) |
| Buffer STT au réception | **180 480 bytes** (104 448 bytes résiduels + 76 032 nouveaux) |
| Résultat | ❌ Timeout (buffer accumulé) |

---

### Test 2

| Métrique | Valeur |
|---|---|
| Phrase | "Quelle est la capitale du Burkina Faso ?" |
| Durée audio | 3.05s |
| Taille PCM | 97 536 bytes |
| Taille MP3 source | 24 384 bytes |
| Format | PCM16 16kHz mono |
| Buffer STT au réception | Accumulé (texte transcrit = Test 1 + Test 2) |
| Résultat | ❌ Timeout (buffer accumulé) |

**Transcription reçue :** "Bonjour Bobodo, comment ça va ? Bonjour Bobodo, comment ça va ? Quelle est la capitale du Burkina Faso ?"

**Preuve d'accumulation :** Le texte contient la phrase du Test 1 répétée 2 fois + la phrase du Test 2, confirmant que `self.audio_buffer` n'est jamais vidé entre connexions.

---

### Test 3

| Métrique | Valeur |
|---|---|
| Phrase | "Explique-moi la photosynthèse en deux phrases." |
| Durée audio | 3.00s |
| Taille PCM | 96 000 bytes |
| Taille MP3 source | 24 000 bytes |
| Format | PCM16 16kHz mono |
| Buffer STT au réception | 96 000 bytes (buffer propre, reset intermédiaire) |
| Latence STT | 9 560 ms |
| Résultat | ✅ Transcription correcte |

---

### Test 4

| Métrique | Valeur |
|---|---|
| Phrase | "Résous cette équation : deux x plus trois égale sept." |
| Durée audio | 4.01s |
| Taille PCM | 128 256 bytes |
| Taille MP3 source | 32 064 bytes |
| Format | PCM16 16kHz mono |
| Buffer STT au réception | 132 096 bytes |
| Latence STT | 8 905 ms |
| Résultat | ✅ "Résous cette équation. 2x plus 3 égale 7." |

---

### Test 5

| Métrique | Valeur |
|---|---|
| Phrase | "Donne-moi un conseil pour réviser efficacement." |
| Durée audio | 3.26s |
| Taille PCM | 104 448 bytes |
| Taille MP3 source | 26 112 bytes |
| Format | PCM16 16kHz mono |
| Buffer STT au réception | Accumulé |
| Résultat | ❌ Timeout |

---

### Agrégation des 5 tests (tests valides : 3 et 4)

| Métrique | Minimum | Moyenne | Maximum |
|---|---|---|---|
| Durée audio | 3.00s | 3.51s | 4.01s |
| Taille PCM | 96 000 | 112 128 | 128 256 |
| Taille MP3 | 24 000 | 26 688 | 32 064 |
| **Latence STT** | **8 905 ms** | **9 233 ms** | **9 560 ms** |

---

### Observation critique : accumulation du buffer

Le buffer `self.audio_buffer` dans `stt_service.py` (ligne 30) est un **bytearray global au niveau de la classe**. Il n'est jamais explicitement vidé entre les connexions WebSocket. Les conséquences :

- **Test 1** : Buffer initial = 104 448 bytes résiduels (des tests précédents non documentés) + 76 032 = 180 480 bytes
- **Test 2** : Buffer accumule encore → transcription contient Test 1 + Test 2
- **Test 3** : Le buffer semble avoir été vidé (peut-être par un silence détecté entre tests) → fonctionne
- **Test 4** : Buffer propre → fonctionne
- **Test 5** : Buffer accumule à nouveau → timeout

**Preuve directe du code :**
```python
# stt_service.py ligne 30
self.audio_buffer = bytearray()  # Créé une fois dans __init__

# Ligne 166
self.audio_buffer.extend(audio_bytes)  # Accumule sans jamais reset

# Ligne 120
audio_to_transcribe = bytes(self.audio_buffer)
self.audio_buffer.clear()  # Seulement vidé APRÈS silence détecté
```

Si une connexion WS se ferme AVANT que le silence ne soit détecté, le buffer conserve l'audio pour la prochaine connexion.
