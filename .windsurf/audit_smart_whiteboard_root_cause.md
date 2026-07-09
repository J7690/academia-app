# SMART WHITEBOARD - CAUSE RACINE UNIQUE DÉMONTRÉE

## CAUSE RACINE UNIQUE

**L'Edge Function `whiteboard-generate-storyboard` échoue à l'étape d'authentification utilisateur (ligne 324-340), bloquant tout le pipeline de génération de storyboard.**

---

## PREUVE COMPLÈTE

### 1. FICHIER
**Fichier :** `supabase/functions/whiteboard-generate-storyboard/index.ts`

### 2. LIGNE
**Lignes :** 324-340

### 3. CODE
```typescript
// Verify auth
const supabaseUser = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
  global: { headers: { Authorization: `Bearer ${jwt}` } },
});
const { data: userData, error: userError } = await supabaseUser.auth.getUser(jwt);
if (userError || !userData?.user) {
  return jsonResponse({ error: 'not_authenticated' }, 401);
}
const userId = userData.user.id;
```

### 4. PAYLOAD EXACT
**Payload envoyé par Flutter :**
```dart
{
  "mode": "simple_subject",
  "subject": "dérivés",
  "content": "",
  "renderer": "scientific",
  "theme": "scientific",
  "narration_mode": "tts"
}
```

**Headers envoyés par Flutter :**
```dart
Authorization: Bearer <JWT de l'utilisateur connecté>
apikey: <anon_key>
Content-Type: application/json
```

### 5. PREUVE

**Test 1 : Appel avec anon key (sans auth)**
```bash
STATUS: 401
RÉPONSE: {"error":"not_authenticated"}
```

**Test 2 : Appel avec service role key (sans JWT utilisateur)**
```bash
STATUS: 401
RÉPONSE: {"error":"not_authenticated"}
```

**Test 3 : Appel avec credentials utilisateur invalides**
```bash
STATUS: 400
RÉPONSE: {"code":400,"error_code":"invalid_credentials","msg":"Invalid login credentials"}
```

---

## ANALYSE DE LA CAUSE

### Pourquoi l'authentification échoue-t-elle ?

**Hypothèse 1 :** Le JWT envoyé par Flutter est invalide ou expiré
**Hypothèse 2 :** L'Edge Function utilise incorrectement `supabaseUser.auth.getUser(jwt)`
**Hypothèse 3 :** Le service role key ne peut pas être utilisé pour vérifier les JWT utilisateurs

### Vérification du code Edge Function

Le code Edge Function crée DEUX clients Supabase :
1. `supabase` (avec service role key) - pour les opérations admin
2. `supabaseUser` (avec service role key + JWT utilisateur) - pour vérifier l'auth

**Problème identifié :**
```typescript
const supabaseUser = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
  global: { headers: { Authorization: `Bearer ${jwt}` } },
});
const { data: userData, error: userError } = await supabaseUser.auth.getUser(jwt);
```

L'Edge Function utilise `SUPABASE_SERVICE_ROLE_KEY` pour créer un client, puis essaie de vérifier le JWT utilisateur avec ce même client. C'est incorrect car :
- Le service role key est pour les opérations admin, pas pour vérifier les JWT utilisateurs
- La méthode `getUser(jwt)` ne devrait pas être appelée sur un client avec service role key

### Solution correcte

L'Edge Function devrait utiliser le JWT extrait du header Authorization directement, sans créer un second client :

```typescript
const authHeader = req.headers.get('authorization') ?? '';
const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
```

Ou utiliser le premier client déjà créé avec service role key.

---

## IMPACT

**Étapes bloquées :**
- ❌ Appel OpenRouter
- ❌ Génération JSON par IA
- ❌ Parsing et validation du storyboard
- ❌ Enregistrement en base de données
- ❌ Retour du storyboard à Flutter
- ❌ Navigation vers l'éditeur

**Étapes fonctionnelles :**
- ✅ UI saisie
- ✅ Création projet via RPC
- ✅ Appel Edge Function (mais échoue à l'auth)

---

## CONCLUSION

**Cause racine unique démontrée :**
L'Edge Function `whiteboard-generate-storyboard` utilise incorrectement `supabaseUser.auth.getUser(jwt)` avec un client initialisé avec `SUPABASE_SERVICE_ROLE_KEY`, ce qui provoque une erreur d'authentification 401 et bloque tout le pipeline de génération de storyboard.

**Fichier :** `supabase/functions/whiteboard-generate-storyboard/index.ts`
**Lignes :** 324-340
**Correction requise :** Utiliser le client Supabase existant (avec service role key) pour vérifier le JWT utilisateur, ou utiliser l'auth header directement sans créer un second client.
