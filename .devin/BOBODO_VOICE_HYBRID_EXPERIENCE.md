# BOBODO VOCAL - MODE HYBRIDE TEXTE + VOCAL

**Date** : 10 juin 2026  
**Statut** : ✅ TERMINÉ

---

## OBJECTIF

Vérifier que l'utilisateur pourra :
- Écrire uniquement
- Parler uniquement
- Écrire puis parler
- Parler puis écrire

Le même contexte conversationnel doit être conservé.
Le même historique doit être utilisé.
La même mémoire Bobodo doit être utilisée.

---

## ARCHITECTURE ACTUELLE BOBODO

### Flux texte (existant)

```
Flutter (texte) → BobodoProvider.sendUserMessage() → Edge Function bobodo-chat → Réponse
```

**Composants** :
- `BobodoProvider` : Gère session et messages
- `sendUserMessage()` : Envoie texte à Edge Function
- `bobodo-chat` : Edge Function Supabase (traitement IA)

**Stockage** :
- Session : `bobodo_sessions` (table Supabase)
- Messages : `bobodo_messages` (table Supabase)
- Mémoire : `bobodo_cross_session_memory` (table Supabase)

---

## ANALYSE DES SCÉNARIOS HYBRIDES

### Scénario 1 : Écrire uniquement

**Flux** :
```
Flutter (texte) → BobodoProvider.sendUserMessage() → Edge Function bobodo-chat → Réponse
```

**Implémentation** :
- ✅ Déjà implémenté
- ✅ Aucune modification requise

**Contexte** :
- ✅ Session conservée (`_currentSessionId`)
- ✅ Historique conservé (`_messages`)
- ✅ Mémoire Bobodo conservée (Edge Function)

---

### Scénario 2 : Parler uniquement

**Flux** :
```
Flutter (audio) → WebSocket → STT (Faster-Whisper) → Texte → BobodoProvider.sendUserMessage() → Edge Function bobodo-chat → Réponse → TTS (Piper) → WebSocket → Flutter (audio)
```

**Implémentation** :
- ⚠️ Nouveau composant WebSocket requis
- ⚠️ Nouveau composant STT requis
- ⚠️ Nouveau composant TTS requis
- ✅ `BobodoProvider.sendUserMessage()` réutilisé

**Contexte** :
- ✅ Session conservée (même `session_id`)
- ✅ Historique conservé (même `session_id`)
- ✅ Mémoire Bobodo conservée (Edge Function indépendante de la source)

**Justification** :
- L'Edge Function `bobodo-chat` reçoit du texte via HTTP POST
- Elle ne sait pas si le texte vient de STT ou de saisie clavier
- Le `session_id` est identique dans tous les cas
- L'historique est stocké dans `bobodo_messages` avec le même `session_id`

---

### Scénario 3 : Écrire puis parler

**Flux** :
```
Message 1 (texte) → BobodoProvider.sendUserMessage() → Edge Function bobodo-chat → Réponse
Message 2 (audio) → WebSocket → STT → Texte → BobodoProvider.sendUserMessage() → Edge Function bobodo-chat → Réponse → TTS → WebSocket → Flutter (audio)
```

**Implémentation** :
- ✅ Message 1 : déjà implémenté
- ⚠️ Message 2 : nouveau composant WebSocket requis
- ✅ `BobodoProvider.sendUserMessage()` réutilisé pour les deux

**Contexte** :
- ✅ Session conservée (même `session_id`)
- ✅ Historique conservé (messages ajoutés séquentiellement)
- ✅ Mémoire Bobodo conservée (Edge Function charge l'historique complet)

**Justification** :
- Le `session_id` ne change pas entre les messages
- L'historique est chargé via `app_list_bobodo_messages(session_id)`
- L'Edge Function charge l'historique complet avant de générer la réponse
- La mémoire cross-session est chargée via `loadCrossSessionMemory()`

---

### Scénario 4 : Parler puis écrire

**Flux** :
```
Message 1 (audio) → WebSocket → STT → Texte → BobodoProvider.sendUserMessage() → Edge Function bobodo-chat → Réponse → TTS → WebSocket → Flutter (audio)
Message 2 (texte) → BobodoProvider.sendUserMessage() → Edge Function bobodo-chat → Réponse
```

**Implémentation** :
- ⚠️ Message 1 : nouveau composant WebSocket requis
- ✅ Message 2 : déjà implémenté
- ✅ `BobodoProvider.sendUserMessage()` réutilisé pour les deux

**Contexte** :
- ✅ Session conservée (même `session_id`)
- ✅ Historique conservé (messages ajoutés séquentiellement)
- ✅ Mémoire Bobodo conservée (Edge Function charge l'historique complet)

**Justification** :
- Le `session_id` ne change pas entre les messages
- L'historique est chargé via `app_list_bobodo_messages(session_id)`
- L'Edge Function charge l'historique complet avant de générer la réponse
- La mémoire cross-session est chargée via `loadCrossSessionMemory()`

---

## VÉRIFICATION TECHNIQUE

### Edge Function bobodo-chat

**Code analysé** : `supabase/functions/bobodo-chat/index.ts`

**Chargement historique** :
```typescript
const { data: history } = await supabaseService
  .rpc('app_list_bobodo_messages', {
    p_session_id: sessionId,
  });
```

**Chargement mémoire cross-session** :
```typescript
const memory = await loadCrossSessionMemory(supabaseForUser, sessionId);
```

**Chargement profil étudiant** :
```typescript
const profile = await loadStudentProfile(supabaseForUser, sessionId);
```

**Conclusion** :
- ✅ L'Edge Function charge l'historique complet via `session_id`
- ✅ L'Edge Function charge la mémoire cross-session via `session_id`
- ✅ L'Edge Function charge le profil étudiant via `session_id`
- ✅ La source du texte (STT ou clavier) n'a aucun impact

---

### BobodoProvider

**Code analysé** : `academia_app/lib/providers/bobodo_provider.dart`

**Gestion session** :
```dart
String? _currentSessionId;
```

**Gestion messages** :
```dart
final List<Map<String, dynamic>> _messages = [];
```

**Envoi message** :
```dart
Future<void> sendUserMessage(String content) async {
  // 1) S'assurer qu'une session existe
  // 2) Ajouter le message en local
  // 3) Appeler Edge Function
}
```

**Conclusion** :
- ✅ La session est stockée dans `_currentSessionId`
- ✅ Les messages sont stockés dans `_messages`
- ✅ L'envoi de message utilise `sendUserMessage(content)` indépendamment de la source
- ✅ La source du texte (STT ou clavier) n'a aucun impact

---

## MODIFICATIONS REQUISES

### Aucune modification requise pour l'hybridité

**Edge Function bobodo-chat** :
- ✅ Aucune modification requise
- ✅ Reçoit du texte via HTTP POST
- ✅ Indépendante de la source

**BobodoProvider** :
- ✅ Aucune modification requise
- ✅ `sendUserMessage()` réutilisable
- ✅ Session et historique déjà gérés

**Nouveaux composants** :
- ⚠️ WebSocket client (Flutter)
- ⚠️ WebSocket server (Kamatera)
- ⚠️ STT (Faster-Whisper)
- ⚠️ TTS (Piper)

**Intégration** :
- ⚠️ STT → `BobodoProvider.sendUserMessage(transcription)`
- ⚠️ TTS → Playback audio Flutter

---

## SCHÉMA D'INTÉGRATION HYBRIDE

```
┌─────────────────────────────────────────────────────────────┐
│ Flutter App                                                 │
│ ─ BobodoProvider (session, messages)                        │
│ ─ Mode texte : TextField → sendUserMessage()                │
│ ─ Mode vocal : Microphone → WebSocket → STT → sendUserMessage() │
│ ─ Mode mixte : Alternance texte/vocal                      │
└──────────┬──────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│ Edge Function bobodo-chat (inchangée)                       │
│ ─ Charge historique (session_id)                            │
│ ─ Charge mémoire cross-session (session_id)                  │
│ ─ Charge profil étudiant (session_id)                       │
│ ─ Génère réponse (indépendante de la source)                │
└─────────────────────────────────────────────────────────────┘
```

---

## TESTS DE VALIDATION

### Test 1 : Contexte conversationnel

**Scénario** :
1. Utilisateur écrit : "Comment accéder aux cours d'appui ?"
2. Bobodo répond (texte)
3. Utilisateur parle : "Et pour les TD ?"
4. Bobodo répond (audio)

**Attendu** :
- ✅ Bobodo comprend "Et pour les TD ?" dans le contexte des cours d'appui
- ✅ L'historique contient les 4 messages (2 utilisateur, 2 Bobodo)
- ✅ La session est identique

---

### Test 2 : Historique complet

**Scénario** :
1. Utilisateur parle : "Bonjour"
2. Bobodo répond (audio)
3. Utilisateur écrit : "Comment ça va ?"
4. Bobodo répond (texte)
5. Utilisateur parle : "Merci"
6. Bobodo répond (audio)

**Attendu** :
- ✅ L'historique contient les 6 messages
- ✅ L'historique est visible dans l'UI
- ✅ L'historique est chargé au prochain lancement

---

### Test 3 : Mémoire cross-session

**Scénario** :
1. Session 1 : Utilisateur parle "Je m'appelle Jean"
2. Session 1 terminée
3. Session 2 : Utilisateur écrit "Comment je m'appelle ?"

**Attendu** :
- ✅ Bobodo répond "Tu t'appelles Jean"
- ✅ La mémoire cross-session est conservée
- ✅ La source (vocal/texte) n'a aucun impact

---

### Test 4 : Profil étudiant

**Scénario** :
1. Utilisateur parle "Quels sont mes cours ?"
2. Bobodo répond (audio) avec les cours de l'étudiant

**Attendu** :
- ✅ Bobodo utilise le profil étudiant
- ✅ La source (vocal) n'a aucun impact

---

## CONCLUSION

### Hybridité : ✅ VALIDÉE

**Scénarios supportés** :
- ✅ Écrire uniquement
- ✅ Parler uniquement
- ✅ Écrire puis parler
- ✅ Parler puis écrire

**Contexte conversationnel** :
- ✅ Conservé (même `session_id`)
- ✅ Historique complet
- ✅ Mémoire Bobodo

**Modifications requises** :
- ✅ Aucune modification de l'Edge Function
- ✅ Aucune modification de BobodoProvider
- ⚠️ Nouveaux composants WebSocket/STT/TTS

**Justification technique** :
- L'Edge Function `bobodo-chat` reçoit du texte via HTTP POST
- Elle est indépendante de la source (STT ou clavier)
- Le `session_id` est identique dans tous les cas
- L'historique et la mémoire sont gérés par l'Edge Function

---

**DOCUMENT TERMINÉ**
