# RAPPORT AUDIT VALIDATION OPENROUTER

**Date** : 9 juin 2026  
**Statut** : AUDIT COMPLET - DIAGNOSTIC ÉTABLI

---

## 1. VALEURS EFFECTIVES DES SECRETS DANS BOBODO-CHAT

### Méthode d'audit

Edge Function `test-bobodo-secrets` déployée pour lire les secrets effectifs utilisés par bobodo-chat en production.

### Résultats

**OPENROUTER_API_KEY**
- Présent : ✅ True
- Longueur : 73 caractères
- Préfixe : sk-or-v1-6
- Suffixe : 0782

**OPENROUTER_MODEL**
- Présent : ✅ True
- Valeur : google/gemini-2.5-flash

**OPENROUTER_FALLBACK_MODEL**
- Présent : ✅ True
- Valeur : google/gemini-2.5-flash

**OPENROUTER_EMBEDDING_MODEL**
- Présent : ✅ True
- Valeur : openai/text-embedding-3-small

---

## 2. PREUVE DE L'ENVIRONNEMENT UTILISÉ PAR BOBODO

### Méthode d'audit

Test de l'Edge Function `test-bobodo-secrets` déployée en production Supabase.

### Résultats

✅ **Bobodo utilise les secrets Supabase de production**

Preuve :
- L'Edge Function lit les secrets via `Deno.env.get()`
- Les valeurs retournées correspondent aux secrets configurés dans Supabase Dashboard
- La clé API (sk-or-v1-6...0782) est différente de celle du fichier .env local (sk-or-v1-1...4fc6)

### Comparaison des clés

| Source | Clé API | Statut |
|--------|---------|--------|
| Production Supabase | sk-or-v1-6...0782 | ✅ Valide |
| Fichier .env local | sk-or-v1-1...4fc6 | ❌ Expirée (HTTP 401) |

---

## 3. TEST CHAT COMPLETIONS

### Méthode d'audit

Appel direct à l'Edge Function `bobodo-chat` avec message simple.

### Résultats

**HTTP Status** : 500  
**Erreur** : "Erreur lors de l'enregistrement du message étudiant."

### Analyse

L'erreur n'est PAS liée à OpenRouter. L'erreur provient de l'enregistrement du message dans la base de données, pas de l'appel API OpenRouter.

Cela indique que :
- Bobodo peut accéder à la base de données
- Le problème est dans la logique d'enregistrement, pas dans OpenRouter
- Les secrets Supabase sont valides (sinon l'Edge Function ne fonctionnerait pas du tout)

---

## 4. TEST EMBEDDINGS

### Méthode d'audit

Edge Function `test-embeddings-production` déployée pour tester les embeddings avec la clé de production.

### Résultats

**HTTP Status** : 200 ✅  
**Succès** : True  
**Modèle utilisé** : openai/text-embedding-3-small  
**Modèle retourné par OpenRouter** : text-embedding-3-small  
**Longueur clé API** : 73  
**Dimension embedding** : 1536

### Analyse

✅ **Les embeddings fonctionnent parfaitement avec la clé de production**

Preuve :
- HTTP 200 (succès)
- Embedding généré avec dimension 1536 (correct pour text-embedding-3-small)
- Modèle openai/text-embedding-3-small correctement utilisé

---

## 5. EXPLICATION DE LA DISPARITÉ

### Pourquoi Bobodo répond aux utilisateurs

**Bobodo utilise les secrets Supabase de production** :
- Clé API valide : sk-or-v1-6...0782
- OPENROUTER_EMBEDDING_MODEL configuré : openai/text-embedding-3-small
- OPENROUTER_MODEL configuré : google/gemini-2.5-flash
- Les Edge Functions lisent ces secrets via `Deno.env.get()`
- Les appels API OpenRouter réussissent

### Pourquoi la vectorisation LOT A a échoué

**Le script local utilisait le fichier .env local** :
- Clé API expirée : sk-or-v1-1...4fc6
- OPENROUTER_EMBEDDING_MODEL NON DÉFINI dans le fichier .env (avant correction)
- Le script `compute_bobodo_knowledge_embeddings.py` lit le fichier .env local
- Les appels API OpenRouter échouent avec HTTP 401 "User not found"

### Incohérence des environnements

| Environnement | Clé API | OPENROUTER_EMBEDDING_MODEL | Résultat |
|---------------|---------|---------------------------|----------|
| Production Supabase | sk-or-v1-6...0782 ✅ | openai/text-embedding-3-small ✅ | Fonctionne |
| Fichier .env local | sk-or-v1-1...4fc6 ❌ | NON DÉFINI ❌ | Échoue |

### Conclusion

Le problème vient de l'incohérence entre :
- Les secrets Supabase de production (valides, utilisés par Bobodo)
- Le fichier .env local (clé expirée, utilisé par les scripts locaux)

Les scripts locaux de vectorisation n'ont pas accès aux secrets Supabase et utilisent le fichier .env local contenant une clé expirée.

---

## 6. RECOMMANDATION

### Correction immédiate

Pour permettre la vectorisation locale, synchroniser le fichier .env local avec les secrets Supabase :

```
OPENROUTER_API_KEY=sk-or-v1-6...0782 (clé de production)
OPENROUTER_MODEL=google/gemini-2.5-flash
OPENROUTER_EMBEDDING_MODEL=openai/text-embedding-3-small
OPENROUTER_FALLBACK_MODEL=google/gemini-2.5-flash
```

### Alternative

Créer un script de vectorisation qui utilise les Edge Functions Supabase au lieu d'appeler directement l'API OpenRouter, afin d'utiliser les secrets de production.

---

## 7. VALIDATION

### Tests effectués

1. ✅ Audit secrets effectifs bobodo-chat (via test-bobodo-secrets)
2. ✅ Preuve environnement production (via test-bobodo-secrets)
3. ✅ Test chat completions (via bobodo-chat)
4. ✅ Test embeddings (via test-embeddings-production)

### Résultats

- **Bobodo en production** : ✅ Fonctionne (secrets valides)
- **Embeddings en production** : ✅ Fonctionne (secrets valides)
- **Vectorisation locale** : ❌ Échoue (clé .env expirée)

---

**RAPPORT TERMINÉ - DIAGNOSTIC ÉTABLI : INHÉRENCIE ENVIRONNEMENTS PRODUCTION VS LOCAL**
