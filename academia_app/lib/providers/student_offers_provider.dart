import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les offres de formation et universités partenaires
/// Utilise exclusivement les RPC validés dans .windsurf
class StudentOffersProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _homeOffers = [];
  List<Map<String, dynamic>> _universities = [];
  List<Map<String, dynamic>> _programsByUniversity = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get homeOffers => _homeOffers;
  List<Map<String, dynamic>> get universities => _universities;
  List<Map<String, dynamic>> get programsByUniversity => _programsByUniversity;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  /// Chargement des offres pour la page d'accueil
  Future<void> loadHomeOffers() async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _client.rpc('app_list_home_offers') as List<dynamic>? ?? [];
      _homeOffers = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Chargement des universités partenaires
  Future<void> loadPartnerUniversities() async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _client.rpc('app_list_partner_universities') as List<dynamic>? ?? [];
      _universities = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Chargement des programmes pour une université donnée
  Future<void> loadProgramsByUniversity(String universityId) async {
    _setLoading(true);
    _setError(null);
    try {
      final data = await _client.rpc(
        'app_list_programs_by_university',
        params: {'p_university_id': universityId},
      ) as List<dynamic>? ?? [];
      _programsByUniversity = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  void clearProgramsByUniversity() {
    _programsByUniversity = [];
    notifyListeners();
  }
}
