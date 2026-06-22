# Visibilité instantanée du feed — diagnostic & correctif

**Date :** 22 Juin 2026
**Objectif :** une vidéo publiée apparaît **immédiatement** dans le feed (UX TikTok),
sans attendre la fin du transcodage multi-résolution du worker Kamatera.

---

## 1. Cause racine (prouvée via `admin_execute_sql`)

Le feed `public.app_student_unified_video_feed` filtre les lignes par :

```
WHERE u.video_url IS NOT NULL
```

et `video_url` = **dernière `video_renditions` avec `status='ready'`**.

Une vidéo n'est donc visible que si elle possède au moins une rendition `ready`.

Or, au moment de la publication, **aucune rendition `ready` n'existe** :

- `app_videoasset_register_uploaded_source` (post-upload) met seulement
  `video_assets.status='uploaded'` + `video_sources.ingested_at=NOW()` et enfile
  les jobs worker. **Elle ne crée aucune rendition.**
- L'Edge Function `transcode-video` (censée créer instantanément une rendition
  `original` + passer `ready`) **échouait** : elle faisait
  `.select('id, status, owner_id')` alors que la colonne réelle est
  `owner_user_id` → erreur 400 → 404 → **aucune rendition `original`**.
- Les seules renditions `ready` viennent donc du **worker Kamatera**
  (`mp4_240p/360p/480p/main`), créées **tardivement**.

### Preuve (diag_feed_output_v4.txt)

| video_asset | source ingéré | rendition `ready` créée | délai |
|---|---|---|---|
| `c6f1ceb6…` (185 Mo) | 15:14:39 | 15:22:01 | **~7,5 min** |
| `3d99f815…` | 15:16:06 | 15:22:34 | **~6,5 min** |

`rendition_key` présents : `mp4_*` (worker) uniquement. **Aucun `original`.**
→ Entre la publication et la fin du worker, `video_url IS NULL` → **vidéo invisible**.

---

## 2. Correctifs

### 2.1 Production — Feed RPC (SQL, rétroactif, sans risque ingestion)

`sql_changes/change_20260622_feed_instant_visibility.sql` remplace
`app_student_unified_video_feed` pour résoudre `video_url` ainsi :

```
video_url = COALESCE(
  dernière rendition 'ready',
  URL publique de la SOURCE uploadée  (si video_sources.ingested_at IS NOT NULL)
)
```

- **Gate `ingested_at IS NOT NULL`** = fichier source réellement uploadé → jamais
  de vidéo « fantôme » avant la fin de l'upload.
- **Rétroactif** : corrige aussi toute vidéo déjà bloquée.
- **Read-path only** : ne touche pas au pipeline d'ingestion.
- Appliqué via `apply_feed_instant_visibility.py` → `admin_execute_sql`.

Comportement : lecture immédiate sur la source, puis montée en qualité
automatique quand les renditions du worker arrivent (le `video_renditions`
map se remplit). Aligné TikTok (playback-ready ≠ transcode-complete).

### 2.2 Repo — Edge Function `transcode-video`

`supabase/functions/transcode-video/index.ts` : `.select('id, status, owner_id')`
→ `.select('id, status')` (colonne `owner_id` inexistante). La fonction peut de
nouveau créer la rendition `original` + passer `ready`.

> ⚠️ Déploiement Edge non fiable ici : `deploy_edge_function.py` utilise la
> Management API avec la **service_role key**, or cette API exige un Personal
> Access Token (`sbp_…`). Le correctif 2.1 (SQL) rend la visibilité instantanée
> **indépendante** de ce déploiement. Le fix code reste correct pour le futur.

---

## 3. Vérification (mesurée en prod le 22/06/2026)

Appliqué via `apply_feed_instant_visibility.py` → `OK (function replaced)` ;
la nouvelle définition contient bien le fallback `app.video_sources`
(`has_fallback = true`).

Impact mesuré (`verify_feed_visibility.py`, requêtes `COUNT(*)`/`JOIN` simples) :

| Métrique (free_videos publiables) | Valeur |
|---|---|
| A. Total publiables | **64** |
| B. Visibles **avant** fix (≥1 rendition `ready`) | **43** |
| C. **Nouvellement** visibles (pas de rendition `ready`, mais source ingérée) | **21** |
| D. Encore invisibles (ni rendition ni source) | **0** |

→ **21 vidéos (~1/3) étaient bloquées invisibles**, désormais visibles ; **0**
vidéo publiable avec source uploadée ne reste cachée.

> Note outil : `admin_execute_sql` retourne vide pour les requêtes `GROUP BY` /
> sous-requêtes scalaires corrélées / `row_to_json(...)`, mais répond
> correctement aux `COUNT(*)` et `JOIN` simples (d'où `verify_feed_visibility.py`).

### Bout-en-bout (app)

Après publication, `video_publish_screen` → `_onReturnFromStudio(published)`
recharge le feed (`loadChallengeVideos`) et saute à l'index 0. Le serveur
renvoyant désormais la vidéo instantanément (fallback source), elle apparaît en
tête sans modification app. Côté lecture, `AdaptiveQualityService` utilise
`video_renditions` si présent, sinon `video_url` (= source) → lecture immédiate.

---

## 4. Rollback

Réappliquer la définition d'origine de `app_student_unified_video_feed`
(dump complet dans `diag_feed_output.txt`) via `admin_execute_sql`.

---

## 5. Tradeoff connu

Tant que le worker n'a pas fini, le feed sert le **fichier source brut**
(potentiellement volumineux, ex. 185 Mo) — identique à ce que la rendition
`original` aurait servi. C'est le compromis standard de la visibilité instantanée.
Atténuations possibles (hors scope immédiat) : compression côté client avant
upload, ou priorisation d'une rendition basse résolution rapide côté worker.
