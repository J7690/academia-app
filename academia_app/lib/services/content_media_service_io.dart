import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Implémentation mobile/desktop de la médiathèque commerciale :
/// - téléchargement (enregistrement dans la galerie)
/// - partage / publication (WhatsApp, Facebook, etc.)
/// - upload manager/admin vers les buckets Supabase
///
/// Chaque accès commercial est journalisé côté serveur (traçabilité des
/// visuels partenaires) via `app_log_content_asset_access`.
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

  Future<String> _downloadToTemp(String url, String fileName) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    await _dio.download(url, path);
    return path;
  }

  /// Récupère la version FILIGRANÉE d'un média image via l'edge function
  /// `content-watermark` (filigrane appliqué côté serveur, non contournable).
  Future<String> _watermarkedTempPath(String assetId, String title) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) throw Exception('not_authenticated');
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${_fileNameFor(title, '.jpg')}';
    await _dio.download(
      '${SupabaseConfig.url}/functions/v1/content-watermark',
      path,
      data: {'asset_id': assetId, 'action': 'download'},
      options: Options(
        method: 'POST',
        responseType: ResponseType.bytes,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': SupabaseConfig.anonKey,
          'Content-Type': 'application/json',
        },
      ),
    );
    return path;
  }

  Future<void> _log(String assetId, String action) async {
    try {
      await Supabase.instance.client.rpc('app_log_content_asset_access',
          params: {'p_asset': assetId, 'p_action': action});
    } catch (_) {}
  }

  Future<String> _resolveFile({
    required String assetId,
    required String title,
    String? url,
    String? storagePath,
  }) async {
    if (storagePath != null && storagePath.isNotEmpty) {
      return _watermarkedTempPath(assetId, title);
    }
    if (url == null || url.isEmpty) throw Exception('no_source');
    final path = await _downloadToTemp(url, _fileNameFor(title, url));
    await _log(assetId, 'download');
    return path;
  }

  /// Télécharge le média (filigrané si privé) et l'enregistre dans la galerie.
  Future<bool> downloadToGallery({
    required String assetId,
    required String title,
    String? url,
    String? storagePath,
  }) async {
    final path = await _resolveFile(
        assetId: assetId, title: title, url: url, storagePath: storagePath);
    final result = await SaverGallery.saveFile(
      filePath: path,
      fileName: path.split('/').last,
      androidRelativePath: 'Download/Academia',
      skipIfExists: false,
    );
    return result.isSuccess;
  }

  /// Ouvre la feuille de partage native pour publier le média.
  Future<void> shareMedia({
    required String assetId,
    required String title,
    String? url,
    String? storagePath,
    String? description,
  }) async {
    final path = await _resolveFile(
        assetId: assetId, title: title, url: url, storagePath: storagePath);
    await Share.shareXFiles(
      [XFile(path)],
      text: description != null && description.isNotEmpty ? description : title,
    );
  }

  /// Upload public (bucket `marketing`) — vidéos/documents non filigranés.
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

  /// Upload privé (bucket `partner-media`) — images filigranées à la demande.
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
