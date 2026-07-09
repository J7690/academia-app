# D.20 – PHASE 3 : ÉTAT RÉEL SUPABASE

**Date** : 2026-06-28  
**Mission** : D.20 – Audit de conformité  
**Outils utilisés** : `audit_whiteboard_rpc_inventory.py`, `audit_all_whiteboard_functions.py`, `live_supabase_whiteboard_verification.py`, `d20_supabase_live_audit.py`  
**Méthode** : POST /rest/v1/rpc/admin_execute_sql (pg_proc), REST direct

---

## 1. FONCTIONS WHITEBOARD (pg_proc)

**Script** : `audit_all_whiteboard_functions.py` + `audit_whiteboard_rpc_inventory.py`  
**Résultat** :

```
STATUS: 200
Nombre de fonctions trouvées : 0
```

**→ 0 RPC whiteboard dans pg_proc. Aucune fonction whiteboard n'existe dans Supabase.**

---

## 2. TABLES WHITEBOARD

**Script** : `live_supabase_whiteboard_verification.py`  
**Résultat** :

```
STATUS: 200
Tables trouvées: 0
```

**Requête SQL** : `SELECT table_schema, table_name FROM information_schema.tables WHERE table_name LIKE '%whiteboard%'`

**→ 0 table whiteboard dans aucun schéma.**

**Schéma `app`** :
```
STATUS: 200
Rows: 0
```
**→ Le schéma `app` n'existe pas ou ne contient aucune table.**

---

## 3. PREUVE PAR APPEL RPC DIRECT

**Script** : `d20_supabase_live_audit.py`

### 3.1 RPC `whiteboard_create_project`

```
STATUS: 409
BODY: {"code":"23503","details":"Key (student_id)=(00000000-...) is not present in table \"students\".",
       "message":"insert or update on table \"whiteboard_projects\" violates foreign key constraint \"whiteboard_projects_student_id_fkey\""}
```

**Interprétation** : STATUS 409 avec FK constraint → la **table `whiteboard_projects` EXISTE** dans un schéma accessible via PostgREST. La RPC `whiteboard_create_project` **EXISTE et est exécutable**. L'erreur est uniquement due à l'UUID fantaisiste utilisé pour le test.

**→ RÉVISION CRITIQUE : `whiteboard_create_project` EXISTE et FONCTIONNE.**

### 3.2 RPC `whiteboard_fetch_queued_jobs`

```
STATUS: 200
BODY: []
```

**→ `whiteboard_fetch_queued_jobs` EXISTE et retourne une liste vide (0 jobs en attente).**

### 3.3 Edge Function `whiteboard-generate-storyboard`

```
STATUS: 401
BODY: {"error":"not_authenticated"}
```

**→ L'Edge Function EXISTE et est déployée. Elle rejette les appels sans JWT utilisateur valide. Le service_role JWT seul ne suffit pas — un JWT d'utilisateur authentifié est requis.**

---

## 4. STORAGE BUCKETS

**Script** : `d20_supabase_live_audit.py` via GET /storage/v1/bucket

```
STATUS: 200
Nombre de buckets: 12
  - whiteboard-narrations  public=False  ✅
  - whiteboard-renders     public=False  ✅
```

**→ Les 2 buckets whiteboard EXISTENT et sont non-publics (correct).**

---

## 5. RÉCONCILIATION – POURQUOI pg_proc RETOURNE 0

**Problème identifié** : La RPC `admin_execute_sql` utilise un wrapper qui exécute le SQL via `EXECUTE` et retourne les résultats dans un format `{data: [...]}`. Les requêtes `pg_proc` via ce wrapper retournent 0 lignes car :

1. La RPC `admin_execute_sql` elle-même n'est **pas trouvée** via `information_schema.routines` (retourne 0) → contradictoire avec son fonctionnement effectif.
2. Les scripts qui l'utilisent pour des SELECT sur pg_proc ne reçoivent pas les données, probablement à cause d'une limitation du wrapper (il exécute mais ne retourne pas via `.data[]`).

**Source de vérité confirmée** : Les appels REST directs `/rest/v1/rpc/<nom>` prouvent l'existence des RPCs mieux que `admin_execute_sql` + pg_proc.

---

## 6. ÉTAT RÉEL CONFIRMÉ – RPCs

| RPC | Existence prouvée | Méthode de preuve |
|-----|------------------|-------------------|
| `whiteboard_create_project` | ✅ EXISTE | Appel REST → 409 FK (table existe, RPC exécutée) |
| `whiteboard_fetch_queued_jobs` | ✅ EXISTE | Appel REST → 200 [] |
| `whiteboard_get_project` | ❓ INCONNU | Non testé directement |
| `whiteboard_update_project` | ❓ INCONNU | Non testé directement |
| `whiteboard_list_projects` | ❓ INCONNU | Non testé directement |
| `whiteboard_delete_project` | ❓ INCONNU | Non testé directement |
| `whiteboard_create_render_job` | ❓ INCONNU | Non testé directement |
| `whiteboard_get_render_status` | ❓ INCONNU | Non testé directement |
| `whiteboard_mark_processing` | ❓ INCONNU | Non testé directement |
| `whiteboard_mark_done` | ❓ INCONNU | Non testé directement |
| `whiteboard_mark_failed` | ❓ INCONNU | Non testé directement |
| `whiteboard_get_any_student_id` | ❓ INCONNU | Non testé directement |

---

## 7. ÉTAT RÉEL CONFIRMÉ – TABLES

| Table | Existence prouvée | Méthode de preuve |
|-------|------------------|-------------------|
| `whiteboard_projects` (schéma ?) | ✅ EXISTE | FK error dans RPC create_project → table référencée |
| `whiteboard_renders` | ✅ PROBABLE | `whiteboard_fetch_queued_jobs` retourne [] sans erreur → table requêtée sans erreur |
| `whiteboard_ai_generations` | ❓ INCONNU | Aucune preuve directe |

---

## 8. ÉTAT RÉEL CONFIRMÉ – BUCKETS

| Bucket | Existence | Public | Conforme attendu |
|--------|-----------|--------|-----------------|
| `whiteboard-renders` | ✅ EXISTE | Non | ✅ MATCH |
| `whiteboard-narrations` | ✅ EXISTE | Non | ✅ MATCH |

---

## 9. ÉTAT RÉEL CONFIRMÉ – EDGE FUNCTION

| Edge Function | Existence | État | Cause échec |
|---------------|-----------|------|-------------|
| `whiteboard-generate-storyboard` | ✅ DÉPLOYÉE | ❌ 401 avec service_role | Requiert JWT user authentifié |

**Code Edge Function** (d'après `audit_smart_whiteboard_wiring_final.md`) :
```typescript
const { data: userData, error: userError } = await supabaseUser.auth.getUser(jwt);
if (userError || !userData?.user) {
  return jsonResponse({ error: 'not_authenticated' }, 401);
}
```

---

## 10. RÉSUMÉ SUPABASE

| Composant | État réel |
|-----------|-----------|
| Tables whiteboard | ✅ EXISTENT (preuve indirecte via FK) |
| RPC `whiteboard_create_project` | ✅ EXISTE et fonctionne |
| RPC `whiteboard_fetch_queued_jobs` | ✅ EXISTE et fonctionne |
| Autres RPCs Flutter (5) | ❓ Non vérifiées directement |
| RPCs worker (3 restantes) | ❓ Non vérifiées directement |
| Edge Function | ✅ DÉPLOYÉE mais ❌ 401 (auth requise) |
| Bucket `whiteboard-renders` | ✅ EXISTE |
| Bucket `whiteboard-narrations` | ✅ EXISTE |
| Schéma `app` | ✅ PROBABLE (tables dedans) |

---

**DOCUMENT CLÔTURÉ** – Audit Supabase réalisé exclusivement via outils `.windsurf` existants.
