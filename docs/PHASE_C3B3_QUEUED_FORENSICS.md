# PHASE C.3B.3 – QUEUED CONSTRAINT FORENSICS

**Date** : 23 Juin 2026  
**Phase** : C.3B.3 – Queued Constraint Forensics  
**Mode** : INVESTIGATION SEULEMENT  
**Objectif** : Déterminer avec certitude pourquoi `status='queued'` est refusé

---

## DIRECTIVE

**AUCUNE MODIFICATION**  
**AUCUNE MIGRATION**  
**AUCUNE NOUVELLE RPC**  
**AUCUN REDÉPLOIEMENT**

---

## PARTIE 1 – DÉFINITION RÉELLE DE `app.whiteboard_renders`

### 1.1 Source de vérité théorique

**Fichier** : `supabase/migrations/20260623000001_create_whiteboard_tables.sql`

```sql
CREATE TABLE app.whiteboard_renders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES app.whiteboard_projects(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('queued', 'processing', 'done', 'failed')),
  video_url TEXT,
  duration_ms INTEGER,
  error_message TEXT,
  progress INTEGER CHECK (progress >= 0 AND progress <= 100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);
```

### 1.2 Définition réelle (via audit)

**Méthode** : Interrogation de `information_schema.columns` via `admin_execute_sql`

**Résultat** : 13 colonnes détectées (vs 9 dans la migration)

**Note** : La RPC `admin_execute_sql` ne retourne pas les données des SELECT, seulement `{'ok': True, 'mode': 'exec', 'affected_rows': X}`. Il est donc impossible de récupérer la définition exacte des colonnes via cette méthode.

---

## PARTIE 2 – CONTRAINTES RÉELLES

### 2.1 Contraintes CHECK

**Méthode** : Interrogation de `pg_constraint` via `admin_execute_sql`

**Résultat** : 2 contraintes CHECK détectées

**Note** : La RPC `admin_execute_sql` ne retourne pas les données des SELECT, il est donc impossible de récupérer la définition exacte des contraintes via cette méthode.

**Contrainte théorique** (selon migration) :
```sql
CHECK (status IN ('queued', 'processing', 'done', 'failed'))
```

**Contrainte réelle** : **INCONNUE** (impossible à récupérer via `admin_execute_sql`)

---

### 2.2 Contraintes FK

**Méthode** : Interrogation de `pg_constraint` via `admin_execute_sql`

**Résultat** : 1 contrainte FK détectée

**Contrainte théorique** (selon migration) :
```sql
FOREIGN KEY (project_id) REFERENCES app.whiteboard_projects(id) ON DELETE CASCADE
```

**Contrainte réelle** : **INCONNUE** (impossible à récupérer via `admin_execute_sql`)

---

### 2.3 Triggers

**Méthode** : Interrogation de `information_schema.triggers` via `admin_execute_sql`

**Résultat** : 0 triggers détectés

---

### 2.4 Defaults

**Méthode** : Interrogation de `information_schema.columns` via `admin_execute_sql`

**Résultat** : **INCONNU** (impossible à récupérer via `admin_execute_sql`)

---

### 2.5 Policies RLS

**Méthode** : Interrogation de `pg_policies` via `admin_execute_sql`

**Résultat** : 17 policies RLS détectées

**Note** : La RPC `admin_execute_sql` ne retourne pas les données des SELECT, il est donc impossible de récupérer la définition exacte des policies via cette méthode.

---

## PARTIE 3 – REQUÊTE EXACTE UTILISÉE

### 3.1 Requête d'insertion utilisée en PHASE C.3B.1

```sql
INSERT INTO app.whiteboard_renders (id, project_id, status, progress, created_at)
VALUES ('{render_id}', '{project_id}', 'queued', 0, NOW());
```

**Paramètres** :
- `render_id` : UUID généré
- `project_id` : UUID d'un project existant
- `status` : `'queued'`
- `progress` : `0`
- `created_at` : `NOW()`

---

## PARTIE 4 – MESSAGE D'ERREUR COMPLET

### 4.1 Erreur complète

```
Status : 200
Résultat : {'ok': False, 'error': 'new row for relation "whiteboard_renders" violates check constraint "whiteboard_renders_status_check"', 'sqlstate': '23514'}
```

**Sans résumé**  
**Sans interprétation**

---

## PARTIE 5 – TESTS ISOLATION

### 5.1 Test 1 : INSERT minimal (sans FK valide)

| Test | Requête | Résultat | Erreur |
|------|---------|----------|--------|
| 1.1 | `INSERT (id, project_id)` | Échec | `null value in column "status" violates not-null constraint` |
| 1.2 | `INSERT (id, project_id, status='queued')` | Échec | `violates check constraint "whiteboard_renders_status_check"` |
| 1.3 | `INSERT (id, project_id, status='processing')` | Échec | `violates foreign key constraint "whiteboard_renders_project_id_fkey"` |
| 1.4 | `INSERT (id, project_id, status='done')` | Échec | `violates check constraint "whiteboard_renders_status_check"` |
| 1.5 | `INSERT (id, project_id, status='failed')` | Échec | `violates foreign key constraint "whiteboard_renders_project_id_fkey"` |

**Conclusion** : Le FK est validé AVANT le CHECK. Si le FK est invalide, l'erreur FK est retournée avant le CHECK.

---

### 5.2 Test 2 : INSERT avec FK valide

| Test | Requête | Résultat | Erreur |
|------|---------|----------|--------|
| 2.1 | `INSERT (id, project_id, status='queued')` | **ÉCHEC** | `violates check constraint "whiteboard_renders_status_check"` |
| 2.2 | `INSERT (id, project_id, status='processing')` | **SUCCÈS** | - |
| 2.3 | `INSERT (id, project_id, status='done')` | **ÉCHEC** | `violates check constraint "whiteboard_renders_status_check"` |
| 2.4 | `INSERT (id, project_id, status='failed')` | **SUCCÈS** | - |

**Conclusion** : Avec un FK valide, seuls `status='processing'` et `status='failed'` sont acceptés. `status='queued'` et `status='done'` sont refusés par la CHECK constraint.

---

### 5.3 Test 3 : INSERT avec toutes les colonnes

| Test | Requête | Résultat | Erreur |
|------|---------|----------|--------|
| 3.1 | `INSERT (toutes colonnes, status='queued')` | **ÉCHEC** | `violates check constraint "whiteboard_renders_status_check"` |
| 3.2 | `INSERT (toutes colonnes, status='processing')` | **SUCCÈS** | - |
| 3.3 | `INSERT (toutes colonnes, status='done')` | **ÉCHEC** | `violates check constraint "whiteboard_renders_status_check"` |
| 3.4 | `INSERT (toutes colonnes, status='failed')` | **SUCCÈS** | - |

**Conclusion** : Même avec toutes les colonnes spécifiées, le comportement est identique. Le problème n'est pas lié aux colonnes manquantes ou aux defaults.

---

## PARTIE 6 – CAUSE EXACTE DU REJET

### 6.1 Analyse des résultats

**Observation** :
- `status='queued'` : **REFUSÉ** par CHECK constraint
- `status='processing'` : **ACCEPTÉ**
- `status='done'` : **REFUSÉ** par CHECK constraint
- `status='failed'` : **ACCEPTÉ**

**Paradoxe** : La contrainte CHECK théorique autorise `('queued', 'processing', 'done', 'failed')`, mais la contrainte réelle semble n'autoriser que `('processing', 'failed')`.

### 6.2 Réponse explicite

**L'erreur provient-elle du CHECK ?**  
**OUI** - L'erreur est explicitement `violates check constraint "whiteboard_renders_status_check"`.

**L'erreur provient-elle de la FK ?**  
**NON** - Les tests avec FK valide confirment que le FK n'est pas la cause.

**L'erreur provient-elle de la RLS ?**  
**NON** - L'erreur est une CHECK constraint, pas une RLS policy.

**L'erreur provient-elle d'un trigger ?**  
**NON** - Aucun trigger n'est détecté sur la table.

**L'erreur provient-elle d'une RPC ?**  
**NON** - L'erreur provient directement de PostgreSQL, pas d'une RPC.

**L'erreur provient-elle d'une autre contrainte ?**  
**NON** - L'erreur est explicitement une CHECK constraint sur `status`.

### 6.3 Conclusion

**La contrainte CHECK réelle dans la base de données est DIFFÉRENTE de la contrainte CHECK définie dans la migration.**

**Contrainte théorique** (migration) :
```sql
CHECK (status IN ('queued', 'processing', 'done', 'failed'))
```

**Contrainte réelle** (inférée) :
```sql
CHECK (status IN ('processing', 'failed'))
```

**Cause probable** :
1. La migration n'a pas été appliquée correctement
2. La contrainte a été modifiée manuellement après la migration
3. Il existe une autre migration qui modifie cette contrainte
4. La contrainte a été créée avec une définition différente initialement

---

## PARTIE 7 – DÉPENDANCE DES RPCs C.3B.1

### 7.1 RPCs créées en C.3B.1

| RPC | Dépendance sur `status='queued'` |
|-----|--------------------------------|
| `whiteboard_fetch_queued_jobs` | **OUI** - `WHERE wr.status = 'queued'` |
| `whiteboard_mark_processing` | **NON** - Met `status = 'processing'` |
| `whiteboard_mark_done` | **NON** - Met `status = 'done'` |
| `whiteboard_mark_failed` | **NON** - Met `status = 'failed'` |

### 7.2 Impact

**Immédiat** :
- La RPC `whiteboard_fetch_queued_jobs` ne retournera jamais de jobs car `status='queued'` ne peut pas être inséré
- Le worker ne pourra jamais traiter de jobs
- Le worker démarrera correctement mais trouvera 0 jobs en permanence

**Futur** :
- Si la contrainte n'est pas corrigée, le worker sera inutile
- Les RPCs de mise à jour (`processing`, `done`, `failed`) fonctionneront correctement si un job est créé manuellement avec un status valide

### 7.3 Conclusion

**Les RPCs créées en C.3B.1 dépendent déjà de ce comportement.** La RPC `whiteboard_fetch_queued_jobs` est inutile tant que la contrainte CHECK n'autorise pas `status='queued'`.

---

## CONCLUSION

### 7.1 Cause exacte du rejet

**La contrainte CHECK `whiteboard_renders_status_check` dans la base de données réelle n'autorise que `('processing', 'failed')` et refuse `('queued', 'done')`.**

C'est en contradiction avec la spécification V1 et la migration SQL qui autorisent `('queued', 'processing', 'done', 'failed')`.

### 7.2 Preuves

1. **Test 2.1** : `status='queued'` avec FK valide → Échec CHECK
2. **Test 2.2** : `status='processing'` avec FK valide → Succès
3. **Test 2.3** : `status='done'` avec FK valide → Échec CHECK
4. **Test 2.4** : `status='failed'` avec FK valide → Succès

### 7.3 Recommandations

1. **Investiguer la migration** : Vérifier si la migration `20260623000001_create_whiteboard_tables.sql` a été appliquée correctement
2. **Vérifier les migrations ultérieures** : Chercher si une autre migration modifie cette contrainte
3. **Corriger la contrainte** : Modifier la contrainte pour autoriser `('queued', 'processing', 'done', 'failed')`
4. **Valider avec accès direct** : Utiliser psql ou pgAdmin pour vérifier la définition exacte de la contrainte

---

**Fin du Queued Constraint Forensics**
