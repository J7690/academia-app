# AUDIT COMPLÉMENTAIRE BOBODO – MÉMOIRE ÉTUDIANTE ET PERSONNALITÉ CONVERSATIONNELLE

**Date**: 8 Juin 2026
**Objectif**: Cartographier précisément l'existant pour préparer une amélioration future de Bobodo
**Contrainte**: Aucune modification de code ou de données

---

# RÉSUMÉ EXÉCUTIF

Bobodo dispose d'une **architecture conversationnelle solide** mais limitée pour devenir un véritable compagnon étudiant conversationnel.

**Points forts** :
- Historique conversationnel fonctionnel (14 messages max)
- Détection émotionnelle avancée (6 états)
- Instructions contextuelles par état émotionnel
- Cache sémantique pour optimiser les réponses
- Salutation personnalisée avec prénom

**Points critiques** :
- ❌ Aucune mémoire cross-session
- ❌ Aucun profil étudiant injecté dans le prompt
- ❌ Aucun résumé automatique des conversations longues
- ❌ Aucune mémoire persistante de profil conversationnel
- ❌ Données étudiant disponibles mais non utilisées

---

# PHASE 1 – AUDIT DE LA MÉMOIRE CONVERSATIONNELLE

## 1. Combien de messages sont réellement chargés dans une conversation ?

**Réponse** : **14 messages maximum** (7 échanges complets)

**Preuve** : `loadConversationHistoryForSession` (bobodo-chat/index.ts ligne 631-679)
```typescript
async function loadConversationHistoryForSession(
  supabaseForUser: ReturnType<typeof createClient>,
  sessionId: string,
  maxMessages = 14,  // ← Limite fixe
): Promise<ChatHistoryMessage[]>
```

**Statistiques réelles** :
- Total sessions : 108
- Étudiants uniques : 13
- Moyenne messages/session : 5.5

---

## 2. Combien de messages sont réellement injectés dans le prompt envoyé au LLM ?

**Réponse** : **Tous les messages chargés** (jusqu'à 14)

**Preuve** : `callOpenRouter` (bobodo-chat/index.ts ligne 160-278)
```typescript
async function callOpenRouter(
  prompt: string,
  knowledge: Array<Record<string, unknown>>,
  options?: {
    systemPrompt?: string | null;
    includeNoAnswerSentinel?: boolean;
    history?: ChatHistoryMessage[];  // ← Historique complet injecté
    max_tokens?: number;
  },
): Promise<string>
```

---

## 3. Existe-t-il un système de résumé automatique des conversations longues ?

**Réponse** : **❌ NON**

**Preuve** : Aucune fonction de résumé dans le code. L'historique est simplement tronqué à 14 messages sans compensation.

**Conséquence** : Au-delà de 7 échanges, les messages les plus anciens sont perdus définitivement.

---

## 4. Existe-t-il une mémoire persistante différente de l'historique brut ?

**Réponse** : **❌ NON**

**Preuve** : Aucune table de mémoire persistante n'existe :
- ❌ `app.bobodo_conversation_memory` n'existe pas
- ❌ `app.bobodo_student_profile` n'existe pas
- ❌ `app.bobodo_user_preferences` n'existe pas
- ❌ `app.bobodo_context_store` n'existe pas

**Seul le cache sémantique existe** : `app.bobodo_answer_cache` (stocke les réponses déjà générées pour éviter les appels OpenRouter).

---

## 5. Existe-t-il une table de profil conversationnel ?

**Réponse** : **❌ NON**

**Preuve** : Aucune table dédiée au profil conversationnel. Les tables existantes sont :
- `app.bobodo_sessions` (id, student_id, title, created_at, updated_at)
- `app.bobodo_messages` (id, session_id, sender, content, safety_flag, created_at)

Aucune colonne de profil, préférences ou contexte conversationnel.

---

## 6. Existe-t-il un stockage des informations importantes détectées ?

**Réponse** : **✅ OUI (partiel)**

**Table** : `app.bobodo_detected_needs`

**Colonnes** :
- `session_id`
- `question_text`
- `category` (NEXIOM_ACADEMIA_INTERNE, ORIENTATION_ETUDES_EMPLOI, etc.)
- `need_summary` (résumé du besoin généré par IA)
- `created_at`

**Limitation** : Stocke uniquement les besoins détectés, pas le profil complet de l'étudiant.

---

## 7. Existe-t-il une conservation des informations entre plusieurs sessions ?

**Réponse** : **❌ NON**

**Preuve** : `app.bobodo_sessions` est isolé par `session_id`. Aucun lien entre sessions du même étudiant. Aucun stockage cross-session.

---

## 8. Lorsqu'un étudiant revient plusieurs jours plus tard :

### Bobodo se souvient-il de lui ?

**Réponse** : **❌ NON**

**Comment** :
- Le prénom est récupéré via `app_get_bobodo_student_first_name` (si premier message de la session)
- Mais l'historique de conversation est perdu (nouvelle session = nouvel historique)
- Aucune mémoire des conversations précédentes

---

## 9. Schéma exact du flux

```
Utilisateur → message
    ↓
Edge Function bobodo-chat
    ↓
1. Enregistrer message dans app.bobodo_messages
    ↓
2. Charger historique via app_list_bobodo_messages (max 14 messages)
    ↓
3. Vérifier cache sémantique (app.bobodo_answer_cache)
    ↓
4. Recherche RAG (app.bobodo_knowledge)
    ↓
5. Classification (catégorie + intention)
    ↓
6. Génération réponse via OpenRouter
    - Prompt système maître (10 règles)
    - Instruction contextuelle (selon état émotionnel)
    - Historique (jusqu'à 14 messages)
    - Connaissance RAG
    ↓
7. Enrichissement salutation (si premier message)
    - Récupérer prénom via app_get_bobodo_student_first_name
    - Ajouter préfixe "Bonjour {prénom}, on se rencontre..."
    ↓
8. Enregistrer réponse dans app.bobodo_messages
    ↓
Utilisateur ← réponse
```

---

# PHASE 2 – AUDIT DU PROFIL ÉTUDIANT

## Données disponibles dans app.students

| Colonne | Type | Bobodo l'utilise ? |
|---------|------|-------------------|
| id | uuid | ❌ NON |
| full_name | text | ✅ OUI (prénom pour salutation) |
| phone | text | ❌ NON |
| country | text | ❌ NON |
| city | text | ❌ NON |
| date_of_birth | date | ❌ NON |
| avatar_url | text | ❌ NON |
| bepc_year | integer | ❌ NON |
| bepc_institution | text | ❌ NON |
| bepc_country | text | ❌ NON |
| bepc_mention | text | ❌ NON |
| bac_year | integer | ❌ NON |
| bac_series | text | ❌ NON |
| bac_mention | text | ❌ NON |
| bac_institution | text | ❌ NON |
| bac_country | text | ❌ NON |
| study_project_text | text | ❌ NON |
| timezone | text | ❌ NON |
| geo_latitude | numeric | ❌ NON |
| geo_longitude | numeric | ❌ NON |
| bio | text | ❌ NON |
| website_url | text | ❌ NON |

## Données disponibles dans app.applications

| Colonne | Type | Bobodo l'utilise ? |
|---------|------|-------------------|
| id | uuid | ❌ NON |
| student_id | uuid | ❌ NON |
| university_id | uuid | ❌ NON |
| program_id | uuid | ❌ NON |
| status | text | ❌ NON |
| created_at | timestamp | ❌ NON |

## Réponse par information demandée

| Information | Source | Table | Colonne | Fréquence d'utilisation | Présence dans prompt final |
|-------------|--------|-------|---------|------------------------|-------------------------|
| Niveau d'étude | ❌ Bobodo n'utilise pas cette donnée | app.students | bepc_year, bac_year | Jamais | ❌ NON |
| Série du bac | ❌ Bobodo n'utilise pas cette donnée | app.students | bac_series | Jamais | ❌ NON |
| Moyenne | ❌ Bobodo n'utilise pas cette donnée | N/A | N/A | Jamais | ❌ NON |
| Université | ❌ Bobodo n'utilise pas cette donnée | app.applications | university_id | Jamais | ❌ NON |
| Filière | ❌ Bobodo n'utilise pas cette donnée | app.applications | program_id | Jamais | ❌ NON |
| Centre d'intérêt | ❌ Bobodo n'utilise pas cette donnée | N/A | N/A | Jamais | ❌ NON |
| Projet professionnel | ❌ Bobodo n'utilise pas cette donnée | app.students | study_project_text | Jamais | ❌ NON |
| Candidatures Academia | ❌ Bobodo n'utilise pas cette donnée | app.applications | status | Jamais | ❌ NON |
| Programmes favoris | ❌ Bobodo n'utilise pas cette donnée | N/A | N/A | Jamais | ❌ NON |
| Historique d'orientation | ❌ Bobodo n'utilise pas cette donnée | app.bobodo_detected_needs | need_summary | Partiel (besoins détectés) | ❌ NON |

---

# PHASE 3 – AUDIT DE LA PERSONNALITÉ CONVERSATIONNELLE

## Prompt système maître (10 règles)

**Source** : bobodo-chat/index.ts lignes 899-927

1. **COMPRÉHENSION SÉMANTIQUE** : Comprendre l'intention même si mal formulée
2. **SUIVI CONTEXTUEL** : Connecter les réponses courtes au dernier message
3. **FRUSTRATION** : Reformuler avec "Permettez-moi d'expliquer autrement :"
4. **SATISFACTION** : Répondre chaleureusement en 1-2 phrases
5. **FIN DE RÉPONSE** : Terminer par "Y a-t-il autre chose sur lequel je peux t'aider ?"
6. **HORS DOMAINE** : Rediriger vers support@nexiom.com
7. **UNIVERSITÉS** : Rediriger vers l'onglet Universités
8. **STYLE** : Français clair, professionnel, chaleureux (2-3 phrases max pour simple, 7 max pour complexe)
9. **SALUTATIONS** : Ne jamais commencer par "Bonjour", "Bonsoir", "Salut"
10. **CONFIRMATION** : Confirmer en 1-2 phrases sans répéter tout

## Instructions contextuelles par état émotionnel

| État | Instruction | max_tokens |
|------|-------------|------------|
| greeting | Réponds naturellement et chaleureusement en 1-2 phrases. Présente-toi brièvement si c'est le début, puis propose ton aide. | 200 |
| emotional | Fais preuve d'empathie en 1-2 phrases, puis propose ton aide de façon bienveillante. | 200 |
| frustrated | REFORMULE ta réponse précédente différemment, plus simplement, avec un exemple concret. Commence par "Permettez-moi d'expliquer autrement :" | 500 |
| satisfied | Réponds chaleureusement en 1-2 phrases et propose ton aide pour autre chose. Ne développe pas de nouveau contenu. | 150 |
| confirmation | Confirme simplement en 1-2 phrases ("Oui, exactement !", "C'est bien ça !") et propose de continuer. NE RÉPÈTE PAS tout le contenu. | 600 |
| follow_up | Utilise jusqu'à 2 messages précédents de Bobodo pour le contexte. Réponds directement et brièvement (1-3 phrases max). | 600 |

## Détection émotionnelle (6 couches)

**Source** : `detectEmotionalState` (lignes 298-372)

1. **Réactions à un seul mot** (oui, non, ok, waw, vraiment?, etc.) → `follow_up`
2. **Confirmation/reformulation** (ah ok, donc c'est, si je comprends bien, etc.) → `follow_up`
3. **Message court avec '?'** (<80 chars) → `follow_up`
4. **Message court en contexte actif** (<100 chars, history >= 2) → `follow_up`
5. **Frustration** (pas clair, pas compris, reformule, etc.) → `frustrated`
6. **Satisfaction** (merci, super, parfait, etc.) → `satisfied`
7. **Défaut** → `neutral`

## Réponses aux questions

### 1. Bobodo peut-il féliciter spontanément un étudiant ?

**Réponse** : ❌ **NON**

**Preuve** : Aucune règle de félicitation spontanée. La règle 4 (SATISFACTION) réagit à l'expression de satisfaction de l'étudiant, mais ne félicite pas spontanément une réussite académique.

### 2. Bobodo peut-il encourager un étudiant en difficulté ?

**Réponse** : ✅ **OUI (limité)**

**Preuve** : Règle 3 (FRUSTRATION) + instruction contextuelle `emotional` ("Fais preuve d'empathie"). Mais cela réagit à l'expression de frustration, pas à une difficulté détectée automatiquement.

### 3. Bobodo peut-il détecter une réussite académique ?

**Réponse** : ❌ **NON**

**Preuve** : Aucune détection de réussite académique. Les données étudiant (moyenne, mentions, etc.) ne sont pas injectées dans le prompt.

### 4. Bobodo peut-il relancer naturellement une discussion ?

**Réponse** : ✅ **OUI**

**Preuve** : Règle 5 (FIN DE RÉPONSE) force systématiquement une question d'engagement ("Y a-t-il autre chose sur lequel je peux t'aider ?").

### 5. Bobodo peut-il poser des questions de découverte du profil ?

**Réponse** : ❌ **NON**

**Preuve** : Aucune règle de découverte de profil. Bobodo répond aux questions mais n'en pose pas spontanément pour apprendre à connaître l'étudiant.

### 6. Bobodo peut-il poursuivre une conversation sur plusieurs échanges sans perdre le contexte ?

**Réponse** : ✅ **OUI (limité à 14 messages)**

**Preuve** : Historique de 14 messages injecté dans le prompt. Au-delà, le contexte est perdu.

### 7. Bobodo dispose-t-il d'un mécanisme de mémoire émotionnelle ?

**Réponse** : ❌ **NON**

**Preuve** : L'état émotionnel est détecté à chaque message mais n'est pas stocké entre les messages ou les sessions.

---

# PHASE 4 – AUDIT DES SALUTATIONS

## Tests théoriques

| Message | Catégorie détectée | Intention détectée | Prompt final | Réponse attendue | Message système injecté |
|---------|-------------------|-------------------|--------------|-----------------|------------------------|
| bonjour | SMALL_TALK_EMOTION | greeting | instruction contextuelle greeting | 1-2 phrases chaleureuses + présentation si premier message | Préfixe salutation enrichi si premier message |
| salut | SMALL_TALK_EMOTION | greeting | instruction contextuelle greeting | 1-2 phrases chaleureuses + présentation si premier message | Préfixe salutation enrichi si premier message |
| coucou | SMALL_TALK_EMOTION | greeting | instruction contextuelle greeting | 1-2 phrases chaleureuses + présentation si premier message | Préfixe salutation enrichi si premier message |
| hello | SMALL_TALK_EMOTION | greeting | instruction contextuelle greeting | 1-2 phrases chaleureuses + présentation si premier message | Préfixe salutation enrichi si premier message |
| bonsoir | SMALL_TALK_EMOTION | greeting | instruction contextuelle greeting | 1-2 phrases chaleureuses + présentation si premier message | Préfixe salutation enrichi si premier message |
| ça va | SMALL_TALK_EMOTION | greeting | instruction contextuelle greeting | 1-2 phrases chaleureuses + présentation si premier message | Préfixe salutation enrichi si premier message |
| cc | SMALL_TALK_EMOTION | greeting | instruction contextuelle greeting | 1-2 phrases chaleureuses + présentation si premier message | Préfixe salutation enrichi si premier message |
| yo | SMALL_TALK_EMOTION | greeting | instruction contextuelle greeting | 1-2 phrases chaleureuses + présentation si premier message | Préfixe salutation enrichi si premier message |
| slt | SMALL_TALK_EMOTION | greeting | instruction contextuelle greeting | 1-2 phrases chaleureuses + présentation si premier message | Préfixe salutation enrichi si premier message |
| bjr | SMALL_TALK_EMOTION | greeting | instruction contextuelle greeting | 1-2 phrases chaleureuses + présentation si premier message | Préfixe salutation enrichi si premier message |

## Pourquoi Bobodo produit des réponses longues et administratives

**CAUSE PRINCIPALE** : Règle 5 du prompt système maître

```
5. FIN DE RÉPONSE: Après une réponse utile, termine par une courte question d'engagement 
("Y a-t-il autre chose sur lequel je peux t'aider ?") — SAUF si l'utilisateur a exprimé satisfaction/fin.
```

Cette règle force systématiquement une question de fin, ce qui rallonge les réponses et les rend plus "administratives".

---

# PHASE 5 – AUDIT DES RELANCES INTELLIGENTES

## Simulation multi-tours

### Message 1 : "Je suis en Terminale D"
- Historique chargé : 0 messages
- Prompt final : message seul
- Informations conservées : Aucune (premier message)
- Informations perdues : N/A
- Informations réinjectées : N/A
- Contexte : ❌ Aucun contexte précédent

### Message 2 : "J'aime les mathématiques"
- Historique chargé : 2 messages (1 étudiant + 1 assistant)
- Prompt final : message + historique (2 messages)
- Informations conservées : Message 1 + Réponse Bobodo 1
- Informations perdues : Aucune
- Informations réinjectées : Message 1 + Réponse Bobodo 1
- Contexte : ✅ Historique disponible

### Message 3 : "Que me conseilles-tu ?"
- Historique chargé : 4 messages (2 échanges)
- Prompt final : message + historique (4 messages)
- Informations conservées : Messages 1-2 + Réponses Bobodo 1-2
- Informations perdues : Aucune
- Informations réinjectées : Messages 1-2 + Réponses Bobodo 1-2
- Contexte : ✅ Historique disponible
- État émotionnel détecté : follow_up (message court avec '?')

### Message 4 : "Et après ?"
- Historique chargé : 6 messages (3 échanges)
- Prompt final : message + historique (6 messages)
- Informations conservées : Messages 1-3 + Réponses Bobodo 1-3
- Informations perdues : Aucune
- Informations réinjectées : Messages 1-3 + Réponses Bobodo 1-3
- Contexte : ✅ Historique disponible
- État émotionnel détecté : follow_up (message court)
- Instruction contextuelle : Utilise les 2 derniers messages de Bobodo

### Message 5 : "Combien ça coûte ?"
- Historique chargé : 8 messages (4 échanges)
- Prompt final : message + historique (8 messages)
- Informations conservées : Messages 1-4 + Réponses Bobodo 1-4
- Informations perdues : Aucune
- Informations réinjectées : Messages 1-4 + Réponses Bobodo 1-4
- Contexte : ✅ Historique disponible
- État émotionnel détecté : follow_up (message court avec '?')

## Où le contexte est cassé

### 1. Troncature à 14 messages
- Au-delà de 7 échanges, l'historique est tronqué
- Les messages les plus anciens sont perdus
- Pas de résumé pour compenser

### 2. Pas de mémoire cross-session
- Chaque session est indépendante
- L'historique précédent est perdu
- Bobodo ne se souvient pas des conversations passées

### 3. Pas de profil étudiant conversationnel
- Les données étudiant (app.students) ne sont PAS injectées dans le prompt
- Bobodo ne connaît pas : niveau, série, moyenne, université, filière, etc.
- Ces données existent mais ne sont pas utilisées par Bobodo

---

# CARTOGRAPHIE COMPLÈTE

## Cartographie de la mémoire actuelle

```
┌─────────────────────────────────────────────────────────────┐
│                    MÉMOIRE BOBODO ACTUELLE                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ MÉMOIRE SESSION (bobodo_sessions)                   │  │
│  │ - id, student_id, title, created_at, updated_at    │  │
│  │ ❌ PAS de données profil étudiant                   │  │
│  │ ❌ PAS de données contexte conversationnel          │  │
│  │ ❌ PAS de préférences utilisateur                  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ MÉMOIRE MESSAGES (bobodo_messages)                   │  │
│  │ - id, session_id, sender, content, safety_flag      │  │
│  │ ✅ Historique brut (max 14 messages chargés)         │  │
│  │ ❌ PAS de résumé automatique                        │  │
│  │ ❌ PAS de tags sémantiques                          │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ CACHE SÉMANTIQUE (bobodo_answer_cache)               │  │
│  │ - question_text, question_embedding, answer_text     │  │
│  │ ✅ Optimise les appels OpenRouter                    │  │
│  │ ❌ PAS de mémoire cross-session                     │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ BESOINS DÉTECTÉS (bobodo_detected_needs)             │  │
│  │ - category, need_summary                             │  │
│  │ ✅ Stocke les besoins détectés                      │  │
│  │ ❌ PAS de profil complet                            │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ❌ MÉMOIRE PERSISTANTE CROSS-SESSION : ABSENTE           │
│  ❌ PROFIL CONVERSATIONNEL : ABSENT                       │
│  ❌ RÉSUMÉ AUTOMATIQUE : ABSENT                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Cartographie de la personnalité actuelle

```
┌─────────────────────────────────────────────────────────────┐
│              PERSONNALITÉ BOBODO ACTUELLE                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  PROMPT SYSTÈME MAÎTRE (10 règles)                          │
│  ✅ Compréhension sémantique                                │
│  ✅ Suivi contextuel                                       │
│  ✅ Gestion frustration                                    │
│  ✅ Gestion satisfaction                                    │
│  ✅ Question d'engagement systématique                    │
│  ✅ Redirection hors domaine                               │
│  ✅ Blocage universités                                    │
│  ✅ Style défini                                          │
│  ✅ Interdiction salutations dans le corps                │
│  ✅ Gestion confirmation                                   │
│                                                             │
│  DÉTECTION ÉMOTIONNELLE (6 états)                          │
│  ✅ greeting (salutation)                                   │
│  ✅ emotional (émotion)                                     │
│  ✅ frustrated (frustration)                                │
│  ✅ satisfied (satisfaction)                                │
│  ✅ confirmation (confirmation)                              │
│  ✅ follow_up (relance)                                     │
│                                                             │
│  INSTRUCTIONS CONTEXTUELLES                                 │
│  ✅ Par état émotionnel                                    │
│  ✅ max_tokens adapté                                      │
│  ✅ Utilise historique pour follow_up                      │
│                                                             │
│  ❌ FÉLICITATIONS SPONTANÉES : ABSENTES                     │
│  ❌ DÉTECTION RÉUSSITE ACADÉMIQUE : ABSENTE                 │
│  ❌ QUESTIONS DÉCOUVERTE PROFIL : ABSENTES                  │
│  ❌ MÉMOIRE ÉMOTIONNELLE : ABSENTE                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Cartographie des salutations

```
┌─────────────────────────────────────────────────────────────┐
│               SALUTATIONS BOBODO ACTUELLES                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  RÈGLE PROMPT SYSTÈME                                       │
│  ❌ "Ne commence JAMAIS ta réponse par 'Bonjour'..."        │
│                                                             │
│  ENRICHISSEMENT CÔTÉ SERVEUR (lignes 1207-1256)            │
│  ✅ SI premier message de la session :                      │
│     - Récupérer prénom via app_get_bobodo_student_first_name│
│     - Ajouter préfixe "Bonjour {prénom}, on se rencontre..." │
│     - Ou "Bonjour, je suis Bobodo, l'assistant d'Academia." │
│                                                             │
│  CATÉGORIE DÉTECTÉE                                        │
│  ✅ SMALL_TALK_EMOTION                                      │
│                                                             │
│  INTENTION DÉTECTÉE                                        │
│  ✅ greeting                                               │
│                                                             │
│  INSTRUCTION CONTEXTUELLE                                  │
│  ✅ "Réponds naturellement et chaleureusement en 1-2 phrases"│
│  ✅ "Présente-toi brièvement si c'est le début"            │
│  ✅ "Propose ton aide"                                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Cartographie du suivi contextuel

```
┌─────────────────────────────────────────────────────────────┐
│              SUIVI CONTEXTUEL BOBODO ACTUEL                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  CHARGEMENT HISTORIQUE                                      │
│  ✅ maxMessages = 14 (7 échanges complets)                │
│  ✅ Tous les messages injectés dans le prompt               │
│                                                             │
│  TRAITEMENT DES RELANCES                                    │
│  ✅ Détection follow_up (6 couches)                         │
│  ✅ Instruction contextuelle enrichie (2 derniers messages) │
│  ✅ Réponse courte (1-3 phrases max)                       │
│                                                             │
│  LIMITES                                                    │
│  ❌ Troncature à 14 messages (pas de résumé)               │
│  ❌ Pas de mémoire cross-session                            │
│  ❌ Pas de profil étudiant injecté                          │
│  ❌ Historique perdu entre sessions                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

# LIMITES IDENTIFIÉES

## Critiques

1. **Pas de mémoire cross-session**
   - Bobodo ne se souvient pas des conversations précédentes
   - Chaque session repart à zéro
   - Impossible de construire une relation continue

2. **Pas de profil étudiant injecté**
   - Les données étudiant existent (app.students) mais ne sont pas utilisées
   - Bobodo ne connaît pas le niveau, la série, les candidatures, etc.
   - Impossible de personnaliser les réponses

3. **Pas de résumé automatique**
   - L'historique est tronqué à 14 messages sans compensation
   - Les conversations longues perdent leur contexte
   - Impossible de maintenir des conversations prolongées

4. **Pas de mémoire émotionnelle**
   - L'état émotionnel est détecté mais pas stocké
   - Impossible de suivre l'évolution émotionnelle
   - Impossible d'adapter le comportement sur le long terme

5. **Pas de félicitations spontanées**
   - Bobodo ne détecte pas les réussites académiques
   - Impossible de célébrer les succès
   - Impossible d'encourager proactivement

6. **Pas de questions de découverte**
   - Bobodo ne pose pas de questions pour apprendre
   - Impossible de construire un profil progressivement
   - La relation est unidirectionnelle (réponse uniquement)

7. **Réponses systématiquement longues**
   - La règle 5 force une question d'engagement systématique
   - Les réponses semblent administratives
   - Pas de variation selon le contexte

---

# AMÉLIORATIONS POSSIBLES (SANS TOUCHER AU RAG MÉTIER)

## 1. Injection du profil étudiant dans le prompt

**Implémentation** :
- Créer une RPC `app_get_bobodo_student_profile(session_id)`
- Récupérer les données pertinentes de `app.students` et `app.applications`
- Injecter ces données dans le prompt système sous forme de contexte

**Bénéfice** : Bobodo connaît l'étudiant et peut personnaliser ses réponses

**Complexité** : Faible (RPC + injection dans prompt)

---

## 2. Mémoire cross-session

**Implémentation** :
- Créer une table `app.bobodo_conversation_memory`
- Stocker un résumé de chaque session (besoins détectés, préférences, informations clés)
- Injecter le résumé des sessions précédentes dans le prompt

**Bénéfice** : Bobodo se souvient des conversations passées

**Complexité** : Moyenne (table + résumé IA + injection)

---

## 3. Résumé automatique des conversations longues

**Implémutation** :
- Lorsque l'historique atteint 12 messages, générer un résumé via OpenRouter
- Stocker le résumé dans `app.bobodo_sessions`
- Injecter le résumé dans le prompt à la place des messages anciens

**Bénéfice** : Maintenir le contexte sur les conversations longues

**Complexité** : Moyenne (résumé IA + stockage + injection)

---

## 4. Mémoire émotionnelle

**Implémentation** :
- Créer une table `app.bobodo_emotional_state`
- Stocker l'état émotionnel détecté à chaque message
- Calculer une tendance émotionnelle (positif/négatif/stable)
- Injecter la tendance dans le prompt

**Bénéfice** : Bobodo s'adapte à l'état émotionnel de l'étudiant

**Complexité** : Moyenne (table + calcul tendance + injection)

---

## 5. Félicitations spontanées

**Implémentation** :
- Détecter les réussites académiques (via candidatures acceptées, paiements validés, etc.)
- Ajouter une règle de félicitation dans le prompt système
- Déclencher une félicitation lors du premier message après une réussite

**Bénéfice** : Bobodo célèbre les succès de l'étudiant

**Complexité** : Moyenne (détection réussite + règle prompt)

---

## 6. Questions de découverte du profil

**Implémutation** :
- Ajouter une règle dans le prompt système : "Si tu ne connais pas le niveau d'étude de l'utilisateur, pose-lui la question"
- Créer une table `app.bobodo_profile_answers` pour stocker les réponses
- Injecter les réponses dans le prompt

**Bénéfice** : Bobodo apprend à connaître l'étudiant progressivement

**Complexité** : Moyenne (règle prompt + table + injection)

---

## 7. Variation des réponses (moins administratives)

**Implémentation** :
- Modifier la règle 5 du prompt système : "Termine par une question d'engagement SEULEMENT si c'est pertinent"
- Ajouter une condition : ne pas poser de question si l'utilisateur a déjà reçu une réponse complète

**Bénéfice** : Réponses plus naturelles et moins administratives

**Complexité** : Faible (modification prompt)

---

# ÉVALUATION DE LA CAPACITÉ ACTUELLE

## Bobodo peut-il devenir un véritable compagnon étudiant conversationnel ?

**Réponse** : **❌ NON dans l'état actuel**

**Raisons** :
1. Pas de mémoire cross-session (relation non continue)
2. Pas de profil étudiant injecté (personnalisation impossible)
3. Pas de félicitations spontanées (pas de célébration des succès)
4. Pas de questions de découverte (relation unidirectionnelle)
5. Pas de mémoire émotionnelle (pas d'adaptation sur le long terme)

**Capacité actuelle** : Assistant fonctionnel mais limité à des réponses ponctuelles

**Capacité cible** : Compagnon conversationnel continu qui se souvient, apprend et s'adapte

---

# CONCLUSION

Bobodo dispose d'une **architecture technique solide** (historique, détection émotionnelle, instructions contextuelles) mais manque des **couches de mémoire et de personnalisation** nécessaires pour devenir un véritable compagnon étudiant conversationnel.

Les améliorations proposées sont **indépendantes du RAG métier** et peuvent être mises en œuvre sans modifier la base de connaissances actuelle.

**Priorité suggérée** :
1. Injection du profil étudiant (impact immédiat, complexité faible)
2. Mémoire cross-session (impact majeur, complexité moyenne)
3. Variation des réponses (impact immédiat, complexité faible)
4. Résumé automatique (impact moyen, complexité moyenne)
5. Félicitations spontanées (impact moyen, complexité moyenne)
6. Questions de découverte (impact moyen, complexité moyenne)
7. Mémoire émotionnelle (impact moyen, complexité moyenne)

---

**Audit terminé. Aucune modification n'a été effectuée.**
