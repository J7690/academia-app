import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../features/admin/hero_studio_models.dart';
import '../utils/mime_type_helper.dart';

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

    // Logs structurés côté client pour suivre tous les appels Hero/TV
    // On ne logge pas le body complet pour éviter d'afficher des tokens.
    // Seuls le path et la présence de champs critiques sont loggés.
    // Exemple de log: "HeroRenderService._postWithUserJwt: POST /hero/studio/render"
    //                  "bodyKeys=[playlist_item_id, slot]".
    final bodyKeys = body.keys.toList(growable: false);
    // ignore: avoid_print
    print(
      'HeroRenderService._postWithUserJwt: POST $path bodyKeys=$bodyKeys',
    );

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
      // ignore: avoid_print
      print(
        'HeroRenderService._postWithUserJwt: ERROR status=${response.statusCode} body=${response.body}',
      );
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'];
          if (detail is Map && detail['message'] is String) {
            throw Exception(detail['message'] as String);
          }
        }
      } catch (_) {}
      throw Exception('Erreur Hero/TV Studio (${response.statusCode}).');
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

    // ignore: avoid_print
    print(
      'HeroRenderService.startRender: playlistItemId=$playlistItemId slot=$slot',
    );

    final result = await _postWithUserJwt(
      path: '/hero/studio/render',
      body: body,
    );

    if (result['success'] != true) {
      throw Exception(
        result['error']?.toString() ?? 'Erreur lors du rendu Hero Studio.',
      );
    }

    final render = HeroRender(
      id: result['render_id']?.toString() ?? '',
      playlistItemId: result['playlist_item_id']?.toString() ?? playlistItemId,
      status: result['status']?.toString() ?? 'done',
      renderUrl: result['render_url']?.toString(),
      thumbnailUrl: result['thumbnail_url']?.toString(),
      logs: null,
      createdAt: null,
      updatedAt: null,
    );

    // ignore: avoid_print
    print(
      'HeroRenderService.startRender: success renderId=${render.id} '
      'status=${render.status} url=${render.renderUrl} thumb=${render.thumbnailUrl}',
    );

    return render;
  }

  static Future<List<HeroPlaylistItem>> getPlaylist({
    required String slot,
  }) async {
    final client = Supabase.instance.client;
    // ignore: avoid_print
    print('HeroRenderService.getPlaylist: slot=$slot');

    final dynamic response = await client.rpc(
      'app_admin_get_hero_playlist',
      params: {
        'p_slot': slot,
      },
    );

    if (response is! Map<String, dynamic>) {
      // ignore: avoid_print
      print(
        'HeroRenderService.getPlaylist: invalid response type=' +
            response.runtimeType.toString(),
      );
      throw Exception('Réponse invalide pour app_admin_get_hero_playlist.');
    }
    if (response['success'] != true) {
      // ignore: avoid_print
      print(
        'HeroRenderService.getPlaylist: error=' +
            (response['error']?.toString() ?? 'unknown_error'),
      );
      throw Exception(
        response['error']?.toString() ??
            'Erreur lors du chargement de la playlist Hero.',
      );
    }

    final itemsRaw = response['items'];
    if (itemsRaw is! List) {
      // ignore: avoid_print
      print('HeroRenderService.getPlaylist: items=[]');
      return const <HeroPlaylistItem>[];
    }

    final items = itemsRaw
        .whereType<Map>()
        .map((e) => HeroPlaylistItem.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList(growable: false);

    // ignore: avoid_print
    print('HeroRenderService.getPlaylist: items=${items.length}');

    return items;
  }

  static Future<String?> uploadHeroMediaFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String folder = 'generic',
    String? playlistItemId,
    String? slot,
  }) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non authentifié.');
    }

    final sanitizedFileName =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final key = (playlistItemId != null && playlistItemId.trim().isNotEmpty)
        ? playlistItemId.trim()
        : ((slot != null && slot.trim().isNotEmpty)
            ? slot.trim()
            : 'generic');

    final storagePath =
        '${user.id}/hero-studio/$key/$folder/$sanitizedFileName';

    // ignore: avoid_print
    print(
      'HeroRenderService.uploadHeroMediaFile: bucket=landing-media path=$storagePath mimeType=$mimeType',
    );

    try {
      await client.storage.from('landing-media').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: MimeTypeHelper.normalize(mimeType),
              upsert: true,
            ),
          );
    } on StorageException catch (e) {
      final message = e.message.toLowerCase();
      final error = (e.error ?? '').toLowerCase();
      final statusCode = e.statusCode?.toString() ?? '';
      final isDuplicate = statusCode == '409' ||
          message.contains('already exists') ||
          error.contains('duplicate');

      if (!isDuplicate) {
        // ignore: avoid_print
        print('HeroRenderService.uploadHeroMediaFile: storage exception=$e');
        throw Exception(e.toString());
      }

      // ignore: avoid_print
      print(
        'HeroRenderService.uploadHeroMediaFile: file already exists, reusing $storagePath',
      );
    } catch (e) {
      // ignore: avoid_print
      print('HeroRenderService.uploadHeroMediaFile: exception=$e');
      throw Exception(e.toString());
    }

    final publicUrl =
        client.storage.from('landing-media').getPublicUrl(storagePath);

    // ignore: avoid_print
    print('HeroRenderService.uploadHeroMediaFile: success url=$publicUrl');

    return publicUrl;
  }

  static Future<String> upsertPlaylistItem({
    String? itemId,
    required String slot,
    required String mediaType,
    String? baseVideoUrl,
    String? baseImageUrl,
    String? title,
    String? subtitle,
    int? sortOrder,
    bool? isActive,
  }) async {
    final client = Supabase.instance.client;

    // ignore: avoid_print
    print(
      'HeroRenderService.upsertPlaylistItem: id=$itemId slot=$slot '
      'mediaType=$mediaType isActive=$isActive sortOrder=$sortOrder',
    );

    final dynamic response = await client.rpc(
      'app_admin_upsert_hero_playlist_item',
      params: {
        'p_item_id': itemId,
        'p_slot': slot,
        'p_media_type': mediaType,
        'p_base_video_url': baseVideoUrl,
        'p_base_image_url': baseImageUrl,
        'p_title': title,
        'p_subtitle': subtitle,
        'p_sort_order': sortOrder,
        'p_is_active': isActive,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Réponse invalide pour app_admin_upsert_hero_playlist_item.');
    }
    if (response['success'] != true) {
      throw Exception(
        response['error']?.toString() ??
            "Erreur lors de l'enregistrement de l'item Hero.",
      );
    }

    final id = response['playlist_item_id']?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('playlist_item_id manquant dans la réponse de upsert.');
    }

    // ignore: avoid_print
    print('HeroRenderService.upsertPlaylistItem: success id=$id');

    return id;
  }

  static Future<void> deactivatePlaylistItem(HeroPlaylistItem item) async {
    await upsertPlaylistItem(
      itemId: item.id,
      slot: item.slot,
      mediaType: item.mediaType,
      baseVideoUrl: item.baseVideoUrl,
      baseImageUrl: item.baseImageUrl,
      title: item.title,
      subtitle: item.subtitle,
      sortOrder: item.sortOrder,
      isActive: false,
    );
  }

  static Future<HeroPlaylistItem> getItemConfig(String playlistItemId) async {
    final client = Supabase.instance.client;
    // ignore: avoid_print
    print('HeroRenderService.getItemConfig: playlistItemId=$playlistItemId');

    final dynamic response = await client.rpc(
      'app_admin_get_hero_playlist_item_config',
      params: {
        'p_playlist_item_id': playlistItemId,
      },
    );

    if (response is! Map<String, dynamic>) {
      // ignore: avoid_print
      print(
        'HeroRenderService.getItemConfig: invalid response type=' +
            response.runtimeType.toString(),
      );
      throw Exception('Réponse invalide pour app_admin_get_hero_playlist_item_config.');
    }
    if (response['success'] != true) {
      // ignore: avoid_print
      print(
        'HeroRenderService.getItemConfig: error=' +
            (response['error']?.toString() ?? 'unknown_error'),
      );
      throw Exception(
        response['error']?.toString() ??
            'Erreur lors du chargement de la configuration Hero.',
      );
    }

    final itemRaw = response['item'];
    if (itemRaw is! Map<String, dynamic>) {
      // ignore: avoid_print
      print('HeroRenderService.getItemConfig: missing item field');
      throw Exception('Configuration Hero manquante pour cet item.');
    }

    final item = HeroPlaylistItem.fromJson(
      Map<String, dynamic>.from(itemRaw),
    );

    // ignore: avoid_print
    print(
      'HeroRenderService.getItemConfig: id=${item.id} slot=${item.slot} '
      'mediaType=${item.mediaType} hasOverlays=${item.overlays != null}',
    );

    return item;
  }

  static Future<void> saveOverlays({
    required String playlistItemId,
    required HeroOverlays overlays,
  }) async {
    final client = Supabase.instance.client;
    // ignore: avoid_print
    print(
      'HeroRenderService.saveOverlays: playlistItemId=$playlistItemId '
      'layers=${overlays.layers.length}',
    );

    final dynamic response = await client.rpc(
      'app_admin_upsert_hero_overlays',
      params: {
        'p_playlist_item_id': playlistItemId,
        'p_layers': overlays.toJson(),
      },
    );

    if (response is! Map<String, dynamic>) {
      // ignore: avoid_print
      print(
        'HeroRenderService.saveOverlays: invalid response type=' +
            response.runtimeType.toString(),
      );
      throw Exception('Réponse invalide pour app_admin_upsert_hero_overlays.');
    }
    if (response['success'] != true) {
      // ignore: avoid_print
      print(
        'HeroRenderService.saveOverlays: error=' +
            (response['error']?.toString() ?? 'unknown_error'),
      );
      throw Exception(
        response['error']?.toString() ??
            'Erreur lors de l\'enregistrement des overlays Hero.',
      );
    }

    // ignore: avoid_print
    print('HeroRenderService.saveOverlays: success');
  }

  static Future<List<HeroRender>> getHeroRenderHistory({
    required String playlistItemId,
  }) async {
    final client = Supabase.instance.client;

    // ignore: avoid_print
    print('HeroRenderService.getHeroRenderHistory: playlistItemId=$playlistItemId');

    final dynamic response = await client
        .from('app.hero_renders')
        .select()
        .eq('playlist_item_id', playlistItemId)
        .order('created_at', ascending: false)
        .limit(20);

    if (response is! List) {
      // ignore: avoid_print
      print('HeroRenderService.getHeroRenderHistory: empty or invalid response');
      return const <HeroRender>[];
    }

    final renders = response
        .whereType<Map>()
        .map((e) => HeroRender.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    // ignore: avoid_print
    print('HeroRenderService.getHeroRenderHistory: count=${renders.length}');

    return renders;
  }

  /// --- Studio TV (timeline + rendus) ---

  static Future<List<HeroTvOverlay>> getTvTimeline({
    required String playlistItemId,
  }) async {
    final client = Supabase.instance.client;
    // ignore: avoid_print
    print('HeroRenderService.getTvTimeline: playlistItemId=$playlistItemId');

    final dynamic response = await client.rpc(
      'app_admin_tv_get_timeline',
      params: {
        'p_playlist_item_id': playlistItemId,
      },
    );

    if (response is! Map<String, dynamic>) {
      // ignore: avoid_print
      print('HeroRenderService.getTvTimeline: invalid response type');
      return const <HeroTvOverlay>[];
    }
    if (response['success'] != true) {
      // ignore: avoid_print
      print(
        'HeroRenderService.getTvTimeline: error=' +
            (response['error']?.toString() ?? 'unknown_error'),
      );
      return const <HeroTvOverlay>[];
    }

    final overlaysRaw = response['overlays'];
    if (overlaysRaw is! List) {
      // ignore: avoid_print
      print('HeroRenderService.getTvTimeline: overlays=[]');
      return const <HeroTvOverlay>[];
    }

    final overlays = overlaysRaw
        .whereType<Map>()
        .map((e) => HeroTvOverlay.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    // ignore: avoid_print
    print('HeroRenderService.getTvTimeline: overlays=${overlays.length}');

    return overlays;
  }

  static Future<HeroTvOverlay> upsertTvOverlay({
    String? id,
    required String playlistItemId,
    required String overlayType,
    required Map<String, dynamic> config,
    required double startAtSeconds,
    required double endAtSeconds,
    int sortOrder = 0,
  }) async {
    final client = Supabase.instance.client;

    // ignore: avoid_print
    print(
      'HeroRenderService.upsertTvOverlay: id=$id playlistItemId=$playlistItemId '
      'type=$overlayType start=$startAtSeconds end=$endAtSeconds',
    );

    final dynamic response = await client.rpc(
      'app_admin_tv_upsert_overlay',
      params: {
        'p_id': id,
        'p_playlist_item_id': playlistItemId,
        'p_overlay_type': overlayType,
        'p_config': config,
        'p_start_at_seconds': startAtSeconds,
        'p_end_at_seconds': endAtSeconds,
        'p_sort_order': sortOrder,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Réponse invalide pour app_admin_tv_upsert_overlay.');
    }
    if (response['success'] != true) {
      throw Exception(
        response['error']?.toString() ??
            'Erreur lors de la sauvegarde de l\'overlay TV.',
      );
    }

    // On recharge la timeline complète pour récupérer la version à jour.
    final overlays = await getTvTimeline(playlistItemId: playlistItemId);
    final createdId = response['id']?.toString();
    if (createdId != null && createdId.isNotEmpty) {
      final found = overlays.where((o) => o.id == createdId).toList();
      if (found.isNotEmpty) {
        return found.first;
      }
    }

    // Fallback: on retourne simplement le premier overlay correspondant par type
    if (overlays.isNotEmpty) {
      return overlays.first;
    }

    throw Exception('Overlay TV non retrouvé après sauvegarde.');
  }

  static Future<void> deleteTvOverlay(String overlayId) async {
    final client = Supabase.instance.client;
    // ignore: avoid_print
    print('HeroRenderService.deleteTvOverlay: id=$overlayId');

    final dynamic response = await client.rpc(
      'app_admin_tv_delete_overlay',
      params: {
        'p_id': overlayId,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Réponse invalide pour app_admin_tv_delete_overlay.');
    }
    if (response['success'] != true) {
      throw Exception(
        response['error']?.toString() ??
            'Erreur lors de la suppression de l\'overlay TV.',
      );
    }
  }

  static Future<HeroTvRender> startTvRender({
    required String playlistItemId,
    String? slot,
    Map<String, dynamic>? meta,
  }) async {
    final body = <String, dynamic>{
      'playlist_item_id': playlistItemId,
    };
    if (slot != null && slot.trim().isNotEmpty) {
      body['slot'] = slot.trim();
    }
    if (meta != null && meta.isNotEmpty) {
      body['meta'] = meta;
    }

    // ignore: avoid_print
    print(
      'HeroRenderService.startTvRender: playlistItemId=$playlistItemId slot=$slot',
    );

    final result = await _postWithUserJwt(
      path: '/studio/tv/render',
      body: body,
    );

    if (result['success'] != true) {
      throw Exception(
        result['error']?.toString() ?? 'Erreur lors du rendu TV.',
      );
    }

    final tvRender = HeroTvRender.fromJson(result);

    // ignore: avoid_print
    print(
      'HeroRenderService.startTvRender: success renderId=${tvRender.id} '
      'status=${tvRender.status} url=${tvRender.renderUrl} '
      'thumb=${tvRender.thumbnailUrl}',
    );

    return tvRender;
  }

  static Future<List<HeroTvRender>> getTvRenderHistory({
    required String playlistItemId,
  }) async {
    final client = Supabase.instance.client;

    // On lit directement la table app.hero_renders_tv côté admin.
    // RLS ne laisse passer que les utilisateurs admin (role=admin).
    // ignore: avoid_print
    print('HeroRenderService.getTvRenderHistory: playlistItemId=$playlistItemId');

    final dynamic response = await client
        .from('app.hero_renders_tv')
        .select()
        .eq('playlist_item_id', playlistItemId)
        .order('created_at', ascending: false)
        .limit(20);

    if (response is! List) {
      return const <HeroTvRender>[];
    }

    final renders = response
        .whereType<Map>()
        .map((e) => HeroTvRender.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    // ignore: avoid_print
    print('HeroRenderService.getTvRenderHistory: count=${renders.length}');

    return renders;
  }
}
