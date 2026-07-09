# D.18 – PHASE 6: PREMIER MISMATCH GLOBAL

**Date**: 2026-06-26
**Mission**: D.18

---

## RÉSULTAT DE L'AUDIT

Après analyse complète du câblage exécutable:

```
Flutter → Supabase → Edge Function → OpenRouter → Supabase → Worker → Kamatera/Storage → Flutter
```

Le **premier mismatch global démontré** est:

---

## MISMATCH: `whiteboard_list_projects` – Type de retour

### Fichier

`academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`

### Ligne

531

### Code Flutter

```dart
@academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:523-534
Future<void> loadProjects() async {
  _setState(SmartWhiteboardState.loading);
  try {
    final client = _supabase;
    final response = await client.rpc('whiteboard_list_projects');

    if (response != null) {
      _projects = response as List<dynamic>;
    } else {
      _projects = [];
    }
    ...
  } catch (e) {
    _setError(e.toString());
  }
}
```

### JSON réel (SQL source)

```sql
@.windsurf/create_missing_flutter_rpcs.sql:208-211
result := jsonb_build_object(
  'success', true,
  'projects', COALESCE(projects, '[]'::jsonb)
);
```

### JSON réel final

```json
{
  "success": true,
  "projects": [
    { "id": "...", "subject": "...", "status": "..." }
  ]
}
```

### Type réel

`_Map<String, dynamic>`

### Type attendu par Flutter

`List<dynamic>`

### Erreur provoquée

```text
type '_Map<String, dynamic>' is not a subtype of type 'List<dynamic>' in type cast
```

### Conséquence

L'écran de liste des projets Smart Whiteboard ne peut pas charger. Le provider passe en état d'erreur et affiche le message d'exception.

---

## POURQUOI C'EST LE PREMIER

### Ordre d'exécution du pipeline

1. **Création du projet** (`whiteboard_create_project`) → ✅ MATCH
2. **Génération du storyboard** (`whiteboard-generate-storyboard`) → ✅ MATCH
3. **Liste des projets** (`whiteboard_list_projects`) → ❌ MISMATCH

La liste des projets est accessible depuis la navigation principale. Si l'utilisateur accède à l'écran "Mes projets" avant ou après la création, le crash se produit.

### Autres candidats écartés

- `whiteboard_create_project` → ✅ cohérent
- `whiteboard_create_render_job` → ✅ cohérent
- `whiteboard_get_render_status` → ✅ cohérent
- `whiteboard-generate-storyboard` → ✅ cohérent
- Upload média → pas de MISMATCH démontré dans le code Flutter
- Kamatera → non utilisé par Smart Whiteboard

---

## PREUVES

### Preuve Flutter

```dart
@academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:531
_projects = response as List<dynamic>;
```

### Preuve Supabase

```sql
@.windsurf/create_missing_flutter_rpcs.sql:178-215
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

Le premier mismatch global démontré dans le système complet est le cast incorrect de `whiteboard_list_projects` dans Flutter.

Aucune modification n'a été appliquée.
