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

  Future<Map<String, dynamic>?> createMerchantAccountDirect({
    required String email,
    required String password,
    required String displayName,
    String? country,
    String? city,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final body = <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'display_name': displayName.trim(),
        'country': country?.trim(),
        'city': city?.trim(),
      };

      final response = await _client.functions.invoke(
        'admin-create-merchant-account',
        body: body,
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la création du compte marchand.',
        );
        return null;
      }

      if (data['success'] != true) {
        _setError(
          data['error']?.toString() ??
              'Erreur lors de la création du compte marchand.',
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

  Future<Map<String, dynamic>?> createAdminAccountDirect({
    required String email,
    required String password,
    String? fullName,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.functions.invoke(
        'admin-create-admin-account',
        body: <String, dynamic>{
          'email': email.trim(),
          'password': password,
          if (fullName != null && fullName.trim().isNotEmpty)
            'full_name': fullName.trim(),
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la création du compte administrateur.',
        );
        return null;
      }

      if (data['success'] != true) {
        _setError(
          data['error']?.toString() ??
              'Erreur lors de la création du compte administrateur.',
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

  Future<Map<String, dynamic>?> createCommercialAccountDirect({
    required String email,
    required String password,
    String? fullName,
    double? commissionRate,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final body = <String, dynamic>{
        'email': email.trim(),
        'password': password,
      };
      if (fullName != null && fullName.trim().isNotEmpty) {
        body['full_name'] = fullName.trim();
      }
      if (commissionRate != null) {
        body['commission_rate'] = commissionRate;
      }

      final response = await _client.functions.invoke(
        'admin-create-commercial-account',
        body: body,
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la création du compte commercial.',
        );
        return null;
      }

      if (data['success'] != true) {
        _setError(
          data['error']?.toString() ??
              'Erreur lors de la création du compte commercial.',
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

  Future<Map<String, dynamic>?> createTeacherAccountDirect({
    required String email,
    required String password,
    String? fullName,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.functions.invoke(
        'admin-create-teacher-account',
        body: <String, dynamic>{
          'email': email.trim(),
          'password': password,
          if (fullName != null && fullName.trim().isNotEmpty)
            'full_name': fullName.trim(),
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la création du compte enseignant.',
        );
        return null;
      }

      if (data['success'] != true) {
        _setError(
          data['error']?.toString() ??
              'Erreur lors de la création du compte enseignant.',
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

  /// Crée un conseiller d'orientation.
  ///
  /// Contrairement aux autres rôles, l'Edge Function pose deux choses en une
  /// seule opération : le compte avec `role = orientation_counselor`, qui
  /// déclenche l'aiguillage à la connexion, et le profil métier dans
  /// `app.orientation_counselors`, sans lequel le conseiller n'apparaîtrait
  /// dans aucune recherche d'élève.
  Future<Map<String, dynamic>?> createOrientationCounselorAccount({
    required String email,
    required String password,
    required String fullName,
    String kind = 'orientation',
    List<String> specialites = const [],
    List<String> niveaux = const [],
    List<String> langues = const ['fr'],
    String? bio,
    int tarifFcfa = 0,
    int dureeMinutes = 45,
  }) async {
    _setSaving(true);
    _setError(null);
    try {
      final response = await _client.functions.invoke(
        'admin-create-orientation-counselor',
        body: <String, dynamic>{
          'email': email.trim().toLowerCase(),
          'password': password,
          'full_name': fullName.trim(),
          'kind': kind,
          'specialites': specialites,
          'niveaux': niveaux,
          'langues': langues,
          if (bio != null && bio.trim().isNotEmpty) 'bio': bio.trim(),
          'tarif_fcfa': tarifFcfa,
          'duree_minutes': dureeMinutes,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        _setError('Réponse invalide lors de la création du conseiller.');
        return null;
      }
      if (data['success'] != true) {
        _setError(_counselorErrorMessage(
            data['error']?.toString(), data['detail']?.toString()));
        return null;
      }
      return data;
    } on FunctionException catch (e) {
      // functions.invoke lève sur tout statut hors 2xx : le corps JSON n'est
      // alors pas dans response.data mais dans e.details. Sans ce cas, une
      // erreur métier parfaitement prévisible — adresse déjà prise — remontait
      // à l'utilisateur sous la forme d'une exception technique brute.
      final details = e.details;
      _setError(_counselorErrorMessage(
        details is Map ? details['error']?.toString() : null,
        details is Map ? details['detail']?.toString() : null,
      ));
      return null;
    } catch (e) {
      _setError('Création impossible. Vérifiez votre connexion et réessayez.');
      debugPrint('[AdminUserInvitations] createOrientationCounselor: $e');
      return null;
    } finally {
      _setSaving(false);
    }
  }

  /// Traduit un code d'erreur de l'Edge Function en phrase actionnable.
  ///
  /// Le détail technique est conservé pour les cas serveur : sans lui, un
  /// échec comme celui du 26 juillet — droits manquants sur la table du module
  /// d'orientation — reste indiagnosticable depuis l'application.
  String _counselorErrorMessage(String? code, [String? detail]) {
    final message = switch (code) {
      'email_already_exists' =>
        'Cette adresse est déjà utilisée par un autre compte. '
            'Choisissez-en une autre.',
      'password_too_short' =>
        'Le mot de passe doit comporter 8 caractères au minimum.',
      'invalid_email' => 'Cette adresse e-mail n\'est pas valide.',
      'full_name_required' => 'Le nom complet est obligatoire.',
      'invalid_kind' => 'Type de conseil non reconnu.',
      'not_admin' => 'Cette action est réservée aux administrateurs.',
      'not_authenticated' =>
        'Votre session a expiré. Reconnectez-vous et réessayez.',
      'user_not_found' => 'Ce compte est introuvable.',
      'profile_creation_failed' =>
        'Le compte n\'a pas pu être rattaché au module d\'orientation. '
            'Aucun compte n\'a été créé.',
      _ => 'Création impossible. Réessayez dans un instant.',
    };
    if (detail != null && detail.trim().isNotEmpty) {
      return '$message\n($detail)';
    }
    return message;
  }
}
