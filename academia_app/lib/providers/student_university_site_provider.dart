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
      debugPrint(
        '[StudentUniversitySiteProvider.loadUniversitySiteBySlug] slug=$slug',
      );
      final dynamic result = await _client.rpc(
        'app_public_university_site',
        params: {'p_slug': slug},
      );
      debugPrint(
        '[StudentUniversitySiteProvider.loadUniversitySiteBySlug] rawResult=$result',
      );

      if (result == null) {
        _site = null;
        _setError('Réponse vide du mini-site université.');
        debugPrint(
          '[StudentUniversitySiteProvider.loadUniversitySiteBySlug] result_null',
        );
        return;
      }

      if (result is! Map<String, dynamic>) {
        _site = null;
        _setError('Format de réponse inattendu pour le mini-site université.');
        debugPrint(
          '[StudentUniversitySiteProvider.loadUniversitySiteBySlug] invalid_format type=${result.runtimeType}',
        );
        return;
      }

      if (result['success'] == true) {
        _site = result;
        final dynamic mediaRaw = result['media'];
        final int mediaCount = mediaRaw is List ? mediaRaw.length : -1;
        final dynamic configRaw = result['config'];
        String? heroPosterMediaId;
        if (configRaw is Map<String, dynamic>) {
          final dynamic heroRaw = configRaw['hero_poster_media_id'];
          heroPosterMediaId = heroRaw?.toString();
        }
        debugPrint(
          '[StudentUniversitySiteProvider.loadUniversitySiteBySlug] success media_count=$mediaCount heroPosterMediaId=$heroPosterMediaId',
        );
        notifyListeners();
      } else {
        final errorMessage = result['error']?.toString() ??
            'Erreur lors du chargement du mini-site université.';
        _site = null;
        _setError(errorMessage);
        debugPrint(
          '[StudentUniversitySiteProvider.loadUniversitySiteBySlug] error=$errorMessage',
        );
      }
    } catch (e) {
      _site = null;
      _setError(e.toString());
      debugPrint(
        '[StudentUniversitySiteProvider.loadUniversitySiteBySlug] exception=$e',
      );
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
