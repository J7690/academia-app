# BOBODO — Audit de Fiabilité Fonctionnelle

**Date**: 2025-06-15  
**Périmètre**: Flutter Provider + Edge Function + Supabase RPC  
**Méthode**: Analyse du code source avec traçage du flux de données

---

## MISSION 1 — DIAGNOSTIC DUPLICATION DES MESSAGES

### Flux complet d'un envoi de message (quand sessionId EXISTE déjà)

```
sendUserMessage(content) [bobodo_provider.dart:136]
│
├── sessionId != null → branche ELSE (ligne 163)
│
├── ÉTAPE A: await loadMessages() [ligne 167]
│   → RPC app_list_bobodo_messages → retourne TOUS les messages de la session
│   → _messages.clear() + addAll(data)
│   → _shouldScrollToBottom = true
│   → notifyListeners() ←──── UI REBUILD #1
│
├── ÉTAPE B: _messages.add({sender:'student', content}) [ligne 181]
│   → Ajout LOCAL d'un message avec id: null
│   → notifyListeners() ←──── UI REBUILD #2
│
├── ÉTAPE C: await _callEdgeFunction(content) [ligne 191]
│   ├── _setLoading(true) → notifyListeners() ←──── UI REBUILD #3
│   │
│   ├── HTTP POST /bobodo-chat
│   │   └── Edge Function:
│   │       ├── app_append_bobodo_message(student) → INSERT Supabase
│   │       ├── ... IA traitement ...
│   │       └── app_append_bobodo_message(assistant) → INSERT Supabase
│   │
│   ├── _setLoading(false) → notifyListeners() ←──── UI REBUILD #4
│   │
│   └── if (backendOk):
│       └── ÉTAPE D: await loadMessages() [ligne 248]
│           → RPC app_list_bobodo_messages → retourne TOUS les messages
│           → _messages.clear() + addAll(data)  ← ÉCRASE tout (y compris le local)
│           → notifyListeners() ←──── UI REBUILD #5
```

### Source EXACTE de la duplication

**La duplication est VISUELLE et TRANSITOIRE, mais elle existe réellement dans `_messages` entre les étapes B et D.**

**Preuve** :

1. **ÉTAPE A** (ligne 167) : `loadMessages()` charge les messages existants. Supposons qu'il y a [msg1, réponse1] dans la session.
   - `_messages = [msg1, réponse1]`

2. **ÉTAPE B** (ligne 181) : Ajout local du nouveau message.
   - `_messages = [msg1, réponse1, msg2_local(id:null)]`
   - `notifyListeners()` → UI affiche 3 messages

3. **ÉTAPE C** : Edge Function insère `msg2` dans Supabase (avec un vrai UUID).

4. **ÉTAPE D** (ligne 248) : `loadMessages()` recharge tout depuis Supabase.
   - `_messages.clear()` → vide
   - `_messages = [msg1, réponse1, msg2_supabase(id:uuid), réponse2]`
   - **Le msg2_local(id:null) est remplacé par msg2_supabase(id:uuid)** → OK, pas de doublon final

**MAIS** : Entre ÉTAPE A et ÉTAPE D, il y a un scénario de doublon :

Si le message envoyé est IDENTIQUE à un message déjà existant dans la session (ex: l'utilisateur dit "Bonjour" deux fois), alors après ÉTAPE A :
- `_messages` contient déjà le premier "Bonjour" (chargé de Supabase)
- ÉTAPE B ajoute un second "Bonjour" local
- L'UI montre deux "Bonjour" ← **DOUBLON VISIBLE**
- ÉTAPE D corrige en rechargeant tout

**SCÉNARIO DE DOUBLON PERSISTANT** :

Il n'y a **PAS** de doublon persistant dans Supabase. L'Edge Function n'insère qu'UNE fois. Le doublon est uniquement **transitoire dans le Provider Flutter**.

### Le loadMessages() de validation (ligne 167) — VRAI PROBLÈME

Ce `loadMessages()` est problématique :
1. Il recharge TOUT avant l'ajout local → affiche des messages anciens + provoque un flash UI
2. Il est INUTILE fonctionnellement : il ne vérifie pas la validité de la session (il charge juste les messages)
3. En cas d'erreur, il crée une session → le message original est envoyé dans une NOUVELLE session, pas l'ancienne

### Verdict duplication

| Question | Réponse | Preuve |
|----------|---------|--------|
| Le doublon est uniquement visuel ? | **OUI** (transitoire) | `_messages.clear()` à l'étape D nettoie |
| Le doublon existe dans Supabase ? | **NON** | L'Edge Function n'a qu'UN `app_append_bobodo_message(student)` par appel |
| Le doublon provient du Provider ? | **OUI** | L'ajout local (181) + loadMessages (167) combinés |
| Le doublon provient de l'Edge Function ? | **NON** | Une seule insertion par invocation |
| Le doublon provient d'un double rebuild ? | **OUI** (5 rebuilds par envoi) | 5 `notifyListeners()` successifs |
| Le doublon provient du mode conversation ? | **INDIRECTEMENT** | En mode conversation, les envois sont rapides et se chevauchent |

---

## MISSION 2 — DIAGNOSTIC ERREUR D'ENREGISTREMENT

### Source du message

**Fichier** : `supabase/functions/bobodo-chat/index.ts` ligne 1458  
**Message exact** : `"Erreur lors de lenregistrement du message étudiant."` (note : faute de frappe, "l'enregistrement" sans apostrophe)

### Fonction concernée

```typescript
// Ligne 1450-1461
const { error: appendStudentError } = await supabaseForUser.rpc('app_append_bobodo_message', {
  p_session_id: sessionId,
  p_sender: 'student',
  p_content: message,
  p_safety_flag: null,
});
```

### RPC concernée

`app_append_bobodo_message` (SQL, `.devin/supabase_bobodo.sql` lignes 174-193) :
```sql
INSERT INTO app.bobodo_messages (session_id, sender, content, safety_flag)
VALUES (p_session_id, p_sender, p_content, p_safety_flag)
RETURNING id INTO v_message_id;
```

### Cas qui produisent cette erreur

| # | Cause | Probabilité | Explication |
|---|-------|:-----------:|-------------|
| 1 | **Session inexistante** | Élevée | Le `session_id` stocké dans SharedPreferences ne correspond à aucune session en base (supprimée, autre environnement) |
| 2 | **Contrainte FK violée** | Élevée | Foreign key `bobodo_messages.session_id` → `bobodo_sessions.id` échoue si la session n'existe pas |
| 3 | **RLS refus** | Moyenne | La fonction est `SECURITY DEFINER` mais utilise `supabaseForUser` (JWT). Si RLS bloque l'accès au student_id de la session |
| 4 | **JWT expiré** | Faible | Token Supabase expiré entre le début de l'appel et l'exécution RPC |
| 5 | **Contenu trop long** | Très faible | Message excédant la taille max du champ TEXT (improbable) |

### La cause la plus probable

La cause la plus probable est le **cas 1/2** : La session stockée dans SharedPreferences est invalide. Cela arrive quand :
- L'utilisateur change d'appareil
- La session a été supprimée côté admin
- L'environnement de test a été réinitialisé
- Le `session_id` est corrompu

### Conséquences

| Aspect | Conséquence |
|--------|-------------|
| **Métier** | Le message de l'étudiant est PERDU. Il n'est jamais enregistré ni côté Flutter (le local reste en mémoire volatile) ni côté Supabase. |
| **UX** | Barre rouge avec message d'erreur. En mode conversation, l'écoute est relancée mais le message est perdu. |
| **Historique** | Le message n'apparaîtra JAMAIS dans l'historique de la session. |
| **Récupération** | Le provider stocke `_lastFailedMessage = content` (ligne 235). Le bouton "Réessayer" dans la barre d'erreur permet de relancer (`retryLastFailed()` ligne 316). |

### Le message est-il réellement perdu ?

**OUI si l'utilisateur ne clique pas sur "Réessayer".** En mode conversation vocale, il n'y a PAS de bouton "Réessayer" visible (la barre d'erreur est masquée par les contrôles de conversation ou non remarquée).

**En mode texte** : le bouton "Réessayer" est visible dans la barre d'erreur (ligne 958-969).

---

## MISSION 3 — INTÉGRITÉ DE L'HISTORIQUE

### Cartographie complète du flux de données

```
FLUTTER (Provider)                    EDGE FUNCTION                     SUPABASE
─────────────────                     ──────────────                    ────────
1. _messages.add(local, id:null)      
   → notifyListeners()                
                                      
2. HTTP POST {session_id, message}    
                                      3. app_append_bobodo_message       
                                         (student)                       → INSERT bobodo_messages
                                      
                                      4. ... IA processing ...
                                      
                                      5. app_append_bobodo_message       
                                         (assistant)                     → INSERT bobodo_messages
                                      
                                      6. HTTP 200 {reply: "..."}
                                      
7. loadMessages()                     
   → RPC app_list_bobodo_messages                                       → SELECT * ORDER BY created_at
   → _messages.clear() + addAll       
   → notifyListeners()
```

### Vérifications d'intégrité

| Vérification | Résultat | Preuve |
|-------------|----------|--------|
| Chaque message étudiant sauvegardé ? | ✅ OUI (si pas d'erreur RPC) | Edge Function ligne 1450: `app_append_bobodo_message(student)` |
| Chaque réponse Bobodo sauvegardée ? | ✅ OUI (si pas d'erreur RPC) | Edge Function ligne 1602: `app_append_bobodo_message(assistant)` |
| Messages perdus possibles ? | ⚠️ OUI | Si `appendStudentError` (erreur RPC), le message est perdu |
| Messages dupliqués en base ? | ❌ NON | Un seul INSERT par appel Edge Function |
| Messages réordonnés ? | ❌ NON | `ORDER BY m.created_at ASC` dans la RPC (SQL ligne 154) |
| Cohérence Flutter/Supabase ? | ⚠️ PARTIELLE | Entre ajout local et reload, il y a un état incohérent |

### Faille d'intégrité identifiée

**Le message local (id:null) et le message Supabase (id:uuid) coexistent brièvement.** Le `loadMessages()` final corrige cela. MAIS si le processus est interrompu (app tuée, réseau coupé pendant l'attente), le message local est perdu car :
- Il n'est pas persisté localement
- Il n'est pas dans Supabase (l'Edge Function n'a pas encore été appelée ou a échoué)

---

## MISSION 4 — MODE CONVERSATION VOCALE — RISQUES DE DOUBLES

### Peut-il y avoir un double envoi ?

**OUI — dans un scénario spécifique.**

**Scénario** : `_onTranscriptionReceived()` (ligne 1401) utilise `await provider.sendUserMessage(text)`. Pendant cet `await`, si un **barge-in** se produit (l'utilisateur parle pendant que Bobodo répond au message précédent), deux `_onTranscriptionReceived()` peuvent s'exécuter en parallèle.

**Preuve** : Le callback `_handleSpeechResult()` (ligne 1337) appelle `_onTranscriptionReceived()` sans vérifier si un envoi est déjà en cours. Il n'y a pas de mutex, de flag `_isSending`, ni de queue.

**MAIS** : En pratique, la séquence est :
1. Utilisateur parle → STT → transcription → `_onTranscriptionReceived()`
2. `_isConversationMode` et `await sendUserMessage()` bloquent la suite
3. Pendant le `await`, le STT est ARRÊTÉ (car `_stopVocalRecording()` est appelé à ligne 1340)
4. La relance d'écoute (`_startVocalRecording()`) ne se produit qu'APRÈS le `await` complet

**Conclusion** : Le barge-in (lignes 1403-1408) n'arrive que si `_isSpeaking == true` au moment de `_onTranscriptionReceived()`. Cela signifie que le TTS est en cours. L'arrêt du TTS déclenche `_onAudioPlaybackComplete()` → relance écoute. Mais à ce moment, le premier `await sendUserMessage()` est toujours en cours.

**RISQUE RÉEL** : Le barge-in pendant un TTS peut théoriquement déclencher un second `_startVocalRecording()` via `_onAudioPlaybackComplete()` PENDANT que le premier `sendUserMessage()` est toujours en attente. Le résultat d'écoute du second STT appelerait un SECOND `_onTranscriptionReceived()`.

**Gravité** : Faible en pratique (le timing doit être exact), mais possible.

### Peut-il y avoir un double appel Edge Function ?

**OUI** — si le scénario de barge-in ci-dessus se produit, deux `_callEdgeFunction()` seraient appelés avec des messages différents. Ce n'est pas un doublon au sens strict (deux messages différents), mais une race condition.

### Peut-il y avoir une double insertion Supabase ?

**NON pour un même message** — Chaque appel Edge Function fait UN `app_append_bobodo_message`. Pas de mécanisme de retry dans l'Edge Function.

### Peut-il y avoir un double chargement de messages ?

**OUI** — Le `loadMessages()` de la ligne 167 (validation) + le `loadMessages()` de la ligne 248 (post-succès) font DEUX chargements par envoi. En mode conversation rapide, les chargements se superposent.

---

## MISSION 5 — PRIORISATION

### P0 — Risque de perte de données

| # | Problème | Impact | Correction |
|---|----------|--------|-----------|
| P0-1 | **Erreur RPC perd le message sans récupération en mode vocal** | Message étudiant perdu définitivement si session invalide | Valider la session AVANT envoi, ou créer une nouvelle session en cas d'erreur |
| P0-2 | **Session SharedPreferences invalide** | Tous les envois échouent jusqu'à ce que l'utilisateur crée une nouvelle conversation | Détecter l'erreur et invalider la session stockée |

### P1 — Risque de duplication

| # | Problème | Impact | Correction |
|---|----------|--------|-----------|
| P1-1 | **loadMessages() inutile à ligne 167** | Flash visuel de duplication + 2 rebuilds inutiles + état intermédiaire incohérent | Supprimer ce loadMessages() (3 lignes) |
| P1-2 | **5 notifyListeners() par envoi** | Flickering UI, rebuilds excessifs | Regrouper les notifications |
| P1-3 | **Barge-in peut déclencher double envoi** | Deux messages envoyés rapidement en parallèle | Ajouter un flag `_isProcessingConversation` |

### P2 — Risque UX

| # | Problème | Impact |
|---|----------|--------|
| P2-1 | Pas de feedback visuel pendant l'écoute | L'utilisateur ne sait pas si sa voix est captée |
| P2-2 | Transcription non affichée | L'utilisateur ne voit pas ce que Bobodo a compris |
| P2-3 | Reprise d'écoute silencieuse | L'utilisateur ne sait pas quand reparler |

### P3 — Amélioration visuelle

| # | Problème | Impact |
|---|----------|--------|
| P3-1 | Bouton header non identifiable | Découvrabilité du mode |
| P3-2 | Animation pulsante absente | Feedback de captation |
| P3-3 | États `processing`/`responding` inutilisés | Code mort |

---

## ESTIMATION DES CORRECTIFS

| Priorité | Fichier | Action | Lignes |
|----------|---------|--------|--------|
| P0-1 | `bobodo_provider.dart` | Après erreur `appendStudent`, invalider session + recréer | ~10 |
| P0-2 | `bobodo_provider.dart` | Dans le catch de `sendUserMessage`, effacer la session invalide | ~5 |
| P1-1 | `bobodo_provider.dart` | Supprimer `await loadMessages()` ligne 167 (et le try/catch) | -5 lignes |
| P1-3 | `student_bobodo_tab.dart` | Ajouter flag `_isProcessingConversation` pour bloquer les envois concurrents | ~6 |
| P2-1 | `student_bobodo_tab.dart` | Afficher `_lastRecognizedWords` en temps réel | ~7 |
| P2-2 | `student_bobodo_tab.dart` | Vibration à la reprise | ~2 |

---

## RISQUE RÉEL POUR LE PILOTE

| Scénario | Probabilité | Impact | Verdict |
|----------|:-----------:|--------|---------|
| Perte de message (P0-1) | **Moyenne** | Élevé | ⛔ Bloquer si session invalide fréquent |
| Duplication visuelle (P1-1) | **Élevée** | Faible (transitoire) | ⚠️ Gênant mais non destructif |
| Double envoi barge-in (P1-3) | **Faible** | Moyen | ⚠️ Rare mais possible |
| UX incompréhensible (P2) | **Élevée** | Moyen | ⚠️ Freine l'adoption |

**Recommandation pour le pilote** :
1. Corriger P0 (perte de données) en priorité absolue
2. Corriger P1-1 (supprimer loadMessages inutile) — correction triviale, gain immédiat
3. Ajouter P1-3 (protection barge-in) — sécurité
4. Les corrections UX (P2/P3) peuvent être faites dans un second temps

---

**Aucune modification effectuée. Aucun patch. Aucune compilation.**

*Fin de l'audit de fiabilité.*
