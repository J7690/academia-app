# D.17 - PHASE 3: MATCH FLUTTER ↔ SUPABASE

**Date**: 2026-06-26
**Mission**: D.17

---

## MÉTHODE

Comparer les appels trouvés dans le code Flutter avec les RPCs attendues dans Supabase.

---

## MATCH PAR RPC

### 1. `whiteboard_create_project`

**Flutter**:
```dart
whiteboard_create_project(
  p_student_id: uuid,
  p_subject: text,
  p_renderer_id: text,
  p_theme_id: text,
  p_narration_mode: text,
  p_storyboard_json: jsonb,
)
```

**Supabase attendue**:
```sql
whiteboard_create_project(
  p_student_id UUID,
  p_subject VARCHAR,
  p_renderer_id VARCHAR,
  p_theme_id VARCHAR,
  p_narration_mode VARCHAR,
  p_storyboard_json JSONB
)
```

**Statut**: ✅ MATCH

---

### 2. `whiteboard_get_project`

**Flutter**:
```dart
whiteboard_get_project(
  p_project_id: uuid,
)
```

**Supabase attendue**:
```sql
whiteboard_get_project(p_project_id UUID)
```

**Statut**: ✅ MATCH

---

### 3. `whiteboard_update_project`

**Flutter**:
```dart
whiteboard_update_project(
  p_project_id: uuid,
  p_subject: text?,
  p_status: text?,
  p_renderer_id: text?,
  p_theme_id: text?,
  p_narration_mode: text?,
  p_storyboard_json: jsonb?,
)
```

**Supabase attendue**:
```sql
whiteboard_update_project(
  p_project_id UUID,
  p_subject VARCHAR DEFAULT NULL,
  p_status VARCHAR DEFAULT NULL,
  p_renderer_id VARCHAR DEFAULT NULL,
  p_theme_id VARCHAR DEFAULT NULL,
  p_narration_mode VARCHAR DEFAULT NULL,
  p_storyboard_json JSONB DEFAULT NULL
)
```

**Statut**: ✅ MATCH

---

### 4. `whiteboard_list_projects`

**Flutter**:
```dart
whiteboard_list_projects(
  p_status: text?,
)
```

**Supabase attendue**:
```sql
whiteboard_list_projects(p_status VARCHAR DEFAULT NULL)
```

**Statut**: ✅ MATCH

---

### 5. `whiteboard_delete_project`

**Flutter**:
```dart
whiteboard_delete_project(
  p_project_id: uuid,
)
```

**Supabase attendue**:
```sql
whiteboard_delete_project(p_project_id UUID)
```

**Statut**: ✅ MATCH

---

### 6. `whiteboard_create_render_job`

**Flutter**:
```dart
whiteboard_create_render_job(
  p_project_id: uuid,
)
```

**Supabase attendue**:
```sql
whiteboard_create_render_job(p_project_id UUID)
```

**Statut**: ✅ MATCH

---

### 7. `whiteboard_get_render_status`

**Flutter**:
```dart
whiteboard_get_render_status(
  p_render_id: uuid,
)
```

**Supabase attendue**:
```sql
whiteboard_get_render_status(p_render_id UUID)
```

**Statut**: ✅ MATCH

---

### 8. Edge Function `whiteboard-generate-storyboard`

**Flutter**:
```dart
client.functions.invoke(
  'whiteboard-generate-storyboard',
  body: {
    'mode': mode,
    'subject': subject,
    'content': content,
    'renderer': renderer,
    'theme': theme,
    'narration_mode': narrationMode,
  },
)
```

**Edge Function**:
```typescript
const mode = (body.mode ?? 'simple_subject').toString().trim();
const subject = (body.subject ?? '').toString().trim();
const content = (body.content ?? '').toString().trim();
const renderer = (body.renderer ?? 'scientific').toString().trim();
const theme = (body.theme ?? 'scientific').toString().trim();
const narrationMode = (body.narration_mode ?? 'none').toString().trim();
```

**Statut**: ✅ MATCH

---

## RÉSUMÉ DES MATCHS

| Élément | Statut | Remarque |
|---------|--------|----------|
| `whiteboard_create_project` | ✅ MATCH | |
| `whiteboard_get_project` | ✅ MATCH | |
| `whiteboard_update_project` | ✅ MATCH | |
| `whiteboard_list_projects` | ✅ MATCH | |
| `whiteboard_delete_project` | ✅ MATCH | |
| `whiteboard_create_render_job` | ✅ MATCH | |
| `whiteboard_get_render_status` | ✅ MATCH | |
| `whiteboard-generate-storyboard` | ✅ MATCH | |

---

## MISMATCH POTENTIELS NON DÉMONTRÉS

### Mismatch 1: Schéma des RPCs

- **Flutter** appelle `whiteboard_create_project` sans préciser de schéma.
- **PostgREST** appelle les fonctions dans le schéma `public` par défaut.
- **Fichiers SQL archivés** montrent que `public.whiteboard_create_project` est un wrapper appelant `app.app_whiteboard_create_project` (legacy).
- **Statut**: ⚠️ SIGNATURE DIFFERENTE / POTENTIEL BREAKPOINT

**Risque**: Si le wrapper `public.whiteboard_create_project` n'a pas été mis à jour pour appeler `app.whiteboard_create_project` (sans `app_`), l'appel échouera car `app.app_whiteboard_create_project` a été supprimée.

---

### Mismatch 2: `whiteboard_list_projects` retourne JSONB

- **Flutter** dans `SmartWhiteboardProvider.loadProjects` attend `List<dynamic>`:
  ```dart
  final response = await client.rpc('whiteboard_list_projects');
  _projects = response as List<dynamic>;
  ```
- **Supabase attendue** retourne `JSONB` avec la structure `{ "success": true, "projects": [...] }`.

**Statut**: ⚠️ TYPE DIFFERENT

**Risque**: Le cast `response as List<dynamic>` échouera car la réponse est un `Map<String, dynamic>`, pas une `List`.

---

## CONCLUSION

- **Signatures des RPCs**: ✅ MATCH (mais schéma réel non confirmé)
- **Type de retour de `whiteboard_list_projects`**: ⚠️ MISMATCH POTENTIEL
- **Câblage Edge Function**: ✅ MATCH
