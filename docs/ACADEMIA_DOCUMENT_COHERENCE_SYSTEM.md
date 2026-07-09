# ACADEMIA DOCUMENT COHERENCE SYSTEM

**Date** : 24 Juin 2026  
**Version** : 1.0  
**Statut** : ACTIF

---

## OBJECTIF

Garantir qu'après plusieurs centaines de phases, n'importe quel agent puisse reconstruire l'intégralité du projet uniquement à partir des 11 documents permanents, sans ambiguïté et sans contradiction.

À partir de cette phase, les 11 documents permanents sont considérés comme un système unique. Ils ne doivent jamais diverger.

---

## LES 11 DOCUMENTS PERMANENTS

1. **ACADEMIA_MASTER_INDEX.md** : Index central du projet
2. **ACADEMIA_TRUTH_MATRIX.md** : Matrice de vérité unique
3. **ACADEMIA_CHANGELOG.md** : Historique complet
4. **ACADEMIA_DEPLOYMENT_STATUS.md** : État des déploiements
5. **ACADEMIA_PROJECT_STATE.md** : État actuel du projet
6. **ACADEMIA_CURRENT_CHECKPOINT.md** : Checkpoint courant
7. **ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md** : Protocole permanent d'exécution
8. **ACADEMIA_TECHNICAL_CONSTITUTION.md** : Constitution technique
9. **ACADEMIA_ARCHITECTURE_DECISIONS.md** : Registre des décisions d'architecture
10. **ACADEMIA_CONTRACT_REGISTRY.md** : Registre des contrats techniques
11. **ACADEMIA_TRACEABILITY_MATRIX.md** : Matrice de traçabilité

---

## RÈGLE 1 : COHÉRENCE INTER-DOCUMENTS

Une modification apportée dans un document ne doit jamais rendre un autre document incohérent.

**Exemples d'incohérences à éviter** :
- Un ADR référencé dans un document mais absent de ACADEMIA_ARCHITECTURE_DECISIONS.md
- Un contrat référencé dans un document mais absent de ACADEMIA_CONTRACT_REGISTRY.md
- Un composant classé A dans la Truth Matrix mais absent de la Traceability Matrix
- Une phase présente dans le Changelog mais absente du Checkpoint alors qu'elle est encore ouverte
- Un document permanent absent du Master Index
- Des classifications A/B/C/D/E incohérentes entre les documents

---

## RÈGLE 2 : CONTRÔLE DE COHÉRENCE EN FIN DE PHASE

À la fin de chaque phase, effectuer un contrôle de cohérence systématique.

**Vérifications à effectuer** :

1. **ADR**
   - Tous les ADR référencés existent-ils dans ACADEMIA_ARCHITECTURE_DECISIONS.md ?
   - Les statuts des ADR sont-ils cohérents ?

2. **Contrats**
   - Tous les contrats référencés existent-ils dans ACADEMIA_CONTRACT_REGISTRY.md ?
   - Les versions des contrats sont-elles cohérentes ?

3. **Composants**
   - Tous les composants présents dans la Truth Matrix existent-ils dans la Traceability Matrix ?
   - Les classifications A/B/C/D/E sont-elles cohérentes entre les documents ?

4. **Phases**
   - Toutes les phases du Changelog sont-elles présentes dans le Checkpoint lorsqu'elles sont encore ouvertes ?
   - Les dates de phases sont-elles cohérentes ?

5. **Master Index**
   - Le Master Index référence-t-il tous les documents permanents ?
   - Les chemins des documents sont-ils corrects ?

6. **Classifications**
   - Les classifications A/B/C/D/E sont-elles cohérentes entre les documents ?
   - Les dates de vérification sont-elles cohérentes ?

---

## RÈGLE 3 : CORRECTION DES INCOHÉRENCES

Si une incohérence est détectée :
1. La corriger immédiatement
2. Documenter la correction dans le rapport de phase

**Format de documentation** :
```
Incohérence détectée : [description]
Correction réalisée : [description]
Document impacté : [nom du document]
```

---

## RÈGLE 4 : SECTION OBLIGATOIRE DANS LES RAPPORTS DE PHASE

Chaque rapport de phase devra désormais contenir une nouvelle section obligatoire :

### Vérification de cohérence documentaire

**Contenu minimum** :
- Documents vérifiés
- Incohérences détectées
- Corrections réalisées
- Résultat final

**Format** :
```markdown
## Vérification de cohérence documentaire

### Documents vérifiés
- ACADEMIA_MASTER_INDEX.md
- ACADEMIA_TRUTH_MATRIX.md
- ACADEMIA_CHANGELOG.md
- ACADEMIA_DEPLOYMENT_STATUS.md
- ACADEMIA_PROJECT_STATE.md
- ACADEMIA_CURRENT_CHECKPOINT.md
- ACADEMIA_PERMANENT_EXECUTION_PROTOCOL.md
- ACADEMIA_TECHNICAL_CONSTITUTION.md
- ACADEMIA_ARCHITECTURE_DECISIONS.md
- ACADEMIA_CONTRACT_REGISTRY.md
- ACADEMIA_TRACEABILITY_MATRIX.md

### Incohérences détectées
- Aucune / [Liste des incohérences]

### Corrections réalisées
- Aucune / [Liste des corrections]

### Résultat final
- COHÉRENT / INCOHÉRENT (avec détails)
```

---

## RÈGLE 5 : IMPACT DOCUMENTAIRE DANS LES RAPPORTS DE PHASE

Le rapport de phase devra également indiquer l'impact documentaire :

### Impact documentaire

**Contenu minimum** :
- ADR modifiés
- Contrats modifiés
- Traceabilité modifiée
- Truth Matrix modifiée
- Checkpoint modifié
- Changelog modifié
- Master Index modifié

**Format** :
```markdown
## Impact documentaire

### ADR modifiés
- Aucun / [Liste des ADR modifiés]

### Contrats modifiés
- Aucun / [Liste des contrats modifiés]

### Traceabilité modifiée
- Aucune / [Liste des modifications]

### Truth Matrix modifiée
- Aucune / [Liste des modifications]

### Checkpoint modifié
- Oui / Non

### Changelog modifié
- Oui / Non

### Master Index modifié
- Oui / Non
```

---

## RÈGLE 6 : VÉRIFICATION FINALE AVANT CLÔTURE

Avant de clôturer une phase, vérifier que les 11 documents racontent exactement la même histoire.

**Critères de validation** :
- L'état du projet est identique dans tous les documents
- Les dates sont cohérentes
- Les classifications sont cohérentes
- Les références sont valides
- Aucune contradiction n'existe

**Il ne doit pas exister deux versions différentes de l'état du projet.**

---

## RÈGLE 7 : CRITÈRES DE REFUS DE CLÔTURE

La clôture d'une phase est refusée si :

1. Un document permanent n'a pas été synchronisé
2. Une référence est cassée (ADR, contrat, composant)
3. Une décision d'architecture n'est pas tracée
4. Un contrat n'est pas référencé
5. Une fonctionnalité n'est pas présente dans la matrice de traçabilité
6. Une incohérence est détectée et non corrigée
7. La section "Vérification de cohérence documentaire" est absente du rapport
8. La section "Impact documentaire" est absente du rapport

---

## PROCÉDURE DE CONTRÔLE DE COHÉRENCE

### Étape 1 : Collecte des modifications

Identifier tous les documents modifiés lors de la phase.

### Étape 2 : Vérification des références

Pour chaque document modifié, vérifier que toutes les références sont valides.

### Étape 3 : Vérification de la cohérence

Vérifier que les modifications sont cohérentes avec les autres documents.

### Étape 4 : Correction des incohérences

Corriger toutes les incohérences détectées.

### Étape 5 : Documentation

Documenter les incohérences et les corrections dans le rapport de phase.

### Étape 6 : Validation finale

Valider que les 11 documents racontent la même histoire.

---

## OUTILS DE CONTRÔLE

### Contrôle automatique (à implémenter)

Script Python pour vérifier automatiquement :
- Les références ADR
- Les références de contrats
- La cohérence des classifications
- La cohérence des dates
- La présence des documents dans le Master Index

### Contrôle manuel

Vérification manuelle des :
- Cohérence narrative
- Cohérence technique
- Cohérence temporelle

---

## HISTORIQUE DES MODIFICATIONS

### 24 Juin 2026
- Création du système de cohérence documentaire
- Définition des 7 règles de cohérence
- Définition de la procédure de contrôle
- Définition des critères de refus de clôture
- Définition des sections obligatoires dans les rapports de phase

---

**Fin de ACADEMIA_DOCUMENT_COHERENCE_SYSTEM.md**
