# BOBODO_FLUTTER_WS_URL

## Mission 5 — Constantes URL vocales dans le code Flutter


### voice_provider.dart
**Chemin:** `c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\services\voice_provider.dart`
```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

/// VoiceProvider abstrait pour multilingue
abstract class VoiceProvider {
  /// Langue de la voix
  String get language;
  
  /// Nom de la voix
  String get voiceName;
  
  /// Génère l'audio à partir du texte
  Future<Uint8List> generateAudio(String text);
  
  /// Configure la vitesse de parole (0.5 - 2.0)
  void setSpeakingRate(double rate);
  
  /// Configure la hauteur (0.5 - 2.0)
  void setPitch(double pitch);
  
  /// Libère les ressources
  void dispose();
}

/// PiperVoiceProvider pour Piper TTS via serveur vocal
class PiperVoiceProvider extends VoiceProvider {
  @override
  String get language => 'fr_FR';
  
  @override
  String get voiceName => 'siwis-medium';
  
  double _speakingRate = 1.0;
  double _pitch = 1.0;
  WebSocketChannel? _channel;
  
  @override
  void setSpeakingRate(double rate) {
    _speakingRate = rate.clamp(0.5, 2.0);
  }
  
  @override
  void setPitch(double pitch) {
    _pitch = pitch.clamp(0.5, 2.0);
  }
  
  @override
  Future<Uint8List> generateAudio(String text) async {
    try {
      // Connexion WebSocket au serveur vocal
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://185.167.97.144:8000/ws'),
      );
      
      // Attendre la connexion
      await _channel!.ready;
      
      // Envoyer le texte pour génération TTS
      _channel!.sink.add(jsonEncode({
        'type': 'text',
        'text': text,
      }));
      
      // Attendre la réponse audio
      final response = await _channel!.stream.first;
      final data = jsonDecode(response as String) as Map<String, dynamic>;
      
      if (data['type'] == 'audio_response') {
        final audioBase64 = data['audio'] as String;
        return base64Decode(audioBase64);
      }
      
      return Uint8List(0);
    } catch (e) {
      print('[PiperVoiceProvider] Erreur génération audio: $e');
      return Uint8List(0);
    }
  }
  
  @override
  void dispose() {
    _channel?.sink.close();
    _channel = null;
  }
}

/// MooréVoiceProvider pour Mooré (future)
class MooreVoiceProvider extends VoiceProvider {
  @override
  String get language => 'mos_BF';
  
  @override
  String get voiceName => 'moore-medium';
  
  @override
  void setSpeakingRate(double rate) {
    // À implémenter
  }
  
  @override
  void setPitch(double pitch) {
    // À implémenter
  }
  
  @override
  Future<Uint8List> generateAudio(String text) async {
    // À implémenter
    return Uint8List(0);
  }
  
  @override
  void dispose() {
    // À implémenter
  }
}

/// DioulaVoiceProvider pour Dioula (future)
class DioulaVoiceProvider extends VoiceProvider {
  @override
  String get language => 'dyu_BF';
  
  @override
  String get voiceName => 'dioula-medium';
  
  @override
  void setSpeakingRate(double rate) {
    // À implémenter
  }
  
  @override
  void setPitch(double pitch) {
    // À implémenter
  }
  
  @override
  Future<Uint8List> generateAudio(String text) async {
    // À implémenter
    return Uint8List(0);
  }
  
  @override
  void dispose() {
    // À implémenter
  }
}

/// FulfuldeVoiceProvider pour Fulfuldé (future)
class FulfuldeVoiceProvider extends VoiceProvider {
  @override
  String get language => 'fuv_BF';
  
  @override
  String get voiceName => 'fulfulde-medium';
  
  @override
  void setSpeakingRate(double rate) {
    // À implémenter
  }
  
  @override
  void setPitch(double pitch) {
    // À implémenter
  }
  
  @override
  Future<Uint8List> generateAudio(String text) async {
    // À implémenter
    return Uint8List(0);
  }
  
  @override
  void dispose() {
    // À implémenter
  }
}

/// VoiceManager pour gérer les providers
class VoiceManager {
  static final VoiceManager _instance = VoiceManager._internal();
  factory VoiceManager() => _instance;
  VoiceManager._internal();
  
  VoiceProvider? _currentProvider;
  
  /// Définit le provider actuel
  void setProvider(VoiceProvider provider) {
    _currentProvider?.dispose();
    _currentProvider = provider;
  }
  
  /// Retourne le provider actuel
  VoiceProvider? get currentProvider => _currentProvider;
  
  /// Configure la langue
  void setLanguage(String language) {
    switch (language) {
      case 'fr_FR':
        setProvider(PiperVoiceProvider());
        break;
      case 'mos_BF':
        setProvider(MooreVoiceProvider());
        break;
      case 'dyu_BF':
        setProvider(DioulaVoiceProvider());
        break;
      case 'fuv_BF':
        setProvider(FulfuldeVoiceProvider());
        break;
      default:
        setProvider(PiperVoiceProvider());
    }
  }
  
  void dispose() {
    _currentProvider?.dispose();
  }
}

```

### bobodo_vocal_service.dart
**Chemin:** `c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\services\bobodo_vocal_service.dart`
```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Service WebSocket pour Bobodo Vocal
/// Gère la connexion WebSocket et les messages audio
class BobodoVocalService {
  WebSocketChannel? _channel;
  final String _url;
  String? _sessionId;
  final _messageController = StreamController<Map<String, dynamic>>();
  final _errorController = StreamController<String>();
  bool _isConnected = false;

  BobodoVocalService(this._url);

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<String> get errorStream => _errorController.stream;
  bool get isConnected => _isConnected;

  /// Connecter au WebSocket
  Future<void> connect(String sessionId) async {
    _sessionId = sessionId;
    debugPrint('[VOICE_WS_SERVICE] Tentative connexion WebSocket: $_url?session_id=$sessionId');
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse('$_url?session_id=$sessionId'));
      _isConnected = true;
      debugPrint('[VOICE_WS_SERVICE] WebSocket connecté');
      
      // Écouter les messages
      _channel!.stream.listen(
        (message) {
          debugPrint('[VOICE_WS_SERVICE] Message brut reçu: $message');
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          debugPrint('[VOICE_WS_SERVICE] Message décodé: $data');
          _messageController.add(data);
        },
        onError: (error) {
          debugPrint('[VOICE_WS_SERVICE_ERROR] Erreur stream: $error');
          _errorController.add(error.toString());
          _isConnected = false;
        },
        onDone: () {
          debugPrint('[VOICE_WS_SERVICE_CLOSED] WebSocket fermé');
          _isConnected = false;
        },
      );
    } catch (e) {
      debugPrint('[VOICE_WS_SERVICE_ERROR] Erreur connexion: $e');
      _errorController.add(e.toString());
      _isConnected = false;
    }
  }

  /// Envoyer des données audio
  void sendAudio(Uint8List audioBytes) {
    if (!_isConnected || _channel == null) {
      debugPrint('[VOICE_WS_SERVICE_ERROR] Non connecté au WebSocket, envoi audio ignoré');
      _errorController.add('Non connecté au WebSocket');
      return;
    }

    debugPrint('[VOICE_WS_SERVICE] Envoi audio: ${audioBytes.length} bytes');
    final base64Audio = base64Encode(audioBytes);
    final message = jsonEncode({
      'type': 'audio',
      'session_id': _sessionId,
      'audio': base64Audio,
    });

    _channel!.sink.add(message);
    debugPrint('[VOICE_WS_SERVICE] Audio envoyé');
  }

  /// Déconnecter
  void disconnect() {
    debugPrint('[VOICE_WS_SERVICE] Déconnexion WebSocket');
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  /// Disposer les ressources
  void dispose() {
    debugPrint('[VOICE_WS_SERVICE] Disposition ressources');
    disconnect();
    _messageController.close();
    _errorController.close();
  }
}

```

### Recherche globale de '8000', 'ws://', 'websocket' dans lib/services/

**Dans:** `c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\services`

#### academia_livekit_service.dart
  Ligne 25: `/// - `url` : URL WebSocket du serveur`

#### bobodo_vocal_service.dart
  Ligne 8: `/// Service WebSocket pour Bobodo Vocal`
  Ligne 9: `/// Gère la connexion WebSocket et les messages audio`
  Ligne 11: `WebSocketChannel? _channel;`
  Ligne 24: `/// Connecter au WebSocket`
  Ligne 27: `debugPrint('[VOICE_WS_SERVICE] Tentative connexion WebSocket: $_url?session_id=$sessionId');`
  Ligne 30: `_channel = WebSocketChannel.connect(Uri.parse('$_url?session_id=$sessionId'));`
  Ligne 32: `debugPrint('[VOICE_WS_SERVICE] WebSocket connecté');`
  Ligne 48: `debugPrint('[VOICE_WS_SERVICE_CLOSED] WebSocket fermé');`
  Ligne 62: `debugPrint('[VOICE_WS_SERVICE_ERROR] Non connecté au WebSocket, envoi audio ignoré');`
  Ligne 63: `_errorController.add('Non connecté au WebSocket');`
  Ligne 81: `debugPrint('[VOICE_WS_SERVICE] Déconnexion WebSocket');`

#### livekit_token_service.dart
  Ligne 12: `/// - `url` : l'URL WebSocket du serveur LiveKit (wss://...)`

#### studio_video_service.dart
  Ligne 109: `// Locally, Docker exposes the backend on port 8000.`
  Ligne 113: `defaultValue: 'http://10.0.2.2:8000',`

#### voice_provider.dart
  Ligne 36: `WebSocketChannel? _channel;`
  Ligne 51: `// Connexion WebSocket au serveur vocal`
  Ligne 52: `_channel = WebSocketChannel.connect(`
  Ligne 53: `Uri.parse('ws://185.167.97.144:8000/ws'),`

**Dans:** `c:\Users\fasop\AndroidStudioProjects\academia\academia_app\lib\features\student\tabs`

#### student_bobodo_tab.dart
  Ligne 86: `// WebSocket vocal`
  Ligne 88: `'ws://185.167.97.144:8000/ws',`
  Ligne 124: `_connectVocalWebSocket();`
  Ligne 1231: `Future<void> _connectVocalWebSocket() async {`