import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantMarketplaceConsoleProviderV2 extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _myOpportunities = [];
  List<Map<String, dynamic>> _inquiries = [];
  List<Map<String, dynamic>> _orders = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get myOpportunities =>
      List.unmodifiable(_myOpportunities);
  List<Map<String, dynamic>> get inquiries => List.unmodifiable(_inquiries);
  List<Map<String, dynamic>> get orders => List.unmodifiable(_orders);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadMyOpportunities(),
      loadInquiries(),
      loadMyOrders(),
    ]);
  }

  Future<void> loadMyOrders({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_merchant_list_my_marketplace_orders',
        params: {
          'p_limit': limit,
          'p_offset': offset,
          'p_status': status,
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

      final items = response['items'];
      if (items is List) {
        _orders = items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _orders = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> getOrderDetail({
    required String orderId,
  }) async {
    final id = orderId.trim();
    if (id.isEmpty) {
      _setError('Identifiant commande invalide.');
      return null;
    }

    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_merchant_get_marketplace_order_detail',
        params: {
          'p_order_id': id,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return null;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur serveur.');
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    final id = orderId.trim();
    final st = status.trim();
    if (id.isEmpty || st.isEmpty) {
      _setError('Paramètres invalides.');
      return false;
    }

    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_merchant_update_marketplace_order_status',
        params: {
          'p_order_id': id,
          'p_status': st,
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

      await loadMyOrders();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMyOpportunities({
    String? reviewStatus,
    int limit = 30,
    int offset = 0,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_merchant_list_my_marketplace_listings',
        params: {
          'p_review_status': reviewStatus,
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
              'Erreur lors du chargement de vos annonces.',
        );
        return;
      }

      final data = response['items'];
      if (data is List) {
        _myOpportunities = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _myOpportunities = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Map<String, dynamic>>> listListingMedia({
    required String listingId,
  }) async {
    final id = listingId.trim();
    if (id.isEmpty) {
      _setError('Identifiant annonce invalide.');
      return const [];
    }

    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_merchant_list_marketplace_listing_media',
        params: {
          'p_listing_id': id,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return const [];
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur serveur.');
        return const [];
      }

      final items = response['items'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }

      return const [];
    } catch (e) {
      _setError(e.toString());
      return const [];
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> disableListingMedia({
    required String mediaId,
  }) async {
    final id = mediaId.trim();
    if (id.isEmpty) {
      _setError('Identifiant média invalide.');
      return false;
    }

    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_merchant_disable_marketplace_listing_media',
        params: {
          'p_media_id': id,
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

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> uploadListingImageAndRegister({
    required String listingId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    int sortOrder = 0,
  }) async {
    final id = listingId.trim();
    if (id.isEmpty) {
      _setError('Identifiant annonce invalide.');
      return null;
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      _setError('Utilisateur non authentifié.');
      return null;
    }

    _setLoading(true);
    _setError(null);

    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ts = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '${user.id}/marketplace/$id/${ts}_$safeName';

    try {
      await _client.storage.from('landing-media').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: false,
            ),
          );

      final publicUrl =
          _client.storage.from('landing-media').getPublicUrl(storagePath);

      final response = await _client.rpc(
        'app_merchant_add_marketplace_listing_media',
        params: {
          'p_listing_id': id,
          'p_storage_path': storagePath,
          'p_sort_order': sortOrder,
          'p_media_type': 'image',
          'p_external_url': null,
          'p_title': null,
          'p_description': null,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return null;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur serveur.');
        return null;
      }

      await loadMyOpportunities();
      return publicUrl;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertOpportunity({
    String? opportunityId,
    required String title,
    required String shortDescription,
    String? description,
    required String type,
    String? category,
    required String organizationName,
    String? organizationLogoUrl,
    required String country,
    required String city,
    bool? isRemotePossible,
    String? contractType,
    int? durationMonths,
    DateTime? startDate,
    DateTime? applicationDeadline,
    double? priceFrom,
    double? priceTo,
    String? currency,
    int? minOrderQty,
    int? leadTimeDays,
    bool? isReadyToShip,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_merchant_upsert_marketplace_listing',
        params: {
          'p_listing_id': opportunityId,
          'p_title': title,
          'p_short_description': shortDescription,
          'p_description': description,
          'p_type': type,
          'p_category': category,
          'p_organization_name': organizationName,
          'p_organization_logo_url': organizationLogoUrl,
          'p_country': country,
          'p_city': city,
          'p_price_from': priceFrom,
          'p_price_to': priceTo,
          'p_currency': currency,
          'p_min_order_qty': minOrderQty,
          'p_lead_time_days': leadTimeDays,
          'p_is_ready_to_ship': isReadyToShip,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la sauvegarde de l’annonce.',
        );
        return false;
      }

      await loadMyOpportunities();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> submitForReview({
    required String opportunityId,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_merchant_submit_marketplace_listing_for_review',
        params: {
          'p_listing_id': opportunityId,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la soumission pour validation.',
        );
        return false;
      }

      await loadMyOpportunities();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadInquiries({
    String? status,
    int limit = 30,
    int offset = 0,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_merchant_list_inquiries',
        params: {
          'p_status': status,
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
              'Erreur lors du chargement des demandes.',
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

  Future<bool> replyToInquiry({
    required String inquiryId,
    required String message,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_merchant_reply_inquiry',
        params: {
          'p_inquiry_id': inquiryId,
          'p_message': message,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ?? 'Erreur lors de l’envoi du message.',
        );
        return false;
      }

      await loadInquiries();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
