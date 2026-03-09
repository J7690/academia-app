import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentMarketplaceBookmarkedListingsProviderV1 extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  int _total = 0;
  int _limit = 20;
  int _offset = 0;
  bool _hasMore = true;

  String _lastSort = 'newest';

  final List<Map<String, dynamic>> _items = [];

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  int get total => _total;
  bool get hasMore => _hasMore;
  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setLoadingMore(bool v) {
    _isLoadingMore = v;
    notifyListeners();
  }

  void _setError(String? v) {
    _error = v;
    notifyListeners();
  }

  Future<void> load({
    String sort = 'newest',
    bool refresh = true,
    int limit = 20,
  }) async {
    if (refresh) {
      _limit = limit;
      _offset = 0;
      _hasMore = true;
      _items.clear();
      _setLoading(true);
    } else {
      if (_isLoadingMore || !_hasMore) return;
      _setLoadingMore(true);
    }

    _setError(null);
    _lastSort = sort;

    try {
      final response = await _client.rpc(
        'app_student_list_bookmarked_marketplace_listings',
        params: {
          'p_limit': _limit,
          'p_offset': _offset,
          'p_sort': _lastSort,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur serveur.');
        return;
      }

      final total = response['total'];
      _total = total is int ? total : 0;

      final data = response['items'];
      final newItems = (data is List)
          ? data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false)
          : <Map<String, dynamic>>[];

      _items.addAll(newItems);
      _offset = _items.length;
      _hasMore = newItems.length >= _limit;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (refresh) {
        _setLoading(false);
      } else {
        _setLoadingMore(false);
      }
    }
  }

  Future<void> loadMore() async {
    await load(sort: _lastSort, refresh: false, limit: _limit);
  }
}
