# BOBODO_STT_MASTER_PLAN_VALIDATION

## Livrable Final — Validation du Master Plan de remédiation

---

### Date
2026-06-13

---

### Méthodologie

Validation strictement basée sur les faits démontrés :
- Mesures réelles sur Kamatera (4 transcriptions medium, 1 test de charge 5 users)
- Audits précédents (7 documents validés)
- Aucune estimation non justifiée acceptée

---

## 1. Ce plan est-il réaliste ?

**Réponse : OUI, avec réserves.**

| Partie du plan | Réaliste ? | Justification |
|---|---|---|
| Architecture multi-session | **OUI** | Pattern standard. Le refactor est technique mais faisable. |
| Latence STT ~1.5s avec tiny | **PLAUSIBLE, NON POUVÉ** | Aucune mesure tiny sur Kamatera. La proportionnalité suggère ~1-3s. |
| 50 users simultanés | **SPÉCULATIF** | Dépend de la latence tiny (non mesurée) et du pattern d'activité. |
| 10 jours Phase 1+2 | **OUI** | Les patches sont des changements ciblés, pas une refonte. |

**Le plan est réaliste dans son approche, mais certaines valeurs chiffrées sont des estimations.**

---

## 2. Quelles hypothèses sont prouvées ?

| Hypothèse | Preuve | Document |
|---|---|---|
| Latence medium = ~8.3s | 4 mesures réelles (7.8s, 7.5s, 8.3s, 9.1s) | `BOBODO_TRANSCRIBE_PROFILING.md` |
| Buffer global = mélange 100% | Test 5 users, transcription des 5 phrases mélangées | `BOBODO_SESSION_ISOLATION_TEST.md` |
| Callback écrasé = 1 seul user reçoit les résultats | 4/5 users timeout à 35s | `BOBODO_CONCURRENT_USERS_AUDIT.md` |
| RAM modèle = 1.9 GB | `/proc/PID/status` pendant transcription | `BOBODO_STT_RESOURCE_USAGE.md` |
| CPU sous-utilisé = 25-30% | `top` pendant transcription medium | `BOBODO_STT_RESOURCE_USAGE.md` |
| Serveur non saturé | Load max 0.66 (4 cœurs disponibles) | `BOBODO_LOAD_TEST_REAL.md` |
| CTranslate2 utilise plusieurs cœurs | Pic CPU = 317% pendant transcription | `BOBODO_LOAD_TEST_REAL.md` |
| RAM de travail recyclable | +943 MB pendant transcription, retour à 1972 MB après | `BOBODO_LOAD_TEST_REAL.md` |
| 100% timeout avec 5 users (actuel) | Test de charge 5 connexions simultanées | `BOBODO_LOAD_TEST_REAL.md` |
| Bug modèle : `.env` ignoré | `stt_service.py` ligne 22, `main.py` ligne 56 | `BOBODO_STT_REAL_MODEL.md` |

---

## 3. Quelles hypothèses sont encore théoriques ?

| Hypothèse | Pourquoi théorique | Incertitude |
|---|---|---|
| **Latence tiny = ~1.5s** | Aucun test exécuté sur Kamatera | **±100%** (plage 0.8s — 3.0s possible) |
| **Latence base = ~2s** | Aucun test exécuté | **±100%** |
| **Latence small = ~3.5s** | Aucun test exécuté | **±70%** |
| **50 users simultanés** | Maximum testé = 5 users (timeout 100%) | Inconnu. Dépend de la latence tiny. |
| **Gain beam_size=1 = 3-5x** | Non mesuré. Benchmarks communautaires uniquement. | **±50%** |
| **Gain silence 300ms = -700ms** | Calculé (1000-300=700), mais pas mesuré en condition réelle | **Faible** (-700ms est une certitude mathématique) |
| **Thread pool = 4 workers viable** | CTranslate2 thread-safety non vérifiée pour notre version | **Moyenne** |
| **Qualité tiny acceptable pour dialogue** | WER estimé ~18%, non testé sur corpus Academia | **Moyenne** |

---

## 4. Quelle phase doit être exécutée en premier ?

**La Phase 1 du plan minimal (3-4 jours).**

Ordre strict :

```
1. Corriger le bug modèle (1.6) — 30 min
   └─→ Permet de tester tiny

2. Tester tiny sur Kamatera — 2 heures
   └─→ Mesurer 3 transcriptions de durées différentes
   └─→ VALIDER ou INFIRMER l'hypothèse « 1.5s »

3. Si tiny < 3s → continuer
   Si tiny > 3s → évaluer base ou small

4. Implémenter l'isolation multi-session (1.1) — 2 jours
   └─→ C'est le blocage absolu

5. Ajouter cleanup + limite buffer (1.2 + 1.3) — 4 heures

6. Tester 5 users avec l'architecture isolée — 4 heures
```

**Pourquoi tester tiny AVANT le refactor ?** Parce que si tiny fait 4s au lieu de 1.5s, l'objectif « latence majeure » n'est pas atteint. Il vaut mieux le savoir avant d'investir 3 jours dans l'isolation.

---

## 5. Quel gain mesurable est garanti ?

| Gain | Valeur garantie | Basé sur |
|---|---|---|
| **Isolation sessions** | 0% mélange (vs 100% actuel) | Refactor technique standard |
| **Cleanup mémoire** | 0 fuite buffer (vs accumulation actuelle) | Pattern `finally` standard |
| **Réduction silence** | **-700 ms** exacts | Mathématique : 1000ms → 300ms |
| **Activation modèle `.env`** | Permet de changer de modèle sans redéployer | Correction de bug évident |

**Ce sont les SEULS gains 100% garantis.**

---

## 6. Quel gain reste spéculatif ?

| Gain | Valeur annoncée | Certitude | Pourquoi spéculatif |
|---|---|---|---|
| **Latence STT avec tiny** | ~1.5s | **Faible** | Jamais mesuré sur Kamatera. Proportionnalité théorique uniquement. |
| **Users simultanés** | 50 | **Très faible** | Maximum testé = 5 (échec 100%). Calcul théorique basé sur tiny non mesuré. |
| **Gain beam_size=1** | 3-5x | **Moyenne** | Non mesuré. Benchmarks communautaires uniquement. |
| **Parallélisme thread pool** | 4x | **Moyenne** | Dépend de la thread-safety de CTranslate2. Non vérifié. |
| **Qualité tiny** | « acceptable dialogue » | **Moyenne** | WER ~18% estimé. Non testé sur français éducatif. |

---

## Synthèse finale

| | |
|---|---|
| **Plan réaliste ?** | Oui, dans son architecture. Non dans ses chiffres de performance (non tous prouvés). |
| **Hypothèses prouvées** | 10 (latence medium, mélange 100%, buffer global, écrasement callback, CPU 25%, serveur non saturé, RAM modèle 1.9GB, RAM recyclable, timeout 5 users, bug modèle) |
| **Hypothèses théoriques** | 8 (latence tiny/base/small, 50 users, gain beam_size, thread pool, qualité tiny) |
| **Phase 1 prioritaire** | Test tiny sur Kamatera (2h) → si OK, refactor isolation (2-3 jours) |
| **Gains garantis** | Isolation, cleanup, -700ms silence, contrôle modèle |
| **Gains spéculatifs** | 1.5s tiny, 50 users, 3-5x beam_size |

---

### Recommandation opérationnelle

**Avant de valider le Master Plan comme réaliste, exécuter un test de 2 heures :**

1. Télécharger `tiny` sur Kamatera
2. Mesurer 3 transcriptions (1s, 3s, 5s audio)
3. Noter la latence

**Si tiny < 2s → le Master Plan est réaliste. Procéder au refactor.**

**Si tiny > 3s → le gain 6.8x est faux. Reconsidérer le plan (base ? cloud API ?).**

**Ce test de 2 heures est le point de décision critique.**
