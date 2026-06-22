# BOBODO_STT_LATENCY_BREAKDOWN

## Mission 1 — Décomposition de la latence STT

---

### Date
2026-06-13

---

### Méthodologie

**Serveur :** Kamatera (185.167.97.144)
**Outil :** Scripts Python `audit_stt_precise.py` (exécuté sur le serveur)
**Méthode :** 3 tests avec phrases de longueurs différentes, mesure côté client et extraction des logs serveur
**Audio source :** gTTS → ffmpeg PCM16 16kHz mono
**Connexion :** WebSocket localhost (pas de latence réseau significative)

---

### Mesures séparées par étape

#### Test "long" (phrase : 4.99s audio, 159744 bytes PCM)

| Étape | Timestamp début | Timestamp fin | Durée (ms) | % du total |
|---|---|---|---|---|
| Connexion WS | 07:37:36,219 | 07:37:36,280 | 61 | 0.6% |
| Envoi audio | 07:37:36,280 | 07:37:36,299 | 19 | 0.2% |
| Réception serveur | 07:37:36,299 | 07:37:36,304 | 5 | 0.0% |
| **Attente silence** | 07:37:36,304 | 07:37:37,305 | **1001** | **9.9%** |
| Création WAV + fichier temp | 07:37:37,305 | 07:37:37,307 | 2 | 0.0% |
| **Transcription Whisper** | 07:37:37,307 | 07:37:46,435 | **9128** | **89.9%** |
| Cleanup + callback | 07:37:46,435 | 07:37:46,436 | 1 | 0.0% |
| Retour WS transcription | 07:37:46,436 | 07:37:46,441 | 5 | 0.0% |
| **TOTAL STT** | — | — | **10,142** | **100%** |

#### Test "medium" (phrase : 2.95s audio, 94464 bytes PCM)

| Étape | Timestamp début | Timestamp fin | Durée (ms) | % du total |
|---|---|---|---|---|
| Connexion WS | — | — | 58 | 0.6% |
| Envoi audio | — | — | 10 | 0.1% |
| Attente silence | — | — | **~1000** | **9.9%** |
| Création WAV + fichier temp | — | — | ~2 | 0.0% |
| **Transcription Whisper** | 07:37:19,295 | 07:37:28,247 | **8952** | **88.9%** |
| Cleanup + callback | — | — | ~1 | 0.0% |
| **TOTAL STT** | — | — | **10,064** | **100%** |

---

### Détail du calcul Whisper

Pour le test "long" (audio 4.99s) :
```
07:37:37,307 - [STT_TRANSCRIPTION_START] Transcribing file ...
07:37:37,401 - [faster_whisper] Processing audio with duration 4.99s
07:37:46,435 - [STT_TRANSCRIPTION_SUCCESS] Transcription completed

Durée Whisper = 46.435 - 37.307 = 9.128 secondes
```

Pour le test "medium" (audio 2.95s) :
```
07:37:19,295 - [STT_TRANSCRIPTION_START]
07:37:28,247 - [STT_TRANSCRIPTION_SUCCESS]

Durée Whisper = 28.247 - 19.295 = 8.952 secondes
```

---

### Conclusion Mission 1

La latence STT totale de ~10.1 secondes se décompose ainsi :

1. **Transcription Whisper (model medium, CPU)** : ~9.0-9.1s (**89-90%**)
2. **Attente seuil de silence (fixe à 1000ms)** : ~1.0s (**10%**)
3. **Réseau + WS + fichiers temp** : ~0.1s (**<1%**)

Le réseau et le disque sont **négligeables**. La totalité de la latence vient du modèle Whisper et du seuil de silence.
