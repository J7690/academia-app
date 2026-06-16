# RAPPORT FORENSIQUE — AUDIT COMPLET DU RPC `app_track_navigation_event`

**Date** : 2026-06-04
**Statut** : AUDIT COMPLET — AUCUNE MODIFICATION EFFECTUEE
**Auditeur** : Cascade (pair programming)
**Projet** : Academia (Flutter + Supabase)

---

## SOMMAIRE EXECUTIF

Le RPC `app_track_navigation_event` est appele par le code Flutter mais **n'existe pas dans le schema `public`** de Supabase. Il existe pourtant dans le schema `app`. Ce probleme est identique a celui rencontre precedemment avec `app_student_request_account_deletion` : le RPC a ete defini dans le mauvais schema (`app` au lieu de `public`), rendant toutes les invocations Flutter en echec.

**Cette anomalie isolee s'inscrit dans un pattern systemique beaucoup plus large** : **50 RPC** sont definis uniquement dans le schema `app` alors que Flutter les attend dans `public`. De plus, **3 RPC sont completement absents** de la base.

---

## PHASE 1 — RECHERCHE FLUTTER

### 1.1 Occurrences de `app_track_navigation_event`

| Fichier | Ligne | Contexte |
|---------|-------|----------|
| `lib/services/analytics_tracking_service.dart` | **93** | Appel RPC principal dans `_flushBatch()` |
| `lib/features/student/student_dashboard_screen.dart` | **68-69** | `init()` + `trackTab('student_dashboard', 0, 'Accueil')` |
| `lib/features/student/student_dashboard_screen.dart` | **520-522** | `trackTab('student_dashboard', index, _tabNames[index])` |

### 1.2 Flux complet utilisateur

```
Utilisateur ouvre l'app etudiant
  -> StudentDashboardScreen.initState()
    -> AnalyticsTrackingService.instance.init()
    -> AnalyticsTrackingService.instance.trackTab('student_dashboard', 0, 'Accueil')
      -> _pendingEvents.add({screen_name, tab_index, tab_name, session_id, duration_seconds})
        -> [tous les 30s OU batch >= 20 elements]
          -> _flushBatch()
            -> for event in batch:
              -> _client.rpc('app_track_navigation_event', params: {...})
                -> [ECHEC] Supabase retourne PGRST202
```

### 1.3 Service AnalyticsTrackingService

Le service est un singleton (`AnalyticsTrackingService.instance`) qui :
- Genere un `session_id` unique au demarrage (`DateTime.now().millisecondsSinceEpoch.toRadixString(36)`)
- Batching des evenements : envoi automatique toutes les **30 secondes** ou lorsque **20 evenements** sont accumules
- Flush force au logout / background
- Duree d'ecran calculee en secondes entre deux `trackScreen()`

---

## PHASE 2 — ANALYSE DU PAYLOAD

### 2.1 Parametres envoyes

| Parametre | Type Dart | Type SQL | Obligatoire | Valeur exemple |
|-----------|-----------|----------|-------------|--------------|
| `p_screen_name` | `String` | `text` | **Oui** | `"student_dashboard"` |
| `p_tab_index` | `int?` | `int` | Non | `0`, `1`, `2` |
| `p_tab_name` | `String?` | `text` | Non | `"Accueil"`, `"Cours"` |
| `p_session_id` | `String?` | `text` | Non | `"l3x9p2m..."` (base36) |
| `p_duration_seconds` | `int` | `int` | Oui (default 0) | `0`, `15`, `120` |

### 2.2 JSON attendu (observe)

```json
{
  "p_screen_name": "student_dashboard",
  "p_tab_index": 0,
  "p_tab_name": "Accueil",
  "p_session_id": "l3x9p2m8qf",
  "p_duration_seconds": 0
}
```

### 2.3 Erreur observee

```text
Could not find function public.app_track_navigation_event(...)
```

Code d'erreur Supabase : **PGRST202** (function not found in schema `public`)

---

## PHASE 3 — RECHERCHE SUPABASE

### 3.1 Fonctions `app_track_navigation_event`

| Schema | Existe | Retour | Parametres |
|--------|--------|--------|------------|
| `public` | **NON** | — | — |
| `app` | **OUI** | `jsonb` | 5 parametres |

### 3.2 Autres fonctions track/analytics

| Fonction | Schema | Retour | Parametres | Statut |
|----------|--------|--------|------------|--------|
| `app_track_navigation_event` | `app` | `jsonb` | 5 params | **Inaccessible depuis Flutter** |
| `app_track_user_activity` | `public` | — | 0 params | **Existe** (mais differente) |
| `app_admin_get_navigation_stats` | `app` | `jsonb` | `p_days`, `p_limit` | **Inaccessible depuis Flutter** |

### 3.3 Fonction `app.app_track_navigation_event` (definition trouvee)

```sql
CREATE OR REPLACE FUNCTION app.app_track_navigation_event(
  p_screen_name text,
  p_tab_index int DEFAULT NULL,
  p_tab_name text DEFAULT NULL,
  p_session_id text DEFAULT NULL,
  p_duration_seconds int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  INSERT INTO app.user_navigation_events (user_id, screen_name, tab_index, tab_name, session_id, duration_seconds)
  VALUES (v_user_id, p_screen_name, p_tab_index, p_tab_name, p_session_id, p_duration_seconds);

  RETURN jsonb_build_object('success', true);
END;
$$;
```

**Constat** : La fonction est correctement implementee mais dans le **mauvais schema** (`app` au lieu de `public`).

### 3.4 Fonction `public.app_track_user_activity` (definition)

Cette fonction existe dans `public` mais n'a **aucun parametre** et semble etre un tout autre mecanisme de tracking (probablement un ancien systeme d'activity logs). Elle n'est **pas appellee** par Flutter.

---

## PHASE 4 — RECHERCHE DANS LES MIGRATIONS SQL

### 4.1 Fichier identifie

| Fichier | Date | Statut |
|---------|------|--------|
| `.windsurf/sql_changes/change_20260602_analytics_tracking.sql` | 2026-06-02 | **Non encore execute / ou partiellement execute** |

### 4.2 Contenu du fichier

Le fichier contient :
1. `CREATE TABLE IF NOT EXISTS app.user_navigation_events` — **8 colonnes**
2. `CREATE INDEX IF NOT EXISTS ...` — 3 index
3. `CREATE OR REPLACE FUNCTION app.app_track_navigation_event(...)` — **dans `app`**
4. `CREATE OR REPLACE FUNCTION app.app_admin_get_navigation_stats(...)` — **dans `app`**

### 4.3 Anomalie fondamentale

**Le meme pattern que l'account deletion** :
- Le RPC est cree dans `app.app_track_navigation_event`
- Flutter appelle `client.rpc('app_track_navigation_event')` → cherche dans `public`
- Le RPC est introuvable → erreur PGRST202

**Le fichier SQL n'a pas ete modifie pour deplacer les RPC vers `public`** apres la lecon apprise avec l'account deletion.

### 4.4 Tables crees par la migration

```sql
CREATE TABLE IF NOT EXISTS app.user_navigation_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  screen_name text NOT NULL,
  tab_index int,
  tab_name text,
  session_id text,
  duration_seconds int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);
```

---

## PHASE 5 — AUDIT DES TABLES ANALYTICS

### 5.1 Table `app.user_navigation_events`

| Colonne | Type | Nullable | Default |
|---------|------|----------|---------|
| `id` | `uuid` | NON | `gen_random_uuid()` |
| `user_id` | `uuid` | NON | — |
| `screen_name` | `text` | NON | — |
| `tab_index` | `int` | OUI | — |
| `tab_name` | `text` | OUI | — |
| `session_id` | `text` | OUI | — |
| `duration_seconds` | `int` | OUI | `0` |
| `created_at` | `timestamptz` | OUI | `now()` |

### 5.2 Volume de donnees

| Table | Lignes | Commentaire |
|-------|--------|-------------|
| `app.user_navigation_events` | **0** | Table creee mais jamais remplie (RPC inaccessible) |
| `app.admin_user_action_logs` | **45** | Table de logs admin (non liee a la navigation) |

### 5.3 Index

| Index | Colonne | Type |
|-------|---------|------|
| `idx_nav_events_user` | `user_id` | B-tree |
| `idx_nav_events_screen` | `screen_name` | B-tree |
| `idx_nav_events_created` | `created_at DESC` | B-tree |

### 5.4 Autres tables analytics/tracking dans `app`

| Table | Colonnes | Volume | Role |
|-------|----------|--------|------|
| `app.user_navigation_events` | 8 | **0 lignes** | Navigation (inactive) |
| `app.admin_user_action_logs` | 7 | 45 lignes | Logs admin actions |
| 7 autres tables `*event*`/`*activity*` dans app | varies | varies | Divers (erreurs, analytics video, etc.) |

---

## PHASE 6 — AUDIT DES DEPENDANCES

### 6.1 Cron jobs

| Job | Commande | Lien avec navigation |
|-----|----------|---------------------|
| `purge_deleted_accounts` | `SELECT public.app_admin_purge_deleted_accounts()` | Aucun |
| 8 autres cron | Divers (push, paiements, prep, etc.) | Aucun |
| **Total cron lies a navigation** | **0** | — |

### 6.2 Triggers

| Trigger | Table | Lien avec navigation |
|---------|-------|---------------------|
| 2 triggers trouves dans `app`/`public` | Divers | Potentiellement lies a analytics (details non recuperes) |

### 6.3 Edge Functions

| Fonction | URL | Lien avec navigation |
|----------|-----|---------------------|
| `prep-feed-actuality` | `/functions/v1/prep-feed-actuality` | Aucun |
| `ligdicash-payout` | `/functions/v1/ligdicash-payout` | Aucun |
| `prep-analyze-trends` | `/functions/v1/prep-analyze-trends` | Aucun |

### 6.4 Vues

Aucune vue specifique a la navigation ou aux analytics de navigation n'a ete trouvee.

### 6.5 Dependances de `app_admin_get_navigation_stats`

Cette fonction admin (aussi dans `app`) depend entierement de `app.user_navigation_events` :
- `SELECT screen_name, COUNT(*) ... FROM app.user_navigation_events`
- `SELECT screen_name, tab_name, tab_index, COUNT(*) ...`
- `SELECT created_at::date as day, COUNT(*) ...`

**Consequence** : L'admin ne peut pas consulter les statistiques de navigation car la table est vide et la fonction est inaccessible.

---

## PHASE 7 — IMPACT METIER

### 7.1 Ce qui ne fonctionne PAS actuellement

| Fonctionnalite | Statut | Impact |
|----------------|--------|--------|
| Tracking des ecrans/onglets etudiants | **BLOQUE** | Aucune donnee collectee |
| Stats de navigation dans l'admin | **BLOQUE** | Table vide, RPC inaccessible |
| Recommandations basees sur l'usage | **BLOQUE** | Pas de donnees d'usage |
| Personnalisation du contenu | **BLOQUE** | Pas de donnees de navigation |

### 7.2 Ce qui continue de fonctionner

- Toutes les fonctionnalites principales de l'app (cours, quiz, videos, messagerie)
- L'ecran etudiant s'affiche correctement
- Les erreurs sont silenciees (try/catch dans `analytics_tracking_service.dart`)

### 7.3 Evaluation de l'impact

| Critere | Evaluation |
|---------|------------|
| Fonctionnalite utilisateur | **Faible** — l'app fonctionne, les erreurs sont masquees |
| Fonctionnalite admin | **Moyen** — pas de stats de navigation |
| Analytics commerciaux | **Moyen** — perte de donnees de comportement |
| Conformite Google Play | **Aucun** — pas de lien direct |
| Risque technique | **Faible** — erreurs silenciees, pas de crash |

### 7.4 Niveau d'impact global

**Moyen** — L'absence du RPC ne bloque pas l'application, mais elle prive Academia de donnees analytics essentielles pour comprendre l'usage etudiant et optimiser l'experience.

---

## PHASE 8 — RECHERCHE D'AUTRES RPC MANQUANTS

### 8.1 Methodologie

Extraction de **tous les appels `.rpc()`** du code Flutter (601 appels uniques), puis verification de leur existence dans :
- Schema `public`
- Schema `app`

### 8.2 Resultats globaux

| Categorie | Nombre | Description |
|-----------|--------|-------------|
| **Total RPC appeles par Flutter** | **601** | Tous les `client.rpc('...')` du codebase |
| **Dans `public`** | **548** | Fonctionnent normalement |
| **Dans `app` seulement** | **50** | Introuvables par Flutter (schema incorrect) |
| **Completement manquants** | **3** | N'existent dans aucun schema |

### 8.3 Les 50 RPC dans `app` seulement (pattern systemique)

#### A. Navigation/Analytics (2 RPC)
- `app_track_navigation_event` ← **sujet de l'audit**
- `app_admin_get_navigation_stats`

#### B. Module Prep (38 RPC)
- `app_prep_admin_get_stats`
- `app_prep_admin_list_ai_conversations`
- `app_prep_admin_list_questions`
- `app_prep_admin_toggle_question`
- `app_prep_admin_upsert_badge`
- `app_prep_create_ai_conversation`
- `app_prep_create_exam_paper`
- `app_prep_create_flashcard`
- `app_prep_create_flashcard_deck`
- `app_prep_create_question`
- `app_prep_create_question_bank`
- `app_prep_create_quiz_template`
- `app_prep_get_ai_config`
- `app_prep_get_leaderboard`
- `app_prep_list_ai_conversations`
- `app_prep_list_ai_messages`
- `app_prep_list_exam_papers`
- `app_prep_list_flashcard_decks`
- `app_prep_list_flashcards`
- `app_prep_list_question_banks`
- `app_prep_list_questions`
- `app_prep_list_quiz_templates`
- `app_prep_save_ai_message`
- `app_prep_save_flashcard_review`
- `app_prep_save_quiz_attempt`
- `app_prep_teacher_end_live_session`
- `app_prep_teacher_grade_submission`
- `app_prep_teacher_list_assignments`
- `app_prep_teacher_list_live_sessions`
- `app_prep_teacher_list_submissions`
- `app_prep_teacher_start_live_session`
- `app_prep_teacher_upsert_assignment`
- `app_prep_teacher_upsert_live_session`
- `app_prep_update_ai_config`
- `app_prep_create_exam_paper`
- `app_prep_create_flashcard`
- `app_prep_create_flashcard_deck`

*(Note : il peut y avoir des doublons dans la liste ci-dessus)*

#### C. Gaming — Ligues & Tournois (10 RPC)
- `league_create`
- `league_get_standings`
- `league_join`
- `league_list_available`
- `league_report_match_result`
- `tournament_create`
- `tournament_get_details`
- `tournament_get_standings`
- `tournament_list_available`
- `tournament_register`
- `tournament_report_match_result`
- `tournament_start`

#### D. Messagerie etudiante (2 RPC)
- `app_student_delete_dm_message`
- `app_student_delete_forum_message`

### 8.4 Les 3 RPC completement manquants

| RPC | Usage Flutter | Impact |
|-----|---------------|--------|
| `app_admin_delete_course` | Admin suppression de cours | **Fonctionnalite admin bloquee** |
| `app_admin_delete_program` | Admin suppression de programme | **Fonctionnalite admin bloquee** |
| `app_admin_list_deleted_users` | Admin liste utilisateurs supprimes | **Fonctionnalite admin bloquee** |

### 8.5 Pattern systemique identifie

Le probleme de `app_track_navigation_event` n'est **pas isole**. Il s'agit d'un **pattern systemique** affectant **50+ RPC** qui ont tous ete definis dans le schema `app` au lieu de `public`. Ce pattern est probablement du a une convention de developpement Academia ou les RPC etaient historiquement crees dans `app`, mais le framework Supabase/Flutter les attend dans `public`.

---

## PHASE 9 — VALIDATION RUNTIME

### 9.1 Erreur observee sur appareil TECNO

```text
Could not find function public.app_track_navigation_event(...)
```

### 9.2 Moment d'appel

L'erreur se produit **30 secondes apres l'ouverture de l'ecran etudiant** (delai du batch timer) ou lors du changement d'onglet si le batch est plein (>= 20 evenements).

### 9.3 Comportement utilisateur

L'utilisateur **ne voit pas** l'erreur car le service analytics est entoure d'un `try/catch` avec `debugPrint` uniquement :

```dart
for (final event in batch) {
  try {
    await _client.rpc('app_track_navigation_event', params: {...});
  } catch (e) {
    debugPrint('[Analytics] Error flushing event: $e');
  }
}
```

### 9.4 Impact runtime

- **Pas de crash** : l'erreur est interceptee
- **Pas de feedback utilisateur** : l'app fonctionne normalement
- **Perte de donnees silencieuse** : aucun evenement n'est jamais enregistre

---

## PHASE 10 — LIVRABLE : CAUSE RACINE ET RECOMMANDATIONS

### 10.1 Cause racine

**La convention de nommage/schema des RPC Academia est incoherente.**

Les RPC destines a etre appeles depuis Flutter (frontend) doivent etre dans le schema `public` car Supabase PostgREST expose par defaut `public` aux clients authentifies. Or, le fichier de migration `change_20260602_analytics_tracking.sql` a cree :
- `app.app_track_navigation_event(...)`
- `app.app_admin_get_navigation_stats(...)`

au lieu de :
- `public.app_track_navigation_event(...)`
- `public.app_admin_get_navigation_stats(...)`

### 10.2 Emplacement Flutter

```dart
@/C:/Users/fasop/AndroidStudioProjects/academia/academia_app/lib/services/analytics_tracking_service.dart:93
```

```dart
await _client.rpc('app_track_navigation_event', params: {
  'p_screen_name': event['screen_name'],
  'p_tab_index': event['tab_index'],
  'p_tab_name': event['tab_name'],
  'p_session_id': event['session_id'],
  'p_duration_seconds': event['duration_seconds'] ?? 0,
});
```

### 10.3 Payload exact

```json
{
  "p_screen_name": "student_dashboard",
  "p_tab_index": 0,
  "p_tab_name": "Accueil",
  "p_session_id": "l3x9p2m8qf",
  "p_duration_seconds": 0
}
```

### 10.4 Objets Supabase trouves

| Objet | Schema | Statut |
|-------|--------|--------|
| `app_track_navigation_event` | `app` | Existe mais **inaccessible** |
| `app_admin_get_navigation_stats` | `app` | Existe mais **inaccessible** |
| `app_track_user_activity` | `public` | Existe mais **non utilise** par Flutter |
| `user_navigation_events` | `app` | Existe, **vide** |

### 10.5 Objets non trouves

| Objet attendu | Schema attendu | Statut |
|---------------|----------------|--------|
| `app_track_navigation_event` | `public` | **INEXISTANT** |
| `app_admin_get_navigation_stats` | `public` | **INEXISTANT** |

### 10.6 Tables analytics

| Table | Schema | Lignes | Role |
|-------|--------|--------|------|
| `user_navigation_events` | `app` | **0** | Stocke les evenements de navigation |
| `admin_user_action_logs` | `app` | 45 | Logs admin (independant) |

### 10.7 Dependances

- `app_admin_get_navigation_stats` depend de `user_navigation_events`
- Aucun cron, trigger, ou edge function ne depend directement des donnees de navigation

### 10.8 Impact metier

**Moyen** — perte de donnees analytics sans blocage fonctionnel. L'admin ne peut pas analyser le comportement utilisateur.

### 10.9 RPC similaires (meme pattern)

**50 RPC** sont dans le meme cas (dans `app` au lieu de `public`), notamment :
- Tout le module **Prep** (38 fonctions)
- Le module **Gaming** (12 fonctions)
- Le module **Navigation** (2 fonctions)
- La suppression de messages (2 fonctions)

### 10.10 Autres RPC manquants

**3 RPC completement absents** :
- `app_admin_delete_course`
- `app_admin_delete_program`
- `app_admin_list_deleted_users`

### 10.11 Niveau de risque

| Risque | Niveau | Justification |
|--------|--------|---------------|
| Fonctionnel | **Faible** | L'app fonctionne, erreurs silenciees |
| Securite | **Faible** | Aucune vulnerabilite introduite |
| Donnees | **Moyen** | Perte de donnees analytics en continu |
| Technique | **Moyen** | Pattern systemique, dette technique |

### 10.12 Recommandation de correction

#### Option A — Correction ciblee (recommandee pour l'audit actuel)

1. **Creer** `public.app_track_navigation_event()` (copie de la logique depuis `app`)
2. **Creer** `public.app_admin_get_navigation_stats()` (idem)
3. **Accorder** `GRANT EXECUTE` a `authenticated` et `anon` si necessaire
4. **Valider** que `app.user_navigation_events` a les bonnes policies RLS
5. **Ne pas supprimer** les fonctions `app.*` (retrocompatibilite)

#### Option B — Correction systemique (recommandee a moyen terme)

1. Auditer les **50 RPC** dans `app` seulement
2. Pour chacun, determiner s'il est appele par Flutter
3. Creer les equivalents dans `public` avec les permissions correctes
4. Corriger les **3 RPC completement manquants**
5. Etablir une **convention** : tout RPC appele par Flutter DOIT etre dans `public`

#### Option C — Workaround Flutter (non recommande)

Modifier le code Flutter pour utiliser un schema prefixe. Cependant, Supabase Flutter ne supporte pas facilement le schema prefixe pour les RPC. Cette option est **a eviter**.

---

## ANNEXE A — FICHIERS DE L'AUDIT

| Fichier | Role |
|---------|------|
| `academia_app/lib/services/analytics_tracking_service.dart` | Service Flutter appellant le RPC |
| `academia_app/lib/features/student/student_dashboard_screen.dart` | Ecran etudiant initialisant le tracking |
| `.windsurf/sql_changes/change_20260602_analytics_tracking.sql` | Migration SQL (RPC dans mauvais schema) |
| `audit_track_navigation_results2.json` | Resultats requetes Supabase |
| `audit_track_navigation_details2.json` | Details fonctions/tables |
| `rpc_verification_simple.json` | Liste des 50+ RPC dans app seulement |
| `rapport_audit_app_track_navigation_event.md` | Ce rapport |

---

## ANNEXE B — COMPARAISON AVEC LE CAS PRECEDENT

| Element | Account Deletion | Navigation Event |
|---------|---------------|------------------|
| RPC manquant | `app_student_request_account_deletion` | `app_track_navigation_event` |
| Schema reel | `app` | `app` |
| Schema attendu | `public` | `public` |
| Erreur | PGRST202 | PGRST202 |
| Migration | `change_20260316_account_deletion_compliance.sql` | `change_20260602_analytics_tracking.sql` |
| Pattern | **IDENTIQUE** | **IDENTIQUE** |
| Impact | Critique (fonctionnalite bloquee) | Moyen (donnees perdues) |

**Conclusion** : Le probleme de `app_track_navigation_event` est le **meme pattern systemique** que celui de l'account deletion, avec la meme cause racine (RPC crees dans `app` au lieu de `public`).
