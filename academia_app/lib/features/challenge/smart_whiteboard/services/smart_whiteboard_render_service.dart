import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  /// Bucket public où le worker dépose les rendus.
  static const String _bucket = 'whiteboard-renders';

  /// Chemin CONVENU de l'aperçu court d'un rendu.
  ///
  /// Le worker publie les 15 premières secondes du cours, sonorisées, dès qu'elles
  /// sont filmées — soit vers 25-35 s après le clic, au lieu des ~115 s du rendu
  /// complet. L'étudiant commence donc à regarder son cours pendant qu'il se fabrique.
  ///
  /// Ce chemin est un CONTRAT partagé avec le serveur
  /// (`whiteboard_upload_renderer.preview_object_key`) : il ne doit pas changer d'un
  /// côté sans l'autre. Ce choix évite d'ajouter une colonne en base et de modifier
  /// `whiteboard_get_render_status`.
  static String _previewObjectKey(String renderId) =>
      'renders/$renderId/preview.mp4';

  /// URL publique de l'aperçu d'un rendu (existe ou non : voir [previewUrlIfReady]).
  String previewUrlFor(String renderId) => _supabase.storage
      .from(_bucket)
      .getPublicUrl(_previewObjectKey(renderId));

  /// Retourne l'URL de l'aperçu S'IL EST DÉJÀ DÉPOSÉ, sinon null.
  ///
  /// On sonde l'URL publique par un HEAD plutôt que d'appeler `list` : la lecture
  /// d'un bucket public ne passe pas par les policies RLS, la détection ne peut donc
  /// pas échouer pour une question de droits. C'est aussi une requête très légère,
  /// répétée toutes les deux secondes pendant le rendu.
  ///
  /// Toute erreur (réseau, timeout) renvoie null : l'aperçu est un confort, son
  /// absence ne doit jamais interrompre l'attente de la vidéo complète.
  Future<String?> previewUrlIfReady(String renderId) async {
    final url = previewUrlFor(renderId);
    try {
      final response = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200 ? url : null;
    } catch (e) {
      print('DEBUG-PREVIEW: previewUrlIfReady($renderId) a echoue: $e');
      return null;
    }
  }

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

  /// Commande une capsule ANIMÉE 3D pour ce projet.
  ///
  /// Le storyboard est le même que celui du tableau manuscrit : c'est la même
  /// génération par IA, donc le même coût en crédits. Seule la fabrication
  /// change. Le serveur du projet traduit puis enregistre la voix avant qu'une
  /// machine soit louée — d'où un travail qui naît `a_preparer` et non `queued`.
  Future<Map<String, dynamic>> createStudioJob(String projectId) async {
    final response = await _supabase.rpc(
      'studio_creer_travail_etudiant',
      params: {'p_project_id': projectId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// État d'une capsule 3D, avec une étape LISIBLE par l'étudiant.
  ///
  /// La RPC renvoie `etape` en clair (« Enregistrement de la voix »,
  /// « Fabrication des images ») : un écran d'attente qui n'affiche qu'une roue
  /// laisse l'étudiant sans repère, et c'est exactement le défaut relevé le
  /// 07/08 sur la chaîne du tableau.
  Future<Map<String, dynamic>> getStudioStatus(String jobId) async {
    final response = await _supabase.rpc(
      'studio_etat_travail',
      params: {'p_job_id': jobId},
    );
    if (response == null) return {'success': false, 'error': 'introuvable'};
    return Map<String, dynamic>.from(response as Map);
  }

  /// URL lisible d'une capsule 3D, signée avec le jeton de l'étudiant.
  ///
  /// Le bucket `studio-visuel` est privé — les capsules n'en sortent que par
  /// URL signée. Une politique de lecture autorise l'étudiant sur le seul
  /// objet du travail qu'il a commandé : il signe donc lui-même, et aucune clé
  /// de service ne descend dans l'application.
  Future<String?> urlCapsuleStudio(String cheminVideo) async {
    try {
      return await _supabase.storage
          .from('studio-visuel')
          .createSignedUrl(cheminVideo, 60 * 60 * 6);
    } catch (e) {
      debugPrint('[STUDIO] signature impossible pour $cheminVideo : $e');
      return null;
    }
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
  ///
  /// [onPreview] est appelé UNE FOIS, dès que l'aperçu court est disponible, bien
  /// avant la fin du rendu : l'appelant peut alors lancer la lecture immédiatement.
  /// L'intervalle est court (2 s) pour ne pas gaspiller l'avance gagnée par le serveur.
  Future<Map<String, dynamic>> waitForRenderCompletion(
    String renderId, {
    Duration timeout = const Duration(minutes: 5),
    Duration pollingInterval = const Duration(seconds: 2),
    void Function(String previewUrl)? onPreview,
  }) async {
    final startTime = DateTime.now();
    var previewAnnounced = false;

    while (true) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed > timeout) {
        throw TimeoutException('Render timeout after ${timeout.inMinutes} minutes', elapsed);
      }

      if (onPreview != null && !previewAnnounced) {
        final previewUrl = await previewUrlIfReady(renderId);
        if (previewUrl != null) {
          previewAnnounced = true;
          print('DEBUG-PREVIEW: apercu disponible apres ${elapsed.inSeconds}s -> $previewUrl');
          onPreview(previewUrl);
        }
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
