import 'package:flutter/foundation.dart';

import '../services/td_service.dart';

class StudentTdCatalogProvider extends ChangeNotifier {
  StudentTdCatalogProvider() : _service = TdService();

  final TdService _service;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _programs = [];
  Map<String, dynamic>? _programDetail;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get programs => List.unmodifiable(_programs);
  Map<String, dynamic>? get programDetail =>
      _programDetail == null ? null : Map<String, dynamic>.unmodifiable(_programDetail!);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadPrograms({String? fieldId, String? level}) async {
    _setLoading(true);
    _setError(null);
    try {
      _programs = await _service.listPublicPrograms(
        fieldId: fieldId,
        level: level,
      );
      notifyListeners();
    } catch (e, st) {
      debugPrint('[StudentTdCatalogProvider] loadPrograms error=$e stack=$st');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadProgramDetail(String programId) async {
    if (programId.isEmpty) return;
    _setLoading(true);
    _setError(null);
    try {
      final data = await _service.getProgramDetail(programId);
      _programDetail = data;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[StudentTdCatalogProvider] loadProgramDetail error=$e stack=$st');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
