import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstallReferrerService {
  static final InstallReferrerService _instance = InstallReferrerService._internal();
  static InstallReferrerService get instance => _instance;
  factory InstallReferrerService() => _instance;
  InstallReferrerService._internal();

  bool _isInitialized = false;
  String? _resolvedRefCode;

  bool get isInitialized => _isInitialized;
  String? get resolvedRefCode => _resolvedRefCode;

  Future<void> initialize() async {
    try {
      // Si déjà résolu lors d'un lancement précédent, on ne rappelle pas l'API.
      final prefs = await SharedPreferences.getInstance();
      final cachedRefCode = prefs.getString('resolved_ref_code');

      if (cachedRefCode != null && cachedRefCode.isNotEmpty) {
        _resolvedRefCode = cachedRefCode;
        _isInitialized = true;
        return;
      }

      var token = prefs.getString('pending_install_referrer_token');
      if (token == null || token.isEmpty) {
        if (_isInitialized) return;

        final referrerDetails = await PlayInstallReferrer.installReferrer;
        final referrer = referrerDetails.installReferrer;

        // Format Play Store: soit le token brut, soit une query string
        // (ex: "referrer=TOKEN&utm_source=...") selon comment le lien a été construit.
        if (referrer != null && referrer.isNotEmpty) {
          token = referrer;
          if (referrer.contains('referrer=')) {
            final referrerUri = Uri.parse('https://dummy.invalid?$referrer');
            token = referrerUri.queryParameters['referrer'] ?? referrer;
          }
          if (token.isNotEmpty) {
            await prefs.setString('pending_install_referrer_token', token);
          }
        }
      }

      _isInitialized = true;
      if (token == null || token.isEmpty || Supabase.instance.client.auth.currentSession == null) {
        return;
      }

      if (await _resolveToken(token)) {
        await prefs.remove('pending_install_referrer_token');
      }
    } catch (e) {
      // Pas de Play Services (émulateur sans Play Store, iOS, etc.) : on ignore.
      print('[InstallReferrerService] Error: $e');
      _isInitialized = true;
    }
  }

  Future<bool> _resolveToken(String token) async {
    try {
      final client = Supabase.instance.client;

      final result = await client.rpc(
        'app_resolve_referral_token',
        params: {'p_token': token},
      );

      if (result is Map && result['success'] == true) {
        final refCode = result['ref_code']?.toString();

        if (refCode != null && refCode.isNotEmpty) {
          _resolvedRefCode = refCode;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('resolved_ref_code', refCode);

          print('[InstallReferrerService] Resolved ref_code: $refCode');
          return true;
        }
      }
    } catch (e) {
      print('[InstallReferrerService] Error resolving token: $e');
    }
    return false;
  }

  Future<void> clearResolvedRefCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('resolved_ref_code');
    _resolvedRefCode = null;
  }
}
