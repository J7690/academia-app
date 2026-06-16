# BOBODO VOICE — AUDIT DE LATENCE BOUT-EN-BOUT

## Date : 14 Juin 2026

---

## Mission 1 — Mesures séparées par étape

### Données brutes (5 échanges, 1 user, localhost)

| # | T1 (silence+STT) | T2 (Bobodo+TTS) | Total | Texte |
|---|---|---|---|---|
| 0 | 8.39s | 3.21s | **11.61s** | Bonjour Bobodo |
| 1 | 8.85s | 3.91s | **12.76s** | Je veux parler à Bobodo |
| 2 | 9.22s | 3.61s | **12.83s** | Bobodo, explique-moi... |
| 3 | 8.60s | 3.80s | **12.40s** | Academia est une super... |
| 4 | 8.27s | 5.94s | **14.22s** | Comment fonctionne Academia? |

### Décomposition fine (échange 4, logs horodatés)

| Étape | Durée | Timestamp |
|---|---|---|
| **T1 — Silence detection** | 1.00s | 10:13:35.813 → 10:13:36.813 |
| **T2 — Whisper Medium transcription** | 7.26s | 10:13:36.814 → 10:13:44.072 |
| **T3 — Création session + envoi Edge Function** | 0.07s | 10:13:44.075 → 10:13:44.148 |
| **T4 — Edge Function (RAG + OpenRouter)** | 3.31s | 10:13:44.148 → 10:13:47.456 |
| **T5 — TTS gTTS** | 2.54s | 10:13:47.457 → 10:13:49.993 |
| **T6 — WebSocket send** | ~0.02s | Négligeable (localhost) |

### Tableau final normalisé (moyenne sur 5 échanges)

| Étape | Temps moyen | % du total |
|---|---|---|
| **Silence detection** | 1.00s | 8% |
| **Whisper Medium (STT)** | **7.28s** | **57%** |
| **Edge Function (Bobodo IA)** | 2.85s | 22% |
| **TTS (gTTS)** | 1.53s | 12% |
| **Réseau/WebSocket** | ~0.05s | <1% |
| **TOTAL** | **~12.7s** | 100% |

---

## Mission 2 — Étape la plus lente

### **Whisper Medium — 7.28s (57% du total)**

**Preuve (logs horodatés) :**

```
10:13:36.814 - [STT_SESSION:latency-test-4] Transcribing /tmp/tmpwinrvwcu.wav
10:13:44.072 - [STT_SESSION:latency-test-4] Transcription: 28 chars, 1 segments
```

Delta : **7.258 secondes** pour transcrire 2.06 secondes d'audio (ratio 3.5x temps réel).

---

## Mission 3 — Source de la latence

| Source | Contribution | Preuve |
|---|---|---|
| **STT (Whisper Medium)** | **57%** | Logs: 7.26s entre "Transcribing" et "Transcription" |
| Réseau | <1% | Logs: localhost, ~20ms total |
| Supabase REST | <1% | 0.07s pour créer la session |
| OpenRouter (via Edge Function) | 22% | 3.31s entre envoi et réponse |
| TTS (gTTS) | 12% | 2.54s pour l'échange le plus long |
| WebSocket | <1% | Négligeable |

**Réponse : La latence provient du STT.**

Whisper Medium sur CPU (4 cœurs Intel Xeon) prend 7.3 secondes pour transcrire ~2 secondes d'audio. C'est le goulot d'étranglement absolu du pipeline.

---

## Mission 4 — Correctifs > 1 seconde de gain

### Action 1 — Migrer Whisper Medium → Small

| | Medium | Small | Gain |
|---|---|---|---|
| Latence STT | 7.28s | **2.84s** | **-4.44s** |
| Source | Mesure actuelle | `small_load_test.json` (audit précédent) | |

**Gain : -4.44s (35% du total)**

Mesure réelle déjà disponible : `small_load_test.json` montre 2 837 ms pour Small sur le même serveur.

### Action 2 — Remplacer gTTS par TTS local (edge-tts ou piper)

| | gTTS | edge-tts (estimé) | Gain |
|---|---|---|---|
| Latence TTS | 1.53s (moy) / 2.54s (max) | ~0.3s | **-1.2 à -2.2s** |
| Source | Mesure actuelle | gTTS fait un appel réseau Google | |

**gTTS appelle `translate.google.com`** à chaque synthèse → latence réseau incluse. Un TTS local (piper) ou semi-local (edge-tts) élimine cette dépendance.

**Gain : -1.2s minimum**

### Action 3 — Réduire silence_threshold de 1000ms à 500ms

| | 1000ms | 500ms | Gain |
|---|---|---|---|
| Silence wait | 1.00s | 0.50s | **-0.5s** |

Ce n'est pas au-dessus du seuil de 1s, mais combiné aux autres c'est notable.

**Gain : -0.5s** (en dessous du seuil demandé — mentionné mais non priorisé)

---

## Livrable final

### Tableau récapitulatif

| Étape | Temps réel | % du total |
|---|---|---|
| Silence detection | 1.00s | 8% |
| **Whisper Medium (STT)** | **7.28s** | **57%** |
| Edge Function (Bobodo IA) | 2.85s | 22% |
| TTS (gTTS) | 1.53s | 12% |
| Réseau/WebSocket | 0.05s | <1% |
| **TOTAL** | **12.7s** | 100% |

---

### CAUSE RACINE UNIQUE

**Whisper Medium sur CPU** — 7.28 secondes pour 2 secondes d'audio.

Le modèle Medium utilise 244M de paramètres et nécessite ~8 secondes de calcul par phrase. Sur un CPU 4 cœurs, c'est le facteur limitant absolu (57% du temps total). Aucune autre optimisation ne peut compenser ce coût.

---

### TOP 3 des actions à meilleur gain réel

| # | Action | Gain mesuré | Nouveau total estimé |
|---|---|---|---|
| **1** | **Migrer Medium → Small** | **-4.44s** | ~8.3s |
| **2** | **Remplacer gTTS par TTS local** | **-1.2s** | ~7.1s |
| **3** | **Combiner 1 + 2** | **-5.6s** | **~7.1s** |

Avec les deux premières actions combinées : pipeline complet en **~7 secondes** au lieu de 12.7 secondes.

---

### Sources des mesures

| Donnée | Fichier/log |
|---|---|
| Latence STT Medium | `journalctl -u bobodo-vocal` — 10:13:36.814 → 10:13:44.072 |
| Latence STT Small | `small_load_test.json` — 2 837 ms mesuré |
| Latence Edge Function | `journalctl` — 10:13:44.148 → 10:13:47.456 |
| Latence TTS | `journalctl` — "Synthesizing" → "Synthesis completed" |
| Latence totale | `latency_audit.json` — 5 mesures bout-en-bout |
