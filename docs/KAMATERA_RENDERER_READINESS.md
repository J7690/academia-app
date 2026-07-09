# KAMATERA RENDERER READINESS

**Version** : 1.0  
**Date** : 23 Juin 2026  
**Phase** : C.0 – Kamatera Renderer Readiness  
**Mode** : LECTURE SEULE  
**Objectif** : Déterminer précisément ce qui existe déjà sur Kamatera et ce qui peut être réutilisé pour le Smart Whiteboard Renderer

---

## DIRECTIVE TECHNIQUE PERMANENTE

Toute vérification Kamatera a été réalisée via les audits existants (STUDIO_KAMATERA_AUDIT.md) et les RPC Python administrateurs dans `.windsurf`.

---

## PARTIE 1 – INVENTAIRE KAMATERA

### 1.1 Conteneurs Docker

**Via audit SSH** (STUDIO_KAMATERA_AUDIT.md)

| Conteneur | Existe | Statut | Rôle |
|-----------|--------|--------|------|
| livekit-server | ✅ | Actif (12 jours uptime) | Streaming vidéo/audio en temps réel |
| academia-backend | ❌ | Non déployé | Backend FastAPI (local Docker Compose uniquement) |
| academia-videoasset-worker | ❌ | Non déployé | Worker vidéo (local Docker Compose uniquement) |
| whiteboard-backend | ❌ | À créer | Backend Smart Whiteboard |
| whiteboard-render-worker | ❌ | À créer | Worker Smart Whiteboard |

**Conclusion** : Kamatera n'héberge que LiveKit. Aucun conteneur de rendu vidéo n'est actif.

### 1.2 Services Python

**Via audit code** (academia_bobodo_backend/)

| Service | Existe | Statut | Rôle |
|---------|--------|--------|------|
| main.py | ✅ | Prêt (local) | Backend FastAPI (proxy Supabase, endpoints vidéo) |
| studio_video_renderer.py | ✅ | Prêt (local) | Fonctions FFmpeg (transcodage, watermark) |
| videoasset_worker.py | ✅ | Prêt (local) | Worker polling (video_processing_jobs) |
| whiteboard_main.py | ❌ | À créer | Backend Smart Whiteboard |
| whiteboard_render_worker.py | ❌ | À créer | Worker Smart Whiteboard |

**Conclusion** : Les services vidéo existent mais ne sont pas déployés sur Kamatera. Ils tournent uniquement en local via Docker Compose.

### 1.3 Dépendances Python

**Via audit Dockerfile** (academia_bobodo_backend/Dockerfile)

| Dépendance | Existe | Version | Utilité |
|------------|--------|---------|---------|
| fastapi | ✅ | Latest | Backend API |
| httpx | ✅ | Latest | HTTP client |
| python-dotenv | ✅ | Latest | Configuration |
| livekit | ✅ | Latest | LiveKit SDK |
| Pillow | ❌ | - | Génération images PNG (manquant) |
| Matplotlib | ❌ | - | Rendu formules LaTeX (manquant) |

**Conclusion** : Pillow et Matplotlib sont manquants pour le rendu Smart Whiteboard.

### 1.4 FFmpeg

**Via audit SSH** (STUDIO_KAMATERA_AUDIT.md)

| Paramètre | Valeur |
|-----------|--------|
| **Version** | 6.1.1-3ubuntu5 |
| **Installation** | Via apt-get (Ubuntu 24.04.4 LTS) |
| **Localisation** | /usr/bin/ffmpeg |
| **Statut** | Installé mais non utilisé pour l'encodage vidéo |

**Conclusion** : FFmpeg est installé sur Kamatera mais n'est PAS utilisé pour l'encodage vidéo. Le transcodage vidéo se fait localement (Docker) ou sur Railway (indisponible).

### 1.5 Docker Compose

**Via audit docker-compose.yml**

| Service | Image | Ports | Statut |
|---------|-------|-------|--------|
| academia-backend | python:3.11-slim | 8001:8000 | Local uniquement |
| academia-videoasset-worker | python:3.11-slim | - | Local uniquement |

**Conclusion** : Docker Compose existe mais n'est pas déployé sur Kamatera. Il tourne uniquement en local.

---

## PARTIE 2 – RÉUTILISATION

### 2.1 Composants réutilisables (Challenge)

| Composant | Fichier | Réutilisable | Notes |
|-----------|---------|--------------|-------|
| Pattern FastAPI | main.py | ✅ OUI | Structure backend réutilisable |
| Pattern FFmpeg | studio_video_renderer.py | ✅ OUI | Fonctions FFmpeg réutilisables |
| Pattern worker | videoasset_worker.py | ✅ OUI | Pattern polling réutilisable |
| Pattern Docker Compose | docker-compose.yml | ✅ OUI | Structure conteneurs réutilisable |
| Pipeline vidéo | videoasset_worker.py | ⚠️ Partiellement | Pattern queue de jobs réutilisable |

### 2.2 Composants réutilisables (TV Pro)

| Composant | Fichier | Réutilisable | Notes |
|-----------|---------|--------------|-------|
| Filtergraph FFmpeg | tv_pro_filter_builder.py | ✅ OUI | Pattern filtergraph réutilisable |
| TV Pro renderer | studio_video_renderer_pro.py | ⚠️ Partiellement | Pattern complex filtergraph réutilisable |

### 2.3 Composants réutilisables (LiveKit)

| Composant | Réutilisable | Notes |
|-----------|--------------|-------|
| LiveKit Server | ❌ NON | Spécifique streaming temps réel |
| Redis | ❌ NON | Spécifique LiveKit |
| Nginx | ❌ NON | Spécifique LiveKit |

### 2.4 Composants réutilisables (Compression vidéo)

| Composant | Fichier | Réutilisable | Notes |
|-----------|---------|--------------|-------|
| Transcodage multi-résolution | videoasset_worker.py | ✅ OUI | Pattern réutilisable |
| Watermark TikTok-style | studio_video_renderer.py | ✅ OUI | Pattern réutilisable |
| Upload Supabase Storage | studio_video_renderer.py | ✅ OUI | Pattern réutilisable |

### 2.5 Conclusion réutilisation

**Réutilisable tel quel** : Aucun composant spécifique Smart Whiteboard

**Réutilisable avec adaptation légère** :
- Pattern FastAPI (main.py)
- Pattern FFmpeg (studio_video_renderer.py)
- Pattern worker (videoasset_worker.py)
- Pattern Docker Compose
- Pattern filtergraph (tv_pro_filter_builder.py)

**À créer** :
- Génération images PNG (Pillow)
- Rendu formules LaTeX (Matplotlib)
- Assemblage images → MP4 (FFmpeg)
- Conteneurs whiteboard-backend, whiteboard-render-worker

---

## PARTIE 3 – PIPELINE RENDERER V1

### 3.1 Pipeline Storyboard JSON → PNG → FFmpeg → MP4

```
Storyboard JSON (Supabase)
↓
Worker Kamatera (poll whiteboard_renders)
↓
Parse JSON (Python)
↓
Pour chaque scène :
  - Créer canvas Pillow (1080x1920)
  - Pour chaque bloc :
    - TitleBlock → Texte Pillow
    - ParagraphBlock → Texte Pillow
    - FormulaBlock → Matplotlib (LaTeX) → PNG
    - DefinitionBlock → Texte Pillow
    - ExerciseBlock → Texte Pillow
    - CorrectionBlock → Texte Pillow
  - Sauvegarder scène PNG
↓
Assemblage PNGs → MP4 (FFmpeg)
  - ffmpeg -f image2 -framerate 30 -i scene_%d.png -c:v libx264 -pix_fmt yuv420p output.mp4
↓
Upload MP4 → Supabase Storage (whiteboard-renders)
↓
Update whiteboard_renders (status=done, video_url)
```

### 3.2 Faisabilité technique

| Étape | Faisabilité | Notes |
|-------|-------------|-------|
| Parse JSON | ✅ OUI | Python json standard |
| Créer canvas Pillow | ✅ OUI | Pillow installé (à ajouter) |
| Texte Pillow | ✅ OUI | Pillow ImageDraw |
| Formules LaTeX | ⚠️ Partiellement | Matplotlib nécessaire (à ajouter) |
| Assemblage PNGs → MP4 | ✅ OUI | FFmpeg installé |
| Upload Supabase | ✅ OUI | Pattern existant (studio_video_renderer.py) |

**Conclusion** : Le pipeline est techniquement faisable avec l'ajout de Pillow et Matplotlib.

---

## PARTIE 4 – CAPACITÉ SERVEUR

### 4.1 Capacité actuelle

**Via audit SSH** (STUDIO_KAMATERA_AUDIT.md)

| Paramètre | Valeur |
|-----------|--------|
| **IP** | 185.167.97.144 |
| **OS** | Ubuntu 24.04.4 LTS |
| **CPU** | 4 coeurs |
| **RAM totale** | 9.7 Go |
| **RAM utilisée** | 1.6 Go |
| **RAM disponible** | 8.2 Go |
| **Disque total** | 30 Go |
| **Disque utilisé** | 17 Go (58%) |
| **Disque disponible** | 12 Go |
| **FFmpeg** | 6.1.1-3ubuntu5 (installé) |
| **Docker** | 29.5.3 (installé) |
| **Conteneurs Docker** | 1 (livekit-server) |

### 4.2 Charge actuelle

**LiveKit uniquement** :
- 1 conteneur Docker (livekit-server)
- ~50 participants simultanés par room
- ~10 rooms simultanées
- RAM utilisée : 1.6 Go / 9.7 Go (16%)
- Charge CPU : Inconnue (non mesurée)

**Conclusion** : Kamatera est sous-utilisé pour le rendu vidéo. LiveKit consomme peu de ressources.

---

## PARTIE 5 – CHARGE ESTIMÉE

### 5.1 Estimation par rendu

**Storyboard typique** :
- Taille JSON : ~1500 octets
- Nombre de scènes : 2-5
- Nombre de blocs : 2-5
- Durée estimée : 10-30 secondes

**Ressources par rendu** :
- CPU : 1-2 cores (Pillow + FFmpeg)
- RAM : 500 Mo - 1 Go (Pillow + FFmpeg + buffers)
- Stockage temporaire : 50-100 Mo (PNGs + MP4 temporaire)
- Durée : 30-60 secondes

### 5.2 Scénario 1 rendu simultané

| Ressource | Utilisation | Disponible | Pourcentage | Évaluation |
|-----------|-------------|------------|-------------|------------|
| CPU | 1-2 cores | 4 cores | 25-50% | ✅ FAISABLE |
| RAM | 500 Mo - 1 Go | 8.2 Go | 6-12% | ✅ FAISABLE |
| Stockage | 50-100 Mo | 12 Go | 0.4-0.8% | ✅ FAISABLE |

**Conclusion** : ✅ FAISABLE

### 5.3 Scénario 5 rendus simultanés

| Ressource | Utilisation | Disponible | Pourcentage | Évaluation |
|-----------|-------------|------------|-------------|------------|
| CPU | 5-10 cores | 4 cores | 125-250% | ❌ OVERLOAD |
| RAM | 2.5-5 Go | 8.2 Go | 30-61% | ⚠️ Acceptable |
| Stockage | 250-500 Mo | 12 Go | 2-4% | ✅ FAISABLE |

**Conclusion** : ❌ CPU OVERLOAD

### 5.4 Scénario 10 rendus simultanés

| Ressource | Utilisation | Disponible | Pourcentage | Évaluation |
|-----------|-------------|------------|-------------|------------|
| CPU | 10-20 cores | 4 cores | 250-500% | ❌ SEVERE OVERLOAD |
| RAM | 5-10 Go | 8.2 Go | 61-122% | ❌ OVERLOAD |
| Stockage | 500 Mo - 1 Go | 12 Go | 4-8% | ⚠️ Acceptable |

**Conclusion** : ❌ CPU + RAM OVERLOAD

### 5.5 Conclusion charge

**Capacité maximale recommandée** : 1-2 rendus simultanés  
**Capacité maximale absolue** : 3 rendus simultanés (avec dégradation)  
**Au-delà de 3 rendus** : CPU bottleneck sévère

---

## PARTIE 6 – ARCHITECTURE RENDERER V1

### 6.1 Backend

**Composant** : whiteboard-backend (FastAPI)

**Rôle** :
- Proxy Supabase (pattern main.py)
- Endpoint création render job (RPC whiteboard_create_render_job)
- Endpoint statut render job (RPC whiteboard_get_render_status)
- Endpoint upload narration (si narration_mode=user_recording)

**Dépendances** :
- fastapi
- httpx
- python-dotenv
- Pillow (à ajouter)
- Matplotlib (à ajouter)

### 6.2 Worker

**Composant** : whiteboard-render-worker (Python)

**Rôle** :
- Poll whiteboard_renders (status=queued)
- Marque job comme running
- Télécharge storyboard_json depuis Supabase
- Parse JSON
- Génère PNGs (Pillow + Matplotlib)
- Assemble PNGs → MP4 (FFmpeg)
- Upload MP4 → Supabase Storage (whiteboard-renders)
- Update whiteboard_renders (status=done, video_url, duration_ms)
- Marque job comme done

**Dépendances** :
- Pillow (à ajouter)
- Matplotlib (à ajouter)
- subprocess (FFmpeg)

### 6.3 Queue

**Composant** : whiteboard_renders (table Supabase)

**Pattern** : Polling (pattern videoasset_worker.py)

**Configuration** :
- WORKER_LOOP=1 (boucle infinie)
- WORKER_INTERVAL_SECONDS=2 (intervalle polling)
- WORKER_MAX_JOBS=1 (jobs max par itération pour éviter CPU overload)

### 6.4 Storage

**Composant** : whiteboard-renders (bucket Supabase)

**Rôle** :
- Stockage MP4 générés
- Stockage narrations audio (si narration_mode=user_recording)

**Configuration** :
- MIME types : video/mp4, audio/mpeg
- Taille max : 100 Mo par fichier
- RLS : student + service_role

### 6.5 FFmpeg

**Composant** : FFmpeg (installé sur Kamatera)

**Commande assemblage** :
```bash
ffmpeg -f image2 -framerate 30 -i scene_%d.png -c:v libx264 -pix_fmt yuv420p -r 30 -preset medium -crf 23 output.mp4
```

**Commande ajout audio** (si narration) :
```bash
ffmpeg -i output.mp4 -i narration.mp3 -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -shortest output_with_audio.mp4
```

---

## PARTIE 7 – RISQUES

### 7.1 Goulets CPU

**Risque** : CPU bottleneck sévère au-delà de 3 rendus simultanés

**Cause** :
- Kamatera : 4 coeurs seulement
- Rendu typique : 1-2 cores
- 5 rendus simultanés : 5-10 cores requis (125-250% overload)

**Mitigation** :
- Limiter à 1-2 rendus simultanés (WORKER_MAX_JOBS=1)
- Implémenter queue de priorité
- Augmenter Kamatera (8 coeurs recommandé)

### 7.2 Goulets RAM

**Risque** : RAM overflow au-delà de 10 rendus simultanés

**Cause** :
- Kamatera : 8.2 Go disponible
- Rendu typique : 500 Mo - 1 Go
- 10 rendus simultanés : 5-10 Go requis (61-122% overload)

**Mitigation** :
- Limiter à 1-2 rendus simultanés
- Nettoyer fichiers temporaires après chaque rendu
- Augmenter Kamatera (16 Go recommandé)

### 7.3 Goulets Stockage

**Risque** : Stockage temporaire insuffisant

**Cause** :
- Kamatera : 12 Go disponible
- Rendu typique : 50-100 Mo
- 100 rendus simultanés : 5-10 Go requis

**Mitigation** :
- Nettoyer fichiers temporaires après chaque rendu
- Utiliser /tmp (monté dans volume Docker)
- Risque faible (12 Go suffisant pour 100+ rendus)

### 7.4 Goulets FFmpeg

**Risque** : FFmpeg single-threaded

**Cause** :
- FFmpeg utilise principalement 1 core par instance
- Pas de parallélisation automatique

**Mitigation** :
- Limiter à 1-2 rendus simultanés
- Utiliser FFmpeg multithreading (-threads 4)
- Risque modéré (CPU bottleneck principal)

---

## PARTIE 8 – RÉPONSES AUX QUESTIONS

### 8.1 Le Renderer V1 est-il réalisable sur l'infrastructure actuelle ?

**Réponse** : ✅ **OUI, avec limitations**

**Justification** :
- FFmpeg est installé sur Kamatera
- Docker est installé sur Kamatera
- RAM disponible (8.2 Go) suffisante pour 1-2 rendus
- Stockage disponible (12 Go) suffisant
- Pattern FastAPI, FFmpeg, worker réutilisables
- Pillow et Matplotlib à ajouter (simple apt-get/pip install)

**Limitations** :
- Capacité maximale : 1-2 rendus simultanés
- Au-delà de 3 rendus : CPU bottleneck sévère
- LiveKit consomme déjà des ressources (à surveiller)

### 8.2 Faut-il augmenter Kamatera ?

**Réponse** : ⚠️ **RECOMMANDÉ pour production**

**Justification** :
- Capacité actuelle : 1-2 rendus simultanés
- Capacité recommandée : 5-10 rendus simultanés
- CPU actuel : 4 coeurs
- CPU recommandé : 8 cores (minimum)
- RAM actuelle : 9.7 Go
- RAM recommandée : 16 Go (minimum)

**Scénarios** :
- **MVP (1-2 rendus simultanés)** : Kamatera actuel suffisant
- **Production (5-10 rendus simultanés)** : Kamatera à augmenter (8 coeurs, 16 Go)

### 8.3 Quels composants peuvent être réutilisés ?

**Réponse** : **Patterns réutilisables, composants spécifiques à créer**

**Réutilisable** :
- Pattern FastAPI (main.py)
- Pattern FFmpeg (studio_video_renderer.py)
- Pattern worker (videoasset_worker.py)
- Pattern Docker Compose
- Pattern filtergraph (tv_pro_filter_builder.py)
- Pattern upload Supabase Storage

**À créer** :
- Génération images PNG (Pillow)
- Rendu formules LaTeX (Matplotlib)
- Assemblage images → MP4 (FFmpeg)
- Conteneurs whiteboard-backend, whiteboard-render-worker
- Services whiteboard_main.py, whiteboard_render_worker.py

### 8.4 Quel est le plus petit Renderer V1 viable ?

**Réponse** : **Worker Python + FFmpeg + Pillow**

**Composants minimum** :
1. **Worker Python** (whiteboard_render_worker.py)
   - Poll whiteboard_renders
   - Parse Storyboard JSON
   - Génération PNGs (Pillow)
   - Assemblage MP4 (FFmpeg)
   - Upload Supabase Storage

2. **FFmpeg** (déjà installé)
   - Assemblage PNGs → MP4

3. **Pillow** (à installer)
   - Génération images PNG

4. **Matplotlib** (optionnel pour V1)
   - Rendu formules LaTeX (peut être reporté à V2)

**Conteneur minimum** :
```yaml
whiteboard-render-worker:
  image: python:3.11-slim
  command: python -u whiteboard_render_worker.py
  volumes:
    - /tmp/whiteboard_render:/tmp
```

**Dépendances minimum** :
- Pillow
- httpx (pour appel Supabase)
- python-dotenv

**Conclusion** : Le plus petit Renderer V1 viable est un worker Python simple avec Pillow + FFmpeg, sans backend FastAPI ni queue complexe.

---

## PARTIE 9 – CONCLUSION

### 9.1 Résumé

**Infrastructure actuelle** :
- Kamatera : 4 coeurs, 9.7 Go RAM, 30 Go disque
- FFmpeg : installé
- Docker : installé
- LiveKit : actif (1 conteneur)

**Capacité** :
- 1-2 rendus simultanés : ✅ FAISABLE
- 3 rendus simultanés : ⚠️ AVEC DÉGRADATION
- 5+ rendus simultanés : ❌ CPU OVERLOAD

**Réutilisation** :
- Patterns FastAPI, FFmpeg, worker réutilisables
- Pillow et Matplotlib à ajouter
- Composants spécifiques Smart Whiteboard à créer

### 9.2 Recommandations

**Pour MVP** :
- Utiliser Kamatera actuel
- Limiter à 1-2 rendus simultanés
- Implémenter worker Python simple
- Ajouter Pillow (Matplotlib optionnel pour V1)

**Pour Production** :
- Augmenter Kamatera (8 coeurs, 16 Go)
- Implémenter backend FastAPI
- Implémenter queue de priorité
- Ajouter Matplotlib (formules LaTeX)

### 9.3 Décision

**PHASE C.0 VALIDÉE** ✅

**Justification** :
- Le Renderer V1 est techniquement réalisable sur l'infrastructure actuelle
- Des limitations existent (1-2 rendus simultanés) mais sont acceptables pour MVP
- Des patterns réutilisables existent (FastAPI, FFmpeg, worker)
- Le plus petit Renderer V1 viable est clairement identifié

---

**Fin du document**
