import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Catégories d'erreurs reconnues par l'application.
enum AppErrorType {
  offline,
  timeout,
  serverDown,
  sessionExpired,
  permission,
  notFound,
  unknown,
}

/// Classificateur central d'erreurs.
///
/// Transforme n'importe quelle exception (Supabase, réseau, Edge Function…)
/// en un message français prédéfini, adapté à la situation réelle.
/// Ne montre JAMAIS l'exception brute à l'utilisateur.
class AppError {
  final AppErrorType type;
  final String message;
  final bool canRetry;

  const AppError._(this.type, this.message, {this.canRetry = true});

  static const _messages = <AppErrorType, String>{
    AppErrorType.offline:
        'Pas de connexion Internet. Vérifiez vos données mobiles ou le Wi-Fi, puis réessayez.',
    AppErrorType.timeout:
        'La connexion est trop lente. Réessayez dans un instant.',
    AppErrorType.serverDown:
        'Nos services sont momentanément indisponibles. Réessayez dans quelques minutes.',
    AppErrorType.sessionExpired:
        'Votre session a expiré. Veuillez vous reconnecter.',
    AppErrorType.permission:
        'Vous n\'avez pas accès à cette ressource.',
    AppErrorType.notFound:
        'Contenu introuvable ou supprimé.',
    AppErrorType.unknown:
        'Une erreur est survenue. Réessayez ou contactez le support.',
  };

  /// Classifie une exception en [AppError] avec message français.
  factory AppError.from(Object? error) {
    final type = _classify(error);
    return AppError._(
      type,
      _messages[type]!,
      canRetry: type != AppErrorType.permission &&
          type != AppErrorType.sessionExpired,
    );
  }

  /// Message français pour une exception quelconque (raccourci).
  static String messageFor(Object? error) => AppError.from(error).message;

  /// Vérifie la connectivité réelle de l'appareil (pour distinguer
  /// « pas de réseau » de « serveur en panne » au moment d'une erreur).
  static Future<bool> isDeviceOffline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  static AppErrorType _classify(Object? error) {
    if (error == null) return AppErrorType.unknown;

    // --- Erreurs réseau pures ---
    if (error is SocketException) return AppErrorType.offline;
    if (error is TimeoutException) return AppErrorType.timeout;

    // --- Erreurs Supabase typées ---
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (_looksOffline(msg)) return AppErrorType.offline;
      if (msg.contains('jwt') ||
          msg.contains('expired') ||
          msg.contains('refresh_token') ||
          msg.contains('session')) {
        return AppErrorType.sessionExpired;
      }
      return AppErrorType.permission;
    }

    if (error is PostgrestException) {
      final code = error.code ?? '';
      final status = int.tryParse(code) ?? 0;
      if (status >= 500) return AppErrorType.serverDown;
      if (status == 401 || status == 403 || code == '42501') {
        return AppErrorType.permission;
      }
      if (status == 404 || code == 'PGRST116') return AppErrorType.notFound;
      final msg = error.message.toLowerCase();
      if (_looksOffline(msg)) return AppErrorType.offline;
      return AppErrorType.unknown;
    }

    if (error is FunctionException) {
      final status = error.status;
      if (status >= 500) return AppErrorType.serverDown;
      if (status == 401 || status == 403) return AppErrorType.permission;
      if (status == 404) return AppErrorType.notFound;
      return AppErrorType.unknown;
    }

    if (error is StorageException) {
      final status = int.tryParse(error.statusCode ?? '') ?? 0;
      if (status >= 500) return AppErrorType.serverDown;
      if (status == 401 || status == 403) return AppErrorType.permission;
      if (status == 404) return AppErrorType.notFound;
      final msg = error.message.toLowerCase();
      if (_looksOffline(msg)) return AppErrorType.offline;
      return AppErrorType.unknown;
    }

    // --- Analyse texte (ClientException, erreurs wrappées, etc.) ---
    final text = error.toString().toLowerCase();
    if (_looksOffline(text)) return AppErrorType.offline;
    if (text.contains('timeout') || text.contains('timed out')) {
      return AppErrorType.timeout;
    }
    if (text.contains('jwt expired') || text.contains('invalid token')) {
      return AppErrorType.sessionExpired;
    }
    if (text.contains('503') ||
        text.contains('502') ||
        text.contains('500') ||
        text.contains('service unavailable') ||
        text.contains('internal server error')) {
      return AppErrorType.serverDown;
    }
    return AppErrorType.unknown;
  }

  static bool _looksOffline(String text) {
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('clientexception') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('connection closed') ||
        text.contains('network is unreachable') ||
        text.contains('no address associated') ||
        text.contains('connection failed') ||
        text.contains('errno = 7') ||
        text.contains('handshake');
  }
}
