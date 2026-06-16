# Audit Conversation Vocale Temps Réel - 11 Juin 2026

## Comportement Observé

**Problème** : Une seule phrase utilisateur est découpée en plusieurs interactions Bobodo.

**Exemple** :
- Utilisateur : "Bonjour Bobodo, est-ce que tu m'entends correctement ?"
- Résultat : "Bonjour" → réponse, puis "Bobodo" → réponse, puis "Est-ce que" → réponse, etc.

---

## MISSION 1 – AUDIT DU BUFFER AUDIO

### Taille du Buffer

**Code** : `stt_service.py` ligne 29
```python
self.audio_buffer = bytearray()  # Buffer to accumulate audio chunks
```

**Valeur** : Dynamique - s'accumule jusqu'à atteindre `min_audio_duration`

### Durée Réelle Accumulée

**Code** : `stt_service.py` ligne 109
```python
current_duration = len(self.audio_buffer) / (self.sample_rate * self.bytes_per_sample)
```

**Calcul** :
- `sample_rate = 16000` Hz
- `bytes_per_sample = 2` (16-bit PCM)
- `current_duration = buffer_size / (16000 * 2) = buffer_size / 32000` secondes

**Exemple** :
- 640 bytes → 0.02s
- 32000 bytes → 1.00s
- 64000 bytes → 2.00s

### Condition Exacte Déclenchant la Transcription

**Code** : `stt_service.py` lignes 113-120
```python
if current_duration < self.min_audio_duration:
    logger.info(f"[STT_BUFFER] Not enough audio yet (need {self.min_audio_duration}s, have {current_duration:.2f}s)")
    return None

# We have enough audio, transcribe it
logger.info(f"[STT_BUFFER] Buffer full, starting transcription ({current_duration:.2f}s)")
audio_to_transcribe = bytes(self.audio_buffer)
self.audio_buffer.clear()  # Clear buffer for next batch
```

**Condition** : `current_duration >= 1.0` seconde

**Comportement** :
- Buffer accumule jusqu'à 1 seconde
- Transcription lancée
- Buffer vidé immédiatement
- Nouvelle accumulation commence

### Fréquence d'Appel de STTService.transcribe()

**Code** : `websocket_handler.py` ligne 85
```python
transcription = await self.stt_service.transcribe(audio_bytes)
```

**Fréquence** : À chaque paquet audio reçu via WebSocket

**Observation logs** :
```
[WS_AUDIO_RECEIVED] Audio decoded: 640 bytes
[WS_STT_START] Starting transcription...
[STT_AUDIO_RECEIVED] Audio received: 640 bytes
```

**Estimation** : ~50 paquets/seconde (640 bytes @ 16000Hz = 20ms par paquet)

---

## MISSION 2 – AUDIT DE LA DÉTECTION DE FIN DE PAROLE

### Logique End Of Speech

**Réponse** : **NON**

**Preuve** : Aucun code ne détecte la fin de parole. Le buffer se vide dès qu'il atteint 1 seconde, indépendamment de la parole.

### Logique de Silence

**Réponse** : **NON**

**Preuve** : Aucun code ne détecte le silence. Le VAD filter de Faster Whisper a été désactivé (ligne 170) :
```python
vad_filter=False  # Disabled VAD filter for short audio clips
```

### Timer de Fin de Phrase

**Réponse** : **NON**

**Preuve** : Aucun timer ou timeout n'est implémenté. La transcription est basée uniquement sur la durée accumulée (1s), pas sur un silence détecté.

---

## MISSION 3 – AUDIT DES APPELS BOBODO

### Pour une Phrase Utilisateur de 10 Secondes

**Calcul** :
- Durée totale : 10 secondes
- Seuil transcription : 1 seconde
- Nombre de transcriptions : 10 / 1 = 10

**Résultat** :
- **10 appels Bobodo** générés
- **10 messages WebSocket** envoyés (type "transcription")
- **10 réponses** reçues (type "audio_response")

### Preuve de Code

**Code** : `websocket_handler.py` lignes 92-114
```python
logger.info(f"[WS_STT_SUCCESS] Transcription: {transcription}")

# Send transcription to client
await self.send_transcription(transcription)

# Send transcription to Bobodo
if not self.session_id:
    logger.error("[WS_SESSION_ERROR] No session ID provided")
    await self.send_error("No session ID provided")
    return
    
logger.info("[WS_BOBODO_START] Sending transcription to Bobodo...")
response = await self.bobodo_client.send_message(
    session_id=self.session_id,
    message=transcription
)
```

**Chaque transcription réussie déclenche un appel Bobodo immédiat.**

---

## MISSION 4 – AUDIT DU SPINNER INFINI

### Variable Pilote Cet État

**Variable** : `_isProcessing`

**Code** : `bobodo_vocal_button.dart` ligne 38
```dart
bool _isProcessing = false;
```

### Où Elle Passe à True

**Code** : `bobodo_vocal_button.dart` lignes 157-160
```dart
Future<void> _stopRecording() async {
  debugPrint('[VOICE_STOP_RECORDING_ENTER] Entrée _stopRecording');
  try {
    await _recorder.stopRecorder();
    debugPrint('[VOICE_STOP_RECORDING_SUCCESS] Recorder arrêté avec succès');
    setState(() {
      _isRecording = false;
      _isProcessing = true;  // ← Passe à true ici
    });
```

### Où Elle Devrait Repasser à False

**Attendu** : Après réception de la réponse audio de Bobodo

**Réalité** : **Aucun code ne remet `_isProcessing` à false**

### Pourquoi Cela N'Arrive Pas

**Cause** : Le handler de messages WebSocket ne gère pas la fin du traitement.

**Code** : `bobodo_vocal_button.dart` lignes 84-98
```dart
_messageSubscription = _vocalService.messageStream.listen((message) {
  debugPrint('[VOICE_WS_MESSAGE] Message reçu: $message');
  final type = message['type'] as String?;
  
  if (type == 'transcription') {
    final text = message['text'] as String?;
    setState(() => _transcription = text);
    widget.onTranscription?.call(text ?? '');
  } else if (type == 'audio_response') {
    final audioBase64 = message['audio'] as String?;
    // Décoder et envoyer l'audio
    // Note: Implémentation de décodage base64 à ajouter
    widget.onAudioResponse?.call(Uint8List(0)); // Placeholder
  }
  // ← Aucun setState pour _isProcessing = false
});
```

---

## MISSION 5 – AUDIT DU CYCLE COMPLET

### Tracé du Cycle

1. **Début parole** : `_startRecording()` → `_isRecording = true`
2. **Accumulation** : `_onAudioData()` → `sendAudio()` → buffer serveur
3. **Silence** : Non détecté (pas de logique VAD)
4. **Transcription** : Buffer >= 1s → `transcribe()` → transcription
5. **Bobodo** : `bobodo_client.send_message()` → réponse
6. **TTS** : `tts_service.synthesize()` → audio
7. **Lecture audio** : `onAudioResponse()` → placeholder (non implémenté)
8. **Fin lecture** : Non détectée (pas de callback)
9. **Retour idle** : Jamais atteint (`_isProcessing` reste true)

### Premier État Qui Ne Se Termine Jamais

**État** : `_isProcessing = true`

**Position** : `_stopRecording()` ligne 159

**Cause** : Aucun code ne remet `_isProcessing` à false après réception de la réponse.

---

## MISSION 6 – RECOMMANDATION ARCHITECTURALE

### Option A - Transcription Toutes les 1 Seconde (Actuel)

**Description** : Buffer 1s → transcription → Bobodo → répétition

**Avantages** :
- Latence faible (1s)
- Implémentation simple

**Inconvénients** :
- ❌ Segmentation incorrecte des phrases
- ❌ Plusieurs réponses pour une seule phrase
- ❌ Expérience utilisateur dégradée

**Verdict** : **REJETÉ**

---

### Option B - Transcription Uniquement Après Silence Détecté

**Description** : Accumulation continue → détection silence X ms → transcription → Bobodo

**Avantages** :
- ✅ Segmentation naturelle des phrases
- ✅ Une seule réponse par phrase
- ✅ Expérience utilisateur similaire assistants modernes
- ✅ Compatible avec architecture actuelle

**Inconvénients** :
- Nécessite implémentation VAD (Voice Activity Detection)
- Latence variable (dépend du silence)

**Verdict** : **RECOMMANDÉ**

---

### Option C - Streaming Temps Réel Façon ChatGPT Voice

**Description** : Transcription en temps réel + génération réponse en streaming + lecture audio progressive

**Avantages** :
- ✅ Expérience utilisateur optimale
- ✅ Latence minimale perçue

**Inconvénients** :
- ❌ Complexité très élevée
- ❌ Nécessite refonte architecture complète
- ❌ Nécessite STT streaming + TTS streaming + audio player streaming
- ❌ Hors scope actuel

**Verdict** : **REJETÉ** (trop complexe pour le moment)

---

## RECOMMANDATION FINALE

**Option B** : Transcription uniquement après silence détecté

### Implémentation Requise

1. **VAD côté serveur** :
   - Réactiver VAD filter de Faster Whisper avec paramètres ajustés
   - OU implémenter VAD custom (détection niveau audio + silence)

2. **Logique de fin de parole** :
   - Détecter silence >= 500ms-1000ms
   - Lancer transcription uniquement après silence
   - Buffer continue à accumuler pendant la parole

3. **Correction spinner** :
   - Remettre `_isProcessing = false` après réponse audio
   - Gérer fin de lecture audio

4. **Cycle complet** :
   - Parole → accumulation → silence détecté → transcription → Bobodo → TTS → lecture → idle

---

## RÉSUMÉ DES PROBLÈMES IDENTIFIÉS

| Problème | Cause | Impact |
|----------|-------|--------|
| Segmentation incorrecte | Transcription toutes les 1s | Plusieurs réponses par phrase |
| Pas de détection fin de parole | Aucun VAD/silence/timer | Pas de segmentation naturelle |
| Spinner infini | `_isProcessing` jamais remis à false | UI bloquée en état traitement |
| Pas de lecture audio | `onAudioResponse` placeholder | Réponse audio non jouée |

---

## CONCLUSION

Le problème actuel est un **problème de segmentation conversationnelle et de gestion d'état**, pas un problème de reconnaissance vocale.

L'architecture actuelle transcrit toutes les 1 secondes, ce qui découpe une seule phrase en plusieurs segments. Il n'y a aucune logique de détection de fin de parole ou de silence.

**Correction requise** : Implémenter une détection de silence (VAD) pour déclencher la transcription uniquement à la fin d'une phrase, et corriger la gestion d'état pour éviter le spinner infini.
