import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to update the app icon badge count on Android launchers.
/// Uses ShortcutBadger via a native MethodChannel to support
/// Samsung, Xiaomi, Huawei, LG, Sony, HTC, and other launchers.
class AppBadgeService {
  AppBadgeService._();
  static final AppBadgeService instance = AppBadgeService._();

  static const _channel = MethodChannel('com.academia.app/badge');

  /// Update the badge count on the app icon.
  /// Pass 0 to remove the badge.
  Future<void> updateBadge(int count) async {
    try {
      if (count > 0) {
        await _channel.invokeMethod('updateBadge', {'count': count});
      } else {
        await _channel.invokeMethod('removeBadge');
      }
    } catch (e) {
      debugPrint('[AppBadgeService] Error updating badge: $e');
    }
  }

  /// Remove the badge from the app icon.
  Future<void> removeBadge() async {
    try {
      await _channel.invokeMethod('removeBadge');
    } catch (e) {
      debugPrint('[AppBadgeService] Error removing badge: $e');
    }
  }
}
