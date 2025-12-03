import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les candidatures côté administrateur.
/// Utilise la RPC app_list_admin_applications.
class AdminApplicationsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _applications = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get applications => List.unmodifiable(_applications);
  int get unreadCount => _applications.where((app) {
        final hasUnread = app['has_unread_for_admin'] == true;
        final hasUnseen = app['has_unseen_for_admin'] == true;
        return hasUnread || hasUnseen;
      }).length;

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
      final response = await _client.rpc('app_list_admin_applications');
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

  Future<bool> updateApplicationPreferences({
    required String applicationId,
    String? requestedDegreeLevel,
    String? requestedStudyMode,
    String? requestedSchedule,
    bool? discountRequested,
    String? discountDetails,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      String? _normalize(String? value) {
        if (value == null) return null;
        final trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        return trimmed;
      }

      final response = await _client.rpc(
        'app_admin_update_application_preferences',
        params: {
          'p_application_id': applicationId,
          'p_requested_degree_level': _normalize(requestedDegreeLevel),
          'p_requested_study_mode': _normalize(requestedStudyMode),
          'p_requested_schedule': _normalize(requestedSchedule),
          'p_discount_requested': discountRequested ?? false,
          'p_discount_details': _normalize(discountDetails),
        },
      );

      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors de la mise à jour des préférences de candidature.'
              : 'Erreur lors de la mise à jour des préférences de candidature.',
        );
        return false;
      }

      await loadApplications();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> forwardApplicationToUniversity({
    required String applicationId,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_forward_application',
        params: {
          'p_application_id': applicationId,
        },
      );

      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors de la transmission de la candidature à l\'université.'
              : 'Erreur lors de la transmission de la candidature à l\'université.',
        );
        return false;
      }

      await loadApplications();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markApplicationSeen(String applicationId) async {
    try {
      final response = await _client.rpc(
        'app_admin_mark_application_seen',
        params: {
          'p_application_id': applicationId,
        },
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        final index = _applications
            .indexWhere((app) => app['id']?.toString() == applicationId);
        if (index != -1) {
          _applications[index]['admin_seen_at'] ??=
              DateTime.now().toIso8601String();
          _applications[index]['has_unseen_for_admin'] = false;
          notifyListeners();
        }
      }
    } catch (_) {
      // On ignore les erreurs discrètement : la notification persistera
      // jusqu'au prochain rafraîchissement explicite.
    }
  }
}
