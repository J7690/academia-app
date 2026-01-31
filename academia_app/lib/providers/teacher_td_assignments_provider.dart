import 'package:flutter/foundation.dart';

import '../services/td_service.dart';

class TeacherTdAssignmentsProvider extends ChangeNotifier {
  TeacherTdAssignmentsProvider() : _service = TdService();

  final TdService _service;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _nextSessions = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get assignments =>
      List.unmodifiable(_assignments);
  List<Map<String, dynamic>> get nextSessions =>
      List.unmodifiable(_nextSessions);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadAssignments() async {
    _setLoading(true);
    _setError(null);
    try {
      final dashboard = await _service.teacherGetDashboard();

      final rawAssignments = dashboard['assignments'] as List<dynamic>? ?? [];
      _assignments = rawAssignments
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      final rawNextSessions =
          dashboard['next_sessions'] as List<dynamic>? ?? [];
      _nextSessions = rawNextSessions
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
      notifyListeners();
    } catch (e, st) {
      debugPrint('[TeacherTdAssignmentsProvider] loadAssignments error=$e stack=$st');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
