# BOBODO VOCAL - RAPPORT INFRASTRUCTURE RÉELLE

**Date** : 10 juin 2026  
**Source** : Données réelles Supabase (secrets, Edge Functions)

---

## 1. DONNÉES SUPABASE RÉELLES

### Secrets Supabase configurés

**Source** : `supabase secrets list` (exécution réelle)

| Secret | Statut | Utilisation |
|--------|--------|-------------|
| LIVEKIT_API_KEY | ✅ Configuré | LiveKit authentication |
| LIVEKIT_API_SECRET | ✅ Configuré | LiveKit authentication |
| LIVEKIT_HOST | ✅ Configuré | LiveKit host |
| LIVEKIT_URL | ✅ Configuré | LiveKit WebSocket URL |
| OPENROUTER_API_KEY | ✅ Configuré | OpenRouter API |
| OPENROUTER_MODEL | ✅ Configuré | OpenRouter model |
| OPENROUTER_FALLBACK_MODEL | ✅ Configuré | OpenRouter fallback |
| OPENROUTER_EMBEDDING_MODEL | ✅ Configuré | OpenRouter embeddings |
| LIGDICASH_API_KEY | ✅ Configuré | LigdiCash payments |
| LIGDICASH_BEARER_TOKEN | ✅ Configuré | LigdiCash auth |
| LIGDICASH_MODE | ✅ Configuré | LigdiCash mode |
| FCM_SERVICE_ACCOUNT_JSON | ✅ Configuré | Firebase push notifications |
| TWILIO_ACCOUNT_SID | ✅ Configuré | Twilio SMS |
| TWILIO_AUTH_TOKEN | ✅ Configuré | Twilio auth |
| TWILIO_FROM_NUMBER | ✅ Configuré | Twilio sender |
| TWILIO_VERIFY_SERVICE_SID | ✅ Configuré | Twilio verify |

**Note** : Tous les secrets sont configurés et actifs

---

### Edge Functions Supabase déployées

**Source** : `supabase functions list` (exécution réelle)

**Total** : 45 Edge Functions déployées

**Bobodo** :
- bobodo-chat ✅ ACTIVE (version 62, 2026-06-09)
- bobodo-generate-embeddings ✅ ACTIVE (version 2, 2026-06-09)

**LiveKit** :
- livekit-token ✅ ACTIVE (version 24, 2026-04-21)
- livekit-recording ✅ ACTIVE (version 12, 2026-04-21)

**Préparation Concours** :
- prep-tutor-chat ✅ ACTIVE
- prep-ingest-document ✅ ACTIVE
- prep-generate-questions ✅ ACTIVE
- prep-analyze-trends ✅ ACTIVE
- prep-grade-assignment ✅ ACTIVE
- prep-scan-subject ✅ ACTIVE
- prep-feed-actuality ✅ ACTIVE
- prep-compose-exam-blanc ✅ ACTIVE
- prep-embed-chunks ✅ ACTIVE

**TD** :
- td-tutor-chat ✅ ACTIVE
- td-ingest-document ✅ ACTIVE
- td-generate-exercises ✅ ACTIVE
- td-scan-subject ✅ ACTIVE

**LigdiCash** :
- ligdicash-initiate ✅ ACTIVE
- ligdicash-confirm ✅ ACTIVE
- ligdicash-callback ✅ ACTIVE
- ligdicash-payout ✅ ACTIVE
- ligdicash-diag ✅ ACTIVE

**Autres** :
- send-push-notifications ✅ ACTIVE
- admin-create-* (multiple) ✅ ACTIVE
- transcode-* (multiple) ✅ ACTIVE
- assemble-video-chunks ✅ ACTIVE
- merge-video-segments ✅ ACTIVE

---

## 2. ANALYSE DE L'INFRASTRUCTURE RÉELLE

### Services externes appelés

**Basé sur les secrets Supabase** :

1. **LiveKit** : ✅ Configuré et actif
   - API Key : LIVEKIT_API_KEY
   - API Secret : LIVEKIT_API_SECRET
   - Host : LIVEKIT_HOST
   - URL : LIVEKIT_URL

2. **OpenRouter** : ✅ Configuré et actif
   - API Key : OPENROUTER_API_KEY
   - Model : OPENROUTER_MODEL
   - Fallback : OPENROUTER_FALLBACK_MODEL
   - Embeddings : OPENROUTER_EMBEDDING_MODEL

3. **LigdiCash** : ✅ Configuré et actif
   - API Key : LIGDICASH_API_KEY
   - Bearer Token : LIGDICASH_BEARER_TOKEN
   - Mode : LIGDICASH_MODE

4. **Firebase** : ✅ Configuré et actif
   - Service Account : FCM_SERVICE_ACCOUNT_JSON

5. **Twilio** : ✅ Configuré et actif
   - Account SID : TWILIO_ACCOUNT_SID
   - Auth Token : TWILIO_AUTH_TOKEN
   - From Number : TWILIO_FROM_NUMBER
   - Verify Service : TWILIO_VERIFY_SERVICE_SID

---

### Configuration LiveKit

**Basé sur les secrets Supabase** :

- LIVEKIT_API_KEY : Configuré
- LIVEKIT_API_SECRET : Configuré
- LIVEKIT_HOST : Configuré
- LIVEKIT_URL : Configuré

**Note** : Les valeurs réelles ne sont pas visibles (seul le digest est affiché), mais les secrets sont actifs

---

## 3. RÉPONSE AUX 3 QUESTIONS

### Question 1 : Quel est le serveur Kamatera réellement utilisé aujourd'hui par Academia ?

**Réponse** : Impossible à déterminer avec certitude depuis Supabase

**Raison** :
- Les secrets Supabase ne contiennent que les clés API LiveKit, pas l'IP du serveur
- L'API Kamatera n'est pas accessible (timeout)
- Les fichiers `.env` locaux ne sont pas fiables (directive corrective)

**Données disponibles** :
- Edge Function livekit-token est ACTIVE
- Secrets LiveKit sont configurés
- Mais l'IP du serveur n'est pas dans Supabase

---

### Question 2 : Pourquoi l'accès SSH actuellement testé échoue-t-il ?

**Réponse** : Impossible à déterminer avec certitude

**Raisons possibles** :
1. **Mot de passe incorrect** : Les identifiants dans les fichiers locaux peuvent être obsolètes
2. **IP incorrecte** : L'IP dans les fichiers locaux peut être obsolète
3. **Serveur désactivé** : Le serveur peut avoir été désactivé ou recréé
4. **Méthode d'authentification différente** : Peut utiliser clé SSH au lieu de mot de passe
5. **Firewall** : Le port SSH peut être bloqué

**Preuves** :
- Les identifiants SSH proviennent de fichiers locaux (non fiables)
- L'API Kamatera n'est pas accessible pour vérifier
- Aucune information d'authentification dans Supabase

---

### Question 3 : Où exactement Bobodo Vocal doit-il être déployé dans l'infrastructure existante ?

**Réponse** : Impossible à déterminer sans accès au serveur Kamatera

**Options basées sur l'architecture** :

**Option A** : Co-localiser avec LiveKit
- Si LiveKit est sur un serveur dédié
- Déployer Bobodo Vocal sur le même serveur
- Avantages : Partage des ressources, latence réduite

**Option B** : Nouveau conteneur sur le même serveur
- Si le serveur LiveKit a des ressources suffisantes
- Déployer Bobodo Vocal dans un conteneur Docker séparé
- Avantages : Isolation, gestion simplifiée

**Option C** : Serveur dédié Bobodo Vocal
- Si le serveur LiveKit n'a pas de ressources suffisantes
- Déployer Bobodo Vocal sur un nouveau serveur
- **BLOQUÉ** : Directive corrective interdit nouveau serveur

**Conclusion** : Sans accès au serveur Kamatera, impossible de déterminer l'option appropriée

---

## 4. BLOCAGES ACTUELS

### Blocage 1 : API Kamatera inaccessible

**Symptôme** : Timeout lors de la connexion à console.kamatera.com

**Impact** : Impossible de lister les serveurs, vérifier l'état, obtenir les IP

---

### Blocage 2 : Accès SSH non fonctionnel

**Symptôme** : Authentication failed

**Impact** : Impossible de déployer le service vocal

---

### Blocage 3 : IP serveur inconnue

**Symptôme** : L'IP n'est pas dans Supabase

**Impact** : Impossible de savoir quel serveur utiliser

---

## 5. RECOMMANDATIONS

### Recommandation 1 : Obtenir l'accès au dashboard Kamatera

**Action** :
- Accéder au dashboard web Kamatera
- Lister les serveurs actifs
- Obtenir les IP correctes
- Réinitialiser les accès SSH si nécessaire

**Justification** : C'est la seule méthode fiable pour obtenir les informations réelles

---

### Recommandation 2 : Contacter le support Kamatera

**Action** :
- Demander assistance pour l'accès API
- Demander assistance pour l'accès SSH
- Obtenir les informations serveur

**Justification** : Support officiel peut résoudre les problèmes d'accès

---

### Recommandation 3 : Utiliser les Edge Functions Supabase

**Action** :
- Déployer Bobodo Vocal comme Edge Function Supabase
- Utiliser OpenRouter pour STT/TTS
- Éviter l'infrastructure Kamatera

**Justification** :
- Supabase est accessible
- OpenRouter est déjà configuré
- Évite les problèmes d'accès Kamatera

---

## 6. CONCLUSION

### Réponses aux 3 questions

1. **Serveur Kamatera** : ❌ Impossible à déterminer
2. **Pourquoi SSH échoue** : ❌ Impossible à déterminer
3. **Où déployer Bobodo Vocal** : ❌ Impossible à déterminer

### Blocage principal

**Accès Kamatera** : API timeout + SSH authentication failed

### Solution recommandée

**Obtenir l'accès au dashboard Kamatera** pour récupérer les informations réelles

---

**RAPPORT TERMINÉ**
