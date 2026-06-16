# RAPPORT D'AUDIT DE SECURITE FINAL — SUPPRESSION DE COMPTE ACADEMIA

**Statut** : Audit securite pre-execution (aucune modification effectuee)
**Date** : 2026-06-04
**Objectif** : Valider qu'aucun compte existant ne risque d'etre purge par erreur lors de l'activation du systeme de suppression de compte.

---

## 1. COMPTAGES PRECISES

| Metrique | Valeur | Commentaire |
|----------|--------|-------------|
| Total lignes `app.user_admin_status` | **25** | Population totale suivie |
| `is_deleted = TRUE` | **23** (92%) | Quasi-totalite des comptes sont marques supprimes |
| `is_suspended = TRUE` | **24** (96%) | Presque tous sont aussi suspendus |
| `deleted_at IS NOT NULL` | **23** | Coherence parfaite avec `is_deleted = TRUE` |
| `deleted_at NOT NULL mais is_deleted = FALSE` | **0** | Aucune incoherence detectee |
| `is_deleted = TRUE mais deleted_at IS NULL` | **0** | Aucune incoherence detectee |

**Distribution is_deleted / is_suspended :**

| is_deleted | is_suspended | Count |
|------------|--------------|-------|
| FALSE | FALSE | 1 |
| FALSE | TRUE | 1 |
| TRUE | TRUE | **23** |

**Comptes non supprimes (2 seulement) :**

| user_id | is_deleted | is_suspended | updated_at |
|---------|-----------|--------------|------------|
| 0016169f-... | FALSE | TRUE | 2026-04-13 |
| 33fc5aa5-... | FALSE | FALSE | 2026-01-20 |

---

## 2. ORIGINE DES COMPTES SUPPRIMES

### 2.1 Caracteristiques des 23 comptes supprimes

| user_id | deleted_at | suspended_at | deleted_reason | suspended_reason |
|---------|-----------|-------------|----------------|-----------------|
| fac01c01-... | 2026-02-18 13:37 | 2026-02-18 13:37 | `hard_delete` | `hard_delete` |
| 74493dee-... | 2026-02-16 05:24 | 2026-02-16 05:24 | `NULL` | `account_deleted` |
| 03de29af-... | 2026-02-16 04:54 | 2026-02-16 04:54 | `NULL` | `account_deleted` |
| 3e99289f-... | 2026-02-16 04:54 | 2026-02-16 04:54 | `NULL` | `account_deleted` |
| aa507d72-... | 2026-02-16 04:54 | 2026-02-16 04:54 | `NULL` | `account_deleted` |
| 9ebd556c-... | 2026-02-16 04:54 | 2026-02-16 04:54 | `NULL` | `account_deleted` |
| 96f0c40c-... | 2026-02-16 04:53 | 2026-02-16 04:53 | `NULL` | `account_deleted` |
| 1953c04f-... | 2026-01-28 11:08 | 2026-01-28 11:08 | `NULL` | `account_deleted` |
| ecfbc99d-... | 2026-01-28 11:08 | 2026-01-28 11:08 | `NULL` | `account_deleted` |
| cf77200c-... | 2026-01-20 13:28 | 2026-01-20 13:28 | `NULL` | `account_deleted` |
| 12501d2b-... | 2026-01-20 13:27 | 2026-01-20 13:27 | `NULL` | `account_deleted` |
| c2573724-... | 2026-01-20 13:27 | 2026-01-20 13:27 | `NULL` | `account_deleted` |
| 533fc50f-... | 2026-01-20 12:44 | 2026-01-20 12:44 | `NULL` | `account_deleted` |
| 07cd4119-... | 2026-01-19 13:39 | 2026-01-19 13:39 | `NULL` | `account_deleted` |
| a6151d26-... | 2026-01-19 13:38 | 2026-01-19 13:38 | `NULL` | `account_deleted` |
| 084073ad-... | 2026-01-19 13:38 | 2026-01-19 13:38 | `NULL` | `account_deleted` |
| 2b5093a8-... | 2026-01-19 13:38 | 2026-01-19 13:38 | `NULL` | `account_deleted` |
| 933e3820-... | 2026-01-19 13:38 | 2026-01-19 13:38 | `NULL` | `account_deleted` |
| 9fa7c5b9-... | 2026-01-10 06:17 | 2026-01-10 06:17 | `NULL` | `account_deleted` |
| 8228063d-... | 2026-01-10 06:16 | 2026-01-10 06:16 | `NULL` | `account_deleted` |
| eb5fab3e-... | 2026-01-10 06:16 | 2026-01-02 08:33 | `NULL` | `account_deleted` |
| e9896517-... | 2026-01-10 06:16 | 2026-01-02 08:33 | `NULL` | `account_deleted` |
| 296591ce-... | 2026-01-10 06:15 | 2026-01-02 08:33 | `NULL` | `account_deleted` |

### 2.2 Analyse chronologique

**Cluster 1 — 2026-01-02 puis 2026-01-10 (3 comptes)**
- `suspended_at` = 2026-01-02
- `deleted_at` = 2026-01-10
- Pattern : suspension prealable, suppression ulterieure

**Cluster 2 — 2026-01-10 (3 comptes)**
- `deleted_at` = `suspended_at` = 2026-01-10
- Suppression immediate

**Cluster 3 — 2026-01-19 (5 comptes)**
- `deleted_at` = `suspended_at` = 2026-01-19
- Batch de 5 suppressions simultanees

**Cluster 4 — 2026-01-20 (5 comptes)**
- `deleted_at` = `suspended_at` = 2026-01-20
- Batch de 5 suppressions simultanees

**Cluster 5 — 2026-01-28 (2 comptes)**
- `deleted_at` = `suspended_at` = 2026-01-28

**Cluster 6 — 2026-02-16 (6 comptes)**
- `deleted_at` = `suspended_at` = 2026-02-16
- Batch de 6 suppressions simultanees

**Cluster 7 — 2026-02-18 (1 compte)**
- `deleted_at` = `suspended_at` = 2026-02-18
- `deleted_reason = 'hard_delete'` (unique cas avec reason non-NULL)

### 2.3 Classification par origine

| user_id | Classification | Justification |
|---------|---------------|---------------|
| fac01c01-... | **Suppression administrative** | `deleted_reason = 'hard_delete'` — terme utilise par les administrateurs |
| 22 comptes avec `deleted_reason = NULL` | **Suppression administrative** | `suspended_reason = 'account_deleted'` correspond au DEFAULT de `app_admin_delete_user_account` (`COALESCE(p_reason, 'account_deleted')`). Le `deleted_reason = NULL` correspond a `p_reason = NULL` lors de l'appel admin. |

**Conclusion** : Les 23 comptes sont **tous** issus de suppressions administratives (`public.app_admin_delete_user_account`). **Aucun** n'est issu d'une suppression volontaire utilisateur (il n'y a jamais eu de RPC `app_student_request_account_deletion` fonctionnel).

### 2.4 Nature des comptes

| Type | Comptage | Justification |
|------|----------|---------------|
| Comptes de production reels | Inconnu | Impossible de determiner sans acces a `auth.users.email` ou `students.full_name` |
| Comptes de test | Probablement la majorite | Volume eleve (23 comptes), dates groupes, suppression admin systematique |
| Comptes utilisateurs legitimes | Probablement 0-2 | L'application n'a pas encore de base utilisateurs significative en production |

---

## 3. ETAT DES SESSIONS (ANOMALIE DETECTEE)

**Resultat** : 11 des 23 comptes supprimes possedent encore des sessions actives dans `auth.sessions`.

| user_id (supprime) | Sessions actives |
|-------------------|-----------------|
| (11 comptes) | >= 1 session chacun |

**Impact actuel** : Ces comptes pourraient theoriquement encore acceder a l'application si leurs tokens n'ont pas expire. L'admin RPC `app_admin_delete_user_account` ne supprime pas les sessions (contrairement au futur RPC etudiant).

---

## 4. LOGIQUE FUTURE DU CRON — DISTINCTION DES METHODES

### 4.1 Valeurs attendues de `deletion_method`

| Valeur | Signification | Source |
|--------|---------------|--------|
| `'self_service'` | Suppression demandee par l'utilisateur lui-meme | RPC `app_student_request_account_deletion` |
| `'admin'` | Suppression effectuee par un administrateur | Hypothetique — aucun RPC actuel ne l'ecrit |
| `'purged'` | Etat final apres execution du cron | RPC `app_admin_purge_deleted_accounts` |
| `NULL` | Aucune suppression en cours | Etat initial / compte actif |

### 4.2 Clause WHERE du cron purge

```sql
SELECT user_id, purge_due_at
FROM app.user_admin_status
WHERE is_deleted = TRUE
  AND purge_due_at IS NOT NULL
  AND purge_due_at <= NOW()
  AND deletion_method IS NOT NULL
```

**Analyse des conditions :**

| Condition | Protection actuelle | Apres migration |
|-----------|---------------------|-----------------|
| `is_deleted = TRUE` | Les 23 comptes repondent | Les 23 comptes repondent |
| `purge_due_at IS NOT NULL` | **NULL pour tous** (colonne inexistante) | Sera NULL pour les 23 comptes existants (DEFAULT n'affecte que `deletion_method`) |
| `purge_due_at <= NOW()` | FALSE pour tous (NULL) | FALSE pour les 23 comptes existants |
| `deletion_method IS NOT NULL` | **NULL pour tous** (colonne inexistante) | Sera `'self_service'` pour tous via DEFAULT |

**Point critique** : La condition `purge_due_at IS NOT NULL` est le **seul rempart** empechant la purge immediate des 23 comptes existants.

---

## 5. SIMULATION LOGIQUE — IMPACT DE `DEFAULT 'self_service'`

### 5.1 Etat avant migration

| user_id | is_deleted | deleted_at | deletion_method | purge_due_at |
|---------|-----------|-----------|-----------------|--------------|
| 23 comptes | TRUE | date | **NULL** | **NULL** |
| 2 comptes | FALSE | NULL | **NULL** | **NULL** |

### 5.2 Apres ALTER TABLE avec `DEFAULT 'self_service'`

| user_id | is_deleted | deleted_at | deletion_method | purge_due_at |
|---------|-----------|-----------|-----------------|--------------|
| 23 comptes | TRUE | date | **'self_service'** | **NULL** |
| 2 comptes | FALSE | NULL | **'self_service'** | **NULL** |

### 5.3 Evaluation du cron sur cet etat

```
is_deleted = TRUE         → 23 comptes ✓
purge_due_at IS NOT NULL  → 0 comptes  ✗ (tous NULL)
purge_due_at <= NOW()     → 0 comptes  ✗ (NULL <= NOW() = NULL = FALSE)
deletion_method IS NOT NULL → 23 comptes ✓
```

**Resultat de la simulation** : **AUCUN** des 23 comptes serait selectionne par le cron immediatement apres l'ALTER TABLE.

### 5.4 Risques residuels

| Scenario | Probabilite | Impact |
|----------|-------------|--------|
| Un backfill ou script met `purge_due_at = NOW()` sur les 23 comptes existants | Moyenne (erreur humaine) | **CRITIQUE** — les 23 comptes seraient immediatement eligibles a la purge |
| Modification future du cron supprimant `purge_due_at IS NOT NULL` | Faible | **CRITIQUE** — les 23 comptes seraient immediatement eligibles |
| Un admin appelle manuellement le RPC purge sans verifier les criteres | Faible | **CRITIQUE** — purge immediate |

---

## 6. RISQUES DE PURGE INVOLONTAIRE

### 6.1 Risque immediat (apres migration sans backfill)

| Risque | Niveau | Description |
|--------|--------|-------------|
| R1 | **FAIBLE** | Les 23 comptes existants ne seront PAS purges car `purge_due_at = NULL`. La condition `IS NOT NULL` du cron les protege. |

### 6.2 Risque differre (apres backfill non controle)

| Risque | Niveau | Description |
|--------|--------|-------------|
| R2 | **CRITIQUE** | Si un backfill set `purge_due_at = NOW()` sur les comptes existants sans distinguer leur origine, 23 comptes seraient purges immediatement. |
| R3 | **CRITIQUE** | Si un script confond `deletion_method = 'self_service'` avec `origine = utilisateur`, il pourrait traiter des suppressions admin comme des suppressions volontaires. |

### 6.3 Risque de confusion categorielle

| Risque | Niveau | Description |
|--------|--------|-------------|
| R4 | **MOYEN** | Avec `DEFAULT 'self_service'`, les 23 suppressions administratives seraient historiquement etiquetees `'self_service'`. Cela fausserait les statistiques et l'audit. |

---

## 7. STRATEGIE DE MIGRATION RECOMMANDEE

### 7.1 Option A : Colonne nullable sans DEFAULT (RECOMMANDEE)

```sql
ALTER TABLE app.user_admin_status
  ADD COLUMN IF NOT EXISTS deletion_method TEXT;
```

**Avantages :**
- Toutes les lignes existantes conservent `NULL`
- Les 23 comptes supprimes admin restent avec `deletion_method = NULL`
- Le cron (`deletion_method IS NOT NULL`) les ignore naturellement
- Pas de fausse categorisation historique

**Inconvenient :**
- Le RPC `app_student_request_account_deletion` doit explicitement ecrire `'self_service'`
- Le RPC `app_admin_purge_deleted_accounts` doit explicitement ecrire `'purged'`

**Verdict** : **RECOMMANDEE** — la securite prime sur la commodite.

### 7.2 Option B : DEFAULT 'self_service' avec backfill controle

```sql
-- Etape 1 : Ajout avec DEFAULT
ALTER TABLE app.user_admin_status ADD COLUMN IF NOT EXISTS deletion_method TEXT DEFAULT 'self_service';

-- Etape 2 : Backfill immédiat et controle des comptes deja supprimes
UPDATE app.user_admin_status
SET deletion_method = 'admin'
WHERE is_deleted = TRUE AND deleted_at IS NOT NULL;

-- Etape 3 : Supprimer le DEFAULT pour eviter les confusions futures
ALTER TABLE app.user_admin_status ALTER COLUMN deletion_method DROP DEFAULT;
```

**Avantages :**
- Les nouveaux comptes qui demandent la suppression pourront avoir `'self_service'` par defaut
- L'historique est preserve avec `'admin'`

**Inconvenients :**
- Necessite un backfill immediat — risque d'erreur
- Si le backfill est oublie, les 23 comptes restent `'self_service'`

**Verdict** : Acceptable mais moins sur que Option A.

### 7.3 Option C : Valeur speciale pour historique

```sql
ALTER TABLE app.user_admin_status ADD COLUMN IF NOT EXISTS deletion_method TEXT DEFAULT 'legacy_admin';
```

**Avantages :**
- Distingue clairement les suppressions historiques des nouvelles

**Inconvenients :**
- Introduit une valeur inattendue dans le systeme
- Necessite de documenter cette valeur speciale

**Verdict** : Pas necessaire — Option A suffit.

### 7.4 Decision recommandee

| Aspect | Recommandation |
|--------|---------------|
| `deletion_method` | **Nullable sans DEFAULT** (`TEXT` sans `DEFAULT`) |
| `deletion_requested_at` | **Nullable sans DEFAULT** (`TIMESTAMPTZ`) |
| `purge_due_at` | **Nullable sans DEFAULT** (`TIMESTAMPTZ`) |
| Backfill | **Aucun** — laisser les valeurs historiques a `NULL` |
| RPC etudiant | Ecrire explicitement `'self_service'` lors de l'insertion |
| RPC admin existant | Ne pas modifier — ses suppressions resteront avec `deletion_method = NULL` |
| Cron | La condition `deletion_method IS NOT NULL` protege les comptes historiques |

---

## 8. CONCLUSION

### 8.1 Decouverte majeure

**92% des comptes (23 sur 25) dans `app.user_admin_status` sont deja marques comme supprimes.** Tous sont issus de suppressions administratives via `public.app_admin_delete_user_account`. Aucun n'est issu d'une suppression volontaire utilisateur.

### 8.2 Analyse de risque

| Risque | Probabilite | Impact | Mitigation |
|--------|-------------|--------|------------|
| Purge involontaire des 23 comptes | **Faible** (requisit : `purge_due_at` NULL -> non-NULL) | **Critique** | Garder `purge_due_at = NULL` pour les comptes historiques. Ne JAMAIS backfill `purge_due_at` sans audit prealable. |
| Fausses statistiques | **Elevee** (si DEFAULT applique) | **Faible** | Ne pas utiliser DEFAULT. Laisser `NULL` pour l'historique. |
| Sessions actives sur comptes supprimes | **Confirmee** (11 comptes) | **Moyen** | Pre-existant a la migration. Ne pas resoudre dans ce scope. |

### 8.3 Pre-requis avant migration

1. **Compter les comptes `is_deleted = TRUE`** — Fait (23 comptes)
2. **Ne PAS appliquer de DEFAULT sur `deletion_method`** — La colonne doit etre nullable
3. **Ne PAS backfill `purge_due_at`** — Garder `NULL` pour tous les comptes historiques
4. **Documenter que `deletion_method = NULL` signifie "historique pre-systeme"** pour les equipes futures

### 8.4 Validation finale

**Le risque de purge involontaire est FAIBLE si et seulement si :**
- `purge_due_at` reste `NULL` pour les 23 comptes historiques
- `deletion_method` reste `NULL` pour les 23 comptes historiques (pas de DEFAULT)
- Le cron conserve sa clause `purge_due_at IS NOT NULL`

**Si l'une de ces conditions est violee, le risque devient CRITIQUE.**

---

**Aucune modification effectuee. Aucun SQL execute. Ce rapport est pret pour decision finale.**
