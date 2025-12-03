import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnlineCourseForumProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoadingThreads = false;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  String? _error;
  List<Map<String, dynamic>> _threads = [];
  List<Map<String, dynamic>> _messages = [];

  bool get isLoadingThreads => _isLoadingThreads;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isSending => _isSending;
  String? get error => _error;
  List<Map<String, dynamic>> get threads => List.unmodifiable(_threads);
  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);

  void _setLoadingThreads(bool value) {
    _isLoadingThreads = value;
    notifyListeners();
  }

  void _setLoadingMessages(bool value) {
    _isLoadingMessages = value;
    notifyListeners();
  }

  void _setSending(bool value) {
    _isSending = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadThreads(String courseId) async {
    _setLoadingThreads(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_student_list_online_course_forum_threads',
        params: {'p_course_id': courseId},
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour le forum du cours.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des sujets du forum.',
        );
        return;
      }
      final data = response['threads'];
      if (data is List) {
        _threads = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _threads = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoadingThreads(false);
    }
  }

  Future<bool> createThread({
    required String courseId,
    required String title,
    required String content,
  }) async {
    if (title.trim().isEmpty || content.trim().isEmpty) {
      _setError('Le titre et le message sont obligatoires.');
      return false;
    }

    _setSending(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_student_create_online_course_forum_thread',
        params: {
          'p_course_id': courseId,
          'p_title': title.trim(),
          'p_content': content.trim(),
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la création du sujet.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la création du sujet de forum.',
        );
        return false;
      }
      await loadThreads(courseId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSending(false);
    }
  }

  Future<void> loadMessages(String threadId) async {
    _setLoadingMessages(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_student_list_online_course_forum_messages',
        params: {'p_thread_id': threadId},
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les messages du forum.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des messages du forum.',
        );
        return;
      }
      final data = response['messages'];
      if (data is List) {
        _messages = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _messages = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoadingMessages(false);
    }
  }

  Future<bool> sendMessage({
    required String threadId,
    required String content,
  }) async {
    if (content.trim().isEmpty) {
      _setError('Le message est vide.');
      return false;
    }

    _setSending(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_student_add_online_course_forum_message',
        params: {
          'p_thread_id': threadId,
          'p_content': content.trim(),
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de l\'envoi du message.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de l\'envoi du message.',
        );
        return false;
      }
      await loadMessages(threadId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSending(false);
    }
  }
}
