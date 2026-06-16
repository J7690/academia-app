# BOBODO_VOICE_PRODUCTION_DECISION_FINAL

## Audit final de capacité production Bobodo Voice

---

### Résumé exécutif

| Mission | Livrable | Verdict |
|---|---|---|
| M1 — Multi-session | `BOBODO_MULTI_SESSION_PROOF.md` | ❌ ÉCHEC |
| M2 — Charge Small | `BOBODO_SMALL_LOAD_TEST.md` | ⚠️ OK standalone, KO production |
| M3 — Conversation 5min | `BOBODO_5MIN_CONVERSATION_TEST.md` | ❌ ÉCHEC |
| M4 — Reprise réseau | `BOBODO_NETWORK_RESILIENCE.md` | ✅ OK avec perte de session |
| M5 — Capacité réelle | `BOBODO_REAL_CAPACITY.md` | 1 user, 1 échange |

---

## 1. GO ou NO GO

### **NO GO**

Le service Bobodo Voice **ne peut pas être mis en production** dans son état actuel.

---

## 2. Nombre réel d'utilisateurs simultanés

### **1 utilisateur**

Et même cet utilisateur ne peut pas avoir une conversation complète.

### Preuves

**M1 — Multi-session :** 0/15 transcriptions reçues sur tests 2/3/5 users. Les logs serveur montrent que 5 fichiers audio de 5 users différents ont été **mélangés** dans un seul buffer de 10.68s, produisant une transcription concaténée envoyée à un seul user.

**M3 — Conversation :** Sur 5 minutes, 9 échanges audio ont été envoyés. **1 seule transcription** a été reçue (le premier échange). Les 8 suivants sont restés sans réponse. Le service cesse de fonctionner après le premier échange.

---

## 3. Latence réelle observée

### Service actuel (Medium)

| Scénario | Latence observée | Preuve |
|---|---|---|
| 1 échange | ~8.5s | `conversation_test.json` ligne 48 |
| 2+ users | Timeout | `multi_session_test_v2.json` |
| 2+ échanges | Silence | `conversation_test.json` |

### Si on bascule sur Small (standalone)

| Users | Latence | Preuve |
|---|---|---|
| 1 | 2 837 ms | `small_load_test.json` |
| 2 | 5 574 ms | `small_load_test.json` |
| 3 | 8 230 ms | `small_load_test.json` |
| 5 | 13 429 ms | `small_load_test.json` |

**Mais Small avec le code actuel donnerait le même résultat : 1 user, 1 échange, car les bugs sont architecturaux, pas liés au modèle.**

---

## 4. Risque principal restant

### **Risque #1 : Architecture monocession (CRITIQUE)**

| | |
|---|---|
| **Probabilité** | 100% (le code le garantit) |
| **Impact** | Catastrophique — impossibilité de servir plus d'un user |
| **Root cause** | `STTService` instancié une seule fois, buffer global, callback écrasé |
| **Code concerné** | `@/opt/bobodo-vocal/stt_service.py:30`, `@/opt/bobodo-vocal/stt_service.py:37`, `@/opt/bobodo-vocal/websocket_handler.py:39` |

**Preuve :** Les logs serveur (`journalctl -u bobodo-vocal`) montrent une transcription de 10.68s contenant 5 phrases de 5 users, envoyée à un seul handler.

### **Risque #2 : Perte de contexte conversation (CRITIQUE)**

| | |
|---|---|
| **Probabilité** | 100% après le premier échange |
| **Impact** | L'utilisateur ne peut pas poser de question de suivi |
| **Root cause** | État interne du `STTService` non réinitialisé après transcription |
| **Preuve** | 1/9 échanges sur 5 minutes (`conversation_test.json`) |

### **Risque #3 : Pas de persistance de session (MAJEUR)**

| | |
|---|---|
| **Probabilité** | 100% à chaque reconnexion |
| **Impact** | L'utilisateur perd le fil de la conversation si le réseau coupe |
| **Root cause** | Chaque connexion WebSocket crée un handler vierge |
| **Preuve** | `resilience_test.json` — reconnexion OK mais état local perdu |

---

## 5. Priorité n°1 après mise en production

### **Il n'y a pas de "priorité n°1 après mise en production" car c'est un NO GO.**

Le service ne doit pas être mis en production. Avant toute mise en production, il faut :

#### Phase 1 — Correction architecturale (BLOQUANT)

| # | Action | Fichier | Ligne |
|---|---|---|---|
| 1 | Créer un `STTService` **par session** (pas global) | `main.py` | 78 |
| 2 | Isoler `audio_buffer` par session | `stt_service.py` | 30 |
| 3 | Isoler `transcription_callback` par session | `stt_service.py` | 37 |
| 4 | Isoler `silence_task` par session | `stt_service.py` | 35 |
| 5 | Réinitialiser l'état STT après chaque transcription | `stt_service.py` | 101–146 |

#### Phase 2 — Tests de validation (BLOQUANT)

| # | Test | Critère de succès |
|---|---|---|
| 1 | 2 users simultanés | Chaque user reçoit SA transcription, pas celle de l'autre |
| 2 | 5 users simultanés | Pas de mélange, 100% des transcriptions reçues |
| 3 | Conversation 5 min | ≥8 échanges sur 9 avec transcription reçue |
| 4 | Reconnexion | Contexte conversation préservé (si stocké côté Bobodo) |

#### Phase 3 — Optimisation (APRÈS correction)

| # | Action | Gain attendu |
|---|---|---|
| 1 | Passer de Medium à Small | Latence ÷ 2.7 (7.7s → 2.8s) |
| 2 | Ajouter file d'attente par user | Support multi-user séquentiel |
| 3 | Pool de workers STT | Support 2–3 users réels en parallèle |
| 4 | Fallback cloud STT | Réduction latence à <1s si coût acceptable |

---

## Réponses aux 5 questions du livrable final

| # | Question | Réponse avec preuves |
|---|---|---|
| 1 | **GO / NO GO** | **NO GO** — architecture monocession, mélange audio, perte de contexte |
| 2 | **Users simultanés** | **1** — multi-session = 0/15 transcriptions, buffer global partagé |
| 3 | **Latence réelle** | **~8.5s** (Medium actuel) / **~2.8s** (Small standalone) |
| 4 | **Risque principal** | **Architecture monocession** — buffer global + callback écrasé = mélange total |
| 5 | **Priorité n°1** | **Corriger l'architecture** avant toute mise en production. Pas de déploiement possible. |

---

## Données brutes

| Fichier | Preuve |
|---|---|
| `multi_session_test_v2.json` | 0/15 transcriptions en multi-session |
| `small_load_test.json` | Latence Small 2 837–13 429 ms |
| `conversation_test.json` | 1/9 échanges sur 5 min |
| `resilience_test.json` | Reconnexion OK, session perdue |
| `journalctl -u bobodo-vocal` | 5 phrases mélangées dans 1 fichier 10.68s |
| `stt_service_server.py` | Code source montrant buffer global |
| `websocket_handler_server.py` | Code source montrant callback écrasé |
