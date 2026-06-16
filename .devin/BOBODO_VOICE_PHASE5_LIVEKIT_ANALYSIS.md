# BOBODO VOCAL - PHASE 5 : INTÉGRATION LIVEKIT

**Date** : 10 juin 2026  
**Statut** : ✅ TERMINÉ

---

## CONTEXTE LIVEKIT ACTUEL

### Infrastructure existante

**Serveur** : Kamatera VPS
- IP : 185.167.97.144
- WebSocket : ws://185.167.97.144:7880
- HTTP API : http://185.167.97.144:7880
- Capacité : ~50 participants/room, ~10 rooms
- Bande passante : 100 Mbps

**Utilisation actuelle** :
- Live sessions (cours en direct)
- Recording (egress vers Supabase Storage)
- Flutter : `livekit_client` package intégré

---

## ANALYSE POUR BOBODO VOCAL

### Option A : Utiliser LiveKit pour Bobodo Vocal

**Architecture proposée** :
```
Flutter (audio) → LiveKit Room (1:1) → Service Vocal (STT/TTS) → Edge Function bobodo-chat → LiveKit Room → Flutter (audio)
```

**Avantages** :
- ✅ Infrastructure déjà déployée
- ✅ Gestion automatique WebRTC
- ✅ Streaming audio natif
- ✅ Recording intégré (conversation logging)
- ✅ Gestion reconnexion automatique
- ✅ Évolutivité (scaling rooms)

**Inconvénients** :
- ❌ Surcharge serveur LiveKit existant
- ❌ Latence supplémentaire (WebRTC overhead)
- ❌ Complexité architecture (room management)
- ❌ Coût bande passante (100 Mbps partagé)
- ❌ Pas optimisé pour STT/TTS (audio full duplex non requis)

**Coût serveur** :
- Aucun (réutilisation existante)
- Risque surcharge : élevé

**Complexité** :
- Élevée (room management, token generation, WebRTC)

---

### Option B : WebSocket dédié pour Bobodo Vocal

**Architecture proposée** :
```
Flutter (audio) → WebSocket dédié → Service Vocal (STT/TTS) → Edge Function bobodo-chat → WebSocket dédié → Flutter (audio)
```

**Avantages** :
- ✅ Isolation complète (pas d'impact LiveKit)
- ✅ Latence minimale (WebSocket direct)
- ✅ Contrôle total du flux audio
- ✅ Optimisé pour STT/TTS (streaming unidirectionnel)
- ✅ Simple à implémenter
- ✅ Scalabilité indépendante

**Inconvénients** :
- ❌ Nouveau service à déployer
- ❌ Pas de recording intégré
- ❌ Gestion reconnexion manuelle
- ❌ Coût serveur dédié

**Coût serveur** :
- Nouveau VPS : ~$39/mois (Kamatera)
- Ou upgrade serveur existant : +$20/mois

**Complexité** :
- Moyenne (WebSocket simple)

---

### Option C : HTTP REST API (audio upload/download)

**Architecture proposée** :
```
Flutter (audio) → HTTP POST (audio) → Service Vocal (STT) → Edge Function bobodo-chat → Service Vocal (TTS) → HTTP GET (audio) → Flutter (audio)
```

**Avantages** :
- ✅ Simple à implémenter
- ✅ Pas de gestion connexion
- ✅ Compatible tous devices
- ✅ Pas de WebSocket

**Inconvénients** :
- ❌ Latence élevée (upload + traitement + download)
- ❌ Pas de streaming (temps réel impossible)
- ❌ Taille fichiers audio
- ❌ Pas optimisé conversation

**Coût serveur** :
- Faible (HTTP simple)

**Complexité** :
- Faible (HTTP standard)

---

## RECOMMANDATION

**Option B : WebSocket dédié pour Bobodo Vocal**

**Justification** :
1. **Performance** : Latence minimale (WebSocket direct)
2. **Isolation** : Pas d'impact sur LiveKit existant
3. **Optimisation** : Flux audio optimisé pour STT/TTS
4. **Simplicité** : WebSocket simple vs WebRTC complexe
5. **Scalabilité** : Indépendant de LiveKit
6. **Coût** : Abordable (nouveau VPS ou upgrade)

**Architecture détaillée** :
```
┌─────────────────────────────────────────────────────────────┐
│ Flutter App                                                 │
│ ─ WebSocket client (audio streaming)                       │
│ ─ Audio capture (microphone)                                │
│ ─ Audio playback (speaker)                                  │
└──────────┬──────────────────────────────────────────────────┘
           │ WebSocket (ws://vocal-server:9000)
           ▼
┌─────────────────────────────────────────────────────────────┐
│ Kamatera - Service Vocal (Dedicated)                        │
│ ─ WebSocket server (audio streaming)                       │
│ ─ Faster-Whisper (STT) : audio → text                      │
│ ─ HTTP POST → Edge Function bobodo-chat                     │
│ ─ Piper (TTS) : text → audio                               │
│ ─ WebSocket response (audio streaming)                      │
└─────────────────────────────────────────────────────────────┘
```

---

## LIVEKIT : À ÉVITER POUR BOBODO VOCAL

**Raisons** :
1. **Surcharge** : LiveKit déjà utilisé pour Live Sessions (50 participants/room)
2. **Latence** : WebRTC overhead inutile pour STT/TTS
3. **Complexité** : Room management non requis pour conversation 1:1
4. **Coût** : Bande passante partagée (100 Mbps)
5. **Optimisation** : LiveKit optimisé pour vidéo, pas pour STT/TTS

**Cas d'utilisation LiveKit** :
- ✅ Live Sessions (vidéo + audio)
- ✅ Group calls
- ✅ Recording (egress)
- ✅ Screen sharing

**Cas d'utilisation Bobodo Vocal** :
- ❌ Conversation 1:1 (audio uniquement)
- ❌ STT/TTS (traitement audio)
- ❌ Latence critique (< 500ms)

---

## ARCHITECTURE RECOMMANDÉE

**Service Vocal dédié avec WebSocket**

**Composants** :
1. **WebSocket Server** : Streaming audio bidirectionnel
2. **Faster-Whisper** : STT (audio → text)
3. **HTTP Client** : Appel Edge Function bobodo-chat
4. **Piper** : TTS (text → audio)
5. **Audio Buffer** : Gestion flux audio

**Flux** :
1. Client connecte WebSocket
2. Client envoie audio (streaming)
3. Serveur transcrit audio (Faster-Whisper)
4. Serveur envoie texte à bobodo-chat
5. Serveur reçoit réponse
6. Serveur synthétise audio (Piper)
7. Serveur envoie audio (streaming)
8. Client joue audio

**Protocole WebSocket** :
```json
// Client → Server
{
  "type": "audio_chunk",
  "data": "base64_audio_data"
}

// Server → Client
{
  "type": "text",
  "data": "transcribed_text"
}

// Server → Client
{
  "type": "audio_chunk",
  "data": "base64_audio_data"
}
```

---

## COÛT ESTIMÉ

**Option A (LiveKit)** : $0 (réutilisation)
- Risque surcharge : élevé
- Performance : moyenne

**Option B (WebSocket dédié)** : $39/mois
- Nouveau VPS Kamatera (2 vCPU, 4 GB RAM)
- Performance : élevée
- Isolation : complète

**Option C (HTTP REST)** : $20/mois (upgrade)
- Upgrade serveur existant
- Performance : faible
- Latence : élevée

---

## COMPLEXITÉ

| Option | Complexité | Temps implémentation |
|--------|------------|----------------------|
| LiveKit | Élevée | 2-3 semaines |
| WebSocket dédié | Moyenne | 1-2 semaines |
| HTTP REST | Faible | 1 semaine |

---

## CONCLUSION

**Recommandation** : **Option B - WebSocket dédié**

**Raisons** :
- ✅ Performance optimale
- ✅ Isolation complète
- ✅ Complexité raisonnable
- ✅ Coût abordable
- ✅ Scalabilité indépendante

**LiveKit à éviter** pour Bobodo Vocal car :
- ❌ Surcharge serveur existant
- ❌ Latence WebRTC inutile
- ❌ Complexité room management
- ❌ Pas optimisé pour STT/TTS

---

**RAPPORT PHASE 5 TERMINÉ**
