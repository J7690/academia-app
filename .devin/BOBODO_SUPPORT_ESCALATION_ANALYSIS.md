# BOBODO SUPPORT ESCALATION ANALYSIS

**Date** : 9 juin 2026  
**Statut** : ANALYSE EN COURS

---

## OBJECTIF

Produire des statistiques sur les redirections support :
- Nombre de redirections support
- Motifs
- Catégories
- Questions non couvertes

Objectif : Identifier les futurs enrichissements de connaissances.

---

## ÉTAT ACTUEL

### Règle d'escalade support

**Implémentation** : ✅ Existe

**Localisation** : `supabase/functions/bobodo-chat/index.ts`

**Règle** (Section 8 du system prompt) :
```
8. ESCALADE VERS LE SUPPORT HUMAIN:
- Lorsque tu ne peux pas répondre avec suffisamment de certitude, invite l'utilisateur à utiliser l'icône flottante Support située juste à côté de Bobodo dans l'application Academia afin de contacter directement l'équipe d'administration.
- Cas concernés: absence de réponse fiable, utilisateur insatisfait, plusieurs reformulations sans succès, demande administrative, problème de candidature, problème de paiement, université non disponible, question hors périmètre, besoin d'un accompagnement humain.
- Formule: "Pour t'aider davantage, je t'invite à utiliser l'icône flottante Support située juste à côté de moi dans l'application Academia. L'équipe d'administration pourra te répondre directement."
```

### Détection de frustration

**Implémentation** : ✅ Existe

**Localisation** : `supabase/functions/bobodo-chat/index.ts`

**Fonctionnement** :
- Détection de frustration via `detectEmotionalState()`
- Instruction contextuelle pour orienter vers support après frustration persistante

---

## DONNÉES DISPONIBLES

### Tables existantes

**bobodo_sessions** :
- id
- user_id
- title
- created_at
- updated_at

**bobodo_messages** :
- id
- session_id
- sender
- content
- safety_flag
- created_at

**bobodo_feedback** :
- id
- session_id
- message_id
- rating
- comment
- created_at

### Analyse des données

**Feedback négatif** :
- Les feedbacks "down" indiquent une insatisfaction
- Ces feedbacks peuvent être analysés pour identifier les motifs d'escalade

**Messages étudiants** :
- Les messages contenant des motifs de frustration peuvent être analysés
- Les messages non couverts par les fiches peuvent être identifiés

---

## STATISTIQUES À COLLECTER

### 1. Nombre de redirections support

**Méthode** :
- Compter les feedbacks "down" dans `bobodo_feedback`
- Compter les messages contenant des motifs de frustration
- Compter les messages contenant des demandes de support

### 2. Motifs d'escalade

**Catégories** :
- Absence de réponse fiable
- Utilisateur insatisfait
- Plusieurs reformulations sans succès
- Demande administrative
- Problème de candidature
- Problème de paiement
- Université non disponible
- Question hors périmètre
- Besoin d'un accompagnement humain

### 3. Questions non couvertes

**Méthode** :
- Analyser les messages étudiants qui n'ont pas de réponse satisfaisante
- Identifier les thèmes récurrents
- Croiser avec les fiches existantes pour identifier les manques

---

## ANALYSE PROPOSÉE

### Étape 1 : Collecter les feedbacks

```sql
SELECT 
  COUNT(*) as total_feedback,
  COUNT(CASE WHEN rating = 'down' THEN 1 END) as negative_feedback,
  COUNT(CASE WHEN rating = 'up' THEN 1 END) as positive_feedback
FROM app.bobodo_feedback;
```

### Étape 2 : Analyser les motifs de frustration

```sql
SELECT 
  COUNT(*) as total_messages,
  COUNT(CASE WHEN content ILIKE '%pas clair%' THEN 1 END) as unclear,
  COUNT(CASE WHEN content ILIKE '%pas compris%' THEN 1 END) as not_understood,
  COUNT(CASE WHEN content ILIKE '%pas satisfait%' THEN 1 END) as not_satisfied,
  COUNT(CASE WHEN content ILIKE '%tu ne réponds pas%' THEN 1 END) as not_responding
FROM app.bobodo_messages
WHERE sender = 'student';
```

### Étape 3 : Identifier les questions non couvertes

```sql
SELECT 
  content,
  COUNT(*) as frequency
FROM app.bobodo_messages
WHERE sender = 'student'
  AND content ILIKE '%support%'
GROUP BY content
ORDER BY frequency DESC
LIMIT 20;
```

---

## LIMITATIONS ACTUELLES

### Absence de tracking explicite

**Problème** : Il n'existe pas de tracking explicite des redirections support.

**Conséquence** : Impossible de savoir exactement quand Bobodo a orienté vers le support.

**Solution proposée** :
- Ajouter une colonne `escalation_reason` dans `bobodo_messages`
- Marquer les messages où Bobodo a orienté vers le support
- Stocker le motif d'escalade

### Absence de catégorisation

**Problème** : Les motifs d'escalade ne sont pas catégorisés.

**Conséquence** : Impossible d'analyser les motifs par catégorie.

**Solution proposée** :
- Créer une table `bobodo_escalation_events`
- Stocker chaque événement d'escalade avec son motif
- Permettre l'analyse par catégorie

---

## ARCHITECTURE PROPOSÉE

### Nouvelle table : bobodo_escalation_events

```sql
CREATE TABLE app.bobodo_escalation_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES app.bobodo_sessions(id) ON DELETE CASCADE,
  message_id UUID REFERENCES app.bobodo_messages(id) ON DELETE SET NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  escalation_reason TEXT NOT NULL, -- 'no_reliable_answer', 'user_dissatisfied', 'multiple_reformulations', 'administrative_request', 'application_issue', 'payment_issue', 'university_unavailable', 'out_of_scope', 'human_assistance_needed'
  user_message TEXT,
  bot_response TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_bobodo_escalation_user ON app.bobodo_escalation_events(user_id);
CREATE INDEX idx_bobodo_escalation_reason ON app.bobodo_escalation_events(escalation_reason);
CREATE INDEX idx_bobodo_escalation_date ON app.bobodo_escalation_events(created_at);
```

### Modification de bobodo_messages

```sql
ALTER TABLE app.bobodo_messages ADD COLUMN is_escalation BOOLEAN DEFAULT FALSE;
ALTER TABLE app.bobodo_messages ADD COLUMN escalation_reason TEXT;
```

### Nouvelle RPC : app_log_bobodo_escalation

Logger automatiquement les événements d'escalade dans `bobodo_escalation_events`.

---

## ÉTAT ACTUEL DES STATISTIQUES

⚠️ **DONNÉES INSUFFISANTES**

**Raison** :
- Pas de tracking explicite des redirections support
- Pas de catégorisation des motifs
- Données historiques limitées

**Action requise** :
- Implémenter le tracking des escalades
- Collecter les données sur une période significative
- Analyser les données après collecte

---

## RECOMMANDATIONS

### Court terme

1. **Implémenter le tracking des escalades**
   - Créer la table `bobodo_escalation_events`
   - Modifier `bobodo-chat` pour logger les escalades
   - Ajouter la RPC `app_log_bobodo_escalation`

2. **Analyser les feedbacks existants**
   - Analyser les feedbacks "down"
   - Identifier les motifs récurrents
   - Croiser avec les messages

### Moyen terme

3. **Collecter les données sur 2-4 semaines**
   - Laisser le tracking en place
   - Collecter suffisamment de données
   - Analyser les tendances

4. **Identifier les enrichissements prioritaires**
   - Analyser les motifs d'escalade
   - Identifier les questions non couvertes
   - Prioriser les enrichissements de connaissances

### Long terme

5. **Automatiser l'analyse**
   - Créer des dashboards de monitoring
   - Alertes sur les pics d'escalade
   - Recommandations automatiques d'enrichissement

---

## CONCLUSION

**État actuel** : Règle d'escalade implémentée, mais pas de tracking des données.

**Statistiques disponibles** : Insuffisantes pour une analyse pertinente.

**Action requise** : Implémenter le tracking des escalades avant de pouvoir produire des statistiques fiables.

**Priorité** : Moyenne - Amélioration de la qualité des connaissances, mais non bloquante pour LOT B.

---

**ANALYSE TERMINÉE - DONNÉES INSUFFISANTES**
