import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les annonces officielles globales côté étudiant.
/// Consomme les RPC :
/// - app_get_official_announcements_summary
/// - app_list_official_announcements_for_current_user
/// - app_mark_official_announcement_read
class StudentAnnouncementsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isUpdatingRead = false;
  String? _error;
  List<Map<String, dynamic>> _announcements = <Map<String, dynamic>>[];
  int _unreadCount = 0;

  bool get isLoading => _isLoading;
  bool get isUpdatingRead => _isUpdatingRead;
  String? get error => _error;
  List<Map<String, dynamic>> get announcements =>
      List<Map<String, dynamic>>.unmodifiable(_announcements);
  int get unreadCount => _unreadCount;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setUpdatingRead(bool value) {
    _isUpdatingRead = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadAnnouncements({int limit = 50}) async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_list_official_announcements_for_current_user',
        params: <String, dynamic>{
          'p_limit': limit,
        },
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        final List<dynamic> rawList =
            (response['announcements'] as List<dynamic>? ?? <dynamic>[]);
        _announcements = rawList
            .whereType<Map>()
            .map((dynamic e) => Map<String, dynamic>.from(
                  e as Map<dynamic, dynamic>,
                ))
            .toList(growable: false);
      } else {
        _announcements = <Map<String, dynamic>>[];
        if (response is Map<String, dynamic>) {
          _setError(
            response['error']?.toString() ??
                'Erreur lors du chargement des annonces officielles.',
          );
        }
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      final dynamic response =
          await _client.rpc('app_get_official_announcements_summary');
      if (response is Map<String, dynamic> && response['success'] == true) {
        _unreadCount = response['unread_count'] as int? ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[StudentAnnouncementsProvider] refreshUnreadCount error: $e');
    }
  }

  Future<bool> markAnnouncementRead(
    String announcementId, {
    bool? isPinned,
  }) async {
    _setUpdatingRead(true);
    _setError(null);
    try {
      final Map<String, dynamic> params = <String, dynamic>{
        'p_announcement_id': announcementId,
      };
      if (isPinned != null) {
        params['p_is_pinned'] = isPinned;
      }

      final dynamic response = await _client.rpc(
        'app_mark_official_announcement_read',
        params: params,
      );

      if (response is! Map<String, dynamic> || response['success'] != true) {
        if (response is Map<String, dynamic>) {
          _setError(
            response['error']?.toString() ??
                'Erreur lors du marquage de l\'annonce comme lue.',
          );
        } else {
          _setError('Réponse invalide du serveur pour le marquage de lecture.');
        }
        return false;
      }

      // Mise à jour locale de l\'état de l\'annonce
      final int index = _announcements.indexWhere(
        (Map<String, dynamic> a) => a['id'] == announcementId,
      );
      if (index != -1) {
        final Map<String, dynamic> updated =
            Map<String, dynamic>.from(_announcements[index]);
        updated['is_read'] = true;
        if (isPinned != null) {
          updated['is_pinned'] = isPinned;
        }
        _announcements[index] = updated;
        notifyListeners();
      }

      // Rafraîchit le compteur non-lues en arrière-plan.
      await refreshUnreadCount();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setUpdatingRead(false);
    }
  }
}
