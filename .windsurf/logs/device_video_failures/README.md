# Logs d’échecs vidéo par device

Ce dossier est destiné à recevoir des logs détaillés d’échecs de lecture vidéo
(par exemple TECNO LD7, anciens Android, etc.).

Exemples de fichiers à placer ici :
- `tecno_ld7_video_feed_YYYYMMDD.txt`
- `android_generic_decoder_errors_YYYYMMDD.txt`

Chaque fichier doit idéalement contenir :
- le modèle du device
- la version d’Android
- les logs pertinents (logcat, stacktrace Flutter, erreurs MediaCodec/ExoPlayer)
- le contexte (écran, URL vidéo, rendition utilisée)
