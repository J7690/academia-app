import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stripe_flutter/stripe_flutter.dart';
import 'tiktok_creator_fund_service.dart';
import 'sponsorship_service.dart';

/// Service pour la gestion des wallets et paiements mobile first
class WalletService {
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static final Map<String, UserWallet> _wallets = {};
  static final Map<String, List<PaymentMethod>> _paymentMethods = {};
  static final Map<String, List<WalletTransaction>> _transactions = {};
  static final Uuid _uuid = Uuid();
  
  /// Initialiser le wallet d'un utilisateur
  static Future<UserWallet> initializeWallet(String userId) async {
    try {
      // Vérifier si le wallet existe déjà
      final existingWallet = await getUserWallet(userId);
      if (existingWallet != null) {
        return existingWallet;
      }
      
      // Créer le wallet
      final wallet = UserWallet(
        id: _uuid.v4(),
        userId: userId,
        balance: 0.0,
        currency: 'USD',
        totalEarned: 0.0,
        totalSpent: 0.0,
        lastTransactionAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Sauvegarder dans la base
      await Supabase.instance.client
          .from('user_wallets')
          .insert(wallet.toJson());
      
      _wallets[userId] = wallet;
      return wallet;
    } catch (e) {
      print('Erreur initialisation wallet: $e');
      rethrow;
    }
  }
  
  /// Obtenir le wallet d'un utilisateur
  static Future<UserWallet?> getUserWallet(String userId) async {
    try {
      if (_wallets.containsKey(userId)) {
        return _wallets[userId];
      }
      
      final result = await Supabase.instance.client
          .from('user_wallets')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      if (result != null) {
        final wallet = UserWallet.fromJson(result);
        _wallets[userId] = wallet;
        return wallet;
      }
      return null;
    } catch (e) {
      print('Erreur récupération wallet: $e');
      return null;
    }
  }
  
  /// Ajouter une méthode de paiement
  static Future<String> addPaymentMethod({
    required String userId,
    required PaymentMethodType type,
    required String provider,
    required String methodToken,
    String? lastFour,
    int? expiryMonth,
    int? expiryYear,
    String? brand,
    bool isDefault = false,
  }) async {
    try {
      final paymentMethodId = _uuid.v4();
      
      // Si c'est la méthode par défaut, désactiver les autres
      if (isDefault) {
        await _setDefaultPaymentMethod(userId, null);
      }
      
      final paymentMethod = PaymentMethod(
        id: paymentMethodId,
        userId: userId,
        type: type,
        provider: provider,
        methodToken: methodToken,
        lastFour: lastFour,
        expiryMonth: expiryMonth,
        expiryYear: expiryYear,
        brand: brand,
        isDefault: isDefault,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Sauvegarder dans la base
      await Supabase.instance.client
          .from('payment_methods')
          .insert(paymentMethod.toJson());
      
      // Mettre à jour le cache
      if (!_paymentMethods.containsKey(userId)) {
        _paymentMethods[userId] = [];
      }
      _paymentMethods[userId]!.add(paymentMethod);
      
      // Sauvegarder le token de manière sécurisée
      await _secureStorage.write(
        key: 'payment_token_${paymentMethodId}',
        value: methodToken,
      );
      
      return paymentMethodId;
    } catch (e) {
      print('Erreur ajout méthode paiement: $e');
      rethrow;
    }
  }
  
  /// Définir la méthode de paiement par défaut
  static Future<void> _setDefaultPaymentMethod(String userId, String? paymentMethodId) async {
    try {
      if (paymentMethodId != null) {
        await Supabase.instance.client
            .from('payment_methods')
            .update({'is_default': false})
            .eq('user_id', userId)
            .neq('id', paymentMethodId);
        
        await Supabase.instance.client
            .from('payment_methods')
            .update({'is_default': true})
            .eq('id', paymentMethodId);
      } else {
        await Supabase.instance.client
            .from('payment_methods')
            .update({'is_default': false})
            .eq('user_id', userId);
      }
      
      // Mettre à jour le cache
      if (_paymentMethods.containsKey(userId)) {
        for (final method in _paymentMethods[userId]!) {
          method.isDefault = (method.id == paymentMethodId);
        }
      }
    } catch (e) {
      print('Erreur définition méthode par défaut: $e');
    }
  }
  
  /// Obtenir les méthodes de paiement d'un utilisateur
  static Future<List<PaymentMethod>> getPaymentMethods(String userId) async {
    try {
      if (_paymentMethods.containsKey(userId)) {
        return _paymentMethods[userId]!;
      }
      
      final result = await Supabase.instance.client
          .from('payment_methods')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('is_default', ascending: false);
      
      final methods = result.map((json) => PaymentMethod.fromJson(json)).toList();
      _paymentMethods[userId] = methods;
      return methods;
    } catch (e) {
      print('Erreur méthodes paiement: $e');
      return [];
    }
  }
  
  /// Créer une transaction
  static Future<String> createTransaction({
    required String userId,
    required TransactionType type,
    required double amount,
    required String description,
    String? referenceId,
    String? referenceType,
    String? paymentMethodId,
    double feeAmount = 0.0,
  }) async {
    try {
      final transactionId = _uuid.v4();
      final netAmount = amount - feeAmount;
      
      final transaction = WalletTransaction(
        id: transactionId,
        userId: userId,
        type: type,
        amount: amount,
        currency: 'USD',
        description: description,
        referenceId: referenceId,
        referenceType: referenceType,
        status: TransactionStatus.completed,
        paymentMethodId: paymentMethodId,
        feeAmount: feeAmount,
        netAmount: netAmount,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Sauvegarder dans la base
      await Supabase.instance.client
          .from('wallet_transactions')
          .insert(transaction.toJson());
      
      // Mettre à jour le cache
      if (!_transactions.containsKey(userId)) {
        _transactions[userId] = [];
      }
      _transactions[userId]!.add(transaction);
      
      // Mettre à jour le wallet (le trigger s'en charge)
      final wallet = await getUserWallet(userId);
      if (wallet != null) {
        wallet.balance += (type == TransactionType.credit || type == TransactionType.refund) ? netAmount : -netAmount;
        wallet.lastTransactionAt = DateTime.now();
        wallet.updatedAt = DateTime.now();
        _wallets[userId] = wallet;
      }
      
      return transactionId;
    } catch (e) {
      print('Erreur création transaction: $e');
      rethrow;
    }
  }
  
  /// Obtenir les transactions d'un utilisateur
  static Future<List<WalletTransaction>> getTransactions(String userId, {int limit = 20}) async {
    try {
      if (_transactions.containsKey(userId) && _transactions[userId]!.length <= limit) {
        return _transactions[userId]!;
      }
      
      final result = await Supabase.instance.client
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', descending: true)
          .limit(limit);
      
      final transactions = result.map((json) => WalletTransaction.fromJson(json)).toList();
      _transactions[userId] = transactions;
      return transactions;
    } catch (e) {
      print('Erreur transactions: $e');
      return [];
    }
  }
  
  /// Payer avec Stripe
  static Future<String> payWithStripe({
    required String userId,
    required double amount,
    required String description,
    String? paymentMethodId,
  }) async {
    try {
      // Initialiser Stripe
      await Stripe.instance.init();
      
      // Créer le Payment Intent
      final paymentIntent = await Stripe.instance.createPaymentIntent(
        amount: (amount * 100).round(), // Convertir en cents
        currency: 'usd',
        description: description,
        paymentMethodId: paymentMethodId,
      );
      
      final transactionId = await createTransaction(
        userId: userId,
        type: TransactionType.debit,
        amount: amount,
        description: 'Stripe payment: $description',
        referenceId: paymentIntent.id,
        referenceType: 'stripe_payment',
        paymentMethodId: paymentMethodId,
        feeAmount: amount * 0.029 + 0.30, // Frais Stripe standard
      );
      
      return transactionId;
    } catch (e) {
      print('Erreur paiement Stripe: $e');
      rethrow;
    }
  }
  
  /// Ajouter des fonds (pour revenus Creator Fund, sponsorships, etc.)
  static Future<String> addFunds({
    required String userId,
    required double amount,
    required String description,
    String? referenceId,
    String? referenceType,
  }) async {
    return createTransaction(
      userId: userId,
      type: TransactionType.credit,
      amount: amount,
      description: description,
      referenceId: referenceId,
      referenceType: referenceType,
    );
  }
  
  /// Retirer des fonds
  static Future<String> withdrawFunds({
    required String userId,
    required double amount,
    required String description,
    String? paymentMethodId,
  }) async {
    final wallet = await getUserWallet(userId);
    if (wallet == null) throw Exception('Wallet non trouvé');
    
    if (wallet.balance < amount) {
      throw Exception('Solde insuffisant');
    }
    
    return createTransaction(
      userId: userId,
      type: TransactionType.debit,
      amount: amount,
      description: description,
      paymentMethodId: paymentMethodId,
      feeAmount: 2.50, // Frais de retrait
    );
  }
  
  /// Obtenir l'historique des transactions filtré
  static Future<List<WalletTransaction>> getTransactionsByType(
    String userId, 
    TransactionType type, {
    int limit = 20,
  }) async {
    try {
      final result = await Supabase.instance.client
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .eq('transaction_type', type.toString())
          .order('created_at', descending: true)
          .limit(limit);
      
      return result.map((json) => WalletTransaction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur transactions par type: $e');
      return [];
    }
  }
  
  /// Obtenir les statistiques du wallet
  static Future<WalletStats> getWalletStats(String userId) async {
    try {
      final wallet = await getUserWallet(userId);
      if (wallet == null) throw Exception('Wallet non trouvé');
      
      // Obtenir les transactions des 30 derniers jours
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final result = await Supabase.instance.client
          .from('wallet_transactions')
          .select()
          .eq('user_id', userId)
          .gte('created_at', thirtyDaysAgo.toIso8601String());
      
      final transactions = result.map((json) => WalletTransaction.fromJson(json)).toList();
      
      double monthlyIncome = 0.0;
      double monthlyExpense = 0.0;
      int transactionCount = transactions.length;
      
      for (final transaction in transactions) {
        if (transaction.type == TransactionType.credit || transaction.type == TransactionType.refund) {
          monthlyIncome += transaction.netAmount;
        } else {
          monthlyExpense += transaction.netAmount;
        }
      }
      
      return WalletStats(
        currentBalance: wallet.balance,
        totalEarned: wallet.totalEarned,
        totalSpent: wallet.totalSpent,
        monthlyIncome: monthlyIncome,
        monthlyExpense: monthlyExpense,
        transactionCount: transactionCount,
        lastTransactionAt: wallet.lastTransactionAt,
      );
    } catch (e) {
      print('Erreur statistiques wallet: $e');
      rethrow;
    }
  }
  
  /// Nettoyer le cache
  static Future<void> clearCache() async {
    _wallets.clear();
    _paymentMethods.clear();
    _transactions.clear();
  }
  
  /// Synchroniser les données depuis le serveur
  static Future<void> syncFromServer(String userId) async {
    try {
      await Future.wait([
        getUserWallet(userId),
        getPaymentMethods(userId),
        getTransactions(userId),
      ]);
    } catch (e) {
      print('Erreur synchronisation serveur: $e');
    }
  }
}

/// Wallet utilisateur
class UserWallet {
  final String id;
  final String userId;
  double balance;
  final String currency;
  double totalEarned;
  double totalSpent;
  DateTime lastTransactionAt;
  DateTime createdAt;
  DateTime updatedAt;
  
  UserWallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.currency,
    required this.totalEarned,
    required this.totalSpent,
    required this.lastTransactionAt,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory UserWallet.fromJson(Map<String, dynamic> json) {
    return UserWallet(
      id: json['id'],
      userId: json['user_id'],
      balance: json['balance']?.toDouble() ?? 0.0,
      currency: json['currency'],
      totalEarned: json['total_earned']?.toDouble() ?? 0.0,
      totalSpent: json['total_spent']?.toDouble() ?? 0.0,
      lastTransactionAt: DateTime.parse(json['last_transaction_at']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'balance': balance,
      'currency': currency,
      'total_earned': totalEarned,
      'total_spent': totalSpent,
      'last_transaction_at': lastTransactionAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Méthode de paiement
class PaymentMethod {
  final String id;
  final String userId;
  final PaymentMethodType type;
  final String provider;
  final String methodToken;
  final String? lastFour;
  final int? expiryMonth;
  final int? expiryYear;
  final String? brand;
  bool isDefault;
  bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  PaymentMethod({
    required this.id,
    required this.userId,
    required this.type,
    required this.provider,
    required this.methodToken,
    this.lastFour,
    this.expiryMonth,
    this.expiryYear,
    this.brand,
    required this.isDefault,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'],
      userId: json['user_id'],
      type: PaymentMethodType.values.firstWhere(
        (type) => type.toString() == 'PaymentMethodType.${json['method_type']}',
        orElse: () => PaymentMethodType.creditCard,
      ),
      provider: json['provider'],
      methodToken: json['method_token'],
      lastFour: json['last_four'],
      expiryMonth: json['expiry_month'],
      expiryYear: json['expiry_year'],
      brand: json['brand'],
      isDefault: json['is_default'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'method_type': type.toString(),
      'provider': provider,
      'method_token': methodToken,
      'last_four': lastFour,
      'expiry_month': expiryMonth,
      'expiry_year': expiryYear,
      'brand': brand,
      'is_default': isDefault,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Transaction du wallet
class WalletTransaction {
  final String id;
  final String userId;
  final TransactionType type;
  final double amount;
  final String currency;
  final String description;
  final String? referenceId;
  final String? referenceType;
  final TransactionStatus status;
  final String? paymentMethodId;
  final double feeAmount;
  final double netAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.description,
    this.referenceId,
    this.referenceType,
    required this.status,
    this.paymentMethodId,
    required this.feeAmount,
    required this.netAmount,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'],
      userId: json['user_id'],
      type: TransactionType.values.firstWhere(
        (type) => type.toString() == 'TransactionType.${json['transaction_type']}',
        orElse: () => TransactionType.credit,
      ),
      amount: json['amount']?.toDouble() ?? 0.0,
      currency: json['currency'],
      description: json['description'],
      referenceId: json['reference_id'],
      referenceType: json['reference_type'],
      status: TransactionStatus.values.firstWhere(
        (status) => status.toString() == 'TransactionStatus.${json['status']}',
        orElse: () => TransactionStatus.completed,
      ),
      paymentMethodId: json['payment_method_id'],
      feeAmount: json['fee_amount']?.toDouble() ?? 0.0,
      netAmount: json['net_amount']?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'transaction_type': type.toString(),
      'amount': amount,
      'currency': currency,
      'description': description,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'status': status.toString(),
      'payment_method_id': paymentMethodId,
      'fee_amount': feeAmount,
      'net_amount': netAmount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Types de transaction
enum TransactionType {
  credit,
  debit,
  refund,
  withdrawal,
}

/// Statuts de transaction
enum TransactionStatus {
  pending,
  completed,
  failed,
  cancelled,
}

/// Statistiques du wallet
class WalletStats {
  final double currentBalance;
  final double totalEarned;
  final double totalSpent;
  final double monthlyIncome;
  final double monthlyExpense;
  final int transactionCount;
  final DateTime lastTransactionAt;
  
  WalletStats({
    required this.currentBalance,
    required this.totalEarned,
    required this.totalSpent,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.transactionCount,
    required this.lastTransactionAt,
  });
}

/// Types de méthode de paiement
enum PaymentMethodType {
  creditCard,
  paypal,
  applePay,
  googlePay,
  crypto,
}
