import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentMarketplaceInquiriesProviderV1 extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _inquiries = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get inquiries => List.unmodifiable(_inquiries);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadMyInquiries({
    int limit = 30,
    int offset = 0,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_student_list_my_opportunity_inquiries',
        params: {
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement de vos demandes.',
        );
        return;
      }

      final data = response['inquiries'];
      if (data is List) {
        _inquiries = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _inquiries = [];
      }

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createInquiry({
    required String opportunityId,
    required String message,
    int? quantity,
    double? budget,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_student_create_marketplace_listing_inquiry',
        params: {
          'p_listing_id': opportunityId,
          'p_message': message,
          'p_quantity': quantity,
          'p_budget': budget,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de l’envoi de la demande.',
        );
        return false;
      }

      await loadMyInquiries();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
