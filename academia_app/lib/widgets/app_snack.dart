import 'package:flutter/material.dart';

import '../services/app_error_messages.dart';

/// Helper unique pour afficher des SnackBars cohérentes dans toute l'app.
///
/// Usage :
/// ```dart
/// } catch (e) {
///   AppSnack.error(context, e, onRetry: _load);
/// }
/// ```
class AppSnack {
  AppSnack._();

  /// Affiche un message d'erreur prédéfini (jamais l'exception brute).
  static void error(
    BuildContext context,
    Object? rawError, {
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;
    final appError = AppError.from(rawError);
    _show(
      context,
      message: appError.message,
      icon: _iconFor(appError.type),
      background: const Color(0xFFB91C1C),
      onRetry: appError.canRetry ? onRetry : null,
    );
  }

  /// Affiche un message de succès.
  static void success(BuildContext context, String message) {
    if (!context.mounted) return;
    _show(
      context,
      message: message,
      icon: Icons.check_circle_outline,
      background: const Color(0xFF15803D),
    );
  }

  /// Affiche un message d'information.
  static void info(BuildContext context, String message) {
    if (!context.mounted) return;
    _show(
      context,
      message: message,
      icon: Icons.info_outline,
      background: const Color(0xFF1D4ED8),
    );
  }

  static IconData _iconFor(AppErrorType type) {
    switch (type) {
      case AppErrorType.offline:
        return Icons.wifi_off_rounded;
      case AppErrorType.timeout:
        return Icons.hourglass_bottom_rounded;
      case AppErrorType.serverDown:
        return Icons.cloud_off_rounded;
      case AppErrorType.sessionExpired:
        return Icons.lock_clock_rounded;
      case AppErrorType.permission:
        return Icons.block_rounded;
      case AppErrorType.notFound:
        return Icons.search_off_rounded;
      case AppErrorType.unknown:
        return Icons.error_outline_rounded;
    }
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color background,
    VoidCallback? onRetry,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Réessayer',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}
