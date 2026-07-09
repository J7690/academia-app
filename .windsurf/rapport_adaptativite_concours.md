# Rapport d'Adaptativité - Onglet Concours

**Date**: 20 avril 2026  
**Objectif**: Identifier et corriger tous les problèmes d'overflow et d'adaptativité dans l'onglet "Concours" de l'application Flutter Academia.  
**Contrainte**: Aucune modification de la logique métier, uniquement des corrections UI pour améliorer la responsivité.

---

## Résumé Exécutif

**Fichiers audités**: 8 fichiers Dart liés au module Prépa Concours  
**Corrections appliquées**: 2  
**Problèmes identifiés**: 2  
**Aucun problème critique d'overflow détecté** dans la majorité des écrans. Les widgets utilisent déjà des patterns responsifs (Wrap, Expanded, SingleChildScrollView).

---

## Fichiers Audités

1. `lib/features/student/prep_concours/prep_concours_home_screen.dart`
2. `lib/features/student/prep_concours/prep_sujets_blancs_screen.dart`
3. `lib/features/student/prep_concours/prep_training_screen.dart`
4. `lib/features/student/prep_concours/prep_exam_screen.dart`
5. `lib/features/student/prep_concours/prep_diagnostic_screen.dart`
6. `lib/features/student/prep_concours/prep_sujet_blanc_exam_screen.dart`
7. `lib/features/student/prep/psychotech/prep_psychotech_tab.dart`
8. `lib/features/admin/prep_concours/admin_prep_concours_screen.dart`

---

## Corrections Appliquées

### Correction #1: Indicateurs de Difficulté - Psychotech Tab

**Fichier**: `lib/features/student/prep/psychotech/prep_psychotech_tab.dart`  
**Ligne**: 203  
**Widget**: Container (indicateurs de difficulté)

#### Problème Identifié
```dart
Container(
  margin: const EdgeInsets.only(right: 6),
  width: 28, height: 28,  // Width fixe trop large
  decoration: BoxDecoration(
    color: i < _difficulty ? Colors.white : Colors.white.withAlpha(40),
    borderRadius: BorderRadius.circular(6),
  ),
  ...
)
```

**Cause**: Les indicateurs de difficulté avaient une largeur fixe de 28px, ce qui pouvait causer un overflow sur les très petits écrans lorsque combinés avec le texte "Difficulté : " dans un Row.

#### Solution Appliquée
```dart
Container(
  margin: const EdgeInsets.only(right: 6),
  width: 24, height: 24,  // Width réduit pour meilleure adaptativité
  decoration: BoxDecoration(
    color: i < _difficulty ? Colors.white : Colors.white.withAlpha(40),
    borderRadius: BorderRadius.circular(6),
  ),
  ...
)
```

**Justification**: Réduire la largeur de 28px à 24px permet aux indicateurs de s'adapter plus facilement sur les petits écrans sans affecter la lisibilité. La hauteur a également été ajustée proportionnellement pour maintenir le ratio carré.

**Impact**: Améliore l'adaptativité sur les écrans de petite taille (< 360px de largeur).

---

### Correction #2: AlertDialogs - Admin Prep Concours Screen

**Fichier**: `lib/features/admin/prep_concours/admin_prep_concours_screen.dart`  
**Lignes**: 98-103, 203-208, 316-321, 374-377, 516-519  
**Widget**: SizedBox dans AlertDialog

#### Problème Identifié
```dart
content: SizedBox(
  width: 520,  // Width fixe non adaptatif
  height: 320,
  child: ...
)
```

**Cause**: Tous les AlertDialogs utilisaient une largeur fixe de 520px, ce qui causait un overflow sur les tablettes et mobiles en mode portrait, et ne s'adaptait pas correctement aux différentes tailles d'écran.

#### Solution Appliquée
```dart
content: ConstrainedBox(
  constraints: BoxConstraints(
    maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
    maxHeight: 320,
  ),
  child: ...
)
```

**Justification**: Utiliser `ConstrainedBox` avec `MediaQuery` permet au dialogue de s'adapter à 90% de la largeur de l'écran, garantissant qu'il ne déborde jamais tout en conservant une hauteur maximale raisonnable pour le scroll.

**Dialogues concernés**:
1. `_showEntitlementsDialog()` - Affichage des accès Prépa concours
2. `_showAiUsageSummaryDialog()` - Analytics IA
3. `_showAttemptsSummaryDialog()` - Stats tentatives
4. `_openGenerationDetail()` - Détail génération IA
5. `_openCreateSubjectDialog()` - Création de matière

**Impact**: Les dialogues s'adaptent maintenant correctement sur tous les écrans (mobiles, tablettes, desktop).

---

## Éléments Déjà Responsifs (Aucune Correction Requise)

### 1. Filter Chips - Prep Sujets Blancs Screen
**Fichier**: `lib/features/student/prep_concours/prep_sujets_blancs_screen.dart` (lignes 135-151)

```dart
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: _concoursTypes.entries.map((e) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(...),
      );
    }).toList(),
  ),
)
```

**Analyse**: Les chips de filtre sont déjà dans un `SingleChildScrollView` horizontal, ce qui permet un scroll naturel sur les petits écrans. ✅

### 2. Wrap pour Chips - Prep Sujets Blancs Screen
**Fichier**: `lib/features/student/prep_concours/prep_sujets_blancs_screen.dart` (lignes 312-322)

```dart
Wrap(
  spacing: 8,
  runSpacing: 4,
  children: [
    _chip(Icons.help_outline, '${exam.totalQuestions} questions'),
    _chip(Icons.timer_outlined, '${exam.durationMinutes} min'),
    ...
  ],
)
```

**Analyse**: Les chips d'information utilisent déjà `Wrap` pour s'adapter à la largeur disponible. ✅

### 3. Navigation Dots - Prep Sujet Blanc Exam Screen
**Fichier**: `lib/features/student/prep_concours/prep_sujet_blanc_exam_screen.dart` (lignes 394-445)

```dart
Container(
  height: 36,
  child: ListView.builder(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    itemCount: _questions.length,
    itemBuilder: (ctx, i) {
      return GestureDetector(
        onTap: () => _goToQuestion(i),
        child: Container(
          width: 28,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          ...
        ),
      );
    },
  ),
)
```

**Analyse**: Les points de navigation sont dans un `ListView.builder` horizontal avec scroll, ce qui est déjà adaptatif. ✅

### 4. Bottom Action Bar - Prep Sujet Blanc Exam Screen
**Fichier**: `lib/features/student/prep_concours/prep_sujet_blanc_exam_screen.dart` (lignes 631-653)

```dart
Row(
  children: [
    if (_index > 0)
      OutlinedButton(
        onPressed: () => _goToQuestion(_index - 1),
        child: const Text('Précédent'),
      ),
    const Spacer(),
    if (!_isFinished)
      FilledButton(
        onPressed: _canConfirm ? _confirmAndNext : null,
        child: Text(isLast ? 'Terminer' : 'Suivant'),
      ),
    ...
  ],
)
```

**Analyse**: Utilise `Spacer` pour distribuer l'espace entre les boutons de manière adaptative. ✅

### 5. Wrap pour Boutons d'Action - Prep Exam Screen
**Fichier**: `lib/features/student/prep_concours/prep_exam_screen.dart` (lignes 276-298)

```dart
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    TextButton(
      onPressed: () {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      },
      child: const Text('Fermer'),
    ),
    TextButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PrepProgressScreen(subject: widget.subject),
          ),
        );
      },
      child: const Text('Voir stats'),
    ),
  ],
)
```

**Analyse**: Les boutons d'action en cas d'erreur utilisent déjà `Wrap` pour s'adapter. ✅

### 6. Rows avec Expanded - Tous les écrans
**Analyse**: Tous les écrans utilisent `Expanded` dans les `Row` pour les éléments de contenu principal (titres, badges, etc.), ce qui est le pattern correct pour la responsivité. ✅

---

## Confirmation de Zéro Modification de Logique Métier

**Aucune modification** des éléments suivants :
- Aucun RPC appelé modifié
- Aucun provider modifié
- Aucune structure de données modifiée
- Aucune logique de validation modifiée
- Aucun flux de navigation modifié
- Aucun état métier modifié

**Modifications exclusivement UI** :
- Dimensions de widgets (width, height)
- Conteneurs de layout (SizedBox → ConstrainedBox)
- Contraintes responsives (MediaQuery)

---

## Recommandations Futures

Bien que l'audit n'ait révélé que 2 problèmes mineurs, voici des recommandations pour maintenir l'adaptativité :

1. **Utiliser LayoutBuilder** pour les widgets complexes qui nécessitent des calculs basés sur la largeur disponible
2. **Éviter les dimensions fixes** dans les nouveaux développements (préférer Expanded, Flexible, Wrap)
3. **Tester sur plusieurs tailles d'écran** lors des développements futurs (small: 320px, medium: 375px, large: 414px, tablette: 768px+)
4. **Utiliser FractionallySizedBox** pour les proportions relatives plutôt que des dimensions absolues

---

## Conclusion

L'audit de l'onglet Concours a révélé une architecture UI globalement saine avec une utilisation correcte des widgets responsifs (Wrap, Expanded, SingleChildScrollView). Les 2 corrections mineures appliquées améliorent l'adaptativité sur les très petits écrans et les tablettes.

**Statut**: ✅ Corrections terminées, aucun problème critique d'overflow détecté.
