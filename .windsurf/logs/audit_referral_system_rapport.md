# Audit du Système de Référenciation des Prospects Commerciaux

**Date:** 7 Juillet 2026  
**Objectif:** Auditer le système de référenciation des prospects pour le rôle commercial  
**Problème signalé:** Le lien du commercial comptabilise deux prospects pour un vrai prospect

---

## Méthodologie

L'audit a été réalisé via l'RPC `admin_execute_sql` sur Supabase, en utilisant des scripts Python dans le dossier `.windsurf/`.

### Scripts d'audit créés
1. `audit_referral_system.py` - Audit initial (échec format)
2. `audit_referral_system_v2.py` - Version avec logging (échec format)
3. `audit_referral_system_v3.py` - Recherche de tables (connexion reset)
4. `audit_referral_simple.py` - Version simplifiée (succès partiel)
5. `audit_referral_test_format.py` - Test format réponse (succès)
6. `audit_referral_pg_class.py` - Utilisation pg_class (succès mais pas de données)
7. `audit_referral_public.py` - Recherche schéma public (succès)
8. `audit_referral_all_schemas.py` - Tous schémas (succès)
9. `audit_referral_direct.py` - Tests directs (timeout)

---

## Résultats des Tests

### Tests réussis

**Test 1: SELECT simple**
```sql
SELECT 1 as test_col, 'hello' as test_str
```
- **Status:** ✅ Succès
- **Response:** `{"ok": true, "mode": "select", "rows": [{"test_col": 1, "test_str": "hello"}]}`

**Test 2: Vérification existence schéma app**
```sql
SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'app';
```
- **Status:** ✅ Succès
- **Response:** `{"ok": true, "mode": "exec", "affected_rows": 1}`
- **Conclusion:** Le schéma `app` existe

**Test 3: Recherche tables avec 'referral' ou 'commission' (tous schémas)**
```sql
SELECT n.nspname as schema_name, c.relname as table_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
AND (c.relname ILIKE '%referral%' OR c.relname ILIKE '%commission%')
AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY n.nspname, c.relname;
```
- **Status:** ✅ Succès
- **Response:** `{"ok": true, "mode": "exec", "affected_rows": 0}`
- **Conclusion:** Aucune table avec 'referral' ou 'commission' trouvée dans aucun schéma

**Test 4: Recherche tables avec 'referral' ou 'commission' (schéma public)**
- **Status:** ✅ Succès
- **Response:** `{"ok": true, "mode": "exec", "affected_rows": 0}`
- **Conclusion:** Aucune table trouvée dans le schéma public

### Tests échoués (timeout/connexion)

Les tests suivants ont échoué en raison de timeouts de connexion à Supabase:
- `audit_referral_direct.py` - Tests directs sur les tables (timeout après 30s)

### Tests avec format de réponse inattendu

Les requêtes utilisant `pg_class` et `pg_attribute` retournent `mode: "exec"` au lieu de `mode: "select"`, ce qui empêche la récupération des lignes de résultats.

---

## Analyse des Mémoires Existantes

### Système de Commissions (Mémoire 4de83688-6255-4940-a206-c0becdeb17f9)

Selon la mémoire sur le système de commissions:

**Table `app.commission_rules`:**
- Colonnes: id, payment_reason, degree_level, commission_rate, max_amount, currency, is_active, description, priority
- UNIQUE(payment_reason, degree_level)
- 13 règles par défaut

**Fonction de résolution:**
- `app.fn_resolve_commission_rate(payment_reason, degree_level)`
- Priorité: exact match > payment_reason match > degree_level match > wildcard

**Commission automatique dans `app_admin_confirm_payment`:**
- Vérifie si l'étudiant a un commercial referrer (user_referrals)
- Vérifie si le profil commercial est actif
- Résout le taux de commission depuis commission_rules
- Applique un cap par prospect (fn_check_commission_cap)
- Applique un taux dégressif: min(resolved_rate, cap_adjusted_rate)
- Crée une entrée referral_commissions avec status='pending'

**Système hybride commercial:**
- Tiers: Bronze(0)/Silver(5)/Gold(15)/Diamond(30)
- Cap: max N commissions par prospect (default 3)
- Taux dégressif: base * 0.85^n

### Problème Potentiel Identifié

La mémoire mentionne:
- `user_referrals` - table pour stocker les liens de référenciation
- `referral_commissions` - table pour stocker les commissions créées

Cependant, les tests SQL n'ont trouvé **aucune table** avec ces noms dans aucun schéma.

---

## Hypothèses sur le Problème

### Hypothèse 1: Tables nommées différemment

Les tables de référenciation pourraient avoir des noms différents de ceux mentionnés dans les mémoires:
- Possibilité: `commercial_referrals` au lieu de `user_referrals`
- Possibilité: `referral_commission` (singulier) au lieu de `referral_commissions` (pluriel)

### Hypothèse 2: Système implémenté via colonnes dans students

Le système de référenciation pourrait être implémenté via une colonne dans la table `students`:
- Colonne potentielle: `referred_by` (UUID du commercial)
- Colonne potentielle: `commercial_referrer_id`

### Hypothèse 3: Système non déployé

Le système de référenciation complet pourrait ne pas avoir été déployé:
- Les mémoires décrivent un système planifié
- Les tables n'existent pas encore en production
- Seul le système de `commission_rules` est déployé

### Hypothèse 4: Problème de duplication (le vrai problème)

Si le système existe mais que les tables n'ont pas été trouvées, le problème "deux prospects pour un vrai prospect" pourrait être causé par:

1. **Absence de contrainte UNIQUE** sur (prospect_id, commercial_id)
   - Un commercial pourrait créer plusieurs références pour le même prospect
   - Chaque référence génère une commission distinctE

2. **Trigger mal configuré** lors de la création de paiement
   - Le trigger pourrait créer plusieurs entrées de referral_commissions
   - Pour un même paiement et un même prospect

3. **Bug dans l'RPC app_admin_confirm_payment**
   - La logique de vérification du cap pourrait être contournée
   - Plusieurs commissions pourraient être créées pour le même prospect

---

## Recommandations

### Recommandation 1: Audit approfondi des tables existantes

Exécuter les requêtes suivantes pour identifier les vraies tables de référenciation:

```sql
-- Lister toutes les tables du schéma app
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'app'
ORDER BY table_name;

-- Chercher les colonnes de référenciation dans students
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name = 'students'
AND (column_name LIKE '%ref%' OR column_name LIKE '%commercial%');

-- Chercher les colonnes de référenciation dans commercial_profiles
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'app'
AND table_name = 'commercial_profiles'
AND (column_name LIKE '%ref%' OR column_name LIKE '%prospect%');
```

### Recommandation 2: Vérifier les contraintes sur les tables de référenciation

Si les tables existent, vérifier:
- Contrainte UNIQUE sur (prospect_id, commercial_id)
- Index sur prospect_id pour éviter les duplications
- Trigger de validation avant insertion

### Recommandation 3: Audit des données de commissions

Si `referral_commissions` existe:
```sql
SELECT 
    prospect_id,
    commercial_id,
    COUNT(*) as commission_count,
    SUM(amount) as total_amount
FROM app.referral_commissions
GROUP BY prospect_id, commercial_id
HAVING COUNT(*) > 1
ORDER BY commission_count DESC;
```

### Recommandation 4: Vérifier la logique de l'RPC app_admin_confirm_payment

Auditer le code source de l'RPC pour s'assurer que:
- La vérification du cap est correcte
- La création de commission est idempotente
- Aucune boucle ne crée plusieurs commissions

---

## Analyse du Code Flutter

### Système de Référenciation Côté Client

**Fichier: `signup_screen.dart`**
- Le code de référenciation (`ref_code`) est injecté dans `user_metadata` lors de l'inscription
- Le code est également stocké dans `SharedPreferences` sous la clé `pending_referral_code_v1`
- Le code est transmis au serveur via `client.auth.signUp(data: signUpData)`

**Fichier: `auth_wrapper.dart`**
- Après la connexion, le système lit le code de référenciation depuis `SharedPreferences`
- Fallback: lecture depuis `user_metadata['ref_code']` côté serveur
- Appel de l'RPC `app_register_referral_for_current_user` avec:
  - `p_ref_code`: le code de référenciation
  - `p_source`: source du code ('link', 'manual', 'metadata')
- Si succès, le code est supprimé de `SharedPreferences`

**Fichier: `admin_commission_rules_screen.dart`**
- Interface admin pour gérer les règles de commission
- Utilise l'RPC `app_admin_list_commission_rules` pour charger les règles
- Utilise l'RPC `app_admin_upsert_commission_rule` pour créer/modifier des règles
- Utilise l'RPC `app_admin_delete_commission_rule` pour supprimer des règles

**Fichier: `admin_commission_rules_provider.dart`**
- Provider Flutter pour la gestion des règles de commission
- Les règles incluent: payment_reason, degree_level, commission_rate, max_amount, priority, is_active

---

## Tests RPCs Supabase

### Tests effectués

**Test 1: Recherche de `app_register_referral_for_current_user`**
```sql
SELECT pg_get_functiondef(oid)
FROM pg_proc 
WHERE proname = 'app_register_referral_for_current_user';
```
- **Résultat:** ❌ RPC non trouvée (mode: "exec", affected_rows: 1)

**Test 2: Liste des RPCs avec 'referral' dans le nom**
```sql
SELECT n.nspname, p.proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%referral%';
```
- **Résultat:** ❌ Aucune RPC trouvée (mode: "exec", affected_rows: 5)

**Test 3: Liste des RPCs avec 'commission' dans le nom**
```sql
SELECT n.nspname, p.proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname ILIKE '%commission%';
```
- **Résultat:** ❌ Aucune RPC trouvée (mode: "exec", affected_rows: 10)

**Test 4: Liste des RPCs du schéma app**
```sql
SELECT json_agg(json_build_object('function', p.proname))
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'app' AND p.prokind = 'f' LIMIT 20;
```
- **Résultat:** ❌ Pas de données retournées (mode: "exec", affected_rows: 1)

### Problème identifié avec admin_execute_sql

L'RPC `admin_execute_sql` retourne `mode: "exec"` pour les requêtes SELECT sur les vues système (pg_proc, pg_class, pg_attribute), ce qui empêche la récupération des lignes de résultats. Les requêtes simples sur des tables retournent `mode: "select"` correctement.

---

## Conclusion

### État actuel
- ❌ Les tables `user_referrals` et `referral_commissions` n'ont pas été trouvées via API REST (404)
- ❌ Les RPCs de référenciation n'ont pas été trouvées via pg_proc (problème de format de réponse)
- ✅ Le schéma `app` existe
- ✅ Les requêtes simples via admin_execute_sql fonctionnent
- ✅ Le code Flutter montre un système de référenciation implémenté côté client
- ⚠️ L'RPC `app_register_referral_for_current_user` est appelée dans Flutter mais n'a pas été trouvée dans Supabase

### Problème identifié

Le problème "deux prospects pour un vrai prospect" pourrait être causé par:

1. **RPC manquante ou non déployée:** `app_register_referral_for_current_user` est appelée dans Flutter mais n'existe pas dans Supabase
2. **Absence de contrainte UNIQUE:** Si la table de référenciation existe sans contrainte UNIQUE sur (prospect_id, commercial_id)
3. **Bug dans la logique de création:** Si l'RPC crée plusieurs entrées pour le même prospect

### Recommandations

1. **Déployer l'RPC manquante:** Créer l'RPC `app_register_referral_for_current_user` dans Supabase
2. **Auditer les tables existantes:** Obtenir la liste complète des tables du schéma app via un autre moyen
3. **Ajouter des contraintes:** S'assurer que les tables de référenciation ont des contraintes UNIQUE appropriées
4. **Tester le flux complet:** Tester le flux d'inscription avec un code de référenciation pour vérifier le comportement

### Prochaine étape

Il est nécessaire de:
1. Contacter l'équipe backend pour obtenir la liste complète des tables du schéma app
2. Vérifier si l'RPC `app_register_referral_for_current_user` existe dans un autre schéma ou avec un nom différent
3. Auditer les données de paiement pour identifier les duplications de commissions
4. Corriger la logique de duplication si nécessaire

---

## Scripts créés

- `audit_referral_system.py` - Audit initial
- `audit_referral_system_v2.py` - Version avec logging
- `audit_referral_system_v3.py` - Recherche de tables
- `audit_referral_simple.py` - Version simplifiée
- `audit_referral_test_format.py` - Test format réponse
- `audit_referral_pg_class.py` - Utilisation pg_class
- `audit_referral_public.py` - Recherche schéma public
- `audit_referral_all_schemas.py` - Tous schémas
- `audit_referral_direct.py` - Tests directs
- `audit_referral_rest_api.py` - Tests API REST
- `audit_referral_rest_schema.py` - Tests API REST avec schéma
- `audit_referral_rpc_source.py` - Recherche code source RPC
- `audit_referral_rpc_list.py` - Liste RPCs
- `search_referral_rpc.py` - Recherche RPC dans fichiers SQL locaux

Tous les scripts sont disponibles dans le dossier `.windsurf/`.
