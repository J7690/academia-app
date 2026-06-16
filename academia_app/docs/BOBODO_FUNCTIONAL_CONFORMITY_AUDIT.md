# BOBODO — Audit de Conformité Fonctionnelle

**Date**: 2025-06-15  
**Méthode**: Vérification architecturale par analyse de code (pas d'hypothèse)  
**Fichiers analysés**:
- `academia_app/lib/features/student/tabs/student_bobodo_tab.dart` (1956 lignes)
- `academia_app/lib/providers/bobodo_provider.dart` (354 lignes)
- `academia_app/lib/services/bobodo_vocal_service.dart` (163 lignes)
- `supabase/functions/bobodo-chat/index.ts` (1634 lignes)
- `.windsurf/websocket_handler_v2.py` (167 lignes)
- `.windsurf/main_server.py` (128 lignes)
- `.windsurf/tts_service_edge.py` (103 lignes)

---

## RÉSUMÉ EXÉCUTIF

| Cas | Statut | Verdict |
|-----|--------|---------|
| A — Envoi texte | **CONFORME** | Fonctionne intégralement |
| B — Dictée vocale | **CONFORME** | Fonctionne intégralement |
| C — Conversation vocale | **NON CONFORME** | Architecture cassée — réponse vocale impossible |
| D — Restauration historique | **CONFORME** | Fonctionne intégralement |

**Problème critique**: Le mode conversation vocale (CAS C) est architecturalement déconnecté. Le flux ne produit jamais de réponse vocale.

---

## CAS A — ENVOI MESSAGE TEXTE

### 1. Attendu

Utilisateur écrit un message → appuie sur Envoyer → Bobodo répond → scroll automatique → dernière réponse visible.

### 2. Existant

**Flux complet vérifié** (`student_bobodo_tab.dart` + `bobodo_provider.dart` + Edge Function):

```
1. _send() [ligne 1208] → provider.sendUserMessage(text)
2. sendUserMessage() [bobodo_provider:136] → ajoute message local immédiatement
3. _callEdgeFunction() [bobodo_provider:194] → POST vers Edge Function
4. Edge Function [bobodo-chat/index.ts:1361] → STT/RAG/OpenRouter → réponse texte
5. loadMessages() [bobodo_provider:111] → recharge depuis Supabase → _shouldScrollToBottom = true
6. Consumer rebuild → auto-scroll [student_bobodo_tab:262-274]
```

**Preuves de code** :

- Bouton envoi désactivé si texte vide ou loading (`student_bobodo_tab.dart:1101`)
- Message ajouté localement avant requête (`bobodo_provider.dart:181-189`)
- Edge Function persiste le message étudiant via `app_append_bobodo_message` (`index.ts:1450`)
- Edge Function persiste la réponse IA via `app_append_bobodo_message` (`index.ts:1602`)
- Après succès, `loadMessages()` recharge les messages et active le scroll flag (`bobodo_provider.dart:124`)
- Auto-scroll déclenché à 3 endroits : changement de nombre de messages, isLoading, et shouldScrollToBottom (`student_bobodo_tab.dart:262-274`)

### 3. Conforme : **OUI**

### 4. Écart identifié : Aucun

### 5. Recommandation : Aucune

---

## CAS B — DICTÉE VOCALE (Micro zone de saisie)

### 1. Attendu

Utilisateur active la dictée → parle → texte transcrit → texte dans zone de saisie → utilisateur modifie si nécessaire → envoie → Bobodo répond.

### 2. Existant

**Flux complet vérifié** :

```
1. Appui micro zone saisie [ligne 1070-1076] → _startVocalRecording()
2. _startVocalRecording() [ligne 1272] → demande permission micro → _speechToText.listen()
3. SpeechToText natif Android (package speech_to_text) → reconnaissance en français (fr_FR)
4. onResult callback [ligne 1284-1289] → _lastRecognizedWords mis à jour
5. Résultat final → _handleSpeechResult() → _stopVocalRecording() → _onTranscriptionReceived()
6. _onTranscriptionReceived() EN MODE NON-CONVERSATION [ligne 1400-1410]:
   → _controller.text = text (texte placé dans le champ)
   → _isRecordingMode = false (retour au mode texte)
7. Utilisateur peut modifier et envoyer via bouton Envoyer
```

**Preuves de code** :

- STT natif utilisé : `SpeechToText` package (`student_bobodo_tab.dart:83`)
- Locale française : `localeId: 'fr_FR'` (`student_bobodo_tab.dart:1293`)
- Durée max 30s avec pause auto 3s (`student_bobodo_tab.dart:1291-1292`)
- Texte placé dans le TextEditingController (`student_bobodo_tab.dart:1406`)
- Retour au mode texte après transcription (`student_bobodo_tab.dart:1403-1404`)

### 3. Conforme : **OUI**

### 4. Écart identifié : Aucun

### 5. Recommandation : Aucune

---

## CAS C — CONVERSATION VOCALE (Micro header)

### 1. Attendu

Utilisateur active le mode conversation → parle → Bobodo comprend → Bobodo répond ORALEMENT → utilisateur parle à nouveau → conversation continue SANS intervention clavier.

### 2. Existant

**Flux vérifié — ARCHITECTURE CASSÉE** :

```
1. Appui micro header [ligne 404-412] → _toggleVoiceMode() → _isConversationMode = true
2. _startConversationMode() [ligne 1522] → _startVocalRecording()
3. _startVocalRecording() [ligne 1272] → _speechToText.listen() (STT NATIF ANDROID)
4. Résultat final → _handleSpeechResult() → _onTranscriptionReceived()
5. _onTranscriptionReceived() EN MODE CONVERSATION [ligne 1380-1399]:
   → provider.sendUserMessage(text) [ENVOI TEXTE VIA HTTP EDGE FUNCTION]
6. Edge Function → génère réponse TEXTE UNIQUEMENT → retourne JSON {reply: "..."}
7. loadMessages() → UI reconstruite avec la réponse texte
```

**LE POINT DE RUPTURE** :

Le code attend une réponse audio via `_onAudioResponseReceived()` (ligne 1413) qui est déclenchée par un message WebSocket de type `audio_response`.

**MAIS** : Ce message WebSocket n'arrive JAMAIS car :

1. **Le STT natif est utilisé** (pas le WebSocket) — `_speechToText.listen()` est appelé, pas `_vocalService.sendAudio()`
2. **Le message est envoyé via HTTP** — `provider.sendUserMessage()` appelle l'Edge Function par HTTP POST
3. **L'Edge Function ne produit que du texte** — elle retourne `{reply: "..."}`, pas d'audio
4. **Le WebSocket est connecté mais inactif** — `_vocalService.sendAudio()` n'est JAMAIS appelé nulle part dans `student_bobodo_tab.dart`
5. **Le serveur Kamatera ne reçoit jamais d'audio** — donc il ne peut pas exécuter STT → Bobodo → TTS → audio_response

**Preuve formelle** : Grep de `sendAudio` dans tout le fichier Flutter :

- `bobodo_vocal_service.dart:122` — Définition de la méthode `sendAudio()`
- ZÉRO appel à `sendAudio()` dans `student_bobodo_tab.dart` ou tout autre fichier client

**Ce qui se passe réellement en mode conversation** :

1. L'utilisateur parle
2. Le STT natif Android transcrit
3. Le texte est envoyé comme un message texte classique (même flux que CAS A)
4. Bobodo répond par texte dans le chat
5. **Aucune réponse vocale n'est produite**
6. `_onAudioPlaybackComplete()` (ligne 1564) qui devrait relancer l'écoute n'est JAMAIS atteint
7. La boucle conversationnelle vocale est donc **impossible**

**Architecture serveur prête mais non connectée** :

Le serveur Kamatera (`websocket_handler_v2.py`) implémente correctement :
```python
# ligne 108-140
async def _on_transcription_complete(self, transcription):
    # 1. Envoie transcription au client
    await self.send_transcription(transcription)
    # 2. Envoie transcription à Bobodo (Edge Function)
    response = await self.bobodo_client.send_message(session_id, message=transcription)
    # 3. Synthèse TTS
    audio_response = await self.tts_service.synthesize(response)
    # 4. Envoie audio au client
    await self.send_audio_response(audio_response)
```

Le service TTS Edge (`tts_service_edge.py`) est prêt :
```python
# Edge-TTS avec fallback gTTS
async def synthesize(self, text: str) -> Optional[bytes]:
    # Retourne des bytes audio MP3
```

**MAIS le client Flutter n'envoie jamais d'audio au WebSocket.**

### 3. Conforme : **NON**

### 4. Écart identifié

| Composant | État |
|-----------|------|
| STT natif (speech_to_text) | Fonctionnel ✅ |
| WebSocket client Flutter (connexion) | Fonctionnel ✅ |
| WebSocket client Flutter (envoi audio) | **Jamais appelé ❌** |
| Serveur WebSocket Kamatera (réception audio) | Prêt ✅ |
| Serveur STT Whisper | Prêt ✅ |
| Serveur TTS Edge | Prêt ✅ |
| Serveur → client audio_response | Prêt ✅ |
| Client réception audio_response | Code existe ✅ |
| Client lecture audio | Code existe ✅ |
| Client relance écoute après lecture | Code existe ✅ |
| **Lien manquant : audio → WebSocket** | **ABSENT ❌** |

**Cause racine** : Le mode conversation utilise le STT natif Android + envoi HTTP, alors qu'il devrait utiliser le pipeline WebSocket complet (audio brut → serveur STT → Bobodo → TTS → audio retour).

### 5. Recommandation

Pour obtenir le comportement attendu "parler → réponse vocale → parler → réponse vocale", il faut :

**Option A — Utiliser le pipeline WebSocket complet** :
- En mode conversation, enregistrer l'audio brut (PCM/WAV)
- L'envoyer via `_vocalService.sendAudio(audioBytes)`
- Le serveur fait STT + Bobodo + TTS
- Le client reçoit `audio_response` → lit l'audio → relance l'écoute
- Toute la boucle est déjà codée côté serveur ET côté client réception, seul l'envoi manque

**Option B — Garder le STT natif + ajouter TTS client** :
- Garder `_speechToText.listen()` pour la transcription (plus rapide, offline possible)
- Après réponse texte de l'Edge Function, synthétiser localement via `FlutterTts`
- Le code `_speakWithLocalTts()` existe déjà (ligne 1456) mais n'est jamais appelé dans le flux normal
- Relancer l'écoute après lecture

**Option C — Hybride : STT natif + TTS serveur** :
- Garder STT natif
- Après envoi texte + réception réponse texte, demander au serveur de faire le TTS
- Nécessite un endpoint HTTP pour TTS ou envoi du texte au WebSocket

---

## CAS D — RESTAURATION HISTORIQUE

### 1. Attendu

Utilisateur possède un historique → ouvre Bobodo → arrive directement sur sa dernière conversation → pas sur les cartes de suggestions.

### 2. Existant

**Flux complet vérifié** :

```
1. initState() → postFrameCallback → provider.restoreLastSession()
2. restoreLastSession() [bobodo_provider:59-72]:
   → Lit SharedPreferences (clé: bobodo_current_session_id_v1)
   → Si session trouvée: _currentSessionId = stored, loadMessages()
3. loadMessages() [bobodo_provider:111-131]:
   → Appel RPC app_list_bobodo_messages
   → _messages rempli avec les données
   → _shouldScrollToBottom = true
4. Consumer rebuild [student_bobodo_tab:284-286]:
   → messages.isEmpty ? _buildWelcomeView() : _buildMessagesList()
   → Si messages chargés: liste de messages affichée (PAS les suggestions)
5. Auto-scroll déclenché via shouldScrollToBottom flag
```

**Preuves de code** :

- Persistance à la création de session (`bobodo_provider.dart:95-102`)
- Persistance au changement de session (`bobodo_provider.dart:288-290`)
- Suppression au "Nouvelle conversation" (`bobodo_provider.dart:260-262`)
- Condition d'affichage : si `messages.isEmpty` ET `!provider.isLoading` → welcome view ; sinon → messages list (`student_bobodo_tab.dart:284-286`)

**Cas de rupture identifié** : Si `restoreLastSession()` échoue (réseau, session supprimée côté serveur, SharedPreferences corrompu), `_messages` reste vide → welcome view affiché. Ce n'est pas un bug, c'est un fallback légitime.

### 3. Conforme : **OUI**

### 4. Écart identifié : Aucun

### 5. Recommandation : Aucune

---

## MISSION 4 — SUPABASE (Persistance)

### Conversations persistées ?

**OUI** — Preuve :
- `createSession()` appelle `app_get_or_create_bobodo_session` RPC (`bobodo_provider.dart:84`)
- Edge Function enregistre message étudiant via `app_append_bobodo_message` (`index.ts:1450`)
- Edge Function enregistre réponse IA via `app_append_bobodo_message` (`index.ts:1602`)
- Les messages sont stockés dans la table `bobodo_messages` (implicite par le RPC)

### Sessions restaurées ?

**OUI** — Preuve :
- `restoreLastSession()` lit SharedPreferences (`bobodo_provider.dart:62-63`)
- Si session ID présent, `loadMessages()` appelle `app_list_bobodo_messages` RPC (`bobodo_provider.dart:117-120`)

### Messages rechargés ?

**OUI** — Preuve :
- `loadMessages()` appelle `app_list_bobodo_messages` avec `p_session_id` (`bobodo_provider.dart:117-120`)
- Les messages sont castés en `List<Map<String, dynamic>>` et assignés à `_messages` (`bobodo_provider.dart:121-123`)

### Conversations récupérables ?

**OUI** — Preuve :
- `loadSessions()` interroge `bobodo_sessions` table directement (`bobodo_provider.dart:268-272`)
- `switchToSession(sessionId)` permet de charger n'importe quelle session existante (`bobodo_provider.dart:281-292`)
- UI : `_SessionsSheet` affiche la liste des sessions avec date et titre (`student_bobodo_tab.dart:1811-1955`)

---

## MISSION 5 — MODE CONVERSATION VOCALE (Analyse détaillée)

### Le mode conversation vocale permet-il actuellement : parler → réponse vocale → parler → réponse vocale sans intervention clavier ?

**NON.**

### Preuve par traçage des états et callbacks :

```
ÉTAT 1: _isConversationMode = true, _conversationState = listening
  → _startVocalRecording() déclenche _speechToText.listen()
  
ÉTAT 2: Utilisateur parle → résultat final reçu
  → _handleSpeechResult() → _stopVocalRecording() → _onTranscriptionReceived()
  
ÉTAT 3: _onTranscriptionReceived() en mode conversation
  → _conversationState = thinking
  → provider.sendUserMessage(text)  ← ENVOI HTTP (pas WebSocket)
  
ÉTAT 4: sendUserMessage() → _callEdgeFunction()
  → HTTP POST Edge Function
  → Réponse texte reçue → loadMessages()
  → _isLoading = false → UI rebuild

ÉTAT 5: UI reconstruite avec nouveau message
  → La réponse est affichée EN TEXTE dans le chat
  → _onAudioResponseReceived() N'EST JAMAIS APPELÉ
  → _audioPlayer ne joue rien
  → _onAudioPlaybackComplete() n'est jamais atteint
  → _conversationState reste sur "thinking" (jamais mis à "playing" ou "listening")
  → L'écoute NE REPREND JAMAIS automatiquement

RÉSULTAT: Après le premier message, la conversation s'arrête.
L'utilisateur doit quitter le mode conversation et recommencer manuellement.
```

### Flux qui DEVRAIT fonctionner mais qui n'est pas connecté :

```
CE QUI EXISTE CÔTÉ CLIENT (mais jamais déclenché):
  _onAudioResponseReceived() [ligne 1413]
    → Décode audio base64
    → _audioPlayer.setSourceBytes(audioBytes)
    → _audioPlayer.resume()
    → _isSpeaking = true
    → onPlayerComplete → _onAudioPlaybackComplete()
      → _conversationState = listening
      → _startVocalRecording()
      → BOUCLE RELANCÉE

CE QUI MANQUE POUR DÉCLENCHER CE FLUX:
  → _vocalService.sendAudio(audioBytes) n'est JAMAIS appelé
  → Donc le WebSocket serveur ne reçoit jamais d'audio
  → Donc le serveur ne fait jamais STT → Bobodo → TTS
  → Donc le serveur n'envoie jamais audio_response
  → Donc _onAudioResponseReceived() n'est jamais appelé
```

---

## ANOMALIES SUPPLÉMENTAIRES DÉTECTÉES

### A1 — setState() called during build (observé dans les logs runtime)

**Preuve**: Logs observés sur device :
```
Another exception was thrown: setState() or markNeedsBuild() called during build.
```

**Cause probable** : L'auto-scroll dans le `Consumer<BobodoProvider>` builder appelle `_scrollToBottom()` qui appelle `setState()` indirectement via `addPostFrameCallback`. Cependant, si `provider.shouldScrollToBottom` déclenche `provider.resetScrollFlag()` (qui appelle `notifyListeners()`) PENDANT le build du Consumer, cela cause cette erreur.

**Localisation** : `student_bobodo_tab.dart:271-273`
```dart
if (provider.shouldScrollToBottom) {
  _scrollToBottom();
  provider.resetScrollFlag(); // ← Appelle notifyListeners() pendant le build
}
```

### A2 — WebSocket connecté au init avec session potentiellement null

**Preuve** : `_connectVocalWebSocket()` est appelé dans `initState()` (ligne 130). Si aucune session n'existe encore, il crée une session vocale (`provider.createSession(title: 'Conversation vocale')` ligne 1245). Cela peut créer une session parasite avant que l'utilisateur n'interagisse.

### A3 — Listener WebSocket sans dispose propre

**Preuve** : `_audioPlayer.onPlayerComplete.listen(...)` est appelé à chaque réception d'audio (lignes 1430, 1482) sans stocker ni annuler la subscription précédente. Potentiel memory leak par accumulation de listeners.

---

## TABLEAU RÉCAPITULATIF

| # | Fonctionnalité | Attendu | Existant | Conforme | Écart |
|---|---------------|---------|----------|----------|-------|
| A | Envoi texte | Message → réponse → scroll | Implémenté intégralement | ✅ OUI | Aucun |
| B | Dictée vocale | Parler → texte dans champ → envoi manuel | Implémenté via STT natif | ✅ OUI | Aucun |
| C | Conversation vocale | Parler → réponse orale → parler → boucle | STT natif + HTTP texte uniquement | ❌ NON | Pipeline audio WebSocket non connecté |
| D | Restauration historique | Ouvrir → dernière conversation visible | SharedPreferences + loadMessages | ✅ OUI | Aucun |
| S1 | Persistance Supabase | Messages sauvegardés et récupérables | RPC fonctionnels | ✅ OUI | Aucun |
| S2 | Sessions restaurables | Toute session accessible via historique | switchToSession + loadSessions | ✅ OUI | Aucun |

---

## CONCLUSION

**3 fonctionnalités sur 4 sont pleinement conformes.**

**Le CAS C (conversation vocale) est le seul écart critique.** L'architecture serveur (Kamatera : STT Whisper + TTS Edge) est prête. L'architecture client (réception audio + lecture + relance écoute) est codée. Mais le **lien d'envoi** (client → WebSocket audio) n'est jamais exécuté. Le mode conversation se comporte actuellement comme une simple dictée avec envoi automatique — sans réponse vocale et sans boucle conversationnelle.

**Aucune implémentation effectuée. Aucune correction. Aucun commit.**

---

*Fin du rapport.*
