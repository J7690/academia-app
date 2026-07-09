# D.17.1 – PHASE 4: PREMIER BUG RÉEL DÉMONTRÉ

**Date**: 2026-06-26
**Mission**: D.17.1

---

## BUG IDENTIFIÉ

**Fichier**: `academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart`
**Ligne**: 531
**Code fautif**:
```dart
final response = await client.rpc('whiteboard_list_projects');

if (response != null) {
  _projects = response as List<dynamic>;
} else {
  _projects = [];
}
```

---

## PREUVE DU JSON RÉEL

**Source SQL**: `.windsurf/create_missing_flutter_rpcs.sql:208-211`

```sql
result := jsonb_build_object(
  'success', true,
  'projects', COALESCE(projects, '[]'::jsonb)
);
```

**JSON réellement renvoyé**:
```json
{
  "success": true,
  "projects": [
    { "id": "...", "subject": "...", ... }
  ]
}
```

**Type réel**: `Map<String, dynamic>` (`_Map<String, dynamic>`)

---

## PREUVE DU CODE FLUTTER

**Fichier**: `academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:531-534`

```dart
_projects = response as List<dynamic>;
```

**Type attendu**: `List<dynamic>`

---

## MISMATCH

| Élément | Valeur |
|---------|--------|
| JSON réel | `Map<String, dynamic>` avec clé `projects` |
| Type réel | `_Map<String, dynamic>` |
| Flutter attend | `List<dynamic>` |
| Code fautif | `response as List<dynamic>` |

---

## ERREUR PROVOQUÉE

Lorsque `loadProjects()` est appelé (par exemple au chargement de la liste des projets Smart Whiteboard), l'exécution de:

```dart
_projects = response as List<dynamic>;
```

produira l'exception Dart:

```
type '_Map<String, dynamic>' is not a subtype of type 'List<dynamic>' in type cast
```

---

## CONSÉQUENCE

L'écran `smart_whiteboard_projects_list_screen.dart` ne peut pas charger la liste des projets. Le provider passe en état `error` avec le message d'exception.

---

## CORRECTION ATTENDUE (non appliquée)

```dart
final response = await client.rpc('whiteboard_list_projects');
if (response != null) {
  final data = response as Map<String, dynamic>;
  _projects = data['projects'] as List<dynamic>? ?? [];
} else {
  _projects = [];
}
```

---

## CONCLUSION

**Premier bug réel démontré**: cast incorrect de `whiteboard_list_projects` dans `smart_whiteboard_provider.dart:531`.

- La RPC retourne un `Map<String, dynamic>` avec la clé `projects`.
- Le Flutter tente de caster directement la réponse en `List<dynamic>`.
- Cela provoque une exception de type Dart.

Aucune hypothèse. La preuve est dans le code SQL et le code Flutter.
