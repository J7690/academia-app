import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Implémentation WEB de la médiathèque commerciale (sans dart:io).
/// L'upload fonctionne (uploadBinary). Le partage utilise la feuille de
/// partage web via des octets en mémoire. L'enregistrement en galerie n'a
/// pas de sens sur le web : on déclenche un partage/téléchargement à la place.
class ContentMediaService {
  ContentMediaService._();
  static final ContentMediaService instance = ContentMediaService._();

  final Dio _dio = Dio();

  String _fileNameFor(String title, String url) {
    final safe = title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final ext = _extFromUrl(url);
    return 'academia_${safe.isEmpty ? "media" : safe}$ext';
  }

  String _extFromUrl(String url) {
    final clean = url.split('?').first;
    final dot = clean.lastIndexOf('.');
    if (dot != -1 && clean.length - dot <= 5) return clean.substring(dot);
    return '';
  }

  Future<void> _log(String assetId, String action) async {
    try {
      await Supabase.instance.client.rpc('app_log_content_asset_access',
          params: {'p_asset': assetId, 'p_action': action});
    } catch (_) {}
  }

  Future<Uint8List> _resolveBytes({
    required String assetId,
    String? url,
    String? storagePath,
  }) async {
    if (storagePath != null && storagePath.isNotEmpty) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('not_authenticated');
      final res = await _dio.post<List<int>>(
        '${SupabaseConfig.url}/functions/v1/content-watermark',
        data: {'asset_id': assetId, 'action': 'download'},
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'apikey': SupabaseConfig.anonKey,
            'Content-Type': 'application/json',
          },
        ),
      );
      return Uint8List.fromList(res.data ?? const []);
    }
    if (url == null || url.isEmpty) throw Exception('no_source');
    final res = await _dio.get<List<int>>(url,
        options: Options(responseType: ResponseType.bytes));
    await _log(assetId, 'download');
    return Uint8List.fromList(res.data ?? const []);
  }

  /// Sur le web : pas de galerie — on ouvre la feuille de partage.
  Future<bool> downloadToGallery({
    required String assetId,
    required String title,
    String? url,
    String? storagePath,
  }) async {
    await shareMedia(
        assetId: assetId, title: title, url: url, storagePath: storagePath);
    return true;
  }

  Future<void> shareMedia({
    required String assetId,
    required String title,
    String? url,
    String? storagePath,
    String? description,
  }) async {
    final bytes = await _resolveBytes(
        assetId: assetId, url: url, storagePath: storagePath);
    final name = _fileNameFor(title, url ?? '.jpg');
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: name, mimeType: 'application/octet-stream')],
      text: description != null && description.isNotEmpty ? description : title,
    );
  }

  Future<String> uploadToMarketing({
    required Uint8List bytes,
    required String originalName,
  }) async {
    final objectPath = _objectPath(originalName);
    final storage = Supabase.instance.client.storage.from('marketing');
    await storage.uploadBinary(objectPath, bytes,
        fileOptions: const FileOptions(upsert: true));
    return storage.getPublicUrl(objectPath);
  }

  Future<String> uploadToPartnerMedia({
    required Uint8List bytes,
    required String originalName,
  }) async {
    final objectPath = _objectPath(originalName);
    await Supabase.instance.client.storage.from('partner-media').uploadBinary(
        objectPath, bytes,
        fileOptions: const FileOptions(upsert: true));
    return objectPath;
  }

  String _objectPath(String originalName) {
    final ext = _extFromUrl(originalName);
    final safe = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    return 'manager/${DateTime.now().millisecondsSinceEpoch}_$safe$ext';
  }
}
