# Documentation Windsurf

Ce dossier `.windsurf` contient l'ensemble des règles et procédures spécifiques à l'utilisation de Windsurf lors des interactions avec l'assistant IA.

## Structure des Fichiers

### 📋 `rules.md`
Règles fondamentales adaptées à Windsurf, incluant:
- Principes de communication en français
- Intégration avec les fonctionnalités de l'IDE
- Gestion du contexte actif (fichiers ouverts, curseur)
- Utilisation des capacités d'IA intégrées

### 🔄 `procedures.md`
Procédures détaillées optimisées pour Windsurf:
- Analyse de code avec contexte IDE
- Modifications intégrées aux suggestions de Windsurf
- Débogage avancé avec l'interface intégrée
- Navigation intelligente et recherche multi-fichiers

### ⚡ `windsurf_shortcuts.md`
Référence complète des raccourcis et fonctionnalités:
- Raccourcis essentiels de navigation
- Commandes d'édition avancée
- Fonctionnalités spécifiques à l'IA de Windsurf
- Personnalisation et configuration

### 📖 `README.md`
Ce fichier - guide d'overview de la documentation Windsurf.

## Particularités de Windsurf

### 🤖 Intelligence Artificielle Intégrée
- Suggestions de code contextuelles
- Auto-complétion intelligente
- Génération de code depuis commentaires
- Quick fixes assistés par IA

### 🎯 Contexte d'Édition Actif
- Utilisation du fichier actif et de la position du curseur
- Analyse des onglets ouverts
- Prise en compte des erreurs surlignées
- Navigation avec les références existantes

### 🔧 Outils de Développement Intégrés
- Débogueur visuel avec points d'arrêt
- Terminal intégré pour commandes
- Interface Git pour gestion de version
- Extensions et plugins spécialisés

## Utilisation Optimale

### Pour l'Assistant IA
1. **Contexte d'abord**: Toujours analyser l'état actuel de Windsurf
2. **Intégration IDE**: Utiliser les capacités natives de Windsurf
3. **Navigation efficace**: Exploiter les raccourcis et fonctionnalités
4. **Validation continue**: Surveiller les erreurs et suggestions en temps réel

### Pour l'Utilisateur
1. **Communication en français**: Instructions claires et précises
2. **Contexte Windsurf**: Fournir des informations sur l'état de l'IDE si pertinent
3. **Feedback interactif**: Utiliser les suggestions et corrections de Windsurf
4. **Exploration**: Naviguer dans le code avec les outils intégrés

## Workflows Recommandés

### 📝 Analyse de Code
1. Observer le fichier actif et la position du curseur
2. Utiliser F12 pour naviguer vers les définitions
3. Consulter le panneau des problèmes pour les erreurs
4. Appliquer les quick fixes suggérés (Ctrl+.)

### ✏️ Modifications
1. Ouvrir les fichiers nécessaires dans des onglets
2. Utiliser Split View pour comparer les fichiers
3. Appliquer les modifications avec suggestions IA
4. Valider avec les linters intégrés

### 🔍 Recherche
1. Utiliser Ctrl+Shift+F pour rechercher dans tout le projet
2. Filtrer par type de fichier avec des préfixes
3. Naviguer avec Go to Definition et Find References
4. Organiser les résultats efficacement

### 🐛 Débogage
1. Configurer les points d'arrêt (F9)
2. Lancer le débogueur (F5)
3. Surveiller les variables et la pile d'appels
4. Appliquer les corrections en temps réel

## Extensions Recommandées

### Développement Web
- **Prettier**: Formatage de code
- **ESLint**: Vérification JavaScript/TypeScript
- **Live Server**: Développement web local

### Développement Mobile
- **Android**: Développement Android
- **React Native Tools**: Développement React Native
- **Flutter**: Développement Flutter

### Productivité
- **GitLens**: Amélioration Git
- **Material Icon Theme**: Icônes modernes
- **Bracket Pair Colorizer**: Coloration des parenthèses

## Configuration Personnalisée

### settings.json Essentiel
```json
{
    "editor.formatOnSave": true,
    "editor.suggestSelection": "first",
    "files.autoSave": "afterDelay",
    "workbench.colorTheme": "Default Dark+",
    "terminal.integrated.shell.windows": "powershell.exe"
}
```

### Raccourcis Personnalisés
- **Ctrl+;**: Commenter une ligne
- **Ctrl+Shift+;**: Commenter un bloc
- **Alt+Enter**: Quick Fix avec suggestions IA

## Bonnes Pratiques

### 🎯 Efficacité
- Utiliser les commandes de la palette (Ctrl+Shift+P)
- Configurer les snippets pour le code répétitif
- Personnaliser les raccourcis pour les actions fréquentes

### 🔒 Sécurité
- Vérifier les permissions des extensions
- Ne jamais exécuter de commandes dangereuses automatiquement
- Maintenir l'IDE et les extensions à jour

### 📈 Performance
- Désactiver les extensions non utilisées
- Surveiller l'utilisation mémoire pour les grands projets
- Utiliser le mode sans distractions (F11) pour la concentration

## Mises à Jour et Maintenance

Cette documentation doit évoluer avec:
- Nouvelles fonctionnalités de Windsurf
- Mises à jour des capacités d'IA intégrées
- Retours d'expérience des utilisateurs
- Évolution des meilleures pratiques

---

*Dernière mise à jour: 13 novembre 2025*
*Version: 1.0 - Spécifique à Windsurf*
