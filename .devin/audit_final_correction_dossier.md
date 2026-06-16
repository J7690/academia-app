# DOSSIER FINAL DE CORRECTION — SUPPRESSION DE COMPTE ACADEMIA

**Date** : 2026-06-04
**Statut** : PRET POUR REVUE — AUCUNE EXECUTION EFFECTUEE
**Script** : `change_20260604_account_deletion_final.sql`

---

## SOMMAIRE

1. Script SQL final
2. Revue ligne par ligne
3. Validation des colonnes
4. Validation des RPC
5. Validation du cron
6. Protocole de tests
7. Controle final de securite
8. Plan de rollback

---

## 1. SCRIPT SQL FINAL

Fichier : `change_20260604_account_deletion_final.sql`

### Principales corrections par rapport au script initial (2026-03-16)

| Element | Script initial (inapplique) | Script final (corrige) |
|---------|----------------------------|------------------------|
| Schema des RPC | `app.` | `public.` (convention Academia) |
| `deletion_method` DEFAULT | `DEFAULT 'self_service'` | **Aucun DEFAULT** (nullable) |
| Cron appelle | `app.app_admin_purge_deleted_accounts()` | `public.app_admin_purge_deleted_accounts()` |
| Condition cron | `deletion_method IS NOT NULL` | `deletion_method = 'self_service'` |
| `app_check_account_status` | Modifiee dans le script | **Non touchee** (RPC existant) |

---

## 2. REVUE LIGNE PAR LIGNE

### Bloc 1 — ALTER TABLE (lignes 35-39)

```sql
ALTER TABLE app.user_admin_status
  ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS purge_due_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deletion_method TEXT;
```

| Aspect | Detail |
|--------|--------|
| **Objectif** | Ajouter 3 colonnes pour le workflow de suppression |
| **Objets touches** | `app.user_admin_status` |
| **Impact attendu** | Toutes les lignes existantes (25) conservent NULL dans les 3 colonnes |
| **Dependances** | `app.user_admin_status` doit exister (confirme) |
| **Risques** | NUL — `IF EXISTS` empeche l'erreur si reapplique |
| **Rollback** | `ALTER TABLE app.user_admin_status DROP COLUMN IF EXISTS <colonne>;` |

**Validation securite** :
- Aucun DEFAULT => les 23 comptes historiques restent avec `deletion_method = NULL`
- Le cron les ignorera (`deletion_method = 'self_service'` vs `NULL`)

---

### Bloc 2 — public.app_student_request_account_deletion() (lignes 41-179)

| Aspect | Detail |
|--------|--------|
| **Objectif** | RPC appele par Flutter lorsqu'un etudiant demande la suppression |
| **Schema** | `public` (convention Academia) |
| **Parametres** | Aucun (utilise `auth.uid()`) |
| **Retour** | `JSONB` : `{success, message, purge_due_at}` ou `{success, error}` |
| **Controles securite** | auth.uid() non NULL ; role IN ('student','commercial','merchant') ; `is_deleted` non deja TRUE |
| **Tables impactees** | `app.user_admin_status`, `auth.users`, `auth.sessions`, `auth.refresh_tokens`, `app.user_device_tokens`, `app.admin_user_action_logs` |
| **Compatibilite Flutter** | Appel `client.rpc('app_student_request_account_deletion')` — le nom de la fonction dans `public` est visible comme RPC Supabase |
| **Dependances** | `auth.users`, `app.user_admin_status`, `app.user_device_tokens`, `app.admin_user_action_logs` |
| **Risques** | Si `auth.uid()` est NULL (bug auth), le RPC refuse. Si le role est admin, le RPC refuse avec message explicite. |
| **Rollback** | `DROP FUNCTION IF EXISTS public.app_student_request_account_deletion();` |

**Points d'attention** :
- `ON CONFLICT (user_id) DO UPDATE` : si le compte existe deja dans `user_admin_status`, il est mis a jour
- `banned_until = '2099-12-31'` : empeche toute reconnexion
- `DELETE FROM auth.sessions` : deconnecte immediatement
- `UPDATE app.user_device_tokens SET is_active = FALSE` : empeche les notifications push

---

### Bloc 3 — public.app_admin_purge_deleted_accounts() (lignes 181-357)

| Aspect | Detail |
|--------|--------|
| **Objectif** | Purger physiquement et anonymiser les comptes apres 60 jours |
| **Schema** | `public` |
| **Parametres** | Aucun |
| **Retour** | `JSONB` : `{success, purged_count, errors}` |
| **Controles securite** | `deletion_method = 'self_service'` (et non `IS NOT NULL`) — **PROTECTION CRITIQUE** |
| **Tables impactees** | 25+ tables (DELETE ou UPDATE) — voir liste exhaustive dans le script |
| **Dependances** | `pg_cron` (deja installe) |
| **Risques** | Si la condition `deletion_method = 'self_service'` est modifiee, les comptes historiques pourraient etre purges |
| **Rollback** | `DROP FUNCTION IF EXISTS public.app_admin_purge_deleted_accounts();` |

**Points d'attention** :
- `EXCEPTION WHEN OTHERS` : si une iteration echoue, l'erreur est loggee et le cron continue
- `v_errors` : retourne la liste des erreurs pour investigation
- Anonymisation `app.students` : `full_name` devient "Utilisateur supprime", PII effacees
- `auth.users` : email transforme en `deleted_<uuid>@deleted.academia.app`, password vide

---

### Bloc 4 — Correction du cron (lignes 359-372)

```sql
SELECT cron.unschedule('purge_deleted_accounts');
SELECT cron.schedule(
  'purge_deleted_accounts',
  '0 3 * * *',
  $$SELECT public.app_admin_purge_deleted_accounts()$$
);
```

| Aspect | Detail |
|--------|--------|
| **Objectif** | Remplacer la commande du cron existante |
| **Strategie** | `unschedule` + `schedule` (pg_cron ne permet pas de modifier une commande) |
| **Double execution** | Aucun risque — `unschedule` supprime d'abord, `schedule` recree ensuite |
| **Protection purge** | La fonction `public.app_admin_purge_deleted_accounts()` contient `deletion_method = 'self_service'` |
| **Rollback** | `SELECT cron.unschedule('purge_deleted_accounts');` + recreer l'ancien si necessaire |

---

## 3. VALIDATION DES COLONNES

| Colonne | Type | Nullable | DEFAULT | Backfill | Statut |
|---------|------|----------|---------|----------|--------|
| `deletion_requested_at` | `TIMESTAMPTZ` | **OUI** | Aucun | Aucun | ✅ VALIDE |
| `purge_due_at` | `TIMESTAMPTZ` | **OUI** | Aucun | Aucun | ✅ VALIDE |
| `deletion_method` | `TEXT` | **OUI** | Aucun | Aucun | ✅ VALIDE |

**Verification post-migration attendue** :

```sql
SELECT column_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'app'
  AND table_name = 'user_admin_status'
  AND column_name IN ('deletion_requested_at', 'purge_due_at', 'deletion_method');
```

Resultat attendu :

| column_name | is_nullable | column_default |
|-------------|-------------|----------------|
| deletion_requested_at | YES | null |
| purge_due_at | YES | null |
| deletion_method | YES | null |

---

## 4. VALIDATION DES RPC

### 4.1 public.app_student_request_account_deletion()

| Categorie | Detail |
|-----------|--------|
| **Exposition** | `public` => visible comme RPC Supabase pour Flutter |
| **Appel Flutter** | `client.rpc('app_student_request_account_deletion')` |
| **Reponse attendue** | `{success: true, purge_due_at: "2026-08-04T..."}` |
| **Screen impacte** | `student_delete_account_screen.dart` affiche `purge_due_at` |
| **Roles autorises** | student, commercial, merchant (via `raw_user_meta_data->>'role'`) |
| **Auth requis** | Oui (`auth.uid() IS NOT NULL`) |
| **RLS** | Non applicable (SECURITY DEFINER, pas de requetes directes sur tables RLS) |
| **GRANT** | `GRANT EXECUTE ... TO authenticated;` |

### 4.2 public.app_admin_purge_deleted_accounts()

| Categorie | Detail |
|-----------|--------|
| **Exposition** | `public` => peut etre appele manuellement par un admin si necessaire |
| **Appel principal** | Par `pg_cron` quotidiennement a 3h UTC |
| **Retour** | `{success: true, purged_count: N, errors: []}` |
| **Auth requis** | Non (appele par cron, pas par utilisateur) |
| **GRANT** | Aucun GRANT explicite necessaire (cron execute en tant que postgres) |
| **Protection** | `deletion_method = 'self_service'` empeche la purge des comptes historiques |

---

## 5. VALIDATION DU CRON

### 5.1 Etat actuel (confirme par audit)

| Attribut | Valeur |
|----------|--------|
| jobid | 3 |
| jobname | `purge_deleted_accounts` |
| schedule | `0 3 * * *` |
| command | `SELECT app.app_admin_purge_deleted_accounts()` |
| Etat | ECHEC quotidien (function inexistante) |
| Premier echec | 2026-04-24 |

### 5.2 Etat futur (apres correction)

| Attribut | Valeur |
|----------|--------|
| jobid | Nouveau (pg_cron attribue un nouvel ID apres unschedule+schedule) |
| jobname | `purge_deleted_accounts` (meme nom) |
| schedule | `0 3 * * *` (meme horaire) |
| command | `SELECT public.app_admin_purge_deleted_accounts()` |
| Etat | Fonctionnel — purge uniquement les comptes `self_service` elapses |

### 5.3 Strategie de remplacement

```
Etape 1: cron.unschedule('purge_deleted_accounts')
         -> Supprime le job existant (jobid=3)

Etape 2: cron.schedule('purge_deleted_accounts', '0 3 * * *', 'SELECT public.app_admin_purge_deleted_accounts()')
         -> Cree un nouveau job avec la bonne commande
```

### 5.4 Protection contre les purges accidentelles

| Protection | Mecanisme |
|------------|-----------|
| **Comptes historiques** | `deletion_method = NULL` => la clause `= 'self_service'` les exclut |
| **Comptes admin-supprimes** | Seraient `deletion_method = 'admin'` (futur) => excluts |
| **Comptes suspendus non supprimes** | `is_deleted = FALSE` => excluts |
| **Comptes self-service non elapses** | `purge_due_at > NOW()` => excluts |
| **Comptes deja purges** | `deletion_method = 'purged'` => excluts |

---

## 6. PROTOCOLE DE TESTS

### Test 1 — Suppression volontaire utilisateur

**Etapes** :
1. Se connecter avec un compte test etudiant
2. Naviguer vers Parametres > Supprimer mon compte
3. Confirmer le mot de passe
4. Confirmer la suppression finale

**Attendu** :
- Flutter appelle `client.rpc('app_student_request_account_deletion')`
- RPC retourne `{success: true, purge_due_at: ...}`
- Ecran de confirmation affiche la date de purge

**Validation SQL** :
```sql
SELECT is_deleted, deletion_method, purge_due_at
FROM app.user_admin_status
WHERE user_id = '<uuid_test>';
-- Attendu: is_deleted = TRUE, deletion_method = 'self_service', purge_due_at = NOW() + 60j
```

---

### Test 2 — Deconnexion automatique

**Etapes** :
1. Apres Test 1, verifier que l'app redirige vers l'ecran de login
2. Ne pas relancer l'app

**Attendu** :
- L'app est deconnectee immediatement
- `auth.sessions` ne contient plus de ligne pour cet user_id

**Validation SQL** :
```sql
SELECT COUNT(*) FROM auth.sessions WHERE user_id = '<uuid_test>';
-- Attendu: 0
```

---

### Test 3 — Blocage de reconnexion

**Etapes** :
1. Tenter de se reconnecter avec le compte test
2. Saisir les bons identifiants

**Attendu** :
- Supabase retourne une erreur d'authentification
- L'utilisateur ne peut pas se reconnecter

**Validation SQL** :
```sql
SELECT banned_until FROM auth.users WHERE id = '<uuid_test>';
-- Attendu: 2099-12-31 23:59:59+00
```

---

### Test 4 — Affichage de purge_due_at

**Etapes** :
1. Verifier l'ecran de confirmation post-suppression
2. Comparer la date affichee avec `purge_due_at`

**Attendu** :
- Date = NOW() + 60 jours
- Format localise en francais

---

### Test 5 — Comportement des comptes historiques

**Etapes** :
1. Verifier que les 23 comptes historiques restent inchanges
2. S'assurer qu'aucun n'a `deletion_method = 'self_service'`

**Validation SQL** :
```sql
SELECT COUNT(*) FROM app.user_admin_status
WHERE is_deleted = TRUE AND deletion_method IS NOT NULL;
-- Attendu: 0 (immediatement apres migration)
-- Attendu: N (N = nombre de comptes self-service supprimes depuis la correction)
```

---

### Test 6 — Execution controlee du cron

**Etapes** :
1. Apres avoir cree un compte test et demande sa suppression
2. Modifier manuellement `purge_due_at` a une date passee pour simuler l'echeance
3. Executer manuellement `SELECT public.app_admin_purge_deleted_accounts();`

**Attendu** :
- Le compte test est purge
- `purged_count = 1`
- `errors = []`
- Le compte historique (s'il existe encore) n'est PAS affecte

**Validation SQL** :
```sql
SELECT deletion_method FROM app.user_admin_status WHERE user_id = '<uuid_test>';
-- Attendu: 'purged'

SELECT email FROM auth.users WHERE id = '<uuid_test>';
-- Attendu: 'deleted_<uuid>@deleted.academia.app'
```

---

### Test 7 — Anonymisation

**Etapes** :
1. Apres Test 6, verifier la table `app.students`

**Validation SQL** :
```sql
SELECT full_name, phone, email, avatar_url
FROM app.students
WHERE id = '<uuid_test>';
-- Attendu: full_name = 'Utilisateur supprime', phone = NULL, etc.
```

---

### Test 8 — Conformite Google Play

**Criteres** :
- L'utilisateur peut demander la suppression sans contacter le support
- La suppression est effective dans un delai raisonnable (60 jours max)
- Les donnees sont anonymisees avant purge physique
- L'utilisateur est informe de la date de purge

**Verification** :
- Le screen `student_delete_account_screen.dart` affiche la date
- Le RPC retourne `purge_due_at`
- Le cron execute la purge automatiquement

---

## 7. CONTROLE FINAL DE SECURITE

### Question 1 : Un compte historique peut-il etre purge par erreur ?

**Reponse : NON**

Justification :
- Les 23 comptes historiques ont `deletion_method = NULL` (pas de DEFAULT)
- Le cron contient `AND deletion_method = 'self_service'`
- `NULL = 'self_service'` => FALSE
- Les comptes historiques ne seront jamais selectionnes par le cron

---

### Question 2 : Un compte administrativement supprime peut-il etre purge par erreur ?

**Reponse : NON**

Justification :
- Les suppressions administratives futures utiliseraient `deletion_method = 'admin'` (si jamais modifiees)
- Le cron exige `deletion_method = 'self_service'`
- `admin != self_service` => exclu
- De plus, le RPC admin existant (`app_admin_delete_user_account`) ne touche pas a `deletion_method`

---

### Question 3 : Un compte suspendu peut-il etre affecte ?

**Reponse : NON**

Justification :
- Le cron exige `is_deleted = TRUE`
- Un compte simplement suspendu (`is_suspended = TRUE`, `is_deleted = FALSE`) n'est pas elige
- Exemple : le compte `0016169f-...` (is_deleted=FALSE, is_suspended=TRUE) est protege

---

### Question 4 : Les 23 comptes historiques restent-ils intacts ?

**Reponse : OUI**

Justification :
- L'ALTER TABLE avec `IF EXISTS` n'affecte pas les donnees existantes
- Aucun UPDATE/DELETE n'est execute sur ces comptes
- Les colonnes ajoutees sont NULL pour toutes les lignes existantes
- Aucun backfill automatique

---

### Question 5 : Les 11 comptes avec session active sont-ils impactes ?

**Reponse : NON par la migration. OUI comme pre-existant.**

Justification :
- La migration n'ajoute pas de nouvelles sessions, ni n'en supprime
- Ces 11 comptes avaient deja des sessions actives AVANT tout travail
- C'est un probleme pre-existant du RPC `app_admin_delete_user_account` qui ne supprime pas les sessions
- **Recommandation separee** : executer `DELETE FROM auth.sessions WHERE user_id IN (...)` pour les 11 comptes historiques si desire

---

### Question 6 : Existe-t-il un risque de perte de donnees non prevue ?

**Reponse : RISQUE FAIBLE, MITIGE**

Justification :
- Les nouvelles colonnes sont NULL => aucune donnee existante n'est modifiee
- Les nouvelles fonctions ne sont pas encore appellees par le cron (il faut le corriger)
- Le seul risque est une execution manuelle incorrecte du RPC purge
- Mitigation : le RPC purge est appele par cron, pas expose aux utilisateurs

---

### Question 7 : Existe-t-il un risque de regression sur AuthWrapper ?

**Reponse : NON**

Justification :
- `AuthWrapper` n'a pas ete modifie
- `app_check_account_status` (utilise par AuthWrapper) n'a pas ete modifiee
- AuthWrapper continuera de fonctionner comme avant
- Apres suppression par le nouvel RPC, `is_deleted = TRUE` sera lu par AuthWrapper et bloquera l'acces (comportement attendu)

---

### Question 8 : Existe-t-il un risque sur Google Play apres correction ?

**Reponse : NON — AMELIORATION**

Justification :
- Avant correction : la suppression de compte est IMPOSSIBLE pour l'utilisateur (RPC inexistant)
- Google Play pourrait rejeter l'app pour non-conformite
- Apres correction : l'utilisateur peut demander la suppression en self-service
- Le delai de 60 jours est conforme aux exigences
- L'anonymisation avant purge est conforme

---

## 8. PLAN DE ROLLBACK

### 8.1 Rollback immediat (si probleme detecte pendant l'execution)

```sql
-- Annuler la transaction en cours (si execute dans une transaction)
ROLLBACK;
```

### 8.2 Rollback des objets crees

```sql
-- 1. Supprimer le cron
SELECT cron.unschedule('purge_deleted_accounts');

-- 2. Supprimer les fonctions
DROP FUNCTION IF EXISTS public.app_student_request_account_deletion();
DROP FUNCTION IF EXISTS public.app_admin_purge_deleted_accounts();

-- 3. Supprimer les colonnes ajoutees
ALTER TABLE app.user_admin_status
  DROP COLUMN IF EXISTS deletion_requested_at,
  DROP COLUMN IF EXISTS purge_due_at,
  DROP COLUMN IF EXISTS deletion_method;
```

### 8.3 Rollback partiel (si seulement une partie est problematique)

| Scenario | Action |
|----------|--------|
| Le cron purge trop de comptes | `SELECT cron.unschedule('purge_deleted_accounts');` puis investiguer |
| Le RPC etudiant ne fonctionne pas | `DROP FUNCTION public.app_student_request_account_deletion();` — Flutter retournera a l'etat precedent (erreur PGRST202) |
| Les colonnes causent un probleme | `ALTER TABLE ... DROP COLUMN ...` — les donnees historiques ne sont pas touchees |

### 8.4 Donnees non reversibles

| Action | Reversible ? | Commentaire |
|--------|--------------|-------------|
| Suppression de colonnes | OUI | `DROP COLUMN` est reversible si aucune donnee n'a ete inseree |
| Suppression de fonctions | OUI | `DROP FUNCTION` + recreation |
| Suppression du cron | OUI | `unschedule` + `schedule` |
| **Purge d'un compte** | **NON** | Les donnees anonymisees et effacees ne sont pas recuperables |

**Consequence** : Si le cron purge un compte par erreur, les donnees sont definitivement perdues. C'est pourquoi la condition `deletion_method = 'self_service'` est CRITIQUE.

---

## 9. CHECKLIST PRE-EXECUTION

Avant d'executer le script SQL, verifier :

- [ ] Sauvegarde de la base de donnees effectuee
- [ ] Fenetre de maintenance planifiee (si production)
- [ ] Script relu et approuve par un second relecteur
- [ ] Acces Supabase disponible en cas de probleme
- [ ] Plan de rollback imprime/documente
- [ ] Tests planifies dans un environnement de staging

---

**FIN DU DOSSIER — AUCUNE EXECUTION EFFECTUEE**
