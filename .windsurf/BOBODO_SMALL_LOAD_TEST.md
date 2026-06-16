# BOBODO_SMALL_LOAD_TEST

## Mission 2 — Charge réelle avec Small

---

### Conditions

| | |
|---|---|
| **Serveur** | Kamatera 185.167.97.144 |
| **CPU** | Intel Xeon, 4 cœurs @ 2.0GHz |
| **RAM** | 9 970 MB |
| **Modèle testé** | Faster Whisper **Small** (standalone) |
| **Méthode** | Script isolé, pas le service de production |
| **Audio** | 20 fichiers WAV 16kHz mono, ~2s chacun |

*Le service de production actuel utilise Medium. Ce benchmark mesure Small en standalone pour estimer la capacité si on basculeait sur Small.*

---

### Résultats bruts

| Users | Total elapsed (ms) | Avg/transcription (ms) | Min (ms) | Max (ms) | Avg CPU % | Max CPU % | Avg RAM (MB) | Max RAM (MB) | Transcriptions |
|---|---|---|---|---|---|---|---|---|---|
| **1** | 56 751 | **2 837** | 2 610 | 3 091 | 301 | 306 | 680 | 680 | 20 |
| **2** | 56 105 | **5 574** | 4 734 | 5 946 | 305 | 315 | 687 | 687 | 20 |
| **3** | 50 109 | **8 230** | 6 746 | 8 561 | 306 | 317 | 693 | 694 | 18 |
| **5** | 55 070 | **13 429** | 11 097 | 14 095 | 307 | 321 | 706 | 706 | 20 |

---

### Analyse de latence

```
Users  Latence moyenne  Rapport vs 1 user
1      2 837 ms         1.0x
2      5 574 ms         1.96x ≈ 2x
3      8 230 ms         2.90x ≈ 3x
5      13 429 ms        4.73x ≈ 5x
```

**Découverte critique :** La latence est **strictement proportionnelle** au nombre d'utilisateurs. Small sur CPU ne parallélise pas les transcriptions — CTranslate2 les exécute **séquentiellement** même à travers `ThreadPoolExecutor`.

---

### Analyse CPU

| Users | Avg CPU % | Max CPU % | Cœurs utilisés | Saturation ? |
|---|---|---|---|---|
| 1 | 301% | 306% | 2–3 | Non |
| 2 | 305% | 315% | 2–3 | Non |
| 3 | 306% | 317% | 2–3 | Non |
| 5 | 307% | 321% | 2–3 | Non |

**Le CPU ne sature pas.** Il reste à ~300% (3 cœurs sur 4) quel que soit le nombre d'utilisateurs. CTranslate2 utilise toujours le même nombre de threads internes. Le goulot n'est pas le CPU, c'est le **modèle lui-même** (calcul séquentiel).

---

### Analyse RAM

| Users | RAM load (MB) | Peak RAM (MB) | RAM/user |
|---|---|---|---|
| 1 | 527 | 680 | 680 |
| 2 | 527 | 687 | 344 |
| 3 | 527 | 694 | 231 |
| 5 | 527 | 706 | 141 |

**Observation :** La RAM augmente très peu avec le nombre d'utilisateurs (+26 MB de 1 à 5 users). Le modèle Small occupe ~527 MB au chargement et ~680 MB en cours. Le reste est du buffer audio temporaire.

---

### Projection par utilisateur

| Users | Latence/user | Latence totale | Queue |
|---|---|---|---|
| 1 | 2.8s | 2.8s | Aucune |
| 2 | 5.6s | 5.6s | 1 user attend |
| 3 | 8.2s | 8.2s | 2 users attendent |
| 5 | 13.4s | 13.4s | 4 users attendent |

**Si un user envoie 3s d'audio :**
- Avec 1 user : réponse en ~2.8s
- Avec 2 users : le second attend ~2.8s → réponse en ~5.6s
- Avec 5 users : le dernier attend ~11.2s → réponse en ~14.0s

---

### Timeouts et erreurs

| Users | Timeouts | Erreurs | Transcriptions manquantes |
|---|---|---|---|
| 1 | 0 | 0 | 0 |
| 2 | 0 | 0 | 0 |
| 3 | 0 | 0 | 2* |
| 5 | 0 | 0 | 0 |

*3 users : 18 transcriptions sur 20 attendues. Le test a réparti 20 fichiers entre 3 users (6+7+7), ce qui explique 18. Aucune perte due à timeout ou erreur.*

---

### Conclusion Mission 2

| Métrique | Valeur |
|---|---|
| **Latence moyenne 1 user** | **2 837 ms** |
| **Latence moyenne 2 users** | **5 574 ms** |
| **Latence moyenne 3 users** | **8 230 ms** |
| **Latence moyenne 5 users** | **13 429 ms** |
| **RAM Small** | **527 MB** (load) / **706 MB** (peak 5 users) |
| **CPU max** | **321%** |
| **Timeout observés** | **0** |
| **Erreurs observées** | **0** |

**Le modèle Small est stable en standalone mais entièrement séquentiel.** Chaque user ajouté multiplie linéairement la latence. Il n'y a pas de parallélisme réel.
