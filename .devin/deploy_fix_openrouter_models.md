# Fix OpenRouter — Modèles cassés → ERREUR SERVEUR

## Problème identifié

Les étudiants reçoivent "ERREUR SERVEUR" car les modèles de la cascade OpenRouter sont obsolètes :
- ❌ `qwen/qwen3.6-plus:free` — supprimé d'OpenRouter
- ❌ `nvidia/nemotron-3-super-120b-a12b:free` — supprimé d'OpenRouter
- ⚠️ `google/gemini-2.0-flash-lite-001` — potentiellement renommé

Quand les 4 modèles échouent → status 502 → "ERREUR SERVEUR" côté Flutter.

## Fix appliqué (fichiers locaux)

Nouvelle cascade dans **toutes les Edge Functions** :
1. `google/gemini-2.0-flash-exp:free` — modèle free Google stable
2. `google/gemini-2.5-flash-preview-05-20` — low-cost Google dernière gen
3. `google/gemini-2.0-flash-001` — standard payant (très low cost)
4. `meta-llama/llama-4-maverick:free` — fallback Meta free

## Commandes de déploiement

### 1. Mettre à jour le secret OPENROUTER_MODEL
```bash
supabase secrets set OPENROUTER_MODEL=google/gemini-2.0-flash-exp:free
```

### 2. Redéployer les 8 fonctions affectées
```bash
supabase functions deploy prep-tutor-chat
supabase functions deploy td-tutor-chat
supabase functions deploy prep-generate-questions
supabase functions deploy td-generate-exercises
supabase functions deploy prep-grade-assignment
supabase functions deploy prep-compose-exam-blanc
supabase functions deploy bobodo-chat
supabase functions deploy academia-ai-assistant
```

### 3. (Optionnel) Si les scan-subject échouent aussi
```bash
supabase functions deploy prep-scan-subject
supabase functions deploy td-scan-subject
```

## Vérification

Après déploiement :
1. Ouvrir l'app en tant qu'étudiant
2. Aller dans Prépa Concours → Tuteur IA
3. Envoyer un message → doit recevoir une réponse (pas "ERREUR SERVEUR")
4. Vérifier les logs : `supabase functions logs prep-tutor-chat --limit 20`

## Fichiers modifiés
- `supabase/functions/prep-tutor-chat/index.ts`
- `supabase/functions/td-tutor-chat/index.ts`
- `supabase/functions/prep-generate-questions/index.ts`
- `supabase/functions/td-generate-exercises/index.ts`
- `supabase/functions/prep-grade-assignment/index.ts`
- `supabase/functions/prep-compose-exam-blanc/index.ts`
- `supabase/functions/bobodo-chat/index.ts`
