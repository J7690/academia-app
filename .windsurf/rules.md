# Règles et Procédures - Windsurf

## Principes Fondamentaux

### Communication
- **Langue préférée**: Français pour toutes les interactions
- **Style**: Concis et direct, factuel
- **Format**: Utiliser Markdown avec fenced code blocks, titres appropriés
- **Références**: Citer les fichiers, fonctions et symboles avec des backticks

### Développement dans Windsurf
- **Approche**: Modifications minimales et ciblées
- **Style**: Suivre le style existant du codebase
- **Qualité**: Code immédiatement exécutable et testable
- **Imports**: Toujours en haut des fichiers
- **Sécurité**: Ne jamais exécuter de commandes potentiellement destructrices sans permission
- **Intégration IDE**: Tirer parti des fonctionnalités de Windsurf (auto-complétion, refactoring, etc.)

### Spécifique à Windsurf
- **Contexte**: Utiliser le contexte de l'IDE ouvert (fichiers actifs, curseur, etc.)
- **Navigation**: Exploiter les capacités de navigation de Windsurf
- **Refactoring**: Utiliser les outils de refactoring intégrés quand approprié
- **Extensions**: Tenir compte des extensions installées dans Windsurf

## Procédures par Type de Tâche

### 1. Analyse de Code dans Windsurf
1. **Utiliser le contexte actif**: Considérer le fichier ouvert et la position du curseur
2. **Explorer le workspace**: Utiliser les fonctionnalités de recherche de Windsurf
3. **Analyser avec l'IDE**: Profiter de l'analyse statique et des erreurs surlignées
4. **Croiser les informations**: Combiner les outils externes avec les capacités de Windsurf

### 2. Modifications de Code avec Windsurf
1. **Contexte IDE**: Toujours vérifier le fichier actif dans l'éditeur
2. **Modifications intelligentes**: Utiliser les suggestions de Windsurf
3. **Refactoring**: Appliquer les refactorings suggérés par l'IDE
4. **Validation**: Vérifier la syntaxe avec les linters intégrés

### 3. Navigation et Recherche
1. **Go to Definition**: Utiliser F12 ou Ctrl+Clic pour naviguer
2. **Find References**: Utiliser Shift+F12 pour trouver les références
3. **Search in Files**: Utiliser Ctrl+Shift+F pour rechercher dans tout le projet
4. **Symbol Search**: Utiliser Ctrl+Shift+O pour chercher des symboles

### 4. Débogage avec Windsurf
1. **Points d'arrêt**: Utiliser l'interface de débogage de Windsurf
2. **Console**: Examiner la console de débogage intégrée
3. **Variables**: Utiliser la fenêtre de variables pendant le débogage
4. **Call Stack**: Analyser la pile d'appels pour comprendre le flux

## Règles Spécifiques à l'Écosystème Windsurf

### Gestion des Fichiers
- **Tabs**: Gérer les onglets ouverts efficacement
- **Split View**: Utiliser les vues partagées pour comparer des fichiers
- **Explorer**: Naviguer avec l'explorateur de fichiers intégré
- **Search**: Utiliser la recherche intégrée avec filtres

### Extensions et Plugins
- **Vérification**: Considérer les extensions installées qui affectent le comportement
- **Compatibilité**: Assurer la compatibilité avec les outils existants
- **Configuration**: Respecter les fichiers de configuration (.vscode, etc.)

### Intégration Git
- **Source Control**: Utiliser l'interface Git intégrée
- **Changes**: Examiner les changements avant validation
- **Blame**: Utiliser Git Blame pour comprendre l'historique
- **Branch**: Être conscient de la branche Git actuelle

## Priorités et Workflow dans Windsurf

### Gestion des Tâches
1. **Contexte d'abord**: Analyser toujours l'état actuel de l'IDE
2. **Tâches parallèles**: Utiliser les capacités multi-fenêtres de Windsurf
3. **Sauvegarde automatique**: Faire confiance à la sauvegarde automatique de l'IDE
4. **Historique**: Utiliser l'historique local pour revenir en arrière si nécessaire

### Prise de Décision
1. **Analyse contextuelle**: Utiliser toutes les informations disponibles dans l'IDE
2. **Action intégrée**: Privilégier les actions qui utilisent les capacités de Windsurf
3. **Validation continue**: Vérifier les résultats en temps réel avec les linters

## Standards de Qualité pour Windsurf

### Code
- **Linting**: Respecter les règles de linting configurées
- **Formatting**: Utiliser le formateur de code intégré
- **IntelliSense**: Exploiter les suggestions d'auto-complétion
- **Error Highlighting**: Corriger les erreurs surlignées immédiatement

### Documentation
- **IntelliSense Docs**: Écrire des commentaires qui améliorent IntelliSense
- **Type Hints**: Utiliser les annotations de type pour une meilleure aide
- **JSDoc/TSDoc**: Documenter les fonctions avec des standards reconnus

## Gestion des Erreurs dans Windsurf

### Détection
- **Squiggles**: Prêter attention aux lignes ondulées (erreurs/warnings)
- **Problems Panel**: Consulter le panneau des problèmes
- **Output**: Examiner les sorties des outils de build
- **Terminal**: Vérifier les messages d'erreur dans le terminal intégré

### Correction
- **Quick Fix**: Utiliser les quick fixes suggérés (Ctrl+.)
- **Refactoring**: Appliquer les refactorings automatiques
- **Navigate to Error**: Utiliser les raccourcis pour naviguer vers les erreurs

## Outils et Techniques Spécifiques à Windsurf

### Raccourcis Essentiels
- **Ctrl+P**: Quick Open - ouvrir rapidement n'importe quel fichier
- **Ctrl+Shift+P**: Command Palette - accéder à toutes les commandes
- **Ctrl+`**: Toggle Terminal - ouvrir/fermer le terminal
- **Ctrl+B**: Toggle Sidebar - afficher/masquer la barre latérale
- **F11**: Toggle Full Screen - mode plein écran

### Multi-cursor et Sélection
- **Ctrl+Alt+Up/Down**: Ajouter des curseurs multiples
- **Ctrl+D**: Sélectionner la prochaine occurrence
- **Alt+Click**: Ajouter un curseur à la position du clic

### Édition Avancée
- **Ctrl+Shift+K**: Supprimer la ligne actuelle
- **Alt+Up/Down**: Déplacer la ligne vers le haut/bas
- **Shift+Alt+F**: Formater le document
- **Ctrl+/** : Commenter/décommenter la ligne

## Intégration avec les Outils Externes

### Terminal Intégré
- **Commands**: Exécuter les commandes dans le terminal intégré
- **Path**: Utiliser les chemins relatifs au workspace
- **Environment**: Respecter les variables d'environnement configurées

### Extensions Courantes
- **Prettier**: Pour le formatage de code
- **ESLint**: Pour la vérification JavaScript/TypeScript
- **Python**: Pour le développement Python
- **Java Extension Pack**: Pour le développement Java
- **Android**: Pour le développement Android

## Sécurité et Bonnes Pratiques

### Sécurité
- **Workspace**: Être conscient du workspace ouvert et de ses permissions
- **Extensions**: Vérifier la sécurité des extensions installées
- **Commands**: Ne jamais exécuter de commandes potentiellement dangereuses automatiquement

### Performance
- **Large Files**: Faire attention aux fichiers très volumineux
- **Extensions**: Désactiver les extensions non utilisées
- **Memory**: Surveiller l'utilisation de la mémoire pour les grands projets

## Autosélection Obligatoire de l’Agent IA (Projet Academia)

### Agents disponibles
- Agent IA global : `cascade` (préféré, priorité haute).
- Agents spécialisés décrits dans `intelligent_agent_selection.md` :
  - `flutter_ui_agent` : UI Flutter, widgets, layout, vidéo côté app.
  - `supabase_db_agent` : schémas, RPC, RLS, migrations Supabase.
  - `integration_agent` : intégration Flutter ⇄ backend ⇄ Supabase.
  - `system_architect_agent` : architecture globale du projet.
  - `debug_agent` : débogage multi-systèmes, performance, logs.

### Règles de sélection
- Tâches Flutter/UI : utiliser `flutter_ui_agent` comme agent spécialisé.
- Tâches Supabase/SQL/RPC : utiliser `supabase_db_agent`.
- Tâches d’intégration Flutter ⇄ Backend ⇄ Supabase : utiliser `integration_agent`.
- Tâches d’architecture globale : utiliser `system_architect_agent`.
- Tâches de débogage transversal : utiliser `debug_agent` + un agent spécialisé approprié.

Si aucun agent adapté ne peut être identifié, la tâche doit être considérée comme **interdite**.

## Audit Obligatoire Avant Action

Avant toute modification de code ou de schéma liée à Flutter, Supabase ou au backend :
- produire un audit dans `.windsurf/audit/last_audit.md` contenant au minimum :
  - fichiers impactés ;
  - dépendances principales ;
  - risques de régression ;
  - plan d’action détaillé ;
  - agent spécialisé sélectionné.
- sans ce fichier d’audit à jour, **aucune modification ne doit être exécutée**.

## Règles Supabase & RPC

- Toute écriture dans la base doit passer par les RPC/admin documentées dans `.windsurf` :
  - via `auto_supabase_import.py` (méthodes `supabase_*`), ou
  - via `SupabaseAutoManager` et `admin_execute_sql`.
- Aucune exécution SQL directe dans le dashboard n’est autorisée dans le flux Windsurf.
- Les changements SQL significatifs doivent être consignés dans `.windsurf/sql_changes/change_YYYYMMDD.sql`.

## Structure Requise .windsurf (Projet Academia)

À respecter et enrichir progressivement :

- `.windsurf/rules.md` : règles globales (ce fichier).
- `.windsurf/intelligent_agent_selection.md` : détails de sélection d’agents.
- `.windsurf/windsurf_mandatory_rules.json` : règles d’application automatique.
- `.windsurf/audit/last_audit.md` : dernier audit pré-action.
- `.windsurf/sql_changes/` : scripts SQL appliqués via RPC admin.
- `.windsurf/logs/` : journaux d’exécutions, dont échecs vidéo (TECNO LD7, etc.).

## Règle Finale

Si une règle critique (autosélection d’agent, audit préalable, usage des RPC Supabase) n’est pas respectée, la tâche doit être **bloquée** et signalée comme non conforme aux règles `.windsurf` de ce projet.
