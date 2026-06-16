# Audit Transcription Vocale - Problème Session ID

## Date
11 Juin 2026

---

## Symptômes Observés

### Comportement
- **Enregistrement** : Fonctionne (audio envoyé au serveur)
- **Transcription** : Échec systématique (sauf 1 fois avec délai)
- **Session ID** : Non reconnu par le serveur

### Logs Critiques

```
[VOICE_WS_CONNECT] Session ID actuel: null
[VOICE_WS_CONNECT] Création nouvelle session...
[VOICE_WS_CONNECT] Session créée: [ID]
[VOICE_WS_CONNECT] Connexion avec session ID: [ID]
[VOICE_WS_SERVICE] Message brut reçu: {"type": "error", "message": "No session ID provided"}
[VOICE_WS_SERVICE] Message décodé: {type: error, message: No session ID provided}
[VOICE_WS_SERVICE] Envoi audio: 190720 bytes
[VOICE_WS_SERVICE] Audio envoyé
```

---

## Analyse Technique

### 1. Problème Session ID

**Observation** :
- Au démarrage de `initState()`, `provider.currentSessionId` est `null`
- Une session est créée via `provider.createSession()`
- La connexion WebSocket est établie avec le session ID
- Le serveur renvoie quand même "No session ID provided"

**Hypothèse** :
- Le session ID créé n'est pas persisté correctement dans BobodoProvider
- Ou le serveur ne lit pas le paramètre `session_id` dans l'URL WebSocket
- Ou il y a un délai entre la création de session et la connexion

### 2. Timing de Connexion

**Code actuel** :
```dart
@override
void initState() {
  super.initState();
  _audioStreamController = StreamController<Uint8List>();
  _audioStreamController?.stream.listen(_onAudioData);
  _initRecorder();
  _connectVocalWebSocket();  // Connexion immédiate
}
```

**Problème** :
- La connexion WebSocket est tentée immédiatement dans `initState()`
- Si aucune session existe, une nouvelle est créée de manière asynchrone
- La connexion peut se produire avant que la session ne soit créée
- Ou le session ID peut être mal passé au serveur

### 3. Format URL WebSocket

**Code actuel** :
```dart
_channel = WebSocketChannel.connect(Uri.parse('$_url?session_id=$sessionId'));
```

**URL générée** :
`ws://185.167.97.144:8000/ws?session_id=[ID]`

**Question** :
- Le serveur Python (Kamatera) attend-il le paramètre `session_id` dans l'URL ?
- Ou attend-il un message JSON avec `session_id` ?
- Le code serveur doit être vérifié

### 4. Message Audio Envoyé

**Code actuel** :
```dart
final message = jsonEncode({
  'type': 'audio',
  'session_id': _sessionId,
  'audio': base64Audio,
});
```

**Observation** :
- Le session ID est inclus dans le message JSON
- Mais le serveur renvoie l'erreur avant de traiter l'audio
- L'erreur "No session ID provided" vient probablement de la connexion initiale

---

## Scénarios Possibles

### Scénario A : Session ID Non Persisté

**Flow** :
1. `initState()` → `_connectVocalWebSocket()`
2. `provider.currentSessionId` = null
3. `provider.createSession()` crée une session
4. `provider.currentSessionId` = [nouvel ID]
5. `_vocalService.connect(provider.currentSessionId ?? '')`
6. WebSocket connecté avec session ID
7. **Problème** : Le session ID est peut-être réinitialisé ailleurs

**Preuve** :
- Logs montrent "Session ID actuel: null" au démarrage
- Logs montrent "Session créée: [ID]"
- Mais serveur renvoie "No session ID provided"

### Scénario B : Serveur Ne Lit Pas l'URL

**Flow** :
1. WebSocket connecté avec `?session_id=[ID]`
2. Serveur Python ne lit pas le paramètre URL
3. Serveur attend le session ID dans le premier message
4. Erreur "No session ID provided"

**Preuve** :
- L'URL est correctement formatée
- Mais le serveur renvoie l'erreur immédiatement

### Scénario C : Timing Asynchrone

**Flow** :
1. `initState()` → `_connectVocalWebSocket()`
2. `provider.createSession()` est asynchrone
3. `_vocalService.connect()` est appelé avant la fin de `createSession()`
4. Session ID vide passé au WebSocket
5. Erreur "No session ID provided"

**Preuve** :
- Le code utilise `await provider.createSession()`
- Mais il y a peut-être un race condition

### Scénario D : Une Fois Fonctionné

**Observation** :
- L'utilisateur rapporte que ça a fonctionné une fois
- Avec délai
- Plus jamais depuis

**Hypothèse** :
- La première fois, une session existait déjà
- La connexion a réussi
- Ensuite, les sessions sont mal gérées
- Ou le serveur a un problème de state

---

## Audit Code Serveur (à vérifier)

### Fichier : `.windsurf/bobodo-vocal/websocket_handler.py`

**Question** :
- Comment le serveur lit-il le session ID ?
- Depuis l'URL WebSocket ou depuis le message JSON ?
- Y a-t-il une validation du session ID ?

**Code à vérifier** :
```python
# Dans websocket_handler.py
async def websocket_endpoint(websocket: WebSocket):
    session_id = websocket.query_params.get("session_id")
    if not session_id:
        await websocket.close(code=1008, reason="No session ID provided")
        return
```

**Si le code ressemble à ça** :
- Le serveur lit correctement le session ID depuis l'URL
- Le problème vient du client Flutter

**Si le code ne lit pas l'URL** :
- Le serveur doit être modifié pour lire l'URL ou le message JSON

---

## Audit BobodoProvider

### Question
- `createSession()` persiste-t-il le session ID correctement ?
- `currentSessionId` est-il accessible immédiatement après `createSession()` ?
- Y a-t-il un cache ou un délai de mise à jour ?

**Code à vérifier** :
```dart
// Dans bobodo_provider.dart
Future<void> createSession({required String title}) async {
  // Création session
  // Persistance du session ID
  // Notification listeners
}
```

---

## Recommandations pour ChatGPT

### 1. Vérifier le Code Serveur

**Fichier** : `.windsurf/bobodo-vocal/websocket_handler.py`

**Vérifier** :
- Comment le session ID est extrait
- S'il vient de l'URL ou du message JSON
- S'il y a une validation

### 2. Vérifier BobodoProvider

**Fichier** : `academia_app/lib/providers/bobodo_provider.dart`

**Vérifier** :
- Si `createSession()` persiste le session ID immédiatement
- Si `currentSessionId` est accessible après `createSession()`
- S'il y a un délai de mise à jour

### 3. Vérifier le Timing

**Option A** : Déplacer la connexion WebSocket
- Ne pas connecter dans `initState()`
- Connecter uniquement quand l'utilisateur clique sur le micro
- S'assurer que la session existe avant de connecter

**Option B** : Attendre la session
- Dans `initState()`, attendre que la session existe
- Utiliser un listener sur BobodoProvider
- Connecter uniquement quand `currentSessionId` n'est pas null

### 4. Vérifier le Format URL

**Option A** : Utiliser le message JSON
- Ne pas passer le session ID dans l'URL
- Passer uniquement dans le message JSON
- Modifier le serveur pour lire le message JSON

**Option B** : Vérifier le serveur
- S'assurer que le serveur lit le paramètre URL
- Ajouter des logs côté serveur pour voir ce qui est reçu

### 5. Ajouter de Logs Détaillés

**Côté Flutter** :
- Log avant connexion WebSocket
- Log après connexion WebSocket
- Log du session ID passé
- Log de la réponse du serveur

**Côté Serveur** :
- Log de l'URL reçue
- Log du session ID extrait
- Log des messages reçus

---

## Conclusion

### Problème Principal
Le serveur renvoie "No session ID provided" malgré que le client Flutter envoie un session ID.

### Causes Possibles
1. **Session ID non persisté** dans BobodoProvider
2. **Timing asynchrone** entre création de session et connexion
3. **Serveur ne lit pas l'URL** WebSocket
4. **Format incorrect** du session ID

### Prochaines Étapes
1. Vérifier le code serveur (`websocket_handler.py`)
2. Vérifier BobodoProvider (`createSession()`)
3. Ajouter des logs détaillés des deux côtés
4. Tester avec une session existante vs nouvelle session

---

## Sign-off

**Audit réalisé** : 11 Juin 2026
**Auditeur** : Cascade AI
**Statut** : EN ATTENTE VÉRIFICATION SERVEUR
