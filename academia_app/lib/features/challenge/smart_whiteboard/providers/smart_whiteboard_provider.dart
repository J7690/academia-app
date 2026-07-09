import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/storyboard_models.dart';
import '../services/smart_whiteboard_service.dart';
import '../services/smart_whiteboard_render_service.dart';
import '../services/smart_whiteboard_narration_service.dart';

enum SmartWhiteboardState {
  idle,
  loading,
  bobodoGenerating,
  editing,
  narrating,
  previewing,
  rendering,
  done,
  error,
}

class SmartWhiteboardProvider extends ChangeNotifier {
  final SmartWhiteboardService _projectService;
  final SmartWhiteboardRenderService _renderService;
  // final SmartWhiteboardNarrationService _narrationService; // TODO: Use in future

  SmartWhiteboardState _state = SmartWhiteboardState.idle;
  String? _errorMessage;
  
  // Project data
  String? _currentProjectId;
  WhiteboardProject? _currentProject;
  Storyboard? _currentStoryboard;
  Narration? _currentNarration;
  ExportSettings? _exportSettings;
  List<dynamic> _projects = [];
  
  // Render data
  String? _currentRenderJobId;
  RenderJob? _currentRenderJob;
  String? _renderVideoUrl;

  SmartWhiteboardProvider({
    required SmartWhiteboardService projectService,
    required SmartWhiteboardRenderService renderService,
    required SmartWhiteboardNarrationService narrationService, // TODO: Use in future
  })  : _projectService = projectService,
        _renderService = renderService;

  // Getters
  SmartWhiteboardState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get currentProjectId => _currentProjectId;
  WhiteboardProject? get currentProject => _currentProject;
  Storyboard? get currentStoryboard => _currentStoryboard;
  Narration? get currentNarration => _currentNarration;
  ExportSettings? get exportSettings => _exportSettings;
  String? get currentRenderJobId => _currentRenderJobId;
  RenderJob? get currentRenderJob => _currentRenderJob;
  String? get renderVideoUrl => _renderVideoUrl;
  List<dynamic> get projects => _projects;

  // State management
  void _setState(SmartWhiteboardState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _setState(SmartWhiteboardState.error);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Creation methods
  Future<void> createProject({
    required String subject,
    required String rendererId,
    required String themeId,
    String narrationMode = 'none',
  }) async {
    _setState(SmartWhiteboardState.loading);
    _errorMessage = null;

    try {
      print("DEBUG-D19-01: createProject START subject=$subject rendererId=$rendererId themeId=$themeId narrationMode=$narrationMode");
      final result = await _projectService.createProject(
        subject: subject,
        rendererId: rendererId,
        themeId: themeId,
        narrationMode: narrationMode,
      );

      print("DEBUG-D19-02: createProject result=$result runtimeType=${result.runtimeType} isNull=${result == null}");
      print("DEBUG-D19-03: result['success']=${result['success']} runtimeType=${result['success']?.runtimeType}");
      print("DEBUG-D19-04: result['project_id']=${result['project_id']} runtimeType=${result['project_id']?.runtimeType} isNull=${result['project_id'] == null}");

      if (result['success'] == true) {
        _currentProjectId = result['project_id'] as String;
        final client2 = Supabase.instance.client;
        _currentProject = WhiteboardProject(
          id: _currentProjectId!,
          studentId: client2.auth.currentUser?.id ?? '',
          subject: subject,
          status: ProjectStatus.draft,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          rendererId: RendererId.values.firstWhere(
            (e) => e.name == rendererId,
            orElse: () => RendererId.scientific,
          ),
          themeId: ThemeId.values.firstWhere(
            (e) => e.name == themeId,
            orElse: () => ThemeId.scientific,
          ),
          narrationMode: NarrationMode.values.firstWhere(
            (e) => e.name == narrationMode,
            orElse: () => NarrationMode.none,
          ),
          storyboard: Storyboard(
            version: '1.0',
            createdAt: DateTime.now(),
            createdBy: client2.auth.currentUser?.id ?? '',
            subject: subject,
            renderer: RendererId.values.firstWhere(
              (e) => e.name == rendererId,
              orElse: () => RendererId.scientific,
            ),
            theme: ThemeId.values.firstWhere(
              (e) => e.name == themeId,
              orElse: () => ThemeId.scientific,
            ),
            narrationMode: NarrationMode.values.firstWhere(
              (e) => e.name == narrationMode,
              orElse: () => NarrationMode.none,
            ),
            exportSettings: ExportSettings.v1Default,
            scenes: const [],
          ),
        );
        print("DEBUG-D24-01: _currentProject BUILT subject=${_currentProject?.subject} rendererId=${_currentProject?.rendererId.name} themeId=${_currentProject?.themeId.name} narrationMode=${_currentProject?.narrationMode.name}");
        print("DEBUG-D19-05: createProject _currentProjectId=$_currentProjectId");
        _setState(SmartWhiteboardState.idle);
      } else {
        _setError(result['error'] as String? ?? 'Failed to create project');
      }
    } catch (e) {
      print("DEBUG ERROR: $e");
      _setError(e.toString());
    }
  }

  Future<void> generateStoryboard({
    String mode = 'simple_subject',
    String content = '',
  }) async {
    if (_currentProjectId == null) {
      _setError('No project selected');
      return;
    }

    _setState(SmartWhiteboardState.bobodoGenerating);
    _errorMessage = null;

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        _setError('Not authenticated');
        return;
      }

      final _payloadSubject = _currentProject?.subject ?? '';
      final _payloadRenderer = _currentProject?.rendererId.name ?? 'scientific';
      final _payloadTheme = _currentProject?.themeId.name ?? 'scientific';
      final _payloadNarration = _currentProject?.narrationMode.name ?? 'none';
      print("DEBUG-D24-02: generateStoryboard PAYLOAD subject=$_payloadSubject renderer=$_payloadRenderer theme=$_payloadTheme narration_mode=$_payloadNarration");
      print("DEBUG-D19-06: generateStoryboard invoke START mode=$mode subject=$_payloadSubject narration_mode=$_payloadNarration");
      final response = await client.functions.invoke(
        'whiteboard-generate-storyboard',
        body: {
          'mode': mode,
          'subject': _payloadSubject,
          'content': content,
          'renderer': _payloadRenderer,
          'theme': _payloadTheme,
          'narration_mode': _payloadNarration,
        },
      );

      print("DEBUG-D19-07: generateStoryboard response.status=${response.status} runtimeType=${response.status.runtimeType}");
      print("DEBUG-D19-08: generateStoryboard response.data=$response.data runtimeType=${response.data.runtimeType} isNull=${response.data == null}");

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        print("DEBUG-D19-09: generateStoryboard errorData=$errorData runtimeType=${errorData?.runtimeType} isNull=${errorData == null}");
        if (errorData?['error'] == 'insufficient_credits') {
          _setError('Crédits insuffisants. Il vous faut 15 crédits pour générer un Storyboard.');
        } else if (errorData?['error'] == 'invalid_json') {
          _setError('Erreur de génération: JSON invalide. Veuillez réessayer.');
        } else if (errorData?['error'] == 'invalid_storyboard') {
          _setError('Erreur de génération: Storyboard invalide. Veuillez réessayer.');
        } else {
          _setError(errorData?['error'] ?? 'Failed to generate storyboard');
        }
        return;
      }

      final data = response.data as Map<String, dynamic>;
      print("DEBUG-D19-10: generateStoryboard data=$data runtimeType=${data.runtimeType}");
      print("DEBUG-D19-11: data['storyboard_json']=${data['storyboard_json']} runtimeType=${data['storyboard_json']?.runtimeType} isNull=${data['storyboard_json'] == null}");

      final storyboardJson = data['storyboard_json'] as Map<String, dynamic>?;

      if (storyboardJson == null) {
        print("DEBUG-D19-12: generateStoryboard storyboardJson is null");
        _setError('Erreur: storyboard_json manquant dans la réponse');
        return;
      }

      print("DEBUG-D19-13: generateStoryboard storyboardJson=$storyboardJson runtimeType=${storyboardJson.runtimeType}");
      _currentStoryboard = Storyboard.fromJson(storyboardJson);
      print("DEBUG-D19-14: generateStoryboard _currentStoryboard=$_currentStoryboard runtimeType=${_currentStoryboard.runtimeType}");
      _setState(SmartWhiteboardState.editing);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Editing methods
  void addScene(Scene scene) {
    if (_currentStoryboard == null) return;
    
    final updatedScenes = List<Scene>.from(_currentStoryboard!.scenes);
    updatedScenes.add(scene);
    
    _currentStoryboard = Storyboard(
      version: _currentStoryboard!.version,
      createdAt: _currentStoryboard!.createdAt,
      createdBy: _currentStoryboard!.createdBy,
      subject: _currentStoryboard!.subject,
      renderer: _currentStoryboard!.renderer,
      theme: _currentStoryboard!.theme,
      narrationMode: _currentStoryboard!.narrationMode,
      exportSettings: _currentStoryboard!.exportSettings,
      scenes: updatedScenes,
    );
    
    notifyListeners();
  }

  void updateScene(Scene scene) {
    if (_currentStoryboard == null) return;
    
    final updatedScenes = _currentStoryboard!.scenes.map((s) {
      return s.id == scene.id ? scene : s;
    }).toList();
    
    _currentStoryboard = Storyboard(
      version: _currentStoryboard!.version,
      createdAt: _currentStoryboard!.createdAt,
      createdBy: _currentStoryboard!.createdBy,
      subject: _currentStoryboard!.subject,
      renderer: _currentStoryboard!.renderer,
      theme: _currentStoryboard!.theme,
      narrationMode: _currentStoryboard!.narrationMode,
      exportSettings: _currentStoryboard!.exportSettings,
      scenes: updatedScenes,
    );
    
    notifyListeners();
  }

  Future<void> updateStoryboard(Storyboard storyboard) async {
    if (_currentProjectId == null) {
      _setError('No project selected');
      return;
    }

    _setState(SmartWhiteboardState.loading);
    _errorMessage = null;

    try {
      print("DEBUG-D19-15: updateStoryboard START projectId=$_currentProjectId");
      final result = await _projectService.updateProject(
        projectId: _currentProjectId!,
        storyboardJson: storyboard.toJson(),
      );
      print("DEBUG-D19-16: updateStoryboard result=$result runtimeType=${result.runtimeType} isNull=${result == null}");

      if (result['success'] == true) {
        _currentStoryboard = storyboard;
        _setState(SmartWhiteboardState.editing);
      } else {
        _setError(result['error'] as String? ?? 'Failed to update storyboard');
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  void deleteScene(String sceneId) {
    if (_currentStoryboard == null) return;
    
    final updatedScenes = _currentStoryboard!.scenes
        .where((s) => s.id != sceneId)
        .toList();
    
    _currentStoryboard = Storyboard(
      version: _currentStoryboard!.version,
      createdAt: _currentStoryboard!.createdAt,
      createdBy: _currentStoryboard!.createdBy,
      subject: _currentStoryboard!.subject,
      renderer: _currentStoryboard!.renderer,
      theme: _currentStoryboard!.theme,
      narrationMode: _currentStoryboard!.narrationMode,
      exportSettings: _currentStoryboard!.exportSettings,
      scenes: updatedScenes,
    );
    
    notifyListeners();
  }

  void reorderScenes(List<String> sceneIds) {
    if (_currentStoryboard == null) return;
    
    final sceneMap = {for (var s in _currentStoryboard!.scenes) s.id: s};
    final updatedScenes = sceneIds.map((id) => sceneMap[id]).whereType<Scene>().toList();
    
    _currentStoryboard = Storyboard(
      version: _currentStoryboard!.version,
      createdAt: _currentStoryboard!.createdAt,
      createdBy: _currentStoryboard!.createdBy,
      subject: _currentStoryboard!.subject,
      renderer: _currentStoryboard!.renderer,
      theme: _currentStoryboard!.theme,
      narrationMode: _currentStoryboard!.narrationMode,
      exportSettings: _currentStoryboard!.exportSettings,
      scenes: updatedScenes,
    );
    
    notifyListeners();
  }

  void addBlock(String sceneId, Block block) {
    if (_currentStoryboard == null) return;
    
    final updatedScenes = _currentStoryboard!.scenes.map((s) {
      if (s.id == sceneId) {
        final updatedBlocks = List<Block>.from(s.blocks);
        updatedBlocks.add(block);
        return Scene(
          id: s.id,
          order: s.order,
          title: s.title,
          durationMs: s.durationMs,
          blocks: updatedBlocks,
        );
      }
      return s;
    }).toList();
    
    _currentStoryboard = Storyboard(
      version: _currentStoryboard!.version,
      createdAt: _currentStoryboard!.createdAt,
      createdBy: _currentStoryboard!.createdBy,
      subject: _currentStoryboard!.subject,
      renderer: _currentStoryboard!.renderer,
      theme: _currentStoryboard!.theme,
      narrationMode: _currentStoryboard!.narrationMode,
      exportSettings: _currentStoryboard!.exportSettings,
      scenes: updatedScenes,
    );
    
    notifyListeners();
  }

  void updateBlock(String sceneId, Block block) {
    if (_currentStoryboard == null) return;
    
    final updatedScenes = _currentStoryboard!.scenes.map((s) {
      if (s.id == sceneId) {
        final updatedBlocks = s.blocks.map((b) {
          return b.id == block.id ? block : b;
        }).toList();
        return Scene(
          id: s.id,
          order: s.order,
          title: s.title,
          durationMs: s.durationMs,
          blocks: updatedBlocks,
        );
      }
      return s;
    }).toList();
    
    _currentStoryboard = Storyboard(
      version: _currentStoryboard!.version,
      createdAt: _currentStoryboard!.createdAt,
      createdBy: _currentStoryboard!.createdBy,
      subject: _currentStoryboard!.subject,
      renderer: _currentStoryboard!.renderer,
      theme: _currentStoryboard!.theme,
      narrationMode: _currentStoryboard!.narrationMode,
      exportSettings: _currentStoryboard!.exportSettings,
      scenes: updatedScenes,
    );
    
    notifyListeners();
  }

  void deleteBlock(String sceneId, String blockId) {
    if (_currentStoryboard == null) return;
    
    final updatedScenes = _currentStoryboard!.scenes.map((s) {
      if (s.id == sceneId) {
        final updatedBlocks = s.blocks.where((b) => b.id != blockId).toList();
        return Scene(
          id: s.id,
          order: s.order,
          title: s.title,
          durationMs: s.durationMs,
          blocks: updatedBlocks,
        );
      }
      return s;
    }).toList();
    
    _currentStoryboard = Storyboard(
      version: _currentStoryboard!.version,
      createdAt: _currentStoryboard!.createdAt,
      createdBy: _currentStoryboard!.createdBy,
      subject: _currentStoryboard!.subject,
      renderer: _currentStoryboard!.renderer,
      theme: _currentStoryboard!.theme,
      narrationMode: _currentStoryboard!.narrationMode,
      exportSettings: _currentStoryboard!.exportSettings,
      scenes: updatedScenes,
    );
    
    notifyListeners();
  }

  // Narration methods
  Future<void> generateTTS(String text, String voice) async {
    _setState(SmartWhiteboardState.narrating);
    _errorMessage = null;

    try {
      // TODO: Call TTS Edge Function
      // For now, create a placeholder narration
      _currentNarration = Narration(
        mode: NarrationMode.tts,
        voice: voice,
        audioUrl: null,
      );
      
      _setState(SmartWhiteboardState.editing);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> recordNarration() async {
    _setState(SmartWhiteboardState.narrating);
    _errorMessage = null;

    try {
      // TODO: Implement audio recording
      // For now, create a placeholder narration
      _currentNarration = const Narration(
        mode: NarrationMode.userRecording,
        voice: null,
        audioUrl: null,
      );
      
      _setState(SmartWhiteboardState.editing);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Render methods
  Future<void> createRenderJob() async {
    if (_currentProjectId == null) {
      _setError('No project selected');
      return;
    }

    _setState(SmartWhiteboardState.loading);
    _errorMessage = null;

    try {
      print("DEBUG-D19-17: createRenderJob START projectId=$_currentProjectId");
      // First, update the project with the current storyboard
      if (_currentStoryboard != null) {
        await _projectService.updateProject(
          projectId: _currentProjectId!,
          storyboardJson: _currentStoryboard!.toJson(),
        );
      }

      final result = await _renderService.createRenderJob(_currentProjectId!);
      print("DEBUG-D19-18: createRenderJob result=$result runtimeType=${result.runtimeType} isNull=${result == null}");
      print("DEBUG-D19-19: result['render_id']=${result['render_id']} runtimeType=${result['render_id']?.runtimeType} isNull=${result['render_id'] == null}");

      if (result['success'] == true) {
        _currentRenderJobId = result['render_id'] as String;
        _setState(SmartWhiteboardState.rendering);
      } else {
        _setError(result['error'] as String? ?? 'Failed to create render job');
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> pollRenderJob() async {
    if (_currentRenderJobId == null) {
      _setError('No render job selected');
      return;
    }

    _setState(SmartWhiteboardState.rendering);
    _errorMessage = null;

    try {
      print("DEBUG-D19-20: pollRenderJob START renderJobId=$_currentRenderJobId");
      final result = await _renderService.waitForRenderCompletion(_currentRenderJobId!);
      print("DEBUG-D19-21: pollRenderJob result=$result runtimeType=${result.runtimeType} isNull=${result == null}");
      print("DEBUG-D19-22: result['render']=${result['render']} runtimeType=${result['render']?.runtimeType} isNull=${result['render'] == null}");
      final render = result['render'] as Map<String, dynamic>;
      print("DEBUG-D19-23: render['status']=${render['status']} runtimeType=${render['status']?.runtimeType}");
      final status = render['status'] as String;

      if (status == 'done') {
        _renderVideoUrl = render['video_url'] as String?;
        _setState(SmartWhiteboardState.done);
      } else if (status == 'failed') {
        _setError(render['error_message'] as String? ?? 'Render failed');
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Deletion methods
  Future<void> deleteProject(String projectId) async {
    _setState(SmartWhiteboardState.loading);
    _errorMessage = null;

    try {
      print("DEBUG-D19-24: deleteProject START projectId=$projectId");
      await _projectService.deleteProject(projectId);
      print("DEBUG-D19-25: deleteProject DONE");
      
      if (_currentProjectId == projectId) {
        _currentProjectId = null;
        _currentProject = null;
        _currentStoryboard = null;
        _currentNarration = null;
        _currentRenderJobId = null;
        _currentRenderJob = null;
        _renderVideoUrl = null;
      }
      
      _setState(SmartWhiteboardState.idle);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> loadProjects() async {
    _setState(SmartWhiteboardState.loading);
    _errorMessage = null;

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        _setError('Not authenticated');
        return;
      }

      print("DEBUG-D19-26: loadProjects rpc START userId=$userId");
      final response = await client.rpc('whiteboard_list_projects');
      print("DEBUG-D19-27: loadProjects response=$response runtimeType=${response.runtimeType} isNull=${response == null}");

      if (response != null) {
        print("DEBUG-D19-28: loadProjects BEFORE CAST response.runtimeType=${response.runtimeType}");
        _projects = response as List<dynamic>;
        print("DEBUG-D19-29: loadProjects AFTER CAST _projects=$_projects runtimeType=${_projects.runtimeType} length=${_projects.length}");
      } else {
        _projects = [];
      }

      _setState(SmartWhiteboardState.idle);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> cancelRenderJob() async {
    // Note: There's no RPC to cancel a render job
    // This is a placeholder for future implementation
    _currentRenderJobId = null;
    _currentRenderJob = null;
    _renderVideoUrl = null;
    _setState(SmartWhiteboardState.idle);
  }

  // Reset
  void reset() {
    _currentProjectId = null;
    _currentProject = null;
    _currentStoryboard = null;
    _currentNarration = null;
    _exportSettings = null;
    _currentRenderJobId = null;
    _currentRenderJob = null;
    _renderVideoUrl = null;
    _errorMessage = null;
    _setState(SmartWhiteboardState.idle);
  }
}
