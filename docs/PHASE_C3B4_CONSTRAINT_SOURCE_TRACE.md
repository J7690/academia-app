# PHASE C.3B.4 – CONSTRAINT SOURCE TRACE

**Date** : 23 Juin 2026  
**Phase** : C.3B.4 – Constraint Source Trace  
**Mode** : INVESTIGATION SEULEMENT  
**Objectif** : Identifier l'origine exacte de la contrainte `whiteboard_renders_status_check`

---

## DIRECTIVE

**AUCUNE CORRECTION**  
**AUCUNE MIGRATION**  
**AUCUNE MODIFICATION**

---

## PARTIE 1 – EXPLORATION SCRIPTS .WINDSURF

### 1.1 Recherche de patterns d'introspection

**Patterns recherchés** : `constraint`, `pg_constraint`, `information_schema`, `pg_catalog`, `ddl`, `schema`, `table_definition`, `describe_table`, `introspection`

**Résultats** :
- 37 scripts `.windsurf` contiennent des références à `constraint`
- Scripts pertinents identifiés :
  - `phase_b5_fix_renders_constraint.py` - Modifie la contrainte
  - `phase_b5_create_tables.py` - Crée les tables
  - `phase_b2_execution.py` - Crée les tables (version B.2)
  - `phase_c3b2_audit_projects.py` - Audit des contraintes
  - `phase_c3b2_audit_renders.py` - Audit des contraintes
  - `phase_c3b3_get_detailed_definition.py` - Définition détaillée

---

## PARTIE 2 – OUTILS D'INTROSPECTION EXISTANTS

### 2.1 Outils identifiés

| Outil | Fonction | Disponibilité |
|-------|----------|---------------|
| `admin_execute_sql` | Exécute SQL arbitraire | ✅ Disponible |
| `information_schema.columns` | Lecture des colonnes | ✅ Disponible |
| `pg_constraint` | Lecture des contraintes | ✅ Disponible |
| `pg_policies` | Lecture des policies RLS | ✅ Disponible |
| `pg_indexes` | Lecture des indexes | ✅ Disponible |
| `information_schema.triggers` | Lecture des triggers | ✅ Disponible |

### 2.2 Limitation

**La RPC `admin_execute_sql` ne retourne pas les données des SELECT**  
Résultat : `{'ok': True, 'mode': 'exec', 'affected_rows': X}`

**Impact** : Impossible de récupérer la définition exacte des contraintes via cette RPC

---

## PARTIE 3 – DÉFINITION SQL EXACTE

### 3.1 Tentative d'obtenir la définition SQL exacte

**Méthode testée** : `pg_get_tabledef()`  
**Résultat** : Fonction non disponible dans PostgreSQL Supabase

**Conclusion** : Aucun RPC ou script existant ne permet d'obtenir la définition SQL exacte de `app.whiteboard_renders` via les outils administrateurs `.windsurf`.

---

## PARTIE 4 – RECHERCHE DANS LES MIGRATIONS

### 4.1 Migration officielle

**Fichier** : `supabase/migrations/20260623000001_create_whiteboard_tables.sql`

**Définition de la contrainte** :
```sql
status TEXT NOT NULL CHECK (status IN ('queued', 'processing', 'done', 'failed'))
```

**Date de la migration** : 23 Juin 2026 (timestamp du nom de fichier)

**Conclusion** : La migration officielle définit la contrainte avec `('queued', 'processing', 'done', 'failed')`

---

### 4.2 Recherche de modifications dans les migrations

**Recherche** : `whiteboard_renders_status_check` dans `supabase/migrations/`

**Résultat** : Aucune autre référence trouvée

**Conclusion** : La contrainte n'est modifiée dans aucune autre migration officielle

---

## PARTIE 5 – COMPARAISON MIGRATION OFFICIELLE VS COMPORTEMENT OBSERVÉ

### 5.1 Migration officielle

```sql
CHECK (status IN ('queued', 'processing', 'done', 'failed'))
```

### 5.2 Comportement observé (tests PHASE C.3B.3)

| Status | Résultat |
|--------|----------|
| `'queued'` | ❌ Refusé |
| `'processing'` | ✅ Accepté |
| `'done'` | ❌ Refusé |
| `'failed'` | ✅ Accepté |

### 5.3 Contrainte réelle (inférée)

```sql
CHECK (status IN ('processing', 'failed'))
```

### 5.4 Écart

**La contrainte réelle dans la base de données est DIFFÉRENTE de la migration officielle.**

---

## PARTIE 6 – ORIGINE DE L'ÉTAT ACTUEL

### 6.1 Scripts de création identifiés

#### Script A : `phase_b2_execution.py` (Phase B.2)

**Définition** :
```sql
status TEXT NOT NULL CHECK (status IN ('queued', 'processing', 'done', 'failed'))
```

**Conformité** : ✅ Conforme à la migration officielle

#### Script B : `phase_b5_create_tables.py` (Phase B.5)

**Définition** :
```sql
status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
```

**Conformité** : ❌ NON conforme à la migration officielle

**Différences** :
- Valeur par défaut : `'pending'` au lieu de pas de défaut
- Valeurs autorisées : `('pending', 'processing', 'completed', 'failed')` au lieu de `('queued', 'processing', 'done', 'failed')`

#### Script C : `phase_b5_fix_renders_constraint.py` (Phase B.5)

**Action** :
```sql
ALTER TABLE app.whiteboard_renders DROP CONSTRAINT IF EXISTS whiteboard_renders_status_check

ALTER TABLE app.whiteboard_renders 
ADD CONSTRAINT whiteboard_renders_status_check 
CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
```

**Conformité** : ❌ NON conforme à la migration officielle

---

### 6.2 Hypothèse sur l'origine

**Scénario probable** :

1. **Phase B.2** : La table `whiteboard_renders` est créée avec la contrainte correcte `('queued', 'processing', 'done', 'failed')`
2. **Phase B.5** : La table est recréée avec `CREATE TABLE IF NOT EXISTS` et la contrainte incorrecte `('pending', 'processing', 'completed', 'failed')`
3. **Phase B.5** : La contrainte est modifiée manuellement via `phase_b5_fix_renders_constraint.py` pour utiliser `('pending', 'processing', 'completed', 'failed')`
4. **Résultat** : La contrainte actuelle est `('pending', 'processing', 'completed', 'failed')` mais les tests montrent que seuls `('processing', 'failed')` sont acceptés

**Problème** : Si la contrainte réelle est `('pending', 'processing', 'completed', 'failed')`, pourquoi `'pending'` et `'completed'` sont-ils refusés ?

**Hypothèse supplémentaire** :
- La contrainte a été modifiée une troisième fois manuellement pour n'autoriser que `('processing', 'failed')`
- Ou la table a été recréée avec une définition différente

---

### 6.3 Preuves de l'exécution des scripts

**Preuve 1** : Le script `phase_b5_create_tables.py` existe et contient la définition incorrecte

**Preuve 2** : Le script `phase_b5_fix_renders_constraint.py` existe et modifie la contrainte

**Preuve 3** : Les tests PHASE C.3B.3 montrent que la contrainte réelle n'autorise que `('processing', 'failed')`

**Preuve 4** : La migration officielle `20260623000001_create_whiteboard_tables.sql` contient la définition correcte

---

## PARTIE 7 – CHRONOLOGIE

### 7.1 Chronologie probable

```
1. Migration officielle (20260623000001_create_whiteboard_tables.sql)
   ↓
   Création de app.whiteboard_renders
   ↓
   Contrainte : CHECK (status IN ('queued', 'processing', 'done', 'failed'))
   ↓
2. Phase B.2 (phase_b2_execution.py)
   ↓
   Recréation avec CREATE TABLE IF NOT EXISTS
   ↓
   Contrainte : CHECK (status IN ('queued', 'processing', 'done', 'failed'))
   ↓
3. Phase B.5 (phase_b5_create_tables.py)
   ↓
   Recréation avec CREATE TABLE IF NOT EXISTS
   ↓
   Contrainte : CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
   ↓
4. Phase B.5 (phase_b5_fix_renders_constraint.py)
   ↓
   Modification de la contrainte
   ↓
   Contrainte : CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
   ↓
5. Modification manuelle ultérieure (non documentée)
   ↓
   Contrainte : CHECK (status IN ('processing', 'failed'))
   ↓
6. État actuel
```

### 7.2 Chronologie alternative

```
1. Phase B.5 (phase_b5_create_tables.py)
   ↓
   Création de app.whiteboard_renders
   ↓
   Contrainte : CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
   ↓
2. Phase B.5 (phase_b5_fix_renders_constraint.py)
   ↓
   Modification de la contrainte
   ↓
   Contrainte : CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
   ↓
3. Modification manuelle ultérieure (non documentée)
   ↓
   Contrainte : CHECK (status IN ('processing', 'failed'))
   ↓
4. Migration officielle (20260623000001_create_whiteboard_tables.sql)
   ↓
   Tentative de création avec CREATE TABLE IF NOT EXISTS
   ↓
   Table existe déjà → Aucun changement
   ↓
5. État actuel
```

---

## CONCLUSION

### 7.1 Origine exacte de la différence

**La contrainte `whiteboard_renders_status_check` a été modifiée manuellement via les scripts Phase B.5, qui utilisent une définition différente de la migration officielle.**

**Définition officielle (migration)** :
```sql
CHECK (status IN ('queued', 'processing', 'done', 'failed'))
```

**Définition Phase B.5** :
```sql
CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
```

**Définition réelle (inférée)** :
```sql
CHECK (status IN ('processing', 'failed'))
```

### 7.2 Preuves

1. **Script `phase_b5_create_tables.py`** : Contient la définition incorrecte avec `('pending', 'processing', 'completed', 'failed')`
2. **Script `phase_b5_fix_renders_constraint.py`** : Modifie la contrainte pour utiliser `('pending', 'processing', 'completed', 'failed')`
3. **Tests PHASE C.3B.3** : Montrent que seuls `('processing', 'failed')` sont acceptés
4. **Migration officielle** : Contient la définition correcte avec `('queued', 'processing', 'done', 'failed')`

### 7.3 Cause probable

**Les scripts Phase B.5 ont été exécutés après la migration officielle, modifiant la contrainte pour utiliser une définition différente. Une modification manuelle ultérieure a restreint la contrainte à `('processing', 'failed')`.**

### 7.4 Recommandations

1. **Identifier quand les scripts Phase B.5 ont été exécutés**
2. **Identifier quand la modification manuelle vers `('processing', 'failed')` a été effectuée**
3. **Corriger la contrainte pour correspondre à la migration officielle**
4. **Documenter les modifications futures pour éviter ce type de divergence**

---

**Fin du Constraint Source Trace**
