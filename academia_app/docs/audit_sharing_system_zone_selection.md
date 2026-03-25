# Audit du Système de Partage - Sélection de Zone
**Date:** 24 Mars 2026  
**Objectif:** Auditer le système de partage existant et implémenter la sélection de zone pour le partage ciblé

## 📋 État Actuel du Système de Partage

### Architecture Existante

Le système de partage est déjà bien implémenté avec une architecture modulaire :

**Services de Base (`lib/features/share/`)**
- `ShareService` : Orchestrateur principal pour les captures d'écran et partage
- `ScreenshotService` : Service de capture via `RepaintBoundary` avec qualité 3.0 pixel ratio
- `ShareModeProvider` : Provider global gérant l'état de partage avec signature automatique

**Intégration dans les Écrans**
- **TD (`student_td_root_screen.dart`)** : 3 options de partage
  - Vue complète de l'espace TD
  - Carte "Mes TD actifs" (cartes personnalisées)  
  - Carte prochaine séance TD
- **Concours (`student_prep_concours_screen.dart`)** : 1 option
  - Vue complète Prépa Concours

### Fonctionnalités Existantes ✅

1. **Partage complet d'écran** : Capture tout l'écran via `RepaintBoundary`
2. **Partage de cartes personnalisées** : Génération de cartes dédiées au partage
3. **Mode partage** : Interface simplifiée lors de la capture (masquage UI, signature)
4. **Signature automatique** : Branding Academia sur tous les partages
5. **Support multi-plateforme** : iOS/Android (image) + Web (texte fallback)
6. **Intégration native** : Utilisation de `share_plus` pour le partage système

### Code Architecture
```dart
// Flux de partage actuel
_shareService.shareCurrentView(
  context: context,
  boundaryKey: _shareBoundaryKey, // RepaintBoundary global
  shareText: "Texte de partage"
);

// Ou partage de carte personnalisée
_shareService.shareCustomCard(
  context: context,
  card: CustomWidget(),
  shareText: "Texte de partage"
);
```

## 🎯 Objectif : Sélection de Zone

### Fonctionnalité Demandée
Permettre à l'utilisateur de :
1. **Choisir entre partage complet** ou **sélection de zone**
2. **Sélectionner visuellement** une zone de l'écran à partager
3. **Prévisualiser** la zone sélectionnée avant partage
4. **Cas d'usage** : Partager une question spécifique d'un écran Congo

## 🔧 Plan d'Implémentation

### Phase 1: Extension du ShareService
- Ajouter `shareSelectedZone()` method
- Intégrer un widget de sélection de zone interactif
- Gérer les coordonnées de crop

### Phase 2: Widget de Sélection
- `ZoneSelector` : Widget overlay avec sélection rectangulaire
- Gestion des gestes (pan, resize)
- Prévisualisation temps réel

### Phase 3: Intégration UI
- Nouveau modal de choix : "Partage complet" vs "Sélection de zone"
- Boutons d'action dans les écrans TD et Concours

### Phase 4: Capture et Crop
- Extension de `ScreenshotService` pour le crop
- Calcul des coordonnées relatives
- Maintien de la qualité d'image

## 🚀 Implémentation Recommandée

### 1. Extension ShareService
```dart
Future<void> shareSelectedZone({
  required BuildContext context,
  required GlobalKey boundaryKey,
  required Rect selectionRect,
  String? shareText,
})
```

### 2. Widget ZoneSelector
```dart
class ZoneSelector extends StatefulWidget {
  final Widget child;
  final Function(Rect) onSelectionChanged;
}
```

### 3. Modification des Modals
Remplacer les modals actuels par un choix :
- "🖼️ Partage complet"
- "✂️ Sélection de zone"

## 📊 Évaluation de Faisabilité

**✅ Avantages**
- Architecture existante solide et extensible
- Services de capture déjà fonctionnels
- UI patterns cohérents établis

**⚠️ Défis Techniques**
- Calcul précis des coordonnées de crop
- Gestion des différentes résolutions d'écran
- UX intuitive pour la sélection

**⏱️ Estimation**
- **Développement** : 2-3 jours
- **Test et polish** : 1 jour  
- **Total** : 3-4 jours

## 🎨 Maquette UX Proposée

```
[Bouton Partager] → 
Modal "Options de Partage":
├── 🖼️ Partage complet (existant)
└── ✂️ Sélection de zone (nouveau)
    └── Overlay de sélection interactive
        └── Prévisualisation + Partager
```

## 📝 Prochaines Étapes

1. ✅ Audit complet terminé
2. 🔄 Implémentation ZoneSelector widget
3. 🔄 Extension ShareService avec crop
4. 🔄 Intégration dans TD et Concours screens
5. 🔄 Tests et validation

---
*Rapport généré automatiquement par l'audit du système de partage Academia*
