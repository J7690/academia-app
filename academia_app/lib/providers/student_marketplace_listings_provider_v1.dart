import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentMarketplaceListingsProviderV1 extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  int _total = 0;
  int _limit = 20;
  int _offset = 0;
  bool _hasMore = true;

  String? _lastType;
  String? _lastSearch;
  String _lastSort = 'newest';
  bool _lastVerifiedOnly = false;
  bool _lastReadyToShipOnly = false;
  String? _lastCategoryId;
  String? _lastSubCategoryId;

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

  Future<void> loadListings({
    String? type,
    String? search,
    String? sort,
    bool? verifiedOnly,
    bool? readyToShipOnly,
    String? categoryId,
    String? subCategoryId,
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

    _lastType = type;
    _lastSearch = search;
    _lastSort = sort ?? _lastSort;
    _lastVerifiedOnly = verifiedOnly ?? _lastVerifiedOnly;
    _lastReadyToShipOnly = readyToShipOnly ?? _lastReadyToShipOnly;
    _lastCategoryId = categoryId ?? _lastCategoryId;
    _lastSubCategoryId = subCategoryId ?? _lastSubCategoryId;

    try {
      final response = await _client.rpc(
        'app_student_list_marketplace_listings',
        params: {
          'p_type': type,
          'p_search': search,
          'p_limit': _limit,
          'p_offset': _offset,
          'p_sort': _lastSort,
          'p_verified_only': _lastVerifiedOnly,
          'p_ready_to_ship_only': _lastReadyToShipOnly,
          'p_category_id': _lastCategoryId,
          'p_sub_category_id': _lastSubCategoryId,
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
      if (total is int) {
        _total = total;
      } else {
        _total = 0;
      }

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
    await loadListings(
      type: _lastType,
      search: _lastSearch,
      sort: _lastSort,
      verifiedOnly: _lastVerifiedOnly,
      readyToShipOnly: _lastReadyToShipOnly,
      categoryId: _lastCategoryId,
      subCategoryId: _lastSubCategoryId,
      refresh: false,
      limit: _limit,
    );
  }

  Future<bool> toggleBookmark(String listingId) async {
    final id = listingId.trim();
    if (id.isEmpty) {
      _setError('Identifiant annonce invalide.');
      return false;
    }

    _setError(null);
    try {
      final response = await _client.rpc(
        'app_marketplace_listing_toggle_bookmark',
        params: {
          'p_listing_id': id,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur serveur.');
        return false;
      }

      final bookmarked = response['bookmarked'] == true;
      for (var i = 0; i < _items.length; i++) {
        final itemId = _items[i]['id']?.toString();
        if (itemId == id) {
          _items[i] = {
            ..._items[i],
            'is_bookmarked': bookmarked,
          };
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
}
