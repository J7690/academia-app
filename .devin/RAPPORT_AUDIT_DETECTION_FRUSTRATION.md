# RAPPORT AUDIT DÉTECTION FRUSTRATION BOBODO

**Date** : 9 juin 2026  
**Statut** : AUDIT TERMINÉ

---

## 1. AUDIT DE L'EXISTANT

### Localisation

La détection de frustration est implémentée dans `supabase/functions/bobodo-chat/index.ts` dans la fonction `detectEmotionalState()` (lignes 298-372).

### Fonctionnement existant

**Lignes 351-360** - Détection frustration :
```typescript
// Frustration / incompréhension
if (
  [
    'pas clair', 'pas compris', 'je comprends pas', 'comprends pas', 'ne comprends pas',
    'pas satisfait', 'pas satisfaisante', 'mauvaise réponse', 'pas ce que je cherchais',
    "c'est pas ça", "c'est pas ce que", 'reformule', 'explique mieux', 'pas utile',
    'inutile', 'faux', 'incorrect', 'pas la bonne', 'autre explication', 're-explique',
    'non pas', 'non, pas', 'non ce n', 'pas vraiment',
  ].some((k) => text.includes(k))
) return 'frustrated';
```

### Patterns détectés

**Incompréhension** :
- 'pas clair'
- 'pas compris'
- 'je comprends pas'
- 'comprends pas'
- 'ne comprends pas'

**Insatisfaction** :
- 'pas satisfait'
- 'pas satisfaisante'
- 'mauvaise réponse'
- 'pas ce que je cherchais'

**Demande de reformulation** :
- "c'est pas ça"
- "c'est pas ce que"
- 'reformule'
- 'explique mieux'
- 'autre explication'
- 're-explique'

**Inutilité** :
- 'pas utile'
- 'inutile'

**Inexactitude** :
- 'faux'
- 'incorrect'
- 'pas la bonne'

**Négation** :
- 'non pas'
- 'non, pas'
- 'non ce n'
- 'pas vraiment'

---

## 2. VÉRIFICATION DES PATTERNS UTILISATEUR

### Patterns demandés par l'utilisateur

| Pattern utilisateur | Couvert par l'existant | État |
|---------------------|------------------------|------|
| ce n'est pas ce que je cherche | 'pas ce que je cherchais' | ✅ Oui |
| tu ne réponds pas à ma question | Aucun pattern équivalent | ❌ Non |
| je ne suis pas satisfait | 'pas satisfait' | ✅ Oui |
| ça ne m'aide pas | 'pas utile' | ✅ Oui |
| tu te trompes | 'faux', 'incorrect' | ✅ Oui |
| je ne comprends pas | 'pas compris', 'je comprends pas' | ✅ Oui |

### Analyse

**5/6 patterns couverts** - Le système de détection de frustration existe déjà et couvre la majorité des cas.

**Pattern manquant** : "tu ne réponds pas à ma question"

---

## 3. COMPORTEMENT ACTUEL

### Lorsque la frustration est détectée

**Ligne 1189** - Règle métier existante :
```
'- Gestion frustration (reformule avec exemple)\n'
```

**Lignes 1230-1234** - Instruction contextuelle :
```typescript
} else if (emotionalState === 'emotional') {
  contextualInstruction =
    '\n\nCONTEXTE: L\'utilisateur est insatisfait ou n\'a pas compris. ' +
    'Réponds avec empathie, reformule ta réponse avec un exemple concret.';
```

### Limitation actuelle

Le système détecte la frustration mais **n'oriente pas automatiquement vers le support humain**. Il reformule simplement la réponse avec un exemple.

---

## 4. AMÉLIORATION PROPOSÉE

### Ajouter le pattern manquant

Ajouter 'tu ne réponds pas', 'tu ne réponds pas à ma question' aux patterns de frustration.

### Renforcer l'escalade vers le support

**Option 1** : Ajouter une règle explicite dans le system prompt pour orienter vers le support après plusieurs frustrations.

**Option 2** : Implémenter un compteur de frustrations dans la session et orienter vers le support après 3 frustrations consécutives.

**Option 3** : Modifier l'instruction contextuelle pour inclure l'escalade vers le support lorsque l'état émotionnel est 'frustrated'.

### Recommandation

**Option 3** - La plus simple et la plus immédiate :

Modifier l'instruction contextuelle pour l'état 'frustrated' afin d'inclure l'escalade vers le support humain.

---

## 5. CONCLUSION

**Détection de frustration** : ✅ Existe et fonctionne bien
**Couverture des patterns** : ✅ 5/6 patterns utilisateur couverts
**Pattern manquant** : ❌ "tu ne réponds pas à ma question"
**Escalade vers support** : ⚠️ Non implémentée pour la frustration

**Actions recommandées** :
1. Ajouter le pattern manquant
2. Modifier l'instruction contextuelle pour inclure l'escalade vers le support

---

**RAPPORT TERMINÉ**
