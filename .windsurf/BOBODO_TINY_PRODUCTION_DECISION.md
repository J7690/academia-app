# BOBODO_TINY_PRODUCTION_DECISION

## Mission 6 — Validation finale : Tiny + dictionnaire est-il suffisant pour la production ?

---

## 1. Qualité réelle Tiny (phrases complètes vs expressions isolées)

### Contexte critique

Tiny a été testé dans **deux conditions différentes** :

| Condition | Nombre | Type | WER moyen | Verdict |
|---|---|---|---|---|
| **Phrases complètes** | 5 phrases (8–12 mots) | Dialogue naturel étudiant | **~15%** | Acceptable |
| **Expressions isolées** | 100 expressions (2–8 mots) | Vocabulaire Academia pur | **110.5%** | Catastrophique |

**Explication :** Whisper est entraîné sur des phrases grammaticalement complètes. Des expressions isolées sans contexte (ex: "Togo", "Ghana", "Genie civil") sont ambiguës pour le modèle, qui préfère halluciner des mots courants plutôt que reconnaître des noms propres rares.

**Impact :** Dans le vrai usage Bobodo, les étudiants parlent en **phrases complètes** (ex: "Comment postuler sur Academia ?"). Le WER de 15% mesuré sur phrases complètes est donc plus représentatif de l'usage réel que le WER de 110% sur expressions isolées.

---

## 2. Qualité Tiny + correction (dictionnaire)

### Résultats du dictionnaire amélioré

| Métrique | Tiny brut | Tiny + dict | Delta |
|---|---|---|---|
| Exact match | 1.0% | **10.0%** | **+9 pts** |
| WER moyen (100 expr.) | 110.5% | **41.5%** | **-69 pts** |
| Erreurs critiques | 88% | **59%** | **-29 expr.** |

### Ce que le dictionnaire corrige bien

| Type | Exemple | Taux de succès |
|---|---|---|
| Noms propres déformés | Bobodo → Bobo Do / Bobudon / Beboudou | **~80%** |
| Fusions/séparations | superplate forme → super plateforme | **~90%** |
| Substitutions phonétiques | Josef Kiserbo → Joseph Ki-Zerbo | **~70%** |
| Termes techniques | l'île d'icache → LigdiCash | **~60%** |

### Ce que le dictionnaire ne PEUT PAS corriger

| Type | Exemple | Cause |
|---|---|---|
| **Hallucination totale** | "Togo" → "D'où ?" | Le modèle invente une phrase entière |
| **Substitution croisée** | "Droit privé" → "Togo a pris-le ?" | Le regex "D'où" matche aussi sur d'autres mots |
| **Contexte manquant** | "Niger" → "n'y j'ai rien" | Aucun pattern prédictible |
| **Invention sémantique** | "Sciences pharmaceutiques" → "Si on se ferme à ce tic" | Aucun lien phonétique ou orthographique |

---

## 3. Taux d'erreur résiduel

### Après dictionnaire, sur corpus de 100 expressions

| | Count | % du total |
|---|---|---|
| **Parfait** | 10 | 10% |
| **Mineur** (ponctuation/accent seul) | ~15 | ~15% |
| **Majeur** (1–2 mots incorrects) | ~14 | ~14% |
| **Critique** (hallucination ou >30% WER) | **~59** | **~59%** |

**Mais attention :** Sur les ~59 erreurs "critiques", environ :
- **25** sont des différences de ponctuation/accentuation seules (WER artificiellement gonflé)
- **20** sont des erreurs réelles de 1–2 mots dans un contexte partiellement correct
- **~15** sont des hallucinations totales irrécupérables

**Taux d'erreur réel de contenu** (hors ponctuation/accent) : environ **35–40%** sur expressions isolées.

**Taux d'erreur extrapolé sur phrases complètes** (basé sur le benchmark 5 phrases + patterns observés) : environ **15–20%** avec dictionnaire.

---

## 4. Impact utilisateur

### Scénario réel — Étudiant parlant à Bobodo

**Phrase type :** "Bonjour Bobodo, comment postuler sur Academia ?"

| Étape | Risque | Impact |
|---|---|---|
| 1. Transcription Tiny | "Bonjour Bobo Do, comment postuler sur académia ?" | Faible — le dictionnaire corrige |
| 2. Correction | "Bonjour Bobodo, comment postuler sur Academia ?" | OK |
| 3. Traitement LLM | Le LLM comprend la question | OK |

**Phrase type :** "Quelle est la capitale du Ghana ?"

| Étape | Risque | Impact |
|---|---|---|
| 1. Transcription Tiny | "Quelle est la capitale du Genre ?" | **Modéré** — "Genre" n'est pas corrigé |
| 2. LLM | Le LLM ne comprend pas la question | **Échec de la requête** |

**Phrase type :** "Explique la photosynthèse en termes simples"

| Étape | Risque | Impact |
|---|---|---|
| 1. Transcription Tiny | "explique la photo synthèse en termes simples" | Faible — récupérable |
| 2. LLM | Le LLM comprend malgré l'espace | OK |

### Synthèse impact

| Type de requête | Fréquence estimée | Impact erreur | Severité |
|---|---|---|---|
| Questions générales (6+ mots) | ~60% | Faible | 🟢 |
| Questions avec nom propre | ~25% | **Modéré** | 🟡 |
| Mots isolés / courts (2–3 mots) | ~10% | **Critique** | 🔴 |
| Termes techniques rares | ~5% | **Critique** | 🔴 |

---

## 5. Recommandation finale

### Réponse : **NON** — Tiny + dictionnaire n'est PAS suffisant pour la production Academia en l'état.

### Arguments décisifs

| # | Argument | Preuve |
|---|---|---|
| 1 | **Hallucinations irrécupérables** | 15/100 expressions produisent des hallucinations totales ("Togo" → "D'où ?", "Niger" → "n'y j'ai rien") |
| 2 | **Taux d'erreur réel trop élevé** | Même avec dictionnaire, ~35–40% d'erreurs de contenu sur vocabulaire isolé |
| 3 | **Dictionnaire = rustine** | Le dictionnaire corrige les symptômes, pas la cause. Chaque nouveau nom propre nécessite une nouvelle entrée |
| 4 | **Expérience utilisateur** | Un étudiant qui demande "Quelle est la capitale du Ghana ?" et entend "Genre ?" perd confiance immédiatement |
| 5 | **Maintenance impossible** | Le dictionnaire doit couvrir toutes les universités, villes, filières, termes administratifs — liste sans fin |

### Conditions sous lesquelles Tiny DEVIENDRAIT acceptable

| Condition | Description | Priorité |
|---|---|---|
| **1. Tester Base ou Small** | Base (~2-3s, 74MB) ou Small (~4-5s, 244MB) pourrait avoir 3-5x moins d'erreurs sur noms propres | **CRITIQUE** |
| **2. Phrases minimales** | Forcer l'utilisateur à parler en phrases de 6+ mots (pas de mots isolés) | IMPORTANT |
| **3. Dictionnaire élargi** | Couvrir les 200+ noms propres du système (universités, villes, filières) | IMPORTANT |
| **4. Fallback cloud** | Si confiance Whisper < 0.7, envoyer vers STT cloud (Deepgram, AssemblyAI) | IMPORTANT |
| **5. Session isolation** | Corriger l'architecture multi-session AVANT tout changement de modèle | **CRITIQUE** |

### Alternative recommandée

| Option | Latence estimée | Qualité estimée | RAM | Verdict |
|---|---|---|---|---|
| **Tiny actuel** | 699 ms | WER 15–40% | 227 MB | ❌ Inacceptable |
| **Base** | ~1.5–2.5s | WER 8–15% | ~500 MB | ⚠️ À tester |
| **Small** | ~3–5s | WER 3–8% | ~1.1 GB | ⚠️ À tester |
| **Cloud STT** | ~500–800ms | WER <3% | ~0 MB | ✅ Meilleure qualité, coût mensuel |

### Roadmap recommandée

1. **Immédiat** : Ne PAS déployer Tiny en production
2. **Semaine 1** : Tester Base sur le même corpus de 100 expressions
3. **Semaine 2** : Tester Small si Base est insuffisant
4. **Semaine 3** : Comparer coût/bénéfice vs Cloud STT (Deepgram)
5. **Décision** : Choisir entre Small (auto-hébergé) ou Cloud (API externe)

---

## Réponses aux 5 questions du livrable final

| # | Question | Réponse |
|---|---|---|
| 1 | **Qualité réelle Tiny** | Sur phrases complètes : ~15% WER (acceptable). Sur vocabulaire isolé : 110.5% WER (catastrophique). |
| 2 | **Qualité Tiny + correction** | WER réduit de 110.5% à 41.5% sur expressions isolées. Sur phrases complètes : estimé 15–20% WER. Amélioration réelle mais insuffisante. |
| 3 | **Taux d'erreur résiduel** | ~35–40% d'erreurs de contenu réelles sur vocabulaire isolé. ~15–20% sur phrases complètes. 15 hallucinations totales irrécupérables sur 100. |
| 4 | **Impact utilisateur** | Faible pour questions générales (60% des cas). Modéré à critique pour noms propres (35% des cas). Risque de perte de confiance sur erreurs flagrantes. |
| 5 | **Recommandation finale** | **NON.** Tiny + dictionnaire n'est pas suffisant. Tester Base ou Small avant décision. Évaluer Cloud STT comme alternative. |
