import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Transcription et voix de Bobodo **par le cloud**, pour le web.
///
/// ## Pourquoi ce service existe
///
/// Sur téléphone, Bobodo utilise `speech_to_text` : la reconnaissance **native
/// de l'appareil**. Elle est gratuite, quasi instantanée, et s'adapte à l'accent
/// de son propriétaire. Rien ne la surpasse pour cet usage — on n'y touche pas.
///
/// Sur le web, la même API existe (mesuré le 04/09/2026 sur app.academiea.com :
/// reconnaissance et synthèse présentes, trois voix françaises) mais **seulement
/// dans Chrome et Edge** — jamais dans Firefox ni Brave — et les voix système y
/// sont nettement robotiques. Ce service comble les deux manques : il donne une
/// voix de qualité partout, et une transcription là où le navigateur n'en offre
/// aucune.
///
/// ## Ce qu'il ne fait pas
///
/// Il ne remplace pas le natif là où le natif fonctionne. Envoyer un audio au
/// cloud coûte une latence réseau et des crédits, quand l'appareil fait le même
/// travail gratuitement et instantanément. On ne s'en sert qu'en secours.
class BobodoVocalCloudService {
  BobodoVocalCloudService._();
  static final BobodoVocalCloudService instance = BobodoVocalCloudService._();

  static const String _fonction = 'bobodo-vocal';

  /// Transcrit [audio] et renvoie le texte, ou `null` si cela n'a pas abouti.
  ///
  /// Ne lance pas : un échec de transcription ne doit pas faire perdre sa
  /// question à l'étudiant. L'appelant décide quoi montrer.
  ///
  /// [mime] doit décrire le format réellement enregistré (`audio/webm` sur
  /// Chrome, `audio/mp4` sur Safari). Un format mal déclaré est refusé par le
  /// moteur, et l'erreur qu'il renvoie n'est pas parlante.
  Future<String?> transcrire(
    Uint8List audio, {
    String mime = 'audio/webm',
    String? modele,
  }) async {
    if (audio.isEmpty) return null;
    try {
      final reponse = await Supabase.instance.client.functions.invoke(
        _fonction,
        body: {
          'action': 'transcrire',
          'audio': base64Encode(audio),
          'mime': mime,
          if (modele != null && modele.isNotEmpty) 'model': modele,
        },
      );
      final data = reponse.data;
      if (data is Map && data['texte'] is String) {
        final texte = (data['texte'] as String).trim();
        if (texte.isNotEmpty) {
          debugPrint('[BOBODO_VOCAL] transcrit par ${data['modele']}');
          return texte;
        }
      }
      debugPrint('[BOBODO_VOCAL] transcription sans texte : $data');
      return null;
    } catch (e) {
      debugPrint('[BOBODO_VOCAL] transcription impossible : $e');
      return null;
    }
  }

  /// Fabrique l'audio de [texte] et renvoie ses octets, ou `null` en cas
  /// d'échec — l'appelant retombe alors sur la voix du système.
  ///
  /// [modele] et [voix] sont laissés ouverts : essayer un autre moteur ne doit
  /// pas demander un redéploiement. C'est la même règle que `whiteboard-tts`,
  /// dont le commentaire dit que « les deux produits doivent pouvoir diverger
  /// sans se gêner » — Bobodo est le troisième.
  Future<Uint8List?> parler(
    String texte, {
    String? modele,
    String? voix,
  }) async {
    final propre = texte.trim();
    if (propre.isEmpty) return null;
    try {
      final reponse = await Supabase.instance.client.functions.invoke(
        _fonction,
        body: {
          'action': 'parler',
          'texte': propre,
          if (modele != null && modele.isNotEmpty) 'model': modele,
          if (voix != null && voix.isNotEmpty) 'voice': voix,
        },
      );
      final data = reponse.data;
      if (data is Map && data['audio'] is String) {
        final octets = base64Decode(data['audio'] as String);
        if (octets.isNotEmpty) {
          debugPrint('[BOBODO_VOCAL] voix ${data['modele']} / ${data['voix']}');
          return octets;
        }
      }
      debugPrint('[BOBODO_VOCAL] voix sans audio : $data');
      return null;
    } catch (e) {
      debugPrint('[BOBODO_VOCAL] voix impossible : $e');
      return null;
    }
  }
}
