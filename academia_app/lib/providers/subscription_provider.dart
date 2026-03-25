import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour gérer les abonnements Premium de l'étudiant.
class SubscriptionProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _activeSubscription;
  List<Map<String, dynamic>> _plans = [];
  bool _initialized = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get activeSubscription => _activeSubscription;
  List<Map<String, dynamic>> get plans => _plans;
  bool get hasActiveSubscription => _activeSubscription != null;
  bool get initialized => _initialized;

  String get activePlanCode =>
      _activeSubscription?['plan_code']?.toString() ?? '';
  String get activePlanName =>
      _activeSubscription?['plan_name']?.toString() ?? '';
  String? get expiresAt =>
      _activeSubscription?['expires_at']?.toString();

  /// Vérifie si l'étudiant a accès à un feature premium.
  /// Features : "prep_concours", "ia_tuteur_illimite", "jeux_complets",
  ///            "lives_prioritaires", "td_illimite"
  bool hasFeatureAccess(String feature) {
    if (_activeSubscription == null) return false;
    final features = _activeSubscription!['features'];
    if (features is List) {
      return features.contains(feature);
    }
    return false;
  }

  /// Charge l'abonnement actif de l'étudiant courant.
  Future<void> loadActiveSubscription() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        _activeSubscription = null;
        _initialized = true;
        notifyListeners();
        return;
      }

      // Charger l'abonnement actif (le plus récent qui n'a pas expiré)
      final raw = await _client
          .schema('app')
          .from('subscriptions')
          .select('id, student_id, plan_id, status, started_at, expires_at, auto_renew, created_at, subscription_plans!inner(code, name, price, duration_days, features)')
          .eq('student_id', userId)
          .eq('status', 'active')
          .order('expires_at', ascending: false)
          .limit(1);

      final list = raw as List<dynamic>? ?? [];
      if (list.isNotEmpty) {
        final sub = Map<String, dynamic>.from(list.first as Map);
        final plan = sub['subscription_plans'];
        if (plan is Map) {
          sub['plan_code'] = plan['code'];
          sub['plan_name'] = plan['name'];
          sub['plan_price'] = plan['price'];
          sub['features'] = plan['features'];
        }
        // Vérifier l'expiration côté client
        final expiresStr = sub['expires_at']?.toString();
        if (expiresStr != null) {
          final expires = DateTime.tryParse(expiresStr);
          if (expires != null && expires.isBefore(DateTime.now())) {
            _activeSubscription = null;
          } else {
            _activeSubscription = sub;
          }
        } else {
          _activeSubscription = sub;
        }
      } else {
        _activeSubscription = null;
      }
      _initialized = true;
    } catch (e, st) {
      debugPrint('[SubscriptionProvider] loadActiveSubscription error=$e\n$st');
      _error = e.toString();
      _initialized = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charge les plans d'abonnement disponibles.
  Future<void> loadPlans() async {
    try {
      final raw = await _client
          .schema('app')
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('price', ascending: true);

      final list = raw as List<dynamic>? ?? [];
      _plans = list.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e, st) {
      debugPrint('[SubscriptionProvider] loadPlans error=$e\n$st');
    }
  }

  /// Vérifie l'accès via la RPC serveur (plus fiable que le cache local).
  Future<bool> checkFeatureAccessServer(String feature) async {
    try {
      final resp = await _client.rpc('app_student_check_subscription', params: {
        'p_feature': feature,
      });
      final data = resp as Map<String, dynamic>?;
      return data?['has_access'] == true;
    } catch (e) {
      debugPrint('[SubscriptionProvider] checkFeatureAccessServer error=$e');
      return false;
    }
  }

  /// Crée un paiement d'abonnement et retourne le payment_id.
  /// L'appelant ouvrira ensuite le LigdiCashPaymentSheet avec ce payment_id.
  Future<Map<String, dynamic>> createSubscriptionPayment(String planCode) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Trouver le plan
      final plan = _plans.firstWhere(
        (p) => p['code'] == planCode,
        orElse: () => <String, dynamic>{},
      );
      if (plan.isEmpty) {
        _error = 'Plan introuvable.';
        return {'success': false, 'error': 'plan_not_found'};
      }

      final price = plan['price'];
      double amount = 0;
      if (price is num) amount = price.toDouble();

      // Calculer prix avec promo
      final promoPercent = plan['promo_percent'];
      if (promoPercent is int && promoPercent > 0) {
        final promoExpires = plan['promo_expires_at']?.toString();
        bool promoActive = true;
        if (promoExpires != null) {
          final dt = DateTime.tryParse(promoExpires);
          if (dt != null && dt.isBefore(DateTime.now())) {
            promoActive = false;
          }
        }
        if (promoActive) {
          amount = amount * (1 - promoPercent / 100);
        }
      }

      if (amount <= 0) {
        _error = 'Prix invalide pour ce plan.';
        return {'success': false, 'error': 'invalid_price'};
      }

      // Créer le paiement via la RPC existante (subscription type)
      final resp = await _client.rpc('app_student_create_profile_payment', params: {
        'p_payment_reason': 'subscription',
        'p_amount_due': amount,
      });

      final data = resp as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        _error = data?['error']?.toString() ?? 'Erreur création paiement.';
        return {'success': false, 'error': _error};
      }

      final paymentId = data['payment_id']?.toString();
      if (paymentId == null || paymentId.isEmpty) {
        _error = 'payment_id manquant.';
        return {'success': false, 'error': 'missing_payment_id'};
      }

      // Créer la subscription en pending_payment
      final planId = plan['id']?.toString();
      final durationDays = plan['duration_days'] as int? ?? 30;
      final expiresAt = DateTime.now().add(Duration(days: durationDays));

      await _client.schema('app').from('subscriptions').insert({
        'student_id': _client.auth.currentUser!.id,
        'plan_id': planId,
        'status': 'pending_payment',
        'payment_id': paymentId,
        'expires_at': expiresAt.toIso8601String(),
      });

      return {
        'success': true,
        'payment_id': paymentId,
        'amount': amount,
        'plan_code': planCode,
        'plan_name': plan['name'],
      };
    } catch (e, st) {
      debugPrint('[SubscriptionProvider] createSubscriptionPayment error=$e\n$st');
      _error = e.toString();
      return {'success': false, 'error': e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calcule le prix effectif d'un plan (avec promo si applicable).
  double effectivePrice(Map<String, dynamic> plan) {
    final price = plan['price'];
    double base = 0;
    if (price is num) base = price.toDouble();

    final promoPercent = plan['promo_percent'];
    if (promoPercent is int && promoPercent > 0) {
      final promoExpires = plan['promo_expires_at']?.toString();
      bool promoActive = true;
      if (promoExpires != null) {
        final dt = DateTime.tryParse(promoExpires);
        if (dt != null && dt.isBefore(DateTime.now())) {
          promoActive = false;
        }
      }
      if (promoActive) {
        return base * (1 - promoPercent / 100);
      }
    }
    return base;
  }
}
