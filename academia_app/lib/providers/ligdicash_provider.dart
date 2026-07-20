import 'package:flutter/foundation.dart';

import '../services/ligdicash_service.dart';

/// États du flow de paiement LigdiCash OTP.
enum LigdiCashState {
  idle,
  sendingOtp,
  waitingOtp,
  confirming,
  processing,
  success,
  error,
}

/// Provider pour gérer le flow de paiement LigdiCash OTP.
class LigdiCashProvider extends ChangeNotifier {
  final LigdiCashService _service = LigdiCashService.instance;

  LigdiCashState _state = LigdiCashState.idle;
  String? _error;
  String? _message;
  String? _receiptNumber;
  String? _transactionId;
  String? _resultOperator;
  bool _commissionCreated = false;
  double _commissionAmount = 0;
  String _mode = '';

  // Données du paiement en cours
  String _paymentType = '';
  String _paymentId = '';
  String _phoneNumber = '';
  String _selectedOperator = '';
  String? _ussdCode;
  String? _packCode;

  LigdiCashState get state => _state;
  String? get error => _error;
  String? get message => _message;
  String? get receiptNumber => _receiptNumber;
  String? get transactionId => _transactionId;
  String? get operatorName => _resultOperator;
  String get selectedOperator => _selectedOperator;
  bool get commissionCreated => _commissionCreated;
  double get commissionAmount => _commissionAmount;
  String get mode => _mode;
  String? get ussdCode => _ussdCode;
  bool get isLoading =>
      _state == LigdiCashState.sendingOtp || _state == LigdiCashState.confirming;

  /// Réinitialise l'état pour un nouveau paiement.
  void reset() {
    _state = LigdiCashState.idle;
    _error = null;
    _message = null;
    _receiptNumber = null;
    _transactionId = null;
    _resultOperator = null;
    _commissionCreated = false;
    _commissionAmount = 0;
    _mode = '';
    _paymentType = '';
    _paymentId = '';
    _phoneNumber = '';
    _selectedOperator = '';
    _ussdCode = null;
    _packCode = null;
    notifyListeners();
  }

  /// Étape 1 : Envoyer l'OTP au numéro de téléphone.
  Future<bool> initiatePayment({
    required String paymentType,
    required String paymentId,
    required String phoneNumber,
    String operator = '',
    double? amountOverride,
    String? idempotencyKey,
    String? packCode,
  }) async {
    _paymentType = paymentType;
    _paymentId = paymentId;
    _phoneNumber = phoneNumber;
    _selectedOperator = operator;
    _packCode = packCode;
    _state = LigdiCashState.sendingOtp;
    _error = null;
    _message = null;
    notifyListeners();

    final result = await _service.initiatePayment(
      paymentType: paymentType,
      paymentId: paymentId,
      phoneNumber: phoneNumber,
      operator: operator,
      amountOverride: amountOverride,
      idempotencyKey: idempotencyKey,
      packCode: packCode,
    );

    if (result['success'] == true) {
      _state = LigdiCashState.waitingOtp;
      _message = result['message']?.toString();
      _mode = result['mode']?.toString() ?? '';
      _ussdCode = result['ussd_code']?.toString();
      notifyListeners();
      return true;
    } else {
      _state = LigdiCashState.error;
      _error = _humanizeError(result['error']?.toString() ?? 'unknown');
      notifyListeners();
      return false;
    }
  }

  /// Étape 2 : Confirmer avec le code OTP saisi.
  Future<bool> confirmOtp(String otpCode) async {
    if (_paymentId.isEmpty || _phoneNumber.isEmpty) {
      _state = LigdiCashState.error;
      _error = 'Aucun paiement en cours. Recommencez.';
      notifyListeners();
      return false;
    }

    _state = LigdiCashState.confirming;
    _error = null;
    notifyListeners();

    final result = await _service.confirmOtp(
      paymentType: _paymentType,
      paymentId: _paymentId,
      otpCode: otpCode,
      phoneNumber: _phoneNumber,
    );

    if (result['success'] == true) {
      _state = LigdiCashState.success;
      _receiptNumber = result['receipt_number']?.toString();
      _transactionId = result['transaction_id']?.toString();
      _resultOperator = result['operator']?.toString();
      _commissionCreated = result['commission_created'] == true;
      _mode = result['mode']?.toString() ?? '';
      final rawCommission = result['commission_amount'];
      if (rawCommission is num) {
        _commissionAmount = rawCommission.toDouble();
      }
      notifyListeners();
      return true;
    } else if (result['status'] == 'pending' ||
        result['error'] == 'payment_pending') {
      // Le débit peut aboutir côté opérateur : le webhook finalisera. Ne PAS
      // re-soumettre (le serveur réutilise déjà la même facture — aucun double débit),
      // mais on informe l'utilisateur que le paiement est en cours.
      _state = LigdiCashState.processing;
      _message =
          'Paiement en cours de traitement. Vous serez crédité dès confirmation. Vous pouvez fermer cette fenêtre.';
      _error = null;
      notifyListeners();
      return false;
    } else {
      _state = LigdiCashState.error;
      _error = _humanizeError(result['error']?.toString() ?? 'unknown');
      notifyListeners();
      return false;
    }
  }

  /// Revenir à l'état OTP (pour retry après erreur).
  void retryOtp() {
    if (_paymentId.isNotEmpty) {
      _state = LigdiCashState.waitingOtp;
      _error = null;
      notifyListeners();
    }
  }

  String _humanizeError(String code) {
    switch (code) {
      case 'not_authenticated':
        return 'Vous devez être connecté pour effectuer un paiement.';
      case 'payment_not_found':
      case 'marketplace_payment_not_found':
        return 'Paiement introuvable. Veuillez réessayer.';
      case 'not_owner':
      case 'payment_not_found_or_not_owner':
        return 'Ce paiement ne vous appartient pas.';
      case 'invalid_payment_status':
        return 'Ce paiement ne peut plus être traité.';
      case 'invalid_phone_number':
        return 'Numéro de téléphone invalide. Format : 226XXXXXXXX.';
      case 'invalid_amount':
        return 'Montant invalide pour ce paiement.';
      case 'amount_below_minimum':
        return 'Le montant minimum est de 10 XOF.';
      case 'invalid_otp_code':
        return 'Code OTP incorrect. Vérifiez le SMS reçu.';
      case 'ligdicash_otp_failed':
        return 'Impossible d\'envoyer le code. Vérifiez votre numéro.';
      case 'ligdicash_payment_failed':
        return 'Le paiement a échoué. Vérifiez votre solde.';
      case 'payment_pending':
        return 'Paiement en cours de traitement. Vous serez crédité dès confirmation.';
      case 'amount_mismatch':
        return 'Le montant payé ne correspond pas au montant attendu. Opération bloquée par sécurité. Contactez le support.';
      case 'ligdicash_no_token':
      case 'ligdicash_not_configured':
        return 'Service de paiement momentanément indisponible. Réessayez plus tard.';
      case 'confirmation_rpc_failed':
      case 'confirmation_failed':
        return 'Erreur lors de la confirmation. Contactez le support.';
      case 'network_error':
        return 'Erreur réseau. Vérifiez votre connexion internet.';
      case 'missing_parameters':
        return 'Informations manquantes. Veuillez remplir tous les champs.';
      default:
        return 'Erreur : $code';
    }
  }
}
