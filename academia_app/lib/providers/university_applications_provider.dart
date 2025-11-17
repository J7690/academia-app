import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les candidatures côté université partenaire.
/// Utilise la RPC app_list_university_applications.
class UniversityApplicationsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _applications = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get applications => List.unmodifiable(_applications);
  int get unreadTotal =>
      _applications.where((app) => app['has_unread_for_university'] == true).length;

  int get unreadReceived => _applications
      .where((app) =>
          (app['status']?.toString() == 'submitted') &&
          app['has_unread_for_university'] == true)
      .length;

  int get unreadTreated {
    const treatedStatuses = ['under_review', 'accepted', 'rejected', 'canceled'];
    return _applications
        .where((app) =>
            treatedStatuses.contains(app['status']?.toString()) &&
            app['has_unread_for_university'] == true)
        .length;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadApplications() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_list_university_applications');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      final success = response['success'] == true;
      if (!success) {
        _setError(response['error']?.toString() ?? 'Erreur lors du chargement des candidatures.');
        return;
      }
      final apps = response['applications'];
      if (apps is List) {
        _applications = apps
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
      } else {
        _applications = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
