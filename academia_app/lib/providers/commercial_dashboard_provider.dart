import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommercialDashboardProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _referrals = [];
  List<Map<String, dynamic>> _commissions = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get profile => _profile;
  Map<String, dynamic>? get summary => _summary;
  List<Map<String, dynamic>> get referrals => List.unmodifiable(_referrals);
  List<Map<String, dynamic>> get commissions => List.unmodifiable(_commissions);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadDashboard() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_commercial_get_dashboard');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour le tableau de bord commercial.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement du tableau de bord commercial.',
        );
        return;
      }

      final rawProfile = response['profile'];
      final rawSummary = response['summary'];
      final rawReferrals = response['referrals'];
      final rawCommissions = response['commissions'];

      if (rawProfile is Map) {
        _profile = Map<String, dynamic>.from(rawProfile);
      } else {
        _profile = null;
      }

      if (rawSummary is Map) {
        _summary = Map<String, dynamic>.from(rawSummary);
      } else {
        _summary = null;
      }

      if (rawReferrals is List) {
        _referrals = rawReferrals
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _referrals = [];
      }

      if (rawCommissions is List) {
        _commissions = rawCommissions
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _commissions = [];
      }

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
