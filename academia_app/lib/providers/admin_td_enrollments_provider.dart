import 'package:flutter/foundation.dart';

import '../services/td_service.dart';

class AdminTdEnrollmentsProvider extends ChangeNotifier {
  AdminTdEnrollmentsProvider() : _service = TdService();

  final TdService _service;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _enrollments = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get enrollments =>
      List.unmodifiable(_enrollments);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadEnrollments() async {
    _setLoading(true);
    _setError(null);
    try {
      _enrollments = await _service.adminListEnrollmentsWithContext();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AdminTdEnrollmentsProvider] loadEnrollments error=$e stack=$st');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> assignTeacher({
    required String enrollmentId,
    required String tdTeacherId,
  }) async {
    if (enrollmentId.isEmpty || tdTeacherId.isEmpty) {
      _setError("Inscription ou enseignant TD invalide.");
      return false;
    }

    _setLoading(true);
    _setError(null);
    try {
      final ok = await _service.adminAssignTeacher(
        enrollmentId: enrollmentId,
        tdTeacherId: tdTeacherId,
      );
      if (ok) {
        await loadEnrollments();
      }
      return ok;
    } catch (e, st) {
      debugPrint('[AdminTdEnrollmentsProvider] assignTeacher error=$e stack=$st');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
