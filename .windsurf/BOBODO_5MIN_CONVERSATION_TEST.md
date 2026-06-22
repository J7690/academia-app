# BOBODO_5MIN_CONVERSATION_TEST

## Mission 3 — Conversation complète 5 minutes

---

### Conditions

| | |
|---|---|
| **Serveur** | Kamatera 185.167.97.144 |
| **Service** | Bobodo Vocal (production, Medium model) |
| **Endpoint** | `ws://localhost:8000/ws` |
| **Durée** | 300 secondes (5 minutes) |
| **Fréquence** | 1 échange audio toutes les 30 secondes |
| **Audio** | Fichiers WAV du corpus Academia (expressions isolées) |
| **Timeout par échange** | 15 secondes |

---

### Chronologie des événements

| Temps | Événement | Détails |
|---|---|---|
| 0s | Connexion WebSocket | Établie en 96 ms |
| 0–30s | Pings | Pongs reçus normalement |
| 30s | **Échange 0** — Audio envoyé | Fichier WAV expr_000 |
| 38.7s | **Transcription reçue** | `'Bonjour Bobodo'` — latence 8.55s |
| 38.7–60s | Pings | Pongs reçus normalement |
| 60s | **Échange 1** — Audio envoyé | Fichier WAV expr_001 |
| 60.3s | Pong reçu (pas transcription) | Latence 0s — c'est le ping de fond |
| 60–90s | Attente | **Aucune transcription reçue** |
| 90s | **Échange 2** — Audio envoyé | Fichier WAV expr_002 |
| 90.3s | Pong reçu | Pas de transcription |
| 90–120s | Attente | **Aucune transcription reçue** |
| 120s | **Échange 3** — Audio envoyé | Fichier WAV expr_003 |
| 120.4s | Pong reçu | Pas de transcription |
| 120–150s | Attente | **Aucune transcription reçue** |
| 150s | **Échange 4** — Audio envoyé | Fichier WAV expr_004 |
| 150.4s | Pong reçu | Pas de transcription |
| 150–180s | Attente | **Aucune transcription reçue** |
| 180s | **Échange 5** — Audio envoyé | Fichier WAV expr_005 |
| 180.5s | Pong reçu | Pas de transcription |
| 180–210s | Attente | **Aucune transcription reçue** |
| 210s | **Échange 6** — Audio envoyé | Fichier WAV expr_006 |
| 210.6s | Pong reçu | Pas de transcription |
| 210–240s | Attente | **Aucune transcription reçue** |
| 240s | **Échange 7** — Audio envoyé | Fichier WAV expr_007 |
| 240.6s | Pong reçu | Pas de transcription |
| 240–270s | Attente | **Aucune transcription reçue** |
| 270s | **Échange 8** — Audio envoyé | Fichier WAV expr_008 |
| 270.7s | Pong reçu | Pas de transcription |
| 270–300s | Attente | **Aucune transcription reçue** |
| 300s | Fin du test | Connexion toujours ouverte |

---

### Résultats quantitatifs

| Métrique | Valeur |
|---|---|
| **Durée totale** | 300.3 s |
| **Échanges audio envoyés** | 9 |
| **Transcriptions reçues** | **1** |
| **Réponses audio reçues** | **0** |
| **Erreurs reçues** | 0 |
| **Timeouts** | 0 |
| **Déconnexions** | 0 |
| **Stabilité** | **11.1%** (1/9) |

---

### Analyse

#### Perte de contexte

**OUI.** Après le premier échange, le service cesse de produire des transcriptions. Le WebSocket reste ouvert (pongs fonctionnent), mais la pipeline STT devient silencieuse.

**Cause probable :** Après la première transcription, l'état interne du `STTService` (buffer, silence_task, last_audio_time) entre dans un état où les appels ultérieurs à `transcribe()` n'arrivent pas à déclencher `_detect_silence()` correctement. Cela pourrait être dû à :
- Un silence_task fantôme qui bloque les nouveaux appels
- Le buffer audio qui ne se vide pas correctement
- Une condition de course entre le callback et le nouveau silence_task

#### Perte de mémoire

**Non détectée.** La RAM du processus python (vu via `systemctl status`) est restée stable autour de 1.8 GB. Aucune fuite mémoire visible sur 5 minutes.

#### Déconnexion

**Aucune.** La connexion WebSocket est restée active pendant les 300 secondes. Les pings/pongs fonctionnaient normalement.

#### Erreurs WebSocket

**Aucune.** Aucun message de type `error` n'a été reçu du serveur. Le service ne signale pas la défaillance — il reste silencieux.

---

### Logs serveur (confirmation)

Les logs du service montrent que la transcription a bien été traitée pour le **premier** échange :

```
[STT_SILENCE_DETECTED] Buffer duration: 2.15s
[STT_TRANSCRIPTION_RESULT] Text: 'Bonjour Bobodo'
[WS_STT_CALLBACK] Transcription completed: Bonjour Bobodo
```

Mais **aucune transcription** n'apparaît dans les logs pour les échanges 1 à 8. Le service reçoit l'audio (`[STT_AUDIO_RECEIVED]`) mais ne déclenche jamais la détection de silence ou la transcription.

---

### Conclusion Mission 3

| Critère | Résultat | Preuve |
|---|---|---|
| Stabilité conversation | ❌ ÉCHEC | 1/9 échanges (11.1%) |
| Perte de contexte | ❌ PRÉSENTE | Échanges 2–8 sans réponse |
| Perte de mémoire | ✅ ABSENTE | RAM stable |
| Déconnexion | ✅ AUCUNE | WS ouvert 300s |
| Erreurs WebSocket | ❌ SILENCIEUSES | Pas d'error message |

**Verdict : Le service ne supporte pas une conversation de plus d'un échange. Il est inutilisable pour une interaction vocale continue avec Bobodo.**
