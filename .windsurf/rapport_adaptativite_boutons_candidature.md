# Rapport — Adaptativité boutons et zones de saisie (Candidature)

**Date :** 2026-07-02
**Scope :** Écrans de candidature (onglet "Candidature" et sous-onglet "Détail de candidature")
**Objectif :** Rendre tous les boutons et zones de saisie adaptatifs aux tailles d'écran des téléphones (pas de conteneurs fixes)

---

## Audit réalisé

### Fichiers audités
1. `lib/features/admin/admin_application_detail_screen.dart`
2. `lib/features/student/student_application_detail_screen.dart`
3. `lib/features/university/university_application_detail_screen.dart`
4. `lib/features/admin/admin_applications_screen.dart`
5. `lib/features/university/university_applications_screen.dart`

### Problèmes identifiés

| Fichier | Ligne | Type de problème | Description |
|---------|-------|------------------|-------------|
| admin_application_detail_screen.dart | 318-420 | Row fixe | Boutons de paiement (Valider, Rejeter, Confirmer + reçu) dans Row sans Wrap → overflow sur petits écrans |
| admin_application_detail_screen.dart | 491-544 | Row fixe | Boutons de préférences (Modifier, Transmettre) dans Row sans Wrap → overflow sur petits écrans |
| student_application_detail_screen.dart | 428 | Width fixe | SizedBox(width: 68) pour BobodoView → inutilement large, pas adaptatif |

### Éléments déjà corrects (pas de correction nécessaire)

| Fichier | Élément | Raison |
|---------|---------|--------|
| university_application_detail_screen.dart | Ligne 776 | Boutons de statut déjà en Wrap |
| university_application_detail_screen.dart | Ligne 577 | TextField message déjà avec Expanded |
| student_application_detail_screen.dart | Ligne 1007 | TextField message déjà avec Expanded |
| admin_application_detail_screen.dart | Ligne 644 | TextField message déjà avec Expanded |
| admin_applications_screen.dart | Ligne 141 | Chips déjà en Wrap |
| university_applications_screen.dart | Ligne 141 | Chips déjà en Wrap |
| university_applications_screen.dart | Ligne 259 | Filtres en Row avec SingleChildScrollView horizontal |

---

## Corrections appliquées

### 1. admin_application_detail_screen.dart — Boutons de paiement
**Avant :**
```dart
Row(
  children: [
    OutlinedButton.icon(...),
    const SizedBox(width: 8),
    OutlinedButton.icon(...),
    const SizedBox(width: 8),
    ElevatedButton.icon(...),
  ],
)
```

**Après :**
```dart
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    OutlinedButton.icon(...),
    OutlinedButton.icon(...),
    ElevatedButton.icon(...),
  ],
)
```

**Impact :** Les 3 boutons s'adaptent maintenant à la largeur disponible. Sur petits écrans, ils passent à la ligne automatiquement.

---

### 2. admin_application_detail_screen.dart — Boutons de préférences
**Avant :**
```dart
Row(
  children: [
    TextButton.icon(...),
    const SizedBox(width: 8),
    if (!sentToUniversity)
      ElevatedButton.icon(...),
  ],
)
```

**Après :**
```dart
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    TextButton.icon(...),
    if (!sentToUniversity)
      ElevatedButton.icon(...),
  ],
)
```

**Impact :** Les boutons s'adaptent à la largeur disponible.

---

### 3. student_application_detail_screen.dart — BobodoView width
**Avant :**
```dart
SizedBox(
  width: 68,
  child: BobodoView(
    state: bobodoState,
    size: 56,
    text: bobodoText,
  ),
)
```

**Après :**
```dart
SizedBox(
  width: 56,
  child: BobodoView(
    state: bobodoState,
    size: 56,
    text: bobodoText,
  ),
)
```

**Impact :** Le conteneur est maintenant aligné sur la taille du widget (56px), évitant un espace inutile de 12px sur la gauche.

---

## Bilan

| Métrique | Valeur |
|----------|--------|
| **Fichiers audités** | 5 |
| **Problèmes identifiés** | 3 |
| **Corrections appliquées** | 3 |
| **Éléments déjà corrects** | 8+ |
| **Row remplacés par Wrap** | 2 |
| **Width fixe corrigé** | 1 |

---

## Recommandations futures

Pour garantir une adaptativité complète dans toute l'application :

1. **Utiliser Wrap** pour tout groupe de boutons/actions qui pourrait dépasser la largeur
2. **Utiliser Expanded** sur les TextField dans des Row avec boutons à côté
3. **Éviter width fixe** sauf pour des éléments décoratifs de taille connue (icônes, badges)
4. **Utiliser SingleChildScrollView avec Axis.horizontal** pour les filtres/chips longs
5. **Tester sur petits écrans** (320px de large) pour valider l'absence d'overflow

---

## Fichiers modifiés

1. `lib/features/admin/admin_application_detail_screen.dart` (2 corrections)
2. `lib/features/student/student_application_detail_screen.dart` (1 correction)

---

**Fin du rapport.**
