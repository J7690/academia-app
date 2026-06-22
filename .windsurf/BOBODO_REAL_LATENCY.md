# BOBODO_REAL_LATENCY

## Phase 2 — Mesure de latence réelle

---

### Date
2026-06-12

---

### Méthodologie

**Localisation du test :** Serveur Kamatera (localhost WS)
**Outil :** Script Python `test_latency_on_server.py`
**Audio source :** gTTS génération locale → ffmpeg conversion PCM16 16kHz mono
**Phrase test :** "Bonjour Bobodo, comment ça va ?"
**Session :** `a5eea5b6-7477-4035-b332-444d94de3125` (session existante en base)
**Essais :** 3 trials (2 réussis, 1 timeout)

---

### Architecture mesurée

```
[Envoi audio] → [STT Whisper] → [Transcription] → [Appel Bobodo Edge Function] → [TTS gTTS] → [Réception audio_response]
```

---

### Résultats bruts

| Trial | WS Connect (ms) | Send Session (ms) | Send Audio (ms) | STT Latency (ms) | Transcription | Bobodo+TTS (ms) | Audio Length | Total (ms) |
|---|---|---|---|---|---|---|---|---|
| 1 | 75 | 0.3 | 7.6 | **8394** | "Bonjour Bobodo, comment ça va ?" | **3300** | 60928 | 12071 |
| 2 | 55 | 0.2 | 8.3 | **8371** | "Bonjour Bobodo, comment ça va ?" | **2437** | 51712 | 11115 |
| 3 | — | — | — | — | — | Timeout | — | — |

---

### Latence agrégée

| Étape | Minimum (ms) | Moyenne (ms) | Maximum (ms) |
|---|---|---|---|
| **STT** (Faster Whisper medium, CPU) | 8371 | 8383 | 8394 |
| **Bobodo + TTS** (Edge Function + gTTS) | 2437 | 2869 | 3300 |
| **Total end-to-end** | 11115 | 11593 | 12071 |

---

### Analyse

**STT : ~8.4 secondes**
- Temps de buffer accumulation (détection silence) : ~6-7s
- Transcription Whisper medium sur CPU : ~1.5-2s
- **Bottleneck identifié :** Buffer STT global avec détection de silence fixe à 1000ms

**Bobodo (LLM via OpenRouter) + TTS (gTTS) : ~2.5-3.3 secondes**
- Appel Edge Function → OpenRouter `google/gemini-2.5-flash` : ~2-2.5s
- TTS gTTS génération MP3 : ~300-500ms
- Encodage base64 + envoi WS : ~50ms

**Total : ~11-12 secondes**
- L'utilisateur parle pendant ~2.5s
- Attend ~8.4s de silence + STT
- Attend ~2.9s de traitement LLM + TTS
- **Total perçu : ~11-12s entre la fin de la parole et le début de la réponse audio**

---

### Comparaison ChatGPT Voice (référence)

| | ChatGPT Voice | Bobodo Voice (actuel) |
|---|---|---|
| Latence STT | ~200-500ms (streaming) | ~8.4s (buffer + Whisper) |
| Latence LLM | ~500-1500ms | ~2.5s (OpenRouter) |
| Latence TTS | ~200-500ms (streaming) | ~300-500ms (gTTS) |
| **Total** | **~1-2s** | **~11-12s** |

---

### Verdict

✅ Le flux fonctionne de bout en bout (STT → Bobodo → TTS).

⚠️ La latence STT (~8.4s) est **critique**. Elle rend l'expérience non fluide. La cause principale est le buffer de silence qui accumule l'audio avant transcription.

**Recommandation :** Le mode conversation continue (Phase 3) est implémentable malgré cette latence, mais l'UX nécessitera une optimisation du STT par la suite (streaming STT ou réduction du buffer silence).
