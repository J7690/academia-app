# P0 — AUDIT DE DÉPLOIEMENT DU WORKER VIDÉO SUR KAMATERA

**Date :** 19 Juin 2026  
**Objectif :** Audit de faisabilité pour le déploiement du worker vidéo sur le VPS Kamatera

---

## 1. ARCHITECTURE ACTUELLE

### 1.1 VPS Kamatera

| Paramètre | Valeur |
|-----------|--------|
| **IP** | 185.167.97.144 |
| **OS** | Ubuntu 24.04.4 LTS |
| **CPU** | Intel Xeon Processor (SapphireRapids) @ 2.0GHz - 4 coeurs |
| **RAM** | 9.7 Go total (1.6 Go utilisé, 8.2 Go disponible) |
| **Disque** | 30 Go total (17 Go utilisé, 12 Go disponible, 58%) |
| **Load avg** | 0.08 (1 min), 0.05 (5 min), 0.01 (15 min) |
| **Docker** | 29.5.3 (installé) |
| **FFmpeg** | 6.1.1-3ubuntu5 (installé) |

### 1.2 Services actifs

| Service | Mode | Ressources |
|---------|------|------------|
| LiveKit Server | Conteneur Docker (livekit-server:latest) | CPU: 0.52%, RAM: 37.33 MiB |
| Redis | Service systemd | RAM: 4.5 MiB |
| Nginx | Service systemd | RAM: 4.5 MiB |

### 1.3 Docker

| Élément | Valeur |
|--------|--------|
| **Conteneurs actifs** | 1 (livekit-server) |
| **Images** | 1 (livekit/livekit-server:latest - 117 MB) |
| **Réseaux** | bridge, host, none |
| **Volumes** | 0 |
| **Espace Docker** | 8.9 GB (images) + 8.1 GB (conteneurs) + 8.8 GB (build cache) |

### 1.4 FFmpeg

| Paramètre | Valeur |
|-----------|--------|
| **Version** | 6.1.1-3ubuntu5 |
| **Encoders H264** | libx264, libx264rgb, h264_nvenc, h264_qsv, h264_v4l2m2m, h264_vaapi |
| **Decoders H264** | h264, h264_v4l2m2m, h264_qsv, h264_cuvid |
| **Encoders AAC** | aac |
| **Decoders AAC** | aac, aac_fixed, aac_latm |
| **HW Accels** | vdpau, cuda, vaapi, qsv, drm, opencl, vulkan |
| **Formats** | MP4, H264, MOV |
| **Protocoles** | HTTP, HTTPS, FTP, HLS, file |

---

## 2. ARCHITECTURE CIBLE

### 2.1 Déploiement proposé

```
Kamatera VPS (185.167.97.144)
├── LiveKit Server (conteneur Docker) - EXISTANT
├── Redis (service systemd) - EXISTANT
├── Nginx (service systemd) - EXISTANT
└── Video Asset Worker (conteneur Docker) - NOUVEAU
    ├── Image: python:3.11-slim + FFmpeg
    ├── Command: python -u videoasset_worker.py
    ├── Variables: SUPABASE_URL, SUPABASE_SERVICE_KEY, WORKER_LOOP=1, WORKER_INTERVAL_SECONDS=2, WORKER_MAX_JOBS=3
    └── Volumes: /tmp/academia_render:/tmp, ./assets/images:/assets/images:ro
```

### 2.2 Flux du worker

```
Job queued (video_processing_jobs)
↓
Job lock (status=running, locked_at, locked_by)
↓
Téléchargement source depuis Supabase Storage
↓
FFmpeg transcodage (main, 480p, 360p, 240p)
↓
Upload renditions vers Supabase Storage
↓
Update video_renditions (status=ready)
↓
Update video_assets (status=ready)
↓
Job completed (status=done)
```

---

## 3. ANALYSE DU WORKER

### 3.1 Dépendances

**Variables d'environnement requises :**
- `SUPABASE_URL` - URL Supabase
- `SUPABASE_SERVICE_KEY` - Clé service Supabase
- `VIDEO_ASSET_BUCKET` - Bucket vidéo (défaut: video-assets)
- `SUPABASE_PROXY_URL` - (optionnel) Proxy backend
- `SUPABASE_HTTP_TIMEOUT` - (optionnel) Timeout HTTP (défaut: 30s)
- `WATERMARK_LOGO_PATH` - Chemin logo watermark
- `WORKER_LOOP` - Mode boucle (1 ou 0)
- `WORKER_INTERVAL_SECONDS` - Intervalle polling (défaut: 2s)
- `WORKER_MAX_JOBS` - Jobs max par itération (défaut: 3)

**Endpoints requis :**
- Supabase REST API: `/rest/v1/video_processing_jobs`
- Supabase REST API: `/rest/v1/video_sources`
- Supabase REST API: `/rest/v1/video_renditions`
- Supabase REST API: `/rest/v1/video_assets`
- Supabase Storage: `/storage/v1/object/{bucket}/{path}`

**RPCs requis :**
- Aucun (le worker utilise uniquement l'API REST Supabase)

**Buckets requis :**
- `video-assets` - Stockage vidéos

**Tables requises :**
- `video_processing_jobs` - Queue de jobs
- `video_sources` - Sources vidéos
- `video_renditions` - Renditions transcoded
- `video_assets` - Métadonnées vidéos

### 3.2 Compatibilité

**Sans Railway :**
- ✅ Le worker peut fonctionner sans Railway
- ✅ Il communique directement avec Supabase via l'API REST
- ✅ Le proxy backend (SUPABASE_PROXY_URL) est optionnel

**Depuis Kamatera :**
- ✅ Le worker peut fonctionner depuis Kamatera
- ✅ Kamatera dispose de Docker et FFmpeg
- ✅ Kamatera peut accéder à Supabase via Internet
- ✅ Les ressources sont suffisantes (RAM, CPU, disque)

**Avec Supabase :**
- ✅ Le worker est compatible avec Supabase
- ✅ Il utilise l'API REST standard de Supabase
- ✅ Il utilise le service_role_key pour l'authentification

### 3.3 Jobs supportés

| Type de job | Supporté | Action |
|-------------|----------|--------|
| `generate_hls` | ✅ Oui | Transcodage multi-résolution (main, 480p, 360p, 240p) |
| `generate_mp4` | ✅ Oui | Transcodage multi-résolution (main, 480p, 360p, 240p) |
| `export_watermarked` | ✅ Oui | Watermark TikTok-style |
| `generate_thumbs` | ❌ Non | Marqué done sans effet |
| `extract_metadata` | ❌ Non | Marqué done sans effet |

---

## 4. VALIDATION DE LA QUEUE

### 4.1 Répartition réelle (vérifié via RPC admin_execute_sql)

| Status | Count | Pourcentage |
|--------|-------|-------------|
| done | 381 | 89.6% |
| failed | 44 | 10.4% |
| queued | 0 | 0% |
| processing | 0 | 0% |
| **Total** | **425** | **100%** |

### 4.2 Ancienneté

| Paramètre | Valeur |
|-----------|--------|
| **Job le plus ancien** | 2025-12-13T16:50:33.957403+00:00 (failed, generate_mp4) |
| **Job le plus récent** | 2026-06-19T15:10:59.128207+00:00 (done, extract_metadata) |
| **Backlog queued** | 0 jobs |
| **Jobs failed** | 44 jobs |

### 4.3 Types de jobs

| Type de job | Count | Pourcentage |
|-------------|-------|-------------|
| generate_thumbs | 134 | 31.5% |
| generate_mp4 | 134 | 31.5% |
| extract_metadata | 123 | 28.9% |
| export_watermarked | 21 | 4.9% |
| generate_hls | 13 | 3.1% |
| **Total** | **425** | **100%** |

### 4.4 Jobs par status et type

| Status | Type | Count |
|--------|------|-------|
| done | generate_thumbs | 124 |
| done | generate_mp4 | 115 |
| done | extract_metadata | 121 |
| done | generate_hls | 8 |
| done | export_watermarked | 13 |
| failed | generate_thumbs | 10 |
| failed | generate_mp4 | 19 |
| failed | extract_metadata | 2 |
| failed | generate_hls | 5 |
| failed | export_watermarked | 8 |

---

## 5. ESTIMATION DE CAPACITÉ

### 5.1 Cas 1: Vidéo 30 secondes, 720p

**Paramètres :**
- Durée: 30 secondes
- Résolution: 1280x720 (720p)
- Codec: H.264 (libx264)
- Audio: AAC
- Renditions: main (720p), 480p, 360p, 240p

**Estimation temps d'encodage :**
- 720p → 720p (main): ~5-10 secondes
- 720p → 480p: ~3-5 secondes
- 720p → 360p: ~2-3 secondes
- 720p → 240p: ~1-2 secondes
- **Total estimé: 11-20 secondes**

**Estimation ressources :**
- CPU: ~50-70% (1-2 coeurs)
- RAM: ~200-300 Mo
- Disque temporaire: ~50-100 Mo

### 5.2 Cas 2: Vidéo 2 minutes, 1080p

**Paramètres :**
- Durée: 120 secondes
- Résolution: 1920x1080 (1080p)
- Codec: H.264 (libx264)
- Audio: AAC
- Renditions: main (1080p), 480p, 360p, 240p

**Estimation temps d'encodage :**
- 1080p → 1080p (main): ~30-60 secondes
- 1080p → 480p: ~15-25 secondes
- 1080p → 360p: ~10-15 secondes
- 1080p → 240p: ~5-10 secondes
- **Total estimé: 60-110 secondes**

**Estimation ressources :**
- CPU: ~70-90% (2-3 coeurs)
- RAM: ~300-500 Mo
- Disque temporaire: ~200-400 Mo

### 5.3 Cas 3: Vidéo 5 minutes, 1080p

**Paramètres :**
- Durée: 300 secondes
- Résolution: 1920x1080 (1080p)
- Codec: H.264 (libx264)
- Audio: AAC
- Renditions: main (1080p), 480p, 360p, 240p

**Estimation temps d'encodage :**
- 1080p → 1080p (main): ~90-180 secondes
- 1080p → 480p: ~45-75 secondes
- 1080p → 360p: ~30-45 secondes
- 1080p → 240p: ~15-30 secondes
- **Total estimé: 180-330 secondes (3-5.5 minutes)**

**Estimation ressources :**
- CPU: ~80-100% (3-4 coeurs)
- RAM: ~500-800 Mo
- Disque temporaire: ~500-1000 Mo

---

## 6. COEXISTENCE AVEC LIVEKIT

### 6.1 Impact sur LiveKit

**Ressources LiveKit actuelles :**
- CPU: 0.52%
- RAM: 37.33 MiB
- Réseau: 0 B/s (idle)

**Impact estimé du worker :**
- CPU: +50-100% lors de l'encodage
- RAM: +200-800 Mo lors de l'encodage
- Réseau: +10-50 Mbps (upload Supabase)

**Impact sur LiveKit :**
- **CPU:** Le worker peut utiliser 50-100% du CPU pendant l'encodage, ce qui peut affecter la latence de LiveKit si plusieurs sessions sont actives simultanément.
- **RAM:** Le worker utilise 200-800 Mo, ce qui est acceptable (8.2 Go disponible).
- **Réseau:** Le worker peut consommer 10-50 Mbps pour l'upload vers Supabase, ce qui peut affecter la bande passante de LiveKit si plusieurs streams sont actifs.

### 6.2 Impact sur Redis

**Ressources Redis actuelles :**
- RAM: 4.5 MiB
- CPU: Négligeable

**Impact estimé du worker :**
- Aucun impact direct (le worker n'utilise pas Redis)

### 6.3 Impact sur le réseau

**Bande passante disponible :**
- Kamatera: 100 Mbps (standard)

**Consommation estimée :**
- LiveKit: ~1-5 Mbps par participant (variable)
- Worker: ~10-50 Mbps lors de l'upload

**Impact :**
- Si LiveKit a 10 participants actifs (~10-50 Mbps), le worker peut saturer la bande passante.
- Recommandation: Limiter le worker à 1 job concurrent ou utiliser la gestion de la bande passante.

### 6.4 Capacité simultanée

**Question :** Le VPS actuel peut-il héberger simultanément LiveKit et le worker vidéo ?

**Réponse :** **OUI, avec des contraintes**

**Conditions :**
- ✅ RAM suffisante (8.2 Go disponible)
- ✅ Disque suffisant (12 Go disponible)
- ⚠️ CPU limité (4 coeurs) - risque de contention
- ⚠️ Réseau limité (100 Mbps) - risque de saturation

**Recommandations :**
- Limiter le worker à 1 job concurrent (WORKER_MAX_JOBS=1)
- Utiliser la gestion de la priorité CPU (nice/ionice)
- Surveiller la charge CPU et la bande passante
- Éviter l'encodage pendant les pics d'activité LiveKit

---

## 7. FAISABILITÉ TECHNIQUE

### 7.1 Prérequis

| Prérequis | Statut | Notes |
|-----------|--------|-------|
| Docker installé | ✅ OK | Version 29.5.3 |
| FFmpeg installé | ✅ OK | Version 6.1.1-3ubuntu5 |
| RAM disponible | ✅ OK | 8.2 Go disponible |
| Disque disponible | ✅ OK | 12 Go disponible |
| CPU disponible | ⚠️ LIMITÉ | 4 coeurs, charge actuelle faible |
| Accès Supabase | ✅ OK | HTTP/HTTPS disponible |
| Accès Internet | ✅ OK | Disponible |

### 7.2 Contraintes

| Contrainte | Impact | Sévérité |
|------------|--------|----------|
| CPU limité (4 coeurs) | Contention avec LiveKit | **ÉLEVÉE** |
| Réseau limité (100 Mbps) | Saturation avec LiveKit | **MOYENNE** |
| Disque limité (12 Go) | Risque de saturation avec vidéos temporaires | **FAIBLE** |
| RAM suffisante (8.2 Go) | Pas de problème | **AUCUNE** |

### 7.3 Risques identifiés

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Contention CPU avec LiveKit | ÉLEVÉE | ÉLEVÉ | Limiter worker à 1 job, utiliser nice/ionice |
| Saturation réseau avec LiveKit | MOYENNE | MOYENNE | Limiter worker à 1 job, surveiller bande passante |
| Saturation disque avec vidéos temporaires | FAIBLE | MOYENNE | Nettoyage automatique, surveillance |
| Échec du worker (jobs failed) | MOYENNE | FAIBLE | Retry automatique, monitoring |
| Dépendance à Supabase | FAIBLE | ÉLEVÉE | Proxy backend optionnel, retry |

---

## 8. CAPACITÉ MAXIMALE ESTIMÉE

### 8.1 Scénario optimal

**Conditions :**
- Worker limité à 1 job concurrent
- LiveKit: 5 participants simultanés (~5-25 Mbps)
- Vidéos: 30 secondes, 720p

**Capacité estimée :**
- **Jobs par heure:** ~180-327 jobs (11-20 secondes par job)
- **Jobs par jour:** ~4,320-7,848 jobs
- **CPU moyen:** ~30-50%
- **RAM moyenne:** ~300-500 Mo
- **Réseau moyen:** ~15-25 Mbps

### 8.2 Scénario dégradé

**Conditions :**
- Worker limité à 1 job concurrent
- LiveKit: 20 participants simultanés (~20-100 Mbps)
- Vidéos: 2 minutes, 1080p

**Capacité estimée :**
- **Jobs par heure:** ~33-60 jobs (60-110 secondes par job)
- **Jobs par jour:** ~792-1,440 jobs
- **CPU moyen:** ~70-90%
- **RAM moyenne:** ~400-600 Mo
- **Réseau moyen:** ~30-50 Mbps

### 8.3 Scénario critique

**Conditions :**
- Worker limité à 1 job concurrent
- LiveKit: 50 participants simultanés (~50-250 Mbps)
- Vidéos: 5 minutes, 1080p

**Capacité estimée :**
- **Jobs par heure:** ~11-20 jobs (180-330 secondes par job)
- **Jobs par jour:** ~264-480 jobs
- **CPU moyen:** ~90-100%
- **RAM moyenne:** ~600-800 Mo
- **Réseau moyen:** ~50-100 Mbps (SATURATION)

---

## 9. RECOMMANDATION GO / NO GO

### 9.1 Recommandation

**GO CONDITIONNEL**

### 9.2 Conditions minimales avant déploiement

| Condition | Statut | Action requise |
|-----------|--------|----------------|
| Limiter worker à 1 job concurrent | ❌ NON | Configurer WORKER_MAX_JOBS=1 |
| Configurer nice/ionice pour le worker | ❌ NON | Ajouter au Dockerfile ou docker-compose |
| Surveiller charge CPU en temps réel | ❌ NON | Installer monitoring (Prometheus/Grafana) |
| Surveiller bande passante en temps réel | ❌ NON | Installer monitoring (Prometheus/Grafana) |
| Nettoyage automatique des fichiers temporaires | ❌ NON | Configurer cron ou systemd-tmpfiles |
| Test de charge avec LiveKit actif | ❌ NON | Effectuer un test de charge avant déploiement |
| Backup de la configuration LiveKit | ✅ OK | Déjà documenté |
| Documentation de rollback | ❌ NON | Créer une procédure de rollback |

### 9.3 Conditions minimales après déploiement

| Condition | Action |
|-----------|--------|
| Monitoring CPU | Configurer alertes si > 80% |
| Monitoring RAM | Configurer alertes si > 80% |
| Monitoring disque | Configurer alertes si > 80% |
| Monitoring réseau | Configurer alertes si > 80 Mbps |
| Monitoring jobs | Configurer alertes si > 10% failed |
| Monitoring LiveKit | Configurer alertes si latence > 500ms |

---

## 10. CONCLUSION

Le déploiement du worker vidéo sur Kamatera est **techniquement faisable** mais **nécessite des précautions** pour éviter la contention avec LiveKit.

**Points clés :**
- ✅ Les ressources (RAM, disque) sont suffisantes
- ⚠️ Le CPU est limité (4 coeurs) - risque de contention
- ⚠️ Le réseau est limité (100 Mbps) - risque de saturation
- ✅ FFmpeg et Docker sont déjà installés
- ✅ Le worker est compatible avec Supabase et Kamatera
- ✅ La queue de jobs est vide (0 jobs queued) - pas de backlog

**Recommandation finale :**
- **GO** avec les conditions minimales listées en section 9.2
- Limiter le worker à 1 job concurrent
- Installer un monitoring complet
- Effectuer un test de charge avant déploiement en production

---

**Statut :** ✅ AUDIT TERMINÉ
