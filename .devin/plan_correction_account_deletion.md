# PLAN DE CORRECTION — SUPPRESSION DE COMPTE ETUDIANT ACADEMIA

**Statut** : Plan documentaire (aucune modification effectuee)
**Date** : 2026-06-04

---

## PHASE 1 — INVENTAIRE DEFINITIF

| # | Objet | Type | Schema | Existe | Modification | Impact | Risque |
|---|-------|------|--------|--------|------------|--------|--------|
| 1 | `deletion_requested_at` | Colonne | `app.user_admin_status` | Non | **Creer** (ALTER ADD COLUMN) | Colonne nullable, donnees existantes non touchees | Faible |
| 2 | `purge_due_at` | Colonne | `app.user_admin_status` | Non | **Creer** (ALTER ADD COLUMN) | Idem | Faible |
| 3 | `deletion_method` | Colonne | `app.user_admin_status` | Non | **Creer** (ALTER ADD COLUMN DEFAULT 'self_service') | Colonne avec default — lignes existantes misent a 'self_service' | Faible |
| 4 | `app_student_request_account_deletion` | RPC | `public` | Non | **Creer** | Rend fonctionnel le bouton Flutter | Critique si mal implemente |
| 5 | `app_admin_purge_deleted_accounts` | RPC | `public` | Non | **Creer** | Active la purge automatique apres 60j | Eleve (suppression physique) |
| 6 | `purge_deleted_accounts` | Cron | `cron.job` | Oui (orphelin) | **Modifier** commande | Passe d'inoperant a fonctionnel | Faible |
| 7 | `app_check_account_status` | RPC | `public` | Oui | **Conserver** | Deja corrige et fonctionnel | Aucun |
| 8 | `app_admin_delete_user_account` | RPC | `public` | Oui | **Conserver** | Soft-delete admin, logique distincte | Aucun |
| 9 | `app_admin_update_user_status` | RPC | `public` | Oui | **Conserver** | Suspension/reactivation, logique distincte | Aucun |
| 10 | `user_admin_status` | Table | `app` | Oui | **Conserver** (ALTER uniquement) | Table centrale | Faible |
| 11 | `admin_user_action_logs` | Table | `app` | Oui | **Conserver** | Journal existant | Aucun |

### Dependances

- `deletion_requested_at` : ecrite par RPC etudiant, lue par `app_check_account_status`
- `purge_due_at` : ecrite par RPC etudiant (`NOW()+60j`), lue par RPC purge (`<= NOW()`) et Flutter (`_AccountDeletedConfirmationScreen`)
- `deletion_method` : ecrite `'self_service'` (etudiant) ou `'purged'` (cron), filtree `IS NOT NULL` par le cron
- `app_student_request_account_deletion` : depend de `auth.uid()`, `auth.users`, `user_admin_status`, `auth.sessions`, `auth.refresh_tokens`, `user_device_tokens`, `admin_user_action_logs`
- `app_admin_purge_deleted_accounts` : depend de 25+ tables de donnees utilisateur + `students` + `auth.users`

---

## PHASE 2 — PLAN DE MIGRATION LIGNE PAR LIGNE

### Etape 1 — Sauvegarde
- **Objectif** : Preserver l'etat actuel avant toute modification
- **Actions** : Exporter `app.user_admin_status` via `COPY TO` ou `SELECT *`. Noter la commande actuelle du cron job #3.
- **Risques** : Aucun (lecture seule)

### Etape 2 — ALTER TABLE
- **Objectif** : Ajouter les 3 colonnes de gestion du cycle de suppression
- **Actions** : `ALTER TABLE app.user_admin_status ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMPTZ;` puis `ADD COLUMN IF NOT EXISTS purge_due_at TIMESTAMPTZ;` puis `ADD COLUMN IF NOT EXISTS deletion_method TEXT DEFAULT 'self_service';`
- **Impact** : Colonnes ajoutees. Lignes existantes : `deletion_method` = 'self_service'. `deletion_requested_at` et `purge_due_at` = NULL.
- **Risques** : Tres faible (`IF NOT EXISTS`).
- **Rollback** : `DROP COLUMN IF EXISTS` (si aucune donnee ecrite ou perte acceptable)

### Etape 3 — Creer RPC `public.app_student_request_account_deletion()`
- **Objectif** : Rendre fonctionnelle la suppression etudiant depuis Flutter
- **Actions** : Copier la logique du fichier source lignes 22-129 dans le schema `public` (adapter `app.` en `public.`)
- **Impact** : `client.rpc('app_student_request_account_deletion')` fonctionnera
- **Risques** : Moyen — manipule `auth.users`, `auth.sessions`, `auth.refresh_tokens`. `SECURITY DEFINER` requis.
- **Rollback** : `DROP FUNCTION IF EXISTS public.app_student_request_account_deletion();`

### Etape 4 — Creer RPC `public.app_admin_purge_deleted_accounts()`
- **Objectif** : Permettre au cron de purger les comptes apres 60j
- **Actions** : Copier la logique du fichier source lignes 137-329 dans le schema `public`
- **Impact** : Le cron pourra executer la purge
- **Risques** : **ELEVE** — supprime physiquement dans 25+ tables. Mitigation : `FOR ... LOOP` avec `EXCEPTION WHEN OTHERS` par iteration.
- **Rollback** : `DROP FUNCTION` — mais donnees deja supprimees non recuperables

### Etape 5 — Corriger le cron `purge_deleted_accounts`
- **Objectif** : Faire pointer le cron vers `public.app_admin_purge_deleted_accounts()`
- **Actions** : `SELECT cron.unschedule('purge_deleted_accounts');` puis `SELECT cron.schedule('purge_deleted_accounts', '0 3 * * *', $$SELECT public.app_admin_purge_deleted_accounts()$$);`
- **Impact** : Le cron cessera d'echouer quotidiennement
- **Risques** : Faible. Ordre : Etape 4 AVANT Etape 5.
- **Rollback** : `cron.unschedule` puis recreer avec ancienne commande

### Etape 6 — Attribution des permissions (GRANT)
- **Objectif** : Permettre aux roles appropries d'executer les nouveaux RPCs
- **Actions** : `GRANT EXECUTE ON FUNCTION public.app_student_request_account_deletion() TO authenticated;` et `GRANT EXECUTE ON FUNCTION public.app_admin_purge_deleted_accounts() TO authenticated;` (ou service_role selon convention cron)
- **Risques** : Faible — idempotents

### Etape 7 — Verification post-migration
- **Objectif** : Confirmer tous les objets crees et accessibles
- **Actions** : Verifier `information_schema.columns`, `pg_proc`, `cron.job`. Tester appel RPC avec compte de test.
- **Risques** : Aucun

---

## PHASE 3 — ANALYSE DES COLONNES

### `deletion_requested_at`
- **Type** : `TIMESTAMPTZ`, nullable, pas de default
- **Index** : Non requis actuellement. Index partiel envisageable si volume > 100k
- **Flutter** : Non utilise directement
- **RPCs** : Ecrite par `app_student_request_account_deletion`
- **Cron** : Non utilise
- **Compatibilite** : Parfaite (nouvelle colonne nullable)

### `purge_due_at`
- **Type** : `TIMESTAMPTZ`, nullable, pas de default
- **Index** : **Oui recommande** — le cron filtre `purge_due_at <= NOW()`. Index partiel : `ON app.user_admin_status(purge_due_at) WHERE is_deleted = TRUE AND deletion_method IS NOT NULL AND deletion_method != 'purged'`
- **Flutter** : Affichee dans `_AccountDeletedConfirmationScreen` (`purgeDate.substring(0,10)`)
- **RPCs** : Ecrite (`NOW()+60j`), lue par `app_check_account_status`, filtree par purge
- **Cron** : **Critique** — clause WHERE principale
- **Compatibilite** : Parfaite (nullable, comptes non supprimes ignores)

### `deletion_method`
- **Type** : `TEXT`, DEFAULT `'self_service'`
- **Contraintes** : Aucune CHECK. Valeurs attendues : `'self_service'`, `'admin'`, `'purged'`
- **RPCs** : Ecrite `'self_service'` (etudiant) ou `'purged'` (cron). Filtree `IS NOT NULL` par cron.
- **Compatibilite** : Lignes existantes recevront `'self_service'`. Fonctionnellement neutre car `is_deleted = FALSE`. A verifier : compter lignes `WHERE is_deleted = TRUE` avant migration.

---

## PHASE 4 — ANALYSE DES RPC

### `public.app_student_request_account_deletion()`
- **Role metier** : Suppression autonome du compte par l'etudiant (exigence Google Play/App Store)
- **Role technique** : Soft-delete immediate + ban + invalidation sessions + planification purge 60j
- **Parametres** : Aucun (utilise `auth.uid()`)
- **Retour** : `JSONB` : `{"success": true, "message": "...", "purge_due_at": "..."}` ou `{"success": false, "error": "..."}`
- **Tables ecrites** : `user_admin_status` (UPSERT), `auth.users` (banned_until), `auth.sessions` (DELETE), `auth.refresh_tokens` (DELETE), `user_device_tokens` (is_active=FALSE), `admin_user_action_logs` (INSERT)
- **Securite** : `SECURITY DEFINER`. Verifie authentification, role eligible (`student/commercial/merchant`), pas deja pending.
- **RLS** : Aucune (outrepasse par SECURITY DEFINER)
- **Convention** : Nom `app_student_request_account_deletion`, schema `public` — conforme Academia

### `public.app_admin_purge_deleted_accounts()`
- **Role metier** : Purge physique des donnees apres le delai legal de 60j
- **Role technique** : Parcours comptes `is_deleted=TRUE` + `purge_due_at<=NOW()`, supprime donnees filles, anonymise PII, soft-delete auth.users, marque 'purged'
- **Parametres** : Aucun
- **Retour** : `JSONB` : `{"success": true, "purged_count": int, "errors": text[]}`
- **Tables ecrites/supprimees** : 25+ tables (direct_messages, support, prep_*, td_*, video_*, marketplace_*, opportunity_*), `students` (anonymisation), `auth.users` (soft-delete), `user_admin_status` (UPDATE), `admin_user_action_logs` (INSERT)
- **Securite** : `SECURITY DEFINER`, pas de verification de role (appele par cron). `EXCEPTION WHEN OTHERS` par iteration isole les erreurs.
- **Convention** : Nom `app_admin_purge_deleted_accounts`, schema `public` — conforme Academia

### Comparaison avec RPCs existants

| Aspect | `app_admin_delete_user_account` | `app_student_request_account_deletion` |
|--------|----------------------------------|--------------------------------------|
| Appelant | Admin | Etudiant (soi-meme) |
| Ban auth.users | Non | Oui |
| Invalidate sessions | Non | Oui |
| FCM tokens | Non | Oui |
| `purge_due_at` | Non | Oui |
| Portion reutilisable | Aucune — logiques distinctes |

| Aspect | `app_admin_update_user_status` | `app_student_request_account_deletion` |
|--------|--------------------------------|--------------------------------------|
| Action | suspend/reactivate | delete autonome |
| `is_deleted` | Non modifie | Oui |
| Portion reutilisable | Aucune |

| Aspect | `app_check_account_status` (existant) | Source original (`app` schema) |
|--------|--------------------------------------|-------------------------------|
| Schema | `public` (corrige) | `app` (incorrect) |
| Action requise | **Aucune** — deja fonctionnel |

**Conclusion** : Aucune fusion possible. Creations nettes requises.

---

## PHASE 5 — ANALYSE DES PERMISSIONS

| RPC / Objet | Role cible | Permission | Justification |
|-------------|-----------|------------|---------------|
| `public.app_student_request_account_deletion()` | `authenticated` | `EXECUTE` | Tout utilisateur authentifie peut supprimer son compte |
| `public.app_admin_purge_deleted_accounts()` | `authenticated` + `service_role` | `EXECUTE` | Cron (postgres) + convention Academia |
| `app.user_admin_status` (nouvelles colonnes) | `authenticated` | Herite de `SELECT, INSERT, UPDATE` | Deja accorde par migration originale |
| `auth.users`, `auth.sessions`, `auth.refresh_tokens` | — | — | Acces indirect via `SECURITY DEFINER` |

### Risques de securite

| Risque | Niveau | Description | Mitigation |
|--------|--------|-------------|------------|
| R1 — Elevation via SECURITY DEFINER | Moyen | Fonction execute avec droits du createur | Verification `auth.uid()` et role. Search path fixe. |
| R2 — Injection raw_user_meta_data | Faible | `raw_user_meta_data->>'role'` est lu | Operation JSONB natif, pas d'injection SQL |
| R3 — Suppression physique par cron | Eleve | Le cron supprime des donnees | Clause WHERE tres restrictive. Revue de code obligatoire. |

---

## PHASE 6 — ANALYSE DU CRON

| Attribut | Valeur |
|----------|--------|
| **Etat actuel** | Actif mais orphelin. Jobid=3. Commande : `SELECT app.app_admin_purge_deleted_accounts()` |
| **Historique** | Cree manuellement (date inconnue, tres tot, jobid=3). Fichier source commit le 2026-03-25 mais jamais execute. |
| **Premiere execution enregistree** | 2026-04-24 |
| **Statut de toutes les executions** | `failed` — `ERROR: function app.app_admin_purge_deleted_accounts() does not exist` |
| **Fréquence** | `0 3 * * *` (3h UTC quotidien) |
| **Comportement attendu** | Selectionner comptes `is_deleted=TRUE` avec `purge_due_at` depasse, purger donnees, anonymiser |
| **Comportement reel** | Echec quotidien silencieux depuis au moins le 2026-04-24 |

### Strategie de correction

| Option | Description | Recommandation |
|--------|-------------|----------------|
| Remplacer | `cron.unschedule` + `cron.schedule` avec nouvelle commande | **Oui** — la commande actuelle est incorrecte |
| Modifier | Mettre a jour la commande du job existant | Pas possible directement avec `pg_cron` — necessite unschedule+schedule |
| Recreer | Supprimer le job et en creer un nouveau | Equivalent au remplacement |
| Conserver | Laisser tel quel | **Non** — echec quotidien |

**Decision documentee** : **Remplacer** le cron via `cron.unschedule` + `cron.schedule` avec la commande `SELECT public.app_admin_purge_deleted_accounts()`.

---

## PHASE 7 — ANALYSE D'IMPACT

### Tables impactees (purge RPC)

| Domaine | Tables affectees | Operation |
|---------|-----------------|-----------|
| **Messagerie** | `direct_messages`, `direct_conversations`, `direct_message_read_states` | DELETE |
| **Support** | `support_messages`, `support_conversations`, `support_read_states` | DELETE |
| **Commercial** | `commercial_milestone_claims` | DELETE |
| **Prep Concours** | `prep_ai_messages`, `prep_ai_conversations`, `prep_ai_corrections`, `prep_assignment_submissions`, `prep_flashcard_progress`, `prep_live_participants`, `prep_psychotech_profiles`, `prep_psychotech_results`, `prep_quiz_attempts`, `prep_student_badges`, `prep_student_progress` | DELETE |
| **TD** | `td_ai_messages`, `td_ai_conversations`, `td_flashcard_progress`, `td_quiz_attempts`, `td_student_badges`, `td_student_progress`, `td_daily_goals`, `td_streaks`, `td_xp_log` | DELETE |
| **Video** | `video_comments`, `video_favorites`, `video_likes`, `video_reports` | DELETE |
| **Marketplace** | `marketplace_listing_bookmarks`, `marketplace_cart_items`, `marketplace_carts` | DELETE |
| **Opportunites** | `opportunity_bookmarks`, `opportunity_comments`, `opportunity_reactions`, `opportunity_views`, `opportunity_inquiry_messages` | DELETE |
| **Profil** | `students` | UPDATE (anonymisation PII) |
| **Auth** | `auth.users` | UPDATE (soft-delete : email modifie, password vide, meta `role: deleted`) |
| **Audit** | `admin_user_action_logs` | INSERT |
| **Statut** | `user_admin_status` | UPDATE (`deletion_method = 'purged'`) |

### Impact par domaine fonctionnel

| Domaine | Impact | Risque | Validation |
|---------|--------|--------|------------|
| **Authentification** | Compte banni (`banned_until`), sessions invalidees, password efface apres purge | Eleve (bloque l'acces) | Test reconnexion refusee |
| **Etudiants** | Profil anonymise (`full_name = 'Utilisateur supprime'`, etc.) | Moyen | Verifier table `students` |
| **Messagerie** | Messages, conversations, etats de lecture supprimes | Moyen | Verifier tables DM |
| **Marketplace** | Favoris, paniers, articles supprimes | Faible | Verifier marketplace_* |
| **Opportunites** | Favoris, commentaires, reactions, vues supprimes | Faible | Verifier opportunity_* |
| **Prep Concours** | Toutes donnees etudiant supprimees (quiz, badges, progressions, etc.) | Eleve | Verifier prep_* |
| **TD** | Toutes donnees etudiant supprimees | Eleve | Verifier td_* |
| **Video** | Commentaires, likes, favoris, signalements supprimes | Moyen | Verifier video_* |
| **Support** | Conversations et messages supprimes | Faible | Verifier support_* |
| **Commercial** | Reclamations de milestones supprimees | Faible | Verifier commercial_milestone_claims |

---

## PHASE 8 — PLAN DE TESTS

### Test 1 — Demande de suppression
- **Prerequis** : Compte etudiant actif sur le TECNO. App build avec le RPC corrige.
- **Actions** : Naviguer vers Parametres > Supprimer mon compte. Saisir mot de passe. Confirmer.
- **Resultat attendu** : `client.rpc('app_student_request_account_deletion')` retourne `{"success": true, "purge_due_at": "..."}`. `_AccountDeletedConfirmationScreen` s'affiche avec la date de purge.
- **Criteres de succes** : Pas d'erreur PostgrestException 404. JSONB retourne `success=true`.

### Test 2 — Deconnexion automatique
- **Prerequis** : Test 1 reussi.
- **Actions** : Observer le comportement apres succes du RPC.
- **Resultat attendu** : `client.auth.signOut()` est appele. L'ecran de confirmation s'affiche.
- **Criteres de succes** : Aucune session active restante dans `auth.sessions` pour ce `user_id`.

### Test 3 — Blocage de reconnexion
- **Prerequis** : Test 1 et 2 reussis.
- **Actions** : Tenter de se reconnecter avec l'email et le mot de passe du compte supprime.
- **Resultat attendu** : Echec de l'authentification (ban `banned_until = '2099-12-31'`). Message indiquant le compte est inaccessible.
- **Criteres de succes** : `auth.users.banned_until` est datee dans le futur. Aucun token genere.

### Test 4 — Affichage de la date de purge
- **Prerequis** : Test 1 reussi.
- **Actions** : Lire le texte affiche dans `_AccountDeletedConfirmationScreen`.
- **Resultat attendu** : Affichage : `Purge prevue : YYYY-MM-DD` (date = aujourd'hui + 60 jours).
- **Criteres de succes** : Date correcte. Format `YYYY-MM-DD`.

### Test 5 — Execution simulee du cron
- **Prerequis** : Compte de test avec `is_deleted = TRUE` et `purge_due_at` dans le passe.
- **Actions** : Forcer `purge_due_at = NOW() - INTERVAL '1 day'` sur un compte de test. Appeler manuellement `public.app_admin_purge_deleted_accounts()`.
- **Resultat attendu** : JSONB retourne `{"success": true, "purged_count": >=1, "errors": []}`. Le compte test est anonymise dans `students`, `auth.users` soft-deleted, `deletion_method = 'purged'`.
- **Criteres de succes** : Compte bien traite. Pas d'erreur dans `errors`. Donnees associees supprimees.

### Test 6 — Anonymisation
- **Prerequis** : Test 5 reussi.
- **Actions** : Verifier la ligne du compte test dans `app.students`.
- **Resultat attendu** : `full_name = 'Utilisateur supprime'`, `phone = NULL`, `avatar_url = NULL`, etc.
- **Criteres de succes** : Aucun PII conservé dans la ligne.

### Test 7 — Conservation des journaux
- **Prerequis** : Tests 1 et 5 reussis.
- **Actions** : Verifier `app.admin_user_action_logs`.
- **Resultat attendu** : Au moins 2 lignes : `action = 'self_delete_request'` et `action = 'account_purged'`.
- **Criteres de succes** : Journaux presents avec meta JSONB complet.

### Test 8 — Validation Google Play
- **Prerequis** : Tous les tests precedents reussis.
- **Actions** : Verifier que le flux complet (bouton dans UI > mot de passe > confirmation > message de succes > impossible de se reconnecter) est operationnel.
- **Resultat attendu** : Conforme aux exigences Google Play (compte supprimable depuis l'app, delai de suppression clairement indique, confirmation avant action).
- **Criteres de succes** : Le reviewer Google Play pourrait tester ce flux avec succes.

---

## PHASE 9 — PLAN DE ROLLBACK

### Objets a sauvegarder avant migration

| # | Donnee / Objet | Methode de sauvegarde |
|---|---------------|----------------------|
| 1 | `app.user_admin_status` (table complete) | `COPY (SELECT * FROM app.user_admin_status) TO '/tmp/backup_user_admin_status_YYYYMMDD.csv' WITH CSV HEADER;` |
| 2 | Commande actuelle du cron | Note textuelle : `SELECT app.app_admin_purge_deleted_accounts()` |
| 3 | Definition actuelle de `app_check_account_status` | Deja sauvegardee dans `20250603_create_app_check_account_status.sql` |

### Procedures de retour arriere

| # | Etape | Commande de rollback | Reversibilite |
|---|-------|---------------------|---------------|
| 1 | DROP RPC etudiant | `DROP FUNCTION IF EXISTS public.app_student_request_account_deletion();` | Totale |
| 2 | DROP RPC purge | `DROP FUNCTION IF EXISTS public.app_admin_purge_deleted_accounts();` | Totale |
| 3 | Restaurer cron | `SELECT cron.unschedule('purge_deleted_accounts'); SELECT cron.schedule('purge_deleted_accounts', '0 3 * * *', $$SELECT app.app_admin_purge_deleted_accounts()$$);` | Totale |
| 4 | DROP colonnes | `ALTER TABLE app.user_admin_status DROP COLUMN IF EXISTS deletion_requested_at, DROP COLUMN IF EXISTS purge_due_at, DROP COLUMN IF EXISTS deletion_method;` | **Partielle** — les valeurs ecrites entre temps sont perdues. Possible uniquement si aucune suppression n'a eu lieu. |

### Objets critiques vs reversibles

| Objet | Critique | Reversible | Note |
|-------|----------|-----------|------|
| `app_student_request_account_deletion` (RPC) | Non | Totalement | `DROP FUNCTION` suffit |
| `app_admin_purge_deleted_accounts` (RPC) | Non | Totalement | `DROP FUNCTION` suffit |
| Colonnes `user_admin_status` | Oui | Partiellement | `DROP COLUMN` perde les valeurs. Si aucune valeur ecrite, reversible totalement. |
| Cron corrige | Non | Totalement | `unschedule` + recreation ancienne commande |
| Donnees purgees par le cron | **Critique** | **Irreversible** | Une fois le cron execute, les DELETE sur 25+ tables et l'anonymisation sont definitifs. |

**Mesure preventive** : Apres creation du RPC purge mais AVANT correction du cron, forcer `purge_due_at` dans le futur pour tous les comptes existants de test, ou desactiver temporairement le cron (`cron.unschedule`) jusqu'a validation complete.

---

## PHASE 10 — LIVRABLE FINAL ET RECOMMANDATIONS

### Recapitulatif des 10 phases

| Phase | Etat | Livrable |
|-------|------|----------|
| 1 — Inventaire | Complete | 11 objets catalogues avec type, schema, etat, modification, impact, risque |
| 2 — Plan de migration | Complete | 7 etapes documentees avec objectif, actions, impact, risque, rollback |
| 3 — Analyse colonnes | Complete | 3 colonnes analysees (type, index, usage, compatibilite) |
| 4 — Analyse RPCs | Complete | 2 RPCs + comparaison avec 3 RPCs existants. Aucune duplication detectee. |
| 5 — Permissions | Complete | GRANT necessaires + 3 risques de securite identifies et mitiges |
| 6 — Analyse cron | Complete | Etat orphelin confirme. Strategie : remplacer la commande. |
| 7 — Impact | Complete | 25+ tables identifiees, 10 domaines fonctionnels evalues |
| 8 — Plan de tests | Complete | 8 tests avec prerequis, actions, resultats attendus, criteres de succes |
| 9 — Rollback | Complete | Sauvegarde, procedures, objets critiques vs reversibles |

### Recommandations finales

1. **Executer les 7 etapes de migration dans l'ordre strict** (Etape 1 a 7). Ne pas inverser Etape 4 et 5.
2. **Compter les lignes `WHERE is_deleted = TRUE`** dans `user_admin_status` avant l'ALTER TABLE — si des comptes sont deja soft-deletes par `app_admin_delete_user_account`, le DEFAULT `'self_service'` pourrait les rendre eligibles au cron par erreur.
3. **Ajouter l'index partiel sur `purge_due_at`** lors de l'Etape 2 (ALTER TABLE) ou immediatement apres, avant la premiere execution du cron.
4. **Tester avec un compte sacrifiable** sur le TECNO avant de declarer la correction terminee.
5. **Ne pas fusionner** les RPCs existants avec les nouveaux — les responsabilites sont distinctes.
6. **Documenter le plan de rollback** (Phase 9) avant toute execution SQL.

**Aucune modification effectuee. Aucun SQL execute. Ce document est pret pour revue technique et autorisation de correction.**
