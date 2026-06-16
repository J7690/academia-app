# BOBODO_PROTOCOL_FINAL_DECISION

## Mission 6 — Recommandation finale

---

### Récapitulatif des faits établis

1. **Le WebSocket `/ws` existe et fonctionne.** (Preuve : tests clients `websockets` réussis)
2. **Le serveur attend un message `{"type":"session_id",...}`** (Preuve : `handle_session_id()` dans `websocket_handler.py:280`)
3. **Flutter n'envoie jamais ce message.** (Preuve : `bobodo_vocal_service.dart` n'a pas de méthode `sendSessionId()`)
4. **Flutter envoie `session_id` dans le payload audio et le query param.** (Preuve : `bobodo_vocal_service.dart:848`, `:30`)
5. **Le serveur ignore les deux.** (Preuve : `handle_audio()` n'extrait pas `session_id`, FastAPI WS n'extrait pas le query param)
6. **Les pratiques industrielles** (OpenAI, Gemini, LiveKit) utilisent toutes une **phase de configuration/initiation séparée**.
7. **Le buffer STT est global** et posera un problème multi-utilisateur quel que soit le choix.

---

## RECOMMANDATION FINALE

### Option A — Envoyer `session_id` séparément

**Réponse choisie : A**

---

### Justification technique

1. **Alignement avec le code existant** : `handle_session_id()` existe déjà dans `websocket_handler.py`. C'est le chemin prévu par l'auteur original.
2. **Alignement avec les pratiques industrielles** : Gemini Live API utilise un message `setup` initial dédié. OpenAI utilise la connexion elle-même comme session. Aucun ne mélange l'identifiant de session dans chaque message de données.
3. **Robustesse aux reconnections** : Après une déconnexion/réconnexion WS, renvoyer le message `session_id` restaure le contexte. Avec Option B, le buffer STT global est perturbé.
4. **Clarté du protocole** : Un message dédié à la configuration, puis des messages dédiés aux données. Séparation des responsabilités.
5. **Gestion des erreurs** : Si le message `session_id` échoue, le serveur peut envoyer une erreur immédiatement (avant tout traitement audio).

---

### Justification produit

1. **Conversation continue** : Le session_id est configuré une fois au début. Pas besoin de le répéter à chaque tour.
2. **Mode multi-session** : Un utilisateur peut changer de session de Bobodo sans reconnecter le WebSocket (en renvoyant un nouveau message `session_id`).
3. **UX déterministe** : L'erreur "No session ID" apparaît immédiatement si le message initial est manqué, pas après une transcription STT coûteuse.

---

### Impacts

#### Impacts Flutter (estimé : ~10 lignes)

**Fichier :** `lib/services/bobodo_vocal_service.dart`

```dart
Future<void> connect(String sessionId) async {
  _sessionId = sessionId;
  _channel = WebSocketChannel.connect(Uri.parse('$_url?session_id=$sessionId'));
  _isConnected = true;
  
  // AJOUTER :
  _channel!.sink.add(jsonEncode({
    'type': 'session_id',
    'session_id': sessionId,
  }));
  
  // ... reste inchangé
}
```

**Impact :** Faible. Une ligne de code. Testable unitairement.

#### Impacts Kamatera (estimé : 0 ligne)

**Aucune modification du serveur** n'est nécessaire. `handle_session_id()` existe déjà et fonctionne.

**Déploiement :** Aucun redéploiement requis.

#### Impacts Supabase (estimé : 0 ligne)

L'Edge Function `bobodo-chat` reçoit déjà le `session_id` via HTTP POST. Aucun changement.

---

### Plan de test de validation

1. **Test unitaire WS** : Connecter `ws://IP:8000/ws`, envoyer `{"type":"session_id","session_id":"test"}`, envoyer audio, vérifier que la transcription aboutit à un appel Bobodo.
2. **Test Flutter** : Lancer l'app, activer le mode vocal, parler, vérifier la réception de `audio_response`.
3. **Test reconnexion** : Couper le WiFi, le réactiver, vérifier que la conversation reprend.

---

## CONCLUSION OBLIGATOIRE

**Réponse : A — Envoyer `session_id` séparément.**

**Preuves :**
- Le code serveur `handle_session_id()` existe et attend ce message (fichier `websocket_handler.py:280`)
- Les pratiques industrielles (Gemini, OpenAI) utilisent une configuration initiale séparée
- Option A est la seule compatible avec les reconnections réseau
- Option A est la seule qui ne modifie pas le serveur (déjà prêt)
- Le coût d'implémentation Flutter est de 3 lignes de code
