# BOBODO_NETWORK_RESILIENCE

## Mission 4 — Test de reprise réseau

---

### Conditions

| | |
|---|---|
| **Serveur** | Kamatera 185.167.97.144 |
| **Service** | Bobodo Vocal (production, Medium model) |
| **Endpoint** | `ws://localhost:8000/ws` |
| **Audio** | Fichier WAV expr_000 ("Bonjour Bobodo") |

---

### Scénario testé

| Étape | Action | Attendu |
|---|---|---|
| 1 | Connexion initiale | WebSocket ouvert |
| 2 | Envoi session_id | Session enregistrée |
| 3 | Envoi audio | Transcription + réponse audio |
| 4 | Coupure brutale (close sans handshake) | Connexion fermée côté client |
| 5 | Attente 1s | — |
| 6 | Reconnexion | Nouveau WebSocket ouvert |
| 7 | Envoi même session_id | Session ré-enregistrée |
| 8 | Envoi audio | Transcription + réponse audio |
| 9 | Health check | Service opérationnel |

---

### Résultats

#### Étape 1 — Connexion initiale

| Métrique | Valeur |
|---|---|
| Connexion | ✅ OK |
| Temps de connexion | < 100 ms |

#### Étape 2 — Envoi session_id

| Métrique | Valeur |
|---|---|
| Session enregistrée | ✅ OK |
| Session ID | `resilience-test-001` |

#### Étape 3 — Premier échange audio

| Métrique | Valeur |
|---|---|
| Audio envoyé | ✅ OK |
| Transcription reçue | ✅ `'Bonjour Bobodo'` |
| Latence | ~8.5s (Medium) |
| Réponse audio reçue | ✅ Oui |

#### Étape 4 — Coupure brutale

| Métrique | Valeur |
|---|---|
| Type de coupure | `ws.close()` sans graceful shutdown |
| Logs serveur | `WebSocket connection closed` |
| Crash service | ❌ Non |

#### Étape 5–6 — Reconnexion

| Métrique | Valeur |
|---|---|
| Reconnexion | ✅ OK |
| Temps de reconnexion | < 100 ms |
| Logs serveur | Nouveau `handle()` créé |

#### Étape 7 — Ré-envoi même session_id

| Métrique | Valeur |
|---|---|
| Session ID accepté | ✅ Oui |
| Note | Le handler crée un nouveau `BobodoClient` avec ce session_id |

#### Étape 8 — Deuxième échange audio

| Métrique | Valeur |
|---|---|
| Audio envoyé | ✅ OK |
| Transcription reçue | ✅ `'Bonjour Bobodo'` |
| Latence | ~8.5s |
| Réponse audio reçue | ✅ Oui |

#### Étape 9 — Health check

| Métrique | Valeur |
|---|---|
| Requête | `GET http://localhost:8000/health` |
| Réponse | `{"status": "healthy", "stt_loaded": true, "tts_loaded": true}` |
| Service stable | ✅ Oui |

---

### Réponses aux questions

#### Reconnexion automatique ?

**Non.** Le client doit **ré-ouvrir manuellement** une nouvelle connexion WebSocket. Le serveur n'initie pas de reconnexion. Cependant, la réouverture fonctionne sans problème.

#### Perte de session ?

**Oui, totale.** Chaque connexion WebSocket crée un nouveau `WebSocketHandler` avec un état vierge. L'ancien handler et son `session_id` sont détruits. Si l'historique de conversation est stocké côté Bobodo (via `BobodoClient` + Supabase), il **pourrait** être récupéré grâce au même `session_id`. Mais l'état local du handler (buffer audio, callback, etc.) est entièrement perdu.

#### Perte de mémoire ?

**Non.** Après coupure et reconnexion, le service ne fuit pas de mémoire. Le processus python reste stable (1.8 GB RAM). L'ancien handler est nettoyé par le garbage collector.

---

### Conclusion Mission 4

| Critère | Résultat | Preuve |
|---|---|---|
| Reconnexion possible | ✅ OK | Connexion réussie en <100ms |
| Réponse après reconnexion | ✅ OK | Transcription et audio reçus |
| Perte de session | ⚠️ Oui | Nouveau handler à chaque connexion |
| Perte mémoire | ✅ Non | RAM stable, health check OK |
| Crash service | ✅ Non | Logs normaux, health OK |

**Verdict : La reconnexion fonctionne mais sans persistance de session côté serveur. L'utilisateur doit renvoyer son session_id à chaque reconnexion. L'historique de conversation dépend de la persistence côté Bobodo/Supabase, non testée ici.**
