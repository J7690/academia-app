# Workflow de Validation et Exécution

## Processus de Validation en 6 Étapes

### 1. Réception et Analyse de la Demande
```yaml
etape_1_analyse:
  objectif: "Comprendre la nature exacte de la demande"
  actions:
    - analyser_semantique: "comprendre l'intention sans mots-clés"
    - identifier_systemes: "Flutter, Supabase, autres technologies"
    - evaluer_complexite: "simple, moyenne, complexe, critique"
    - selectionner_agents: "automatique selon la nature"
```

### 2. Audit Systématique Pré-Exécution
```yaml
etape_2_audit:
  objectif: "Vérifier l'état actuel des systèmes concernés"
  audit_flutter:
    - scanner_structure: "lib/, pubspec.yaml, dependencies"
    - verifier_composants: "widgets, services, modèles"
    - identifier_impact: "fichiers qui seront modifiés"
  
  audit_supabase:
    - lister_tables: "schéma existant"
    - verifier_fonctions: "RPC, triggers, policies"
    - valider_permissions: "RLS, accès par rôle"
  
  audit_integration:
    - tester_connexions: "endpoints existants"
    - valider_coherence: "types de données compatibles"
    - verifier_securite: "clés API, tokens"
```

### 3. Génération de Proposition d'Action
```markdown
## 📋 Proposition d'Action - Validation Requise

### 🎯 Objectif
[Description claire de ce qui doit être fait]

### 🔍 Résultats de l'Audit
- **Flutter**: X fichiers analysés, Y éléments impactés
- **Supabase**: X tables vérifiées, Y fonctions validées  
- **Integration**: X endpoints testés, Y connexions OK

### 📝 Actions Proposées
1. [Action spécifique 1 avec fichiers concernés]
2. [Action spécifique 2 avec impact identifié]
3. [Action spécifique 3 avec dépendances]

### ⚠️ Risques Identifiés
- [Risque 1 avec probabilité et impact]
- [Risque 2 avec stratégie de mitigation]

### ✅ Validation Requise
Confirmez-vous cette proposition d'action ?
- [ ] Oui, exécuter comme proposé
- [ ] Non, modifications nécessaires
- [ ] Annuler, trop risqué
```

### 4. Validation Explicite Utilisateur
```yaml
etape_4_validation:
  objectif: "Obtenir accord formel avant exécution"
  methode: "Question directe avec options claires"
  conditions:
    - audit_complet: "tous les systèmes vérifiés"
    - risques_identifies: "transparence totale"
    - alternatives_proposees: "si applicable"
    - delai_reflexion: "pas de décision automatique"
```

### 5. Exécution avec Monitoring
```yaml
etape_5_execution:
  objectif: "Appliquer les modifications en surveillant"
  monitoring:
    - verification_syntaxe: "à chaque modification"
    - tests_unitaires: "si disponibles"
    - verification_integration: "Flutter + Supabase"
    - surveillance_erreurs: "logs en temps réel"
  
  rollback:
    - sauvegarde_pre_modification: "automatique"
    - points_de_restoration: "à chaque étape"
    - procedure_rollback: "documentée"
```

### 6. Validation Post-Exécution
```yaml
etape_6_validation_finale:
  objectif: "Confirmer le succès et l'absence de régression"
  tests:
    - fonctionnalite: "vérifier que ça fonctionne"
    - non_regression: "rien d'autre n'est cassé"
    - performance: "pas de dégradation"
    - securite: "pas de nouvelle vulnérabilité"
  
  documentation:
    - modifications_appliquees: "liste détaillée"
    - changements_impact: "fichiers modifiés"
    - prochaines_etapes: "si nécessaire"
```

## Exemples de Workflow

### Scénario: Ajouter champ téléphone utilisateur
```markdown
### 1. Analyse
Demande: "Ajouter un champ téléphone aux utilisateurs"
Complexité: moyenne (UI + BDD + API)
Agents: flutter_ui_agent + supabase_db_agent + integration_agent

### 2. Audit Résultats
- Flutter: Model User trouvé dans lib/models/user.dart
- Supabase: Table users existe, colonne phone absente
- Integration: API user_profile existe, compatible avec ajout

### 3. Proposition
1. Ajouter colonne phone à table users (Supabase)
2. Mettre à jour model User (Flutter)
3. Modifier formulaire d'inscription (Flutter UI)
4. Adapter API calls (Integration)

### 4. Validation
[En attente de confirmation utilisateur]

### 5. Exécution (si validé)
[Monitoring continu pendant modifications]

### 6. Vérification Finale
[Test complet du flow inscription → profil]
```

## Règles Strictes

### Jamais de Déduction
❌ **Interdit**: "Il doit y avoir une table users parce que j'ai vu un User model"
✅ **Obligatoire**: "Je scanne la base Supabase... table users trouvée: colonnes id, email, created_at"

### Audit Systématique
❌ **Interdit**: "Je suppose que cette fonction Supabase existe"
✅ **Obligatoire**: "Je vérifie les fonctions RPC existantes... fonction getUser trouvée avec paramètres: user_id uuid"

### Validation Explicite
❌ **Interdit**: "Je vais faire cette modification directement"
✅ **Obligatoire**: "Voici ce que je propose de faire. Confirmez-vous ?"

Ce workflow garantit zéro supposition et validation complète à chaque étape.
