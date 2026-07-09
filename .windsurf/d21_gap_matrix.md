# D.21 – PHASE 5 : MATRICE DES ÉCARTS RUNTIME

**Date** : 2026-06-28  
**Mission** : D.21 – Audit runtime ground truth  
**Format** : ID | Description | Criticité | Impact | Preuve | Fichier | Ligne

---

## FLUTTER

| ID | Description | Criticité | Impact | Preuve | Fichier | Ligne |
|----|-------------|-----------|--------|--------|---------|-------|
| **F-01** | `_currentProject` jamais assigné après `createProject()` → `generateStoryboard()` envoie `subject=""` au lieu du vrai sujet | 🔴 CRITIQUE | L'IA génère un storyboard sur un sujet vide — comportement utilisateur inutilisable | Code source: `result['project_id']` assigné mais pas de `WhiteboardProject(...)` | `smart_whiteboard_provider.dart` | 100-103 |
| **F-02** | `generateStoryboard()` utilise `_currentProject?.subject ?? ''` mais `_currentProject == null` | 🔴 CRITIQUE | `subject = ""` envoyé à l'Edge Function | Déduction statique directe + code instrumenté DEBUG-D19-08 | `smart_whiteboard_provider.dart` | 139 |
| **F-03** | Edge Function retourne 401 → `_setError("not_authenticated")` → navigation bloquée | 🔴 CRITIQUE | Utilisateur voit un message d'erreur, ne peut pas accéder à l'éditeur | REST D.21: HTTP 401 `{"error":"not_authenticated"}` | `smart_whiteboard_provider.dart` | 150-161 |
| **F-04** | `whiteboard_get_render_status` retourne HTTP 400 (SQL error) → crash ou exception | 🔴 CRITIQUE | Polling de statut impossible → l'utilisateur ne voit jamais la vidéo | REST D.21: HTTP 400 `{"code":"42703","message":"column wr.file_size_bytes does not exist"}` | `smart_whiteboard_render_service.dart` | 33-41 |
| **F-05** | `generateTTS()` est un stub vide (TODO) | 🟠 MAJEUR | Narration TTS jamais fonctionnelle | Code source: `// TODO: Call TTS Edge Function` | `smart_whiteboard_provider.dart` | 407 |
| **F-06** | `recordNarration()` est un stub vide | 🟠 MAJEUR | Narration utilisateur jamais fonctionnelle | Code source: `// TODO: Implement audio recording` | `smart_whiteboard_provider.dart` | 421 |
| **F-07** | `loadProjects()` bypass `SmartWhiteboardService`, appelle `client.rpc()` direct | 🟡 MINEUR | Incohérence architecturale | Code source: `client.rpc('whiteboard_list_projects')` | `smart_whiteboard_provider.dart` | 543 |
| **F-08** | Cast `as Map<String, dynamic>` sans null-check dans `SmartWhiteboardService` | 🟡 RISQUE | Crash `_CastError` si RPC retourne null | Code source: `return response as Map<String, dynamic>` | `smart_whiteboard_service.dart` | 38 |
| **F-09** | Cast `status['render'] as Map<String, dynamic>` sans null-check | 🟡 RISQUE | Crash `_CastError` si `render` absent | Code source: `final render = status['render'] as Map<String, dynamic>` | `smart_whiteboard_render_service.dart` | 63 |
| **F-10** | `_narrationService` accepté dans constructeur mais jamais utilisé | 🟡 MINEUR | Instance inutile, service orphelin | Code source: `// final SmartWhiteboardNarrationService _narrationService` | `smart_whiteboard_provider.dart` | 23 |
| **F-11** | `SmartWhiteboardProjectsListScreen` non accessible depuis le flow challenge principal | 🟡 MINEUR | Utilisateur ne peut pas naviguer vers ses projets | `student_challenges_tab.dart`: navigation directe vers InputScreen | `student_challenges_tab.dart` | ~1928 |

---

## SUPABASE

| ID | Description | Criticité | Impact | Preuve | Composant | Détail |
|----|-------------|-----------|--------|--------|-----------|--------|
| **S-01** | `whiteboard_get_render_status` contient une référence à `wr.file_size_bytes` inexistante | 🔴 CRITIQUE | Toute tentative de poll du statut retourne HTTP 400 — Flutter ne peut jamais récupérer la vidéo | REST D.21: HTTP 400 `{"code":"42703","message":"column wr.file_size_bytes does not exist"}` | RPC Supabase | `whiteboard_get_render_status` |
| **S-02** | Edge Function retourne 401 pour tous les appels sans JWT utilisateur valide | 🔴 CRITIQUE | Storyboard jamais généré | REST D.21: HTTP 401 | Edge Function | `whiteboard-generate-storyboard` |
| **S-03** | `whiteboard_delete_project` retourne `success: true` même pour un UUID inexistant | 🟡 MINEUR | Comportement idempotent mais non documenté | REST D.21: HTTP 200 `{"success": true}` pour UUID fantaisiste | RPC Supabase | `whiteboard_delete_project` |
| **S-04** | Tables `whiteboard_*` dans schéma `app` non exposées via PostgREST `/rest/v1/<table>` | 🟢 INFO | Attendu (sécurité) — tables accédées via RPCs | REST D.21: HTTP 404 PGRST205 | Tables | schéma `app` |
| **S-05** | `whiteboard_ai_generations` non prouvée comme existante | 🟡 INCONNU | Logging IA non vérifié | Aucun appel REST direct testé | Table | `whiteboard_ai_generations` |
| **S-06** | `whiteboard_list_projects` retourne `{projects: []}` avec service_role | 🟡 INFO | Normal — filtrée par student_id de session. Avec service_role, pas de session → vide | REST D.21: HTTP 200 `{"success": true, "projects": []}` | RPC Supabase | `whiteboard_list_projects` |

---

## KAMATERA

| ID | Description | Criticité | Impact | Preuve | Composant | Détail |
|----|-------------|-----------|--------|--------|-----------|--------|
| **K-01** | Worker.log contient 2118 erreurs 404 (ancienne version) | 🟡 HISTORIQUE | Erreurs passées, résolues dans la version actuelle | `worker.log` first/last lines: 404 sur `/rest/v1/whiteboard_renders` | worker.log | Ancienne implémentation |
| **K-02** | Worker actuel poll `whiteboard_fetch_queued_jobs` mais 0 jobs créés | 🟠 MAJEUR | Pipeline end-to-end jamais exercé depuis Flutter | journald: `Found 0 queued job(s)` en boucle continue | Kamatera Worker | PID 395272 |
| **K-03** | Aucun render job créé depuis Flutter (bloqué à l'étape Edge Function) | 🔴 CONSÉQUENCE | Kamatera attend indéfiniment | journald + REST D.21 combinés | Pipeline global | Chaîne Flutter→Supabase→Kamatera |

---

## EDGE FUNCTIONS

| ID | Description | Criticité | Impact | Preuve | Composant | Détail |
|----|-------------|-----------|--------|--------|-----------|--------|
| **EF-01** | `whiteboard-generate-storyboard` requiert JWT user valide, pas service_role | 🔴 CRITIQUE (contexte) | Normal en production, mais bloque les tests sans device authentifié | REST D.21: HTTP 401 | `whiteboard-generate-storyboard` | Auth check dans Edge Function |

---

## STORAGE

| ID | Description | Criticité | Impact | Preuve | Composant | Détail |
|----|-------------|-----------|--------|--------|-----------|--------|
| **ST-01** | Bucket `whiteboard-renders` existe et non-public | ✅ CONFORME | — | REST D.20: HTTP 200 | Bucket Supabase | `whiteboard-renders` |
| **ST-02** | Bucket `whiteboard-narrations` existe et non-public | ✅ CONFORME | — | REST D.20: HTTP 200 | Bucket Supabase | `whiteboard-narrations` |

---

## RÉSUMÉ PAR CRITICITÉ

| Criticité | Nombre | IDs |
|-----------|--------|-----|
| 🔴 CRITIQUE | 5 | F-01, F-02, F-03, F-04, S-01, S-02 |
| 🟠 MAJEUR | 3 | F-05, F-06, K-02 |
| 🟡 MINEUR/RISQUE | 7 | F-07, F-08, F-09, F-10, F-11, S-03, S-05 |
| 🟢 INFO/CONFORME | 4 | S-04, S-06, ST-01, ST-02 |

---

## BLOCAGES DANS LA CHAÎNE D'EXÉCUTION

```
InputScreen → createProject()   ✅ F-OK (RPC fonctionne)
           → generateStoryboard()
              ├─ subject = ""   ❌ F-01/F-02 (PREMIER BLOCAGE FONCTIONNEL)
              └─ Edge Fn 401   ❌ F-03/S-02 (BLOQUANT ABSOLU)
              
[Editor jamais atteint]
[createRenderJob() jamais appelé]
[Worker attend indéfiniment : K-02]
[getRenderStatus() cassée de toute façon : S-01/F-04]
```

---

**DOCUMENT CLÔTURÉ**
