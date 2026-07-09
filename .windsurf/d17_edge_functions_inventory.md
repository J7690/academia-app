# D.17 - PHASE 4: INVENTAIRE EDGE FUNCTIONS

**Date**: 2026-06-26
**Mission**: D.17
**Dossier scanné**: `supabase/functions/`

---

## Fonction: `whiteboard-generate-storyboard`

**Fichier**: `supabase/functions/whiteboard-generate-storyboard/index.ts`

### RPCs appelées

| RPC | Ligne | Usage |
|-----|-------|-------|
| `app_student_reserve_credits` | 351 | Réserver les crédits avant génération |
| `app_student_refund_credits` | 396 | Rembourser les crédits en cas d'erreur LLM |
| `app_student_refund_credits` | 422 | Rembourser les crédits en cas d'erreur JSON |
| `app_student_refund_credits` | 433 | Rembourser les crédits en cas de storyboard invalide |
| `whiteboard_create_project` | 451 | Stocker le projet dans Supabase |
| `app_student_confirm_credits` | 461 | Confirmer la dépense de crédits |
| `admin_execute_sql` | 494 | Logger la génération dans `app.whiteboard_ai_generations` |

### Tables utilisées

| Table | Schéma | Usage |
|-------|--------|-------|
| `app.whiteboard_ai_generations` | `app` | Logging des générations (via `admin_execute_sql`) |
| `app.whiteboard_projects` | `app` | Indirect via `whiteboard_create_project` |

### Buckets utilisés

Aucun bucket utilisé directement dans cette Edge Function.

### URLs externes

| URL | Ligne | Usage |
|-----|-------|-------|
| `https://openrouter.ai/api/v1/chat/completions` | 38 | Appel LLM pour générer le storyboard |

### Webhooks

Aucun webhook utilisé.

### Dépendances non-whiteboard

| RPC | Usage |
|-----|-------|
| `app_student_reserve_credits` | Crédits |
| `app_student_refund_credits` | Crédits |
| `app_student_confirm_credits` | Crédits |
| `admin_execute_sql` | Logging |

---

## Autres fonctions dans `supabase/functions/`

Le dossier `supabase/functions/` contient 50 éléments. La seule Edge Function directement liée au Smart Whiteboard est `whiteboard-generate-storyboard`.

---

## Note importante

L'Edge Function appelle `whiteboard_create_project` (ligne 451). Cette RPC doit exister dans le schéma `public` de Supabase pour être accessible via PostgREST.
