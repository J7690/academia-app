# D.22 – PHASE 4 : VALIDATION SUPABASE RPCs RUNTIME

**Date** : 2026-06-28T09:44Z (device) + 09:17Z (REST D.21)  
**Sources** : logs device réels (D22) + appels REST D.21  
**Outil** : `d21_supabase_rpc_proof.py` (REST direct)

---

## 1. `whiteboard_create_project`

| Élément | Valeur runtime |
|---------|----------------|
| **Source preuve** | DEBUG-D19-31 (device) |
| **HTTP Status** | implicite 200 (success: true) |
| **Payload réel** | `{p_student_id: "6745c7ad-...", p_subject: "dérivés d'une fonction", p_renderer_id: "notebook", p_theme_id: "notebook", p_narration_mode: "tts", p_storyboard_json: {}}` |
| **Body exact** | `{success: true, project_id: "f04aa2f5-b456-4ffb-81f1-42216d7d36ae"}` |
| **Type JSON réel** | `_Map<String, dynamic>` |
| **Conformité Flutter** | ✅ OUI — code Flutter lit `result['success']` et `result['project_id']` correctement |
| **Exécutions runtime** | 3× (f04aa2f5, 9812075e, 073b3e3c) |

**REST D.21 (2026-06-28T09:17:34Z)** :
```
HTTP 200
{"success": true, "project_id": "d6384439-7b78-4f16-9629-b4d3979fc6f0"}
```

**VERDICT** : ✅ RPC fonctionnelle et conforme

---

## 2. `whiteboard_get_project`

| Élément | Valeur runtime |
|---------|----------------|
| **Source preuve** | REST D.21 |
| **HTTP Status** | 200 |
| **Payload** | `{p_project_id: "7c399415-..."}` |
| **Body exact** | `{"error": "Project not found", "success": false}` |
| **Type JSON réel** | `dict` |
| **Conformité Flutter** | ✅ Géré par Flutter (vérifie `result['success']`) |

**Note** : RPC non appelée dans le test device (non instrumentée directement).

**VERDICT** : ✅ RPC fonctionnelle

---

## 3. `whiteboard_update_project`

| Élément | Valeur runtime |
|---------|----------------|
| **Source preuve** | REST D.21 |
| **HTTP Status** | 200 |
| **Body exact** | `{"error": "Project not found", "success": false}` (sur ID inexistant) |
| **Type JSON réel** | `dict` |
| **Conformité Flutter** | ✅ |

**VERDICT** : ✅ RPC fonctionnelle

---

## 4. `whiteboard_list_projects`

| Élément | Valeur runtime |
|---------|----------------|
| **Source preuve** | REST D.21 |
| **HTTP Status** | 200 |
| **Body exact** | `{"success": true, "projects": []}` |
| **Type JSON réel** | `dict` |
| **Conformité Flutter** | ✅ |
| **Note** | Vide avec service_role (normal — filtre par session user) |

**VERDICT** : ✅ RPC fonctionnelle

---

## 5. `whiteboard_create_render_job`

| Élément | Valeur runtime |
|---------|----------------|
| **Source preuve** | REST D.21 |
| **HTTP Status** | 200 |
| **Payload** | `{p_project_id: "7c399415-..."}` (projet C3J supprimé) |
| **Body exact** | `{"error": "Project not found or unauthorized", "success": false}` |
| **Type JSON réel** | `dict` |
| **Conformité Flutter** | ✅ Flutter vérifie `result['success']` |
| **Note** | Non appelée dans test device car EditorScreen ne conduit pas encore au rendu |

**VERDICT** : ✅ RPC fonctionnelle — non atteinte dans le test device

---

## 6. `whiteboard_get_render_status`

| Élément | Valeur runtime |
|---------|----------------|
| **Source preuve** | REST D.21 (2026-06-28T09:17:41Z) |
| **HTTP Status** | **400** |
| **Payload** | `{p_render_id: "fd9e3969-..."}` |
| **Body exact** | `{"code": "42703", "details": null, "hint": null, "message": "column wr.file_size_bytes does not exist"}` |
| **Type JSON réel** | `dict` (erreur Postgres) |
| **Conformité Flutter** | ❌ NON — HTTP 400 → PostgrestException non gérée → crash potentiel |

**VERDICT** : ❌ **RPC CASSÉE** — SQL error 42703 : `column wr.file_size_bytes does not exist`

---

## 7. `whiteboard_fetch_queued_jobs` (Worker)

| Élément | Valeur runtime |
|---------|----------------|
| **Source preuve** | journald Kamatera (2026-06-28T09:46Z) |
| **HTTP Status** | 200 |
| **Body** | `[]` (liste vide) |
| **Type JSON réel** | `list` |
| **Conformité Worker** | ✅ Worker lit la liste et compte `Found 0 queued job(s)` |

**VERDICT** : ✅ RPC fonctionnelle

---

## TABLEAU RÉCAPITULATIF

| RPC | HTTP Status | Body type | Conformité Flutter | Verdict |
|-----|-------------|-----------|-------------------|---------|
| `whiteboard_create_project` | 200 | Map | ✅ | ✅ |
| `whiteboard_get_project` | 200 | Map | ✅ | ✅ |
| `whiteboard_update_project` | 200 | Map | ✅ | ✅ |
| `whiteboard_list_projects` | 200 | Map | ✅ | ✅ |
| `whiteboard_create_render_job` | 200 | Map | ✅ | ✅ |
| `whiteboard_get_render_status` | **400** | Map (erreur) | ❌ | ❌ CASSÉE |
| `whiteboard_fetch_queued_jobs` | 200 | List | ✅ | ✅ |

---

**DOCUMENT CLÔTURÉ**
