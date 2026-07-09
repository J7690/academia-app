import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service pour la gestion des jobs de rendu Smart Whiteboard
/// 
/// Responsabilités :
/// - createRenderJob
/// - getRenderStatus
/// - waitForRenderCompletion
/// - getRenderVideoUrl
class SmartWhiteboardRenderService {
  final SupabaseClient _supabase;

  SmartWhiteboardRenderService(this._supabase);

  /// Crée un nouveau job de rendu
  Future<Map<String, dynamic>> createRenderJob(String projectId) async {
    print("DEBUG-D19-40: renderService.createRenderJob RPC START projectId=$projectId");
    final response = await _supabase.rpc(
      'whiteboard_create_render_job',
      params: {
        'p_project_id': projectId,
      },
    );
    print("DEBUG-D19-41: renderService.createRenderJob response=$response runtimeType=${response.runtimeType} isNull=${response == null}");

    return response as Map<String, dynamic>;
  }

  /// Récupère le statut d'un job de rendu
  Future<Map<String, dynamic>> getRenderStatus(String renderId) async {
    print("DEBUG-D19-42: renderService.getRenderStatus RPC START renderId=$renderId");
    final response = await _supabase.rpc(
      'whiteboard_get_render_status',
      params: {
        'p_render_id': renderId,
      },
    );
    print("DEBUG-D19-43: renderService.getRenderStatus response=$response runtimeType=${response.runtimeType} isNull=${response == null}");

    return response as Map<String, dynamic>;
  }

  /// Attend la complétion d'un job de rendu avec polling
  /// 
  /// Retourne le statut final du job
  /// Timeout après 5 minutes
  Future<Map<String, dynamic>> waitForRenderCompletion(
    String renderId, {
    Duration timeout = const Duration(minutes: 5),
    Duration pollingInterval = const Duration(seconds: 5),
  }) async {
    final startTime = DateTime.now();
    
    while (true) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed > timeout) {
        throw TimeoutException('Render timeout after ${timeout.inMinutes} minutes', elapsed);
      }

      final status = await getRenderStatus(renderId);
      print("DEBUG-D19-44: renderService.waitForRenderCompletion status=$status runtimeType=${status.runtimeType} isNull=${status == null}");
      final render = status['render'] as Map<String, dynamic>;
      print("DEBUG-D19-45: renderService.waitForRenderCompletion render=$render runtimeType=${render.runtimeType} isNull=${render == null}");
      final renderStatus = render['status'] as String;
      print("DEBUG-D19-46: renderService.waitForRenderCompletion renderStatus=$renderStatus runtimeType=${renderStatus.runtimeType}");

      if (renderStatus == 'done' || renderStatus == 'failed') {
        return status;
      }

      await Future.delayed(pollingInterval);
    }
  }

  /// Récupère l'URL de la vidéo rendue
  /// 
  /// Retourne null si le rendu n'est pas terminé
  Future<String?> getRenderVideoUrl(String renderId) async {
    final status = await getRenderStatus(renderId);
    print("DEBUG-D19-47: renderService.getRenderVideoUrl status=$status runtimeType=${status.runtimeType} isNull=${status == null}");
    final render = status['render'] as Map<String, dynamic>;
    print("DEBUG-D19-48: renderService.getRenderVideoUrl render=$render runtimeType=${render.runtimeType} isNull=${render == null}");
    final renderStatus = render['status'] as String;
    print("DEBUG-D19-49: renderService.getRenderVideoUrl renderStatus=$renderStatus runtimeType=${renderStatus.runtimeType}");

    if (renderStatus != 'done') {
      return null;
    }

    final rawUrl = render['video_url'] as String?;
    print("DEBUG-D19-50: renderService.getRenderVideoUrl video_url=$rawUrl");
    return rawUrl;
  }
}
