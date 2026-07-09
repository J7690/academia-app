# PHASE D.6F – ECONOMICS AUDIT

**Date** : 24 Juin 2026  
**Phase** : D.6F – Product Integration and Real User Validation  
**Composant** : Smart Whiteboard Economics Audit

---

## OBJECTIF

Auditer l'économie du système Smart Whiteboard pour :
- Calculer les coûts réels par génération
- Calculer les coûts réels par rendu
- Définir un modèle de prix pour les crédits
- Calculer la marge bénéficiaire
- Évaluer la viabilité économique

---

## 1. COÛTS DU SYSTÈME

### 1.1 Coûts d'infrastructure

#### 1.1.1 Supabase
- **Plan** : Pro ($25/mois)
- **Inclus** :
  - 8 Go de base de données
  - 1 Go de storage
  - 50 Go de bande passante
- **Coût par génération** : Négligeable (< $0.01)
- **Coût par rendu** : Négligeable (< $0.01)

#### 1.1.2 Edge Functions
- **Plan** : Inclus dans Supabase Pro
- **Coût par invocation** : $0.0000004 par 100ms
- **Temps moyen d'invocation** : 3000ms
- **Coût par génération** : $0.0000004 × 30 = $0.000012

#### 1.1.3 Storage
- **Plan** : $0.021/GB/mois
- **Taille moyenne vidéo** : 50 Mo
- **Coût par vidéo** : $0.021 × 0.05 = $0.00105/mois
- **Coût par rendu** : $0.00105 (stockage mensuel)

#### 1.1.4 Kamatera (Worker)
- **Instance** : 4 vCPU, 8 Go RAM
- **Coût** : ~$40/mois
- **Capacité** : ~60 rendus/heure
- **Coût par rendu** : $40 / (60 × 24 × 30) = $0.00093

### 1.2 Coûts d'IA

#### 1.2.1 OpenRouter (Génération storyboard)
- **Modèle** : Anthropic Claude 3.5 Sonnet
- **Prix** : $3/1M tokens input, $15/1M tokens output
- **Tokens par génération** : ~1000 input, ~2000 output
- **Coût par génération** : ($3 × 0.001) + ($15 × 0.002) = $0.033

#### 1.2.2 TTS (Narration)
- **Modèle** : ElevenLabs
- **Prix** : $0.30/1000 caractères
- **Caractères par narration** : ~5000
- **Coût par narration** : $0.30 × 5 = $1.50

### 1.3 Résumé des coûts

| Composant | Coût par génération | Coût par rendu | Coût total (sans narration) | Coût total (avec narration) |
|-----------|-------------------|-----------------|----------------------------|----------------------------|
| Supabase | $0.01 | $0.01 | $0.02 | $0.02 |
| Edge Functions | $0.000012 | $0 | $0.000012 | $0.000012 |
| Storage | $0 | $0.00105 | $0.00105 | $0.00105 |
| Kamatera | $0 | $0.00093 | $0.00093 | $0.00093 |
| OpenRouter | $0.033 | $0 | $0.033 | $0.033 |
| TTS | $0 | $0 | $0 | $1.50 |
| **TOTAL** | **$0.043** | **$0.002** | **$0.055** | **$1.555** |

---

## 2. MODÈLE DE PRIX CRÉDITS

### 2.1 Prix actuel des crédits

Basé sur la documentation existante (ACADEMIA_TRUTH_MATRIX.md) :
- **1 crédit** = 1 génération Smart Whiteboard
- **Prix actuel** : À définir

### 2.2 Proposition de prix

#### 2.2.1 Scénario 1 : Prix bas (adoption massive)
- **Prix par crédit** : 50 FCFA ($0.08)
- **Coût par génération** : $0.055
- **Marge** : $0.025 (31%)
- **Prix avec narration** : 1000 FCFA ($1.60)
- **Coût avec narration** : $1.555
- **Marge** : $0.045 (3%)

#### 2.2.2 Scénario 2 : Prix moyen (équilibre)
- **Prix par crédit** : 100 FCFA ($0.16)
- **Coût par génération** : $0.055
- **Marge** : $0.105 (66%)
- **Prix avec narration** : 2000 FCFA ($3.20)
- **Coût avec narration** : $1.555
- **Marge** : $1.645 (51%)

#### 2.2.3 Scénario 3 : Prix élevé (maximisation)
- **Prix par crédit** : 200 FCFA ($0.32)
- **Coût par génération** : $0.055
- **Marge** : $0.265 (83%)
- **Prix avec narration** : 4000 FCFA ($6.40)
- **Coût avec narration** : $1.555
- **Marge** : $4.845 (76%)

### 2.3 Recommandation

**Scénario 2 (Prix moyen)** est recommandé car :
- Marge saine (66% sans narration, 51% avec narration)
- Prix accessible pour les étudiants
- Viabilité économique assurée
- Compétitif par rapport aux alternatives

---

## 3. ANALYSE DE RENTABILITÉ

### 3.1 Scénarios d'utilisation

#### 3.1.1 Scénario conservateur (100 utilisateurs/mois)
- **Générations par utilisateur** : 2/mois
- **Total générations** : 200/mois
- **Générations avec narration** : 20 (10%)
- **Revenus** : (180 × 100 FCFA) + (20 × 2000 FCFA) = 18,000 + 40,000 = 58,000 FCFA/mois ($93)
- **Coûts** : (180 × $0.055) + (20 × $1.555) = $9.90 + $31.10 = $41/mois
- **Marge** : $52/mois (56%)

#### 3.1.2 Scénario modéré (500 utilisateurs/mois)
- **Générations par utilisateur** : 3/mois
- **Total générations** : 1500/mois
- **Générations avec narration** : 150 (10%)
- **Revenus** : (1350 × 100 FCFA) + (150 × 2000 FCFA) = 135,000 + 300,000 = 435,000 FCFA/mois ($696)
- **Coûts** : (1350 × $0.055) + (150 × $1.555) = $74.25 + $233.25 = $307.50/mois
- **Marge** : $388.50/mois (56%)

#### 3.1.3 Scénario optimiste (2000 utilisateurs/mois)
- **Générations par utilisateur** : 4/mois
- **Total générations** : 8000/mois
- **Générations avec narration** : 800 (10%)
- **Revenus** : (7200 × 100 FCFA) + (800 × 2000 FCFA) = 720,000 + 1,600,000 = 2,320,000 FCFA/mois ($3,712)
- **Coûts** : (7200 × $0.055) + (800 × $1.555) = $396 + $1,244 = $1,640/mois
- **Marge** : $2,072/mois (56%)

### 3.2 Point mort (Break-even)

- **Coûts fixes mensuels** : $65 (Supabase $25 + Kamatera $40)
- **Marge par génération** : $0.105 (sans narration)
- **Point mort** : $65 / $0.105 = 619 générations/mois
- **Utilisateurs nécessaires** : 619 / 3 = 206 utilisateurs (à 3 générations/mois)

---

## 4. COMPARAISON AVEC ALTERNATIVES

### 4.1 Alternatives sur le marché

| Service | Prix par vidéo | Durée | Qualité |
|---------|---------------|--------|---------|
| **D-ID** | $0.10-0.30/frame | 30-60s | Moyenne |
| **Synthesia** | $30-100/vidéo | 5-10min | Haute |
| **HeyGen** | $29-99/mois | Illimité | Haute |
| **Smart Whiteboard** | $0.16 (sans narration) | 1-5min | Haute |
| **Smart Whiteboard** | $3.20 (avec narration) | 1-5min | Haute |

### 4.2 Avantages concurrentiels

- **Prix** : Très compétitif pour les vidéos sans narration
- **Qualité** : Haute qualité pédagogique
- **Personnalisation** : Adapté au niveau scolaire
- **Langue** : Support du français
- **Intégration** : Intégré dans l'écosystème Academia

---

## 5. MODÈLE DE TARIFICATION

### 5.1 Packs de crédits

| Pack | Crédits | Prix (FCFA) | Prix par crédit | Économie |
|------|---------|------------|-----------------|----------|
| Starter | 5 | 500 | 100 FCFA | 0% |
| Standard | 20 | 1,800 | 90 FCFA | 10% |
| Premium | 50 | 4,000 | 80 FCFA | 20% |
| Pro | 100 | 7,000 | 70 FCFA | 30% |

### 5.2 Abonnements

| Abonnement | Crédits/mois | Prix (FCFA) | Prix par crédit | Économie |
|------------|--------------|------------|-----------------|----------|
| Mensuel | 10 | 800 | 80 FCFA | 20% |
| Trimestriel | 30 | 2,100 | 70 FCFA | 30% |
| Annuel | 120 | 7,200 | 60 FCFA | 40% |

### 5.3 Narration

- **Option TTS** : +500 FCFA par génération
- **Option Enregistrement** : +1000 FCFA par génération
- **Option Aucune** : Inclus

---

## 6. STRATÉGIE DE LANCEMENT

### 6.1 Phase bêta (50 étudiants)
- **Objectif** : Tester le système et la tarification
- **Offre** : 10 crédits gratuits
- **Feedback** : Collecter les retours sur la qualité et le prix
- **Durée** : 1 mois

### 6.2 Phase early adopter (200 étudiants)
- **Objectif** : Valider le modèle économique
- **Offre** : Pack Starter à 50% de réduction (250 FCFA)
- **Promotion** : Parrainage (5 crédits offerts par parrainage)
- **Durée** : 3 mois

### 6.3 Phase lancement (1000+ étudiants)
- **Objectif** : Adoption massive
- **Offre** : Tarification standard
- **Promotion** : Pack Premium offert pour les 100 premiers utilisateurs
- **Durée** : Permanent

---

## 7. ANALYSE DE SENSIBILITÉ

### 7.1 Impact d'une réduction de prix

| Réduction | Prix par crédit | Marge | Point mort (générations) |
|-----------|----------------|-------|--------------------------|
| 0% | 100 FCFA | 66% | 619 |
| 10% | 90 FCFA | 49% | 835 |
| 20% | 80 FCFA | 33% | 1,238 |
| 30% | 70 FCFA | 16% | 2,476 |

### 7.2 Impact d'une augmentation des coûts

| Augmentation | Coût par génération | Marge (à 100 FCFA) | Point mort (générations) |
|--------------|---------------------|---------------------|--------------------------|
| 0% | $0.055 | 66% | 619 |
| 20% | $0.066 | 59% | 743 |
| 50% | $0.083 | 48% | 933 |
| 100% | $0.110 | 31% | 1,238 |

### 7.3 Recommandation

- **Prix minimum** : 80 FCFA (marge 33%)
- **Prix optimal** : 100 FCFA (marge 66%)
- **Prix maximum** : 150 FCFA (marge 85%)

---

## 8. RAPPORT D'AUDIT

### 8.1 Structure du rapport

1. **Résumé exécutif**
   - Objectif de l'audit
   - Coûts du système
   - Modèle de prix recommandé
   - Rentabilité

2. **Analyse des coûts**
   - Coûts d'infrastructure
   - Coûts d'IA
   - Coûts totaux

3. **Modèle de tarification**
   - Prix par crédit
   - Packs de crédits
   - Abonnements
   - Options de narration

4. **Analyse de rentabilité**
   - Scénarios d'utilisation
   - Point mort
   - Marge bénéficiaire

5. **Comparaison concurrentielle**
   - Alternatives sur le marché
   - Avantages concurrentiels

6. **Stratégie de lancement**
   - Phase bêta
   - Phase early adopter
   - Phase lancement

7. **Analyse de sensibilité**
   - Impact des réductions de prix
   - Impact des augmentations de coûts

8. **Recommandations**
   - Prix recommandé
   - Packs recommandés
   - Stratégie de lancement

9. **Conclusion**
   - Viabilité économique
   - Risques
   - Opportunités

### 8.2 Livrables

- `docs/PHASE_D6F_ECONOMICS_AUDIT_REPORT.md` : Rapport complet
- `.windsurf/economics_calculator.py` : Calculateur de rentabilité

---

## 9. SCRIPT DE CALCUL DE RENTABILITÉ

### 9.1 Script Python

```python
#!/usr/bin/env python3
"""
Calculateur de rentabilité pour Smart Whiteboard
"""

def calculate_costs():
    """Calcule les coûts par génération"""
    costs = {
        "supabase": 0.01,
        "edge_functions": 0.000012,
        "storage": 0.00105,
        "kamatera": 0.00093,
        "openrouter": 0.033,
        "tts": 1.50,
    }
    
    total_without_narration = sum(costs[k] for k in costs if k != "tts")
    total_with_narration = sum(costs.values())
    
    return {
        "without_narration": total_without_narration,
        "with_narration": total_with_narration,
    }

def calculate_margin(price_credits, costs):
    """Calcule la marge"""
    margin = price_credits - costs["without_narration"]
    margin_percent = (margin / price_credits) * 100
    return {
        "margin": margin,
        "margin_percent": margin_percent,
    }

def calculate_break_even(fixed_costs, margin_per_generation):
    """Calcule le point mort"""
    return fixed_costs / margin_per_generation

def calculate_revenue(n_users, generations_per_user, price_per_credit, narration_rate, narration_price):
    """Calcule les revenus"""
    total_generations = n_users * generations_per_user
    narration_generations = total_generations * narration_rate
    normal_generations = total_generations - narration_generations
    
    revenue = (normal_generations * price_per_credit) + (narration_generations * narration_price)
    return revenue

if __name__ == "__main__":
    # Coûts
    costs = calculate_costs()
    print(f"Coût par génération (sans narration): ${costs['without_narration']:.4f}")
    print(f"Coût par génération (avec narration): ${costs['with_narration']:.4f}")
    
    # Marge (prix moyen : 100 FCFA = $0.16)
    price_per_credit = 0.16
    margin = calculate_margin(price_per_credit, costs)
    print(f"\nMarge par génération: ${margin['margin']:.4f} ({margin['margin_percent']:.1f}%)")
    
    # Point mort
    fixed_costs = 65  # Supabase $25 + Kamatera $40
    break_even = calculate_break_even(fixed_costs, margin['margin'])
    print(f"Point mort: {break_even:.0f} générations/mois")
    
    # Scénario modéré
    n_users = 500
    generations_per_user = 3
    narration_rate = 0.10
    narration_price = 3.20  # 2000 FCFA
    
    revenue = calculate_revenue(n_users, generations_per_user, price_per_credit, narration_rate, narration_price)
    total_generations = n_users * generations_per_user
    narration_generations = total_generations * narration_rate
    normal_generations = total_generations - narration_generations
    
    total_costs = (normal_generations * costs['without_narration']) + (narration_generations * costs['with_narration'])
    profit = revenue - total_costs
    
    print(f"\nScénario modéré ({n_users} utilisateurs):")
    print(f"Revenus: ${revenue:.2f}")
    print(f"Coûts: ${total_costs:.2f}")
    print(f"Profit: ${profit:.2f} ({(profit/revenue)*100:.1f}%)")
```

---

## 10. CONCLUSION

L'audit économique montre que le Smart Whiteboard est économiquement viable avec :
- **Coût par génération** : $0.055 (sans narration), $1.555 (avec narration)
- **Prix recommandé** : 100 FCFA ($0.16) par crédit
- **Marge** : 66% (sans narration), 51% (avec narration)
- **Point mort** : 619 générations/mois (~206 utilisateurs)

Le modèle économique est robuste et permet une marge saine tout en restant compétitif par rapport aux alternatives sur le marché.

---

**Fin de PHASE_D6F_ECONOMICS_AUDIT.md**
