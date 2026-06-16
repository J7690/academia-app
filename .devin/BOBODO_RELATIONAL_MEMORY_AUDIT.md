# BOBODO RELATIONAL MEMORY AUDIT

**Date** : 9 juin 2026  
**Statut** : AUDIT EN COURS

---

## OBJECTIF

Déterminer ce qu'il manque pour que Bobodo puisse :
- Se souvenir d'informations importantes d'un étudiant
- Rappeler une réussite passée
- Rappeler un projet d'étude
- Reprendre une conversation plusieurs semaines plus tard
- Créer une relation durable

---

## ÉTAT ACTUEL DE LA MÉMOIRE

### Mémoire conversationnelle

**Implémentation** : ✅ Existe

**Localisation** : `supabase/functions/bobodo-chat/index.ts`

**Fonctionnement** :
- Utilisation de `app_get_or_create_bobodo_session` pour créer/maintenir une session
- Utilisation de `app_list_bobodo_messages` pour charger l'historique
- Historique des messages conservé dans `bobodo_messages`
- Session persistée via SharedPreferences côté Flutter

**Limitations** :
- Mémoire limitée à la session courante
- Pas de mémoire cross-session (sessions différentes)
- Pas de mémoire long terme (plusieurs semaines)

### Mémoire émotionnelle

**Implémentation** : ✅ Existe

**Localisation** : `supabase/functions/bobodo-chat/index.ts`

**Fonctionnement** :
- Détection de l'état émotionnel via `detectEmotionalState()`
- États : neutral, frustrated, satisfied, follow_up, emotional, greeting
- Instruction contextuelle adaptée selon l'état émotionnel

**Limitations** :
- État émotionnel calculé à partir du message courant
- Pas de persistance de l'état émotionnel
- Pas d'historique des émotions

### Profil étudiant

**Implémentation** : ✅ Existe

**Localisation** : `supabase/functions/bobodo-chat/index.ts`

**Fonctionnement** :
- Chargement du profil via `app_get_bobodo_student_profile`
- Injection du profil dans le system prompt
- Utilisation du prénom, niveau d'étude, objectifs, intérêts

**Limitations** :
- Profil statique (pas d'évolution)
- Pas de mémorisation des interactions avec le profil
- Pas de mise à jour du profil basée sur les conversations

---

## CAPACITÉS MANQUANTES

### 1. Mémoire long terme (cross-session)

**Problème** : Bobodo ne se souvient pas des conversations passées entre différentes sessions.

**Capacité requise** :
- Stocker des informations clés extraites des conversations
- Rappeler ces informations dans les sessions futures
- Maintenir une mémoire persistante

**Solution proposée** :
- Créer une table `bobodo_memory` pour stocker les informations clés
- Extraire et stocker automatiquement les informations importantes (objectifs, préférences, réussites)
- Charger la mémoire au début de chaque session
- Injecter la mémoire dans le system prompt

### 2. Rappel de réussites passées

**Problème** : Bobodo ne se souvient pas des réussites de l'étudiant.

**Capacité requise** :
- Détecter les réussites dans les conversations (examen réussi, mention obtenue, dossier validé)
- Stocker ces réussites
- Rappeler ces réussites dans les conversations futures
- Utiliser les réussites pour encourager l'étudiant

**Solution proposée** :
- Ajouter une colonne `achievements` dans `bobodo_memory`
- Détecter les réussites via l'analyse sémantique des messages
- Stocker les réussites avec la date
- Rappeler les réussites quand pertinent

### 3. Rappel de projet d'étude

**Problème** : Bobodo ne se souvient pas du projet d'étude de l'étudiant.

**Capacité requise** :
- Extraire le projet d'étude des conversations
- Stocker le projet d'étude
- Rappeler le projet d'étude dans les conversations futures
- Adapter les réponses en fonction du projet

**Solution proposée** :
- Ajouter une colonne `study_project` dans `bobodo_memory`
- Extraire le projet d'étude via l'analyse sémantique
- Stocker le projet d'étude
- Rappeler le projet d'étude quand pertinent

### 4. Reprise de conversation après plusieurs semaines

**Problème** : Bobodo ne peut pas reprendre une conversation après une longue absence.

**Capacité requise** :
- Stocker le contexte de la dernière conversation
- Rappeler le contexte lors de la reprise
- Continuer naturellement la conversation

**Solution proposée** :
- Ajouter une colonne `last_context` dans `bobodo_sessions`
- Stocker un résumé de la dernière conversation
- Charger le résumé au début de la session
- Injecter le résumé dans le system prompt

### 5. Relation durable

**Problème** : Bobodo ne crée pas de relation durable avec l'étudiant.

**Capacité requise** :
- Suivre l'évolution de l'étudiant dans le temps
- Se souvenir des préférences et habitudes
- Adapter les réponses en fonction de l'historique

**Solution proposée** :
- Ajouter des colonnes pour les préférences et habitudes dans `bobodo_memory`
- Mettre à jour ces informations au fil des conversations
- Utiliser ces informations pour personnaliser les réponses

---

## ARCHITECTURE PROPOSÉE

### Nouvelle table : bobodo_memory

```sql
CREATE TABLE app.bobodo_memory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  memory_type TEXT NOT NULL, -- 'achievement', 'study_project', 'preference', 'habit'
  content TEXT NOT NULL,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, memory_type, content)
);

CREATE INDEX idx_bobodo_memory_user ON app.bobodo_memory(user_id);
CREATE INDEX idx_bobodo_memory_type ON app.bobodo_memory(memory_type);
```

### Modification de bobodo_sessions

```sql
ALTER TABLE app.bobodo_sessions ADD COLUMN last_context TEXT;
ALTER TABLE app.bobodo_sessions ADD COLUMN memory_summary TEXT;
```

### Nouvelle RPC : app_extract_bobodo_memory

Extraire automatiquement les informations importantes des conversations et les stocker dans `bobodo_memory`.

### Nouvelle RPC : app_get_bobodo_memory

Récupérer la mémoire d'un étudiant pour l'injecter dans le system prompt.

---

## ÉTAPES D'IMPLÉMENTATION

1. **Créer la table bobodo_memory**
2. **Modifier bobodo_sessions**
3. **Créer la RPC app_extract_bobodo_memory**
4. **Créer la RPC app_get_bobodo_memory**
5. **Modifier bobodo-chat pour charger la mémoire**
6. **Modifier bobodo-chat pour extraire la mémoire**
7. **Tester la mémoire cross-session**
8. **Tester le rappel de réussites**
9. **Tester le rappel de projet d'étude**
10. **Tester la reprise de conversation**

---

## CONCLUSION

**État actuel** : Mémoire conversationnelle et émotionnelle existent, mais limitées à la session courante.

**Capacités manquantes** :
- ❌ Mémoire long terme (cross-session)
- ❌ Rappel de réussites passées
- ❌ Rappel de projet d'étude
- ❌ Reprise de conversation après plusieurs semaines
- ❌ Relation durable

**Solution proposée** : Créer une table `bobodo_memory` pour stocker les informations clés et les rappeler dans les sessions futures.

**Priorité** : Moyenne - Amélioration de l'expérience utilisateur, mais non bloquante pour LOT B.

---

**AUDIT TERMINÉ**
