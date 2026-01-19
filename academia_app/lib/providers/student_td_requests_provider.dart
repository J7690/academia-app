import 'package:flutter/foundation.dart';

import '../services/td_service.dart';

class StudentTdRequestsProvider extends ChangeNotifier {
  StudentTdRequestsProvider() : _service = TdService();

  final TdService _service;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _requests = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get requests => List.unmodifiable(_requests);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadMyRequests() async {
    _setLoading(true);
    _setError(null);
    try {
      _requests = await _service.studentListMyRequests();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createRequest({
    String? fieldId,
    String? level,
    required String subject,
    String? description,
    String? preferredModality,
    String? preferredSchedule,
  }) async {
    if (subject.trim().isEmpty) {
      _setError('Sujet de TD requis.');
      return false;
    }

    _setLoading(true);
    _setError(null);
    try {
      await _service.studentCreateRequest(
        fieldId: fieldId,
        level: level,
        subject: subject.trim(),
        description: description,
        preferredModality: preferredModality,
        preferredSchedule: preferredSchedule,
      );
      await loadMyRequests();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
