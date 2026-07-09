# D.23 – PHASE 6 : PLAN DE CORRECTION MINIMAL

**Date** : 2026-06-28  
**Statut** : PROPOSÉ UNIQUEMENT — AUCUNE MODIFICATION APPLIQUÉE  
**Condition** : La cause racine est CONFIRMÉE (d23_root_cause_validation.md)

---

## FIX #1 — Cause racine principale

### Fichier

```
academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart
```

### Localisation exacte

```
Ligne 101-103 (état actuel)
```

### Code actuel (état réel)

```dart
      if (result['success'] == true) {
        _currentProjectId = result['project_id'] as String;
        print("DEBUG-D19-05: createProject _currentProjectId=$_currentProjectId");
        _setState(SmartWhiteboardState.idle);
```

### Code corrigé

```dart
      if (result['success'] == true) {
        _currentProjectId = result['project_id'] as String;
        _currentProject = WhiteboardProject(
          id: _currentProjectId!,
          subject: subject,
          rendererId: rendererId,
          themeId: themeId,
          narrationMode: narrationMode,
          storyboardJson: const {},
        );
        print("DEBUG-D19-05: createProject _currentProjectId=$_currentProjectId");
        _setState(SmartWhiteboardState.idle);
```

### Métriques du fix

| Métrique | Valeur |
|---------|--------|
| **Lignes ajoutées** | 7 |
| **Lignes supprimées** | 0 |
| **Lignes modifiées** | 0 |
| **Fichiers modifiés** | 1 |
| **Imports à ajouter** | 0 (WhiteboardProject déjà importé via storyboard_models.dart) |
| **Tests à exécuter** | flutter run → créer projet → vérifier D19-06 subject≠"" |

---

## FIX #2 — `whiteboard_get_render_status` SQL 42703 (rupture indépendante)

### Problème

La RPC SQL référence `wr.file_size_bytes` mais la colonne n'existe pas dans `whiteboard_renders`.

### Fichier

```
Supabase SQL — function public.whiteboard_get_render_status
```

### Correction minimale (SQL)

Supprimer la ligne `wr.file_size_bytes,` du SELECT dans le corps de la fonction, ou ajouter la colonne manquante à la table.

**Option A** — Retirer la colonne du SELECT (1 ligne supprimée dans la fonction SQL) :
```sql
-- Retirer cette ligne du SELECT :
wr.file_size_bytes,
```

**Option B** — Ajouter la colonne à la table (1 ALTER TABLE) :
```sql
ALTER TABLE app.whiteboard_renders ADD COLUMN file_size_bytes bigint;
```

**Option recommandée** : Option A — plus simple, moins risquée, la valeur n'est probablement pas utilisée par Flutter actuellement.

### Métriques du fix #2

| Métrique | Valeur |
|---------|--------|
| **Lignes supprimées** | 1 (dans le corps SQL de la RPC) |
| **Fichiers modifiés** | 0 Flutter, 1 migration SQL Supabase |
| **Méthode** | Via toolchain `.windsurf` / `execute_ddl` |

---

## RISQUES

| Fix | Risque | Niveau | Mitigation |
|-----|--------|--------|------------|
| Fix #1 | `WhiteboardProject` constructeur incompatible (champs manquants/renommés) | 🟡 FAIBLE | Vérifier le constructeur dans `storyboard_models.dart` avant d'appliquer |
| Fix #1 | `storyboardJson: const {}` vs `{}` selon le type attendu | 🟢 MINIMAL | Utiliser `<String, dynamic>{}` si nécessaire |
| Fix #2 | La colonne `file_size_bytes` est peut-être utilisée ailleurs | 🟢 MINIMAL | grep du codebase avant de décider Option A vs B |

---

## DÉPENDANCES

### Fix #1 dépend de

- `WhiteboardProject` étant importable dans le provider ✅ (import déjà présent via `storyboard_models.dart`)
- Les paramètres `subject`, `rendererId`, `themeId`, `narrationMode` étant dans le scope de `createProject()` ✅ (ce sont les paramètres requis de la méthode, lignes 79-82)

### Fix #2 dépend de

- Rien côté Flutter
- Accès Supabase SQL via toolchain `.windsurf`

---

## ORDRE D'APPLICATION RECOMMANDÉ

```
1. Fix #1 (Flutter provider) — 7 lignes — résout la cause racine
2. Vérification via flutter run + device → D19-06 subject≠"" attendu
3. Fix #2 (SQL Supabase) — 1 ligne SQL — résout rupture phase rendu
4. Vérification via d21_supabase_rpc_proof.py → HTTP 200 sur whiteboard_get_render_status
```

---

## IMPACT ATTENDU APRÈS CORRECTION

| Champ | Avant fix | Après fix |
|-------|-----------|-----------|
| `subject` dans Edge Fn | `""` | `"dérivés d'une fonction"` |
| `renderer` dans Edge Fn | `"scientific"` | `"notebook"` |
| `theme` dans Edge Fn | `"scientific"` | `"notebook"` |
| `narration_mode` dans Edge Fn | `"none"` | `"tts"` |
| Storyboard IA | Sur "Lois de Newton" | Sur "dérivées d'une fonction" |
| `whiteboard_get_render_status` | HTTP 400 | HTTP 200 |
| Pipeline complet | Bloqué à l'IA | Peut atteindre Kamatera |

---

**DOCUMENT CLÔTURÉ** — AUCUNE MODIFICATION APPLIQUÉE. Plan proposé uniquement.
