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
