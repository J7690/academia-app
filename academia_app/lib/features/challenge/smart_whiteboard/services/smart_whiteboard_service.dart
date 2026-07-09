import 'package:supabase_flutter/supabase_flutter.dart';

/// Service pour la gestion des projets Smart Whiteboard
/// 
/// Responsabilités :
/// - createProject
/// - getProject
/// - updateProject
/// - listProjects
/// - deleteProject
class SmartWhiteboardService {
  final SupabaseClient _supabase;

  SmartWhiteboardService(this._supabase);

  /// Crée un nouveau projet Smart Whiteboard
  Future<Map<String, dynamic>> createProject({
    required String subject,
    required String rendererId,
    required String themeId,
    String narrationMode = 'none',
    Map<String, dynamic>? storyboardJson,
  }) async {
    print("DEBUG-D19-30: service.createProject RPC START");
    final response = await _supabase.rpc(
      'whiteboard_create_project',
      params: {
        'p_student_id': _supabase.auth.currentUser?.id,
        'p_subject': subject,
        'p_renderer_id': rendererId,
        'p_theme_id': themeId,
        'p_narration_mode': narrationMode,
        'p_storyboard_json': storyboardJson ?? {},
      },
    );
    print("DEBUG-D19-31: service.createProject response=$response runtimeType=${response.runtimeType} isNull=${response == null}");

    return response as Map<String, dynamic>;
  }

  /// Récupère un projet par son ID
  Future<Map<String, dynamic>> getProject(String projectId) async {
    print("DEBUG-D19-32: service.getProject RPC START projectId=$projectId");
    final response = await _supabase.rpc(
      'whiteboard_get_project',
      params: {
        'p_project_id': projectId,
      },
    );
    print("DEBUG-D19-33: service.getProject response=$response runtimeType=${response.runtimeType} isNull=${response == null}");

    return response as Map<String, dynamic>;
  }

  /// Met à jour un projet existant
  Future<Map<String, dynamic>> updateProject({
    required String projectId,
    String? subject,
    String? status,
    String? rendererId,
    String? themeId,
    String? narrationMode,
    Map<String, dynamic>? storyboardJson,
  }) async {
    print("DEBUG-D19-34: service.updateProject RPC START projectId=$projectId");
    final response = await _supabase.rpc(
      'whiteboard_update_project',
      params: {
        'p_project_id': projectId,
        'p_subject': subject,
        'p_status': status,
        'p_renderer_id': rendererId,
        'p_theme_id': themeId,
        'p_narration_mode': narrationMode,
        'p_storyboard_json': storyboardJson,
      },
    );
    print("DEBUG-D19-35: service.updateProject response=$response runtimeType=${response.runtimeType} isNull=${response == null}");

    return response as Map<String, dynamic>;
  }

  /// Liste les projets de l'utilisateur
  Future<Map<String, dynamic>> listProjects({String? status}) async {
    print("DEBUG-D19-36: service.listProjects RPC START status=$status");
    final response = await _supabase.rpc(
      'whiteboard_list_projects',
      params: {
        'p_status': status,
      },
    );
    print("DEBUG-D19-37: service.listProjects response=$response runtimeType=${response.runtimeType} isNull=${response == null}");

    return response as Map<String, dynamic>;
  }

  /// Supprime un projet
  Future<Map<String, dynamic>> deleteProject(String projectId) async {
    print("DEBUG-D19-38: service.deleteProject RPC START projectId=$projectId");
    final response = await _supabase.rpc(
      'whiteboard_delete_project',
      params: {
        'p_project_id': projectId,
      },
    );
    print("DEBUG-D19-39: service.deleteProject response=$response runtimeType=${response.runtimeType} isNull=${response == null}");

    return response as Map<String, dynamic>;
  }
}
