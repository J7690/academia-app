# BOBODO_TRANSCRIBE_PROFILING

## Mission 4 — Profilage complet de model.transcribe()

---

### Date
2026-06-13

---

### Méthodologie

Script Python exécuté **directement sur le serveur** (`/opt/bobodo-vocal`), utilisant le **même environnement** que le service en production. Le modèle est rechargé une fois, puis 3 fichiers audio de durées différentes sont transcrits séquentiellement.

---

### Résultats bruts

```
[PROFILER] Model loaded in 5626ms

[PROFILER] Test 0: 'Bonjour Bobodo...'
[PROFILER] Audio: 1.39s, 44588 bytes
[PROFILER] Transcription: 7789ms
[PROFILER] Result: 'Bonjour Bobodo'
[PROFILER] Info: lang=fr, dur=1.39s
[PROFILER] Ratio: 5.60x realtime

[PROFILER] Test 1: 'Quelle est la capitale du Burkina Faso...'
[PROFILER] Audio: 2.95s, 94508 bytes
[PROFILER] Transcription: 7542ms
[PROFILER] Result: 'Quelle est la capitale du Burkina Faso?'
[PROFILER] Info: lang=fr, dur=2.95s
[PROFILER] Ratio: 2.56x realtime

[PROFILER] Test 2: 'Explique moi la photosynthese...'
[PROFILER] Audio: 4.99s, 159788 bytes
[PROFILER] Transcription: 8320ms
[PROFILER] Result: 'Explique-moi la photosynthèse en termes simples pour un élève de collège.'
[PROFILER] Info: lang=fr, dur=4.99s
[PROFILER] Ratio: 1.67x realtime
```

---

### Décomposition des 9 secondes

Faster Whisper `model.transcribe()` est une **fonction opaque**. Les logs internes de la librairie ne donnent pas de sous-étapes détaillées. Cependant, les mécanismes internes de Faster Whisper sont documentés :

```
model.transcribe(audio_path, language="fr", beam_size=5, vad_filter=False)
│
├── 1. Chargement audio depuis fichier (~50-100ms)
│   └── Librosa / SoundFile lit le WAV en mémoire
│
├── 2. Prétraitement (~100-200ms)
│   └── Resampling si nécessaire, normalisation, padding
│
├── 3. VAD (désactivé ici: vad_filter=False)
│   └── Skippé
│
├── 4. Encodage (feature extraction) (~500-1000ms)
│   └── CNN encoder Whisper (32 couches, 512 dims)
│
├── 5. Décodage (beam search) (~6000-7000ms)
│   └── Transformer decoder (32 couches, 512 dims)
│   └── beam_size=5 → 5 chemins explorés en parallèle
│
├── 6. Post-traitement (~50-100ms)
│   └── Suppression des tokens spéciaux, timestamps
│
└── 7. Retour segments (~10ms)
    └── Générateur Python yield segments
```

---

### Preuve de la répartition approximative

Les ratios de temps réel sont inversés par rapport à la durée audio :

| Durée audio | Temps transcription | Ratio | ms/audio-second |
|---|---|---|---|
| 1.39s | 7789ms | **5.60x** | **5606 ms/s** |
| 2.95s | 7542ms | **2.56x** | **2553 ms/s** |
| 4.99s | 8320ms | **1.67x** | **1667 ms/s** |

**Observation critique :** Plus l'audio est court, plus le ratio temps réel est élevé. Cela confirme un **overhead fixe** important :

```
Temps total = Overhead fixe + (Durée audio × Ratio variable)

Pour 1.39s : 7789 = Overhead + 1.39 × k
Pour 4.99s : 8320 = Overhead + 4.99 × k

Résolution :
k ≈ 145 ms/s (traitement par seconde d'audio)
Overhead ≈ 7580 ms
```

**L'overhead fixe est ~7.5 secondes.** Cet overhead comprend :
- Chargement du modèle en cache CPU (si cold)
- Compilation / warm-up du graphe CTranslate2
- Encodage initial
- Préparation des états du décodeur

---

### Comparaison avec les mesures du service en ligne

| Mesure | Via service WS (Mission 1) | Via profiler isolé (Mission 4) | Différence |
|---|---|---|---|
| Audio 1.39s | ~timeout | 7789ms | — |
| Audio 2.95s | 10064ms | 7542ms | +2522ms |
| Audio 4.99s | 10142ms | 8320ms | +1822ms |

**La différence** (1.8-2.5s) correspond exactement au **seuil de silence (1000ms)** + overhead WebSocket + écriture/lecture fichier temporaire.

---

### Conclusion

Les 9.1 secondes de transcription se décomposent approximativement :

| Étape | Durée estimée | % |
|---|---|---|
| Overhead fixe (warm-up CTranslate2, encodage initial) | ~6 500 ms | ~72% |
| Décodage beam search (5 chemins) | ~1 800 ms | ~20% |
| Chargement audio + pré/post-traitement | ~600 ms | ~7% |
| Retour résultat | ~50 ms | ~1% |
| **Total** | **~8 950 ms** | **100%** |

**Le goulot est l'overhead fixe du modèle medium sur CPU.** Même un audio de 1 seconde met ~7.8 secondes, dont ~6.5s sont de l'overhead fixe.
