# RAPPORT DE COHÉRENCE OPENROUTER

**Date** : 9 juin 2026  
**Statut** : AUDIT COMPLET - DIAGNOSTIC ÉTABLI

---

## 1. CARTOGRAPHIE COMPLÈTE

### 1.1 Variables d'environnement système

**État** : ❌ Aucune variable définie

- OPENROUTER_API_KEY : NON DÉFINIE
- OPENROUTER_MODEL : NON DÉFINIE
- OPENROUTER_FALLBACK_MODEL : NON DÉFINIE
- OPENROUTER_EMBEDDING_MODEL : NON DÉFINIE

### 1.2 Fichiers .env backend

**Fichier** : `academia_bobodo_backend/.env`

**État** : ✅ Présent (671 octets)

**Configuration** :
- OPENROUTER_API_KEY : sk-or-v1-1...4fc6 (73 caractères)
- OPENROUTER_MODEL : meta-llama/Meta-Llama-3.1-70B-Instruct (38 caractères)
- OPENROUTER_EMBEDDING_MODEL : NON DÉFINIE ❌
- OPENROUTER_FALLBACK_MODEL : NON DÉFINIE ❌

**Autres fichiers** :
- .env.local : ❌ Non présent
- .env.production : ❌ Non présent

### 1.3 Edge Functions utilisant OpenRouter

**16 Edge Functions identifiées** :

1. bobodo-chat - OPENROUTER_API_KEY, MODEL, FALLBACK_MODEL, EMBEDDING_MODEL
2. td-tutor-chat - OPENROUTER_API_KEY, MODEL, FALLBACK_MODEL, EMBEDDING_MODEL (fallback: openai/text-embedding-3-small)
3. td-scan-subject - OPENROUTER_API_KEY, MODEL, FALLBACK_MODEL
4. td-ingest-document - OPENROUTER_API_KEY, MODEL, FALLBACK_MODEL, EMBEDDING_MODEL (fallback: openai/text-embedding-3-small)
5. td-generate-exercises - OPENROUTER_API_KEY, MODEL, FALLBACK_MODEL, EMBEDDING_MODEL (fallback: openai/text-embedding-3-small)
6. prep-tutor-chat - OPENROUTER_API_KEY, MODEL, FALLBACK_MODEL, EMBEDDING_MODEL (fallback: openai/text-embedding-3-small)
7. prep-scan-subject - OPENROUTER_API_KEY, MODEL, FALLBACK_MODEL
8. prep-ingest-document - OPENROUTER_API_KEY, MODEL, FALLBACK_MODEL
9. prep-grade-assignment - OPENROUTER_API_KEY, MODEL, FALLBACK_MODEL
10. prep-generate-questions - OPENROUTER_API_KEY, MODEL, FALLBACK_MODEL, EMBEDDING_MODEL (fallback: openai/text-embedding-3-small)
11. prep-embed-chunks - OPENROUTER_API_KEY, EMBEDDING_MODEL (fallback: openai/text-embedding-3-small)
12. prep-compose-exam-blanc - OPENROUTER_API_KEY, MODEL, FALLBACK_MODEL, CHAT_MODEL
13. prep-analyze-trends - OPENROUTER_API_KEY, MODEL, FALLBACK_MODEL
14. academia-ai-assistant - OPENROUTER_API_KEY, MODEL, FALLBACK_MODEL
15. test-openrouter-validation - OPENROUTER_API_KEY, MODEL, FALLBACK_MODEL
16. test-openrouter-config - OPENROUTER_API_KEY, MODEL, EMBEDDING_MODEL, CHAT_MODEL

**Observation importante** : `bobodo-chat` n'a PAS de fallback pour OPENROUTER_EMBEDDING_MODEL, contrairement aux autres Edge Functions.

---

## 2. COMPARAISON DES ENVIRONNEMENTS

### 2.1 Environnement local (.env)

- **Clé API** : sk-or-v1-1...4fc6 (73 caractères)
- **Modèle chat** : meta-llama/Meta-Llama-3.1-70B-Instruct
- **Modèle embeddings** : NON DÉFINIE
- **Source** : academia_bobodo_backend/.env

### 2.2 Environnement Supabase (Edge Functions)

- **Clé API** : OPENROUTER_API_KEY (secret Supabase)
- **Modèle chat** : OPENROUTER_MODEL (secret Supabase)
- **Modèle embeddings** : OPENROUTER_EMBEDDING_MODEL (secret Supabase)
- **Source** : Deno.env.get() dans Edge Functions

### 2.3 Incohérence détectée

**Problème** : L'environnement local (.env) et l'environnement Supabase (secrets) utilisent potentiellement des clés différentes.

**Preuve** :
- Les tests locaux avec la clé du fichier .env échouent tous (HTTP 401)
- Les Edge Functions en production lisent les secrets Supabase, pas le fichier .env local
- Si OpenRouter fonctionnait en production, c'est que les secrets Supabase contiennent une clé valide différente

---

## 3. TESTS COMPARATIFS

### 3.1 Test Embeddings (openai/text-embedding-3-small)

**Environnement** : Local (.env)  
**Clé** : OPENROUTER_API_KEY du fichier .env  
**Résultat** : ❌ HTTP 401 "User not found"

### 3.2 Test Chat (google/gemini-2.5-flash)

**Environnement** : Local (.env)  
**Clé** : OPENROUTER_API_KEY du fichier .env  
**Résultat** : ❌ HTTP 401 "User not found"

### 3.3 Test Chat (meta-llama/Meta-Llama-3.1-70B-Instruct)

**Environnement** : Local (.env)  
**Clé** : OPENROUTER_API_KEY du fichier .env  
**Résultat** : ❌ HTTP 401 "User not found"

---

## 4. ORIGINE EXACTE DU PROBLÈME

### Diagnostic

**Problème identifié** : **Option B - Une clé remplacée**

**Explication** :

1. **La clé API du fichier .env local est invalide/expirée**
   - Tous les tests locaux échouent avec HTTP 401
   - La clé sk-or-v1-1...4fc6 n'est plus valide sur OpenRouter

2. **Les Edge Functions en production utilisent les secrets Supabase**
   - Elles ne lisent PAS le fichier .env local
   - Elles lisent OPENROUTER_API_KEY depuis Deno.env.get()

3. **Incohérence entre environnements**
   - Le fichier .env local contient une clé expirée
   - Les secrets Supabase contiennent probablement une clé valide différente
   - C'est pourquoi les audits précédents montraient OpenRouter fonctionnel (tests en production)

4. **Problème spécifique embeddings**
   - OPENROUTER_EMBEDDING_MODEL n'est PAS défini dans les secrets Supabase
   - `bobodo-chat` n'a PAS de fallback pour ce modèle
   - Même avec une clé valide, les embeddings échoueraient car le modèle n'est pas configuré

### Conclusion

Le problème provient de **deux causes** :

1. **Clé API locale invalide** : Le fichier .env contient une clé expirée (sk-or-v1-1...4fc6)
2. **Configuration embeddings manquante** : OPENROUTER_EMBEDDING_MODEL n'est pas défini dans les secrets Supabase

---

## 5. RECOMMANDATION DE CORRECTION MINIMALE

### Correction 1 : Mettre à jour les secrets Supabase

**Action requise** :

1. Ouvrir Supabase Dashboard
2. Aller dans Settings → Edge Functions
3. Ajouter/mettre à jour les secrets suivants :
   - `OPENROUTER_API_KEY` : Clé API valide OpenRouter
   - `OPENROUTER_MODEL` : meta-llama/Meta-Llama-3.1-70B-Instruct (ou google/gemini-2.5-flash)
   - `OPENROUTER_EMBEDDING_MODEL` : openai/text-embedding-3-small
   - `OPENROUTER_FALLBACK_MODEL` : google/gemini-2.5-flash (optionnel)

### Correction 2 : Mettre à jour le fichier .env local

**Action requise** :

1. Éditer `academia_bobodo_backend/.env`
2. Remplacer `OPENROUTER_API_KEY` par la même clé valide que dans Supabase
3. Ajouter `OPENROUTER_EMBEDDING_MODEL=openai/text-embedding-3-small`
4. Ajouter `OPENROUTER_FALLBACK_MODEL=google/gemini-2.5-flash` (optionnel)

### Correction 3 : Ajouter fallback dans bobodo-chat (optionnel)

**Action requise** :

Modifier `supabase/functions/bobodo-chat/index.ts` ligne 11 :

```typescript
const OPENROUTER_EMBEDDING_MODEL = Deno.env.get('OPENROUTER_EMBEDDING_MODEL') ?? 'openai/text-embedding-3-small';
```

Cela ajoutera un fallback comme dans les autres Edge Functions.

---

## 6. VALIDATION

Une fois les corrections appliquées :

1. Tester les embeddings avec le script `test_openrouter_comparative.py`
2. Vérifier que les Edge Functions peuvent générer des embeddings
3. Reconstruire les embeddings pour les 20 fiches non vectorisées
4. Valider le RAG avec les formulations de test

---

**RAPPORT TERMINÉ - DIAGNOSTIC ÉTABLI : CLÉ API LOCALE EXPIRÉE + CONFIGURATION EMBEDDINGS MANQUANTE**
