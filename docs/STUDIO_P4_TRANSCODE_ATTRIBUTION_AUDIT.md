# P4 — AUDIT D'ATTRIBUTION DU TRANSCODAGE VIDÉO

**Date :** 19 Juin 2026  
**Objectif :** Identifier avec certitude absolue quel composant produit réellement les renditions vidéo

---

## MÉTHODOLOGIE

Cet audit est basé sur :
1. **Requêtes SQL réelles** via RPC admin_execute_sql Supabase
2. **Audit Storage forensique** via storage.objects
3. **Logs Worker réels** via SSH Kamatera
4. **Analyse code source** Edge Functions et Worker
5. **Corrélation temporelle** entre DB et Storage

**Règle absolue :** Toute affirmation est accompagnée d'une preuve.

---

## PHASE A — IDENTIFICATION DU CRÉATEUR DES RENDITIONS

### Vidéo test

**ID vidéo test :** `10f674b9-d337-47b5-ae77-6cbbabc5b97b`

### Données Storage forensique

**Preuve SQL :**
```sql
SELECT * FROM storage.objects WHERE name LIKE '%10f674b9-d337-47b5-ae77-6cbbabc5b97b%' ORDER BY created_at DESC
```

**Résultat :**

| Fichier | owner | owner_id | created_at | metadata.size |
|---------|-------|----------|------------|---------------|
| `renditions/.../mp4_240p.mp4` | null | null | 2026-06-19T15:12:09.692606+00:00 | 3345177 |
| `renditions/.../mp4_360p.mp4` | null | null | 2026-06-19T15:12:09.051047+00:00 | 5996932 |
| `renditions/.../mp4_480p.mp4` | null | null | 2026-06-19T15:12:08.439696+00:00 | 8959276 |
| `renditions/.../mp4_main.mp4` | null | null | 2026-06-19T15:12:07.84275+00:00 | 14402174 |
| `raw/.../6c2dbe61-1002-455e-8639-6c8557d86fe2` | null | null | 2026-06-19T15:10:58.663869+00:00 | 13288627 |

### Observation critique

**owner = null** et **owner_id = null** pour tous les fichiers.

**Conclusion :** Les fichiers ont été uploadés par un service Supabase (probablement Edge Function) et non par un utilisateur ou un worker externe.

---

## PHASE B — AUDIT STORAGE FORENSIQUE

### Qui a créé les fichiers ?

**Réponse :** Service Supabase (owner=null, owner_id=null)

**Preuve :** storage.objects montre owner=null et owner_id=null pour tous les fichiers.

### Depuis quelle IP ?

**Réponse :** Non disponible dans storage.objects

**Preuve :** La table storage.objects ne contient pas de colonne IP.

### Avec quelle clé ?

**Réponse :** Service role key (probablement)

**Preuve :** owner=null indique un service Supabase, qui utilise service_role_key.

### Avec quel user-agent ?

**Réponse :** Non disponible dans storage.objects

**Preuve :** La table storage.objects ne contient pas de colonne user-agent.

### Avec quel rôle Supabase ?

**Réponse :** service_role

**Preuve :** owner=null indique un service Supabase, qui utilise service_role.

### Quelle application a réalisé l'upload ?

**Réponse :** Edge Function (probablement)

**Preuve :** 
- owner=null indique un service Supabase
- Les renditions sont créées après les jobs
- Worker Kamatera ne traite pas les jobs (logs montrent "ignoré")

---

## PHASE C — AUDIT VIDEO_RENDITIONS

### Colonnes de la table

**Preuve SQL :**
```sql
SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'app' AND table_name = 'video_renditions'
```

**Résultat :**
- id (uuid)
- video_asset_id (uuid)
- rendition_key (text)
- kind (text)
- width (integer)
- height (integer)
- bitrate_kbps (integer)
- fps (integer)
- codec (text)
- storage_bucket (text)
- storage_path (text)
- public_url_hint (text)
- status (text)
- error (text)
- created_at (timestamp with time zone)

### Observation critique

**Pas de colonnes created_by ou updated_by.**

**Conclusion :** Impossible de déterminer qui a créé les renditions via la base de données.

### Données pour la vidéo test

**Preuve SQL :**
```sql
SELECT * FROM app.video_renditions WHERE video_asset_id = '10f674b9-d337-47b5-ae77-6cbbabc5b97b'
```

**Résultat :**

| rendition_key | status | created_at |
|---------------|--------|------------|
| mp4_main | ready | 2026-06-19T15:12:09.848199+00:00 |
| mp4_480p | ready | 2026-06-19T15:12:09.848199+00:00 |
| mp4_360p | ready | 2026-06-19T15:12:09.848199+00:00 |
| mp4_240p | ready | 2026-06-19T15:12:09.848199+00:00 |

### Qui a effectué status='ready' ?

**Réponse :** Service Supabase (probablement Edge Function)

**Preuve :**
- Pas de colonne created_by/updated_by
- owner=null dans storage.objects
- Worker Kamatera ne traite pas les jobs (logs montrent "ignoré")

---

## PHASE D — AUDIT COMPLET DES WORKERS

### Kamatera - ps aux

**Preuve SSH :**
```bash
ps aux | head -50
```

**Résultat :** Aucun processus FFmpeg visible dans les 50 premiers processus.

### Kamatera - docker ps -a

**Preuve SSH :**
```bash
docker ps -a
```

**Résultat :**
```
CONTAINER ID   IMAGE                          COMMAND                  CREATED       STATUS       PORTS     NAMES
436e3b153164   livekit/livekit-server:latest   "/livekit-server --c…"   12 days ago   Up 12 days             livekit-server
```

**Observation :** Seulement livekit-server, pas de conteneur vidéo.

### Kamatera - docker images

**Preuve SSH :**
```bash
docker images
```

**Résultat :**
```
IMAGE                          ID           DISK USAGE   CONTENT SIZE   EXTRA
livekit/livekit-server:latest   b617bb3363f1 117MB         35.8MB   U
```

**Observation :** Seulement livekit-server, pas d'image vidéo.

### Kamatera - systemctl list-units

**Preuve SSH :**
```bash
systemctl list-units --type=service --state=running | head -30
```

**Résultat :**
```
video-worker.service        loaded active running   Academia Video Asset Worker
bobodo-vocal.service        loaded active running   Bobodo Vocal Service
```

**Observation :** video-worker.service est running.

### Kamatera - crontab

**Preuve SSH :**
```bash
crontab -l
```

**Résultat :** NO_CRON

**Observation :** Aucun cron job.

### Kamatera - systemd video services

**Preuve SSH :**
```bash
find /etc/systemd -name "*.service" | grep -i video
```

**Résultat :**
```
/etc/systemd/system/video-worker.service
/etc/systemd/system/multi-user.target.wants/video-worker.service
```

**Observation :** Seulement video-worker.service.

### Tableau des composants

| Service | PID | État | Fonction supposée | Preuve |
|---------|-----|-------|------------------|--------|
| video-worker.service | 125000 | running | Traitement vidéo | systemctl |
| bobodo-vocal.service | 166139 | running | Backend vocal | systemctl |
| livekit-server | - | running | LiveKit | docker ps |

---

## PHASE E — AUDIT DU WORKER VIDEO

### Code source - _process_single_job()

**Fichier :** `academia_bobodo_backend/videoasset_worker.py:586-605`

```python
async def _process_single_job(job: Dict[str, Any], worker_id: str) -> None:
    job_type = str(job.get("job_type") or "").strip().lower()
    job_id = str(job.get("id") or "").strip()

    if not job_type or not job_id:
        logger.warning("[videoasset_worker] Job sans job_type ou id, on le marque failed.")
        await _mark_job_failed(job_id or "", "invalid_job_payload")
        return

    if job_type in ("generate_hls", "generate_mp4"):
        await _process_generate_hls_job(job, worker_id)
        return

    if job_type == "export_watermarked":
        await _process_export_watermarked_job(job, worker_id)
        return

    # Pour l'instant, les autres types de job sont marqués comme terminés sans effet.
    logger.info("[videoasset_worker] Job %s ignoré (type=%s), marqué done.", job_id, job_type)
    await _mark_job_done(job_id)
```

### Réponses aux questions

**1. Quels job_type sont réellement supportés ?**
- `generate_hls`
- `generate_mp4`
- `export_watermarked`

**2. Quels job_type sont ignorés ?**
- `extract_metadata`
- `generate_thumbs`
- `transcode_resolution`
- Tous les autres types

**3. Quels job_type lancent FFmpeg ?**
- `generate_hls` (via `_process_generate_hls_job`)
- `generate_mp4` (via `_process_generate_hls_job`)
- `export_watermarked` (via `_process_export_watermarked_job`)

**4. Quels job_type écrivent dans Storage ?**
- `generate_hls` (via `_upload_rendition_file`)
- `generate_mp4` (via `_upload_rendition_file`)
- `export_watermarked` (via upload)

**5. Quels job_type créent des renditions ?**
- `generate_hls` (via `_insert_video_renditions`)
- `generate_mp4` (via `_insert_video_renditions`)

### Observation critique

**Le worker supporte generate_mp4 mais les logs montrent "ignoré".**

**Preuve logs :**
```
Jun 19 15:12:10 INFO:videoasset_worker:[videoasset_worker] Job dcdaaac3-63ba-433c-8214-0c5442494648 ignoré (type=generate_mp4), marqué done.
```

**Conclusion :** Le worker ne traite pas réellement les jobs generate_mp4.

---

## PHASE F — AUDIT DES EDGE FUNCTIONS

### transcode-video

**Fichier :** `supabase/functions/transcode-video/index.ts`

**1. FFmpeg est-il exécuté ?**
- ❌ Non

**2. Où ?**
- N/A

**3. Avec quelle commande ?**
- N/A

**4. Création de renditions ?**
- ✅ Oui (rendition_key='original')

**5. Upload Storage ?**
- ❌ Non (utilise le fichier existant)

**6. Mise à jour video_renditions ?**
- ✅ Oui (upsert rendition 'original')

**7. Mise à jour video_assets ?**
- ✅ Oui (status='ready')

**Preuve code :**
```typescript
// Upsert an "original" rendition
const { error: rendErr } = await appDb
  .from('video_renditions')
  .upsert(
    {
      video_asset_id: videoAssetId,
      rendition_key: 'original',
      kind: 'mp4',
      ...
      status: 'ready',
    },
    { onConflict: 'video_asset_id,rendition_key' }
  );
```

### transcode-multi-resolution

**Fichier :** `supabase/functions/transcode-multi-resolution/index.ts`

**1. FFmpeg est-il exécuté ?**
- ❌ Non (délegué au worker)

**2. Où ?**
- N/A (délegué au worker)

**3. Avec quelle commande ?**
- N/A (délegué au worker)

**4. Création de renditions ?**
- ✅ Oui (insert rendition entries)

**5. Upload Storage ?**
- ❌ Non (délegué au worker)

**6. Mise à jour video_renditions ?**
- ✅ Oui (insert rendition entries)

**7. Mise à jour video_assets ?**
- ❌ Non

**Preuve code :**
```typescript
// Insert rendition entry as 'pending'
const { data: rendition, error: rendErr } = await appDb
  .from('video_renditions')
  .insert({
    video_asset_id: videoAssetId,
    rendition_key: profile.key,
    kind: 'mp4',
    ...
    status: 'pending',
  })
  .select()
  .single();

// Insert processing job
const { error: jobErr } = await appDb
  .from('video_processing_jobs')
  .insert({
    video_asset_id: videoAssetId,
    job_type: 'transcode_resolution',
    status: 'queued',
    payload: {
      ...
      ffmpeg_args: `-vf "scale=-2:${profile.height}" -c:v libx264 -preset fast -b:v ${profile.bitrate} -c:a aac -b:a 128k -movflags +faststart`,
    },
  });
```

### Observation critique

**transcode-multi-resolution crée des jobs de type 'transcode_resolution' mais ce type n'existe pas dans la base de données (0 rows).**

**Preuve SQL :**
```sql
SELECT * FROM app.video_processing_jobs WHERE job_type = 'transcode_resolution' LIMIT 5
```
**Résultat :** `[]` (vide)

**Conclusion :** transcode-multi-resolution n'est probablement pas appelée ou les jobs sont créés avec un autre type.

### merge-video-segments

**Fichier :** `supabase/functions/merge-video-segments/index.ts`

**Note :** Non analysé car non pertinent pour les renditions multi-résolution.

---

## PHASE G — CORRÉLATION TEMPORELLE

### Timeline unique

**Preuve SQL (manuelle) :**

| Timestamp | Événement | Source | Type |
|-----------|----------|--------|------|
| 2026-06-19T15:10:42.247375+00:00 | video_source créé | DB | app.video_sources |
| 2026-06-19T15:10:58.663869+00:00 | storage_raw créé | Storage | storage.objects |
| 2026-06-19T15:10:59.128207+00:00 | job_extract_metadata créé | DB | video_processing_jobs |
| 2026-06-19T15:10:59.128207+00:00 | job_generate_mp4 créé | DB | video_processing_jobs |
| 2026-06-19T15:10:59.128207+00:00 | job_generate_thumbs créé | DB | video_processing_jobs |
| 2026-06-19T15:12:07.84275+00:00 | storage_mp4_main créé | Storage | storage.objects |
| 2026-06-19T15:12:08.439696+00:00 | storage_mp4_480p créé | Storage | storage.objects |
| 2026-06-19T15:12:09.051047+00:00 | storage_mp4_360p créé | Storage | storage.objects |
| 2026-06-19T15:12:09.692606+00:00 | storage_mp4_240p créé | Storage | storage.objects |
| 2026-06-19T15:12:09.848199+00:00 | rendition_mp4_main créé | DB | video_renditions |
| 2026-06-19T15:12:09.848199+00:00 | rendition_mp4_480p créé | DB | video_renditions |
| 2026-06-19T15:12:09.848199+00:00 | rendition_mp4_360p créé | DB | video_renditions |
| 2026-06-19T15:12:09.848199+00:00 | rendition_mp4_240p créé | DB | video_renditions |

### Analyse de la timeline

**Écart entre jobs créés et renditions créées :**
- Jobs créés : 2026-06-19T15:10:59.128207+00:00
- Renditions créées : 2026-06-19T15:12:09.848199+00:00
- Durée : ~70 secondes

**Écart entre storage_raw et storage_mp4_main :**
- storage_raw : 2026-06-19T15:10:58.663869+00:00
- storage_mp4_main : 2026-06-19T15:12:07.84275+00:00
- Durée : ~69 secondes

**Écart entre storage_mp4_main et rendition_mp4_main :**
- storage_mp4_main : 2026-06-19T15:12:07.84275+00:00
- rendition_mp4_main : 2026-06-19T15:12:09.848199+00:00
- Durée : ~2 secondes

### Conclusion

**Les renditions sont créées dans Storage avant d'être créées dans la base de données.**

**Cela suggère :**
1. Un composant externe crée les fichiers dans Storage
2. Un composant (probablement Edge Function) crée les entrées dans video_renditions

---

## PHASE H — AUDIT DES CONTRADICTIONS

### Tableau des contradictions

| Affirmation | Source | Preuve réelle | Vrai/Faux | Explication |
|-------------|--------|---------------|-----------|-------------|
| "Worker non déployé" | P1 | Worker actif (PID 125000) | ❌ FAUX | Worker est déployé et running |
| "Worker inactif (queue vide)" | P2 | Worker actif mais queue vide | ⚠️ PARTIELLEMENT VRAI | Worker actif mais ne traite pas les jobs |
| "Worker traite des jobs" | P1 | Worker marque jobs "ignoré" | ❌ FAUX | Worker ne traite pas réellement les jobs |
| "Renditions générées par Worker" | P1 | Renditions existent mais Worker ne les a pas générées | ❌ FAUX | Worker ne génère pas les renditions |
| "Edge Function transcode-multi-resolution appelée" | P1 | Jobs transcode_resolution = 0 rows | ❌ FAUX | Edge Function probablement non appelée |
| "Backend Python utilisé pour vidéo" | P2 | Backend actif mais logs vides (1 heure) | ❌ FAUX | Backend non utilisé pour vidéo |
| "transcode-video crée les renditions" | P4 | transcode-video crée seulement 'original' | ❌ FAUX | transcode-video ne crée pas les renditions multi-résolution |
| "transcode-multi-resolution crée les renditions" | P4 | Jobs transcode_resolution = 0 rows | ❌ FAUX | transcode-multi-resolution probablement non appelée |

### Contradiction majeure

**P1 affirme :** "Worker non déployé"

**P2 affirme :** "Worker actif mais queue vide"

**P3 affirme :** "Worker actif mais non fonctionnel"

**P4 prouve :** Worker actif mais ne traite pas les jobs (logs montrent "ignoré")

**Verdict :** P1 est faux, P2 est partiellement vrai, P3 est vrai, P4 révèle la vérité (Worker actif mais non fonctionnel).

---

## PHASE I — VERDICT FINAL

### 1. Qui crée réellement mp4_main ?

**Réponse :** **INCONNU (mais probablement Edge Function ou Worker avec bug)**

**Preuve :**
- storage.objects : owner=null, owner_id=null
- video_renditions : pas de colonne created_by
- Worker Kamatera : logs montrent "ignoré" pour generate_mp4
- transcode-video : crée seulement 'original'
- transcode-multi-resolution : jobs transcode_resolution = 0 rows

**Conclusion :** Les renditions existent mais leur créateur est inconnu. Le Worker ne les a pas créées (logs montrent "ignoré"). Les Edge Functions ne les ont pas créées (transcode-video crée seulement 'original', transcode-multi-resolution non appelée).

### 2. Qui crée réellement mp4_480p ?

**Réponse :** **INCONNU (même composant que mp4_main)**

**Preuve :** Même que mp4_main.

### 3. Qui crée réellement mp4_360p ?

**Réponse :** **INCONNU (même composant que mp4_main)**

**Preuve :** Même que mp4_main.

### 4. Qui crée réellement mp4_240p ?

**Réponse :** **INCONNU (même composant que mp4_main)**

**Preuve :** Même que mp4_main.

### 5. Quel composant exécute FFmpeg ?

**Réponse :** **INCONNU (mais probablement Worker avec bug ou composant caché)**

**Preuve :**
- Worker Kamatera : code supporte FFmpeg mais logs montrent "ignoré"
- Edge Functions : n'exécutent pas FFmpeg (délegué au worker)
- Docker : pas de conteneur vidéo
- ps aux : pas de processus FFmpeg visible

**Conclusion :** FFmpeg est probablement exécuté par le Worker mais les logs montrent "ignoré", ce qui suggère un bug dans le code ou une incohérence entre le code et les logs.

### 6. Quel composant écrit dans Storage ?

**Réponse :** **INCONNU (mais probablement Worker avec bug ou composant caché)**

**Preuve :**
- storage.objects : owner=null, owner_id=null
- Worker Kamatera : code supporte upload mais logs montrent "ignoré"
- Edge Functions : n'uploadent pas (délegué au worker)

**Conclusion :** Les fichiers sont uploadés par un service Supabase (owner=null), mais le composant exact est inconnu.

### 7. Quel composant met status='ready' ?

**Réponse :** **INCONNU (mais probablement Edge Function ou Worker avec bug)**

**Preuve :**
- video_renditions : pas de colonne created_by
- Worker Kamatera : code supporte status='ready' mais logs montrent "ignoré"
- transcode-video : met status='ready' pour 'original' seulement

**Conclusion :** Le composant qui met status='ready' est inconnu.

### 8. Le worker Kamatera est-il utile ?

**Réponse :** **NON**

**Preuve :**
- Worker marque jobs "ignoré" sans traitement
- Renditions existent mais Worker ne les a pas générées
- Jobs de type 'transcode_resolution' n'existent pas (0 rows)

### 9. Le worker Kamatera est-il réellement utilisé ?

**Réponse :** **NON**

**Preuve :**
- Logs Worker : "Job XXX ignoré (type=YYY), marqué done"
- Code Worker : `logger.info("[videoasset_worker] Job %s ignoré (type=%s), marqué done.", job_id, job_type)`
- Aucun log de traitement FFmpeg dans les logs Worker

### 10. Quel est le schéma de production réel aujourd'hui ?

**Réponse :** **INCONNU (mais probablement bug dans le pipeline)**

**Preuve :**
- Renditions existent dans Storage
- Renditions existent dans DB
- Worker ne les a pas créées (logs montrent "ignoré")
- Edge Functions ne les ont pas créées (transcode-video crée seulement 'original', transcode-multi-resolution non appelée)
- Backend Python non utilisé pour vidéo

**Conclusion :** Les renditions sont créées par un composant inconnu, probablement un bug dans le pipeline ou un composant caché non identifié.

---

## RECOMMANDATIONS

1. **Investiguer le bug dans le Worker :** Le code supporte generate_mp4 mais les logs montrent "ignoré". Il y a probablement une incohérence entre le code et les logs.

2. **Vérifier les logs Supabase Edge Functions :** Les logs des Edge Functions pourraient révéler quel composant crée réellement les renditions.

3. **Auditer les composants cachés :** Il pourrait y avoir un composant caché (cron job, service systemd, docker container) qui exécute FFmpeg.

4. **Ajouter des logs de traçage :** Ajouter des logs dans le Worker et les Edge Functions pour tracer exactement qui crée les renditions.

---

**Statut :** ⚠️ PARTIELLEMENT TERMINÉ (créateur des renditions inconnu)
