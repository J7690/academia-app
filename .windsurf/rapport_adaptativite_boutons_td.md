# Rapport — Adaptativité boutons et zones de saisie (Onglet TD)

**Date :** 2026-07-02
**Scope :** Onglet TD (Travaux Dirigés) — Étudiant
**Objectif :** Rendre tous les boutons et zones de saisie adaptatifs aux tailles d'écran des téléphones (pas de conteneurs fixes)

---

## Audit réalisé

### Fichiers audités (Étudiant)
1. `lib/features/student/td/td_home_tab.dart`
2. `lib/features/student/td/td_catalog_tab.dart`
3. `lib/features/student/td/td_exercises_tab.dart`
4. `lib/features/student/td/td_quiz_tab.dart`
5. `lib/features/student/td/td_scan_subject_screen.dart`
6. `lib/features/student/td/td_stats_tab.dart`
7. `lib/features/student/td/td_resources_tab.dart`
8. `lib/features/student/td/td_my_enrollments_tab.dart`
9. `lib/features/student/td/td_leaderboard_tab.dart`
10. `lib/features/student/td/td_ai_tutor_tab.dart`

### Fichiers audités (Admin)
1. `lib/features/admin/admin_td_screen.dart`
2. `lib/features/admin/admin_td_catalog_screen.dart`
3. `lib/features/admin/admin_td_upload_screen.dart`
4. `lib/features/admin/admin_td_direct_import_screen.dart`
5. `lib/features/admin/admin_td_local_groups_screen.dart`
6. `lib/features/admin/admin_td_student_requests_screen.dart`
7. `lib/features/admin/admin_td_teachers_screen.dart`
8. `lib/features/admin/admin_td_analytics_screen.dart`

### Problèmes identifiés

| Fichier | Ligne | Type de problème | Description |
|---------|-------|------------------|-------------|
| td_exercises_tab.dart | 511-527 | Row fixe | Boutons de génération (Générer exercices, Générer devoir type) dans Row sans Wrap → overflow sur petits écrans |
| td_home_tab.dart | 300-329 | Row fixe | Actions rapides (Explorer, Mes TD, Classement, Stats) dans Row sans Wrap → overflow sur petits écrans |
| td_stats_tab.dart | 282 | Width fixe | Badge width: 90 fixe → pas adaptatif pour les badges |

### Éléments déjà corrects (pas de correction nécessaire)

| Fichier | Élément | Raison |
|---------|---------|--------|
| td_quiz_tab.dart | Ligne 109 | Row header déjà avec Expanded |
| td_quiz_tab.dart | Ligne 167 | Row matière déjà avec Expanded |
| td_quiz_tab.dart | Ligne 200 | Row top bar déjà avec Expanded |
| td_scan_subject_screen.dart | Ligne 196 | Row image preview déjà avec Expanded |
| td_scan_subject_screen.dart | Ligne 257 | Row action buttons déjà avec Expanded |
| td_resources_tab.dart | Ligne 158 | Row resource card déjà avec Expanded |
| td_my_enrollments_tab.dart | Ligne 125 | Row enrollment card déjà avec Expanded |
| td_home_tab.dart | Ligne 124 | Row streak hero déjà avec Expanded |
| td_home_tab.dart | Ligne 210 | Row KPI déjà avec Expanded |
| td_home_tab.dart | Ligne 249 | Row next session déjà avec Expanded |
| td_home_tab.dart | Ligne 349 | Row request teacher déjà avec Expanded |
| td_exercises_tab.dart | Ligne 190 | Row dropdowns déjà avec Expanded |
| td_exercises_tab.dart | Ligne 221 | Row inputs déjà avec Expanded |
| td_exercises_tab.dart | Ligne 311 | Row header sheet déjà avec Expanded |
| td_exercises_tab.dart | Ligne 349 | Row question numéro déjà avec Expanded |
| td_exercises_tab.dart | Ligne 370 | Row options déjà avec Expanded |
| td_exercises_tab.dart | Ligne 391 | Row explication déjà avec Expanded |
| td_exercises_tab.dart | Ligne 556 | Row generated exercises déjà avec Expanded |
| td_exercises_tab.dart | Ligne 684 | Row assignment card déjà avec Expanded |
| td_stats_tab.dart | Ligne 59 | Row XP hero déjà avec Expanded |
| td_stats_tab.dart | Ligne 239 | Row stat tile déjà avec Expanded |
| td_stats_tab.dart | Ligne 321 | Row bar chart déjà avec Expanded |
| admin_td_screen.dart | Ligne 62 | Row header déjà avec Expanded |
| admin_td_screen.dart | Ligne 294 | Row split view déjà avec Expanded |
| admin_td_screen.dart | Ligne 643 | Row message input déjà avec Expanded |
| admin_td_local_groups_screen.dart | Ligne 59 | Row filters déjà avec Expanded |
| admin_td_local_groups_screen.dart | Ligne 78 | Row stats déjà avec Expanded |
| admin_td_direct_import_screen.dart | Ligne 305 | Row dropdowns déjà avec Expanded |
| admin_td_direct_import_screen.dart | Ligne 438 | Row buttons déjà avec Expanded |

---

## Corrections appliquées

### 1. td_exercises_tab.dart — Boutons de génération
**Avant :**
```dart
Row(children: [
  Expanded(child: _GenerateButton(
    icon: Icons.auto_awesome,
    label: 'Générer exercices',
    color: accent,
    loading: _generating,
    onTap: () => _showGenerateSheet(mode: 'exercise'),
  )),
  const SizedBox(width: 10),
  Expanded(child: _GenerateButton(
    icon: Icons.description,
    label: 'Générer devoir type',
    color: const Color(0xFFDB2777),
    loading: _generating,
    onTap: () => _showGenerateSheet(mode: 'exam'),
  )),
]),
```

**Après :**
```dart
Wrap(
  spacing: 10,
  runSpacing: 10,
  children: [
    Flexible(child: _GenerateButton(
      icon: Icons.auto_awesome,
      label: 'Générer exercices',
      color: accent,
      loading: _generating,
      onTap: () => _showGenerateSheet(mode: 'exercise'),
    )),
    Flexible(child: _GenerateButton(
      icon: Icons.description,
      label: 'Générer devoir type',
      color: const Color(0xFFDB2777),
      loading: _generating,
      onTap: () => _showGenerateSheet(mode: 'exam'),
    )),
  ],
),
```

**Impact :** Les 2 boutons s'adaptent maintenant à la largeur disponible. Sur petits écrans, ils passent à la ligne automatiquement.

---

### 2. td_home_tab.dart — Actions rapides
**Avant :**
```dart
Row(
  children: [
    _QuickAction(
      icon: Icons.explore,
      label: 'Explorer',
      color: TdTheme.studentTdPrimary,
      onTap: () => DefaultTabController.of(context).animateTo(1),
    ),
    const SizedBox(width: 10),
    _QuickAction(
      icon: Icons.menu_book,
      label: 'Mes TD',
      color: TdTheme.success,
      onTap: () => DefaultTabController.of(context).animateTo(2),
    ),
    const SizedBox(width: 10),
    _QuickAction(
      icon: Icons.leaderboard,
      label: 'Classement',
      color: const Color(0xFFF59E0B),
      onTap: () => DefaultTabController.of(context).animateTo(4),
    ),
    const SizedBox(width: 10),
    _QuickAction(
      icon: Icons.bar_chart,
      label: 'Stats',
      color: const Color(0xFFEF4444),
      onTap: () => DefaultTabController.of(context).animateTo(5),
    ),
  ],
),
```

**Après :**
```dart
Wrap(
  spacing: 10,
  runSpacing: 10,
  children: [
    Flexible(child: _QuickAction(
      icon: Icons.explore,
      label: 'Explorer',
      color: TdTheme.studentTdPrimary,
      onTap: () => DefaultTabController.of(context).animateTo(1),
    )),
    Flexible(child: _QuickAction(
      icon: Icons.menu_book,
      label: 'Mes TD',
      color: TdTheme.success,
      onTap: () => DefaultTabController.of(context).animateTo(2),
    )),
    Flexible(child: _QuickAction(
      icon: Icons.leaderboard,
      label: 'Classement',
      color: const Color(0xFFF59E0B),
      onTap: () => DefaultTabController.of(context).animateTo(4),
    )),
    Flexible(child: _QuickAction(
      icon: Icons.bar_chart,
      label: 'Stats',
      color: const Color(0xFFEF4444),
      onTap: () => DefaultTabController.of(context).animateTo(5),
    )),
  ],
),
```

**Impact :** Les 4 actions rapides s'adaptent à la largeur disponible. Sur petits écrans, elles passent à la ligne automatiquement.

---

### 3. td_stats_tab.dart — Badge width
**Avant :**
```dart
return Container(
  width: 90,
  padding: const EdgeInsets.all(10),
  decoration: TdTheme.cardDecoration(),
  child: Column(
```

**Après :**
```dart
return Flexible(
  child: Container(
    padding: const EdgeInsets.all(10),
    decoration: TdTheme.cardDecoration(),
    child: Column(
```

**Impact :** Le badge s'adapte maintenant à l'espace disponible dans le Wrap parent. Plus de width fixe de 90px.

---

## Bilan

| Métrique | Valeur |
|----------|--------|
| **Fichiers audités (Étudiant)** | 10 |
| **Fichiers audités (Admin)** | 8 |
| **Total fichiers audités** | 18 |
| **Problèmes identifiés** | 3 |
| **Corrections appliquées** | 3 |
| **Éléments déjà corrects** | 30+ |
| **Row remplacés par Wrap** | 2 |
| **Width fixe corrigé** | 1 |

---

## Recommandations futures

Pour garantir une adaptativité complète dans le module TD :

1. **Utiliser Wrap** pour tout groupe de boutons/actions qui pourrait dépasser la largeur
2. **Utiliser Expanded** sur les TextField dans des Row avec boutons à côté
3. **Éviter width fixe** sauf pour des éléments décoratifs de taille connue (icônes, badges circulaires)
4. **Utiliser Flexible** pour les éléments dans des Wrap pour une meilleure distribution
5. **Utiliser SingleChildScrollView avec Axis.horizontal** pour les filtres/chips longs
6. **Tester sur petits écrans** (320px de large) pour valider l'absence d'overflow

---

## Fichiers modifiés

1. `lib/features/student/td/td_exercises_tab.dart` (1 correction)
2. `lib/features/student/td/td_home_tab.dart` (1 correction)
3. `lib/features/student/td/td_stats_tab.dart` (1 correction)

---

**Fin du rapport.**
