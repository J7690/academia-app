import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UniversityApplicationPaymentsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _payments = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get payments => _payments;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadPaymentsForApplication(String applicationId) async {
    if (applicationId.isEmpty) return;
    _setLoading(true);
    _setError(null);
    try {
      final raw = await _client
          .schema('app')
          .from('application_payments')
          .select()
          .eq('application_id', applicationId)
          .order('created_at', ascending: false);
      final list = raw as List<dynamic>? ?? [];
      _payments = list.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e, st) {
      debugPrint(
        '[UniversityApplicationPaymentsProvider] loadPaymentsForApplication error=$e stack=$st',
      );
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
