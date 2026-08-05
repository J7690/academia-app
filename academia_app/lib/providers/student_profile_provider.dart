import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Réponse de `app_is_student_dossier_complete()`.
///
/// [verified] distingue « le serveur a répondu » de « on n'a pas pu savoir ».
/// Sans cette distinction, une coupure réseau bloquerait l'étudiant alors que
/// le serveur reste de toute façon l'arbitre au moment de l'envoi.
class DossierStatus {
  final bool verified;
  final bool isComplete;
  final List<String> missingFields;

  const DossierStatus({
    required this.verified,
    required this.isComplete,
    required this.missingFields,
  });

  const DossierStatus.unverified()
      : verified = false,
        isComplete = false,
        missingFields = const <String>[];
}

class StudentProfileProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _profile;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get profile => _profile;
  String? get avatarUrl => _profile?['avatar_url']?.toString();
  String get displayName => _profile?['full_name']?.toString() ?? '';

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadProfile() async {
    _setLoading(true);
    _setError(null);
    try {
      final result = await _client.rpc('app_get_student_profile');
      if (result == null) {
        _profile = null;
      } else if (result is Map) {
        _profile = Map<String, dynamic>.from(result);
      } else {
        _setError('Réponse inattendue lors du chargement du profil.');
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Demande au serveur si le dossier de candidature est complet.
  ///
  /// On appelle le RPC plutôt que de rejouer les 12 règles côté Dart : une
  /// seconde définition de « complet » finirait par diverger de celle qui
  /// décide réellement, dans `app_create_application`.
  ///
  /// Ne touche ni `_isLoading` ni `_error` : c'est une vérification de
  /// passage, elle n'a pas à faire basculer l'écran profil en erreur.
  Future<DossierStatus> checkDossier() async {
    try {
      final result = await _client.rpc('app_is_student_dossier_complete');
      if (result is! Map) {
        debugPrint(
          '[StudentProfileProvider] checkDossier réponse inattendue: ${result.runtimeType}',
        );
        return const DossierStatus.unverified();
      }
      final map = Map<String, dynamic>.from(result);
      if (map['success'] != true) {
        debugPrint(
          '[StudentProfileProvider] checkDossier échec serveur: ${map['error']}',
        );
        return const DossierStatus.unverified();
      }
      final rawMissing = map['missing_fields'];
      return DossierStatus(
        verified: true,
        isComplete: map['is_complete'] == true,
        missingFields: rawMissing is List
            ? rawMissing.map((e) => e.toString()).toList()
            : const <String>[],
      );
    } catch (e) {
      debugPrint('[StudentProfileProvider] checkDossier error=$e');
      return const DossierStatus.unverified();
    }
  }

  /// Upload avatar image to Supabase Storage and update profile
  Future<bool> uploadAvatar(Uint8List bytes, String fileName) async {
    _setLoading(true);
    _setError(null);
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _setError('Utilisateur non connecté.');
        return false;
      }
      final ext = fileName.split('.').last.toLowerCase();
      final path = 'avatars/$userId.$ext';
      await _client.storage.from('community-media').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$ext',
            ),
          );
      final publicUrl =
          _client.storage.from('community-media').getPublicUrl(path);
      // Append cache-buster to force refresh
      final url = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      final ok = await updateProfile(avatarUrl: url);
      return ok;
    } catch (e) {
      _setError('Erreur upload avatar: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? country,
    String? city,
    String? dateOfBirth,
    String? avatarUrl,
    int? bepcYear,
    String? bepcInstitution,
    String? bepcCountry,
    String? bepcMention,
    int? bacYear,
    String? bacSeries,
    String? bacMention,
    String? bacInstitution,
    String? bacCountry,
    String? studyProjectText,
    String? timezone,
    double? geoLatitude,
    double? geoLongitude,
    String? bio,
    String? websiteUrl,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final params = <String, dynamic>{
        'p_full_name': fullName,
        'p_phone': phone,
        'p_country': country,
        'p_city': city,
        'p_date_of_birth': dateOfBirth,
        'p_avatar_url': avatarUrl,
        'p_bepc_year': bepcYear,
        'p_bepc_institution': bepcInstitution,
        'p_bepc_country': bepcCountry,
        'p_bepc_mention': bepcMention,
        'p_bac_year': bacYear,
        'p_bac_series': bacSeries,
        'p_bac_mention': bacMention,
        'p_bac_institution': bacInstitution,
        'p_bac_country': bacCountry,
        'p_study_project_text': studyProjectText,
        'p_timezone': timezone,
        'p_geo_latitude': geoLatitude,
        'p_geo_longitude': geoLongitude,
        'p_bio': bio,
        'p_website_url': websiteUrl,
      };

      final result = await _client.rpc('app_student_update_full_profile', params: params);
      if (result is Map) {
        final map = Map<String, dynamic>.from(result);
        if (map['success'] == true && map['profile'] is Map) {
          _profile = Map<String, dynamic>.from(map['profile'] as Map);
          notifyListeners();
          return true;
        } else {
          _setError(map['error']?.toString() ?? 'Erreur lors de la mise à jour du profil.');
          return false;
        }
      } else {
        _setError('Réponse inattendue lors de la mise à jour du profil.');
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
