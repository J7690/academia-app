import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentMarketplaceCartProviderV1 extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isMutating = false;
  String? _error;

  String? _cartId;
  List<Map<String, dynamic>> _items = [];
  num _total = 0;
  String? _currency;

  bool get isLoading => _isLoading;
  bool get isMutating => _isMutating;
  String? get error => _error;
  String? get errorMessage => _mapErrorToMessage(_error);

  String? get cartId => _cartId;
  List<Map<String, dynamic>> get items => List.unmodifiable(_items);
  num get total => _total;
  String? get currency => _currency;

  static String? _mapErrorToMessage(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;

    switch (v) {
      case 'not_authenticated':
        return 'Connecte-toi pour utiliser le panier.';
      case 'cart_not_found':
        return 'Panier introuvable. Réessaie.';
      case 'cart_empty':
        return 'Ton panier est vide.';
      case 'listing_not_available':
        return 'Ce produit n’est plus disponible.';
      case 'invalid_listing_id':
      case 'invalid_item_id':
      case 'invalid_params':
      case 'item_not_found':
        return 'Action impossible. Réessaie.';
      default:
        return v;
    }
  }

  int get itemsCount {
    int sum = 0;
    for (final i in _items) {
      final q = i['quantity'];
      if (q is int) sum += q;
      if (q is num) sum += q.toInt();
    }
    return sum;
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setMutating(bool v) {
    _isMutating = v;
    notifyListeners();
  }

  void _setError(String? v) {
    _error = v;
    notifyListeners();
  }

  Future<void> loadCart() async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await _client.rpc('app_student_get_cart');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur serveur.');
        return;
      }

      _cartId = response['cart_id']?.toString();
      _total = (response['total'] is num) ? response['total'] as num : 0;
      _currency = response['currency']?.toString();

      final data = response['items'];
      if (data is List) {
        _items = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _items = [];
      }

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addItem({required String listingId, int quantity = 1}) async {
    final id = listingId.trim();
    if (id.isEmpty) {
      _setError('Identifiant produit invalide.');
      return false;
    }

    _setMutating(true);
    _setError(null);

    try {
      final response = await _client.rpc(
        'app_student_cart_add_item',
        params: {
          'p_listing_id': id,
          'p_quantity': quantity,
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

      await loadCart();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setMutating(false);
    }
  }

  Future<bool> updateQuantity({required String itemId, required int quantity}) async {
    final id = itemId.trim();
    if (id.isEmpty) {
      _setError('Identifiant item invalide.');
      return false;
    }

    _setMutating(true);
    _setError(null);

    try {
      final response = await _client.rpc(
        'app_student_cart_update_quantity',
        params: {
          'p_item_id': id,
          'p_quantity': quantity,
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

      await loadCart();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setMutating(false);
    }
  }

  Future<bool> removeItem({required String itemId}) async {
    final id = itemId.trim();
    if (id.isEmpty) {
      _setError('Identifiant item invalide.');
      return false;
    }

    _setMutating(true);
    _setError(null);

    try {
      final response = await _client.rpc(
        'app_student_cart_remove_item',
        params: {
          'p_item_id': id,
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

      await loadCart();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setMutating(false);
    }
  }

  Future<bool> clear() async {
    _setMutating(true);
    _setError(null);

    try {
      final response = await _client.rpc('app_student_cart_clear');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur serveur.');
        return false;
      }

      await loadCart();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setMutating(false);
    }
  }

  Future<Map<String, dynamic>?> checkout() async {
    _setMutating(true);
    _setError(null);

    try {
      final response =
          await _client.rpc('app_student_checkout_create_order_from_cart');

      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return null;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ?? 'Erreur serveur.');
        return null;
      }

      await loadCart();
      return response;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setMutating(false);
    }
  }
}
