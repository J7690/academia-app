import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider admin pour la gestion des annonces officielles globales.
/// Utilise les RPC :
/// - app_admin_list_official_announcements
/// - app_admin_upsert_official_announcement
/// - app_admin_delete_official_announcement
class AdminAcademicAnnouncementsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _announcements = <Map<String, dynamic>>[];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get announcements =>
      List<Map<String, dynamic>>.unmodifiable(_announcements);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadAnnouncements() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_list_official_announcements',
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        _announcements = <Map<String, dynamic>>[];
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors du chargement des annonces officielles.",
        );
        _announcements = <Map<String, dynamic>>[];
        return;
      }
      final data = response['announcements'];
      if (data is List) {
        _announcements = data
            .whereType<Map>()
            .map(
              (dynamic e) =>
                  Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
            )
            .toList(growable: false);
      } else {
        _announcements = <Map<String, dynamic>>[];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _announcements = <Map<String, dynamic>>[];
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertAnnouncement({
    String? announcementId,
    required String title,
    required String body,
    String? summary,
    String urgencyLevel = 'info',
    String? category,
    List<String>? targetRoles,
    List<String>? targetCountries,
    List<String>? targetStudyLevels,
    List<String>? targetUniversityIds,
    bool? isPublished,
    DateTime? visibleFrom,
    DateTime? visibleUntil,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final Map<String, dynamic> params = <String, dynamic>{
        'p_announcement_id': announcementId,
        'p_title': title,
        'p_body': body,
        'p_summary': summary,
        'p_urgency_level': urgencyLevel,
        'p_category': category,
        'p_target_roles': targetRoles,
        'p_target_countries': targetCountries,
        'p_target_study_levels': targetStudyLevels,
        'p_target_university_ids': targetUniversityIds,
        'p_is_published': isPublished,
        'p_visible_from': visibleFrom?.toIso8601String(),
        'p_visible_until': visibleUntil?.toIso8601String(),
      };

      final dynamic response = await _client.rpc(
        'app_admin_upsert_official_announcement',
        params: params,
      );

      if (response is! Map<String, dynamic>) {
        _setError(
          '\nRéponse invalide du serveur lors de la sauvegarde de l\'annonce.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de la sauvegarde de l'annonce.",
        );
        return false;
      }
      await loadAnnouncements();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteAnnouncement(String announcementId) async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_admin_delete_official_announcement',
        params: <String, dynamic>{
          'p_announcement_id': announcementId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la suppression de l\'annonce.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              "Erreur lors de la suppression de l'annonce.",
        );
        return false;
      }
      await loadAnnouncements();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
