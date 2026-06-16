# BOBODO VOCAL - PHASE 2 : AUDIT ARCHITECTURE ACADEMIA

**Date** : 10 juin 2026  
**Statut** : ✅ TERMINÉ

---

## ARCHITECTURE ACTUELLE BOBODO

### Flutter (Client)

**Fichier** : `academia_app/lib/providers/bobodo_provider.dart`

**Fonctionnalités** :
- Gestion des sessions Bobodo
- Envoi de messages texte
- Chargement de l'historique
- Feedback utilisateur (up/down)
- Régénération de réponses
- Persistance via SharedPreferences

**Communication** :
- Edge Function : `bobodo-chat`
- Méthode : HTTP POST
- Authentification : Supabase JWT
- Payload : `{ session_id, message }`

---

### Supabase Edge Function (Backend)

**Fichier** : `supabase/functions/bobodo-chat/index.ts`

**Fonctionnalités** :
- Authentification via Supabase JWT
- Détection d'état émotionnel
- Recherche RAG (vectorielle + textuelle)
- Cache sémantique des réponses
- Historique conversationnel (14 messages)
- Profil étudiant (prénom, série BAC, etc.)
- Mémoire cross-session
- Résumé de conversation
- Appel OpenRouter (LLM)
- Fallback modèle
- Détection contenu sensible
- Refus questions universités

**RPCs Supabase utilisées** :
- `app_get_or_create_bobodo_session`
- `app_list_bobodo_messages`
- `app_add_bobodo_feedback`
- `app_search_bobodo_knowledge_vector`
- `app_search_bobodo_knowledge`
- `app_search_bobodo_answer_cache`
- `app_bobodo_cache_hit`
- `app_insert_bobodo_answer_cache`
- `get_bobodo_cross_session_memory`
- `save_bobodo_conversation_memory`

**Modèles OpenRouter** :
- Principal : `OPENROUTER_MODEL`
- Fallback : `OPENROUTER_FALLBACK_MODEL`
- Embeddings : `OPENROUTER_EMBEDDING_MODEL`
- Web Search : `perplexity/sonar-small-online` (fallback)

---

### Tables Supabase

**bobodo_sessions**
- id, student_id, title, created_at, updated_at

**bobodo_messages**
- id, session_id, sender, content, safety_flag, created_at

**bobodo_knowledge**
- id, title, content, category, tags, embedding, is_active, created_at

**bobodo_answer_cache**
- cache_id, question_text, question_embedding, answer_text, category, hit_count, created_at

**bobodo_conversation_memory**
- student_id, summary, interests, preferences, updated_at

**students**
- full_name, bac_series, bac_year, bac_mention, bac_institution, bac_country, bepc_year, bepc_mention, bepc_institution, bepc_country, study_project_text, country, city, bio

**applications**
- program_id, status, created_at

---

## POINTS D'INTÉGRATION VOCAL

### Option A : Intégration dans Edge Function bobodo-chat

**Avantages** :
- ✅ Réutilisation de l'architecture existante
- ✅ Pas de modification Flutter majeure
- ✅ Gestion centralisée du STT/TTS
- ✅ Authentification déjà en place

**Inconvénients** :
- ❌ Edge Function limitée en CPU/RAM
- ❌ Latence supplémentaire (STT + TTS)
- ❌ Dépendance OpenRouter pour embeddings STT

**Architecture proposée** :
```
Flutter (audio) → Edge Function bobodo-chat → STT (Whisper) → LLM (OpenRouter) → TTS (Piper) → Flutter (audio)
```

### Option B : Service dédié sur Kamatera

**Avantages** :
- ✅ Isolation des charges (STT/TTS)
- ✅ Meilleure performance
- ✅ Pas de limitation Edge Function
- ✅ Contrôle total des ressources

**Inconvénients** :
- ❌ Nouveau service à déployer
- ❌ Maintenance supplémentaire
- ❌ Coût serveur dédié

**Architecture proposée** :
```
Flutter (audio) → Service Vocal Kamatera → STT (Whisper) → Edge Function bobodo-chat → LLM (OpenRouter) → Service Vocal Kamatera → TTS (Piper) → Flutter (audio)
```

### Option C : Intégration directe dans Flutter

**Avantages** :
- ✅ Latence minimale (STT/TTS local)
- ✅ Pas de dépendance serveur
- ✅ Fonctionne offline

**Inconvénients** :
- ❌ Taille application augmentée
- ❌ Consommation batterie
- ❌ Performance variable selon device
- ❌ Mises à jour complexes

**Architecture proposée** :
```
Flutter (STT local) → Edge Function bobodo-chat → LLM (OpenRouter) → Flutter (TTS local)
```

---

## RECOMMANDATION ARCHITECTURE

**Option B : Service dédié sur Kamatera**

**Justification** :
1. **Performance** : STT/TTS nécessitent des ressources CPU/RAM importantes
2. **Scalabilité** : Service dédié permet une montée en charge progressive
3. **Isolation** : Pas d'impact sur LiveKit existant
4. **Flexibilité** : Possibilité d'optimiser Whisper/Piper sans contrainte Edge Function
5. **Maintenance** : Mise à jour des modèles indépendante

**Architecture détaillée** :
```
┌─────────────────────────────────────────────────────────────┐
│ Flutter App (Mobile)                                        │
│ ─ Audio capture (microphone)                                │
│ ─ Audio playback (speaker)                                  │
│ ─ WebSocket pour streaming audio                            │
└──────────┬──────────────────────────────────────────────────┘
           │ WebSocket (audio stream)
           ▼
┌─────────────────────────────────────────────────────────────┐
│ Kamatera - Service Vocal (Dedicated)                        │
│ ─ Whisper (STT) : audio → text                              │
│ ─ Edge Function bobodo-chat : text → response               │
│ ─ Piper (TTS) : response → audio                           │
│ ─ WebSocket pour streaming audio                            │
└──────────┬──────────────────────────────────────────────────┘
           │ HTTP POST (text)
           ▼
┌─────────────────────────────────────────────────────────────┐
│ Supabase Edge Function bobodo-chat                          │
│ ─ RAG vectoriel                                            │
│ ─ OpenRouter LLM                                            │
│ ─ Cache sémantique                                          │
│ ─ Mémoire conversationnelle                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## MODIFICATIONS REQUISES

### Flutter

1. **Capture audio** : Intégrer `flutter_sound` ou `record`
2. **WebSocket** : Streaming audio bidirectionnel
3. **UI** : Bouton microphone, animation vocal, mode silencieux
4. **Provider** : Extension de `BobodoProvider` pour audio

### Kamatera

1. **Service WebSocket** : Streaming audio
2. **Whisper** : Installation et configuration
3. **Piper** : Installation et configuration
4. **API Supabase** : Appel bobodo-chat
5. **Monitoring** : Logs, métriques

### Supabase

1. **Edge Function** : Aucune modification requise
2. **RPCs** : Aucune modification requise
3. **Tables** : Optionnel : logs audio (si conservation requise)

---

## COMPLEXITÉ

- **Flutter** : Moyenne (audio + WebSocket)
- **Kamatera** : Moyenne (service WebSocket + Whisper + Piper)
- **Supabase** : Faible (réutilisation existante)

---

**RAPPORT PHASE 2 TERMINÉ**
