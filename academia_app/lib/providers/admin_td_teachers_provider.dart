import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour la gestion des enseignants TD côté admin.
class AdminTdTeachersProvider extends ChangeNotifier {
  AdminTdTeachersProvider() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _teachers = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get teachers => List.unmodifiable(_teachers);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadTeachers() async {
    _setLoading(true);
    _setError(null);
    try {
      final raw = await _client
          .schema('app')
          .from('td_teachers')
          .select()
          .order('full_name');
      final list = raw as List<dynamic>? ?? [];
      _teachers = list.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[AdminTdTeachersProvider] loadTeachers error=$e stack=$st');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createTeacher({
    required String userId,
    required String fullName,
    String? discipline,
    String? zone,
    String? availability,
  }) async {
    if (userId.isEmpty || fullName.trim().isEmpty) {
      _setError('Utilisateur ou nom enseignant invalide.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      await _client.schema('app').from('td_teachers').insert({
            'user_id': userId,
            'full_name': fullName.trim(),
            'discipline': discipline?.trim(),
            'zone': zone?.trim(),
            'availability': availability?.trim(),
          });
      await loadTeachers();
      return true;
    } catch (e, st) {
      debugPrint('[AdminTdTeachersProvider] createTeacher error=$e stack=$st');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateTeacherStatus({
    required String teacherId,
    required String status,
  }) async {
    if (teacherId.isEmpty || status.trim().isEmpty) {
      _setError('Enseignant ou statut invalide.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      await _client
          .schema('app')
          .from('td_teachers')
          .update({'status': status.trim()}).eq('id', teacherId);
      await loadTeachers();
      return true;
    } catch (e, st) {
      debugPrint('[AdminTdTeachersProvider] updateTeacherStatus error=$e stack=$st');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
