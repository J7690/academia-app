import 'package:flutter/foundation.dart';

import '../services/td_service.dart';

class AdminTdStudentRequestsProvider extends ChangeNotifier {
  AdminTdStudentRequestsProvider() : _service = TdService();

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

  Future<void> loadRequests({
    String? status,
    String? fieldId,
    String? level,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      _requests = await _service.adminListStudentRequests(
        status: status,
        fieldId: fieldId,
        level: level,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> markRequestConverted({
    required String requestId,
    required String programId,
  }) async {
    if (requestId.isEmpty || programId.isEmpty) {
      _setError('Demande ou programme TD invalide.');
      return false;
    }

    _setLoading(true);
    _setError(null);
    try {
      await _service.adminMarkRequestConverted(
        requestId: requestId,
        programId: programId,
      );
      await loadRequests();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
