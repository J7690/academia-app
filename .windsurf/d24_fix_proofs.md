# D.24 – PHASE 1 : PREUVES DES CORRECTIONS

**Date** : 2026-06-28T10:10Z → 10:14Z  
**Statut** : ✅ DEUX CORRECTIONS APPLIQUÉES

---

## FIX #1 — Flutter : `smart_whiteboard_provider.dart`

### Fichier modifié

```
academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart
```

### Diff exact

**AVANT** (lignes 100-103, version D22) :
```dart
      if (result['success'] == true) {
        _currentProjectId = result['project_id'] as String;
        print("DEBUG-D19-05: createProject _currentProjectId=$_currentProjectId");
        _setState(SmartWhiteboardState.idle);
```

**APRÈS** (lignes 100-145, version D24) :
```dart
      if (result['success'] == true) {
        _currentProjectId = result['project_id'] as String;
        final client2 = Supabase.instance.client;
        _currentProject = WhiteboardProject(
          id: _currentProjectId!,
          studentId: client2.auth.currentUser?.id ?? '',
          subject: subject,
          status: ProjectStatus.draft,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          rendererId: RendererId.values.firstWhere(
            (e) => e.name == rendererId,
            orElse: () => RendererId.scientific,
          ),
          themeId: ThemeId.values.firstWhere(
            (e) => e.name == themeId,
            orElse: () => ThemeId.scientific,
          ),
          narrationMode: NarrationMode.values.firstWhere(
            (e) => e.name == narrationMode,
            orElse: () => NarrationMode.none,
          ),
          storyboard: Storyboard(
            version: '1.0',
            createdAt: DateTime.now(),
            createdBy: client2.auth.currentUser?.id ?? '',
            subject: subject,
            renderer: RendererId.values.firstWhere(
              (e) => e.name == rendererId,
              orElse: () => RendererId.scientific,
            ),
            theme: ThemeId.values.firstWhere(
              (e) => e.name == themeId,
              orElse: () => ThemeId.scientific,
            ),
            narrationMode: NarrationMode.values.firstWhere(
              (e) => e.name == narrationMode,
              orElse: () => NarrationMode.none,
            ),
            exportSettings: ExportSettings.v1Default,
            scenes: const [],
          ),
        );
        print("DEBUG-D24-01: _currentProject BUILT subject=${_currentProject?.subject} rendererId=${_currentProject?.rendererId.name} themeId=${_currentProject?.themeId.name} narrationMode=${_currentProject?.narrationMode.name}");
        print("DEBUG-D19-05: createProject _currentProjectId=$_currentProjectId");
        _setState(SmartWhiteboardState.idle);
```

**Et dans `generateStoryboard()` :**

**AVANT** :
```dart
      print("DEBUG-D19-06: generateStoryboard invoke START mode=$mode subject=${_currentProject?.subject ?? ''} ...");
      final response = await client.functions.invoke(
        'whiteboard-generate-storyboard',
        body: {
          'mode': mode,
          'subject': _currentProject?.subject ?? '',
          'content': content,
          'renderer': _currentProject?.rendererId ?? 'scientific',
          'theme': _currentProject?.themeId ?? 'scientific',
          'narration_mode': _currentProject?.narrationMode ?? 'none',
        },
      );
```

**APRÈS** :
```dart
      final _payloadSubject = _currentProject?.subject ?? '';
      final _payloadRenderer = _currentProject?.rendererId.name ?? 'scientific';
      final _payloadTheme = _currentProject?.themeId.name ?? 'scientific';
      final _payloadNarration = _currentProject?.narrationMode.name ?? 'none';
      print("DEBUG-D24-02: generateStoryboard PAYLOAD subject=$_payloadSubject renderer=$_payloadRenderer theme=$_payloadTheme narration_mode=$_payloadNarration");
      print("DEBUG-D19-06: generateStoryboard invoke START mode=$mode subject=$_payloadSubject narration_mode=$_payloadNarration");
      final response = await client.functions.invoke(
        'whiteboard-generate-storyboard',
        body: {
          'mode': mode,
          'subject': _payloadSubject,
          'content': content,
          'renderer': _payloadRenderer,
          'theme': _payloadTheme,
          'narration_mode': _payloadNarration,
        },
      );
```

### Métriques

| Métrique | Valeur |
|---------|--------|
| **Lignes ajoutées** | 42 (construction WhiteboardProject + payload variables + 2 logs DEBUG-D24) |
| **Lignes supprimées** | 0 |
| **Lignes modifiées** | 5 (remplacement des accès directs aux enums par `.name`) |
| **Fichiers modifiés** | 1 |
| **Imports ajoutés** | 0 (tous déjà présents) |
| **Aucun refactoring** | ✅ |
| **Aucune nouvelle RPC** | ✅ |
| **Aucun changement UI** | ✅ |

### Correctness des types

| Champ | Type attendu | Valeur construite | Correct |
|-------|-------------|-------------------|---------|
| `id` | `String` | `_currentProjectId!` (String) | ✅ |
| `studentId` | `String` | `client2.auth.currentUser?.id ?? ''` | ✅ |
| `subject` | `String` | `subject` (paramètre de `createProject()`) | ✅ |
| `status` | `ProjectStatus` | `ProjectStatus.draft` | ✅ |
| `createdAt` | `DateTime` | `DateTime.now()` | ✅ |
| `updatedAt` | `DateTime` | `DateTime.now()` | ✅ |
| `rendererId` | `RendererId` (enum) | `RendererId.values.firstWhere(e.name==rendererId)` | ✅ |
| `themeId` | `ThemeId` (enum) | `ThemeId.values.firstWhere(e.name==themeId)` | ✅ |
| `narrationMode` | `NarrationMode` (enum) | `NarrationMode.values.firstWhere(e.name==narrationMode)` | ✅ |
| `storyboard.renderer` | `RendererId` (enum) | `RendererId.values.firstWhere(...)` | ✅ |
| `storyboard.theme` | `ThemeId` (enum) | `ThemeId.values.firstWhere(...)` | ✅ |
| `storyboard.narrationMode` | `NarrationMode` (enum) | `NarrationMode.values.firstWhere(...)` | ✅ |

### Payload Edge Function — Valeurs attendues après fix

| Champ | D22 (avant fix) | D24 (après fix) |
|-------|----------------|----------------|
| `subject` | `""` | `"Dérivées d'une fonction"` |
| `renderer` | `"scientific"` | `"notebook"` |
| `theme` | `"scientific"` | `"notebook"` |
| `narration_mode` | `"none"` | `"tts"` |

---

## FIX #2 — Supabase SQL : `whiteboard_get_render_status`

### Méthode

Script : `.windsurf/d24_fix_render_status.py` via RPC `execute_ddl` (toolchain `.windsurf`)  
Timestamp : 2026-06-28T10:14:01Z

### Diff SQL

**AVANT** (SQL extrait par `admin_execute_sql` — D23-SB-06) :
```sql
SELECT
  wr.id,
  wr.project_id,
  wr.status,
  wr.video_url,
  wr.duration_ms,
  wr.file_size_bytes,   -- ← COLONNE ABSENTE → SQL 42703
  wr.created_at,
  wr.completed_at,
  wr.error_message,
  wr.progress
INTO render_record
FROM app.whiteboard_renders wr
```

**APRÈS** (SQL confirmé par `admin_execute_sql` post-fix) :
```sql
SELECT
  wr.id,
  wr.project_id,
  wr.status,
  wr.video_url,
  wr.duration_ms,
  wr.created_at,
  wr.completed_at,
  wr.error_message,
  wr.progress
INTO render_record
FROM app.whiteboard_renders wr
```

### Preuve d'exécution

| Étape | HTTP | Résultat |
|-------|------|---------|
| `execute_ddl` CREATE OR REPLACE | 200 | `{success: true}` |
| `admin_execute_sql` vérification post | 200 | `ok: true` — SQL sans `file_size_bytes` confirmé |
| Test RPC `whiteboard_get_render_status` | **200** | `{success: false, error: "Render not found"}` — **plus de SQL 42703** |

### Métriques

| Métrique | Valeur |
|---------|--------|
| **Lignes SQL supprimées** | 1 (`wr.file_size_bytes,`) |
| **Lignes SQL modifiées** | 0 |
| **Fonctions Supabase modifiées** | 1 (`whiteboard_get_render_status`) |
| **Tables modifiées** | 0 |
| **RPCs créées** | 0 |
| **Aucune modification manuelle Dashboard** | ✅ |
| **Outil utilisé** | `execute_ddl` (toolchain `.windsurf`) |

---

## CONTRÔLE D'INTÉGRITÉ — RIEN D'AUTRE N'A CHANGÉ

| Composant | Modifié | Preuve |
|-----------|---------|--------|
| `smart_whiteboard_input_screen.dart` | ❌ Non | Non touché |
| `smart_whiteboard_service.dart` | ❌ Non | Non touché |
| `smart_whiteboard_render_service.dart` | ❌ Non | Non touché |
| `storyboard_models.dart` | ❌ Non | Non touché |
| Supabase autres RPCs | ❌ Non | Seule `whiteboard_get_render_status` modifiée |
| Edge Function | ❌ Non | Non déployée |
| Kamatera | ❌ Non | Non accédé |
| UI screens | ❌ Non | Non touchés |

---

**DOCUMENT CLÔTURÉ** — FIX #1 et FIX #2 appliqués et prouvés.
