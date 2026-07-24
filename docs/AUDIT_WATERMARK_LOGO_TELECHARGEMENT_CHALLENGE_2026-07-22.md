# Audit — Filigrane (logo animé « façon TikTok ») au téléchargement des vidéos Challenge

**Projet :** Academia (Flutter + Supabase + Kamatera)
**Date :** 22 juillet 2026
**Périmètre :** mécanisme d'incrustation du logo Academia lors du téléchargement d'une vidéo Challenge / vidéo libre.
**Méthode :** audit statique du code Flutter + interrogation en direct de Supabase (RPC admin `admin_execute_sql`, clé service_role de `.windsurf/.env`) + interrogation SSH en direct de Kamatera (`185.167.97.144`, scripts `.windsurf/audit_kamatera_video.py`) + recherche externe sur le comportement du filigrane TikTok.
**Nature :** lecture seule. Aucun code ni objet base/serveur n'a été modifié. Ce document est un diagnostic + des propositions.

---

## 1. Verdict en une phrase

Le logo ne s'incruste jamais visiblement parce que **deux défaillances indépendantes se cumulent** : côté serveur Kamatera le fichier logo déployé est un PNG **transparent de 1×1 pixel** (donc filigrane invisible même quand le rendu réussit), et côté client Flutter le flux de téléchargement **abandonne le rendu serveur après 3 secondes** et enregistre la **vidéo source brute, non filigranée**. Résultat : dans la quasi‑totalité des cas l'utilisateur récupère une vidéo sans aucun logo ; dans le cas résiduel où il attend le rendu serveur, le logo est invisible.

---

## 2. Cartographie : il existe DEUX systèmes de filigrane, incohérents

L'application contient deux implémentations parallèles qui ne se parlent pas.

### 2.1 Système A — Client Flutter `WatermarkService` (le « bon », mais inutilisé pour les challenges)

Fichier : `academia_app/lib/games/services/watermark_service.dart`

- Vrai style TikTok : **saut aux 4 coins toutes les 3 s** (TL→BR→TR→BL) via une expression `overlay` avec `mod(floor(t/3),4)`.
- Logo réel `assets/ACADEMIA_logo1.png`, opacité 0.35, échelle 8 % de la hauteur, `lanczos`.
- Stratégie robuste à 3 niveaux de repli (animé → statique coin → overlay minimal).
- **Problème d'usage :** il n'est appelé QUE par les jeux :
  - `lib/games/screens/auto_record_game_wrapper.dart:146`
  - `lib/games/screens/games_hub_screen.dart:746` et `:1002`
- Il **n'est jamais appelé** par le pipeline Challenge ni par le flux de téléchargement. Le commentaire du flux de download « already watermarked locally » est donc **faux** pour les vidéos Challenge.

### 2.2 Système B — Worker serveur Kamatera (celui qui alimente réellement le téléchargement)

Service `video-worker.service` → `/opt/video-worker/videoasset_worker.py` (machine `185.167.97.144`).

- Fonction `_run_ffmpeg_export_watermarked()` : overlay **dérive sinusoïdale douce** vers le coin bas-droite (`sin`/`cos`, périodes 6 s et 7 s), opacité 0.5, échelle 12 % de la largeur via `scale2ref`.
- C'est ce worker qui consomme les jobs `export_watermarked` de la table `app.video_processing_jobs` et publie la rendition `export_watermarked` dans `app.video_renditions`.

Deux styles d'animation différents (saut 4 coins vs dérive coin bas-droite), deux logos, deux opacités, deux échelles. **Aucune source de vérité unique.**

---

## 3. Flux réel de téléchargement (challenge) et sa chaîne de dépendances

`student_challenges_tab.dart` → `_downloadWatermarkedWithProgressSheet()` (l. 2853+) :

1. **STEP 0** — cherche une rendition déjà prête (`_pickWatermarkedUrlFromRenditions`).
2. **STEP 1** — sinon appelle la RPC `app_student_request_video_export_watermarked(p_video_asset_id)` (via `student_challenges_provider.dart:196`).
3. **STEP 2** — *polling* du statut via `app_student_get_video_export_watermarked_status(...)`.
4. **STEP 3** — repli sur `fallbackVideoUrl` (la vidéo **source**).
5. **STEP 4-6** — téléchargement HTTP + `SaverGallery.saveFile` dans `Movies`.

Côté base, les deux RPC (vérifiées en direct — elles existent et répondent `not_authenticated` hors session) :

- `public.app_student_request_video_export_watermarked` — `SECURITY DEFINER`. Contrôle `allow_download` sur `app.challenge_participations` / `app.free_videos`, renvoie la rendition `export_watermarked` si `status='ready'`, **sinon enfile un job** `export_watermarked` (`status='queued'`) dans `app.video_processing_jobs` et renvoie `status='queued'`.
- `public.app_student_get_video_export_watermarked_status` — même contrôle de droits, renvoie l'état du dernier job (`queued`/`running`/`processing`/`failed`/`ready`).

**Point clé d'architecture :** ces RPC ne rendent rien. Elles délèguent 100 % du travail d'incrustation au worker Kamatera. Si le worker produit un logo invisible, la RPC répond quand même `ready` avec une URL — le contrat « ready » ne garantit pas un logo visible.

> Note : la fonction `app.app_prepare_watermarked_asset(p_asset, p_action)` existe aussi mais concerne un **autre** sujet (assets commerciaux, filigrane **texte** « Nexiom Group · <ref> »). Elle n'intervient pas dans le logo des vidéos Challenge — à ne pas confondre.

---

## 4. État réel constaté en direct (22/07/2026)

### 4.1 Supabase — table `app.video_processing_jobs`

| job_type | done | failed | en file | job le plus récent |
|---|---|---|---|---|
| `export_watermarked` | 13 | 8 | **0** | **07/06/2026** |
| `generate_mp4` | 164 | 19 | 0 | 22/07/2026 |
| `extract_metadata` | 170 | 2 | 0 | 22/07/2026 |

- Renditions `export_watermarked` avec `status='ready'` : **seulement 5** (la plus récente 07/06/2026), pour 13 jobs « done » → incohérence done/rendition.
- Aucun job `export_watermarked` créé depuis 6 semaines, alors que `generate_mp4`/`extract_metadata` tournent aujourd'hui → **le chemin filigrane n'est quasiment plus exercé** (cf. bug client §5.4).

### 4.2 Kamatera — worker vivant, file vide

- `video-worker.service`, `academia-compress.service`, `whiteboard-worker.service` = **active/running**. ffmpeg **6.1.1** présent.
- Journal worker : boucle toutes les 5 s, `« Aucun job video_processing_jobs en file d'attente »` → le worker fonctionne mais n'a rien à traiter.

### 4.3 Le logo serveur est un pixel transparent — **cause racine n°1**

```
/opt/video-worker/academia.png : PNG image data, 1 x 1, 8-bit/color RGBA — 70 octets
```

Le vrai logo existe pourtant dans le repo : `academia_app/assets/ACADEMIA_logo1.png` = **1024×1536, 2,09 Mo**. Le worker pointe (via `.env WATERMARK_LOGO_PATH`) sur le **1×1**. Donc tout export « réussi » incruste un logo **invisible**.

### 4.4 Historique d'échecs ffmpeg — **fragilité n°2**

Erreurs réelles des jobs `failed` :

- `Watermark logo missing: /assets/images/academia.png` → chemin par défaut du code (`/opt/assets/images/academia.png`, l. 44-45) **inexistant** ; seul l'override `.env` évite le crash, mais il pointe sur le 1×1.
- `Expressions with scale2ref variables are not valid in scale filter` (code 234) → le filtre `scale2ref` avec `w='min(iw,main_w*0.12)'` est **rejeté** (comportement `scale2ref` déprécié/non portable, notamment ffmpeg 7.x). Le rendu n'est donc pas portable d'une machine/version ffmpeg à l'autre.

---

## 5. Défauts, classés (revue de code)

| # | Sévérité | Localisation | Défaut | Conséquence |
|---|---|---|---|---|
| 1 | **Bloquant** | Kamatera `/opt/video-worker/academia.png` | Logo = PNG transparent 1×1 | Filigrane **invisible** sur tout export serveur |
| 2 | **Bloquant** | `videoasset_worker.py` `_run_ffmpeg_export_watermarked` (`scale2ref`) | Filtre non portable, rejeté selon version ffmpeg | Jobs `failed`, rendu instable |
| 3 | **Majeur** | `videoasset_worker.py:44-45` | Chemin logo par défaut `/opt/assets/images/academia.png` inexistant | Dépendance fragile à `.env` |
| 4 | **Majeur** | `student_challenges_tab.dart:2904-2905` | `rpcTimeout=3s` + polling désactivé dès qu'un `fallbackVideoUrl` existe | Le client **abandonne** le rendu serveur (qui prend > 3 s) et enregistre la **source brute non filigranée** |
| 5 | **Majeur** | Architecture | Deux systèmes de filigrane (client jeux vs serveur challenge) non unifiés | Incohérence visuelle, logo/opacité/animation différents, double maintenance |
| 6 | **Moyen** | Contrat RPC | `status='ready'` renvoyé sans garantie que le logo soit visible | Faux positif : « prêt » ≠ « filigrané » |
| 7 | **Moyen** | `student_challenges_tab.dart:2975` | Commentaire « already watermarked locally » faux pour les vidéos Challenge | Hypothèse erronée entretenue dans le code |
| 8 | **Mineur** | Data | 13 jobs « done » mais 5 renditions `ready` | Divergence état job / rendition à instrumenter |

**Chaîne causale du symptôme « ça ne marche pas » :** #4 fait que l'utilisateur télécharge presque toujours la source brute (aucun logo) ; et dans le cas résiduel où il attend, #1 rend le logo invisible. Les deux chemins échouent → **aucun logo visible, jamais**.

---

## 6. Recherche externe — comment se comporte le filigrane TikTok

Synthèse (sources en fin de document). **Il n'existe pas de spécification technique officielle publiée par TikTok** pour l'animation du filigrane : le comportement ci-dessous est celui, largement documenté, observé sur les vidéos téléchargées.

- **Contenu** : logo TikTok **+ @nom d'utilisateur** du créateur (attribution).
- **Mouvement** : le filigrane **saute d'une position à une autre** pendant la lecture — effet « économiseur d'écran DVD ». Il alterne principalement entre coins, avec une **légère variation d'opacité**.
- **Cadence** : repositionnement **périodique** (de l'ordre de quelques secondes), pas une dérive continue.
- **Intention** : appliqué **au moment du téléchargement**, pour rendre le **recadrage/suppression difficile** sans sacrifier une grande partie du cadre 9:16, tout en gardant l'attribution visible mais non invasive.

**Lecture pour Academia :** l'implémentation *client* existante (Système A : saut 4 coins toutes les 3 s + logo réel + opacité modérée) est **conceptuellement la plus proche de TikTok**. La dérive sinusoïdale du serveur (Système B) est plus « molle » et moins protectrice contre le recadrage. La vraie valeur TikTok ajoutée manquante partout : le **@pseudo** à côté du logo.

---

## 7. Propositions

### 7.1 Décision d'architecture à trancher (préalable)

Choisir **une seule** source de vérité :

- **Option A — Filigrane 100 % serveur (Kamatera).** Recommandée pour la robustesne et la non‑contournabilité : le logo est appliqué au serveur, identique sur tous les appareils, impossible à éviter côté client. Coût : dépendance au worker + latence de rendu (à masquer par pré‑rendu à l'upload, cf. 7.3).
- **Option B — Filigrane 100 % client (Flutter).** Recommandée pour la simplicité/latence nulle : réutiliser `WatermarkService` (déjà fonctionnel et « TikTok-like ») au moment du download. Coût : rendu dépendant du device, contournable par un utilisateur avancé, qualité FFmpegKit variable.

> Recommandation : **Option A comme cible** (cohérence + protection), avec l'**Option B en repli** immédiat si le rendu serveur n'est pas prêt — mais alors le repli doit **réellement filigraner** (aujourd'hui il ne le fait pas).

### 7.2 Correctifs P0 (débloquent le visuel immédiatement)

**a) Déployer le vrai logo sur Kamatera.** Remplacer `/opt/video-worker/academia.png` (1×1) par une variante compacte du logo réel : PNG à **fond transparent**, largeur ~512 px, idéalement une version **horizontale/monochrome blanche** pour rester lisible sur fond clair comme sombre. Corriger aussi `WATERMARK_LOGO_PATH` et le chemin par défaut du code pour qu'ils pointent sur ce fichier.

**b) Rendre le filtre ffmpeg portable et « TikTok 4 coins ».** Abandonner `scale2ref`. Sonder la taille avec `ffprobe`, redimensionner le logo en amont, puis overlay avec saut périodique + `@pseudo`. Filtre proposé (à valider sur ffmpeg 6.1.1 du serveur) :

```text
# 1) ffprobe → hauteur H de la vidéo ; logoH = round(H*0.08) ; m = round(H*0.04)
# 2) filter_complex :
[1:v]format=rgba,scale=-1:{logoH},colorchannelmixer=aa=0.38[wm];
[0:v][wm]overlay=
  x=if(between(mod(floor(t/3)\,4)\,1\,2)\,W-w-{m}\,{m}):
  y=if(mod(mod(floor(t/3)\,4)\,2)\,H-h-{m}\,{m}),
drawtext=text='@{username}':fontsize={logoH}/2.5:fontcolor=white@0.85:
  box=1:boxcolor=black@0.25:boxborderw=6:
  x=if(between(mod(floor(t/3)\,4)\,1\,2)\,W-tw-{m}\,{m}):
  y=if(mod(mod(floor(t/3)\,4)\,2)\,H-h-{m}-th-6\,{m}+h+6),
format=yuv420p
```

Cela reproduit le saut 4 coins de TikTok (période 3 s), ajoute l'attribution `@pseudo`, opacité non invasive (~0,38 logo / 0,85 texte). C'est l'alignement du Système B sur le Système A + le manque TikTok (le pseudo).

**c) Corriger le repli client (bug #4).** Deux variantes :
- si Option A : porter le premier timeout à ~10-12 s et **réactiver le polling** même en présence d'un fallback, afin d'attendre réellement le rendu filigrané ; n'utiliser le fallback brut qu'en dernier recours **explicitement signalé** à l'utilisateur.
- si Option B (repli) : avant `SaverGallery.saveFile`, faire passer la vidéo par `WatermarkService.addWatermark(file.path)` pour garantir un logo, même quand la source est brute. Supprimer/mettre à jour le commentaire trompeur l. 2975.

### 7.3 Améliorations P1

- **Pré-rendu à l'upload** : enfiler le job `export_watermarked` dès la publication de la vidéo (pas seulement au 1er download) pour que la rendition soit `ready` avant que l'utilisateur clique → latence de download quasi nulle en Option A.
- **Durcir le contrat RPC** : ne considérer une rendition `ready` que si le worker a écrit un marqueur « logo appliqué » (ex. `payload.watermark_ok=true` + taille logo > seuil), pour éliminer les faux positifs (#6).
- **Unifier le logo & le style** entre jeux et challenges (une seule constante d'asset, une seule fonction de construction de filtre partagée conceptuellement).
- **Nettoyage/observabilité** : investiguer l'écart 13 « done » / 5 renditions, purger/rejouer les 8 jobs `failed`, ajouter une métrique « % downloads réellement filigranés ».

### 7.4 Plan de validation (avant de considérer le sujet clos)

1. Rendu d'un job `export_watermarked` de test → **ouvrir la MP4 et vérifier visuellement** que le logo saute aux 4 coins et que `@pseudo` est lisible mais non invasif.
2. Test device réel : download challenge avec worker lent → vérifier que la vidéo enregistrée **contient** le logo (pas la source brute).
3. Test recadrage : confirmer qu'on ne peut pas rogner le logo sans perdre une grande partie du cadre.
4. Régression : s'assurer que le filigrane des **jeux** (Système A) n'est pas cassé.
5. Vérifier la portabilité ffmpeg (6.1.1 serveur) — pas d'erreur `scale2ref`.

---

## 8. Ce qui fonctionne déjà (à ne pas casser)

- Le worker Kamatera est **vivant, stable et rapide** sur `generate_mp4` / `extract_metadata` (jobs traités le jour même). L'infrastructure de queue `video_processing_jobs` → `video_renditions` est saine ; seul le **contenu** du job `export_watermarked` (logo + filtre) est défaillant.
- Les RPC de droits (`allow_download`) sont correctes et sécurisées (`SECURITY DEFINER`, contrôle propriétaire/audience).
- `WatermarkService` (jeux) produit déjà le rendu « façon TikTok » souhaité — c'est la meilleure base de référence pour l'unification.

---

## Sources (recherche externe TikTok)

- [How to Change Position TikTok Watermark — TikTok Discover](https://www.tiktok.com/discover/how-to-change-position-tiktok-watermark)
- [How to Remove the TikTok Watermark — Buffer](https://buffer.com/resources/remove-tiktok-watermark/)
- [How to Remove TikTok Watermark — Hopper HQ](https://www.hopperhq.com/blog/how-to-remove-tiktok-watermark/)
- [How to Remove TikTok Watermark: A Complete Guide — NodeMaven](https://nodemaven.com/blog/remove-tiktok-watermark/)
- [TikTok Watermark Still There — DropZap](https://www.dropzap.digital/blog/tiktok-watermark-still-there-fix)
- [Remove the TikTok logo without losing engagement — watermark.phd](https://watermark.phd/blog/how-to-remove-the-tiktok-logo)

## Addendum — Corrections appliquées (22/07/2026)

Décision retenue : **filigrane serveur (Kamatera) = source de vérité**, avec **filigrane client garanti en repli**. Style unifié « TikTok » : logo blanc détouré semi-transparent qui **saute aux 4 coins toutes les 5 s** (BL → TR → BR → TL), discret et non invasif.

**Asset filigrane (nouveau).** Génération d'un `academia_wm.png` propre (logo blanc + halo sombre sur fond **transparent**) à partir du line-art `ACADEMIA_logo1.png` (le PNG d'origine avait un fond gris, d'où le rectangle disgracieux). Le halo assure la lisibilité sur fond clair **comme** sombre. Validé visuellement sur fonds sombre / clair / chargé.
- Repo : `academia_app/assets/academia_wm.png` (couvert par le glob `assets/` du `pubspec.yaml`, aucune modif pubspec).
- Serveur : déployé en `/opt/video-worker/academia_wm.png`.

**Serveur Kamatera (`/opt/video-worker/videoasset_worker.py`).**
- Remplacement du logo 1×1 par le vrai asset ; `WATERMARK_LOGO_PATH` (dans `.env`) et le chemin par défaut du code corrigés vers `academia_wm.png`.
- Réécriture de `_run_ffmpeg_export_watermarked` : abandon de `scale2ref` (non portable) au profit d'un **sondage `ffprobe`** des dimensions + `scale` simple, puis overlay à saut 4 coins (période 5 s, `aa=0.85`, logo 8 % de la hauteur, marge 5 %). Testé et validé sur ffmpeg 6.1.1 du serveur.
- Service `video-worker.service` redémarré, actif, sans erreur.
- **Validation bout-en-bout** : un job `export_watermarked` réel enfilé le 22/07 a été traité par le nouveau code → rendition fraîche avec logo **visible** et mobile (vérifié sur frames extraites BL puis TR).
- **Rollback** : sauvegardes `/opt/video-worker/videoasset_worker.py.bak_20260722_143745` et `/opt/video-worker/.env.bak_20260722_143745`.

**Client Flutter.**
- `lib/games/services/watermark_service.dart` : asset → `assets/academia_wm.png` ; mouvement aligné (saut 4 coins / 5 s, `aa=0.85`). Bénéficie aussi aux jeux (cohérence de marque).
- `lib/features/student/tabs/student_challenges_tab.dart` (`_downloadWatermarkedWithProgressSheet`) : le client **attend et sonde réellement** le rendu filigrané serveur (fin du timeout 3 s + polling désormais actif même en présence d'un fallback). Ajout d'un indicateur `serverWatermarked` et d'une **étape de repli (STEP 5b)** : si la vidéo téléchargée n'est pas filigranée côté serveur, le logo est incrusté **localement** via `WatermarkService` avant l'enregistrement. Résultat : **aucune vidéo ne peut plus sortir sans logo**.
- Non compilable ici (SDK Flutter du repo en CRLF, non exécutable sous Linux) ; revue statique effectuée. À valider par `flutter analyze` + test device côté dev.

**Reste à faire (recommandé, non bloquant).**
- P1 : pré-rendre le job `export_watermarked` **à la publication** (pas seulement au 1er download) → latence de téléchargement quasi nulle.
- Nettoyer le dossier résiduel `academia_app/assets/watermark/` (doublon non bundlé de l'asset ; suppression non permise depuis cette session).
- Durcir le contrat RPC « ready » (marqueur « logo appliqué ») et investiguer l'écart historique 13 « done » / 5 renditions.

## Addendum 2 — Pré-rendu à la publication (parité TikTok, déployé le 22/07)

Mécanisme confirmé identique à TikTok/Facebook : ils maintiennent deux versions serveur — une *propre* pour la lecture, une *filigranée* pour le téléchargement (logo cuit). Academia fait pareil (source propre + rendition `export_watermarked`). Le « pré-rendu » ne change pas le mécanisme, il prépare la version filigranée **d'avance** pour un téléchargement **instantané** (au lieu d'attendre la 1re demande).

Déployé en base (migration `supabase/migrations/20260722_prerender_watermark_on_publish.sql`) :
- `app.enqueue_export_watermarked_job(uuid)` — enfile un job (idempotent : rien si rendition déjà prête / job déjà en file / source pas encore prête).
- `app.asset_is_downloadable(uuid)` — la vidéo liée autorise-t-elle le téléchargement.
- **Trigger A** sur `app.video_renditions` (mp4_main devient `ready`) → pré-rendu si la vidéo est téléchargeable.
- **Trigger B** sur `app.challenge_participations` et `app.free_videos` (`allow_download` passe à `true`) → pré-rendu si la source est prête.
- Toutes les fonctions sont `EXCEPTION WHEN OTHERS` → elles ne peuvent **jamais** bloquer le transcodage ni la mise à jour d'une vidéo.

Validé en direct : triggers attachés (vérif `pg_trigger`) ; appel de la fonction de pré-rendu sur une vidéo éligible → job enfilé → worker → rendition `export_watermarked` prête en ~24 s. Rollback complet documenté en tête de la migration.

## Fichiers & objets audités

- Flutter : `academia_app/lib/games/services/watermark_service.dart`, `.../features/student/tabs/student_challenges_tab.dart` (`_downloadWatermarkedWithProgressSheet`, `_pickWatermarkedUrlFromRenditions`), `.../providers/student_challenges_provider.dart`.
- Supabase (via RPC admin `admin_execute_sql`) : `public.app_student_request_video_export_watermarked`, `public.app_student_get_video_export_watermarked_status`, `app.app_prepare_watermarked_asset`, tables `app.video_processing_jobs`, `app.video_renditions`.
- Kamatera (`185.167.97.144`, SSH) : `video-worker.service`, `/opt/video-worker/videoasset_worker.py`, `/opt/video-worker/academia.png`, `/opt/video-worker/.env`, `/root/compress-service/app.py`.
