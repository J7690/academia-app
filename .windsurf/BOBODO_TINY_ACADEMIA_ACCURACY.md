# BOBODO_TINY_ACADEMIA_ACCURACY

## Mission 2 — Transcription des 100 expressions du corpus Academia par Tiny

---

### Conditions

| | |
|---|---|
| **Serveur** | Kamatera 185.167.97.144 |
| **Modèle** | Whisper Tiny (faster-whisper) |
| **Paramètres** | `device=cpu`, `compute_type=int8`, `beam_size=5`, `language=fr` |
| **Audio** | gTTS français → WAV 16kHz mono |
| **Date** | 2026-06-13 |

---

### Résultats globaux

| Métrique | Valeur |
|---|---|
| **Total expressions** | 100 |
| **Transcriptions exactes** | **1 / 100 = 1.0%** |
| **WER moyen** | **110.5%** |
| **Temps moyen / expression** | 818 ms |
| **Temps total** | 82 secondes |

---

### Classification des erreurs (RAW — avant correction)

| Classe | Définition | Count | % |
|---|---|---|---|
| **CRITIQUE** | WER ≥ 30% | 88 | **88.0%** |
| **MAJEURE** | 10% ≤ WER < 30% | 11 | **11.0%** |
| **MINEURE** | 0% < WER < 10% | 0 | 0.0% |
| **PARFAITE** | WER = 0% | 1 | 1.0% |

---

### WER par catégorie

| Catégorie | n | WER moyen | Pire expression |
|---|---|---|---|
| **Pays** | 10 | **214.2%** | Niger → "n'y j'ai rien." (500%) |
| **Filières** | 15 | **175.6%** | Sciences pharmaceutiques → "Si on se ferme à ce tic." (350%) |
| **Villes** | 10 | **176.7%** | Gaoua → "Gène-moi !" (300%) |
| **Pédagogie** | 10 | **110.8%** | Questionnaire → "Qu'est-ce qu'il y a une erre à chaud à multiples ?" (325%) |
| **Administratif** | 15 | **89.8%** | Baccalauréat → "Becqu'elle aurait a." (400%) |
| **Bobodo** | 6 | **69.5%** | Bobodo explique → "Beaucoup d'où expliquent moi cette lecomme." (100%) |
| **Academia** | 4 | **63.0%** | Comment fonctionne → "comme on fonctionne académia." (100%) |
| **Questions** | 15 | **44.5%** | Comment payer avec LigdiCash → "Comment payer avec l'île d'icache ?" (125%) |
| **Universités** | 9 | **50.2%** | Thomas Sankara → "d'Omasson Carat" (100%) |
| **Écoles** | 6 | **43.6%** | ENS Koudougou → "et que le normal supérieur de Coudougou." (120%) |

---

### Échantillon d'erreurs par classe

#### CRITIQUE (WER ≥ 30%)

| # | Attendu | Obtenu | WER |
|---|---|---|---|
| 28 | Sciences pharmaceutiques | Si on se ferme à ce tic. | **350%** |
| 41 | Burkina Faso | Bur qu'il n'a face au... | **350%** |
| 49 | Niger | n'y j'ai rien. | **500%** |
| 65 | Baccalaureat | Becqu'elle aurait a. | **400%** |
| 47 | Togo | D'où ? | **300%** |
| 29 | Genie civil | J'ai mis civils. | **200%** |
| 30 | Genie electrique | Je n'ai ni électrique. | **250%** |
| 31 | Genie informatique | J'ai ni un formatique. | **250%** |
| 80 | Questionnaire a choix multiple | Qu'est-ce qu'il y a une erre à chaud à multiples ? | **325%** |
| 20 | Ecole Normale Superieure de Koudougou | et que le normal supérieur de Coudougou. | **120%** |
| 15 | Universite Thomas Sankara | Université d'Omasson Carat | **100%** |
| 3 | Bobodo explique moi cette lecon | Beaucoup d'où expliquent moi cette lecomme. | **100%** |

#### MAJEURE (10–30%)

| # | Attendu | Obtenu | WER |
|---|---|---|---|
| 6 | Je suis sur Academia depuis deux mois | Je suis sur académia depuis de mois. | **28.6%** |
| 16 | Institut National des Sciences et Techniques | Institut national des sciences et techniques. | **16.7%** |
| 18 | Institut Superieur des Sciences de la Sante | Institut supérieur des sciences de la Sente. | **14.3%** |
| 19 | Centre Universitaire de Kaya | Centre universitaire de Caïa. | **25.0%** |

---

### Analyse des patterns d'erreur

| Pattern | Fréquence | Exemple |
|---|---|---|
| **Hallucination totale** | ~45% | "Togo" → "D'où ?" |
| **Substitution phonétique** | ~30% | "Genie" → "J'ai ni" |
| **Noms propres déformés** | ~15% | "Bobodo" → "Bobudon", "Bobo Do", "Bobo Daud" |
| **Mots collés/séparés** | ~8% | "superplate forme", "courants lignes" |
| **Ponctuation différente** | ~2% | Point final ajouté |

**Conclusion Mission 2 :** Tiny est **catastrophique** sur des expressions courtes et isolées. Le WER de 110% indique que le modèle ajoute et supprime plus de mots qu'il ne conserve. Ce phénomène est amplifié par l'absence de contexte grammatical dans des expressions de 2–4 mots.
