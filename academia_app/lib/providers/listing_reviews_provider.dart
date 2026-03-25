import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListingReviewsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;

  final Map<String, List<Map<String, dynamic>>> _reviews = {};
  final Map<String, int> _totals = {};
  final Map<String, bool> _hasMore = {};

  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Map<String, dynamic>> getReviews(String listingId) =>
      _reviews[listingId] ?? [];

  int getTotal(String listingId) => _totals[listingId] ?? 0;

  bool hasMore(String listingId) => _hasMore[listingId] ?? true;

  Future<void> loadReviews(
    String listingId, {
    bool refresh = false,
    int limit = 20,
    String sort = 'newest',
  }) async {
    if (refresh) {
      _reviews[listingId] = [];
      _hasMore[listingId] = true;
    }

    final current = _reviews[listingId] ?? [];
    final offset = refresh ? 0 : current.length;

    if (!refresh && _hasMore[listingId] == false) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _client.rpc(
        'app_student_list_listing_reviews',
        params: {
          'p_listing_id': listingId,
          'p_limit': limit,
          'p_offset': offset,
          'p_sort': sort,
        },
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        final newReviews = (response['reviews'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final total = response['total'] as int? ?? 0;
        final hasMoreData = response['has_more'] as bool? ?? false;

        if (refresh) {
          _reviews[listingId] = newReviews;
        } else {
          _reviews[listingId] = [...current, ...newReviews];
        }
        _totals[listingId] = total;
        _hasMore[listingId] = hasMoreData;
      } else {
        _error = response is Map
            ? response['error']?.toString()
            : 'Erreur chargement avis';
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[ListingReviewsProvider] loadReviews error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addReview({
    required String listingId,
    String? orderId,
    required int rating,
    String? title,
    String? content,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _client.rpc(
        'app_student_add_listing_review',
        params: {
          'p_listing_id': listingId,
          'p_order_id': orderId,
          'p_rating': rating,
          'p_title': title,
          'p_content': content,
        },
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        await loadReviews(listingId, refresh: true);
        return true;
      }

      _error = response is Map
          ? response['error']?.toString()
          : 'Erreur ajout avis';
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('[ListingReviewsProvider] addReview error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearCache(String listingId) {
    _reviews.remove(listingId);
    _totals.remove(listingId);
    _hasMore.remove(listingId);
  }
}
