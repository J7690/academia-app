import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Provider Bobodo
/// Gère la session courante et les messages côté Flutter
/// L'appel à l'IA OpenRouter doit se faire via un backend sécurisé (non géré ici).
class BobodoProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _sessionPrefKey = 'bobodo_current_session_id_v1';

  bool _isLoading = false;
  String? _error;
  String? _currentSessionId;
  final List<Map<String, dynamic>> _messages = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentSessionId => _currentSessionId;
  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);

  final Map<String, String> _feedbackByMessageId = {};

  Map<String, String> get feedbackByMessageId =>
      Map.unmodifiable(_feedbackByMessageId);

  String? feedbackForMessage(String messageId) =>
      _feedbackByMessageId[messageId];

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> createSession({String? title}) async {
    _setLoading(true);
    _setError(null);
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      final result = await _client
          .rpc('app_get_or_create_bobodo_session', params: {
        'p_title': title,
      });
      debugPrint('Bobodo createSession rpc result: $result');
      final sessionId = result?.toString();
      _currentSessionId = sessionId;
      _messages.clear();
      notifyListeners();

      // Persister la session Bobodo pour la réutiliser lors des prochains
      // lancements de l'application.
      if (sessionId != null && sessionId.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_sessionPrefKey, sessionId);
        } catch (_) {
          // On ignore les erreurs de persistance pour ne pas bloquer l'UX.
        }
      }
    } catch (e) {
      debugPrint('Bobodo createSession error: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMessages() async {
    final sessionId = _currentSessionId;
    if (sessionId == null) return;
    _setLoading(true);
    _setError(null);
    try {
      final data = await _client.rpc(
        'app_list_bobodo_messages',
        params: {'p_session_id': sessionId},
      ) as List<dynamic>? ?? [];
      _messages
        ..clear()
        ..addAll(data.cast<Map<String, dynamic>>());
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Envoi d'un message texte de l'étudiant.
  /// La génération de la réponse IA est gérée par le backend FastAPI Bobodo
  /// (Python), qui utilise Supabase + OpenRouter + éventuelle recherche web.
  Future<void> sendUserMessage(String content) async {
    if (content.trim().isEmpty) return;
    _setError(null);

    // 1) S'assurer qu'une session existe
    var sessionId = _currentSessionId;
    if (sessionId == null) {
      // Tenter d'abord de recharger une session existante depuis les préférences
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getString(_sessionPrefKey);
        if (stored != null && stored.trim().isNotEmpty) {
          sessionId = stored.trim();
          _currentSessionId = sessionId;
          // Optionnel : recharger l'historique si besoin.
          await loadMessages();
        }
      } catch (_) {
        // Si lecture des préférences échoue, on continue en créant une session.
      }

      if (sessionId == null) {
        await createSession(
          title: content.substring(0, content.length > 60 ? 60 : content.length),
        );
        sessionId = _currentSessionId;
      }
    } else {
      // On a déjà un session_id en mémoire, mais on vérifie si elle est toujours valide
      // en essayant de charger les messages. Si erreur, on tente d'en créer une nouvelle.
      try {
        await loadMessages();
      } catch (_) {
        await createSession(
          title: content.substring(0, content.length > 60 ? 60 : content.length),
        );
        sessionId = _currentSessionId;
      }
    }
    if (sessionId == null) {
      _setError('Impossible de créer la session Bobodo.');
      return;
    }

    // 2) Ajouter immédiatement le message de l'étudiant en local pour l'affichage
    _messages.add({
      'id': null,
      'sender': 'student',
      'content': content,
      'safety_flag': null,
      'created_at': DateTime.now().toIso8601String(),
    });
    notifyListeners();

    // 3) Appeler la future Edge Function Supabase `bobodo-chat` qui se charge de :
    //    - enregistrer le message étudiant via RPC,
    //    - interroger la base de connaissances Supabase + IA,
    //    - enregistrer la réponse IA via RPC.
    _setLoading(true);
    var backendOk = true;
    try {
      final session = _client.auth.currentSession;
      if (session == null || session.accessToken.isEmpty) {
        throw Exception('Utilisateur non authentifié pour Bobodo.');
      }

      final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/bobodo-chat');
      final body = jsonEncode({
        'session_id': sessionId,
        'message': content,
      });

      final finalResponse = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'apikey': SupabaseConfig.anonKey,
        },
        body: body,
      );

      if (finalResponse.statusCode >= 400) {
        backendOk = false;
        String message = 'Erreur backend Bobodo (${finalResponse.statusCode}).';
        try {
          final decoded = jsonDecode(finalResponse.body);
          if (decoded is Map<String, dynamic>) {
            final detail = decoded['error'] ?? decoded['message'] ?? decoded['detail'];
            if (detail is String && detail.trim().isNotEmpty) {
              message = detail;
            }
          }
        } catch (_) {}
        _setError(message);
      }
    } catch (e) {
      backendOk = false;
      _setError('Erreur lors de l\'appel Bobodo (Edge Function): $e');
    } finally {
      _setLoading(false);
    }

    // 4) Recharger les messages depuis Supabase (session + réponse IA) uniquement
    // si le backend a répondu correctement. Sinon on garde le message local.
    if (backendOk) {
      await loadMessages();
    }
  }

  /// Envoi d'un feedback sur une réponse Bobodo ("up" ou "down").
  /// Utilise la RPC app_add_bobodo_feedback côté Supabase.
  Future<void> sendFeedback({
    required String messageId,
    required String rating,
    String? comment,
  }) async {
    final sessionId = _currentSessionId;
    if (sessionId == null) return;
    if (rating != 'up' && rating != 'down') return;

    try {
      await _client.rpc(
        'app_add_bobodo_feedback',
        params: {
          'p_session_id': sessionId,
          'p_message_id': messageId,
          'p_rating': rating,
          if (comment != null) 'p_comment': comment,
        },
      );
    } catch (_) {
      // On ignore les erreurs de feedback pour ne pas bloquer l'UX.
    } finally {
      _feedbackByMessageId[messageId] = rating;
      notifyListeners();
    }
  }
}
