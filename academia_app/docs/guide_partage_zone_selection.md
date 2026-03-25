# Guide d'utilisation - Partage avec Sélection de Zone
**Date de création:** 24 Mars 2026  
**Module:** Système de partage avancé Academia

## 🎯 Fonctionnalité : Sélection de Zone pour le Partage

### Vue d'ensemble
La nouvelle fonctionnalité de sélection de zone permet aux utilisateurs de :
- **Partager une portion spécifique** de l'écran au lieu de tout l'écran
- **Sélectionner interactivement** la zone à partager
- **Prévisualiser** la sélection avant partage
- **Partager des éléments ciblés** comme une question de quiz, un TD spécifique, etc.

## 📱 Comment utiliser la sélection de zone

### 1. Accéder aux options de partage

#### Dans l'onglet TD (Travaux Dirigés)
1. Naviguez vers l'onglet TD
2. Cliquez sur l'icône de partage en haut à droite
3. Le modal affiche maintenant **3 options principales** :
   - 🌐 **Vue complète** : Capture tout l'écran
   - ✂️ **Sélection de zone** : NOUVELLE option pour sélectionner une zone
   - 📊 **Cartes personnalisées** : Cartes pré-formatées

#### Dans l'onglet Concours (Préparation Concours)
1. Naviguez vers l'onglet Concours
2. Cliquez sur l'icône de partage
3. Choisissez entre :
   - 🌐 **Vue complète Prépa Concours**
   - ✂️ **Sélection de zone** : Pour partager une question spécifique

### 2. Utiliser la sélection de zone

Lorsque vous choisissez "Sélection de zone" :

1. **Interface de sélection**
   - Un overlay semi-transparent apparaît
   - Une zone de sélection rectangle est visible
   - Les dimensions sont affichées au centre

2. **Actions disponibles**
   - **Déplacer** : Touchez et glissez la zone
   - **Redimensionner** : Utilisez les 8 poignées (coins + milieux)
   - **Dimensions** : Affichées en temps réel (largeur × hauteur)

3. **Boutons d'action**
   - ❌ **Annuler** : Ferme sans partager
   - 📤 **Partager la sélection** : Confirme et partage

### 3. Exemples d'utilisation

#### Cas 1 : Partager une question spécifique du quiz
```
1. Ouvrir l'onglet Concours > Quiz
2. Cliquer sur Partager > Sélection de zone
3. Ajuster le rectangle autour de la question
4. Partager → La question est partagée avec le branding Academia
```

#### Cas 2 : Partager un TD actif
```
1. Ouvrir l'onglet TD > Mes TD
2. Cliquer sur Partager > Sélection de zone
3. Sélectionner le TD voulu dans la liste
4. Partager → Seul ce TD est visible dans l'image
```

#### Cas 3 : Partager une zone de statistiques
```
1. Ouvrir l'onglet Stats
2. Partager > Sélection de zone
3. Cadrer sur le graphique pertinent
4. Partager → Graphique isolé avec signature Academia
```

## 🎨 Interface utilisateur

### Écran de sélection
```
┌─────────────────────────────────────┐
│  [Annuler]        [Partager la sél.] │
│                                      │
│  ╔═══════════════════════════════╗  │
│  ║                               ║  │
│  ║     Zone sélectionnée        ║  │
│  ║     [200 × 150]              ║  │
│  ║                               ║  │
│  ╚═══════════════════════════════╝  │
│                                      │
│  🎯 Instructions:                    │
│  • Touchez et glissez               │
│  • Utilisez les poignées            │
└─────────────────────────────────────┘
```

### Poignées de redimensionnement
- **8 poignées** : 4 coins + 4 milieux
- **Feedback visuel** : Cercles bleus avec bordure blanche
- **Zone minimum** : 50×50 pixels

## 🔧 Architecture technique

### Nouveaux composants
1. **`ZoneSelector`** : Widget de sélection interactive
2. **`ScreenshotService.captureRepaintBoundaryWithCrop()`** : Capture avec crop
3. **`ShareService.shareSelectedZone()`** : Orchestrateur du partage de zone

### Flux de données
```
User → Modal → shareSelectedZone() → ZoneSelector
  ↓
Sélection → captureRepaintBoundaryWithCrop() → PNG cropé
  ↓
share_plus → Partage natif (iOS/Android/Web)
```

## ✅ Points forts de l'implémentation

- **Qualité d'image** : Ratio 3.0 pour des captures nettes
- **Signature automatique** : Branding Academia sur tous les partages
- **UX intuitive** : Gestes naturels (drag & resize)
- **Performance** : Crop côté client, pas de serveur requis
- **Cross-platform** : Fonctionne sur iOS, Android et Web

## 📋 Checklist de validation

- [x] Sélection de zone interactive
- [x] Prévisualisation en temps réel
- [x] Redimensionnement par poignées
- [x] Déplacement par glisser-déposer
- [x] Affichage des dimensions
- [x] Capture et crop de la zone
- [x] Partage via système natif
- [x] Signature Academia intégrée
- [x] Support multi-plateforme

## 🚀 Prochaines améliorations possibles

1. **Formes de sélection** : Cercle, forme libre
2. **Annotations** : Ajouter texte ou flèches
3. **Templates** : Zones pré-définies pour cas courants
4. **Multi-sélection** : Plusieurs zones dans une image
5. **Historique** : Sauvegarder les dernières sélections

---
*Guide généré pour l'équipe Academia - Module de partage avancé avec sélection de zone*
