import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentProfileProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _profile;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get profile => _profile;

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
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final params = <String, dynamic>{};
      if (fullName != null) params['p_full_name'] = fullName;
      if (phone != null) params['p_phone'] = phone;
      if (country != null) params['p_country'] = country;
      if (city != null) params['p_city'] = city;
      if (dateOfBirth != null) params['p_date_of_birth'] = dateOfBirth;
      if (avatarUrl != null) params['p_avatar_url'] = avatarUrl;
      if (bepcYear != null) params['p_bepc_year'] = bepcYear;
      if (bepcInstitution != null) params['p_bepc_institution'] = bepcInstitution;
      if (bepcCountry != null) params['p_bepc_country'] = bepcCountry;
      if (bepcMention != null) params['p_bepc_mention'] = bepcMention;
      if (bacYear != null) params['p_bac_year'] = bacYear;
      if (bacSeries != null) params['p_bac_series'] = bacSeries;
      if (bacMention != null) params['p_bac_mention'] = bacMention;
      if (bacInstitution != null) params['p_bac_institution'] = bacInstitution;
      if (bacCountry != null) params['p_bac_country'] = bacCountry;
      if (studyProjectText != null) {
        params['p_study_project_text'] = studyProjectText;
      }

      final result = await _client.rpc('app_update_student_profile', params: params);
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
