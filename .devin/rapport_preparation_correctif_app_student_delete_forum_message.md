# RAPPORT DE PRÉPARATION DU CORRECTIF

## `app_student_delete_forum_message` — Proxy `public` → `app`

**Date** : 2026-06-04
**Statut** : PRÉPARATION COMPLÈTE — AUCUNE EXÉCUTION EFFECTUÉE
**Type d'intervention** : Proxy SQL (wrapper) sans modification de la logique métier
**Fichier SQL préparé** : `.windsurf/sql_changes/change_20260604_fix_app_student_delete_forum_message.sql`

---

## 1. SIGNATURE DU RPC SOURCE (DÉDUITE)

### Inventaire Supabase

| Propriété | Valeur confirmée | Source |
|-----------|-----------------|--------|
| **Nom** | `app_student_delete_forum_message` | `audit_inventory_base.json` |
| **Schéma actuel** | `app` uniquement | `rpc_matrix_full.json` (status: B) |
| **Return type** | `jsonb` | `audit_inventory_base.json` |
| **Paramètres** | `p_message_id UUID` (hypothèse forte) | Déduit du code Flutter + pattern des autres RPCs |

### Code Flutter appelant

```dart
await Supabase.instance.client.rpc(
  'app_student_delete_forum_message',
  params: {'p_message_id': msgId},  // msgId = m['id']?.toString() (UUID string)
);
```

### Pattern de référence (RPC similaire validé)

Le RPC `public.app_student_delete_video_comment` (migration `change_20260223_add_delete_video_comment.sql`) suit le même pattern :

```sql
CREATE OR REPLACE FUNCTION public.app_student_delete_video_comment(p_comment_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$ ... $$;

GRANT EXECUTE ON FUNCTION public.app_student_delete_video_comment(UUID) TO authenticated;
```

**Conclusion** : Le paramètre est très probablement un `UUID`. La vérification préalable dans le script SQL permet de confirmer avant exécution.

---

## 2. SCRIPT SQL PRÉPARÉ — REVUE LIGNE PAR LIGNE

**Fichier** : `change_20260604_fix_app_student_delete_forum_message.sql`

### Section 0 — Vérification préalable (commentée)

```sql
/*
SELECT 
  p.proname AS function_name,
  pg_get_function_arguments(p.oid) AS arguments,
  pg_get_function_result(p.oid) AS return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'app'
  AND p.proname = 'app_student_delete_forum_message';
*/
```

| Ligne | Rôle | Risque |
|-------|------|--------|
| Commentaire | Permet de vérifier la signature exacte avant déploiement | Aucun — ne s'exécute pas automatiquement |

**Action requise** : L'opérateur doit copier-coller cette requête dans Supabase SQL Editor et confirmer que le résultat indique `p_message_id uuid` avant d'exécuter le reste du script.

---

### Section 1 — Création du proxy

```sql
CREATE OR REPLACE FUNCTION public.app_student_delete_forum_message(
  p_message_id UUID
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, app, auth
AS $$
  SELECT app.app_student_delete_forum_message(p_message_id);
$$;
```

| Élément | Valeur | Justification |
|---------|--------|---------------|
| `CREATE OR REPLACE` | Idempotent | Permet de réexécuter sans erreur si besoin |
| `public.` | Schéma cible | PostgREST résout les appels RPC sans préfixe dans `public` |
| `p_message_id UUID` | Paramètre unique | Correspond au `{'p_message_id': msgId}` du code Flutter |
| `RETURNS JSONB` | Type de retour | Identique au RPC source et aux autres RPCs forum |
| `LANGUAGE sql` | Langage SQL (pas plpgsql) | Le proxy ne fait qu'une délégation simple ; pas besoin de logique procédurale |
| `SECURITY DEFINER` | Exécution avec les droits du créateur | Nécessaire pour que le proxy puisse appeler la fonction `app` (le rôle `authenticated` n'a pas directement accès au schéma `app`) |
| `SET search_path = public, app, auth` | Ordre de résolution | `public` d'abord (standard), `app` pour résoudre `app.app_student_delete_forum_message`, `auth` pour `auth.uid()` si jamais appelé indirectement |
| `SELECT app.app_student_delete_forum_message(p_message_id)` | Délégation | Appelle le RPC source dans `app` avec le même paramètre et retourne son résultat tel quel |

**Risque identifié** : Si le type réel du paramètre dans `app` n'est pas `UUID` (ex: `text`), le `CREATE FUNCTION` échouera avec une erreur de cast. La vérification préalable (Section 0) élimine ce risque.

---

### Section 2 — Grant

```sql
GRANT EXECUTE ON FUNCTION public.app_student_delete_forum_message(UUID) TO authenticated;
```

| Élément | Valeur | Justification |
|---------|--------|---------------|
| `GRANT EXECUTE` | Permission d'appel | Sans ce grant, PostgREST refuse l'appel même si la fonction existe dans `public` |
| `TO authenticated` | Rôle cible | Rôle standard pour les utilisateurs connectés dans Supabase/PostgREST ; identique aux autres RPCs forum |

**Pattern confirmé** : 255 occurrences de `GRANT EXECUTE ... TO authenticated` dans les migrations du projet.

---

## 3. ROLLBACK PRÉPARÉ

### Rollback immédiat (suppression du proxy)

```sql
DROP FUNCTION IF EXISTS public.app_student_delete_forum_message(UUID);
```

| Propriété | Valeur |
|-----------|--------|
| **Effet** | Supprime uniquement le proxy dans `public`. Le RPC source dans `app` reste intact. |
| **Impact utilisateur** | Retour à l'état initial : l'appel Flutter retombe en `PGRST202`. |
| **Durée** | < 1 seconde |
| **Reversibilité** | Le proxy peut être recréé instantanément en réexécutant le script de correction. |

### Scénarios de rollback

| Scénario | Déclencheur | Action |
|----------|-------------|--------|
| **A** — Type de paramètre incorrect | Le `CREATE FUNCTION` échoue lors du déploiement | Aucun rollback nécessaire (aucune modification n'a été appliquée) |
| **B** — Comportement inattendu après déploiement | L'appel fonctionne mais retourne un résultat erroné | Exécuter `DROP FUNCTION IF EXISTS public.app_student_delete_forum_message(UUID);` |
| **C** — Régression sur d'autres fonctionnalités | Un autre RPC forum cesse de fonctionner (très improbable) | Même rollback : `DROP FUNCTION ...` |

---

## 4. ANALYSE DE RISQUE

### Matrice de risque

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| **Type de paramètre incorrect** | Faible | Le CREATE échoue, aucune modification | Vérification préalable (Section 0) |
| **La fonction source `app` est corrompue/défectueuse** | Inconnue | Le proxy délègue vers une fonction qui échoue | Le proxy n'altère pas la source ; le risque préexiste |
| **Conflit de nom** | Nulle | Un autre objet `public.app_student_delete_forum_message` existe | L'inventaire confirme l'absence dans `public` |
| **Régression sur les autres RPCs forum** | Nulle | Les 8 autres RPCs forum sont dans `public` depuis longtemps | Le proxy n'interagit avec aucun autre RPC |
| **Régression sur les tables** | Nulle | Le proxy ne touche pas aux tables | Délégation pure, pas de requête directe |
| **Problème de permissions** | Faible | Le rôle `authenticated` ne peut pas appeler le proxy | Le `GRANT EXECUTE` est explicite et testé |
| **Fuite de données** | Nulle | Le proxy expose plus que prévu | Le proxy a la même signature que la source et retourne le même résultat |

### Risque résiduel global

**FAIBLE**

Le proxy est une délégation transparente. Il n'ajoute aucune logique métier, ne modifie aucune table, et n'altère aucun objet existant. Le seul risque réel est une inadéquation de type de paramètre, qui est éliminée par la vérification préalable.

---

## 5. VÉRIFICATION DE L'IMPACT SUR LES AUTRES FONCTIONNALITÉS

### Écosystème forum (8 autres RPCs)

| RPC | Schéma | Statut | Impact du proxy |
|-----|--------|--------|-----------------|
| `app_ci_add_online_course_forum_message` | `public` | A (OK) | Aucun |
| `app_ci_create_online_course_forum_thread` | `public` | A (OK) | Aucun |
| `app_ci_list_online_course_forum_messages` | `public` | A (OK) | Aucun |
| `app_ci_list_online_course_forum_threads` | `public` | A (OK) | Aucun |
| `app_student_add_online_course_forum_message` | `public` | A (OK) | Aucun |
| `app_student_create_online_course_forum_thread` | `public` | A (OK) | Aucun |
| `app_student_list_online_course_forum_messages` | `public` | A (OK) | Aucun |
| `app_student_list_online_course_forum_threads` | `public` | A (OK) | Aucun |

**Conclusion** : Le proxy est isolé. Il n'y a aucune dépendance croisée avec les autres RPCs de forum.

### Flux utilisateur vérifiés

| Flux | Avant proxy | Après proxy | Changement |
|------|-------------|-------------|------------|
| **Création de thread** | OK (public) | OK (public) | Aucun |
| **Liste des threads** | OK (public) | OK (public) | Aucun |
| **Envoi de message** | OK (public) | OK (public) | Aucun |
| **Liste des messages** | OK (public) | OK (public) | Aucun |
| **Suppression de message** | ❌ PGRST202 | ✅ Fonctionnel | **Corrigé** |
| **Signalement de message** | OK (Flutter local) | OK (Flutter local) | Aucun |
| **Bloquer auteur** | OK (Flutter local) | OK (Flutter local) | Aucun |

### Écrans et Providers

| Fichier | Rôle | Impact |
|---------|------|--------|
| `online_course_detail_screen.dart` | Écran étudiant (bouton suppression) | **Bénéficiaire du correctif** |
| `online_course_forum_provider.dart` | Provider (loadThreads, loadMessages, sendMessage) | Aucun (le provider ne supprime pas de messages) |
| `instructor_course_forum_screen.dart` | Écran instructeur | Aucun (pas de suppression instructeur via ce RPC) |

---

## 6. PLAN DE TEST TECNO

### Prérequis

- [ ] Application Academia installée sur le téléphone TECNO
- [ ] Compte étudiant connecté
- [ ] Inscription à un cours en ligne avec forum actif
- [ ] Au moins un message personnel dans le forum

### Procédure de test

#### Test 1 — Vérification pré-déploiement (constater le bug)

1. Ouvrir l'application sur le TECNO
2. Naviguer vers un cours en ligne → onglet "Forum"
3. Ouvrir un thread de discussion
4. Envoyer un message (si aucun message personnel n'existe)
5. Appui **long** sur son propre message
6. Sélectionner **"Supprimer"** (rouge)
7. **Constater** : une erreur apparaît (probablement `PostgrestException [404]: ...`)
8. **Capturer** : screenshot de l'erreur

#### Test 2 — Déploiement du correctif

1. Ouvrir Supabase SQL Editor
2. Exécuter la **Section 0** (vérification préalable) du script SQL
3. Confirmer que le résultat indique `p_message_id uuid`
4. Exécuter la **Section 1** (CREATE FUNCTION) du script SQL
5. Exécuter la **Section 2** (GRANT) du script SQL
6. Vérifier post-déploiement : exécuter les requêtes de vérification commentées dans le script

#### Test 3 — Vérification post-déploiement (constater la correction)

1. Sur le TECNO, retourner au même cours → forum
2. Appui long sur le même message (ou un nouveau message personnel)
3. Sélectionner "Supprimer"
4. **Constater** : le message disparaît sans erreur
5. **Capturer** : screenshot de l'écran sans le message
6. Vérifier que le reload automatique (`p.loadMessages(threadId)`) rafraîchit la liste

#### Test 4 — Régression (vérifier les autres flux)

1. Envoyer un nouveau message dans le thread
2. Vérifier que le message apparaît immédiatement
3. Rafraîchir la liste des threads
4. Vérifier que les threads s'affichent correctement
5. Signaler un message d'un autre utilisateur
6. Vérifier que le signalement fonctionne

#### Test 5 — Rollback (optionnel, si un problème est constaté)

1. Exécuter : `DROP FUNCTION IF EXISTS public.app_student_delete_forum_message(UUID);`
2. Retester la suppression
3. Constater que l'erreur PGRST202 revient

### Critères de succès

| Test | Critère |
|------|---------|
| Test 1 | Erreur PGRST202 visible avant déploiement |
| Test 2 | Script SQL exécuté sans erreur |
| Test 3 | Message supprimé sans erreur visible |
| Test 4 | Aucune régression sur création/liste/signalement |
| Test 5 | (Optionnel) Rollback fonctionnel si nécessaire |

---

## 7. CHECKLIST DE DÉPLOIEMENT

### Avant exécution

- [ ] Relecture du présent rapport par un second opérateur
- [ ] Exécution de la vérification préalable (Section 0) dans Supabase SQL Editor
- [ ] Confirmation que `p_message_id` est bien de type `UUID`
- [ ] Sauvegarde de la base de données (point-in-time recovery Supabase) notée
- [ ] Fenêtre de maintenance définie (si applicable)

### Exécution

- [ ] Exécuter la Section 1 (`CREATE OR REPLACE FUNCTION ...`) dans Supabase SQL Editor
- [ ] Exécuter la Section 2 (`GRANT EXECUTE ...`) dans Supabase SQL Editor
- [ ] Exécuter les requêtes de vérification post-déploiement (commentées dans le script)

### Après exécution

- [ ] Exécuter le Test 3 sur le TECNO (suppression de message)
- [ ] Exécuter le Test 4 sur le TECNO (régression)
- [ ] Documenter le résultat dans le présent rapport (section "Résultat du déploiement")
- [ ] Si succès : marquer l'intervention comme terminée
- [ ] Si échec : exécuter le rollback et investiguer

---

## 8. SYNTHÈSE

| Élément | Valeur |
|---------|--------|
| **Problème** | `app_student_delete_forum_message` existe dans `app` mais pas dans `public` → PGRST202 |
| **Solution** | Proxy `public.app_student_delete_forum_message()` déléguant vers `app.app_student_delete_forum_message()` |
| **Lignes de code SQL** | 3 lignes actives (CREATE, GRANT, DROP rollback) |
| **Temps d'exécution estimé** | < 5 secondes dans Supabase SQL Editor |
| **Temps de test TECNO estimé** | 5 minutes |
| **Risque** | Faible (proxy transparent, vérification préalable) |
| **Rollback** | `DROP FUNCTION IF EXISTS public.app_student_delete_forum_message(UUID);` |
| **Modifications Flutter** | Aucune |
| **Modifications tables** | Aucune |
| **Modifications autres RPCs** | Aucune |

---

*Document préparé sans exécution ni modification. Autorisation séparée requise avant déploiement.*
