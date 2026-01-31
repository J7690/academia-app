import 'package:flutter/foundation.dart';

import '../services/td_service.dart';

class StudentTdEnrollmentsProvider extends ChangeNotifier {
  StudentTdEnrollmentsProvider() : _service = TdService();

  final TdService _service;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _enrollments = [];
  List<Map<String, dynamic>> _nextSessions = [];
  int _unreadMessagesCount = 0;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get enrollments =>
      List.unmodifiable(_enrollments);
  List<Map<String, dynamic>> get nextSessions =>
      List.unmodifiable(_nextSessions);
  int get unreadMessagesCount => _unreadMessagesCount;

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
      final dashboard = await _service.studentGetDashboard();

      final rawEnrollments = dashboard['enrollments'] as List<dynamic>? ?? [];
      _enrollments = rawEnrollments
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      final rawNextSessions =
          dashboard['next_sessions'] as List<dynamic>? ?? [];
      _nextSessions = rawNextSessions
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      _unreadMessagesCount =
          (dashboard['unread_messages_count'] as int?) ?? 0;
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
