import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Service WebSocket pour Bobodo Vocal
/// Gère la connexion WebSocket, les messages audio et la reconnexion automatique
class BobodoVocalService {
  WebSocketChannel? _channel;
  final String _url;
  String? _sessionId;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  bool _isConnected = false;
  bool _disposed = false;
  bool _intentionalDisconnect = false;

  // Reconnexion automatique
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const int _initialRetryDelayMs = 2000;
  static const int _maxRetryDelayMs = 30000;
  Timer? _reconnectTimer;

  BobodoVocalService(this._url);

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<String> get errorStream => _errorController.stream;
  bool get isConnected => _isConnected;

  /// Connecter au WebSocket
  Future<void> connect(String sessionId) async {
    _sessionId = sessionId;
    _intentionalDisconnect = false;
    _reconnectAttempts = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_disposed || _sessionId == null) return;

    debugPrint('[VOICE_WS_SERVICE] Tentative connexion WebSocket: $_url?session_id=$_sessionId');

    try {
      _channel = WebSocketChannel.connect(Uri.parse('$_url?session_id=$_sessionId'));
      _isConnected = true;
      _reconnectAttempts = 0;
      debugPrint('[VOICE_WS_SERVICE] WebSocket connecté');

      // Envoyer le session_id selon le protocole Bobodo
      final sessionMessage = jsonEncode({
        'type': 'session_id',
        'session_id': _sessionId,
      });
      _channel!.sink.add(sessionMessage);
      debugPrint('[VOICE_WS_SERVICE] Message session_id envoyé: $_sessionId');

      // Écouter les messages
      _channel!.stream.listen(
        (message) {
          debugPrint('[VOICE_WS_SERVICE] Message brut reçu: $message');
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          debugPrint('[VOICE_WS_SERVICE] Message décodé: $data');
          if (!_messageController.isClosed) {
            _messageController.add(data);
          }
        },
        onError: (error) {
          debugPrint('[VOICE_WS_SERVICE_ERROR] Erreur stream: $error');
          if (!_errorController.isClosed) {
            _errorController.add(error.toString());
          }
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[VOICE_WS_SERVICE_CLOSED] WebSocket fermé');
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('[VOICE_WS_SERVICE_ERROR] Erreur connexion: $e');
      if (!_errorController.isClosed) {
        _errorController.add(e.toString());
      }
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  /// Planifier une reconnexion avec exponential backoff
  void _scheduleReconnect() {
    if (_intentionalDisconnect || _disposed) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[VOICE_WS_SERVICE] Max reconnexion atteint ($_maxReconnectAttempts), abandon');
      if (!_errorController.isClosed) {
        _errorController.add('Reconnexion impossible après $_maxReconnectAttempts tentatives');
      }
      return;
    }

    _reconnectAttempts++;
    final delay = min(
      _initialRetryDelayMs * pow(2, _reconnectAttempts - 1).toInt(),
      _maxRetryDelayMs,
    );
    debugPrint('[VOICE_WS_SERVICE] Reconnexion #$_reconnectAttempts dans ${delay}ms');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      if (!_disposed && !_intentionalDisconnect && !_isConnected) {
        _doConnect();
      }
    });
  }

  /// Envoyer des données audio
  void sendAudio(Uint8List audioBytes) {
    if (!_isConnected || _channel == null) {
      debugPrint('[VOICE_WS_SERVICE_ERROR] Non connecté au WebSocket, envoi audio ignoré');
      if (!_errorController.isClosed) {
        _errorController.add('Non connecté au WebSocket');
      }
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

  /// Déconnecter intentionnellement (pas de reconnexion)
  void disconnect() {
    debugPrint('[VOICE_WS_SERVICE] Déconnexion WebSocket intentionnelle');
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  /// Disposer les ressources
  void dispose() {
    debugPrint('[VOICE_WS_SERVICE] Disposition ressources');
    _disposed = true;
    _reconnectTimer?.cancel();
    disconnect();
    _messageController.close();
    _errorController.close();
  }
}
