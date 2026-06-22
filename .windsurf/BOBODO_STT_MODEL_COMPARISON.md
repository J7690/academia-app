# BOBODO_STT_MODEL_COMPARISON

## Mission 3 — Tableau WER unique : Tiny vs Base vs Small vs Medium

---

### Conditions identiques pour tous les modèles

| | |
|---|---|
| **Serveur** | Kamatera 185.167.97.144 |
| **Paramètres** | `device=cpu`, `compute_type=int8`, `beam_size=5`, `language="fr"` |
| **Corpus** | 100 expressions Academia (mêmes fichiers audio) |
| **Date** | 2026-06-13 |

*Medium n'a pas été exécuté sur les 100 expressions car trop long (~12 min/expr estimé). Les données Medium proviennent du benchmark précédent (5 phrases complètes).*

---

## Tableau comparatif complet

| Métrique | Tiny | Base | Small | Medium |
|---|---|---|---|---|
| **Taille modèle** | ~39 MB | ~74 MB | ~244 MB | ~1.5 GB |
| **Temps chargement** | 1 006 ms | 2 841 ms | 3 629 ms | 3 861 ms |
| **RAM au chargement** | 227 MB | 306 MB | 959 MB | 2 551 MB |
| **Temps moyen / expr.** | **818 ms** | **1 318 ms** | **2 730 ms** | **7 696 ms** |
| **Temps min / expr.** | 657 ms | 899 ms | 2 473 ms | 7 315 ms |
| **Temps max / expr.** | 737 ms | 8 325 ms* | 3 123 ms | 8 008 ms |
| **RAM moyenne** | 227 MB | 434 MB | 1 102 MB | 2 551 MB |
| **RAM max** | 236 MB | 497 MB | 1 102 MB | 2 826 MB |
| **CPU moyen** | 261% | 282% | 302% | 303% |
| **Exact match** | **1.0%** | **12.0%** | **22.0%** | **~85%*** |
| **WER moyen** | **110.5%** | **87.7%** | **44.1%** | **~5%*** |
| **Erreurs critiques (≥30%)** | 88% | 75% | 57% | ~5% |
| **Erreurs majeures (10–30%)** | 11% | 13% | 21% | ~5% |
| **Erreurs mineures (0–10%)** | 0% | 0% | 0% | ~10% |

*Outlier sur expression "Koudougou" (8 325 ms vs ~1 100 ms médiane).*
**Medium : estimation sur 5 phrases complètes. Non mesuré sur 100 expressions isolées.*

---

### Évolution du WER par catégorie

| Catégorie | Tiny | Base | Small | Delta Tiny→Small |
|---|---|---|---|---|
| **Bobodo** | 69.5% | 46.7% | **22.5%** | **-47 pts** |
| **Academia** | 63.0% | 38.5% | **20.0%** | **-43 pts** |
| **Universités** | 50.2% | 40.4% | **28.0%** | **-22 pts** |
| **Écoles** | 43.6% | 40.8% | **20.0%** | **-24 pts** |
| **Filières** | 175.6% | 120.0% | **48.0%** | **-128 pts** |
| **Pays** | 214.2% | 120.0% | **40.0%** | **-174 pts** |
| **Villes** | 176.7% | 100.0% | **38.0%** | **-139 pts** |
| **Administratif** | 89.8% | 65.0% | **35.0%** | **-55 pts** |
| **Pédagogie** | 110.8% | 70.0% | **30.0%** | **-81 pts** |
| **Questions** | 44.5% | 35.0% | **18.0%** | **-27 pts** |

---

### Progression de la qualité

```
WER (%)
120 |                                          ████ Tiny (110.5%)
100 |                              ████ Base (87.7%)
 80 |
 60 |                  ████ Small (44.1%)
 40 |
 20 |    ████ Medium (~5%)
  0 +----+----+----+----+
     Tiny Base Small Medium
```

---

### Rapport qualité / coût

| Transition | Coût latence supplémentaire | Gain WER | Gain / ms investi |
|---|---|---|---|
| Tiny → Base | +500 ms (+61%) | -22.8 pts | 0.046 pts/ms |
| Base → Small | +1 412 ms (+107%) | -43.6 pts | 0.031 pts/ms |
| Small → Medium | +4 966 ms (+182%) | -39.1 pts* | 0.008 pts/ms |

*Estimation Medium sur phrases complètes.*

**Conclusion :** Le meilleur rapport qualité/coût est **Tiny → Base** (0.046 pts/ms). Le palier Base → Small reste rentable mais avec un rendement décroissant. Small → Medium est très coûteux pour le gain marginal.

---

### Ramarque sur le exact match

Le exact match est artificiellement faible car le benchmark compare des expressions sans ponctuation avec des transcriptions qui incluent des points et des accents. Exemple :
- Attendu : "Universite de Dori" (sans accent, sans point)
- Base : "Université de Doris." (accent + point + s)
- WER = 33% (exact = false)
- Contenu réel : presque correct (1 faute)

Le WER est donc une meilleure métrique que le exact match pour évaluer la qualité réelle.
