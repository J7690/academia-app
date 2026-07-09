# D.23 – PHASE 4 : MATRICE DE VALIDATION CROISÉE DES CONTRATS

**Date** : 2026-06-28  
**Sources** : D23 Phases 1, 2, 3 + logs runtime D22  
**Format** : Couche | Attendu | Réel | Conforme | Impact

---

## MATRICE PRINCIPALE

| Couche | Point de contrat | Attendu | Réel (D22 runtime) | Conforme | Impact |
|--------|-----------------|---------|-------------------|---------|--------|
| **Flutter** | `createProject()` assigne `_currentProjectId` | `String` UUID | `"f04aa2f5-..."` (D19-05) | ✅ OUI | Aucun |
| **Flutter** | `createProject()` construit `_currentProject` | `WhiteboardProject(subject, rendererId, ...)` | `null` | ❌ **NON** | **CAUSE RACINE** |
| **Flutter** | `generateStoryboard()` lit `_currentProject?.subject` | `"dérivés d'une fonction"` | `""` (D19-06) | ❌ NON | Sujet perdu |
| **Flutter** | `generateStoryboard()` lit `_currentProject?.rendererId` | `"notebook"` | `"scientific"` (défaut) | ❌ NON | Mauvais renderer |
| **Flutter** | `generateStoryboard()` lit `_currentProject?.themeId` | `"notebook"` | `"scientific"` (défaut) | ❌ NON | Mauvais thème |
| **Flutter** | `generateStoryboard()` lit `_currentProject?.narrationMode` | `"tts"` | `"none"` (défaut) | ❌ NON | Narration désactivée |
| **Supabase** | `whiteboard_create_project` RETURNS | `{success, project_id}` | `{success: true, project_id: "f04aa2f5-..."}` (D19-31) | ✅ OUI | Aucun |
| **Supabase** | `whiteboard_create_project` retourne `subject` | **Non prévu** | **Non retourné** | ✅ OUI (cohérent) | Design délibéré |
| **Supabase** | `whiteboard_get_project` retourne tous les champs | `{success, project: {id, subject, renderer_id, ...}}` | Jamais appelé en D22 | N/A | Non atteinte |
| **Supabase** | `whiteboard_get_render_status` retourne status | `{success, render: {...}}` | HTTP 400 SQL 42703 (`file_size_bytes` absent) | ❌ **CASSÉE** | Rupture phase rendu |
| **Edge Fn** | Accepte `subject=""` | Comportement défini : accepte | ✅ Accepte (D19-07: HTTP 200) | ✅ OUI | Aucun (par design) |
| **Edge Fn** | `subject` vide → IA génère contenu spontané | "Les Lois de Newton" (sujets LLM courants) | `subject=""` injecté dans JSON retourné | ✅ Cohérent | Storyboard hors-sujet |
| **Edge Fn** | Défaut `renderer="scientific"` | Volontaire si non fourni | `"scientific"` reçu (D22) | ✅ OUI | Combiné avec bug Flutter |
| **Edge Fn** | Défaut `narration_mode="none"` | Volontaire si non fourni | `"none"` reçu (D22) | ✅ OUI | Combiné avec bug Flutter |
| **Edge Fn** | Crée un second projet en interne | `whiteboard_create_project` appelé avec `subject=""` | HTTP 200, `project_data` retourné | ✅ Fonctionne | Double projet créé en DB |
| **Kamatera** | Poll `whiteboard_fetch_queued_jobs` | HTTP 200, jobs list | HTTP 200, `[]` (D22 runtime 09:46Z) | ✅ OUI | Aucun job à traiter |
| **Kamatera** | Traitement d'un job | `mark_processing` + rendu + `mark_done` | Jamais appelé depuis le 24 juin | ✅ Normal (pas de job) | En attente |

---

## MATRICE DE COHÉRENCE PAR COUCHE

### Flutter → Supabase

| Appel | Payload Flutter | Contrat Supabase | Conforme |
|-------|----------------|-----------------|---------|
| `whiteboard_create_project` | `{p_student_id, p_subject, p_renderer_id, p_theme_id, p_narration_mode, p_storyboard_json}` | Attend exactement ces 6 paramètres | ✅ OUI |
| Lecture réponse `result['success']` | `result['success'] == true` | SQL retourne `jsonb_build_object('success', true, ...)` | ✅ OUI |
| Lecture réponse `result['project_id']` | `result['project_id'] as String` | SQL retourne `'project_id', v_project_id` (uuid castable String) | ✅ OUI |

### Flutter → Edge Function

| Champ envoyé | Valeur avec `_currentProject==null` | Valeur avec `_currentProject≠null` | Impact |
|-------------|------------------------------------|------------------------------------|--------|
| `subject` | `""` | `"dérivés d'une fonction"` | ❌ Sujet perdu |
| `renderer` | `"scientific"` | `"notebook"` | ❌ Mauvais renderer |
| `theme` | `"scientific"` | `"notebook"` | ❌ Mauvais thème |
| `narration_mode` | `"none"` | `"tts"` | ❌ Narration perdue |

### Supabase SQL → Runtime réel

| RPC | SQL prévu | Runtime D22 | Écart |
|-----|-----------|-------------|-------|
| `whiteboard_create_project` | INSERT + RETURNING id | ✅ `{success:true, project_id:UUID}` | Aucun |
| `whiteboard_get_render_status` | SELECT `wr.file_size_bytes` | ❌ HTTP 400, `file_size_bytes does not exist` | Colonne absente |

---

## SYNTHÈSE DES ÉCARTS PAR CRITICITÉ

| # | Écart | Couche | Criticité | Type |
|---|-------|--------|-----------|------|
| 1 | `_currentProject` jamais assigné après `createProject()` | Flutter | 🔴 CRITIQUE | Bug — ligne manquante |
| 2 | `whiteboard_get_render_status` SQL 42703 (`file_size_bytes` absent) | Supabase SQL | 🔴 CRITIQUE | Bug — colonne absente |
| 3 | Edge Function ne valide pas `subject` non vide | Edge Fn | 🟡 MOYEN | Comportement permissif |
| 4 | Edge Function recrée un second projet en interne (double création DB) | Edge Fn | 🟡 MOYEN | Design discutable |
| 5 | Flutter ignore `project_data` dans la réponse Edge Function | Flutter | 🟡 MOYEN | Occasion manquée |

---

## CONCLUSION PHASE 4

La matrice confirme **un seul point d'entrée du bug** : l'écart #1 (Flutter). Tous les autres composants (Supabase `whiteboard_create_project`, Edge Function, Kamatera) fonctionnent conformément à leur contrat. L'écart #2 (`whiteboard_get_render_status`) est une **seconde rupture indépendante** qui se déclencherait lors d'un poll de rendu.

---

**DOCUMENT CLÔTURÉ** — Matrice construite depuis les 3 sources de vérité : code Flutter, SQL Supabase réel (toolchain `.windsurf`), code Edge Function.
