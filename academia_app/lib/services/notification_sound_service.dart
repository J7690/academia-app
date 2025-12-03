import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSoundService {
  NotificationSoundService._();

  static final NotificationSoundService instance = NotificationSoundService._();

  static const String _prefKeyEnabled = 'notification_sounds_enabled';

  bool _enabled = true;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKeyEnabled) ?? true;
    _initialized = true;
  }

  Future<bool> isEnabled() async {
    await _ensureInitialized();
    return _enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    await _ensureInitialized();
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, enabled);
  }

  Future<void> playIfEnabled() async {
    await _ensureInitialized();
    if (!_enabled) return;
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }
}
