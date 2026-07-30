import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Actions de modération d'une séance live.
///
/// Toutes passent par l'Edge Function `livekit-moderate`, jamais directement
/// par le client : couper un micro ou retirer quelqu'un exige la clé secrète
/// LiveKit, qui ne doit jamais quitter le serveur. Le droit est revalidé à
/// chaque appel côté serveur — l'application ne fait qu'afficher les commandes.
///
/// Qui peut agir :
///   • administrateur (`admin` / `super_admin`) — sur n'importe quelle séance ;
///   • hôte — sur sa propre séance uniquement.
class AcademiaModerationService {
  AcademiaModerationService._();

  static Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw Exception('Vous devez être connecté pour modérer une séance.');
    }

    try {
      final response = await client.functions.invoke('livekit-moderate', body: body);
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Réponse de modération invalide.');
      }
      if (data['success'] != true) {
        throw Exception(data['error']?.toString() ?? 'Action refusée.');
      }
      return data;
    } on FunctionException catch (e) {
      // `invoke()` LÈVE dès que le statut n'est pas 2xx : tout contrôle
      // `if (response.status != 200)` serait du code mort (cf. audit 27/07/2026).
      // On traduit donc ici, à partir de `details`.
      debugPrint('[Moderation] FunctionException ${e.status}: ${e.details}');
      throw Exception(_messageFor(e));
    }
  }

  static String _messageFor(FunctionException e) {
    final details = e.details;
    String? serverError;
    if (details is Map && details['error'] != null) {
      serverError = details['error'].toString();
    } else if (details is String && details.isNotEmpty) {
      serverError = details;
    }
    if (e.status == 403) {
      return serverError ??
          'Action réservée à l\'hôte de la séance ou à un administrateur.';
    }
    if (e.status == 404) return serverError ?? 'Séance ou participant introuvable.';
    return serverError ?? 'La modération a échoué. Réessayez.';
  }

  /// Liste les participants réellement présents dans la salle LiveKit.
  /// Utile pour l'administrateur qui rejoint une séance en cours.
  static Future<List<Map<String, dynamic>>> listParticipants(String sessionId) async {
    final data = await _call({'session_id': sessionId, 'action': 'list'});
    final raw = data['participants'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Coupe le micro d'un participant (et sa caméra si [includeVideo]).
  ///
  /// Note LiveKit : le serveur peut couper une piste, mais le participant reste
  /// libre de se réactiver. Pour retirer durablement la parole, utiliser
  /// [revokePublish].
  static Future<void> mute(
    String sessionId,
    String identity, {
    bool includeVideo = false,
  }) =>
      _call({
        'session_id': sessionId,
        'action': 'mute',
        'target_identity': identity,
        'include_video': includeVideo,
      });

  static Future<void> unmute(String sessionId, String identity) => _call({
        'session_id': sessionId,
        'action': 'unmute',
        'target_identity': identity,
      });

  /// Suspend le droit de parole : le participant reste dans la séance mais ne
  /// peut plus publier tant que le droit n'est pas rendu.
  static Future<void> revokePublish(String sessionId, String identity) => _call({
        'session_id': sessionId,
        'action': 'revoke_publish',
        'target_identity': identity,
      });

  /// Rend la parole (« donner le micro »).
  static Future<void> grantPublish(String sessionId, String identity) => _call({
        'session_id': sessionId,
        'action': 'grant_publish',
        'target_identity': identity,
      });

  /// Retire un participant de la séance.
  static Future<void> remove(String sessionId, String identity) => _call({
        'session_id': sessionId,
        'action': 'remove',
        'target_identity': identity,
      });

  /// Arrête la séance pour tout le monde et la marque terminée.
  static Future<void> endSession(String sessionId) => _call({
        'session_id': sessionId,
        'action': 'end_session',
      });
}
