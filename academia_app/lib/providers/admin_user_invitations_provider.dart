import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUserInvitationsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<Map<String, dynamic>> _invitations = [];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<Map<String, dynamic>> get invitations => List.unmodifiable(_invitations);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadInvitations() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_admin_list_user_invitations');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les invitations.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des invitations.',
        );
        return;
      }
      final data = response['invitations'];
      if (data is List) {
        _invitations = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _invitations = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> createInvitation({
    required String email,
    required String role,
    String? universityId,
    String? fullName,
    String? notes,
    DateTime? expiresAt,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final params = <String, dynamic>{
        'p_email': email.trim(),
        'p_role': role.trim(),
        'p_university_id': universityId,
        'p_full_name': fullName?.trim(),
        'p_notes': notes?.trim(),
        'p_expires_at': expiresAt?.toIso8601String(),
      };
      final response = await _client.rpc(
        'app_admin_create_user_invitation',
        params: params,
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de la création.');
        return null;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la création de l\'invitation.',
        );
        return null;
      }
      await loadInvitations();
      return response;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  Future<Map<String, dynamic>?> createUniversityAccountDirect({
    required String email,
    required String password,
    required String universityName,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.functions.invoke(
        'admin-create-university-account',
        body: <String, dynamic>{
          'email': email.trim(),
          'password': password,
          'university_name': universityName.trim(),
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la création du compte université.',
        );
        return null;
      }

      if (data['success'] != true) {
        _setError(
          data['error']?.toString() ??
              'Erreur lors de la création du compte université.',
        );
        return null;
      }

      await loadInvitations();
      return data;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setSaving(false);
    }
  }

  Future<bool> cancelInvitation(String invitationId) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_cancel_user_invitation',
        params: {
          'p_invitation_id': invitationId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur lors de l\'annulation.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de l\'annulation de l\'invitation.',
        );
        return false;
      }
      await loadInvitations();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSaving(false);
    }
  }
}
