# BOBODO_STT_LATENCY_ASSUMPTIONS

## Mission 1 — Validation des estimations de latence du Master Plan

---

### Date
2026-06-13

---

### Question

Le Master Plan affirme :

| Modèle | Latence estimée | Source dans le plan |
|---|---|---|
| Tiny | ~1.5 s | "Passage tiny + beam_size=1 + silence 300ms" |
| Base | ~2 s | Tableau latences estimées |
| Small | ~3-4 s | Tableau latences estimées |
| Medium | ~8-10 s | Mesures réelles |

**D'où proviennent ces chiffres ?**

---

### Mesures réelles disponibles

**Seul modèle testé sur Kamatera : MEDIUM**

| Audio | Latence mesurée | Source |
|---|---|---|
| 1.39s | 7 789 ms | `audit_missions_server.py` — profiler direct |
| 2.95s | 7 542 ms | `audit_missions_server.py` — profiler direct |
| 4.99s | 8 320 ms | `audit_missions_server.py` — profiler direct |
| 4.99s | 9 128 ms | `BOBODO_STT_LATENCY_BREAKDOWN.md` — via service WS |

**Modèle confirmé :** medium (1.5 GB) (`BOBODO_STT_REAL_MODEL.md`)

**Environnement confirmé :** CPU Intel Xeon 4 cœurs @ 2.0GHz, 10 GB RAM (`BOBODO_STT_RESOURCE_USAGE.md`)

---

### Modèles NON testés sur Kamatera

| Modèle | Mesuré sur Kamatera ? | Preuve |
|---|---|---|
| **tiny** | **NON** | Aucun test exécuté |
| **base** | **NON** | Aucun test exécuté |
| **small** | **NON** | Aucun test exécuté |
| **medium** | **OUI** | 4 mesures réelles |

---

### Origine des estimations tiny/base/small

Les valeurs du Master Plan pour tiny/base/small proviennent de :

1. **Benchmarks communautaires Faster Whisper** (GitHub, documentation)
2. **Rapport taille/complexité :**
   - tiny = 39 MB, 4 couches encoder, 384 dims
   - base = 74 MB, 6 couches, 512 dims
   - small = 244 MB, 12 couches, 768 dims
   - medium = 1.5 GB, 32 couches, 512 dims
3. **Règle empirique :** latence CPU ∝ nombre de couches × dimensions
4. **Comparaison relative au seul point mesuré (medium = 8.3s)**

---

### Calcul théorique des estimations

```
Medium (32 couches, 512 dims) = 8.3s mesuré
Tiny (4 couches, 384 dims)   = 8.3s × (4/32) × (384/512) ≈ 8.3s × 0.125 × 0.75 ≈ 0.78s
                                        + overhead fixe CTranslate2 ≈ +0.7s
                                        ≈ 1.5s (estimation Master Plan)
```

**C'est une ESTIMATION THÉORIQUE.** Aucune mesure n'a été faite.

---

### Réponse à la question

| Modèle | Type de valeur | Preuve |
|---|---|---|
| **tiny ≈ 1.5s** | **B. Estimation théorique** | Aucun test exécuté. Déduit par proportionnalité depuis medium. |
| **base ≈ 2s** | **B. Estimation théorique** | Aucun test exécuté. Déduit par proportionnalité depuis medium. |
| **small ≈ 3-4s** | **B. Estimation théorique** | Aucun test exécuté. Déduit par proportionnalité depuis medium. |
| **medium ≈ 8-10s** | **A. Mesure réelle sur Kamatera** | 4 mesures indépendantes confirmées. |

---

### Incertitude des estimations

| Modèle | Valeur estimée | Plage réaliste possible | Incertitude |
|---|---|---|---|
| tiny | 1.5 s | **0.8 s — 3.0 s** | **±100%** |
| base | 2.0 s | **1.2 s — 4.0 s** | **±100%** |
| small | 3.5 s | **2.5 s — 6.0 s** | **±70%** |
| medium | 8.3 s | 8.0 s — 9.5 s | ±15% (mesuré) |

**Facteurs d'incertitude :**
- Overhead fixe CTranslate2 (warm-up) peut représenter 50-70% du temps tiny
- La qualité du CPU (AVX2, AVX-512) affecte massivement les petits modèles
- Le français peut être plus lent que l'anglais (tokenization plus longue)
- `beam_size=1` vs `beam_size=5` : gain réel inconnu sans test

---

### Conclusion

**Seule la latence du modèle medium est prouvée par des mesures réelles sur Kamatera.**

Les latences tiny, base et small sont des **estimations théoriques** déduites par proportionnalité. Elles sont **plausibles** mais **non vérifiées**. Avant de prendre une décision basée sur ces chiffres, il est impératif de :

1. Télécharger le modèle tiny sur Kamatera
2. Mesurer 3 transcriptions de durées différentes
3. Comparer avec les estimations

**Sans ces mesures, le gain de 6.8x annoncé pour tiny est spéculatif.**
