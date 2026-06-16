# BOBODO VOCAL - ARCHITECTURE TECHNIQUE

**Date** : 10 juin 2026  
**Version** : 1.0  
**Statut** : ✅ FINAL

---

## RÉSUMÉ EXÉCUTIF

Bobodo Vocal est une extension vocale de l'assistant IA Bobodo existant sur Academia. Il permet aux étudiants de poser des questions vocales et de recevoir des réponses audio, tout en conservant l'architecture textuelle existante.

**Architecture recommandée** : Service WebSocket dédié sur Kamatera
- STT : Faster-Whisper (modèle small)
- TTS : Piper (modèle medium)
- LLM : OpenRouter via Edge Function bobodo-chat existante
- Communication : WebSocket bidirectionnel
- Sécurité : TLS 1.3, authentification Supabase JWT

---

## ARCHITECTURE GLOBALE

```
┌─────────────────────────────────────────────────────────────┐
│ Flutter App (Mobile)                                        │
│ ─ BobodoProvider (extension audio)                          │
│ ─ WebSocket client (audio streaming)                       │
│ ─ Audio capture (microphone)                                │
│ ─ Audio playback (speaker)                                  │
│ ─ UI : bouton microphone, visualisation audio               │
└──────────┬──────────────────────────────────────────────────┘
           │ WebSocket (ws://vocal-server:9000, TLS 1.3)
           ▼
┌─────────────────────────────────────────────────────────────┐
│ Kamatera - Service Vocal (Dedicated)                        │
│ ─ WebSocket server (audio streaming)                       │
│ ─ Faster-Whisper (STT) : audio → text                      │
│ ─ HTTP POST → Edge Function bobodo-chat                     │
│ ─ Piper (TTS) : text → audio                               │
│ ─ WebSocket response (audio streaming)                      │
│ ─ Rate limiting, monitoring, logging                       │
└──────────┬──────────────────────────────────────────────────┘
           │ HTTP POST (TLS 1.3)
           ▼
┌─────────────────────────────────────────────────────────────┐
│ Supabase Edge Function bobodo-chat (existante)             │
│ ─ RAG vectoriel (pgvector)                                  │
│ ─ OpenRouter LLM                                            │
│ ─ Cache sémantique                                          │
│ ─ Mémoire conversationnelle                                 │
│ ─ Profil étudiant                                           │
└─────────────────────────────────────────────────────────────┘
```

---

## COMPOSANTS TECHNIQUES

### 1. Flutter (Client)

**Packages requis** :
- `flutter_sound` ou `record` : Capture audio
- `just_audio` ou `flutter_sound` : Playback audio
- `web_socket_channel` : WebSocket client
- `permission_handler` : Gestion permissions

**Nouveaux composants** :
- `BobodoVocalProvider` : Extension de BobodoProvider
- `VocalButton` : Bouton microphone avec animation
- `AudioVisualizer` : Visualisation onde sonore
- `VocalSettings` : Mode silencieux, préférences

**Flux audio** :
- Capture : WAV 16kHz mono
- Transmission : WebSocket (base64)
- Réception : WAV/MP3 streaming
- Playback : `just_audio`

---

### 2. Service Vocal (Kamatera)

**Technologies** :
- Python 3.11+
- FastAPI (WebSocket)
- Faster-Whisper (STT)
- Piper (TTS)
- Uvicorn (ASGI server)

**Endpoints** :
- WebSocket : `ws://vocal-server:9000/ws`
- Health : `http://vocal-server:9000/health`

**Configuration** :
- STT : Faster-Whisper small, INT8 quantization
- TTS : Piper medium, voix française
- Rate limiting : 100 req/min par utilisateur
- Connexions max : 50 (2 vCPU, 4 GB RAM)

---

### 3. Supabase (Edge Function)

**Edge Function** : `bobodo-chat` (existante, non modifiée)

**RPCs utilisées** :
- `app_get_or_create_bobodo_session`
- `app_list_bobodo_messages`
- `app_search_bobodo_knowledge_vector`
- `app_search_bobodo_knowledge`
- `app_add_bobodo_feedback`

**Aucune modification requise** :
- L'Edge Function reçoit du texte (via HTTP POST)
- Elle ne sait pas si le texte vient de STT ou de saisie clavier
- Architecture inchangée

---

## PROTOCOLE WEBSOCKET

### Connexion

**Client → Server** :
```json
{
  "type": "connect",
  "token": "supabase_jwt_token",
  "session_id": "bobodo_session_id"
}
```

**Server → Client** :
```json
{
  "type": "connected",
  "status": "ok"
}
```

---

### Streaming Audio (Client → Server)

**Client → Server** :
```json
{
  "type": "audio_chunk",
  "data": "base64_audio_data",
  "sequence": 1
}
```

**Server → Client** (transcription temps réel) :
```json
{
  "type": "transcription",
  "text": "Bonjour, comment puis-je vous aider ?",
  "is_final": false
}
```

---

### Fin Audio (Client → Server)

**Client → Server** :
```json
{
  "type": "audio_end"
}
```

---

### Réponse Texte (Server → Client)

**Server → Client** :
```json
{
  "type": "text_response",
  "text": "Pour accéder aux cours d'appui..."
}
```

---

### Streaming Audio (Server → Client)

**Server → Client** :
```json
{
  "type": "audio_chunk",
  "data": "base64_audio_data",
  "sequence": 1
}
```

---

### Erreurs

**Server → Client** :
```json
{
  "type": "error",
  "code": "transcription_failed",
  "message": "Je n'ai pas compris, peux-tu répéter ?"
}
```

---

## SÉCURITÉ

### Authentification

- Supabase JWT token requis à la connexion
- Vérification token via Supabase Auth
- Expiration token : 1h
- Reconnexion automatique

### Chiffrement

- WebSocket : TLS 1.3
- HTTP : HTTPS (TLS 1.3)
- Certificat SSL : Let's Encrypt

### Rate Limiting

- 100 req/min par utilisateur
- 50 connexions simultanées (serveur)
- Rejet au-delà des limites

### Confidentialité

- Audio : Non stocké (éphémère)
- Texte : Intégré dans conversation Bobodo existante
- Logs : Anonymisés (pas de contenu audio)

---

## PERFORMANCE

### Latence cible

- Capture → STT : 1-2s
- STT → LLM : 0.5s
- LLM → TTS : 1-2s
- **Total** : 2.5-4.5s

### Capacité

- **Phase 1** (lancement) : 10-15 utilisateurs simultanés
- **Phase 2** (croissance) : 25-30 utilisateurs simultanés
- **Phase 3** (expansion) : 50+ utilisateurs simultanés (load balancing)

### Ressources

- **STT** (Faster-Whisper small) : 2-3 vCPU, 2-4 GB RAM
- **TTS** (Piper medium) : 1-2 vCPU, 1-2 GB RAM
- **WebSocket** : 0.1 vCPU par connexion, 50 MB RAM par connexion

---

## SCALABILITÉ

### Vertical Scaling

- 2 vCPU, 4 GB RAM → 4 vCPU, 8 GB RAM : +$20/mois
- 4 vCPU, 8 GB RAM → 8 vCPU, 16 GB RAM : +$40/mois

### Horizontal Scaling

- Load balancer Nginx
- 2-3 serveurs identiques
- Redondance + failover

### Auto-scaling (optionnel)

- Seuil CPU > 80% : +1 serveur
- Seuil CPU < 30% : -1 serveur
- Délai : 5 min

---

## MONITORING

### Métriques

- CPU, RAM, bande passante
- Connexions actives
- Latence STT, LLM, TTS
- Taux d'erreur
- Utilisateurs simultanés

### Outils

- Prometheus + Grafana
- Logs structurés
- Alertes automatiques

---

## ALTERNATIVES ÉTUDIÉES

### Option A : LiveKit

**Rejeté** car :
- Surcharge serveur LiveKit existant
- Latence WebRTC inutile
- Complexité room management
- Pas optimisé pour STT/TTS

### Option B : HTTP REST

**Rejeté** car :
- Latence élevée (upload + traitement + download)
- Pas de streaming temps réel
- Taille fichiers audio

### Option C : STT/TTS Cloud (Google, Amazon, ElevenLabs)

**Rejeté** car :
- Coût élevé
- Dépendance internet
- Confidentialité (données envoyées à tiers)

---

## CONCLUSION

**Architecture recommandée** : Service WebSocket dédié sur Kamatera

**Avantages** :
- ✅ Performance optimale (latence < 5s)
- ✅ Isolation complète (pas d'impact LiveKit)
- ✅ Coût abordable ($39/mois)
- ✅ Sécurité renforcée (TLS 1.3, JWT)
- ✅ Conformité RGPD (audio non stocké)
- ✅ Scalabilité progressive

**Complexité** : Moyenne (1-2 semaines développement)

**Risque** : Faible (technologies éprouvées)

---

**DOCUMENT TERMINÉ**
