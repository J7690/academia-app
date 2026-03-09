import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminMarketplaceControlTowerProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _pendingOpportunities = [];
  List<Map<String, dynamic>> _publishedListings = [];
  List<Map<String, dynamic>> _merchants = [];
  List<Map<String, dynamic>> _orders = [];

  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Map<String, dynamic>> get pendingOpportunities =>
      List.unmodifiable(_pendingOpportunities);
  List<Map<String, dynamic>> get publishedListings =>
      List.unmodifiable(_publishedListings);
  List<Map<String, dynamic>> get merchants => List.unmodifiable(_merchants);
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
      loadPendingOpportunities(),
      loadPublishedListings(),
      loadMerchants(),
      loadOrders(),
    ]);
  }

  Future<void> loadOrders({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_marketplace_orders',
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

      final data = response['items'];
      if (data is List) {
        _orders = data
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

  Future<void> loadPublishedListings({
    int limit = 50,
    int offset = 0,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_published_marketplace_listings',
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
              'Erreur lors du chargement des annonces publiées.',
        );
        return;
      }

      final data = response['items'];
      if (data is List) {
        _publishedListings = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _publishedListings = [];
      }

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPendingOpportunities() async {
    _setLoading(true);
    _setError(null);
    try {
      final response =
          await _client.rpc('app_admin_list_pending_marketplace_listings');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des annonces en attente.',
        );
        return;
      }

      final data = response['items'];
      if (data is List) {
        _pendingOpportunities = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _pendingOpportunities = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> reviewOpportunity({
    required String opportunityId,
    required bool approve,
    String? reason,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_review_marketplace_listing',
        params: {
          'p_listing_id': opportunityId,
          'p_decision': approve ? 'approve' : 'reject',
          'p_reason': reason,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la validation de l’annonce.',
        );
        return false;
      }

      await loadPendingOpportunities();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMerchants() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_admin_list_marketplace_merchants');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors du chargement des marchands.',
        );
        return;
      }

      final data = response['merchants'];
      if (data is List) {
        _merchants = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _merchants = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> setMerchantVerification({
    required String merchantId,
    required bool isVerified,
    required String verificationLevel,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_set_merchant_verification',
        params: {
          'p_merchant_id': merchantId,
          'p_is_verified': isVerified,
          'p_verification_level': verificationLevel,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la mise à jour de la vérification.',
        );
        return false;
      }

      await loadMerchants();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateMerchantStatus({
    required String merchantId,
    required bool isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_update_marketplace_merchant_status',
        params: {
          'p_merchant_id': merchantId,
          'p_is_active': isActive,
        },
      );

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      if (response['success'] != true) {
        _setError(
          response['error']?.toString() ??
              'Erreur lors de la mise à jour du statut.',
        );
        return false;
      }

      await loadMerchants();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Map<String, dynamic>>> adminListListingMedia({
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
        'app_admin_list_marketplace_listing_media',
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

  Future<bool> adminDisableListingMedia({
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
        'app_admin_disable_marketplace_listing_media',
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

  Future<String?> adminUploadListingImageAndRegister({
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
    final storagePath = '${user.id}/admin/marketplace/$id/${ts}_$safeName';

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
        'app_admin_add_marketplace_listing_media',
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

      return publicUrl;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }
}
