import 'package:flutter/foundation.dart';

import '../services/td_service.dart';

class TeacherTdAssignmentsProvider extends ChangeNotifier {
  TeacherTdAssignmentsProvider() : _service = TdService();

  final TdService _service;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _assignments = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get assignments =>
      List.unmodifiable(_assignments);

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
      _assignments = await _service.teacherListAssignments();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[TeacherTdAssignmentsProvider] loadAssignments error=$e stack=$st');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
