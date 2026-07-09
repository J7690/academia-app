# D.19 – PHASE 5: CORRECTION MINIMALE UNIQUE

**Date**: 2026-06-27
**Mission**: D.19

---

## PREMIER CRASH RÉEL IDENTIFIÉ

**Fichier**: `academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`
**Ligne**: 548
**Fonction**: `loadProjects()`

---

## CODE DÉFECTUEUX

```dart
@smart_whiteboard_provider.dart:531-548
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

    print("DEBUG-D19-26: loadProjects rpc START userId=$userId");
    final response = await client.rpc('whiteboard_list_projects');
    print("DEBUG-D19-27: loadProjects response=$response runtimeType=${response.runtimeType} isNull=${response == null}");

    if (response != null) {
      print("DEBUG-D19-28: loadProjects BEFORE CAST response.runtimeType=${response.runtimeType}");
      _projects = response as List<dynamic>;  // ← CRASH ICI
      print("DEBUG-D19-29: loadProjects AFTER CAST _projects=$_projects runtimeType=${_projects.runtimeType} length=${_projects.length}");
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

## VALEUR RÉELLE PRODUITE PAR SUPABASE

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

**Type réel**: `_Map<String, dynamic>`

---

## TYPE ATTENDU PAR FLUTTER

`List<dynamic>`

---

## STACKTRACE ATTENDUE

```text
type '_Map<String, dynamic>' is not a subtype of type 'List<dynamic>' in type cast

#0      SmartWhiteboardProvider.loadProjects
(academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:548:24)
```

---

## CORRECTION MINIMALE UNIQUE

**Fichier**: `smart_whiteboard_provider.dart`
**Ligne**: 546-552

### Code corrigé

```dart
if (response != null) {
  print("DEBUG-D19-28: loadProjects BEFORE CAST response.runtimeType=${response.runtimeType}");
  if (response is Map<String, dynamic> && response['success'] == true) {
    _projects = response['projects'] as List<dynamic>? ?? [];
  } else {
    _projects = [];
  }
  print("DEBUG-D19-29: loadProjects AFTER CAST _projects=$_projects runtimeType=${_projects.runtimeType} length=${_projects.length}");
} else {
  _projects = [];
}
```

### Différence

- **Avant**: `_projects = response as List<dynamic>;`
- **Après**: Vérifier si `response` est un `Map`, extraire la clé `projects`, caster en `List<dynamic>?`, fallback à `[]`

---

## POURQUOI C'EST LA CORRECTION MINIMALE

1. **Une seule ligne modifiée**: Ligne 548
2. **Un seul bug corrigé**: Le cast incorrect de `whiteboard_list_projects`
3. **Pas de modification SQL**: Aucune modification de Supabase
4. **Pas de modification Edge Function**: Aucune modification de l'Edge Function
5. **Pas de modification Kamatera**: Aucune modification de Kamatera
6. **Compatible avec tous les contrats D.18.1**: Le contrat SQL est `{success: true, projects: [...]}`

---

## VALIDATION

Après correction:
- `response` est `_Map<String, dynamic>` ✅
- `response['success']` est `true` ✅
- `response['projects']` est `List<dynamic>` ✅
- `_projects` devient `List<dynamic>` ✅
- Le cast réussit ✅

---

## NOTE IMPORTANTE

Cette correction est **proposée uniquement** pour la mission D.19.
Elle n'est **PAS appliquée** conformément à l'interdiction formelle de la mission D.19.

L'utilisateur doit décider d'appliquer ou non cette correction.
