# GUIDE DE CORRECTION OPENROUTER

## PHASE 1 - CORRECTION SECRETS SUPABASE

### Étape 1 : Accéder au Dashboard Supabase

1. Ouvrir https://supabase.com/dashboard
2. Se connecter
3. Sélectionner le projet : `thevdfcwlcqzdoybfvgs`

### Étape 2 : Accéder aux secrets Edge Functions

1. Dans le menu de gauche, cliquer sur **Edge Functions**
2. Cliquer sur l'onglet **Settings**
3. Scroller jusqu'à la section **Environment Variables**

### Étape 3 : Vérifier et corriger les secrets

Vérifier les secrets suivants et les mettre à jour si nécessaire :

**OPENROUTER_API_KEY**
- Si vide ou invalide : Remplacer par une clé API OpenRouter valide
- Format : sk-or-v1-...

**OPENROUTER_MODEL**
- Si vide : Définir à `meta-llama/Meta-Llama-3.1-70B-Instruct`
- Ou utiliser `google/gemini-2.5-flash` pour de meilleures performances

**OPENROUTER_EMBEDDING_MODEL**
- Si vide : Définir à `openai/text-embedding-3-small`
- Ce secret est CRITIQUE pour la génération d'embeddings

**OPENROUTER_FALLBACK_MODEL** (optionnel)
- Si vide : Définir à `google/gemini-2.5-flash`
- Utilisé en cas d'échec du modèle principal

### Étape 4 : Sauvegarder

Cliquer sur **Save** pour appliquer les modifications.

---

## PHASE 2 - ALIGNEMENT DES ENVIRONNEMENTS

### Étape 1 : Éditer le fichier .env local

Ouvrir le fichier : `academia_bobodo_backend/.env`

### Étape 2 : Synchroniser avec les secrets Supabase

Remplacer les valeurs par les mêmes que dans Supabase :

```
OPENROUTER_API_KEY=<même_clé_que_supabase>
OPENROUTER_MODEL=meta-llama/Meta-Llama-3.1-70B-Instruct
OPENROUTER_EMBEDDING_MODEL=openai/text-embedding-3-small
OPENROUTER_FALLBACK_MODEL=google/gemini-2.5-flash
```

### Étape 3 : Sauvegarder le fichier

Sauvegarder les modifications.

---

## PHASE 3 - TESTS OPENROUTER

Une fois les corrections appliquées, exécuter :

```bash
cd .windsurf
python test_openrouter_comparative.py
```

Les tests doivent réussir avec HTTP 200.

---

## PHASE 4 - VECTORISATION COMPLÈTE

Une fois les tests validés, exécuter :

```bash
cd .windsurf
python compute_bobodo_knowledge_embeddings.py
```

Cela générera les embeddings pour toutes les fiches non vectorisées.

---

## PHASE 5 - VALIDATION RAG

Tester manuellement dans l'application Flutter avec les questions :
- Comment postuler ?
- Quels documents fournir ?
- Comment suivre ma candidature ?
- Comment acheter des crédits IA ?
- Mon paiement est en attente.
- Que signifie under_review ?

---

## PHASE 6 - AUDIT FINAL

Exécuter :

```bash
cd .windsurf
python map_bobodo_vectorization.py
```

Confirmer que le taux de vectorisation est de 100%.

---

**IMPORTANT : Commencer par la PHASE 1 (correction secrets Supabase)**
