import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service pour gérer les deep links et redirections email
class DeepLinkService {
  static const MethodChannel _channel = MethodChannel('com.academia.app/deeplink');
  static final DeepLinkService _instance = DeepLinkService._internal();
  
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  /// Vérifie si l'app a été ouverte depuis un deep link
  Future<String?> getInitialLink() async {
    try {
      if (Platform.isAndroid) {
        final String? link = await _channel.invokeMethod('getInitialLink');
        return link;
      }
    } catch (e) {
      debugPrint('DeepLinkService: Error getting initial link: $e');
    }
    return null;
  }

  /// Écoute les deep links lorsque l'app est déjà ouverte
  void listenForLinks(VoidCallback? onLinkReceived) {
    if (Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onLinkReceived' && onLinkReceived != null) {
          onLinkReceived();
        }
      });
    }
  }

  /// Traite un lien de confirmation email
  Future<bool> handleEmailConfirmationLink(String link) async {
    try {
      debugPrint('DeepLinkService: Processing email link: $link');
      
      final client = Supabase.instance.client;
      
      // Extraire le token du lien Supabase
      final uri = Uri.parse(link);
      final accessToken = uri.queryParameters['access_token'];
      final refreshToken = uri.queryParameters['refresh_token'];
      
      if (accessToken != null && refreshToken != null) {
        // Créer la session avec les tokens du lien
        await client.auth.setSession(accessToken, refreshToken);
        
        debugPrint('DeepLinkService: Session restored from email link');
        return true;
      }
    } catch (e) {
      debugPrint('DeepLinkService: Error processing email link: $e');
    }
    return false;
  }

  /// Génère un lien de réinitialisation de mot de passe
  static String generatePasswordResetLink(String email) {
    return 'https://dulcet-snickerdoodle-915a6b.netlify.app/auth/callback#access_token=...';
  }
}
