import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../features/admin/hero_studio_models.dart';

class HeroRenderService {
  HeroRenderService._();

  static Future<Map<String, dynamic>> _postWithUserJwt({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null) {
      throw Exception('Utilisateur non authentifié.');
    }

    final jwt = session.accessToken;
    if (jwt.isEmpty) {
      throw Exception('Jeton utilisateur invalide.');
    }

    final supabaseUrl = SupabaseConfig.url;
    final baseUri = Uri.parse(supabaseUrl);
    final backendBase = Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
    );

    final uri = backendBase.replace(path: path);

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 400) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'];
          if (detail is Map && detail['message'] is String) {
            throw Exception(detail['message'] as String);
          }
        }
      } catch (_) {}
      throw Exception('Erreur Hero Studio (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Réponse Hero Studio invalide.');
    }
    return decoded;
  }

  static Future<HeroRender> startRender({
    required String playlistItemId,
    String? slot,
  }) async {
    final body = <String, dynamic>{
      'playlist_item_id': playlistItemId,
    };
    if (slot != null && slot.trim().isNotEmpty) {
      body['slot'] = slot.trim();
    }

    final result = await _postWithUserJwt(
      path: '/hero/studio/render',
      body: body,
    );

    if (result['success'] != true) {
      throw Exception(
        result['error']?.toString() ?? 'Erreur lors du rendu Hero Studio.',
      );
    }

    return HeroRender(
      id: result['render_id']?.toString() ?? '',
      playlistItemId: result['playlist_item_id']?.toString() ?? playlistItemId,
      status: result['status']?.toString() ?? 'done',
      renderUrl: result['render_url']?.toString(),
      thumbnailUrl: result['thumbnail_url']?.toString(),
      logs: null,
      createdAt: null,
      updatedAt: null,
    );
  }

  static Future<List<HeroPlaylistItem>> getPlaylist({
    required String slot,
  }) async {
    final client = Supabase.instance.client;
    final dynamic response = await client.rpc(
      'app_admin_get_hero_playlist',
      params: {
        'p_slot': slot,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Réponse invalide pour app_admin_get_hero_playlist.');
    }
    if (response['success'] != true) {
      throw Exception(
        response['error']?.toString() ??
            'Erreur lors du chargement de la playlist Hero.',
      );
    }

    final itemsRaw = response['items'];
    if (itemsRaw is! List) {
      return const <HeroPlaylistItem>[];
    }

    return itemsRaw
        .whereType<Map>()
        .map((e) => HeroPlaylistItem.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList(growable: false);
  }

  static Future<HeroPlaylistItem> getItemConfig(String playlistItemId) async {
    final client = Supabase.instance.client;
    final dynamic response = await client.rpc(
      'app_admin_get_hero_playlist_item_config',
      params: {
        'p_playlist_item_id': playlistItemId,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Réponse invalide pour app_admin_get_hero_playlist_item_config.');
    }
    if (response['success'] != true) {
      throw Exception(
        response['error']?.toString() ??
            'Erreur lors du chargement de la configuration Hero.',
      );
    }

    final itemRaw = response['item'];
    if (itemRaw is! Map<String, dynamic>) {
      throw Exception('Configuration Hero manquante pour cet item.');
    }

    return HeroPlaylistItem.fromJson(
      Map<String, dynamic>.from(itemRaw),
    );
  }

  static Future<void> saveOverlays({
    required String playlistItemId,
    required HeroOverlays overlays,
  }) async {
    final client = Supabase.instance.client;
    final dynamic response = await client.rpc(
      'app_admin_upsert_hero_overlays',
      params: {
        'p_playlist_item_id': playlistItemId,
        'p_layers': overlays.toJson(),
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Réponse invalide pour app_admin_upsert_hero_overlays.');
    }
    if (response['success'] != true) {
      throw Exception(
        response['error']?.toString() ??
            'Erreur lors de l\'enregistrement des overlays Hero.',
      );
    }
  }
}
