import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstallReferrerService {
  static final InstallReferrerService _instance =
      InstallReferrerService._internal();
  static InstallReferrerService get instance => _instance;
  factory InstallReferrerService() => _instance;
  InstallReferrerService._internal();

  static const _prefKey = 'pending_referral_token_v2';
  static const _readKey = 'install_referrer_read_v2';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_readKey) == true) return;

      final details = await PlayInstallReferrer.installReferrer;
      final referrer = details.installReferrer;
      if (referrer == null || referrer.isEmpty) return;

      // Le referrer est soit le token brut (32 hex), soit une query string
      // "TOKEN&utm_source=..." selon le format du lien Play Store.
      String token = referrer;
      if (referrer.contains('referrer=')) {
        final parsed = Uri.parse('https://d.invalid?$referrer');
        token = parsed.queryParameters['referrer'] ?? referrer;
      }

      // Valider le format : 32 caracteres hexadecimaux
      if (!RegExp(r'^[0-9A-Fa-f]{32}$').hasMatch(token)) return;

      await prefs.setString(_prefKey, token.toUpperCase());
      await prefs.setBool(_readKey, true);
      debugPrint('InstallReferrer: token captured');
    } catch (e) {
      debugPrint('InstallReferrer: $e');
    }
  }

  Future<String?> consumeToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefKey);
    if (token != null) {
      await prefs.remove(_prefKey);
    }
    return token;
  }
}
