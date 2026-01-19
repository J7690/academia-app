import 'package:flutter/foundation.dart';

import '../services/td_service.dart';

class StudentTdEnrollmentsProvider extends ChangeNotifier {
  StudentTdEnrollmentsProvider() : _service = TdService();

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

  Future<void> loadMyEnrollments() async {
    _setLoading(true);
    _setError(null);
    try {
      _enrollments = await _service.studentListMyEnrollments();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[StudentTdEnrollmentsProvider] loadMyEnrollments error=$e stack=$st');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createEnrollmentAndPayment({
    required String programId,
    String? collectionId,
    required String accessScope,
    required double amountDue,
    String? studentNotes,
  }) async {
    if (programId.isEmpty) {
      _setError('Programme TD invalide.');
      return false;
    }

    _setLoading(true);
    _setError(null);
    try {
      await _service.studentCreateEnrollmentAndPayment(
        programId: programId,
        collectionId: collectionId,
        accessScope: accessScope,
        amountDue: amountDue,
        studentNotes: studentNotes,
      );
      await loadMyEnrollments();
      return true;
    } catch (e, st) {
      debugPrint('[StudentTdEnrollmentsProvider] createEnrollmentAndPayment error=$e stack=$st');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
