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

  /// Fixe le taux de réduction obtenu auprès de l'établissement.
  ///
  /// CE GESTE OUVRE UN ENCAISSEMENT, et c'est pour cela qu'il est séparé des
  /// « préférences de candidature ». Les préférences décrivent ce que
  /// l'étudiant DEMANDE avant la négociation ; le taux enregistre ce qui a été
  /// OBTENU après. Tant qu'il n'est pas posé, le serveur refuse tout paiement
  /// de courtage sur ce dossier (`taux_de_reduction_non_fixe`).
  ///
  /// Zéro est une valeur valide : « négocié, rien obtenu » est un résultat, et
  /// il doit pouvoir débloquer le paiement.
  Future<bool> setApplicationDiscount({
    required String applicationId,
    required double discountRate,
    String? note,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_set_application_discount',
        params: {
          'p_application_id': applicationId,
          'p_discount_rate': discountRate,
          'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
        },
      );

      if (response is! Map<String, dynamic> || response['success'] != true) {
        final code = response is Map<String, dynamic>
            ? response['error']?.toString()
            : null;
        _setError(messageDuTaux(code));
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

  /// Traduit le code d'erreur du serveur en une phrase qu'on peut lire.
  ///
  /// Le 09/09, plusieurs formulaires affichaient encore le code brut à
  /// l'écran : « unsupported_role » ne dit rien à personne. On nomme donc
  /// chaque cas, y compris celui que voit l'étudiant.
  static String messageDuTaux(String? code) {
    switch (code) {
      case 'not_admin':
        return 'Seul un administrateur peut fixer le taux de réduction.';
      case 'taux_invalide':
        return 'Le taux doit être un nombre compris entre 0 et 100.';
      case 'application_not_found':
        return 'Cette candidature est introuvable.';
      case 'not_authenticated':
        return 'Session expirée. Reconnecte-toi et réessaie.';
      case 'taux_de_reduction_non_fixe':
        return 'La réduction négociée n\'a pas encore été enregistrée par '
            'Academia. Le paiement s\'ouvrira dès qu\'elle le sera.';
      default:
        return code == null || code.isEmpty
            ? 'Le taux n\'a pas pu être enregistré.'
            : 'Le taux n\'a pas pu être enregistré ($code).';
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
