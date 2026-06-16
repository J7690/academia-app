# Validation 2 - Schéma des États

## Définition des États

### 1. IDLE
**Description** : État par défaut, aucune action en cours

**Conditions** :
- Aucun enregistrement en cours
- Aucune transcription en cours
- Aucun envoi en cours
- Aucune lecture audio en cours

**UI** :
- Champ texte actif
- Bouton micro actif
- Bouton envoi actif (si texte non vide)
- Bouton emoji actif

**Transitions** :
- IDLE → RECORDING : Tap bouton micro
- IDLE → SENDING : Tap bouton envoi (texte non vide)

**Variables** :
- `_isRecordingMode = false`
- `_isRecording = false`
- `_isTranscribing = false`
- `_isSending = false`
- `_isSpeaking = false`

---

### 2. RECORDING
**Description** : Enregistrement audio en cours

**Conditions** :
- Microphone actif
- Audio capté et accumulé
- Timer durée actif
- Animation ondulations active

**UI** :
- Champ texte remplacé par interface vocale
- Animation ondulations audio
- Durée d'enregistrement affichée
- Bouton annuler actif
- Bouton stop actif
- Bouton emoji désactivé
- Bouton envoi désactivé

**Transitions** :
- RECORDING → IDLE : Tap bouton annuler
- RECORDING → TRANSCRIBING : Tap bouton stop

**Variables** :
- `_isRecordingMode = true`
- `_isRecording = true`
- `_isTranscribing = false`
- `_isSending = false`
- `_isSpeaking = false`
- `_recordingDuration` : incrémenté chaque seconde

**Actions** :
- Accumuler audio dans buffer local
- Mettre à jour timer
- Animer ondulations basées sur niveau audio

---

### 3. TRANSCRIBING
**Description** : Transcription STT en cours

**Conditions** :
- Enregistrement arrêté
- Audio envoyé au serveur STT
- En attente réponse transcription

**UI** :
- Champ texte remplacé par interface vocale
- Texte "Transcription en cours..."
- Spinner circulaire
- Bouton annuler actif
- Bouton envoi désactivé
- Bouton emoji désactivé
- Bouton micro désactivé

**Transitions** :
- TRANSCRIBING → IDLE : Tap bouton annule (annule transcription)
- TRANSCRIBING → EDITING : Transcription reçue avec succès

**Variables** :
- `_isRecordingMode = true`
- `_isRecording = false`
- `_isTranscribing = true`
- `_isSending = false`
- `_isSpeaking = false`

**Actions** :
- Envoyer audio au serveur STT
- Attendre réponse WebSocket
- Annuler si bouton annuler tapé

---

### 4. EDITING
**Description** : Transcription reçue, utilisateur peut éditer

**Conditions** :
- Transcription injectée dans champ texte
- Aucun envoi en cours
- Utilisateur peut modifier le texte

**UI** :
- Champ texte actif avec transcription
- Bouton micro actif
- Bouton envoi actif (si texte non vide)
- Bouton emoji actif
- Identique à état IDLE visuellement

**Transitions** :
- EDITING → IDLE : Suppression complète du texte
- EDITING → SENDING : Tap bouton envoi
- EDITING → RECORDING : Tap bouton micro (nouvel enregistrement)

**Variables** :
- `_isRecordingMode = false`
- `_isRecording = false`
- `_isTranscribing = false`
- `_isSending = false`
- `_isSpeaking = false`

**Actions** :
- Injecter transcription dans `_controller.text`
- Permettre édition normale du champ texte

---

### 5. SENDING
**Description** : Message envoyé à Bobodo, en attente réponse

**Conditions** :
- Message envoyé via `sendUserMessage()`
- Edge Function appelée
- En attente réponse Bobodo

**UI** :
- Champ texte désactivé (lecture seule)
- Bouton micro désactivé
- Bouton envoi remplacé par spinner
- Bouton emoji désactivé

**Transitions** :
- SENDING → IDLE : Erreur d'envoi
- SENDING → SPEAKING : Réponse reçue avec succès

**Variables** :
- `_isRecordingMode = false`
- `_isRecording = false`
- `_isTranscribing = false`
- `_isSending = true`
- `_isSpeaking = false`

**Actions** :
- Appeler `provider.sendUserMessage(text)`
- Attendre réponse via `BobodoProvider`

---

### 6. SPEAKING
**Description** : Réponse Bobodo lue vocalement

**Conditions** :
- Réponse reçue
- Audio TTS généré
- Lecture audio en cours

**UI** :
- Champ texte actif
- Bouton micro actif
- Bouton envoi remplacé par icône haut-parleur animé
- Bouton emoji actif

**Transitions** :
- SPEAKING → IDLE : Fin de lecture audio
- SPEAKING → IDLE : Tap bouton haut-parleur (pause)

**Variables** :
- `_isRecordingMode = false`
- `_isRecording = false`
- `_isTranscribing = false`
- `_isSending = false`
- `_isSpeaking = true`

**Actions** :
- Jouer audio TTS via AudioPlayer
- Animer icône haut-parleur
- Détecter fin de lecture

---

## Diagramme des Transitions

```
┌─────────┐
│  IDLE   │◄─────────────────────────────────────────────────┐
└────┬────┘                                                  │
     │                                                       │
     │ Tap micro                                            │
     ▼                                                       │
┌─────────┐      Tap annuler      ┌─────────┐                │
│RECORDING│─────────────────────►│  IDLE   │                │
└────┬────┘                      └─────────┘                │
     │                                                       │
     │ Tap stop                                              │
     ▼                                                       │
┌─────────┐      Tap annuler      ┌─────────┐                │
│TRANSCRIB│─────────────────────►│  IDLE   │                │
└────┬────┘                      └─────────┘                │
     │                                                       │
     │ Transcription reçue                                  │
     ▼                                                       │
┌─────────┐      Suppression text    ┌─────────┐                │
│ EDITING │────────────────────────►│  IDLE   │                │
└────┬────┘                      └─────────┘                │
     │                                                       │
     │ Tap envoi                                            │
     ▼                                                       │
┌─────────┐      Erreur envoi       ┌─────────┐                │
│ SENDING │────────────────────────►│  IDLE   │                │
└────┬────┘                      └─────────┘                │
     │                                                       │
     │ Réponse reçue                                        │
     ▼                                                       │
┌─────────┐      Fin lecture        ┌─────────┐                │
│SPEAKING │────────────────────────►│  IDLE   │                │
└─────────┘                      └─────────┘                │
```

---

## Variables d'État

```dart
// Mode vocal
bool _isRecordingMode = false;  // true si interface vocale affichée

// Enregistrement
bool _isRecording = false;     // true si enregistrement en cours
Duration _recordingDuration = Duration.zero;
Timer? _recordingTimer;

// Transcription
bool _isTranscribing = false;   // true si transcription en cours

// Envoi
bool _isSending = false;        // true si envoi en cours

// Lecture audio
bool _isSpeaking = false;       // true si lecture audio en cours

// Audio
FlutterSoundRecorder _recorder;
StreamController<Uint8List>? _audioStreamController;
List<Uint8List> _audioBuffer = [];  // Buffer local pour audio

// WebSocket
BobodoVocalService _vocalService;
bool _isVocalConnected = false;
StreamSubscription? _messageSubscription;
StreamSubscription? _errorSubscription;
```

---

## Méthodes de Transition

### IDLE → RECORDING
```dart
void _startVocalRecording() async {
  final granted = await _requestPermission();
  if (!granted) return;

  await _recorder.startRecorder(
    codec: Codec.pcm16WAV,
    toStream: _audioStreamController?.sink,
  );

  setState(() {
    _isRecordingMode = true;
    _isRecording = true;
    _recordingDuration = Duration.zero;
  });

  _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
    setState(() {
      _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
    });
  });
}
```

### RECORDING → IDLE (Annuler)
```dart
void _cancelVocalRecording() async {
  await _recorder.stopRecorder();
  _recordingTimer?.cancel();
  _audioBuffer.clear();

  setState(() {
    _isRecordingMode = false;
    _isRecording = false;
    _recordingDuration = Duration.zero;
  });
}
```

### RECORDING → TRANSCRIBING (Stop)
```dart
void _stopVocalRecording() async {
  await _recorder.stopRecorder();
  _recordingTimer?.cancel();

  setState(() {
    _isRecording = false;
    _isTranscribing = true;
  });

  // Envoyer audio au serveur STT
  final audioBytes = Uint8List.fromList(_audioBuffer.expand((e) => e).toList());
  _audioBuffer.clear();
  _vocalService.sendAudio(audioBytes);
}
```

### TRANSCRIBING → EDITING
```dart
void _onTranscriptionReceived(String text) {
  setState(() {
    _isTranscribing = false;
    _isRecordingMode = false;
  });

  _controller.text = text;
  _controller.selection = TextSelection.fromPosition(
    TextPosition(offset: text.length),
  );
}
```

### EDITING → SENDING
```dart
Future<void> _send(BuildContext context) async {
  final text = _controller.text.trim();
  if (text.isEmpty) return;

  _controller.clear();
  setState(() => _isSending = true);

  final provider = context.read<BobodoProvider>();
  await provider.sendUserMessage(text);

  setState(() => _isSending = false);
}
```

### SENDING → SPEAKING
```dart
void _onBobodoResponseReceived(String response) {
  // TTS et lecture audio
  _synthesizeAndPlay(response);
  setState(() => _isSpeaking = true);
}
```

### SPEAKING → IDLE
```dart
void _onAudioPlaybackComplete() {
  setState(() => _isSpeaking = false);
}
```

---

## Contraintes Respectées

✅ **Validation 6 - États définis** : 6 états explicites documentés
✅ **Validation 6 - Transitions documentées** : Diagramme complet
✅ **Validation 6 - Aucun état bloqué** : Toutes les transitions vers IDLE
✅ **Validation 6 - Variables d'état** : Liste complète avec types
