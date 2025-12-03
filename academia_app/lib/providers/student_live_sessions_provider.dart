import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentLiveSessionsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get sessions => List.unmodifiable(_sessions);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadMySessions() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_student_list_my_online_course_live_sessions');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour mes sessions live de cours en ligne.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement de mes sessions live.',
        );
        return;
      }
      final data = response['sessions'];
      if (data is List) {
        _sessions = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _sessions = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
