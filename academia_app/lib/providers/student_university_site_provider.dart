import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour le mini-site université côté étudiant
/// Consomme exclusivement la RPC app_public_university_site
class StudentUniversitySiteProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _site;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get site => _site;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadUniversitySiteBySlug(String slug) async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic result = await _client.rpc(
        'app_public_university_site',
        params: {'p_slug': slug},
      );

      if (result == null) {
        _site = null;
        _setError('Réponse vide du mini-site université.');
        return;
      }

      if (result is! Map<String, dynamic>) {
        _site = null;
        _setError('Format de réponse inattendu pour le mini-site université.');
        return;
      }

      if (result['success'] == true) {
        _site = result;
        notifyListeners();
      } else {
        final errorMessage = result['error']?.toString() ??
            'Erreur lors du chargement du mini-site université.';
        _site = null;
        _setError(errorMessage);
      }
    } catch (e) {
      _site = null;
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  void clear() {
    _site = null;
    _error = null;
    notifyListeners();
  }
}
