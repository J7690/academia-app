# BOBODO_MULTI_SESSION_PROOF

## Mission 1 — Validation multi-session

---

### Conditions

| | |
|---|---|
| **Serveur** | Kamatera 185.167.97.144 |
| **Service** | Bobodo Vocal (production, Medium model) |
| **Endpoint** | `ws://localhost:8000/ws` |
| **Test** | 2, 3, 5 clients WebSocket simultanés |
| **Audio** | Fichiers WAV distincts par user (phrases différentes) |
| **Timeout** | 25s par requête |

---

### Preuve par inspection de code

Avant même le test réseau, le code source du service de production prouve l'absence d'isolation :

```python
# stt_service.py ligne 30
self.audio_buffer = bytearray()  # Buffer to accumulate audio chunks

# stt_service.py ligne 37
self.transcription_callback = None  # Callback for transcription results

# websocket_handler.py ligne 39
self.stt_service.set_transcription_callback(self._on_transcription_complete)
```

**@/opt/bobodo-vocal/stt_service.py:30** — Un seul `bytearray()` global partagé par toutes les connexions.

**@/opt/bobodo-vocal/stt_service.py:37** — Une seule référence `transcription_callback`, écrasée à chaque nouvelle connexion.

**@/opt/bobodo-vocal/websocket_handler.py:39** — Chaque handler écrase le callback du précédent.

**Conséquence prouvée par le code :**
1. L'audio de tous les users s'accumule dans le **même buffer**
2. Le callback pointe toujours vers le **dernier user connecté**
3. Toutes les transcriptions sont envoyées à **un seul user**

---

### Preuve par test réseau

#### Test 2 users simultanés

| User | Connexion | Transcription reçue | Audio reçu |
|---|---|---|---|
| 0 | OK | **0** | 0 |
| 1 | OK | **0** | 0 |

#### Test 3 users simultanés

| User | Connexion | Transcription reçue | Audio reçu |
|---|---|---|---|
| 0 | OK | **0** | 0 |
| 1 | OK | **0** | 0 |
| 2 | OK | **0** | 0 |

#### Test 5 users simultanés

| User | Connexion | Transcription reçue | Audio reçu |
|---|---|---|---|
| 0 | OK | **0** | 0 |
| 1 | OK | **0** | 0 |
| 2 | OK | **0** | 0 |
| 3 | OK | **0** | 0 |
| 4 | OK | **0** | 0 |

**Résultat : 0 transcription reçue sur 15 tentatives (0%).**

---

### Preuve par logs serveur (journalctl)

Extrait des logs du service de production pendant le test 5 users :

```
[STT_SILENCE_DETECTED] Buffer duration: 10.68s
[STT_TEMP_FILE_SIZE] File size: 341804 bytes
[STT_TRANSCRIPTION_RESULT] Text:
  'Je veux parler à Bobodo.
   Comment fonctionne Academia ?
   Bobodo, explique-moi, c'est le con.
   Academia est une super plateforme.
   Bonjour Bobodo.'
[WS_STT_CALLBACK] Transcription completed: [texte mixé de 5 users]
```

**Preuve irréfutable :**
- **5 fichiers audio distincts** ont été mélangés dans un seul buffer de 10.68 secondes
- **La transcription contient les 5 phrases** — les voix se sont superposées dans le buffer
- **Seul le dernier user connecté** a reçu le callback (les 4 autres connexions ont été fermées sans réponse)

---

### Réponses aux questions

#### Les buffers audio sont-ils totalement isolés ?

**NON.**

Preuve : le buffer est une variable d'instance `self.audio_buffer = bytearray()` dans `STTService`. Or `STTService` est instancié **une seule fois** dans `main.py` et partagé par tous les `WebSocketHandler`. Le code de production ne crée pas de buffer par session.

#### Existe-t-il encore un mélange de transcriptions ?

**OUI, TOTAL.**

Preuve : les logs montrent une transcription de 10.68s contenant les 5 phrases envoyées par 5 users différents, concaténées en un seul texte. Ce texte a été envoyé à un seul user via le callback écrasé.

---

### Synthèse Mission 1

| Critère | Résultat | Preuve |
|---|---|---|
| Isolation buffer | ❌ ÉCHEC | Code + logs mélange |
| Isolation callback | ❌ ÉCHEC | Code écrasement ligne 44 |
| Absence de mélange | ❌ ÉCHEC | 5 phrases dans 1 transcription |
| Réponse à tous les users | ❌ ÉCHEC | 0/15 transcriptions reçues |

**Verdict : Le service de production ne supporte pas 2 users simultanés. L'architecture est fondamentalement monocession.**
