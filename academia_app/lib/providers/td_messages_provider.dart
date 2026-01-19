import 'package:flutter/foundation.dart';

import '../services/td_service.dart';

class TdMessagesProvider extends ChangeNotifier {
  TdMessagesProvider() : _service = TdService();

  final TdService _service;

  bool _isLoading = false;
  String? _error;
  final Map<String, List<Map<String, dynamic>>> _messagesByEnrollment = {};

  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Map<String, dynamic>> messagesFor(String enrollmentId) {
    final list = _messagesByEnrollment[enrollmentId] ?? const [];
    return List.unmodifiable(list);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadMessages(String enrollmentId) async {
    if (enrollmentId.isEmpty) return;
    _setLoading(true);
    _setError(null);
    try {
      final messages = await _service.listMessagesForEnrollment(enrollmentId);
      _messagesByEnrollment[enrollmentId] = messages;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[TdMessagesProvider] loadMessages error=$e stack=$st');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendMessage({
    required String enrollmentId,
    required String threadType,
    required String content,
    String? attachmentUrl,
  }) async {
    if (enrollmentId.isEmpty || content.trim().isEmpty) {
      _setError('Message TD invalide.');
      return false;
    }

    _setLoading(true);
    _setError(null);
    try {
      await _service.sendMessage(
        enrollmentId: enrollmentId,
        threadType: threadType,
        content: content,
        attachmentUrl: attachmentUrl,
      );
      await loadMessages(enrollmentId);
      return true;
    } catch (e, st) {
      debugPrint('[TdMessagesProvider] sendMessage error=$e stack=$st');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
