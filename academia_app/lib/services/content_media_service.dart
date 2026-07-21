import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de gestion des médias de la médiathèque commerciale :
/// - téléchargement (enregistrement dans la galerie du téléphone)
/// - partage / publication (WhatsApp, Facebook, etc. via la feuille de partage)
/// - upload par le manager/admin vers le bucket public `marketing`
///
/// Chaque téléchargement/partage par un commercial est journalisé côté
/// serveur (traçabilité des visuels partenaires) via `app_log_content_asset_access`.
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

  Future<void> _log(String assetId, String action) async {
    try {
      await Supabase.instance.client.rpc('app_log_content_asset_access',
          params: {'p_asset': assetId, 'p_action': action});
    } catch (_) {}
  }

  /// Télécharge le média et l'enregistre dans la galerie du téléphone.
  /// Retourne true si l'enregistrement a réussi.
  Future<bool> downloadToGallery({
    required String assetId,
    required String url,
    required String title,
  }) async {
    final fileName = _fileNameFor(title, url);
    final path = await _downloadToTemp(url, fileName);
    final result = await SaverGallery.saveFile(
      filePath: path,
      fileName: fileName,
      androidRelativePath: 'Download/Academia',
      skipIfExists: false,
    );
    await _log(assetId, 'download');
    return result.isSuccess;
  }

  /// Ouvre la feuille de partage native pour publier le média
  /// (WhatsApp, Facebook, Instagram, etc.).
  Future<void> shareMedia({
    required String assetId,
    required String url,
    required String title,
    String? description,
  }) async {
    final fileName = _fileNameFor(title, url);
    final path = await _downloadToTemp(url, fileName);
    await _log(assetId, 'download');
    await Share.shareXFiles(
      [XFile(path)],
      text: description != null && description.isNotEmpty ? description : title,
    );
  }

  /// Upload d'un fichier (manager/admin) vers le bucket public `marketing`.
  /// Retourne l'URL publique, directement téléchargeable et partageable.
  Future<String> uploadToMarketing({
    required File file,
    required String originalName,
  }) async {
    final ext = _extFromUrl(originalName);
    final objectPath =
        'manager/${DateTime.now().millisecondsSinceEpoch}_'
        '${originalName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_')}$ext';
    final storage = Supabase.instance.client.storage.from('marketing');
    await storage.upload(objectPath, file,
        fileOptions: const FileOptions(upsert: true));
    return storage.getPublicUrl(objectPath);
  }
}
