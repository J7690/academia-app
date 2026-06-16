# BOBODO_PATCH_PRIORITY_MATRIX

## Mission 4 — Audit des patches proposés dans le Master Plan

---

### Date
2026-06-13

---

### Méthodologie

Pour chaque patch du Master Plan (Mission 7), analyser :
- **Gain attendu** : quelle amélioration ?
- **Risque** : qu'est-ce qui peut mal tourner ?
- **Dépendances** : de quels autres patches dépend-il ?
- **Effet secondaire** : conséquences imprévues ?

Puis classer : **CRITIQUE** / **IMPORTANT** / **OPTIONNEL**

---

### Patch 1.1 — Isolation multi-session (`SessionState` + `SessionManager`)

| | |
|---|---|
| **Fichier** | `stt_service.py`, `websocket_handler.py` |
| **Gain attendu** | 0% mélange entre utilisateurs, base de toute la scalabilité |
| **Risque** | **HAUT** — refactor majeur. Bug = perte de sessions, fuites mémoire, ou crash. |
| **Dépendances** | Aucune (c'est le premier patch) |
| **Effet secondaire** | Change la structure interne de `STTService`. Tous les autres patches en dépendent. |
| **Classification** | **CRITIQUE** — sans cela, aucun autre patch n'a de sens. C'est le fondement. |

---

### Patch 1.2 — Cleanup session (`destroy_session()`)

| | |
|---|---|
| **Fichier** | `websocket_handler.py` |
| **Gain attendu** | Évite l'accumulation de buffers, élimine la fuite mémoire |
| **Risque** | **FAIBLE** — ajout d'un `finally` simple |
| **Dépendances** | **Patch 1.1** (nécessite que `destroy_session()` existe) |
| **Effet secondaire** | Aucun. Juste du nettoyage. |
| **Classification** | **CRITIQUE** — une fuite mémoire = crash en production. |

---

### Patch 1.3 — Limite buffer (`MAX_BUFFER_SIZE = 5 MB`)

| | |
|---|---|
| **Fichier** | `stt_service.py` |
| **Gain attendu** | Protection contre attaque DoS par audio infini |
| **Risque** | **FAIBLE** — ajout d'une vérification simple |
| **Dépendances** | **Patch 1.1** (nécessite le buffer par session) |
| **Effet secondaire** | Connexion rejetée si limite atteinte. Nécessite un message d'erreur clair. |
| **Classification** | **IMPORTANT** — sécurité, mais pas bloquant immédiat. |

---

### Patch 1.4 — Thread pool transcription (`ThreadPoolExecutor(4)`)

| | |
|---|---|
| **Fichier** | `stt_service.py` |
| **Gain attendu** | Parallélisme : 4 transcriptions simultanées au lieu d'une |
| **Risque** | **MOYEN** — `asyncio.run_coroutine_threadsafe()` peut créer des race conditions si Mall géré. CTranslate2 est-il thread-safe en écriture ? |
| **Dépendances** | **Patch 1.1** (nécessite l'isolation par session pour éviter le mélange en parallèle) |
| **Effet secondaire** | RAM multipliée par le nombre de transcriptions simultanées (pic +943 MB × 4 = ~3.8 GB potentiel). Si 4 transcriptions medium en parallèle = RAM explose. |
| **Classification** | **CRITIQUE** — mais doit être combiné avec tiny, sinon la RAM ne suit pas. |

---

### Patch 1.5 — Réduction silence (`1000 ms → 300 ms`)

| | |
|---|---|
| **Fichier** | `stt_service.py`, `.env` |
| **Gain attendu** | **-700 ms** par requête |
| **Risque** | **FAIBLE** — mais risque de découpe précoce si l'utilisateur fait des pauses > 300 ms dans sa phrase |
| **Dépendances** | Aucune |
| **Effet secondaire** | Phrases avec pauses longues (ex: "Bonjour... [pause] ...Bobodo") seront coupées en deux. |
| **Classification** | **IMPORTANT** — gain immédiat, risque minime. |

---

### Patch 1.6 — Correction bug modèle (`main.py:56` passe Settings)

| | |
|---|---|
| **Fichier** | `main.py`, `stt_service.py` |
| **Gain attendu** | Active la configuration `.env` (actuellement ignorée, medium forcé) |
| **Risque** | **FAIBLE** — correction d'un bug de passage de paramètre |
| **Dépendances** | Aucune |
| **Effet secondaire** | Si `.env` contient `medium`, pas de changement. Si `.env` contient `tiny`, chargement d'un nouveau modèle au redémarrage. |
| **Classification** | **CRITIQUE** — sans ce patch, le changement de modèle est impossible. |

---

### Patch 2.1 — Passage modèle medium → tiny

| | |
|---|---|
| **Fichier** | `.env`, redémarrage service |
| **Gain attendu** | **6-8x plus rapide** (estimé : 1.5s vs 8.3s) |
| **Risque** | **MOYEN** — perte de précision. WER tiny ≈ 18% (vs medium ≈ 8%). Dialogue éducatif = tolérant, mais risque de mots mal reconnus. |
| **Dépendances** | **Patch 1.6** (nécessite que le modèle `.env` soit lu) |
| **Effet secondaire** | Doit être testé avec des phrases réelles en français. Nécessite un benchmark qualité avant/après. |
| **Classification** | **CRITIQUE** — c'est le patch qui fait passer Bobodo de « inutilisable » à « utilisable ». |

---

### Patch 2.2 — Réduction `beam_size` (`5 → 1`)

| | |
|---|---|
| **Fichier** | `stt_service.py` |
| **Gain attendu** | **3-5x plus rapide** (estimé théorique) |
| **Risque** | **MOYEN** — `beam_size=1` = greedy decoding. Perte de qualité sur phrases ambiguës ou bruitées. |
| **Dépendances** | Aucune (indépendant du modèle) |
| **Effet secondaire** | Doit être testé sur des phrases avec homophones (ex: "son" / "sont") |
| **Classification** | **IMPORTANT** — gain significatif, mais qualité à vérifier. |

---

### Patch 2.3 — Traitement en mémoire (`io.BytesIO` au lieu de fichier temp)

| | |
|---|---|
| **Fichier** | `stt_service.py` |
| **Gain attendu** | **-50 ms** (négligeable vs 8.3s) |
| **Risque** | **FAIBLE** — si `faster-whisper` accepte `io.BytesIO` |
| **Dépendances** | Aucune |
| **Effet secondaire** | Aucun notable. |
| **Classification** | **OPTIONNEL** — gain marginal. À faire si facile, pas prioritaire. |

---

### Patch 2.4 — Heartbeat WebSocket (ping/pong 30s)

| | |
|---|---|
| **Fichier** | `websocket_handler.py` |
| **Gain attendu** | Empêche les déconnexions silencieuses par proxy/load balancer |
| **Risque** | **FAIBLE** — implémentation standard |
| **Dépendances** | Aucune |
| **Effet secondaire** | Légère augmentation du trafic réseau (ping/pong toutes les 30s = négligeable) |
| **Classification** | **IMPORTANT** — stabilité production. |

---

### Patch 2.5 — Tests charge 50 users

| | |
|---|---|
| **Fichier** | Scripts de test |
| **Gain attendu** | Validation que l'architecture cible tient la charge |
| **Risque** | **N/A** — c'est un test, pas un patch |
| **Dépendances** | **Tous les patches Phase 1+2** |
| **Effet secondaire** | Peut révéler des bugs non anticipés |
| **Classification** | **CRITIQUE** — sans test, pas de validation production. |

---

### Résumé classification

| Classification | Patches |
|---|---|
| **CRITIQUE** | 1.1 (isolation), 1.2 (cleanup), 1.4 (thread pool), 1.6 (bug modèle), 2.1 (tiny), 2.5 (tests charge) |
| **IMPORTANT** | 1.3 (limite buffer), 1.5 (silence 300ms), 2.2 (beam_size=1), 2.4 (heartbeat) |
| **OPTIONNEL** | 2.3 (BytesIO) |

---

### Risque global des patches CRITIQUES

| Patch | Risque principal | Mitigation |
|---|---|---|
| 1.1 Isolation | Refactor majeur, régression | Tests unitaires avant/après, rollback plan |
| 1.4 Thread pool | CTranslate2 thread-safety | Lire doc CTranslate2 ; tester 2 users d'abord |
| 2.1 Tiny | Perte précision ~10% absolue | Benchmark WER sur 50 phrases fr ; rollback si inacceptable |

---

### Dépendances entre patches

```
1.6 (bug modèle) ──────┐
                        ├──→ 2.1 (tiny)
.env correct ───────────┘

1.1 (isolation) ───────┬──→ 1.2 (cleanup)
                        ├──→ 1.3 (limite buffer)
                        ├──→ 1.4 (thread pool)
                        └──→ tout le reste
```

**1.1 est le patch racine.** Tout le reste dépend de l'isolation multi-session.
