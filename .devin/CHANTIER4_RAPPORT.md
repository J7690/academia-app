# CHANTIER 4 - MODE CONVERSATION CONTINUE

**Date** : 10 juin 2026  
**Objectif** : Valider que bobodo-chat gère le contexte/historique pour une conversation continue

---

## INFRASTRUCTURE EXISTANTE DANS BOBODO-CHAT

### 1. Historique de conversation
**Fonction** : `loadConversationHistoryForSession` (ligne 632)
- Charge les 14 derniers messages (7 échanges complets)
- Via RPC `app_list_bobodo_messages`
- Format : `ChatHistoryMessage[]` avec role ('user'/'assistant') et content
- Utilisé pour enrichir le prompt OpenRouter avec le contexte

**Code** :
```typescript
async function loadConversationHistoryForSession(
  supabaseForUser: ReturnType<typeof createClient>,
  sessionId: string,
  maxMessages = 14,
): Promise<ChatHistoryMessage[]>
```

### 2. Mémoire cross-session
**Fonction** : `loadCrossSessionMemory` (ligne 755)
- Récupère la mémoire cross-session via RPC `get_bobodo_cross_session_memory`
- Basée sur student_id (pas session_id)
- Permet de se souvenir des conversations précédentes

**Code** :
```typescript
async function loadCrossSessionMemory(
  supabaseForUser: ReturnType<typeof createClient>,
  sessionId: string,
): Promise<Record<string, unknown>>
```

### 3. Résumé de conversation
**Fonction** : `saveConversationSummary` (ligne 795)
- Génère un résumé via OpenRouter (2-3 phrases max)
- Identifie les intérêts, objectifs d'étude et préférences
- Sauvegarde via RPC `save_bobodo_conversation_memory`
- Déclenché automatiquement après 4+ messages

**Code** :
```typescript
async function saveConversationSummary(
  supabaseService: ReturnType<typeof createClient>,
  sessionId: string,
  history: ChatHistoryMessage[],
): Promise<void>
```

### 4. Profil étudiant
**Fonction** : `loadStudentProfile` (ligne 683)
- Récupère le profil étudiant complet
- Inclut : nom, série BAC, année BAC, mention, projet d'étude, pays, ville, bio
- Récupère les 5 candidatures récentes
- Injecté dans le prompt pour personnalisation

**Code** :
```typescript
async function loadStudentProfile(
  supabaseForUser: ReturnType<typeof createClient>,
  sessionId: string,
): Promise<Record<string, unknown>>
```

### 5. Détection état émotionnel
**Fonction** : `detectEmotionalState` (ligne 298)
- Détecte : neutral, frustrated, satisfied, follow_up
- Basé sur patterns de mots (pas d'appel IA)
- 4 couches de détection :
  1. Réactions ultra-courtes (oui, non, ok, waw)
  2. Confirmation/reformulation
  3. Message court avec point d'interrogation
  4. Message court en contexte actif

**Code** :
```typescript
function detectEmotionalState(
  message: string,
  history: ChatHistoryMessage[],
): 'neutral' | 'frustrated' | 'satisfied' | 'follow_up'
```

### 6. Cache sémantique
**Fonctions** :
- `checkAnswerCache` (ligne 473) : Vérifie si la question a déjà été répondue
- `registerCacheHit` (ligne 492) : Enregistre un hit de cache
- `saveAnswerToCache` (ligne 501) : Sauvegarde une nouvelle réponse

**Objectif** : Éviter les appels OpenRouter pour les questions déjà vues

---

## INTÉGRATION DANS LE FLOW PRINCIPAL

### OpenRouter avec historique
**Fonction** : `callOpenRouter` (ligne 160)
- Accepte un paramètre `history?: ChatHistoryMessage[]`
- L'historique est injecté dans le prompt OpenRouter
- Permet à l'IA de se souvenir du contexte de conversation

**Code** :
```typescript
async function callOpenRouter(
  prompt: string,
  knowledge: Array<Record<string, unknown>>,
  options?: {
    systemPrompt?: string | null;
    includeNoAnswerSentinel?: boolean;
    history?: ChatHistoryMessage[];
    max_tokens?: number;
  },
): Promise<string>
```

---

## ÉTAT DU CHANTIER 4

### ✅ Infrastructure en place
- Historique de conversation (14 messages)
- Mémoire cross-session
- Résumé automatique
- Profil étudiant
- Détection état émotionnel
- Cache sémantique
- Injection historique dans OpenRouter

### ⏸️ Validation requise
**Tests scénarios réels** :
1. Conversation continue sur plusieurs échanges
2. Validation des rebonds conversationnels
3. Test de la mémoire cross-session
4. Test de la détection émotionnelle
5. Test du cache sémantique

### ⚠️ Limitations actuelles
- Pas de tests réels effectués
- Pas de validation avec enregistrements audio
- Pas de tests avec accents BF/Afrique
- Pas de tests avec bruit ambiant

---

## RECOMMANDATIONS

### Pour valider le Chantier 4
1. **Créer des scénarios de test** :
   - Salutation simple
   - Orientation universitaire
   - Conversation de plusieurs minutes
   - Questions de suivi (follow-up)
   - Rebonds conversationnels

2. **Tester avec l'interface Flutter** :
   - Utiliser BobodoVocalButton
   - Enregistrer des échantillons audio
   - Vérifier la transcription
   - Vérifier la réponse Bobodo
   - Vérifier la synthèse vocale

3. **Mesurer les indicateurs** :
   - Latence STT
   - Latence TTS
   - Latence Bobodo-chat
   - Qualité transcription
   - Pertinence réponse
   - Fluidité conversation

---

## CONCLUSION

L'infrastructure pour le mode conversation continue est **déjà en place** dans bobodo-chat. Les fonctions nécessaires existent et sont intégrées dans le flow principal.

Le Chantier 4 nécessite des **tests fonctionnels réels** pour valider que l'infrastructure fonctionne correctement dans des scénarios d'utilisation réels.

---

**CHANTIER 4 - EN ATTENTE DE TESTS RÉELS**
