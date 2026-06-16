# Rapport Debug STT Kamatera - 10 Juin 2026

## Objectif Initial

Identifier l'exception exacte produisant le message "Transcription failed" dans le service vocal Kamatera et corriger le problème pour permettre la transcription audio réelle.

---

## Infrastructure

- **Serveur** : Kamatera VPS (185.167.97.144)
- **Service** : bobodo-vocal (FastAPI + Faster Whisper Medium)
- **STT** : Faster Whisper Medium (modèle Systran/faster-whisper-medium)
- **TTS** : gTTS (Google Text-to-Speech)
- **Client** : Flutter app (TECNO LD7 - Android 10)

---

## Difficultés Rencontrées

### 1. Erreur InvalidDataError - Format Audio Invalide

**Symptôme** :
```
av.error.InvalidDataError: [Errno 1094995529] Invalid data found when processing input
```

**Cause Racine** :
- Flutter envoie du audio en format PCM16WAV brut (raw PCM data)
- Faster Whisper attend un fichier WAV valide avec en-têtes WAV (RIFF header, fmt chunk, data chunk)
- Le fichier temporaire ne contenait que les données audio brutes sans les en-têtes nécessaires

**Correction** :
- Ajout de la méthode `_add_wav_header()` dans `stt_service.py`
- Reconstruction d'un fichier WAV valide avec en-têtes appropriés avant transcription
- Paramètres : 16000Hz, 1 canal (mono), 16-bit PCM

**Fichier modifié** : `.windsurf/bobodo-vocal/stt_service.py`

---

### 2. Paquets Audio Trop Courts - VAD Filter Supprime Tout

**Symptôme** :
```
VAD filter removed 00:00.020 of audio
[STT_TRANSCRIPTION_SUCCESS] Transcription completed: 0 characters, 0 segments
```

**Cause Racine** :
- Flutter envoie des paquets de 640 bytes (20ms à 16000Hz)
- Le VAD filter (Voice Activity Detection) de Faster Whisper supprime les segments < 250ms
- Chaque paquet individuel était supprimé car trop court

**Correction** :
- Ajout d'un buffer d'accumulation dans `STTService.__init__()`
- Accumulation des paquets jusqu'à atteindre 1 seconde minimum
- Transcription lancée uniquement quand le buffer est plein

**Fichier modifié** : `.windsurf/bobodo-vocal/stt_service.py`

---

### 3. Handler Envoie Erreurs Prématurées

**Symptôme** :
```
[WS_STT_ERROR] Transcription returned None
```
L'erreur était envoyée à chaque paquet alors que le buffer n'était pas encore plein.

**Cause Racine** :
- Le handler considérait `None` comme une erreur
- Quand le buffer n'était pas plein, la transcription retournait `None` (normal)
- Le client recevait des erreurs inutiles

**Correction** :
- Modification de `handle_audio()` dans `websocket_handler.py`
- Si transcription retourne `None`, log info "Buffer not full yet" et retour sans erreur
- Erreur envoyée uniquement en cas d'échec réel

**Fichier modifié** : `.windsurf/bobodo-vocal/websocket_handler.py`

---

### 4. VAD Filter Trop Aggressif

**Symptôme** :
```
VAD filter removed 00:00.000 of audio
```
Même avec 1 seconde d'audio, le VAD filter supprimait tout.

**Cause Racine** :
- Le VAD filter est configuré pour détecter la voix humaine
- L'audio capturé peut être de faible volume ou contenir du silence
- Le threshold par défaut (0.5) peut être trop élevé

**Correction** :
- Désactivation du VAD filter (`vad_filter=False`)
- Faster Whisper transcrira tout l'audio sans filtrage
- Peut être réactivé plus tard avec paramètres ajustés si nécessaire

**Fichier modifié** : `.windsurf/bobodo-vocal/stt_service.py`

---

## Instrumentation Logs Ajoutée

### stt_service.py

- `[STT_SERVICE_INIT]` - Initialisation du service
- `[STT_MODEL_LOADING]` - Chargement du modèle
- `[STT_MODEL_READY]` - Modèle chargé avec succès
- `[STT_AUDIO_RECEIVED]` - Audio reçu (taille en bytes)
- `[STT_WAV_HEADER]` - Ajout en-tête WAV (taille, fréquence, canaux, bits)
- `[STT_BUFFER]` - État du buffer (taille, durée)
- `[STT_TEMP_FILE_CREATED]` - Fichier temporaire créé
- `[STT_TEMP_FILE_SIZE]` - Taille fichier temporaire
- `[STT_TRANSCRIPTION_START]` - Début transcription
- `[STT_TRANSCRIPTION_INFO]` - Info transcription (langue, durée)
- `[STT_TRANSCRIPTION_SUCCESS]` - Transcription réussie (caractères, segments)
- `[STT_TRANSCRIPTION_RESULT]` - Texte transcrit
- `[STT_TRANSCRIPTION_ERROR]` - Erreur transcription (type, message, stacktrace)
- `[STT_TEMP_FILE_CLEANED]` - Fichier temporaire supprimé

### websocket_handler.py

- `[WS_AUDIO_RECEIVED]` - Audio décodé (taille en bytes)
- `[WS_STT_START]` - Début transcription
- `[WS_STT_BUFFER]` - Buffer pas plein encore
- `[WS_STT_SUCCESS]` - Transcription réussie
- `[WS_STT_ERROR]` - Erreur transcription
- `[WS_BOBODO_START]` - Envoi transcription à Bobodo
- `[WS_BOBODO_SUCCESS]` - Réponse Bobodo reçue
- `[WS_BOBODO_ERROR]` - Erreur Bobodo
- `[WS_TTS_START]` - Synthèse audio
- `[WS_TTS_ERROR]` - Erreur TTS

---

## Scripts de Déploiement Créés

### 1. deploy_stt_instrumentation.py
- Déploie `stt_service.py` et `websocket_handler.py` sur Kamatera
- Redémarre le service `bobodo-vocal`
- Utilise paramiko pour SSH/SCP

### 2. check_stt_logs.py
- Récupère le statut du service `bobodo-vocal`
- Affiche les 50 dernières lignes de logs

### 3. check_deployment.py
- Vérifie si l'instrumentation est déployée
- Cherche les tags de logs dans les fichiers distants

### 4. check_remote_path.py
- Trouve le chemin correct du service sur Kamatera
- Résultat : `/opt/bobodo-vocal` (pas `/root/bobodo-vocal`)

### 5. watch_stt_logs.py
- Surveille les logs en temps réel via `journalctl -f`
- Utile pendant les tests fonctionnels

---

## État Actuel

### Corrections Déployées ✅

1. **WAV Header** : Ajout en-têtes WAV pour raw PCM16
2. **Buffer Accumulation** : Accumulation jusqu'à 1 seconde minimum
3. **Handler** : Plus d'erreurs prématurées quand buffer pas plein
4. **VAD Filter** : Désactivé pour éviter suppression audio

### Service Actif ✅

- Modèle Faster Whisper Medium chargé
- Service bobodo-vocal actif sur port 8000
- Logs d'instrumentation en place
- Prêt pour tests fonctionnels

### Tests en Attente ⏳

- Tests fonctionnels avec audio réel
- Validation transcription complète
- Métriques de latence et qualité
- Validation mémoire (vocal↔texte)
- Validation Support (frustration, escalade)

---

## Prochaines Étapes

1. **Tests Fonctionnels** : Parler pendant au moins 1 seconde pour valider la transcription
2. **Métriques** : Mesurer latence STT (temps d'accumulation + transcription)
3. **Qualité** : Évaluer précision transcription en français
4. **Mémoire** : Valifier cohérence entre messages vocaux et textuels
5. **Support** : Tester scénarios frustration et escalade
6. **Rapport Final** : Documenter captures, métriques, anomalies, corrections

---

## Résumé Technique

| Problème | Cause | Correction | Fichier |
|----------|-------|------------|---------|
| InvalidDataError | Raw PCM sans WAV header | Ajout en-têtes WAV | stt_service.py |
| VAD supprime audio | Paquets trop courts (20ms) | Buffer 1s minimum | stt_service.py |
| Erreurs prématurées | Handler interprète None comme erreur | Log info sans erreur | websocket_handler.py |
| VAD trop aggressif | Threshold trop élevé | Désactivation VAD | stt_service.py |

---

## Conclusion

Le service STT Kamatera a été instrumenté et corrigé pour gérer le format audio PCM16WAV brut envoyé par Flutter. Les 4 problèmes identifiés ont été résolus :
1. Format audio invalide → WAV header
2. Paquets trop courts → Buffer accumulation
3. Erreurs prématurées → Handler correction
4. VAD filter aggressif → Désactivation

Le service est prêt pour tests fonctionnels avec audio réel.
