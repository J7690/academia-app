# D.17 - PHASE 5: AUDIT KAMATERA CLOUD

**Date**: 2026-06-26
**Mission**: D.17

---

## MÉTHODE

Recherche des URLs et références à Kamatera dans le code exécutable (`*.ts`, `*.js`, `*.py`, `*.dart`).

---

## URLs Kamatera trouvées

### 1. `compress-video`

| Service | URL | Fichier | Ligne |
|---------|-----|---------|-------|
| FFmpeg compress | `http://185.167.97.144:8001/compress` | `supabase/functions/compress-video/index.ts` | 24, 101 |

### 2. `transcode-multi-resolution`

| Service | URL / Mécanisme | Fichier | Ligne |
|---------|-----------------|---------|-------|
| FFmpeg transcode | `video_processing_jobs` table (worker polling) | `supabase/functions/transcode-multi-resolution/index.ts` | 14, 127-145 |
| VPS IP | `185.167.97.144` (fallback) | `supabase/functions/transcode-multi-resolution/index.ts` | 15 |

---

## SERVICES ATTENDUS

| Service | URL | Qui l'appelle | Statut |
|---------|-----|---------------|--------|
| compress-video FFmpeg | `http://185.167.97.144:8001/compress` | `supabase/functions/compress-video/index.ts` | EXISTE (dans le code) |
| transcode-multi-resolution worker | `video_processing_jobs` polling | `supabase/functions/transcode-multi-resolution/index.ts` | EXISTE (dans le code) |
| render-worker | Non trouvé dans le code Smart Whiteboard | - | INCONNU |
| livekit | `ws://185.167.97.144:7880` (d'après mémoire) | `livekit-token` | INCONNU |
| renderer | Non trouvé | - | INCONNU |
| websocket | Non trouvé | - | INCONNU |
| api général | Non trouvé | - | INCONNU |

---

## FICHIERS CONCERNÉS

| Fichier | Service | URL / Mécanisme |
|---------|---------|-----------------|
| `supabase/functions/compress-video/index.ts` | compression + watermark | `http://185.167.97.144:8001/compress` |
| `supabase/functions/transcode-multi-resolution/index.ts` | création de jobs de transcodage | `app.video_processing_jobs` |

---

## LIEN AVEC SMART WHITEBOARD

Aucune Edge Function Smart Whiteboard (`whiteboard-generate-storyboard`) n'appelle directement Kamatera.

Le rendu vidéo Smart Whiteboard est censé passer par:
1. `whiteboard_create_render_job` (RPC)
2. `app.whiteboard_renders` (table)
3. worker qui poll `whiteboard_renders` ou `video_processing_jobs`
4. Kamatera FFmpeg pour le rendu final
5. Storage bucket `whiteboard-videos` ou `video-assets`

**Aucun fichier de code exécutable dans le repo ne montre ce worker de rendu Smart Whiteboard.**

---

## STATUT GLOBAL

- **URL Kamatera dans le code**: ✅ EXISTE
- **Service FFmpeg compress**: ✅ EXISTE
- **Worker de rendu Smart Whiteboard**: ❌ INCONNU / NON TROUVÉ
- **État réel du serveur Kamatera (online/offline)**: ❌ NON VÉRIFIÉ

---

## LIMITATION

L'audit ne peut pas confirmer que le serveur `185.167.97.144:8001` répond actuellement. Seule l'URL présente dans le code est prouvée.
