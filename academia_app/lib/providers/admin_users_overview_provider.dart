import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour la vue d'ensemble des comptes utilisateurs admin.
/// Utilise la RPC app_admin_list_users_overview (JSONB) définie dans .windsurf/sql_changes.
class AdminUsersOverviewProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  bool _isUpdating = false;
  List<Map<String, dynamic>>? _commercialsOverview;
  List<Map<String, dynamic>> _deletedUsers = [];
  List<Map<String, dynamic>> _milestoneClaims = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get users => List.unmodifiable(_users);
  bool get isUpdating => _isUpdating;
  List<Map<String, dynamic>>? get commercialsOverview =>
      _commercialsOverview == null ? null : List.unmodifiable(_commercialsOverview!);
  List<Map<String, dynamic>> get deletedUsers => List.unmodifiable(_deletedUsers);
  List<Map<String, dynamic>> get milestoneClaims => List.unmodifiable(_milestoneClaims);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setUpdating(bool value) {
    _isUpdating = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadUsers() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_admin_list_users_overview');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les comptes utilisateurs.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des comptes utilisateurs.',
        );
        return;
      }
      final data = response['users'];
      if (data is List) {
        _users = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _users = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateUserStatus({
    required String userId,
    required bool suspend,
    String? reason,
  }) async {
    _setUpdating(true);
    _setError(null);
    try {
      final action = suspend ? 'suspend' : 'reactivate';
      final response = await _client.rpc(
        'app_admin_update_user_status',
        params: {
          'p_target_user_id': userId,
          'p_action': action,
          'p_reason': reason,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour l\'action admin.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de l\'action administrateur sur le compte.',
        );
        return false;
      }
      await loadUsers();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  Future<bool> hardDeleteUserAccount({
    required String userId,
    String? reason,
  }) async {
    _setUpdating(true);
    _setError(null);
    try {
      final response = await _client.functions.invoke(
        'admin-hard-delete-user-account',
        body: <String, dynamic>{
          'target_user_id': userId,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour la suppression définitive du compte.');
        return false;
      }
      if (data['success'] != true) {
        _setError(
          data['error']?.toString() ??
              'Erreur lors de la suppression définitive du compte utilisateur.',
        );
        return false;
      }

      await loadUsers();
      await loadDeletedUsers();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  Future<bool> promoteUserRole({
    required String userId,
    required String targetRole,
    String? universityName,
  }) async {
    _setUpdating(true);
    _setError(null);
    try {
      final response = await _client.functions.invoke(
        'admin-promote-user-role',
        body: <String, dynamic>{
          'target_user_id': userId,
          'target_role': targetRole,
          if (universityName != null && universityName.trim().isNotEmpty)
            'university_name': universityName.trim(),
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur pour la promotion du compte.',
        );
        return false;
      }
      if (data['success'] != true) {
        _setError(
          data['error']?.toString() ??
              'Erreur lors de la promotion du compte utilisateur.',
        );
        return false;
      }
      await loadUsers();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  /// Promeut un compte existant en conseiller d'orientation.
  ///
  /// Fonction dédiée plutôt qu'un `targetRole` de plus dans [promoteUserRole] :
  /// la promotion ne se limite pas à changer un rôle, elle crée aussi le profil
  /// métier dans `app.orientation_counselors`. Sans lui, le conseiller
  /// n'apparaîtrait dans aucune recherche d'élève.
  Future<bool> promoteToOrientationCounselor({
    required String userId,
    String? fullName,
    String kind = 'orientation',
    List<String> specialites = const [],
    List<String> langues = const ['fr'],
    int dureeMinutes = 45,
    int tarifFcfa = 0,
  }) async {
    _setUpdating(true);
    _setError(null);
    try {
      final response = await _client.functions.invoke(
        'admin-promote-to-orientation-counselor',
        body: <String, dynamic>{
          'user_id': userId,
          if (fullName != null && fullName.trim().isNotEmpty)
            'full_name': fullName.trim(),
          'kind': kind,
          'specialites': specialites,
          'langues': langues,
          'duree_minutes': dureeMinutes,
          'tarif_fcfa': tarifFcfa,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        await loadUsers();
        return true;
      }
      _setError(_promotionErrorMessage(
          data is Map ? data['error']?.toString() : null));
      return false;
    } on FunctionException catch (e) {
      // functions.invoke lève sur tout statut hors 2xx : le corps de la réponse
      // se trouve alors dans e.details, pas dans response.data. Sans ce cas,
      // une erreur métier prévisible remonterait en exception technique brute.
      final details = e.details;
      _setError(_promotionErrorMessage(
          details is Map ? details['error']?.toString() : null));
      return false;
    } catch (e) {
      _setError('Promotion impossible. Vérifiez votre connexion et réessayez.');
      debugPrint('[AdminUsersOverview] promoteToOrientationCounselor: $e');
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  String _promotionErrorMessage(String? code) => switch (code) {
        'cannot_demote_admin' =>
          'Un compte administrateur ne peut pas être converti en conseiller.',
        'user_not_found' => 'Ce compte est introuvable.',
        'not_admin' => 'Cette action est réservée aux administrateurs.',
        'not_authenticated' =>
          'Votre session a expiré. Reconnectez-vous et réessayez.',
        'profile_creation_failed' =>
          'Le profil de conseiller n\'a pas pu être créé. Le compte n\'a pas été modifié.',
        'role_update_failed' =>
          'Le rôle n\'a pas pu être changé. La promotion a été annulée.',
        _ => 'Promotion impossible. Réessayez dans un instant.',
      };

  Future<List<Map<String, dynamic>>> fetchUserActionLogs(String userId) async {
    try {
      final response = await _client.rpc(
        'app_admin_list_user_action_logs',
        params: {
          'p_target_user_id': userId,
        },
      );
      if (response is! Map<String, dynamic>) {
        throw Exception('Réponse invalide du serveur pour l\'historique des actions.');
      }
      if (response['success'] != true) {
        final message = response['error']?.toString() ??
            'Erreur lors du chargement de l\'historique des actions.';
        throw Exception(message);
      }
      final data = response['logs'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
      return const [];
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteUserAccount({
    required String userId,
    String? reason,
  }) async {
    _setUpdating(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_delete_user_account',
        params: {
          'p_target_user_id': userId,
          'p_reason': reason,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour la suppression du compte.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la suppression du compte utilisateur.',
        );
        return false;
      }
      await loadUsers();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  Future<void> refresh() => loadUsers();

  Future<void> loadCommercialsOverview() async {
    try {
      final response = await _client.rpc('app_admin_list_commercials_overview');
      if (response is! Map<String, dynamic>) {
        return;
      }
      if (response['success'] != true) {
        return;
      }
      final data = response['commercials'];
      if (data is List) {
        _commercialsOverview = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
        notifyListeners();
      }
    } catch (_) {
      // On ignore les erreurs ici : l'écran admin reste fonctionnel sans ce résumé.
    }
  }

  Future<void> loadDeletedUsers({int limit = 200, int offset = 0}) async {
    try {
      final response = await _client.rpc(
        'app_admin_list_deleted_users',
        params: {
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      if (response is! Map<String, dynamic>) {
        return;
      }
      if (response['success'] != true) {
        return;
      }
      final data = response['deleted_users'];
      if (data is List) {
        _deletedUsers = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
        notifyListeners();
      }
    } catch (_) {
      // On ignore les erreurs ici : l'écran admin reste fonctionnel sans l'archive.
    }
  }

  Future<Map<String, dynamic>?> fetchCommercialDetail(
    String commercialUserId,
  ) async {
    try {
      final response = await _client.rpc(
        'app_admin_get_commercial_detail',
        params: {
          'p_commercial_user_id': commercialUserId,
        },
      );
      if (response is! Map<String, dynamic>) {
        throw Exception(
          'Réponse invalide du serveur pour le détail commercial.',
        );
      }
      if (response['success'] != true) {
        final message = response['error']?.toString() ??
            'Erreur lors du chargement du détail commercial.';
        throw Exception(message);
      }
      final data = response['data'];
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> updateReferralCommissionStatus({
    required String commissionId,
    required String newStatus,
    String? adminNote,
  }) async {
    _setUpdating(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_update_referral_commission_status',
        params: {
          'p_commission_id': commissionId,
          'p_new_status': newStatus,
          'p_admin_note': adminNote,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur pour la mise à jour de la commission.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la mise à jour de la commission.',
        );
        return false;
      }
      await loadCommercialsOverview();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  Future<void> loadMilestoneClaims({String status = 'pending'}) async {
    try {
      final response = await _client.rpc(
        'app_admin_list_milestone_claims',
        params: {'p_status': status},
      );
      if (response is! Map<String, dynamic>) return;
      if (response['success'] != true) return;
      final data = response['claims'];
      if (data is List) {
        _milestoneClaims = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> updateMilestoneClaimStatus({
    required String claimId,
    required String newStatus,
  }) async {
    _setUpdating(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_update_milestone_claim_status',
        params: {
          'p_claim_id': claimId,
          'p_new_status': newStatus,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('R\u00e9ponse invalide du serveur.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur lors de la mise \u00e0 jour.');
        return false;
      }
      await loadMilestoneClaims();
      await loadCommercialsOverview();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  Future<bool> updateCommercialCap({
    required String userId,
    required int maxCap,
  }) async {
    _setUpdating(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_update_commercial_cap',
        params: {
          'p_user_id': userId,
          'p_max_cap': maxCap,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('R\u00e9ponse invalide du serveur.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur lors de la mise \u00e0 jour du cap.');
        return false;
      }
      await loadCommercialsOverview();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  Future<bool> updateCommercialCommissionRate({
    required String userId,
    required double rate,
  }) async {
    _setUpdating(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_set_commercial_commission_rate',
        params: {
          'p_user_id': userId,
          'p_rate': rate,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur pour la mise à jour du taux de commission.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la mise à jour du taux de commission.',
        );
        return false;
      }
      await loadCommercialsOverview();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  /// Vérifie si une conversation support existe pour un email
  Future<String?> checkSupportConversationExists(String email) async {
    try {
      final response = await _client.rpc(
        'app_admin_check_support_conversation',
        params: {'p_user_email': email},
      );
      if (response is! Map<String, dynamic>) {
        return null;
      }
      if (response['success'] != true) {
        return null;
      }
      return response['conversation_id']?.toString();
    } catch (e) {
      debugPrint('[AdminUsersOverview] checkSupportConversationExists error: $e');
      return null;
    }
  }

  /// Crée une nouvelle conversation support avec un utilisateur
  Future<String?> createSupportConversation({
    required String email,
    String? initialMessage,
  }) async {
    try {
      final params = <String, dynamic>{'p_user_email': email};
      if (initialMessage != null && initialMessage.trim().isNotEmpty) {
        params['p_initial_message'] = initialMessage.trim();
      }
      
      final response = await _client.rpc(
        'app_admin_create_support_conversation',
        params: params,
      );
      if (response is! Map<String, dynamic>) {
        return null;
      }
      if (response['success'] != true) {
        return null;
      }
      return response['conversation_id']?.toString();
    } catch (e) {
      debugPrint('[AdminUsersOverview] createSupportConversation error: $e');
      return null;
    }
  }
}
