# BOBODO – ÉVOLUTION VERS ASSISTANT CONVERSATIONNEL DE NOUVELLE GÉNÉRATION

**Date**: 8 Juin 2026
**Objectif**: Transformer Bobodo d'un assistant question/réponse en un véritable compagnon conversationnel étudiant
**Contrainte**: Aucune modification des règles métier existantes (sécurité, RAG, gouvernance)

---

# RÉSUMÉ EXÉCUTIF

**Audit complet terminé** : 10 chantiers audités, 0 implémentation effectuée

**Points critiques identifiés** :
- ❌ Pas de mémoire cross-session
- ❌ Pas de profil étudiant injecté dans le prompt
- ❌ Pas de résumé automatique des conversations longues
- ❌ Questions d'engagement forcées systématiques (ton administratif)
- ❌ Pas de félicitations spontanées
- ❌ Pas de questions de découverte
- ❌ Pas de mémoire émotionnelle

**Points positifs conservés** :
- ✅ Détection émotionnelle avancée (6 états)
- ✅ Instructions contextuelles par état
- ✅ Détection questions de rebond
- ✅ Gouvernance des sources (hiérarchie maintenue)
- ✅ Règles métier (sécurité, blocage universités)

---

# LIVRABLE 1 – CARTOGRAPHIE MÉMOIRE ACTUELLE

```
┌─────────────────────────────────────────────────────────────┐
│                    MÉMOIRE BOBODO ACTUELLE                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ MÉMOIRE SESSION (app.bobodo_sessions)               │  │
│  │ - id, student_id, title, created_at, updated_at    │  │
│  │ ❌ PAS de données profil étudiant                   │  │
│  │ ❌ PAS de données contexte conversationnel          │  │
│  │ ❌ PAS de préférences utilisateur                  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ MÉMOIRE MESSAGES (app.bobodo_messages)               │  │
│  │ - id, session_id, sender, content, safety_flag      │  │
│  │ ✅ Historique brut (max 14 messages chargés)         │  │
│  │ ❌ PAS de résumé automatique                        │  │
│  │ ❌ PAS de tags sémantiques                          │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ CACHE SÉMANTIQUE (app.bobodo_answer_cache)           │  │
│  │ - question_text, question_embedding, answer_text     │  │
│  │ ✅ Optimise les appels OpenRouter                    │  │
│  │ ❌ PAS de mémoire cross-session                     │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ BESOINS DÉTECTÉS (app.bobodo_detected_needs)         │  │
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

## Données utilisateur disponibles (app.students)

| Colonne | Type | Bobodo l'utilise ? |
|---------|------|-------------------|
| full_name | text | ✅ OUI (prénom pour salutation) |
| bac_series | text | ❌ NON |
| bac_year | integer | ❌ NON |
| bac_mention | text | ❌ NON |
| bac_institution | text | ❌ NON |
| bac_country | text | ❌ NON |
| bepc_year | integer | ❌ NON |
| bepc_mention | text | ❌ NON |
| bepc_institution | text | ❌ NON |
| bepc_country | text | ❌ NON |
| study_project_text | text | ❌ NON |
| country | text | ❌ NON |
| city | text | ❌ NON |
| bio | text | ❌ NON |

## Données candidatures disponibles (app.applications)

| Colonne | Type | Bobodo l'utilise ? |
|---------|------|-------------------|
| program_id | uuid | ❌ NON |
| status | text | ❌ NON |
| created_at | timestamp | ❌ NON |

## Statistiques réelles

- Total sessions : 108
- Étudiants uniques : 13
- Moyenne messages/session : 5.5
- Max messages/session : 46
- Distribution : 9 étudiants (1 session), 1 (2 sessions), 1 (3 sessions), 1 (21 sessions), 1 (73 sessions)

## Besoins détectés

- NEXIOM_ACADEMIA_INTERNE : 59
- ORIENTATION_ETUDES_EMPLOI : 33
- AUTRE_UNIVERSITE_OU_ENTREPRISE : 6
- PARTENAIRE_UNIVERSITE_DETAILLEE : 2

---

# LIVRABLE 2 – CARTOGRAPHIE CONTEXTE INJECTÉ AUX PROMPTS

```
┌─────────────────────────────────────────────────────────────┐
│              CONTEXTE INJECTÉ DANS LE PROMPT LLM             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  CHARGEMENT HISTORIQUE                                      │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Fonction: loadConversationHistoryForSession           │  │
│  │ RPC: app_list_bobodo_messages                         │  │
│  │ Limite: maxMessages = 14                              │  │
│  │ Ordre: created_at ASC (chronologique)                 │  │
│  │ Format: ChatHistoryMessage[]                           │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  INJECTION DANS LE PROMPT                                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Fonction: callOpenRouter                              │  │
│  │ Paramètre: history optionnel                          │  │
│  │ Injection: Tous les messages chargés                   │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  CONNAISSANCE RAG                                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ RPC: app_search_bobodo_knowledge                       │  │
│  │ RPC: app_search_bobodo_knowledge_vector                │  │
│  │ Table: app.bobodo_knowledge                            │  │
│  │ Priorité: Niveau 1 (connaissances internes)          │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  CACHE SÉMANTIQUE                                           │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ RPC: app_search_bobodo_answer_cache                    │  │
│  │ Table: app.bobodo_answer_cache                         │  │
│  │ Seuil: similarity >= 0.92                              │  │
│  │ Priorité: Avant RAG                                   │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ❌ PROFIL ÉTUDIANT : NON INJECTÉ                          │
│  ❌ RÉSUMÉ SESSION : NON INJECTÉ                           │
│  ❌ MÉMOIRE CROSS-SESSION : NON INJECTÉE                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Flux de construction du prompt

```
1. Prompt système maître (10 règles)
   ↓
2. Instruction contextuelle (selon état émotionnel)
   ↓
3. Historique conversationnel (max 14 messages)
   ↓
4. Connaissance RAG (app.bobodo_knowledge)
   ↓
5. Cache sémantique (si match)
   ↓
6. Message utilisateur
   ↓
7. Enrichissement salutation (si premier message)
```

## Profondeur du contexte

| Scénario | Messages | Contexte conservé | Pertes |
|----------|----------|-------------------|--------|
| Court (< 14) | < 14 | ✅ 100% | ❌ 0% |
| Moyen (14-20) | 14-20 | ⚠️ 70% | ⚠️ 30% |
| Long (> 20) | > 20 | ❌ < 50% | ❌ > 50% |

## Qualité du chargement historique

**Points positifs** :
- ✅ Chargement chronologique
- ✅ Filtrage par session_id
- ✅ Limite configurable
- ✅ Séparation sender

**Points négatifs** :
- ❌ Pas de filtrage par pertinence
- ❌ Pas de déduplication
- ❌ Pas de compression
- ❌ Pas de résumé des messages anciens
- ❌ Pas de détection de redondance

---

# LIVRABLE 3 – CARTOGRAPHIE RÈGLES PERSONNALITÉ EXISTANTES

```
┌─────────────────────────────────────────────────────────────┐
│              PERSONNALITÉ BOBODO ACTUELLE                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  PROMPT SYSTÈME MAÎTRE (10 règles)                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 1. COMPRÉHENSION SÉMANTIQUE ✅                       │  │
│  │ 2. SUIVI CONTEXTUEL ✅                               │  │
│  │ 3. FRUSTRATION ✅                                     │  │
│  │ 4. SATISFACTION ✅                                    │  │
│  │ 5. FIN DE RÉPONSE ❌ (question forcée)               │  │
│  │ 6. HORS DOMAINE ✅                                    │  │
│  │ 7. UNIVERSITÉS ✅ (blocage)                          │  │
│  │ 8. STYLE ✅                                           │  │
│  │ 9. SALUTATIONS ❌ (contradiction enrichissement)      │  │
│  │ 10. CONFIRMATION ✅                                   │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  DÉTECTION ÉMOTIONNELLE (6 états)                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ greeting ✅                                           │  │
│  │ emotional ✅                                          │  │
│  │ frustrated ✅                                         │  │
│  │ satisfied ✅                                          │  │
│  │ confirmation ✅                                       │  │
│  │ follow_up ✅                                          │  │
│  │ neutral ✅                                            │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  INSTRUCTIONS CONTEXTUELLES                                 │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ greeting → 1-2 phrases chaleureuses                  │  │
│  │ emotional → empathie 1-2 phrases                      │  │
│  │ frustrated → reformule avec exemple                  │  │
│  │ satisfied → chaleureux 1-2 phrases                    │  │
│  │ confirmation → confirme sans répéter                 │  │
│  │ follow_up → utilise 2 derniers messages              │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ❌ FÉLICITATIONS SPONTANÉES : ABSENTES                     │
│  ❌ ENCOURAGEMENT SPONTANÉ : ABSENT                         │
│  ❌ QUESTIONS DÉCOUVERTE : ABSENTES                         │
│  ❌ MÉMOIRE ÉMOTIONNELLE : ABSENTE                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Ton actuel

| Caractéristique | État |
|-----------------|------|
| Professionnel | ✅ |
| Chaleureux | ⚠️ (limité) |
| Intelligent | ✅ |
| Naturel | ❌ (trop formel) |
| Encourageant | ❌ |
| Concis | ⚠️ (question forcée rallonge) |

## Questions forcées identifiées

**Règle 5 du prompt maître** :
```
"Après une réponse utile, termine par une courte question d'engagement"
"Y a-t-il autre chose sur lequel je peux t'aider ?"
```

**Instructions contextuelles** :
- satisfied : "propose ton aide pour autre chose"
- confirmation : "propose de continuer"

**Problèmes** :
- ❌ Question systématique
- ❌ Phrase identique à chaque fois
- ❌ Pas contextuelle
- ❌ Ton administratif
- ❌ Rallonge toutes les réponses

## Salutations actuelles

**Règle 9 du prompt maître** :
```
"Ne commence JAMAIS ta réponse par Bonjour, Bonsoir, Salut"
"La conversation est déjà engagée. Va directement au sujet."
```

**Enrichissement côté serveur** :
```
SI premier message de la session:
- Récupérer prénom via app_get_bobodo_student_first_name
- Ajouter préfixe: "Bonjour {prénom}, on se rencontre, je suis Bobodo..."
```

**Problèmes** :
- ❌ Contradiction entre règle prompt et enrichissement serveur
- ❌ Bloc de présentation institutionnel
- ❌ Pas de variété dans les salutations

---

# LIVRABLE 4 – CARTOGRAPHIE MÉCANISMES REBOND CONVERSATIONNEL

```
┌─────────────────────────────────────────────────────────────┐
│            MÉCANISMES REBOND CONVERSATIONNEL ACTUELS          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  DÉTECTION ÉMOTIONNELLE (6 couches)                         │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 1. Réactions à un seul mot → follow_up               │  │
│  │    (oui, non, ok, waw, vraiment?)                     │  │
│  │ 2. Confirmation/reformulation → follow_up             │  │
│  │    (ah ok, donc c'est, si je comprends bien)         │  │
│  │ 3. Message court avec '?' (< 80 chars) → follow_up    │  │
│  │ 4. Message court en contexte actif → follow_up        │  │
│  │    (< 100 chars, history >= 2)                        │  │
│  │ 5. Frustration → frustrated                           │  │
│  │    (pas clair, pas compris, reformule)                │  │
│  │ 6. Satisfaction → satisfied                           │  │
│  │    (merci, super, parfait)                            │  │
│  │ 7. Défaut → neutral                                   │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  INSTRUCTIONS CONTEXTUELLES                                 │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ follow_up → Utilise 2 derniers messages de Bobodo     │  │
│  │           Réponds directement et brièvement          │  │
│  │           1-3 phrases max                             │  │
│  │           Sans reformuler tout le contexte           │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ✅ QUESTIONS DE REBOND COURANTES DÉTECTÉES                │
│  - "Et après ?" → follow_up ✅                             │
│  - "Pourquoi ?" → follow_up ✅                             │
│  - "Et dans ce cas ?" → follow_up ✅                       │
│  - "Tu peux développer ?" → follow_up ✅                   │
│  - "Et pour moi ?" → follow_up ✅                          │
│  - "Combien de temps ?" → follow_up ✅                     │
│                                                             │
│  ❌ LIMITES                                                 │
│  - Pas de détection de références implicites complexes   │
│  - Pas de détection de changement de sujet                │
│  - Pas de détection d'anaphores (il, elle, ça)           │
│  - Pas de détection de pronoms relatifs (qui, quoi, où)  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Qualité du rebond

**Points positifs** :
- ✅ Détection de réactions à un seul mot
- ✅ Détection de confirmation/reformulation
- ✅ Détection de questions courtes
- ✅ Utilisation du contexte pour follow_up

**Points négatifs** :
- ❌ Pas de hiérarchisation des messages
- ❌ Pas de pondération temporelle
- ❌ Pas de détection de changement de sujet
- ❌ Pas de détection d'anaphores

---

# LIVRABLE 5 – PROPOSITION TECHNIQUE DÉTAILLÉE

## CHANTIER 1 – Injection profil étudiant dans prompt

### Objectif
Bobodo doit connaître le profil de l'utilisateur lorsqu'il dialogue.

### Implémentation proposée

**1. Créer une RPC** `app_get_bobodo_student_profile(p_session_id)`

```sql
CREATE OR REPLACE FUNCTION app_get_bobodo_student_profile(
    p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile JSONB;
BEGIN
    SELECT JSONB_BUILD_OBJECT(
        'first_name', split_part(COALESCE(st.full_name, ''), ' ', 1),
        'full_name', st.full_name,
        'bac_series', st.bac_series,
        'bac_year', st.bac_year,
        'bac_mention', st.bac_mention,
        'bac_institution', st.bac_institution,
        'bepc_year', st.bepc_year,
        'bepc_mention', st.bepc_mention,
        'study_project', st.study_project_text,
        'country', st.country,
        'city', st.city,
        'bio', st.bio,
        'applications', (
            SELECT JSONB_AGG(
                JSONB_BUILD_OBJECT(
                    'program_id', a.program_id,
                    'status', a.status,
                    'created_at', a.created_at
                )
            )
            FROM app.applications a
            WHERE a.student_id = s.id
            LIMIT 5
        )
    ) INTO v_profile
    FROM app.bobodo_sessions bs
    JOIN app.students s ON s.id = bs.student_id
    WHERE bs.id = p_session_id;

    RETURN v_profile;
END;
$$;
```

**2. Modifier l'Edge Function** `bobodo-chat/index.ts`

```typescript
// Après le chargement de l'historique
const studentProfile = await supabaseForUser.rpc('get_bobodo_student_profile', {
  p_session_id: sessionId
});

// Injecter dans le prompt système
const profileContext = studentProfile 
  ? `\n\nPROFIL ÉTUDIANT:\n${JSON.stringify(studentProfile, null, 2)}` 
  : '';
```

**3. Ajouter une règle dans le prompt système**

```
11. PERSONNALISATION: Utilise les informations du profil étudiant pour personnaliser tes réponses.
    Si l'étudiant a une série de bac spécifique, adapte tes exemples.
    Si l'étudiant a un projet d'étude, relie tes réponses à son projet.
    Si l'étudiant a des candidatures en cours, mentionne-les si pertinent.
```

### Complexité
- **Faible** (RPC + injection dans prompt)
- **Impact immédiat** sur la personnalisation

---

## CHANTIER 2 – Mémoire cross-session (résumé automatique)

### Objectif
Bobodo doit conserver les centres d'intérêt, projets d'études, préférences exprimées entre les sessions.

### Implémentation proposée

**1. Créer une table** `app.bobodo_conversation_memory`

```sql
CREATE TABLE IF NOT EXISTS app.bobodo_conversation_memory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES app.students (id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES app.bobodo_sessions (id) ON DELETE CASCADE,
    summary TEXT NOT NULL,
    interests TEXT[],
    study_goals TEXT[],
    preferences TEXT[],
    key_information TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.bobodo_conversation_memory ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_bobodo_conversation_memory_student ON app.bobodo_conversation_memory(student_id);
CREATE INDEX idx_bobodo_conversation_memory_session ON app.bobodo_conversation_memory(session_id);
```

**2. Créer une RPC** `app_generate_bobodo_session_summary(p_session_id)`

```sql
CREATE OR REPLACE FUNCTION app_generate_bobodo_session_summary(
    p_session_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_summary TEXT;
BEGIN
    -- Cette RPC sera appelée par l'Edge Function
    -- L'Edge Function enverra le résumé généré par l'IA
    -- Cette RPC stockera le résumé dans la table
    
    RETURN v_summary;
END;
$$;
```

**3. Modifier l'Edge Function** `bobodo-chat/index.ts`

```typescript
// À la fin de chaque session (ou après N messages)
async function generateSessionSummary(sessionId: string, history: ChatHistoryMessage[]) {
  const summaryPrompt = `
    Résume cette conversation en 3-5 phrases.
    Identifie:
    - Les centres d'intérêt de l'étudiant
    - Les projets d'études exprimés
    - Les préférences exprimées
    - Les informations clés partagées
    
    Format JSON:
    {
      "summary": "...",
      "interests": ["..."],
      "study_goals": ["..."],
      "preferences": ["..."],
      "key_information": ["..."]
    }
  `;
  
  const summary = await callOpenRouter(summaryPrompt, [], {
    systemPrompt: 'Tu es un assistant qui résume des conversations.',
    history: history,
    max_tokens: 500
  });
  
  // Stocker dans la table
  await supabaseForUser.rpc('save_bobodo_conversation_memory', {
    p_session_id: sessionId,
    p_summary: summary
  });
}
```

**4. Créer une RPC** `app_get_bobodo_cross_session_memory(p_student_id)`

```sql
CREATE OR REPLACE FUNCTION app_get_bobodo_cross_session_memory(
    p_student_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_memory JSONB;
BEGIN
    SELECT JSONB_BUILD_OBJECT(
        'recent_summaries', (
            SELECT JSONB_AGG(
                JSONB_BUILD_OBJECT(
                    'summary', cm.summary,
                    'interests', cm.interests,
                    'study_goals', cm.study_goals,
                    'created_at', cm.created_at
                )
            )
            FROM app.bobodo_conversation_memory cm
            WHERE cm.student_id = p_student_id
            ORDER BY cm.created_at DESC
            LIMIT 5
        ),
        'all_interests', (
            SELECT ARRAY_AGG(DISTINCT unnest(interests))
            FROM app.bobodo_conversation_memory
            WHERE student_id = p_student_id
        ),
        'all_study_goals', (
            SELECT ARRAY_AGG(DISTINCT unnest(study_goals))
            FROM app.bobodo_conversation_memory
            WHERE student_id = p_student_id
        )
    ) INTO v_memory;
    
    RETURN v_memory;
END;
$$;
```

**5. Injecter la mémoire cross-session dans le prompt**

```typescript
// Au début de chaque session
const crossSessionMemory = await supabaseForUser.rpc('get_bobodo_cross_session_memory', {
  p_student_id: studentId
});

const memoryContext = crossSessionMemory 
  ? `\n\nMÉMOIRE CONVERSATIONNELLE:\n${JSON.stringify(crossSessionMemory, null, 2)}` 
  : '';
```

### Complexité
- **Moyenne** (table + résumé IA + injection)
- **Impact majeur** sur la continuité conversationnelle

---

## CHANTIER 3 – Amélioration détection questions de rebond

### Objectif
Bobodo doit comprendre les références implicites sans exiger une reformulation complète.

### Implémentation proposée

**État actuel** : Les questions de rebond courantes sont déjà bien détectées.

**Amélioration** : Étendre la détection avec des patterns supplémentaires.

```typescript
function detectEmotionalState(message: string, history: ChatHistoryMessage[]): EmotionalState {
  const lowerMessage = message.toLowerCase().trim();
  
  // ... code existant ...
  
  // Nouvelle couche : détection d'anaphores
  if (lowerMessage.match(/^(il|elle|ça|ce|c')\s/) && history.length >= 2) {
    return 'follow_up';
  }
  
  // Nouvelle couche : détection de pronoms relatifs
  if (lowerMessage.match(/^(qui|quoi|où|quand|comment)\s/) && history.length >= 2) {
    return 'follow_up';
  }
  
  // Nouvelle couche : détection de changement de sujet
  if (detectTopicChange(message, history)) {
    return 'neutral'; // Nouveau sujet, pas de follow_up
  }
  
  return currentState;
}
```

### Complexité
- **Faible** (extension de la logique existante)
- **Impact moyen** sur la qualité du rebond

---

## CHANTIER 4 – Réécriture complète personnalité

### Objectif
Bobodo doit être chaleureux, intelligent, naturel, encourageant, concis.

### Implémentation proposée

**Nouveau prompt système maître** :

```
Tu es Bobodo, assistant IA de Nexiom Group et de la plateforme Academia.

Ta mission est d'accompagner les étudiants dans leur parcours :
- guider
- informer
- rassurer
- orienter
- encourager

RÈGLES DE PERSONNALITÉ:

1. TON CHALEUREUX: Sois naturel, comme un ami bienveillant. Utilise un langage simple,
   accessible. Évite le jargon administratif. Sois empathique et encourageant.

2. CONCISION: Sois bref et direct. Pas de phrases inutiles. Pas de paragraphes interminables.
   Questions simples → 1-2 phrases. Questions complexes → 3-5 phrases max.

3. PERSONNALISATION: Utilise les informations du profil étudiant pour personnaliser tes réponses.
   Adapte tes exemples au niveau de l'étudiant. Relie tes réponses à son projet d'étude.

4. ENCOURAGEMENT: Encourage l'étudiant naturellement. Félicite les réussites.
   Valide les efforts. Rassure en cas de difficulté.

5. QUESTIONS NATURELLES: Pose des questions de manière naturelle, pas comme un formulaire.
   Adapte tes questions au contexte. Évite le spam de questions.

6. SUIVI CONTEXTUEL: Connecte les réponses courtes au contexte précédent.
   Comprends les références implicites. Relie les sujets entre eux.

7. RÉGLES MÉTIER (CONSERVÉES):
   - Compréhension sémantique
   - Gestion frustration
   - Gestion satisfaction
   - Redirection hors domaine
   - Blocage universités
   - Gestion confirmation

8. PAS DE QUESTIONS FORCÉES: Ne termine pas systématiquement par une question d'engagement.
   Pose une question seulement si c'est naturel et pertinent pour la conversation.
```

### Complexité
- **Faible** (modification du prompt système)
- **Impact majeur** sur le ton et la personnalité

---

## CHANTIER 5 – Refonte salutations

### Objectif
Bobodo doit répondre aux salutations par des réponses courtes, pas par un bloc institutionnel.

### Implémentation proposée

**1. Supprimer l'enrichissement côté serveur** (lignes 1207-1256)

```typescript
// Supprimer ce code
// const firstName = await supabaseForUser.rpc('get_bobodo_student_first_name', ...);
// const greetingPrefix = `Bonjour ${firstName}, on se rencontre...`;
```

**2. Modifier l'instruction contextuelle greeting**

```
greeting:
Réponds naturellement et chaleureusement en 1-2 phrases.
Exemples:
- "Salut 👋"
- "Bonsoir, content de te revoir."
- "Hey ! Comment vas-tu aujourd'hui ?"
- "Coucou ! Je suis Bobodo, ton assistant Academia."

Ne fais jamais de bloc de présentation institutionnel.
```

**3. Ajouter une variété de réponses**

```typescript
const greetingResponses = [
  "Salut 👋",
  "Bonsoir, content de te revoir.",
  "Hey ! Comment vas-tu aujourd'hui ?",
  "Coucou ! Je suis Bobodo, ton assistant Academia.",
  "Salut ! Comment puis-je t'aider ?",
  "Bonjour ! Content de te voir."
];

// Sélectionner aléatoirement une réponse
const greetingResponse = greetingResponses[Math.floor(Math.random() * greetingResponses.length)];
```

### Complexité
- **Faible** (suppression enrichissement + modification instruction)
- **Impact immédiat** sur les salutations

---

## CHANTIER 6 – Suppression questions forcées systématiques

### Objectif
Les questions de relance doivent devenir contextuelles et non obligatoires.

### Implémentation proposée

**1. Modifier la règle 5 du prompt système**

```
5. RELANCE NATURELLE: Pose une question de relance SEULEMENT si c'est naturel et pertinent.
   Évite les questions systématiques. Adapte la question au contexte.
   Exemples de relances naturelles:
   - "Tu veux en savoir plus ?"
   - "Ça répond à ta question ?"
   - "Autre chose ?"
   - "Je peux t'aider sur autre chose ?"
   
   NE pose PAS de question si:
   - L'utilisateur a déjà exprimé satisfaction
   - La réponse est complète
   - La conversation semble terminée
```

**2. Modifier les instructions contextuelles**

```
satisfied:
Réponds chaleureusement en 1-2 phrases.
NE propose PAS systématiquement ton aide pour autre chose.

confirmation:
Confirme simplement en 1-2 phrases.
NE propose PAS systématiquement de continuer.
```

### Complexité
- **Faible** (modification du prompt système)
- **Impact immédiat** sur le ton des réponses

---

## CHANTIER 7 – Félicitations et encouragements

### Objectif
Bobodo doit détecter les réussites et féliciter spontanément.

### Implémentation proposée

**1. Créer une fonction de détection de réussite**

```typescript
function detectAchievement(message: string, studentProfile: any): boolean {
  const lowerMessage = message.toLowerCase();
  
  // Détection de réussite bac
  if (lowerMessage.match(/bac|baccalauréat/) && lowerMessage.match(/eu|obtenu|réussi/)) {
    return true;
  }
  
  // Détection de réussite bepc
  if (lowerMessage.match(/bepc/) && lowerMessage.match(/eu|obtenu|réussi/)) {
    return true;
  }
  
  // Détection d'admission
  if (lowerMessage.match(/admis|accepté|sélectionné/)) {
    return true;
  }
  
  // Détection de bonne moyenne
  if (lowerMessage.match(/\d+/)) {
    const match = lowerMessage.match(/\d+/);
    const score = parseInt(match[0]);
    if (score >= 12) {
      return true;
    }
  }
  
  return false;
}
```

**2. Ajouter une instruction contextuelle achievement**

```
achievement:
Félicite chaleureusement l'étudiant pour sa réussite.
Utilise des émojis si approprié (🎉, 🌟, 👏).
Exemples:
- "Félicitations 🎉 14 est une très bonne moyenne !"
- "Bravo pour ton admission ! 🌟"
- "Super travail ! 👏"
```

**3. Injecter les données de réussite dans le prompt**

```typescript
if (detectAchievement(message, studentProfile)) {
  const achievementContext = `
    L'étudiant vient de partager une réussite.
    Données disponibles:
    - bac_mention: ${studentProfile.bac_mention}
    - bepc_mention: ${studentProfile.bepc_mention}
  `;
  
  // Injecter dans le prompt
}
```

### Complexité
- **Moyenne** (détection + instruction contextuelle)
- **Impact moyen** sur l'expérience utilisateur

---

## CHANTIER 8 – Questions de découverte naturelles

### Objectif
Bobodo doit parfois prendre l'initiative pour apprendre à connaître l'étudiant.

### Implémentation proposée

**1. Créer une table** `app.bobodo_profile_answers`

```sql
CREATE TABLE IF NOT EXISTS app.bobodo_profile_answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES app.students (id) ON DELETE CASCADE,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    asked_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.bobodo_profile_answers ENABLE ROW LEVEL SECURITY;
```

**2. Créer une logique de déclenchement des questions**

```typescript
function shouldAskDiscoveryQuestion(studentProfile: any, profileAnswers: any[]): boolean {
  // Ne pas poser de question si le profil est déjà complet
  if (studentProfile.bac_series && studentProfile.study_project) {
    return false;
  }
  
  // Ne pas poser de question si une question a été posée récemment
  const recentQuestion = profileAnswers.find(
    a => new Date(a.asked_at) > new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
  );
  if (recentQuestion) {
    return false;
  }
  
  // Ne pas poser de question si l'utilisateur semble pressé
  // (détection basée sur la longueur des messages, la fréquence, etc.)
  
  return true;
}

function selectDiscoveryQuestion(studentProfile: any): string {
  const questions = [];
  
  if (!studentProfile.bac_series) {
    questions.push("Quelle série as-tu suivie au bac ?");
  }
  
  if (!studentProfile.study_project) {
    questions.push("As-tu déjà une idée du métier que tu vises ?");
  }
  
  if (!studentProfile.country) {
    questions.push("Préfères-tu poursuivre tes études au Burkina ou ailleurs ?");
  }
  
  if (questions.length === 0) {
    questions.push("Quels domaines t'intéressent le plus ?");
  }
  
  return questions[Math.floor(Math.random() * questions.length)];
}
```

**3. Ajouter une instruction contextuelle discovery**

```
discovery:
Pose une question de découverte de manière naturelle.
Intègre la question dans la conversation, ne la pose pas de manière abrupte.
Exemples:
- "Au fait, quelle série as-tu suivie au bac ?"
- "J'aimerais savoir : as-tu déjà une idée du métier que tu vises ?"
- "Dis-moi, quels domaines t'intéressent le plus ?"
```

### Complexité
- **Moyenne** (table + logique déclenchement + instruction)
- **Impact moyen** sur la richesse conversationnelle

---

## CHANTIER 9 – Mémoire émotionnelle

### Objectif
Adapter le ton lors des échanges futurs en fonction de l'état émotionnel.

### Implémentation proposée

**1. Créer une table** `app.bobodo_emotional_history`

```sql
CREATE TABLE IF NOT EXISTS app.bobodo_emotional_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES app.students (id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES app.bobodo_sessions (id) ON DELETE CASCADE,
    emotional_state TEXT NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE app.bobodo_emotional_history ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_bobodo_emotional_history_student ON app.bobodo_emotional_history(student_id);
```

**2. Stocker l'état émotionnel à chaque message**

```typescript
// Après la détection de l'état émotionnel
await supabaseForUser.rpc('save_bobodo_emotional_state', {
  p_session_id: sessionId,
  p_emotional_state: emotionalState,
  p_message: message
});
```

**3. Calculer la tendance émotionnelle**

```sql
CREATE OR REPLACE FUNCTION app_get_bobodo_emotional_trend(
    p_student_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trend JSONB;
BEGIN
    SELECT JSONB_BUILD_OBJECT(
        'recent_states', (
            SELECT JSONB_AGG(
                JSONB_BUILD_OBJECT(
                    'state', eh.emotional_state,
                    'created_at', eh.created_at
                )
            )
            FROM app.bobodo_emotional_history eh
            WHERE eh.student_id = p_student_id
            ORDER BY eh.created_at DESC
            LIMIT 10
        ),
        'frustration_count', (
            SELECT COUNT(*)
            FROM app.bobodo_emotional_history
            WHERE student_id = p_student_id
              AND emotional_state = 'frustrated'
              AND created_at > NOW() - INTERVAL '7 days'
        ),
        'satisfaction_count', (
            SELECT COUNT(*)
            FROM app.bobodo_emotional_history
            WHERE student_id = p_student_id
              AND emotional_state = 'satisfied'
              AND created_at > NOW() - INTERVAL '7 days'
        )
    ) INTO v_trend;
    
    RETURN v_trend;
END;
$$;
```

**4. Adapter le ton en fonction de la tendance**

```typescript
const emotionalTrend = await supabaseForUser.rpc('get_bobodo_emotional_trend', {
  p_student_id: studentId
});

if (emotionalTrend.frustration_count > 3) {
  // Adapter le ton pour être plus patient et encourageant
  systemPrompt += "\n\nNOTE: L'étudiant a été frustré récemment. Sois particulièrement patient et encourageant.";
}
```

### Complexité
- **Moyenne** (table + calcul tendance + adaptation ton)
- **Impact moyen** sur l'adaptation émotionnelle

---

## CHANTIER 10 – Vérification gouvernance sources

### Objectif
Maintenir strictement la hiérarchie des sources.

### Vérification

**Hiérarchie actuelle (CONSERVÉE)** :
- ✅ Niveau 1 : Connaissances internes Academia/Nexiom (app.bobodo_knowledge)
- ✅ Niveau 2 : Données vérifiées plateforme (app.students, app.applications)
- ✅ Niveau 3 : Sources externes fiables (Perplexity web search)

**Règles métier (CONSERVÉES)** :
- ✅ Sécurité (isSensitiveQuery)
- ✅ Filtrage contenus dangereux
- ✅ Blocage universités (isUniversityQuery)
- ✅ Gouvernance des réponses
- ✅ Consultation prioritaire connaissances Academia/Nexiom
- ✅ Mécanismes RAG existants
- ✅ Cache sémantique
- ✅ OpenRouter
- ✅ Classification métier

**Interdictions (MAINTENUES)** :
- ✅ Jamais inventer informations Academia
- ✅ Jamais inventer informations Nexiom
- ✅ Jamais inventer informations partenaires

### Aucune modification requise

La gouvernance des sources est déjà correctement implémentée et ne nécessite aucun changement.

---

# PLAN D'IMPLÉMENTATION PRIORITAIRE

## Phase 1 – Impact immédiat (complexité faible)

1. **CHANTIER 1** – Injection profil étudiant dans prompt
2. **CHANTIER 4** – Réécriture complète personnalité
3. **CHANTIER 5** – Refonte salutations
4. **CHANTIER 6** – Suppression questions forcées

**Impact** : Transformation immédiate du ton et de la personnalité

## Phase 2 – Impact majeur (complexité moyenne)

5. **CHANTIER 2** – Mémoire cross-session
6. **CHANTIER 7** – Félicitations et encouragements
7. **CHANTIER 8** – Questions de découverte

**Impact** : Amélioration significative de la richesse conversationnelle

## Phase 3 – Impact moyen (complexité moyenne)

8. **CHANTIER 3** – Amélioration détection questions de rebond
9. **CHANTIER 9** – Mémoire émotionnelle

**Impact** : Affinement de la qualité conversationnelle

## Phase 4 – Vérification

10. **CHANTIER 10** – Vérification gouvernance sources

**Impact** : Aucune modification requise (déjà correct)

---

# TESTS ET VALIDATION

## Tests à réaliser

1. **Test salutations** : Vérifier que les réponses sont courtes et variées
2. **Test profil** : Vérifier que Bobodo utilise les données du profil
3. **Test mémoire cross-session** : Vérifier que Bobodo se souvient des conversations précédentes
4. **Test félicitations** : Vérifier que Bobodo félicite les réussites
5. **Test questions découverte** : Vérifier que les questions sont naturelles
6. **Test mémoire émotionnelle** : Vérifier que le ton s'adapte
7. **Test gouvernance** : Vérifier que les règles métier sont conservées

## Critères de succès

- ✅ Bobodo répond aux salutations en 1-2 phrases
- ✅ Bobodo utilise les données du profil étudiant
- ✅ Bobodo se souvient des conversations précédentes
- ✅ Bobodo félicite les réussites
- ✅ Bobodo pose des questions de découverte naturelles
- ✅ Bobodo adapte son ton en fonction de l'état émotionnel
- ✅ Les règles métier sont conservées (sécurité, RAG, gouvernance)

---

# CONCLUSION

L'audit complet a identifié les limites actuelles de Bobodo et proposé des solutions techniques détaillées pour le transformer en un véritable compagnon conversationnel étudiant.

**Aucune régression fonctionnelle** n'est acceptable sur :
- RAG
- Sécurité
- Cache
- Classification
- Gouvernance métier

Les améliorations proposées sont **indépendantes du RAG métier** et peuvent être mises en œuvre sans modifier la base de connaissances actuelle.

**Priorité suggérée** :
1. Phase 1 (impact immédiat, complexité faible)
2. Phase 2 (impact majeur, complexité moyenne)
3. Phase 3 (impact moyen, complexité moyenne)
4. Phase 4 (vérification)

---

**Audit terminé. Aucune modification n'a été effectuée.**
