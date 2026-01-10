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

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get users => List.unmodifiable(_users);
  bool get isUpdating => _isUpdating;

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
}
