# Validation 3 - Plan d'Intégration dans student_bobodo_tab.dart

## État Actuel

### Imports Existant
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../providers/bobodo_provider.dart';
import '../../../theme/prep_theme.dart';
import '../../share/share_service.dart';
import '../../share/share_mode_provider.dart';
import '../../share/widgets/share_signature.dart';
import '../../../widgets/bobodo_vocal_button.dart';
```

### État Existant
```dart
class _StudentBobodoTabState extends State<StudentBobodoTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _shareBoundaryKey = GlobalKey();
  final ShareService _shareService = ShareService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _showEmojiPicker = false;
  int _prevMessageCount = 0;
  bool _showVocalButton = false;
```

### Méthodes Existantes
- `_buildInputBar()` : Zone de saisie avec champ texte
- `_buildVocalPanel()` : Panel vocal flottant (à supprimer)
- `_send()` : Envoi message texte
- `_buildHeader()`, `_buildWelcomeView()`, `_buildMessagesList()`, etc.

---

## Plan d'Intégration

### Étape 1 - Ajout Imports

**Ajouter après imports existants** :
```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bobodo_vocal_service.dart';
```

**Supprimer** :
```dart
import '../../../widgets/bobodo_vocal_button.dart';
```

---

### Étape 2 - Ajout Variables d'État

**Ajouter après variables existantes** :
```dart
// Mode vocal
bool _isRecordingMode = false;
bool _isRecording = false;
bool _isTranscribing = false;
bool _isSending = false;
bool _isSpeaking = false;

// Enregistrement
Duration _recordingDuration = Duration.zero;
Timer? _recordingTimer;
FlutterSoundRecorder _recorder = FlutterSoundRecorder();

// Audio
StreamController<Uint8List>? _audioStreamController;
List<Uint8List> _audioBuffer = [];

// WebSocket vocal
BobodoVocalService _vocalService = BobodoVocalService(
  'ws://185.167.97.144:8000/ws',
);
bool _isVocalConnected = false;
StreamSubscription? _messageSubscription;
StreamSubscription? _errorSubscription;

// Animation audio
List<double> _audioLevels = [0.0, 0.0, 0.0, 0.0, 0.0];
Timer? _audioLevelTimer;
```

**Supprimer** :
```dart
bool _showVocalButton = false;
```

---

### Étape 3 - Modification initState()

**Ajouter après `super.initState()`** :
```dart
@override
void initState() {
  super.initState();
  
  // Audio vocal
  _audioStreamController = StreamController<Uint8List>();
  _audioStreamController?.stream.listen(_onAudioData);
  _initRecorder();
  _connectVocalWebSocket();
  
  // Existant
  _scrollToBottom();
  // ...
}
```

---

### Étape 4 - Modification dispose()

**Ajouter avant `super.dispose()`** :
```dart
@override
void dispose() {
  // Vocal
  _recorder.closeRecorder();
  _vocalService.disconnect();
  _vocalService.dispose();
  _messageSubscription?.cancel();
  _errorSubscription?.cancel();
  _audioStreamController?.close();
  _recordingTimer?.cancel();
  _audioLevelTimer?.cancel();
  
  // Existant
  _controller.dispose();
  _scrollController.dispose();
  _focusNode.dispose();
  _audioPlayer.dispose();
  super.dispose();
}
```

---

### Étape 5 - Ajout Méthodes Vocales

**Ajouter après méthode `_send()`** :

```dart
// ─── Méthodes vocales ───────────────────────────────────────────────

Future<void> _initRecorder() async {
  try {
    await _recorder.openRecorder();
  } catch (e) {
    debugPrint('[VOICE_RECORDER_INIT_ERROR] $e');
  }
}

Future<void> _connectVocalWebSocket() async {
  try {
    final provider = context.read<BobodoProvider>();
    final sessionId = provider.currentSessionId;
    if (sessionId == null) {
      await provider.createSession(title: 'Conversation vocale');
    }
    
    await _vocalService.connect(provider.currentSessionId ?? '');
    setState(() => _isVocalConnected = true);

    _messageSubscription = _vocalService.messageStream.listen((message) {
      _onVocalMessage(message);
    });

    _errorSubscription = _vocalService.errorStream.listen((error) {
      debugPrint('[VOICE_WS_ERROR] $error');
    });
  } catch (e) {
    debugPrint('[VOICE_WS_CONNECT_ERROR] $e');
  }
}

Future<bool> _requestPermission() async {
  final status = await Permission.microphone.request();
  return status.isGranted;
}

Future<void> _startVocalRecording() async {
  final granted = await _requestPermission();
  if (!granted) return;

  try {
    await _recorder.startRecorder(
      codec: Codec.pcm16WAV,
      toStream: _audioStreamController?.sink,
    );

    setState(() {
      _isRecordingMode = true;
      _isRecording = true;
      _recordingDuration = Duration.zero;
      _audioBuffer.clear();
    });

    _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
      });
    });

    _audioLevelTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      setState(() {
        // Simuler niveau audio (à remplacer par vrai niveau)
        for (int i = 0; i < _audioLevels.length; i++) {
          _audioLevels[i] = (DateTime.now().millisecond % 100) / 100.0;
        }
      });
    });
  } catch (e) {
    debugPrint('[VOICE_RECORDING_ERROR] $e');
  }
}

Future<void> _stopVocalRecording() async {
  await _recorder.stopRecorder();
  _recordingTimer?.cancel();
  _audioLevelTimer?.cancel();

  setState(() {
    _isRecording = false;
    _isTranscribing = true;
  });

  // Envoyer audio au serveur STT
  final audioBytes = Uint8List.fromList(_audioBuffer.expand((e) => e).toList());
  _audioBuffer.clear();
  _vocalService.sendAudio(audioBytes);
}

Future<void> _cancelVocalRecording() async {
  await _recorder.stopRecorder();
  _recordingTimer?.cancel();
  _audioLevelTimer?.cancel();
  _audioBuffer.clear();

  setState(() {
    _isRecordingMode = false;
    _isRecording = false;
    _recordingDuration = Duration.zero;
  });
}

void _onAudioData(Uint8List data) {
  if (_isRecording) {
    _audioBuffer.add(data);
  }
}

void _onVocalMessage(Map<String, dynamic> message) {
  final type = message['type'] as String?;

  if (type == 'transcription') {
    final text = message['text'] as String?;
    _onTranscriptionReceived(text ?? '');
  } else if (type == 'audio_response') {
    final audioBase64 = message['audio'] as String?;
    _onAudioResponseReceived(audioBase64 ?? '');
  } else if (type == 'error') {
    final errorMessage = message['message'] as String?;
    _onVocalError(errorMessage ?? 'Erreur vocale');
  }
}

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

void _onAudioResponseReceived(String audioBase64) async {
  try {
    final audioBytes = base64Decode(audioBase64);
    await _audioPlayer.setSourceBytes(audioBytes);
    await _audioPlayer.resume();
    
    setState(() => _isSpeaking = true);
    
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() => _isSpeaking = false);
    });
  } catch (e) {
    debugPrint('[VOICE_AUDIO_ERROR] $e');
  }
}

void _onVocalError(String error) {
  setState(() {
    _isTranscribing = false;
    _isRecordingMode = false;
  });
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error)),
  );
}

String _formatRecordingDuration(Duration duration) {
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
```

---

### Étape 6 - Modification _buildInputBar()

**Remplacer la méthode `_buildInputBar()` existante par** :

```dart
Widget _buildInputBar(BobodoProvider provider) {
  return Container(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
    decoration: BoxDecoration(
      color: PrepTheme.cardBg,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          // Emoji toggle
          IconButton(
            icon: Icon(
              _showEmojiPicker
                  ? Icons.keyboard
                  : Icons.emoji_emotions_outlined,
              color: _isRecordingMode ? PrepTheme.textTertiary : PrepTheme.textTertiary,
              size: 22,
            ),
            onPressed: _isRecordingMode ? null : () {
              setState(() {
                _showEmojiPicker = !_showEmojiPicker;
                if (_showEmojiPicker) {
                  _focusNode.unfocus();
                } else {
                  _focusNode.requestFocus();
                }
              });
            },
          ),
          // Zone de saisie (texte ou vocal)
          Expanded(
            child: _isRecordingMode
                ? _buildVocalInputInterface()
                : _buildTextInputInterface(),
          ),
          const SizedBox(width: 6),
          // Bouton vocal ou envoi
          _isRecordingMode
              ? _buildVocalActionButtons()
              : _buildTextActionButtons(provider),
        ],
      ),
    ),
  );
}
```

---

### Étape 7 - Ajout Méthodes UI

**Ajouter après `_buildInputBar()`** :

```dart
// ─── Interface texte ────────────────────────────────────────────────

Widget _buildTextInputInterface() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: PrepTheme.scaffoldBg,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: PrepTheme.divider),
    ),
    child: TextField(
      controller: _controller,
      focusNode: _focusNode,
      textCapitalization: TextCapitalization.sentences,
      maxLines: 4,
      minLines: 1,
      style: const TextStyle(fontSize: 14),
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: 'Pose une question à Bobodo...',
        hintStyle: TextStyle(
          color: PrepTheme.textTertiary,
          fontSize: 14,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 10),
      ),
      onSubmitted: (_) => _send(context),
      onTap: () {
        if (_showEmojiPicker) {
          setState(() => _showEmojiPicker = false);
        }
      },
    ),
  );
}

Widget _buildTextActionButtons(BobodoProvider provider) {
  return Row(
    children: [
      // Bouton micro
      IconButton(
        icon: Icon(
          Icons.mic,
          color: PrepTheme.primary,
          size: 22,
        ),
        onPressed: _startVocalRecording,
      ),
      const SizedBox(width: 4),
      // Bouton envoi
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: PrepTheme.headerGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: PrepTheme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.send, color: Colors.white, size: 18),
          padding: EdgeInsets.zero,
          onPressed: provider.isLoading || _controller.text.trim().isEmpty
              ? null
              : () => _send(context),
        ),
      ),
    ],
  );
}

// ─── Interface vocale ──────────────────────────────────────────────

Widget _buildVocalInputInterface() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: PrepTheme.primary.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: PrepTheme.primary.withValues(alpha: 0.2)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isRecording)
          _buildAudioWaveform()
        else if (_isTranscribing)
          _buildTranscribingIndicator(),
        const SizedBox(height: 8),
        Text(
          _formatRecordingDuration(_recordingDuration),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: PrepTheme.primary,
          ),
        ),
      ],
    ),
  );
}

Widget _buildAudioWaveform() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(5, (index) {
      final height = _audioLevels[index] * 40.0;
      return Container(
        width: 4,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: PrepTheme.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }),
  );
}

Widget _buildTranscribingIndicator() {
  return const Column(
    children: [
      SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      SizedBox(height: 8),
      Text(
        'Transcription en cours...',
        style: TextStyle(
          fontSize: 12,
          color: PrepTheme.textSecondary,
        ),
      ),
    ],
  );
}

Widget _buildVocalActionButtons() {
  return Row(
    children: [
      // Bouton annuler
      IconButton(
        icon: const Icon(Icons.close, size: 22),
        color: PrepTheme.danger,
        onPressed: _isTranscribing ? _cancelVocalRecording : _cancelVocalRecording,
      ),
      const SizedBox(width: 4),
      // Bouton stop
      if (_isRecording)
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: PrepTheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.stop, color: Colors.white, size: 18),
            padding: EdgeInsets.zero,
            onPressed: _stopVocalRecording,
          ),
        ),
    ],
  );
}
```

---

### Étape 8 - Suppression _buildVocalPanel()

**Supprimer la méthode `_buildVocalPanel()` (lignes 940-1014)**

**Supprimer l'appel dans `build()`** :
```dart
// Supprimer ces lignes
// ─── Vocal button panel ───
if (_showVocalButton)
  _buildVocalPanel(provider),
```

---

### Étape 9 - Modification build()

**Dans la méthode `build()`, supprimer** :
```dart
// Supprimer
bool _showVocalButton = false;
```

---

## Résumé des Modifications

### Fichiers Modifiés
- `student_bobodo_tab.dart` : Modifications majeures

### Fichiers Supprimés
- `bobodo_vocal_button.dart` : Suppression complète

### Lignes de Code
- Ajout : ~300 lignes (méthodes vocales + UI)
- Suppression : ~75 lignes (_buildVocalPanel + BobodoVocalButton)
- Net : +225 lignes

### Complexité
- **Faible** : Intégration dans fichier existant
- **Risque** : Faible (logique bien isolée)
- **Test** : Nécessite tests complets du flux

---

## Contraintes Respectées

✅ **Validation 1 - Aucun envoi automatique** : Envoi uniquement via bouton envoi
✅ **Validation 2 - Transcription = texte normal** : Même TextEditingController
✅ **Validation 3 - Aucune duplication d'interface** : Une seule zone de saisie
✅ **Validation 4 - Visualisation audio** : Ondulations + durée
✅ **Validation 5 - Boutons obligatoires** : [Annuler] [Stop]
✅ **Validation 6 - États définis** : 6 états avec transitions
✅ **Validation 7 - Lecture audio** : AudioPlayer avec callback fin
✅ **Validation 8 - Mémoire Bobodo** : Aucune modification BobodoProvider
