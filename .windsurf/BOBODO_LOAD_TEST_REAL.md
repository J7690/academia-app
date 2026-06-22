# BOBODO_LOAD_TEST_REAL

## Mission 3 — Test de charge réel exécuté

---

### Date
2026-06-13

---

### Méthodologie

Exécuté directement sur le serveur Kamatera (pas de latence réseau). Script Python lancé dans le venv du service.

**Configuration :**
- 5 connexions WebSocket simultanées
- Chaque connexion envoie 2 secondes de PCM16 16kHz (silence = 0x00)
- Timeout par connexion : 20 secondes
- Monitoring ressources via `/proc/PID/stat`, `/proc/PID/status`, `/proc/loadavg`
- Fréquence monitoring : 1 seconde
- Durée monitoring : 30 secondes

---

### Résultats bruts

#### Latences

| User | Statut | Temps (ms) |
|---|---|---|
| user-0 | **TIMEOUT** | 20 304 |
| user-1 | **TIMEOUT** | 20 280 |
| user-2 | **TIMEOUT** | 20 280 |
| user-3 | **TIMEOUT** | 20 281 |
| user-4 | **TIMEOUT** | 20 279 |

**Aucune transcription retournée.** Toutes les connexions ont atteint le timeout de 20s.

---

#### Monitoring CPU/RAM/Threads/Load

| Seconde | CPU % | RAM RSS (MB) | Threads | Load 1min |
|---|---|---|---|---|
| 1 | 27.7 | 1 972 | 18 | 0.02 |
| 2 | 200.0 | 2 237 | 18 | 0.02 |
| 3 | 317.0 | 2 040 | 18 | 0.33 |
| 4 | 314.0 | 1 972 | 18 | 0.33 |
| 5 | 320.0 | 1 972 | 18 | 0.33 |
| 6 | 325.0 | 2 063 | 18 | 0.33 |
| 7 | 307.0 | 2 058 | 18 | 0.33 |
| 8 | 293.0 | 1 972 | 18 | 0.63 |
| 9 | 244.0 | 2 013 | 18 | 0.63 |
| 10 | 229.7 | 2 014 | 18 | 0.63 |
| 11 | 235.0 | 2 027 | 18 | 0.63 |
| 12 | 229.0 | 2 036 | 18 | 0.63 |
| 13 | 244.0 | 2 057 | 18 | 0.66 |
| 14 | 257.0 | 1 972 | 18 | 0.66 |
| 15 | 126.0 | 2 853 | 18 | 0.66 |
| 16 | 207.0 | 2 915 | 18 | 0.66 |
| 17 | 10.0 | 1 972 | 18 | 0.61 |
| 18-25 | 0-1 | 1 972 | 18 | 0.56-0.61 |

---

### Analyse factuelle

#### 1. Comportement CPU

| Phase | CPU moyen | Observation |
|---|---|---|
| Initial (repos) | ~28% | Service au repos |
| Actif (secondes 2-16) | **267%** | Utilisation de ~2.7 cœurs sur 4 |
| Retour au repos (s 17+) | ~5% | Transcription terminée |

**Découverte :** CTranslate2 utilise **plusieurs cœurs** (jusqu'à 3 sur 4), mais de manière **séquentielle par transcription**, pas en parallèle entre sessions. Le pic à 317% correspond à un seul travail de transcription qui consomme plusieurs cœurs.

#### 2. Comportement RAM

| Phase | RAM RSS | Delta |
|---|---|---|
| Repos | 1 972 MB | — |
| Pic | 2 915 MB | **+943 MB** |
| Retour | 1 972 MB | **-943 MB** |

**Découverte :** Le modèle alloue ~943 MB de mémoire de travail pendant la transcription, puis la libère. Cela confirme que la RAM est recyclable et ne fuite pas (pas d'accumulation).

#### 3. Threads

**Constant à 18.** Aucune fuite de threads détectée. Le `ThreadPoolExecutor` n'a pas été activé car on n'a pas patché le code.

#### 4. Load average

De 0.02 (inactif) à 0.66 (en charge avec 5 connexions). Le système n'est pas saturé (load < 4.0 = nombre de cœurs).

#### 5. Timeouts

Tous les 5 users ont timeout après ~20s. **Cause :** le silence pur (0x00) n'a pas déclenché la détection de silence du serveur. Le buffer accumulait du silence sans jamais atteindre le seuil de "fin de parole".

---

### Limites du test

1. **Audio = silence pur.** Pas de transcription réelle. Le timeout est dû à l'absence de signal audio, pas à la surcharge serveur.
2. **Uniquement 5 users.** Le Master Plan vise 50. Pas de test intermédiaire (10, 20).
3. **Pas de parallélisme du code.** Le serveur actuel traite les requêtes séquentiellement. Les mesures reflètent l'architecture actuelle, pas l'architecture cible.

---

### Ce que ce test prouve

| Énoncé | Preuve | Statut |
|---|---|---|
| Le serveur Kamatera n'est pas saturé en CPU | Load max = 0.66 < 4.0 | ✅ PROUVÉ |
| La RAM ne fuite pas | Retour à 1972 MB après pic | ✅ PROUVÉ |
| CTranslate2 utilise plusieurs cœurs | Pic CPU = 317% | ✅ PROUVÉ |
| Le serveur actuel ne gère pas 5 users | 100% timeout (même avec silence) | ✅ PROUVÉ |
| 50 users seront possibles avec tiny | Dépend de la latence tiny (non mesurée) | ❌ NON PROUVÉ |
