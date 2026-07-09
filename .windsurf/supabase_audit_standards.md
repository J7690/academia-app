# SUPABASE AUDIT STANDARDS

**Date**: 2026-06-25
**Version**: 1.0
**Objectif**: Normaliser les audits Supabase pour éviter les contradictions entre scripts Python et SQL Editor

---

## CONTEXTE

Les audits précédents ont produit des résultats contradictoires :

- **SQL Editor Supabase**: 43 fonctions whiteboard trouvées dans pg_proc
- **Scripts Python**: 0 fonctions trouvées

**Cause identifiée**: `admin_execute_sql` ne retourne pas les données de SELECT, uniquement le statut d'exécution.

**Règle absolue**: À partir de maintenant, pg_proc est la source de vérité absolue.

---

## INTERDICTIONS

- ❌ Ne plus utiliser `information_schema.routines` comme source principale
- ❌ Ne plus conclure qu'un objet n'existe pas sans preuve issue de pg_proc ou pg_class
- ❌ Ne plus lancer de scripts CREATE/DROP avant vérification complète
- ❌ Ne jamais utiliser `supabase_functions.hooks` sans vérifier son existence

---

## RÈGLE 1 – FONCTIONS / RPC

### REQUÊTE OFFICIELLE

```sql
SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n
ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%MOT_CLE%'
ORDER BY
    n.nspname,
    p.proname;
```

### EXEMPLE

```sql
WHERE p.proname ILIKE '%whiteboard%'
```

### INTERDICTION

❌ NE JAMAIS utiliser comme preuve finale :

```sql
SELECT * FROM information_schema.routines
```

### SOURCE DE VÉRITÉ

- **pg_proc** (catalogue système PostgreSQL)
- **pg_namespace** (pour le nom du schéma)

---

## RÈGLE 2 – TABLES

### REQUÊTE OFFICIELLE (Option 1)

```sql
SELECT
    schemaname,
    relname,
    n_live_tup
FROM pg_stat_user_tables
ORDER BY
    schemaname,
    relname;
```

### REQUÊTE OFFICIELLE (Option 2)

```sql
SELECT
    n.nspname,
    c.relname,
    c.relkind
FROM pg_class c
JOIN pg_namespace n
ON n.oid = c.relnamespace
WHERE c.relname ILIKE '%whiteboard%'
ORDER BY
    n.nspname,
    c.relname;
```

### SOURCE DE VÉRITÉ

- **pg_class** (catalogue système PostgreSQL)
- **pg_stat_user_tables** (statistiques des tables utilisateur)

---

## RÈGLE 3 – TRIGGERS

### REQUÊTE OFFICIELLE

```sql
SELECT
    n.nspname,
    c.relname,
    t.tgname
FROM pg_trigger t
JOIN pg_class c
ON c.oid = t.tgrelid
JOIN pg_namespace n
ON n.oid = c.relnamespace
WHERE
    NOT t.tgisinternal
    AND (
        c.relname ILIKE '%whiteboard%'
        OR t.tgname ILIKE '%whiteboard%'
    )
ORDER BY
    n.nspname,
    c.relname;
```

### SOURCE DE VÉRITÉ

- **pg_trigger** (catalogue système PostgreSQL)
- **pg_class** (pour la table associée)
- **pg_namespace** (pour le schéma)

---

## RÈGLE 4 – POLICIES RLS

### REQUÊTE OFFICIELLE

```sql
SELECT
    schemaname,
    tablename,
    policyname
FROM pg_policies
WHERE
    tablename ILIKE '%whiteboard%'
ORDER BY
    schemaname,
    tablename;
```

### SOURCE DE VÉRITÉ

- **pg_policies** (vue système PostgreSQL)

---

## RÈGLE 5 – EDGE FUNCTIONS

### VÉRIFICATION OFFICIELLE

Les Edge Functions ne doivent PAS être interrogées via SQL.

**Méthodes autorisées**:

1. Dashboard Supabase
2. CLI: `supabase functions list`

### INTERDICTION

❌ Ne jamais utiliser `supabase_functions.hooks` sans vérifier son existence.

---

## RÈGLE 6 – CONTRADICTION DES PREUVES

### PROCÉDURE SI CONTRADICTION

**SI**: Script Python ≠ SQL Editor

**ALORS**:

1. **STOP immédiat** - Ne rien modifier
2. Créer `.windsurf/root_cause_contradiction.md`
3. Expliquer:
   - Requête utilisée
   - Utilisateur utilisé
   - Base utilisée
   - Schéma utilisé
   - Différence observée
4. Identifier la cause avant toute action

---

## RÈGLE 7 – AUDITS PYTHON

### OBLIGATIONS

Tous les scripts Python doivent AFFICHER:

```
URL Supabase : ...
Utilisateur : ...
Schéma interrogé : ...
SQL exécuté : ...
Nombre de lignes : ...
Premières lignes : ...
```

### VALIDATION

Sans ces preuves, l'audit est considéré comme **invalide**.

---

## RÈGLE 8 – SOURCE DE VÉRITÉ

### ORDRE OFFICIEL

1. **pg_proc** (fonctions)
2. **pg_class** (tables)
3. **pg_trigger** (triggers)
4. **pg_policies** (RLS)
5. **SQL Editor Supabase**
6. **Scripts Python**

### RÈGLE ABSOLUE

Les scripts Python ne sont JAMAIS la preuve finale.

Ils ne font qu'automatiser des requêtes SQL déjà validées manuellement.

---

## RÈGLE 9 – RPC admin_execute_sql

### LIMITATION CONNUE

`admin_execute_sql` est conçue pour exécuter des commandes DML/DDL (INSERT, UPDATE, DELETE, CREATE, DROP), PAS pour retourner des données de SELECT.

### RETOUR

```json
{
  "ok": true/false,
  "mode": "exec",
  "affected_rows": X
}
```

### INTERDICTION

❌ Ne JAMAIS utiliser `admin_execute_sql` pour des SELECT qui retournent des données.

### ALTERNATIVE

Pour les SELECT, utiliser:
- SQL Editor Supabase (manuel)
- API REST PostgREST (si accessible)
- Créer une RPC wrapper dédiée

---

## CHECKLIST D'AUDIT

Avant de conclure qu'un objet n'existe pas:

- [ ] Requête exécutée sur pg_proc/pg_class
- [ ] Requête exécutée sur SQL Editor Supabase
- [ ] Résultats concordants
- [ ] Utilisateur correct (service_role si nécessaire)
- [ ] Schéma correct (public, app, etc.)
- [ ] Base correcte (pas de base de test)

---

## MIGRATION DES SCRIPTS EXISTANTS

Les scripts d'audit existants doivent être migrés pour respecter ces règles:

- `audit_whiteboard_rpc_inventory.py` → Migrer vers pg_proc
- `verify_whiteboard_deployment.py` → Migrer vers pg_proc/pg_class
- `audit_td_supabase_deep.py` → Migrer vers pg_proc/pg_class
- Tous les autres scripts d'audit → Migrer selon les règles

---

## DOCUMENTATION

Créer pour chaque audit:

- `.windsurf/audit_[NOM]_query_used.md` - Requête SQL exacte utilisée
- `.windsurf/audit_[NOM]_result.md` - Résultat brut
- `.windsurf/audit_[NOM]_analysis.md` - Analyse et conclusion

---

## VALIDATION

Un audit est considéré comme **VALIDÉ** uniquement si:

1. La requête SQL utilise pg_proc/pg_class/pg_trigger/pg_policies
2. Les résultats sont concordants entre SQL Editor et script Python
3. La documentation complète est créée
4. Les contradictions sont résolues avant toute action
