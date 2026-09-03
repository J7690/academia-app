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
      // TOUT SE FAIT MAINTENANT CÔTÉ SERVEUR, EN UNE SEULE FOIS.
      //
      // Ce qu'il y avait avant, et pourquoi ça ne marchait pas (audit du
      // 03/09/2026, constats B6 et M1) :
      //
      //  1. le montant était calculé ICI — prix du plan mis en cache, promo
      //     appliquée côté client — puis transmis à
      //     `app_student_create_profile_payment(p_amount_due)`, qui ne
      //     vérifiait que « > 0 ». Un client modifié payait ce qu'il voulait ;
      //  2. la ligne d'abonnement était insérée depuis le client
      //     (`.schema('app').from('subscriptions').insert`). app.subscriptions
      //     a RLS active et AUCUNE policy INSERT pour un étudiant : l'insertion
      //     était refusée. `app_confirm_ligdicash_payment` cherchait ensuite une
      //     ligne 'pending_payment' à activer et n'en trouvait jamais.
      //     Mesuré le 03/09 : app.subscriptions = 0 ligne. Personne n'avait
      //     jamais obtenu Premium, même après avoir payé.
      //
      // `app_student_create_subscription_payment` lit le tarif dans
      // app.subscription_plans, applique la promo elle-même, et crée le
      // paiement ET l'abonnement dans la même transaction.
      final resp = await _client.rpc(
        'app_student_create_subscription_payment',
        params: {'p_plan_code': planCode},
      );

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

      // Le montant affiché est désormais celui que le serveur a retenu,
      // pas celui que l'application avait calculé.
      final montant = data['amount_due'];
      return {
        'success': true,
        'payment_id': paymentId,
        'amount': montant is num ? montant.toDouble() : 0.0,
        'plan_code': data['plan_code']?.toString() ?? planCode,
        'plan_name': data['plan_name'],
        'subscription_id': data['subscription_id'],
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
