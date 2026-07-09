import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service pour la gestion des narrations Smart Whiteboard
/// 
/// Responsabilités :
/// - uploadNarration
/// - deleteNarration
/// - getNarrationUrl
class SmartWhiteboardNarrationService {
  final SupabaseClient _supabase;
  static const String _bucketName = 'whiteboard-narrations';

  SmartWhiteboardNarrationService(this._supabase);

  /// Upload un fichier audio de narration
  /// 
  /// Retourne l'URL publique du fichier uploadé
  Future<String> uploadNarration({
    required String projectId,
    required File audioFile,
    required String fileName,
  }) async {
    final path = 'narrations/$projectId/$fileName';
    
    await _supabase.storage
        .from(_bucketName)
        .upload(
          path,
          audioFile,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true,
          ),
        );

    final publicUrl = _supabase.storage
        .from(_bucketName)
        .getPublicUrl(path);

    return publicUrl;
  }

  /// Supprime un fichier audio de narration
  Future<void> deleteNarration({
    required String projectId,
    required String fileName,
  }) async {
    final path = 'narrations/$projectId/$fileName';
    
    await _supabase.storage
        .from(_bucketName)
        .remove([path]);
  }

  /// Récupère l'URL publique d'un fichier audio de narration
  String getNarrationUrl({
    required String projectId,
    required String fileName,
  }) {
    final path = 'narrations/$projectId/$fileName';
    
    return _supabase.storage
        .from(_bucketName)
        .getPublicUrl(path);
  }
}
