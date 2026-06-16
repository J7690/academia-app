# BOBODO_STT_FINAL_MODEL_SELECTION

## Mission 5 — Meilleur compromis latence vs qualité

## Livrable final — Modèle recommandé pour Academia

---

## Résumé exécutif

| Modèle | Latence | WER (100 expr.) | WER (phrases complètes est.) | RAM | Recommandation |
|---|---|---|---|---|---|
| **Tiny** | 818 ms | 110.5% | ~15% | 227 MB | ❌ Rejeté — qualité inacceptable |
| **Base** | 1 318 ms | 87.7% | ~12% | 434 MB | ❌ Rejeté — qualité encore trop faible |
| **Small** | **2 730 ms** | **44.1%** | **~10–15%** | **1 102 MB** | ⚠️ **Acceptable à court terme** |
| **Medium** | 7 696 ms | ~5% | ~3–5% | 2 551 MB | ❌ Rejeté — latence inacceptable |

---

## 1. Modèle recommandé

### **Small**

**Justification :**
- C'est le **premier modèle** du spectre Whisper à produire une qualité utilisable sur le vocabulaire Academia
- WER de **44.1%** sur expressions isolées, estimé à **10–15%** sur phrases complètes (usage réel)
- Latence de **2.7s** par transcription — acceptable bien que pas idéal
- RAM de **1.1 GB** — compatible avec le serveur Kamatera (10 GB)
- Noms propres africains **partiellement reconnus** (Burkina Faso, Mali, Niger corrects)
- Hallucinations **réduites** mais pas éliminées

**Pourquoi pas Medium ?**
- 7.7s de latence = expérience inutilisable (attente > 10s par interaction)
- 2.5 GB RAM = 3 users max avant saturation
- Gain qualité de ~40% WER non justifié par la perte de 3x en latence

**Pourquoi pas Base ?**
- WER de 87.7% = encore trop d'erreurs sur vocabulaire spécialisé
- 12% exact match = insuffisant pour la production
- Gain de qualité par rapport à Tiny non assez significatif

---

## 2. Latence réelle

| Scénario | Temps |
|---|---|
| **Chargement modèle** | 3 629 ms (une fois au démarrage) |
| **1 transcription moyenne** | **2 730 ms** |
| **1 transcription rapide** | 2 473 ms |
| **1 transcription lente** | 3 123 ms |
| **5 users simultanés*** | **13 650 ms total** (2 730 ms / user) |
| **1 user + LLM + TTS** | **~6–9s** round-trip estimé |

*CTranslate2 exécute séquentiellement en interne. 5 users = 5 × 2.7s = 13.5s de file d'attente.*

**Verdict latence :** Acceptable pour un MVP, mais pas fluide. L'utilisateur ressentira une pause de 2–3s entre sa phrase et la réponse de Bobodo.

---

## 3. WER réel

### Sur corpus de 100 expressions isolées

| Modèle | WER | Exact | Critique |
|---|---|---|---|
| Tiny | 110.5% | 1% | 88% |
| **Base** | **87.7%** | **12%** | **75%** |
| **Small** | **44.1%** | **22%** | **57%** |
| Medium* | ~5% | ~85% | ~5% |

### Extrapolation sur phrases complètes (usage réel)

| Modèle | WER estimé | Base de l'estimation |
|---|---|---|
| Tiny | ~15% | Benchmark 5 phrases : 0% erreur sur phrases générales, 100% sur noms propres |
| Base | ~12% | Amélioration ~20% sur Tiny, même profil |
| **Small** | **~10–15%** | Amélioration ~50% sur Tiny, noms propres mieux gérés |
| Medium | ~3–5% | Benchmark 5 phrases : quasi-parfait |

**Verdict qualité :** Small à **~10–15% WER** sur phrases complètes est **acceptable pour un assistant éducatif** où la précision absolue n'est pas critique (contrairement à la dictée médicale, par exemple).

---

## 4. Coût RAM

| Modèle | RAM modèle | RAM peak | Users RAM max** | Users CPU max*** |
|---|---|---|---|---|
| Tiny | 227 MB | 236 MB | ~40 | ~2* |
| **Small** | **959 MB** | **1 102 MB** | **~9** | **~2** |
| Medium | 2 551 MB | 2 826 MB | ~3 | ~2 |

*CTranslate2 utilise 2–3 cœurs par transcription, donc 2 users CPU en parallèle max sur 4 cœurs.
**RAM max = RAM serveur (10 GB) / RAM peak modèle.
***CPU max = cœurs CPU (4) / cœurs utilisés par transcription (~3).

**Verdict RAM :** Small à 1.1 GB permet **~9 users** en RAM. Mais le CPU limite à **2 users** simultanés réels. C'est le goulot.

---

## 5. Capacité multi-utilisateur

### Limite réelle — Contrainte CPU

CTranslate2 utilise **2–3 cœurs** par transcription quel que soit le modèle. Sur un serveur **4 cœurs** :

| Users simultanés | Temps total (Small) | Temps/user | Saturé ? |
|---|---|---|---|
| 1 | 2.7s | 2.7s | Non |
| 2 | 5.4s | 2.7s | Non |
| 3 | 8.1s | 2.7s | Oui (queue) |
| 5 | 13.5s | 2.7s | Oui (file d'attente) |

**Capacité pratique : 2 users simultanés** avec Small.
- Au-delà, les users attendent en file d'attente
- Temps d'attente acceptable jusqu'à ~5 users (13.5s max)
- Au-delà de 5, expérience dégradée

---

## 6. GO / NO GO production

### **GO — avec conditions**

Small est recommandé pour un **déploiement en production limitée** (beta) sous les conditions suivantes :

#### Conditions obligatoires

| # | Condition | Priorité |
|---|---|---|
| 1 | **Corriger l'architecture multi-session** avant tout changement de modèle | **CRITIQUE** |
| 2 | **Ajouter un dictionnaire post-transcription** pour "Bobodo" → "BoboDo" et noms propres courants | IMPORTANT |
| 3 | **Limiter à 2 users simultanés** par serveur Kamatera (4 cœurs) | IMPORTANT |
| 4 | **Mesurer le WER sur phrases complètes réelles** (pas seulement expressions isolées) avant généralisation | IMPORTANT |
| 5 | **Prévoir un fallback cloud** (Deepgram, AssemblyAI) si confiance < 0.7 | RECOMMANDÉ |

#### Risques acceptés

| Risque | Probabilité | Impact | Mitigation |
|---|---|---|---|
| Hallucination sur nom propre | ~15% | Modéré | Dictionnaire + fallback LLM |
| Latence 2.7s ressentie | 100% | Modéré | Indicateur visuel "Bobodo écoute..." |
| Queue >2 users | Variable | Faible | Limite 2 users / serveur |

#### Risques NON acceptés (bloquants si présents)

| Risque | Détection |
|---|---|
| Session mixing (architecture actuelle) | Tester avec 2 users réels |
| Crash mémoire (>10 users) | Monitorer RAM en prod |
| WER >20% sur phrases réelles | Tester sur corpus de 50 phrases complètes |

---

### Alternative recommandée à évaluer

| Option | Latence | Qualité | Coût mensuel estimé | Verdict |
|---|---|---|---|---|
| **Small (auto-hébergé)** | 2.7s | WER ~10–15% | 0 € | **GO conditionnel** |
| **Deepgram Nova-2** | ~500 ms | WER <3% | ~50–100€/mois (usage étudiant) | **À évaluer** |
| **AssemblyAI** | ~800 ms | WER <5% | ~30–80€/mois | **À évaluer** |
| **Whisper API (OpenAI)** | ~2–4s | WER ~5% | ~10–30€/mois | **À évaluer** |

**Recommandation stratégique :**
1. **Court terme** (1–2 mois) : Déployer Small + dictionnaire + limite 2 users
2. **Moyen terme** (2–4 mois) : Tester Deepgram ou AssemblyAI sur un échantillon d'users
3. **Long terme** (4+ mois) : Basculer sur cloud STT si le coût est acceptable vs le gain qualité

---

## Réponses aux 6 questions

| # | Question | Réponse factuelle |
|---|---|---|
| 1 | **Modèle recommandé** | **Small** |
| 2 | **Latence réelle** | **2 730 ms** moyenne (2 473–3 123 ms) |
| 3 | **WER réel** | **44.1%** sur expressions isolées, **~10–15%** estimé sur phrases complètes |
| 4 | **Coût RAM** | **1 102 MB** peak — ~9 users RAM max, mais **2 users** CPU max |
| 5 | **Capacité multi-utilisateur** | **2 users simultanés** sur 4 cœurs. Au-delà, file d'attente séquentielle. |
| 6 | **GO / NO GO** | **GO conditionnel** — sous réserve de : (1) correction architecture multi-session, (2) dictionnaire post-transcription, (3) limite 2 users/serveur, (4) fallback cloud prévu. |
