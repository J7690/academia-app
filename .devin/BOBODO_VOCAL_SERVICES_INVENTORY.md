# BOBODO VOCAL - INVENTAIRE DES SERVICES DÉPLOYÉS

**Date** : 10 juin 2026  
**Mission** : Inventaire des services déjà déployés sur Kamatera

---

## 1. DOCKER

### Statut

**Source** : `academia_app/docs/INFRASTRUCTURE_KAMATERA.md`

**LiveKit** : ✅ Déployé avec Docker
- Image : `livekit/livekit-server:latest`
- Network mode : `host`
- Compose : `/opt/livekit/docker-compose.yaml`

**Bobodo Vocal** : ⚠️ Prévu mais non déployé
- Dockerfile créé : `.windsurf/bobodo-vocal/Dockerfile`
- docker-compose.yml créé : `.windsurf/bobodo-vocal/docker-compose.yml`

---

## 2. DOCKER COMPOSE

### Statut

**LiveKit** : ✅ Déployé
- Fichier : `/opt/livekit/docker-compose.yaml`
- Services : livekit-server, redis

**Bobodo Vocal** : ⚠️ Prévu mais non déployé
- Fichier : `.windsurf/bobodo-vocal/docker-compose.yml`
- Services : bobodo-vocal

---

## 3. LIVEKIT

### Statut

**Déployé** : ✅ Oui

**Configuration** :
- IP : 185.167.97.144
- HTTP API : http://185.167.97.144:7880
- WebSocket : ws://185.167.97.144:7880
- API Key : APIKeylrmgQYJgiEZa
- API Secret : uXu7tiObNgaLkYA3VydinjsKRzPJjL8SNWC9pRx8
- Config : /opt/livekit/livekit.yaml
- Installé le : 2026-06-07

**Ports** :
- 7880/TCP (API)
- 7881/TCP (WebRTC TCP)
- 50000-60000/UDP (WebRTC media)

---

## 4. NGINX

### Statut

**Déployé** : ✅ Oui

**Configuration** :
- URL : http://185.167.97.144
- Status : http://185.167.97.144/status

**Note** : Utilisé pour reverse proxy et statut

---

## 5. SSL

### Statut

**Déployé** : ❌ Non documenté

**Note** : Aucun certificat SSL documenté dans l'infrastructure actuelle

**Recommandation** : Configurer SSL avec Let's Encrypt si nécessaire pour le service vocal

---

## 6. MONITORING

### Statut

**LiveKit Dashboard** : ✅ Disponible
- URL : http://185.167.97.144:7880

**pg_cron jobs** : ✅ Configurés
- purge_deleted_accounts (quotidien 3h)
- expire_subscriptions (quotidien 2h)
- reset_stale_processing_payments (30min)
- prep-feed-actuality (quotidien 5h)
- app_learning_presence_cleanup (à configurer)

**Monitoring dédié** : ❌ Non documenté

**Note** : Pas de monitoring dédié (Prometheus, Grafana, etc.) documenté

---

## 7. SERVICES ACADEMIA

### Supabase Edge Functions

**Déployées** : ✅ Oui (liste partielle)

**Bobodo** :
- bobodo-chat ✅

**Préparation Concours** :
- prep-tutor-chat ✅
- prep-ingest-document ✅
- prep-generate-questions ✅
- prep-analyze-trends ✅
- prep-grade-assignment ✅

**TD** :
- td-tutor-chat ✅
- td-scan-subject ✅
- td-generate-exercises ✅

**LiveKit** :
- livekit-token ⚠️ À déployer
- livekit-recording ⚠️ À déployer

---

### Supabase Storage

**Buckets** :
- prep-documents ✅
- td-documents ✅

---

### Supabase Database

**Schemas** :
- app ✅
- public ✅

**Tables** :
- bobodo_sessions ✅
- bobodo_messages ✅
- prep_* (32 tables) ✅
- td_* (tables) ✅

---

## 8. SERVICES REQUIS POUR BOBODO VOCAL

### À déployer

| Service | Statut actuel | Action requise |
|---------|---------------|----------------|
| Faster Whisper Medium | ❌ Non déployé | Télécharger modèle |
| Piper TTS | ❌ Non déployé | Télécharger modèle |
| FastAPI | ❌ Non déployé | Déployer via Docker |
| WebSocket | ❌ Non déployé | Déployer via FastAPI |
| Bobodo-chat Edge Function | ✅ Déployé | Aucune action |
| OpenRouter API | ⚠️ Key requise | Configurer secret |

---

## 9. CARTOGRAPHIE ACTUELLE

```
┌─────────────────────────────────────────────────────────────┐
│ Kamatera VPS (185.167.97.144)                                │
│ ─────────────────────────────────────────────────────────   │
│ ✅ LiveKit Server (Docker)                                   │
│ ✅ Redis (Docker)                                            │
│ ✅ Nginx                                                     │
│ ❌ Bobodo Vocal (à déployer)                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Supabase Cloud                                               │
│ ─────────────────────────────────────────────────────────   │
│ ✅ bobodo-chat Edge Function                                │
│ ✅ prep-* Edge Functions                                    │
│ ✅ td-* Edge Functions                                      │
│ ✅ Storage (prep-documents, td-documents)                   │
│ ✅ PostgreSQL (app, public schemas)                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 10. RECOMMANDATIONS

### Pour le déploiement Bobodo Vocal

1. **Utiliser Docker Compose** (déjà utilisé pour LiveKit)
2. **Co-localiser avec LiveKit** (même serveur ou nouveau serveur)
3. **Configurer secrets Supabase** (OPENROUTER_API_KEY)
4. **Télécharger modèles** (Faster Whisper Medium, Piper)
5. **Déployer via SSH** (nécessite accès fonctionnel)

---

## 11. CONCLUSION

### Services déjà déployés

- ✅ Docker
- ✅ Docker Compose
- ✅ LiveKit
- ✅ Nginx
- ✅ Redis
- ✅ Edge Functions Supabase
- ✅ Storage Supabase
- ✅ PostgreSQL Supabase

### Services à déployer

- ❌ Bobodo Vocal (FastAPI + WebSocket)
- ❌ Faster Whisper Medium
- ❌ Piper TTS
- ⚠️ SSL (optionnel)

### Blocage actuel

- ❌ Accès SSH non fonctionnel

---

**RAPPORT TERMINÉ**
