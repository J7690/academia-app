import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service pour communiquer avec les Edge Functions LigdiCash.
class LigdiCashService {
  LigdiCashService._();
  static final LigdiCashService instance = LigdiCashService._();

  final SupabaseClient _client = Supabase.instance.client;

  /// Initie un paiement OTP : envoie le code OTP au téléphone du client.
  /// [paymentType] : 'application', 'marketplace', 'subscription', 'td'
  /// [paymentId] : UUID du paiement dans la DB
  /// [phoneNumber] : numéro mobile money (ex: 22670123456)
  /// [idempotencyKey] : UUID pour éviter les paiements en double
  Future<Map<String, dynamic>> initiatePayment({
    required String paymentType,
    required String paymentId,
    required String phoneNumber,
    String operator = '',
    double? amountOverride,
    String? idempotencyKey,
    String? packCode,
  }) async {
    try {
      debugPrint('[LigdiCash] initiatePayment: type=$paymentType, id=$paymentId, phone=$phoneNumber, override=$amountOverride, idempotency=$idempotencyKey');
      final body = <String, dynamic>{
        'payment_type': paymentType,
        'payment_id': paymentId,
        'phone_number': phoneNumber,
        'operator': operator,
      };
      if (packCode != null && packCode.isNotEmpty) {
        body['pack_code'] = packCode;
      }
      if (amountOverride != null && amountOverride > 0) {
        body['amount_override'] = amountOverride;
      }
      if (idempotencyKey == null || idempotencyKey.isEmpty) {
        // Générer un idempotency key UUID si non fourni
        idempotencyKey = const Uuid().v4();
        debugPrint('[LigdiCash] Generated idempotency key: $idempotencyKey');
      }
      body['idempotency_key'] = idempotencyKey;
      
      final response = await _client.functions.invoke(
        'ligdicash-initiate',
        body: body,
      );

      final data = _parseResponse(response);
      debugPrint('[LigdiCash] initiatePayment response: $data');
      return data;
    } on FunctionException catch (e) {
      debugPrint('[LigdiCash] initiatePayment FunctionException: status=${e.status} body=${e.details}');
      try {
        final body = e.details;
        if (body is Map) return Map<String, dynamic>.from(body);
        if (body is String) {
          final decoded = jsonDecode(body);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
      return {'success': false, 'error': 'ligdicash_error', 'details': e.details?.toString() ?? e.toString()};
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
    } on FunctionException catch (e) {
      debugPrint('[LigdiCash] confirmOtp FunctionException: status=${e.status} body=${e.details}');
      // Extract real error message from Edge Function response
      try {
        final body = e.details;
        if (body is Map) return Map<String, dynamic>.from(body);
        if (body is String) {
          final decoded = jsonDecode(body);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
      return {'success': false, 'error': 'ligdicash_error', 'details': e.details?.toString() ?? e.toString()};
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
