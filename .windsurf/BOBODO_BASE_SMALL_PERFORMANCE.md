# BOBODO_BASE_SMALL_PERFORMANCE

## Mission 2 — Mesures de performance Base et Small

---

### Serveur

| | |
|---|---|
| **Serveur** | Kamatera 185.167.97.144 |
| **CPU** | Intel Xeon SapphireRapids, 4 cœurs @ 2.0GHz |
| **RAM totale** | 9 970 MB |
| **OS** | Ubuntu 22.04 LTS |

---

### Tableau comparatif — Performance

| Métrique | Tiny | Base | Small | Medium |
|---|---|---|---|---|
| **Temps chargement** | 1 006 ms | **2 841 ms** | **3 629 ms** | 3 861 ms |
| **RAM au chargement** | 227 MB | **306 MB** | **959 MB** | 2 551 MB |
| **Temps moyen / expression** | 818 ms | **1 318 ms** | **2 730 ms** | 7 696 ms |
| **Temps min / expression** | 657 ms | **899 ms** | **2 473 ms** | 7 315 ms |
| **Temps max / expression** | 737 ms | **8 325 ms** | **3 123 ms** | 8 008 ms |
| **RAM moyenne en cours** | 227 MB | **434 MB** | **1 102 MB** | 2 551 MB |
| **RAM max en cours** | 236 MB | **497 MB** | **1 102 MB** | 2 826 MB |
| **CPU moyen** | 261% | **282%** | **302%** | 303% |
| **Taille modèle** | ~39 MB | ~74 MB | ~244 MB | ~1.5 GB |

*Tiny et Medium provennent du benchmark précédent (5 phrases et concurrence).*

---

### Latence — Détail Base

| Percentile | Temps (ms) |
|---|---|
| p50 (médiane) | ~1 030 |
| p75 | ~1 100 |
| p90 | ~1 200 |
| p95 | ~1 300 |
| p99 | ~1 500 |
| Max | 8 325 (outlier, expression #60 "Koudougou") |

**Remarque :** Le max de 8 325 ms est un outlier sur l'expression #60 "Koudougou" qui a demandé un traitement anormalement long. Sans cet outlier, max ≈ 1 500 ms.

### Latence — Détail Small

| Percentile | Temps (ms) |
|---|---|
| p50 (médiane) | ~2 700 |
| p75 | ~2 800 |
| p90 | ~2 900 |
| p95 | ~3 000 |
| p99 | ~3 050 |
| Max | 3 123 |

**Observation :** Small est très stable (écart-type ~150 ms), sans outlier. Chaque transcription prend systématiquement 2.5–3.1s.

---

### RAM — Profil d'utilisation

```
Modèle    Chargement  Peak usage  Marge système
Tiny      227 MB      236 MB      ~9 700 MB
Base      306 MB      497 MB      ~9 500 MB
Small     959 MB      1 102 MB    ~8 900 MB
Medium    2 551 MB    2 826 MB    ~7 100 MB
```

**Capacité théorique (RAM seule) :**
- Tiny : ~40 users simultanés
- Base : ~20 users simultanés
- Small : ~9 users simultanés
- Medium : ~3 users simultanés

---

### CPU — Profil

| Modèle | CPU moyen | Cœurs utilisés | Saturation ? |
|---|---|---|---|
| Tiny | 261% | 2–3 | Non |
| Base | 282% | 2–3 | Non |
| Small | 302% | 2–3 | Non |
| Medium | 303% | 2–3 | Non |

**Découverte :** Le CPU n'est pas le facteur limitant pour aucun modèle. CTranslate2 utilise toujours 2–3 cœurs sur les 4 disponibles. La latence dépend de la taille du modèle et de la complexité du calcul, pas du nombre de cœurs.

---

### Ratio qualité / latence

| Modèle | Latence (ms) | WER (%) | Ratio WER/Latence (WER/s) | Effort par point de qualité |
|---|---|---|---|---|
| Tiny | 818 | 110.5 | 135.1 | — |
| Base | 1 318 | 87.7 | 66.5 | +500ms → -22.8 pts WER |
| Small | 2 730 | 44.1 | 16.2 | +1 412ms → -43.6 pts WER |
| Medium | 7 696 | ~5* | 0.65 | +4 966ms → -39.1 pts WER |

*WER Medium estimé sur phrases complètes (~5%), non mesuré sur corpus Academia car trop long.

**Observation :** Chaque palier de modèle double approximativement la latence et réduit le WER de ~40–50%. Le **retour sur investissement décroît** : Tiny→Base = +60% latence pour -23% WER ; Base→Small = +107% latence pour -44% WER.
