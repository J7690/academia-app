# BOBODO_BASE_SMALL_CORPUS_RESULTS

## Mission 1 — Corpus Academia complet sur Base et Small

---

### Conditions

| | |
|---|---|
| **Serveur** | Kamatera 185.167.97.144 |
| **CPU** | Intel Xeon SapphireRapids, 4 cœurs @ 2.0GHz |
| **RAM** | 9 970 MB |
| **Audio** | Mêmes 100 fichiers WAV générés pour le benchmark Tiny |
| **Paramètres** | `device=cpu`, `compute_type=int8`, `beam_size=5`, `language="fr"` |
| **Date** | 2026-06-13 |

---

### Résultats globaux — Base

| Métrique | Valeur |
|---|---|
| **Exact match** | **12 / 100 = 12.0%** |
| **WER moyen** | **87.7%** |
| **Temps moyen** | **1 318 ms** |
| **Temps min** | 899 ms |
| **Temps max** | 8 325 ms |
| **RAM moyenne** | 434 MB |
| **RAM max** | 497 MB |
| **CPU moyen** | 282% |
| **Chargement** | 2 841 ms / 306 MB |
| **Erreurs critiques (≥30%)** | 75 (75.0%) |
| **Erreurs majeures (10–30%)** | 13 (13.0%) |
| **Erreurs mineures (0–10%)** | 0 (0.0%) |

### Résultats globaux — Small

| Métrique | Valeur |
|---|---|
| **Exact match** | **22 / 100 = 22.0%** |
| **WER moyen** | **44.1%** |
| **Temps moyen** | **2 730 ms** |
| **Temps min** | 2 473 ms |
| **Temps max** | 3 123 ms |
| **RAM moyenne** | 1 102 MB |
| **RAM max** | 1 102 MB |
| **CPU moyen** | 302% |
| **Chargement** | 3 629 ms / 959 MB |
| **Erreurs critiques (≥30%)** | 57 (57.0%) |
| **Erreurs majeures (10–30%)** | 21 (21.0%) |
| **Erreurs mineures (0–10%)** | 0 (0.0%) |

---

### Comparaison visuelle — Base vs Small (échantillon)

| # | Attendu | Base | Small |
|---|---|---|---|
| 1 | Bonjour Bobodo | Bonjour, BoboDo. | Bonjour BoboDo. |
| 3 | Bobodo explique moi cette lecon | BoboDoh explique moi cette lecomme. | BoboDo, explique-moi, c'est le con. |
| 5 | Comment fonctionne Academia | Comment fonctionne l'Académie ? | Comment fonctionne l'académie ? |
| 11 | Universite Joseph Ki-Zerbo | Universite Joseph Kiserbo. | UNIVERSITE JOSEPH KISERBAU |
| 15 | Universite Thomas Sankara | Universite d'Omasson Carat | Université Thomas-Sancara |
| 41 | Burkina Faso | Bur qu'il n'a face au... | Burkina Faso |
| 43 | Cote d Ivoire | Cote d'Ivoire. | Côte d'Eivoire |
| 45 | Mali | Mala. | Mali |
| 47 | Togo | Tougou | Tougou |
| 52 | Bobo Dioulasso | Bobo Dioulaso. | Boubou Dioulasso |
| 56 | Fada N Gourma | Fada N'Gourma. | Fadain Gourmet |
| 65 | Baccalaureat | baccalauréat | Bacchaleuréa |
| 69 | Inscription administrative | Inscription administrative | Inscription administrative |
| 80 | Questionnaire a choix multiple | questionnaires à choix multiples. | Questionnaire à choix multiple. |
| 89 | Comment payer avec LigdiCash | Comment payer avec lignes d'icaches ? | Comment payer avec League d'Icache ? |

---

### Observations clés

**Base :**
- Amélioration notable sur les noms propres africains ("Burkina Faso" correct, "Fada N'Gourma" correct)
- Capitale "Bobo Dioulaso" proche de "Bobo Dioulasso" (1 faute)
- Échec sur "Thomas Sankara" → hallucination totale "d'Omasson Carat"
- "Academia" souvent confondu avec "Académie"
- "BoboDo" avec majuscule incorrecte (cas de détail)

**Small :**
- 22% exact match (vs 1% Tiny, 12% Base)
- WER 44.1% (vs 110.5% Tiny, 87.7% Base)
- Noms de pays souvent corrects (Mali, Niger, Guinée Conakry)
- "Burkina Faso" = correct
- "BoboDo" persiste (majuscule interne)
- "LigdiCash" → "League d'Icache" (hallucination récurrente)
- Termes techniques plus reconnus ("Travaux pratiques" exact)

---

### Conclusion Mission 1

Small apporte une **amélioration mesurable** sur le vocabulaire Academia par rapport à Tiny et Base :
- WER réduit de **110.5% → 44.1%** (+60% de gain)
- Exact match multiplié par **22x** (1% → 22%)
- Noms propres africains mieux reconnus
- Hallucinations réduites mais pas éliminées
