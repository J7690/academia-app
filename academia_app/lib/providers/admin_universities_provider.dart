import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUniversitiesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _universities = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get universities => List.unmodifiable(_universities);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  /// Définit le type de partenaire ('university' ou 'auto_ecole') d'un
  /// établissement. Utilisé pour distinguer les auto-écoles (permis de
  /// conduire) des universités classiques.
  Future<bool> setPartnerType({
    required String universityId,
    required String partnerType,
  }) async {
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_set_partner_type',
        params: {
          'p_university_id': universityId,
          'p_partner_type': partnerType,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  'Erreur lors du changement de type de partenaire.'
              : 'Erreur lors du changement de type de partenaire.',
        );
        return false;
      }
      final index = _universities
          .indexWhere((u) => u['id']?.toString() == universityId);
      if (index != -1) {
        _universities = List<Map<String, dynamic>>.from(_universities);
        _universities[index] = {
          ..._universities[index],
          'partner_type': partnerType,
        };
        notifyListeners();
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<void> loadUniversities() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc('app_list_partner_universities');
      if (response is List) {
        _universities = response
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _universities = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
