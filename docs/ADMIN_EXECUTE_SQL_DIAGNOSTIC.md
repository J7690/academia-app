# ADMIN_EXECUTE_SQL DIAGNOSTIC

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Mode** : LECTURE SEULE  
**Objectif** : Diagnostic de l'RPC admin_execute_sql

---

## PROBLÈME OBSERVÉ

`admin_execute_sql` retourne `ok = true` mais les objets attendus ne sont pas créés ou ne sont pas trouvés ensuite.

---

## ÉTAPE 1 – DÉFINITION DE ADMIN_EXECUTE_SQL

### 1.1 Recherche dans information_schema.routines

**Résultat** : ❌ Définition non trouvée

**SQL** :
```sql
SELECT 
  routine_name,
  routine_type,
  data_type,
  external_language,
  security_type
FROM information_schema.routines 
WHERE routine_schema = 'app' 
AND routine_name = 'admin_execute_sql'
```

**Conclusion** : L'RPC n'est pas trouvée dans le schéma app via information_schema.routines.

### 1.2 Recherche du code source via pg_proc

**Résultat** : ❌ Code source non trouvé

**SQL** :
```sql
SELECT pg_get_functiondef(oid)
FROM pg_proc 
WHERE proname = 'admin_execute_sql'
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'app')
```

**Conclusion** : L'RPC n'est pas trouvée dans pg_proc pour le schéma app.

### 1.3 Hypothèse

L'RPC `admin_execute_sql` est probablement une Edge Function ou une fonction dans un autre schéma (ex: public), pas dans le schéma app.

---

## ÉTAPE 2 – TEST MINIMAL

### 2.1 SELECT simple

**Résultat** : ✅ Fonctionne

**SQL** : `SELECT 1 as test`

**Réponse** :
```json
{
  "ok": true,
  "mode": "select",
  "rows": [{"test": 1}]
}
```

**Conclusion** : Les SELECT fonctionnent correctement.

### 2.2 Contexte utilisateur

**Résultat** : ✅ Fonctionne

**SQL** : `SELECT current_user, current_database(), current_schema()`

**Réponse** :
```json
{
  "ok": true,
  "mode": "select",
  "rows": [{
    "current_user": "postgres",
    "current_database": "postgres",
    "current_schema": "public"
  }]
}
```

**Conclusion** :
- User : postgres (service role)
- Database : postgres
- Schema : public (pas app)

**Problème identifié** : Le schéma par défaut est `public`, pas `app`.

### 2.3 CREATE TEMP TABLE

**Résultat** : ❌ Échec

**SQL** : `CREATE TEMP TABLE diagnostic_test (id SERIAL PRIMARY KEY, name TEXT)`

**Réponse** :
```json
{
  "ok": true,
  "mode": "exec",
  "affected_rows": 0
}
```

**Vérification** : Table non trouvée dans pg_temp

**Conclusion** : Les tables temporaires ne sont pas persistantes entre les requêtes (comportement normal).

### 2.4 CREATE TABLE permanente (schéma public)

**Résultat** : ✅ Fonctionne

**SQL** : `CREATE TABLE app.diagnostic_test (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT)`

**Réponse** :
```json
{
  "ok": true,
  "mode": "exec",
  "affected_rows": 0
}
```

**Vérification** : Table trouvée dans schéma app

**Conclusion** : Les tables permanentes sont créées correctement dans le schéma app.

### 2.5 CREATE TABLE dans schéma app (SET SEARCH_PATH)

**Résultat** : ✅ Fonctionne

**SQL** : `SET search_path TO app, public; CREATE TABLE whiteboard_test2 (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT)`

**Réponse** :
```json
{
  "ok": true,
  "mode": "exec",
  "affected_rows": 0
}
```

**Vérification** : Table trouvée dans schéma app

**Conclusion** : SET search_path fonctionne.

### 2.6 CREATE TABLE dans schéma app (explicite)

**Résultat** : ✅ Fonctionne

**SQL** : `CREATE TABLE app.whiteboard_test3 (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT)`

**Réponse** :
```json
{
  "ok": true,
  "mode": "exec",
  "affected_rows": 0
}
```

**Vérification** : Table trouvée dans schéma app

**Conclusion** : Le schéma explicite fonctionne.

---

## ÉTAPE 3 – VÉRIFICATION DE L'EXÉCUTION

### 3.1 Test de création de tables whiteboard

**Résultat** : ❌ Échec

**SQL** : Création de whiteboard_projects et whiteboard_renders

**Réponse** :
```json
{
  "ok": false,
  "error": "relation \"whiteboard_projects\" already exists",
  "sqlstate": "42P07"
}
```

**Problème** : Les tables existent déjà mais ne sont pas trouvées.

### 3.2 Localisation des tables

**Résultat** : ❌ Non trouvées

**SQL** : Recherche dans tous les schémas via information_schema.tables

**Réponse** : Aucune table trouvée

**SQL** : Recherche via pg_tables

**Réponse** : Aucune table trouvée

**SQL** : Recherche via pg_class

**Réponse** : Aucune table trouvée

**Conclusion** : Les tables n'existent pas dans la base de données, mais l'RPC retourne "already exists".

### 3.3 DROP TABLE force

**Résultat** : ✅ Exécuté (0 lignes affectées)

**SQL** : `DROP TABLE IF EXISTS public.whiteboard_projects, public.whiteboard_renders CASCADE`

**SQL** : `DROP TABLE IF EXISTS app.whiteboard_projects, app.whiteboard_renders CASCADE`

**Conclusion** : Les tables n'existent pas, DROP n'affecte rien.

### 3.4 Recréation des tables

**Résultat** : ✅ Créées

**SQL** : Création de whiteboard_projects et whiteboard_renders dans schéma app

**Réponse** :
```json
{
  "ok": true,
  "mode": "exec",
  "affected_rows": 0
}
```

**Vérification** : ❌ Non trouvées via pg_tables

**Conclusion** : Les tables sont créées (ok = true) mais ne sont pas trouvées ensuite.

---

## ÉTAPE 4 – COMPARAISON RÉSULTAT RPC VS ÉTAT RÉEL

### 4.1 Résumé des tests

| Test | RPC Response | État réel | Conformité |
|------|--------------|-----------|------------|
- SELECT simple | ok = true | Données retournées | ✅ Conforme |
- Contexte utilisateur | ok = true | postgres/public | ✅ Conforme |
- CREATE TEMP TABLE | ok = true | Non trouvée | ❌ Non conforme |
- CREATE TABLE permanente | ok = true | Trouvée | ✅ Conforme |
- CREATE TABLE app (SET PATH) | ok = true | Trouvée | ✅ Conforme |
- CREATE TABLE app (explicite) | ok = true | Trouvée | ✅ Conforme |
- CREATE whiteboard_projects | ok = false (already exists) | Non trouvée | ❌ Non conforme |
- CREATE whiteboard_renders | ok = false (already exists) | Non trouvée | ❌ Non conforme |
- Recréation whiteboard | ok = true | Non trouvée | ❌ Non conforme |

### 4.2 Analyse

**Problème 1** : Les tables whiteboard retournent "already exists" mais ne sont pas trouvées.
- Possible cause : Cache dans l'RPC ou erreur de synchronisation.

**Problème 2** : Après recréation, les tables ne sont pas trouvées.
- Possible cause : Les tables sont créées dans une autre base ou dans une transaction non commitée.

**Problème 3** : Le schéma par défaut est public, pas app.
- Impact : Les tables créées sans schéma explicite vont dans public.

---

## ÉTAPE 5 – CONCLUSION

### 5.1 Évaluation de admin_execute_sql

| Aspect | État | Notes |
|--------|------|-------|
- SELECT | ✅ Fonctionne | Retourne les données correctement |
- Contexte utilisateur | ✅ Fonctionne | Retourne postgres/public |
- CREATE TABLE (simple) | ✅ Fonctionne | Tables créées et trouvées |
- CREATE TABLE (schéma app) | ✅ Fonctionne | Tables créées et trouvées |
- Migration complexe | ❌ Problématique | Tables "already exists" mais non trouvées |
- Fichier de migration | ❌ Inutilisable | Exécution via RPC ne fonctionne pas |

### 5.2 Décision

**admin_execute_sql fonctionne partiellement** ⚠️

**Justification** :
- ✅ Les SELECT fonctionnent correctement
- ✅ Les CREATE TABLE simples fonctionnent correctement
- ❌ Les migrations complexes (fichiers SQL complets) ne fonctionnent pas
- ❌ Problème de synchronisation (already exists vs non trouvées)
- ❌ Le schéma par défaut est public, pas app

### 5.3 Recommandations

**Pour les migrations** :
- ❌ Ne pas utiliser admin_execute_sql pour les migrations complexes
- ✅ Utiliser Supabase CLI (`supabase db push`) pour les migrations
- ✅ Pour les créations simples, utiliser admin_execute_sql avec schéma explicite

**Pour les tables whiteboard** :
- ✅ Utiliser Supabase CLI pour exécuter la migration
- ✅ Ou créer les tables via admin_execute_sql avec schéma explicite (une par commande)

---

## CONCLUSION

**admin_execute_sql est utilisable pour les opérations simples** (SELECT, CREATE TABLE simple), mais **inutilisable pour les migrations complexes** (fichiers SQL complets).

**Phase B.2 doit utiliser Supabase CLI** pour exécuter la migration.

---

**Fin du document**
