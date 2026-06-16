# Audit de la vidéo stack Academia – Étape 0

## Backend – studio_video_renderer.py

Fichier : `academia_bobodo_backend/studio_video_renderer.py`

- **Fonctions de transcodage**
  - `_run_ffmpeg_transcode` ("main")
    - max_width = 720
    - max_bitrate_k = 900
    - audio_bitrate_k = 96
    - fps = None (fps source conservé)
  - `_run_ffmpeg_transcode_480p`
    - max_width = 480
    - max_bitrate_k = 600
    - audio_bitrate_k = 96
    - fps = 30
  - `_run_ffmpeg_transcode_360p`
    - max_width = 360
    - max_bitrate_k = 450
    - audio_bitrate_k = 80
    - fps = 30
  - `_run_ffmpeg_transcode_240p`
    - max_width = 240
    - max_bitrate_k = 300
    - audio_bitrate_k = 64
    - fps = 24

- **Helper commun** : `_run_ffmpeg_generic(input_path, max_width, max_bitrate_k, audio_bitrate_k, label, fps=None)`
  - **Codec vidéo / profil**
    - `-c:v libx264`
    - `-profile:v baseline`
    - `-level 3.0`
    - `-x264-params ref=1:bframes=0:cabac=0:deblock=0:weightp=0:no-scenecut=1:level=30:vbv-maxrate={max_bitrate_k}:vbv-bufsize={2*max_bitrate_k}`
  - **Pixel format / colorimétrie**
    - `-pix_fmt yuv420p`
    - `-color_primaries bt709`
    - `-color_trc bt709`
    - `-colorspace bt709`
  - **GOP / timing**
    - `-g 30`
    - `-keyint_min 30`
    - `-sws_flags lanczos+accurate_rnd+full_chroma_int`
    - fps forcé avec `-r` quand `fps` non nul (480p/360p/240p), sinon fps source.
  - **Audio**
    - `-c:a aac`
    - `-ac 2`
    - `-ar 44100`
    - `-b:a {audio_bitrate_k}k`
  - **VBV / faststart**
    - `-maxrate {max_bitrate_k}k`
    - `-bufsize {2*max_bitrate_k}k`
    - `-movflags +faststart`
  - **Logs / erreurs**
    - Affiche la commande complète `[FFMPEG-{label}] Running command: ...`.
    - Affiche stderr en cas d’erreur et lève `HTTPException` 500.

**Conclusion Étape 0 (backend ffmpeg)** :
- Les 4 fonctions de transcodage existent et appellent bien un helper commun.
- Le profil H.264 Baseline Level 3.0 + yuv420p + GOP court + VBV et BT709 est bien appliqué à toutes les renditions.

---

## Backend – call_studio_video_render (main.py)

Fichier : `academia_bobodo_backend/main.py`
Fonction : `call_studio_video_render(video_url: str, overlays: Dict[str, Any], participation_id: str) -> Dict[str, Any]`

- **Étapes principales**
  - Nettoie/valide `video_url`.
  - Force `overlays` à un dict.
  - Variables de travail : `input_path`, `output_path_default`, `output_path_480p`, `output_path_360p`, `output_path_240p`.
  - `input_path = await _download_video_to_temp(url)`.
  - Génère les renditions :
    - `output_path_default = _run_ffmpeg_transcode(input_path)`
    - `output_path_480p = _run_ffmpeg_transcode_480p(input_path)`
    - `output_path_360p = _run_ffmpeg_transcode_360p(input_path)`
    - `output_path_240p = _run_ffmpeg_transcode_240p(input_path)`
  - Upload Supabase Storage (bucket `challenge-media`) via `_upload_to_supabase_storage` :
    - `url_default`
    - `url_480p`
    - `url_360p`
    - `url_240p`

- **Construction de l’URL par défaut**
  - `default_url = (url_480p or '') or (url_360p or '') or (url_240p or '') or (url_default or '')`
  - Si `default_url` est vide → `HTTPException(500, "Aucune URL vidéo rendue disponible.")`.

- **Construction de `video_renditions`**
  - Toujours : `video_renditions = {"default": default_url}`.
  - Si présentes :
    - `video_renditions["480p"] = url_480p`
    - `video_renditions["360p"] = url_360p`
    - `video_renditions["240p"] = url_240p`
    - `video_renditions["source"] = url_default` si différente de `default_url`.

- **Nettoyage**
  - Supprime (best-effort) `input_path` et toutes les sorties intermédiaires.

- **Valeur de retour**
  - `{"video_url": default_url, "video_renditions": video_renditions}`.

**Conclusion Étape 0 (orchestration backend)** :
- `call_studio_video_render` génère bien 4 renditions (main/480/360/240), les uploade, puis construit un dictionnaire `video_renditions` cohérent avec les clés attendues.
- `video_url` retourné au reste du backend correspond à `default_url` (priorité 480p → 360p → 240p → source), ce qui alimente ensuite les RPC côté Supabase.

---

## Flutter – _ChallengeVideoItemState (feed "Vidéos de challenges")

Fichier : `academia_app/lib/features/student/tabs/student_challenges_tab.dart`
Classe : `_ChallengeVideoItemState`

- **Initialisation**
  - `initState` appelle `_startInit()`.
  - `_startInit()` :
    - Loggue l’objet brut : `ANDROID VIDEO DEBUG :: raw video object = ...`.
    - Lit `widget.video['video_renditions']` si c’est un `Map` → `_renditions`.
    - Appelle `_pickBestUrl()` et stocke le résultat dans `_selectedUrl`.
    - Log : `ANDROID VIDEO DEBUG :: picked URL = ...`.

- **Sélection de l’URL (renditions)**
  - `_pickBestUrl()` :
    - Si `_renditions == null` → retourne `video['video_url']` (trim).
    - Sinon, priorité :
      - `const order = ['360p', '240p', '480p', 'default', 'source'];`
      - Retourne la première rendition non vide, en logguant :
        - `ANDROID VIDEO DEBUG :: found rendition <key> = <url>`.
    - Si aucune rendition valide n’est trouvée → fallback sur `video['video_url']`.

- **Filtrage des URLs brutes**
  - Après `_pickBestUrl` :
    - Si `_selectedUrl` est vide → `_setError("Aucune URL vidéo disponible (renditions absentes ou invalides).")`.
    - Si l’URL ne contient pas `/renders/` :

      ```dart
      if (!_selectedUrl.contains("/renders/")) {
        _setError("Android ne lit pas la vidéo brute. Rendition absente.\nURL : $_selectedUrl");
        return;
      }
      ```

- **Initialisation du contrôleur vidéo**
  - Utilise `VideoPlayerController.networkUrl(Uri.parse(_selectedUrl))`.
  - Appelle `initialize()`, `setLooping(true)`, `play()`.
  - Si succès :
    - `setState(() => _initialized = true);`
    - Log : `ANDROID VIDEO DEBUG :: init success for <url>`.
  - En cas d’exception :

    ```dart
    print("ANDROID VIDEO ERROR :: $e");
    _setError("Erreur Android/ExoPlayer :\n$e\n\nURL : $_selectedUrl");
    ```

- **Affichage en cas d’erreur**
  - Si `_errorMessage != null` :
    - Affiche un écran noir avec texte :
      - `❌ Vidéo indisponible\n\n<_errorMessage>`.
    - Conserve les overlays meta (_buildOverlayMeta) et les actions (_buildRightActions) par-dessus.

- **Affichage normal**
  - Si pas d’erreur et `_controller == null` :
    - Texte : `Vidéo indisponible (aucun contrôleur)`.
  - Si `_initialized == true` :
    - Affiche `StudentVideoPlayer(controller: _controller!, overlays: overlays, feedMode: true)`.

**Conclusion Étape 0 (Flutter feed)** :
- Le feed utilise bien `video_renditions` si présent, avec une priorité adaptée aux appareils fragiles : `360p → 240p → 480p → default → source`.
- Les URLs sans `/renders/` sont explicitement refusées pour Android (on évite les vidéos brutes).
- En cas d’erreur ExoPlayer, l’UI affiche un message explicite et l’URL utilisée.

---

## Logs TECNO LD7 et échecs de décodage

- Les logs collectés (`.windsurf/logs/tecno_ld7_video_feed_20251208.txt`) montrent :
  - Enregistrement CameraX correct (AudioEncoder/VideoEncoder, MPEG4Writer OK).
  - Appel backend Studio OK :
    - `POST /studio/video/render` avec `participation_id=fcc962af-...`.
    - Réponse 200 avec `video_url` dans `challenge-media/renders/...`.
  - Bug Flutter séparé :
    - Exception `This widget has been unmounted, so the State no longer has a context` dans `_StudentChallengeVideoEditorScreenState._submitVideoChallenge` (lifecycle, hors sujet pour la lecture).
  - Échec de décodage vidéo sur le TECNO LD7 :
    - Décodage H.264 via `OMX.MTK.VIDEO.DECODER.AVC`.
    - Format vu par ExoPlayer : `video/avc, avc1.42C01E, [480, 640, 30.0, ColorInfo(BT601, Limited range,...)]`, `format_supported=YES`.
    - Erreurs répétées du codec MediaTek :
      - `Failed to allocate buffers after transitioning to IDLE state (error 0xffffffea)`.
      - `signalError(omxError 0x8000101c, internalError -2147483648)`.
      - Remontée en `DecoderInitializationException: start failed` côté ExoPlayer.

**Conclusion Étape 0 (logs TECNO)** :
- Le pipeline de rendu backend + URL /renders/ fonctionne comme prévu.
- Le problème principal vient du décodeur matériel MediaTek (`OMX.MTK.VIDEO.DECODER.AVC`) qui n’arrive pas à allouer ses buffers sur certains flux H.264 pourtant Baseline/Level 3.0.
- Une stack vidéo robuste doit donc intégrer un **fallback logiciel** (OMX.google.h264.decoder ou ffmpeg) côté Android, en plus des renditions backend déjà harmonisées.
