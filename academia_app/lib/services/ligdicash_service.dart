import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service pour communiquer avec les Edge Functions LigdiCash.
class LigdiCashService {
  LigdiCashService._();
  static final LigdiCashService instance = LigdiCashService._();

  final SupabaseClient _client = Supabase.instance.client;

  /// Initie un paiement OTP : envoie le code OTP au téléphone du client.
  /// [paymentType] : 'application', 'marketplace', 'subscription', 'td'
  /// [paymentId] : UUID du paiement dans la DB
  /// [phoneNumber] : numéro mobile money (ex: 22670123456)
  Future<Map<String, dynamic>> initiatePayment({
    required String paymentType,
    required String paymentId,
    required String phoneNumber,
  }) async {
    try {
      debugPrint('[LigdiCash] initiatePayment: type=$paymentType, id=$paymentId, phone=$phoneNumber');
      final response = await _client.functions.invoke(
        'ligdicash-initiate',
        body: {
          'payment_type': paymentType,
          'payment_id': paymentId,
          'phone_number': phoneNumber,
        },
      );

      final data = _parseResponse(response);
      debugPrint('[LigdiCash] initiatePayment response: $data');
      return data;
    } catch (e, st) {
      debugPrint('[LigdiCash] initiatePayment error: $e\n$st');
      return {'success': false, 'error': 'network_error', 'details': e.toString()};
    }
  }

  /// Confirme le paiement avec le code OTP saisi par l'utilisateur.
  Future<Map<String, dynamic>> confirmOtp({
    required String paymentType,
    required String paymentId,
    required String otpCode,
    required String phoneNumber,
  }) async {
    try {
      debugPrint('[LigdiCash] confirmOtp: type=$paymentType, id=$paymentId, otp=$otpCode');
      final response = await _client.functions.invoke(
        'ligdicash-confirm',
        body: {
          'payment_type': paymentType,
          'payment_id': paymentId,
          'otp_code': otpCode,
          'phone_number': phoneNumber,
        },
      );

      final data = _parseResponse(response);
      debugPrint('[LigdiCash] confirmOtp response: $data');
      return data;
    } catch (e, st) {
      debugPrint('[LigdiCash] confirmOtp error: $e\n$st');
      return {'success': false, 'error': 'network_error', 'details': e.toString()};
    }
  }

  Map<String, dynamic> _parseResponse(FunctionResponse response) {
    final rawData = response.data;
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is String) {
      try {
        final decoded = jsonDecode(rawData);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return {'success': false, 'error': 'invalid_response', 'raw': rawData?.toString()};
  }
}
