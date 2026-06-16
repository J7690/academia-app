# AUDIT ET RÉPARATION VECTORISATION BOBODO

**Date** : 9 juin 2026  
**Statut** : PHASE 1-2 TERMINÉES - ATTENTE CORRECTION CLÉ API

---

## 1. CAUSE EXACTE DU HTTP 401

### Diagnostic

**Erreur** : HTTP 401 "User not found" sur l'API OpenRouter

**Tests effectués** :
- ✅ Embeddings (openai/text-embedding-3-small) → HTTP 401
- ✅ Chat completions (meta-llama/Meta-Llama-3.1-70B-Instruct) → HTTP 401
- ✅ Embeddings avec modèle incorrect → HTTP 401

**Conclusion** : La clé API OpenRouter est invalide ou expirée. Toutes les requêtes échouent, indépendamment du modèle utilisé.

### Secrets Supabase

**Fichier** : `academia_bobodo_backend/.env`

**État** :
- ✅ OPENROUTER_API_KEY : Présente (73 caractères)
- ❌ OPENROUTER_EMBEDDING_MODEL : NON DÉFINIE
- ✅ OPENROUTER_MODEL : meta-llama/Meta-Llama-3.1-70B-Instruct
- ❌ OPENROUTER_FALLBACK_MODEL : NON DÉFINIE

**Problème** : La clé API est invalide. Le modèle d'embedding n'est pas configuré dans les secrets Supabase.

### Code génération embeddings

**Fichier** : `supabase/functions/bobodo-chat/index.ts`

**Fonction** : `embedQuery()` (lignes 112-156)

**Logique** :
- Récupère OPENROUTER_API_KEY et OPENROUTER_EMBEDDING_MODEL depuis les secrets
- Appelle l'API OpenRouter embeddings
- Retourne null si erreur (HTTP 401)

**Impact** : Si la clé API est invalide, la fonction retourne null et la recherche vectorielle est désactivée.

---

## 2. ÉTAT AVANT CORRECTION

### Statistiques globales

- **Total fiches** : 33
- **Fiches vectorisées** : 13
- **Fiches non vectorisées** : 20
- **Taux de vectorisation** : 39.4%

### État LOT A

- **Fiches LOT A** : 7
- **Vectorisées** : 0/7
- **Non vectorisées** : 7/7

### Liste des fiches non vectorisées (20)

**LOT A (7 fiches)** :
1. Comment déposer une candidature sur Academia
2. Documents nécessaires pour une candidature
3. Critères d'admission des universités partenaires
4. Comprendre les statuts de candidature
5. Effectuer un paiement sur Academia
6. Guide complet des crédits IA
7. Comment suivre sa candidature

**Autres fiches (13 fiches)** :
8. Orientation académique et professionnelle
9. Messagerie et groupes
10. Espace Opportunités
11. Espace Challenge
12. Espace Live
13. Bibliothèque de cours
14. Accompagnement par des enseignants
15. Crédits IA
16. Préparation Concours
17. Onglet TD
18. Onglet Marketplace
19. Onglet Universités
20. Présentation générale d'Academia

---

## 3. CORRECTION APPLIQUÉE

### Correction minimale requise

**Problème** : Clé API OpenRouter invalide (HTTP 401 "User not found")

**Solution** : Renouveler ou corriger la clé API OpenRouter

**Actions requises** :

1. **Vérifier le compte OpenRouter** :
   - Se connecter sur https://openrouter.ai/
   - Vérifier que la clé API est active
   - Régénérer la clé si nécessaire

2. **Mettre à jour les secrets Supabase** :
   - Ouvrir Supabase Dashboard
   - Aller dans Settings → Edge Functions
   - Mettre à jour `OPENROUTER_API_KEY` avec la nouvelle clé
   - Ajouter `OPENROUTER_EMBEDDING_MODEL` = `openai/text-embedding-3-small`

3. **Mettre à jour le fichier .env local** :
   - Éditer `academia_bobodo_backend/.env`
   - Remplacer `OPENROUTER_API_KEY` par la nouvelle clé
   - Ajouter `OPENROUTER_EMBEDDING_MODEL=openai/text-embedding-3-small`

**Note** : Cette correction est externe au code. Aucune modification de code n'est requise.

---

## 4. ÉTAT APRÈS CORRECTION

**En attente de validation de la nouvelle clé API OpenRouter**

Une fois la clé API corrigée :
- ✅ Les appels API OpenRouter fonctionneront
- ✅ La génération d'embeddings sera possible
- ✅ La recherche vectorielle sera rétablie

---

## 5. NOMBRE DE FICHES VECTORISÉES

**État actuel** : 13/33 (39.4%)

**Objectif après correction** : 33/33 (100%)

---

## 6. TESTS RAG RÉALISÉS

**Non applicable** - En attente de correction de la clé API OpenRouter

---

## 7. VALIDATION FINALE

**En attente** - La correction de la clé API OpenRouter est requise avant de poursuivre.

---

## PROCHAINES ÉTAPES

Une fois la clé API corrigée :

1. **Phase 4** : Reconstruction des embeddings pour les 20 fiches non vectorisées
2. **Phase 5** : Validation RAG avec les formulations de test
3. **Validation finale** : Rapport complet

---

**RAPPORT PHASE 1-2 TERMINÉ - ATTENTE CORRECTION CLÉ API OPENROUTER**
