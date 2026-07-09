# D.18.1 – PHASE 5: PREMIER BUG BLOQUANT RÉEL

**Date**: 2026-06-26
**Mission**: D.18.1

---

## BUG IDENTIFIÉ

**Premier bug bloquant réel**: mauvais type de retour consommé pour `whiteboard_list_projects`.

---

## FICHIER

`academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`

## LIGNE

531

## CODE DÉFECTUEUX

```dart
@academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:518-543
Future<void> loadProjects() async {
  _setState(SmartWhiteboardState.loading);
  _errorMessage = null;

  try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      _setError('Not authenticated');
      return;
    }

    final response = await client.rpc('whiteboard_list_projects');

    if (response != null) {
      _projects = response as List<dynamic>;
    } else {
      _projects = [];
    }

    _setState(SmartWhiteboardState.idle);
  } catch (e) {
    _setError(e.toString());
  }
}
```

---

## JSON RÉEL PRODUIT PAR SUPABASE

```sql
@.windsurf/create_missing_flutter_rpcs.sql:208-211
result := jsonb_build_object(
  'success', true,
  'projects', COALESCE(projects, '[]'::jsonb)
);
```

### Exemple de JSON réel

```json
{
  "success": true,
  "projects": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "student_id": "550e8400-e29b-41d4-a716-446655440001",
      "subject": "Pythagore",
      "status": "draft",
      "created_at": "2026-06-26T10:00:00+00:00",
      "updated_at": "2026-06-26T10:00:00+00:00",
      "renderer_id": "scientific",
      "theme_id": "scientific",
      "narration_mode": "none"
    }
  ]
}
```

### Type réel

`_Map<String, dynamic>`

---

## TYPE ATTENDU PAR FLUTTER

```dart
_projects = response as List<dynamic>;
```

### Type attendu

`List<dynamic>`

---

## STACKTRACE ATTENDUE

```text
type '_Map<String, dynamic>' is not a subtype of type 'List<dynamic>' in type cast

#0      SmartWhiteboardProvider.loadProjects
(academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:534:24)
```

---

## CONSÉQUENCE RUNTIME

1. L'utilisateur ouvre l'écran de liste des projets Smart Whiteboard.
2. `loadProjects()` appelle `whiteboard_list_projects`.
3. Supabase retourne un `Map<String, dynamic>`.
4. Flutter tente de caster en `List<dynamic>`.
5. Le cast échoue avec une `TypeError`.
6. Le `catch` capture l'erreur et appelle `_setError(e.toString())`.
7. L'écran affiche: `type '_Map<String, dynamic>' is not a subtype of type 'List<dynamic>' in type cast`

---

## CORRECTION MINIMALE NÉCESSAIRE

**Note**: Cette correction est indiquée à titre d'information. Aucune modification n'est appliquée (interdiction formelle de la mission D.18.1).

### Option A: Extraire la clé `projects`

```dart
final response = await client.rpc('whiteboard_list_projects');

if (response is Map<String, dynamic> && response['success'] == true) {
  _projects = response['projects'] as List<dynamic>? ?? [];
} else {
  _projects = [];
}
```

### Option B: Ligne 534 corrigée directement

```dart
_projects = (response as Map<String, dynamic>)['projects'] as List<dynamic>? ?? [];
```

---

## POURQUOI C'EST LE PREMIER BUG BLOQUANT

### Ordre d'exécution utilisateur

1. L'utilisateur lance l'app.
2. L'utilisateur navigue vers l'onglet Challenge → Smart Whiteboard.
3. La liste des projets est chargée automatiquement.
4. `loadProjects()` est appelée.
5. Le cast échoue immédiatement.

### Autres bugs candidats écartés

- `whiteboard_create_project` → ✅ contrat compatible
- `whiteboard-generate-storyboard` → ✅ contrat compatible
- `whiteboard_create_render_job` → ✅ contrat compatible
- `whiteboard_get_render_status` → ✅ contrat compatible
- `ExportSettings.fromJson` → ✅ contrat compatible (mais les DEBUG prints indiquent que le type a été un problème historique)

---

## PREUVES

### Preuve Flutter

```dart
@academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:531-534
final response = await client.rpc('whiteboard_list_projects');

if (response != null) {
  _projects = response as List<dynamic>;
}
```

### Preuve SQL

```sql
@.windsurf/create_missing_flutter_rpcs.sql:178-214
CREATE OR REPLACE FUNCTION public.whiteboard_list_projects(
  p_status text DEFAULT NULL
)
RETURNS jsonb
...
result := jsonb_build_object(
  'success', true,
  'projects', COALESCE(projects, '[]'::jsonb)
);
```

---

## CONCLUSION

Le premier bug bloquant réel du système Smart Whiteboard est le cast incorrect de `whiteboard_list_projects` dans `smart_whiteboard_provider.dart:534`.

**Aucune modification n'a été appliquée.**
