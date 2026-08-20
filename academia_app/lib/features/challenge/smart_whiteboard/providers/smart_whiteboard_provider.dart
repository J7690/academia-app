import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../config/backend_hosts.dart';
import '../models/storyboard_models.dart';
import '../models/storyboard_fusion.dart';
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

  /// Le JSON du storyboard TEL QUE L'IA l'a produit.
  ///
  /// Il porte des champs que le modele Dart ignore -- `engine`, la narration
  /// par bloc, `emphasis`, `key_words`. Les reecrire avec `toJson()` seul les
  /// effacait, et le serveur retombait alors sur le moteur degrade. On le garde
  /// donc, et toute sauvegarde passe par `fusionnerStoryboard`.
  Map<String, dynamic>? _storyboardOrigine;

  /// `vision2` (tableau manuscrit) ou `studio` (animation 3D).
  ///
  /// Initialisé depuis `BackendHosts.whiteboardEngine` — et non écrit en dur —
  /// pour que `--dart-define=WHITEBOARD_ENGINE` reste le défaut de l'application
  /// tant que l'étudiant n'a rien choisi. Le choix de l'écran de saisie l'écrase
  /// ensuite, et c'est LUI qui part au serveur.
  String _typeProduction = BackendHosts.whiteboardEngine;

  /// Ce que l'étudiant a choisi dans l'écran de saisie.
  String get typeProduction => _typeProduction;
  bool get estAnimation3d => _typeProduction == 'studio';

  void choisirTypeProduction(String type) {
    if (type != _typeProduction) {
      _typeProduction = type;
      notifyListeners();
    }
  }

  /// Où en est la fabrication, en une phrase lisible par l'étudiant.
  ///
  /// Alimenté par `studio_etat_travail` pour l'animation 3D. Un écran d'attente
  /// qui n'affiche qu'une roue ne dit ni ce qui se passe, ni si c'est tombé en
  /// panne : c'est le défaut relevé le 07/08 sur la chaîne du tableau, et il ne
  /// sera pas reproduit ici.
  String? _etapeEnCours;
  String? get etapeEnCours => _etapeEnCours;
  RenderJob? _currentRenderJob;
  String? _renderVideoUrl;

  /// Aperçu court (15 s sonorisées) disponible bien avant la vidéo complète.
  /// Sert à faire patienter l'étudiant en lui montrant déjà son cours.
  String? _previewVideoUrl;

  SmartWhiteboardProvider({
    required SmartWhiteboardService projectService,
    required SmartWhiteboardRenderService renderService,
    required SmartWhiteboardNarrationService
        narrationService, // TODO: Use in future
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
  String? get previewVideoUrl => _previewVideoUrl;
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
      print(
          "DEBUG-D19-01: createProject START subject=$subject rendererId=$rendererId themeId=$themeId narrationMode=$narrationMode");
      final result = await _projectService.createProject(
        subject: subject,
        rendererId: rendererId,
        themeId: themeId,
        narrationMode: narrationMode,
      );

      print(
          "DEBUG-D19-02: createProject result=$result runtimeType=${result.runtimeType} isNull=${result == null}");
      print(
          "DEBUG-D19-03: result['success']=${result['success']} runtimeType=${result['success']?.runtimeType}");
      print(
          "DEBUG-D19-04: result['project_id']=${result['project_id']} runtimeType=${result['project_id']?.runtimeType} isNull=${result['project_id'] == null}");

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
        print(
            "DEBUG-D24-01: _currentProject BUILT subject=${_currentProject?.subject} rendererId=${_currentProject?.rendererId.name} themeId=${_currentProject?.themeId.name} narrationMode=${_currentProject?.narrationMode.name}");
        print(
            "DEBUG-D19-05: createProject _currentProjectId=$_currentProjectId");
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
      print(
          "DEBUG-D24-02: generateStoryboard PAYLOAD subject=$_payloadSubject renderer=$_payloadRenderer theme=$_payloadTheme narration_mode=$_payloadNarration");
      print(
          "DEBUG-D19-06: generateStoryboard invoke START mode=$mode subject=$_payloadSubject narration_mode=$_payloadNarration");
      final response = await client.functions.invoke(
        'whiteboard-generate-storyboard',
        body: {
          'mode': mode,
          'subject': _payloadSubject,
          'content': content,
          'renderer': _payloadRenderer,
          'theme': _payloadTheme,
          'narration_mode': _payloadNarration,
          // LE CHOIX DE L'ÉTUDIANT, PAS LA CONSTANTE DE COMPILATION.
          //
          // Défaut mesuré le 12/08/2026 : cette ligne envoyait
          // `BackendHosts.whiteboardEngine`, figé à `vision2` au build. Le
          // sélecteur « tableau manuscrit / animation 3D » de l'écran de saisie
          // remplissait bien `_typeProduction` (voir `choisirTypeProduction`),
          // mais cette valeur n'atteignait JAMAIS le serveur.
          //
          // Conséquence : un étudiant qui choisissait l'animation 3D recevait
          // un storyboard de TABLEAU. Le choix existait à l'écran et nulle part
          // ailleurs — c'est le symptôme exact qu'on cherchait à corriger côté
          // serveur, et il avait aussi sa cause ici.
          //
          // `BackendHosts.whiteboardEngine` reste le DÉFAUT : `_typeProduction`
          // est initialisé avec, et `--dart-define=WHITEBOARD_ENGINE` continue
          // donc de fonctionner tant que l'étudiant ne choisit rien.
          'engine': _typeProduction,
          'writing_style': BackendHosts.whiteboardWritingStyle,
        },
      );

      print(
          "DEBUG-D19-07: generateStoryboard response.status=${response.status} runtimeType=${response.status.runtimeType}");
      print(
          "DEBUG-D19-08: generateStoryboard response.data=$response.data runtimeType=${response.data.runtimeType} isNull=${response.data == null}");

      // NOTE : un statut d'erreur ne parvient JAMAIS ici. `functions.invoke` leve
      // une FunctionException des que le statut n'est pas 2xx (functions_client :
      // `if (isSuccessStatus) return ...; throw FunctionException(...)`). Toute la
      // traduction des erreurs se fait donc dans le `catch`, via _messageForError.

      final data = response.data as Map<String, dynamic>;
      print(
          "DEBUG-D19-10: generateStoryboard data=$data runtimeType=${data.runtimeType}");
      print(
          "DEBUG-D19-11: data['storyboard_json']=${data['storyboard_json']} runtimeType=${data['storyboard_json']?.runtimeType} isNull=${data['storyboard_json'] == null}");

      final storyboardJson = data['storyboard_json'] as Map<String, dynamic>?;

      if (storyboardJson == null) {
        print("DEBUG-D19-12: generateStoryboard storyboardJson is null");
        _setError('Erreur: storyboard_json manquant dans la réponse');
        return;
      }

      print(
          "DEBUG-D19-13: generateStoryboard storyboardJson=$storyboardJson runtimeType=${storyboardJson.runtimeType}");
      // On garde le JSON DE L'IA avant de le parser : le modèle Dart ignore
      // `engine`, la narration par bloc, `emphasis` et `key_words`, et une
      // sauvegarde ultérieure les effacerait — c'est ce qui faisait retomber
      // le serveur sur le moteur dégradé.
      _storyboardOrigine = storyboardJson;

      // LE PROJET QUI COMPTE EST CELUI QUE LE SERVEUR VIENT DE CRÉER.
      //
      // Deux projets naissent pour une seule génération : l'application en
      // crée un VIDE avant d'appeler l'IA, et l'Edge Function en crée un
      // SECOND qui porte le storyboard (index.ts:118, whiteboard_create_project).
      // Elle le renvoie dans `project_data.project_id` — et personne ne le
      // lisait. L'application continuait donc de désigner sa coquille vide.
      //
      // Mesure du 18/08 sur le téléphone, sujet « le pétrole » :
      //   17:50:55  projet créé par l'app       → 0 scène
      //   17:51:10  projet créé par le serveur  → 5 scènes, engine studio,
      //                                           0 correction
      // La génération était PARFAITE. Le rendu était demandé sur le premier,
      // d'où « storyboard sans scène » — un échec affiché à l'étudiant pour un
      // cours qui existait, à quinze secondes de là.
      //
      // Sans cet identifiant, rien de ce qui suit — rendu, aperçu, reprise —
      // ne désigne le bon cours.
      final projectData = data['project_data'];
      final idServeur = projectData is Map ? projectData['project_id'] : null;
      if (idServeur is String && idServeur.isNotEmpty) {
        _currentProjectId = idServeur;
      }

      // UNE CAPSULE 3D N'EST PAS UN STORYBOARD DE TABLEAU.
      //
      // Ses scènes portent des `gestes` — des verbes et des coordonnées — et
      // n'ont ni `blocks`, ni `export_settings`, ni `video_codec`. Or
      // `Storyboard.fromJson` transtype ces champs en NON-NULLABLE.
      //
      // Défaut mesuré sur le téléphone le 12/08/2026 : la génération
      // réussissait côté serveur — capsule valide, cinq scènes, aucune
      // correction — et l'application plantait à l'analyse avec
      // « type 'Null' is not a subtype of type 'String' in type cast ».
      // L'étudiant voyait un échec là où tout avait marché.
      //
      // On ne rend donc PAS le modèle tolérant à coups de casts nullables : on
      // n'analyse pas ce qui n'est pas fait pour l'être. `_storyboardOrigine`
      // garde le JSON complet, et `createRenderJob` sait déjà se passer de
      // `_currentStoryboard` (il ne met à jour le projet que s'il existe).
      final scenes = storyboardJson['scenes'];
      final estCapsule = scenes is List &&
          scenes.isNotEmpty &&
          scenes.first is Map &&
          (scenes.first as Map).containsKey('gestes');

      if (estCapsule) {
        _currentStoryboard = null;
        // On n'envoie PAS l'étudiant dans un éditeur qui n'aurait rien à
        // éditer : une capsule n'a pas de blocs de texte. On enchaîne
        // directement sur la fabrication, qui affiche l'attente.
        await createRenderJob();
        return;
      }

      _currentStoryboard = Storyboard.fromJson(storyboardJson);
      _setState(SmartWhiteboardState.editing);
    } on FunctionException catch (e) {
      print(
          "DEBUG-D19-09: generateStoryboard FunctionException status=${e.status} details=${e.details} runtimeType=${e.details.runtimeType}");
      _setError(_messageForError(e, 'Échec de la génération du storyboard.'));
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Traduit une erreur d'Edge Function en message lisible par l'étudiant.
  ///
  /// Les Edge Functions repondent un corps JSON `{ "error": "<code>", ... }`.
  /// `FunctionException.details` contient ce corps : deja decode en Map quand la
  /// reponse est annoncee en JSON, mais parfois une chaine brute. On gere les deux,
  /// sinon l'etudiant voit un vidage technique au lieu d'une explication.
  String _messageForError(FunctionException e, String fallback) {
    Map<String, dynamic>? body;
    final details = e.details;
    if (details is Map<String, dynamic>) {
      body = details;
    } else if (details is String && details.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(details);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {
        // Corps illisible : on retombe sur le message generique.
      }
    }

    final code = body?['error']?.toString();
    switch (code) {
      case 'insufficient_credits':
        final cost = body?['cost'] ?? 15;
        final balance = body?['balance'] ?? 0;
        return 'Crédits insuffisants : il vous faut $cost crédits (solde : $balance).';
      case 'not_authenticated':
        return 'Session expirée. Reconnectez-vous puis réessayez.';
      case 'llm_error':
        return "Le service de génération n'a pas répondu. Réessayez dans un instant.";
      case 'invalid_json':
      case 'invalid_storyboard':
        // Le detail technique est precieux pour le diagnostic mais illisible pour
        // l'etudiant : il part dans les logs, pas a l'ecran.
        print(
            "DEBUG-D19-09b: generateStoryboard $code detail=${body?['detail']}");
        return 'La génération a produit un cours inexploitable. Veuillez réessayer.';
      case 'internal_error':
        return "Une erreur interne est survenue. Vos crédits n'ont pas été débités si la génération a échoué.";
    }
    return code ?? fallback;
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
      print(
          "DEBUG-D19-15: updateStoryboard START projectId=$_currentProjectId");
      final result = await _projectService.updateProject(
        projectId: _currentProjectId!,
        storyboardJson:
            fusionnerStoryboard(_storyboardOrigine, storyboard.toJson()),
      );
      print(
          "DEBUG-D19-16: updateStoryboard result=$result runtimeType=${result.runtimeType} isNull=${result == null}");

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

    final updatedScenes =
        _currentStoryboard!.scenes.where((s) => s.id != sceneId).toList();

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
    final updatedScenes =
        sceneIds.map((id) => sceneMap[id]).whereType<Scene>().toList();

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
          storyboardJson: fusionnerStoryboard(
              _storyboardOrigine, _currentStoryboard!.toJson()),
        );
      }

      // LE BRANCHEMENT DES DEUX CHAINES.
      // Même projet, même storyboard, même narration : seule la fabrication
      // diffère. L'animation 3D passe par une file distincte, car elle exige
      // une machine à carte graphique — que le serveur ne loue qu'APRÈS avoir
      // traduit la capsule et enregistré la voix.
      final result = estAnimation3d
          ? await _renderService.createStudioJob(_currentProjectId!)
          : await _renderService.createRenderJob(_currentProjectId!);
      print(
          "DEBUG-D19-18: createRenderJob result=$result runtimeType=${result.runtimeType} isNull=${result == null}");
      print(
          "DEBUG-D19-19: result['render_id']=${result['render_id']} runtimeType=${result['render_id']?.runtimeType} isNull=${result['render_id'] == null}");

      if (result['success'] == true) {
        // LES DEUX FILES NE NOMMENT PAS LEUR IDENTIFIANT PAREIL :
        // `render_id` côté tableau, `job_id` côté animation. Un transtypage
        // direct sur l'un des deux plantait sur l'autre.
        final identifiant =
            (result['render_id'] ?? result['job_id'])?.toString();
        if (identifiant == null || identifiant.isEmpty) {
          _setError('La fabrication n\'a pas démarré : identifiant manquant.');
          return;
        }
        _currentRenderJobId = identifiant;
        _etapeEnCours =
            estAnimation3d ? 'Préparation du cours' : 'Écriture du tableau';
        _setState(SmartWhiteboardState.rendering);
      } else {
        _setError(result['error'] as String? ?? 'Failed to create render job');
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Suit une capsule 3D jusqu'à sa mise à disposition, ou jusqu'à l'échec.
  ///
  /// Renvoie `true` si la vidéo est prête. À chaque tour, `etapeEnCours` porte
  /// une phrase lisible — « Enregistrement de la voix », « Fabrication des
  /// images » — et un échec remplit `errorMessage` au lieu de laisser tourner
  /// une roue. C'est le défaut relevé le 07/08 sur l'autre chaîne, et il ne
  /// sera pas reproduit ici.
  ///
  /// Le délai est large à dessein : l'animation demande la location d'une
  /// machine, dont l'amorçage seul prend quelques minutes. Un délai trop court
  /// ferait abandonner l'étudiant AVANT que sa vidéo n'arrive — l'autre défaut
  /// mesuré le même jour.
  Future<bool> suivreCapsule3d({
    Duration limite = const Duration(minutes: 45),
    Duration intervalle = const Duration(seconds: 5),
  }) async {
    if (_currentRenderJobId == null) {
      _setError('Aucune capsule en cours.');
      return false;
    }
    final depart = DateTime.now();

    // Une coupure de réseau n'est pas un échec de fabrication. Sur un rendu de
    // 2 min 40 l'application interroge le serveur une trentaine de fois ; à
    // Bobo-Dioulasso, qu'un de ces appels échoue est ordinaire. On tolère donc
    // les incidents passagers — et on s'arrête quand ils cessent d'être
    // passagers, au lieu de laisser l'exception remonter et figer la roue.
    const echecsToleres = 5;
    var echecs = 0;

    while (true) {
      if (DateTime.now().difference(depart) > limite) {
        _setError('La fabrication dépasse le temps prévu. '
            'Ton cours reste enregistré : rouvre-le plus tard.');
        return false;
      }

      Map<String, dynamic> etat;
      try {
        etat = await _renderService.getStudioStatus(_currentRenderJobId!);
        echecs = 0;
      } catch (e) {
        // AUCUN try/catch N'EXISTAIT ICI, alors que `pollRenderJob` en a un.
        // Une seule PostgrestException figeait l'écran d'attente pour de bon :
        // l'exception sortait de la boucle, sortait de `_start()`, et l'étudiant
        // gardait un sablier devant une vidéo qui, elle, se fabriquait très bien.
        echecs++;
        debugPrint('[STUDIO] suivi interrompu ($echecs/$echecsToleres) : $e');
        if (echecs >= echecsToleres) {
          _setError('La connexion ne répond plus. '
              'Ton cours continue de se fabriquer : rouvre-le dans un moment.');
          return false;
        }
        await Future.delayed(intervalle);
        continue;
      }

      final statut = etat['statut']?.toString();

      // UN STATUT ABSENT N'EST PAS UN STATUT « EN COURS ».
      // `getStudioStatus` fabrique {success:false, error:'introuvable'} quand la
      // RPC ne renvoie aucune ligne — travail purgé, identifiant inconnu, ou
      // session rattachée à un autre compte. Sans ce test, `statut` valait null,
      // aucune branche ne se déclenchait, et l'étudiant attendait les 45 minutes
      // entières devant un travail qui n'existait pas. C'est exactement la forme
      // que ce dépôt traque : déduire « ça avance » d'une absence de nouvelle.
      if (statut == null || statut.isEmpty) {
        _setError(etat['error']?.toString() == 'introuvable'
            ? 'Ce cours est introuvable. Il a peut-être été supprimé.'
            : "La fabrication ne répond pas. Ton cours reste enregistré.");
        return false;
      }

      final etape = etat['etape']?.toString();
      if (etape != null && etape != _etapeEnCours) {
        _etapeEnCours = etape;
        notifyListeners();
      }

      if (statut == 'failed') {
        _setError(etat['erreur']?.toString() ??
            'La fabrication a échoué. Ton cours reste enregistré.');
        return false;
      }

      if (statut == 'preview_ready' || statut == 'approved') {
        final chemin = etat['chemin_video']?.toString();
        if (chemin == null || chemin.isEmpty) {
          _setError('La vidéo est annoncée prête mais introuvable.');
          return false;
        }
        final url = await _renderService.urlCapsuleStudio(chemin);
        if (url == null) {
          _setError('La vidéo est prête mais son accès a été refusé.');
          return false;
        }
        _renderVideoUrl = url;
        _etapeEnCours = null;
        _setState(SmartWhiteboardState.done);
        return true;
      }

      await Future.delayed(intervalle);
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
      print(
          "DEBUG-D19-20: pollRenderJob START renderJobId=$_currentRenderJobId");
      final result = await _renderService.waitForRenderCompletion(
        _currentRenderJobId!,
        onPreview: (previewUrl) {
          // Publié en cours de rendu : on notifie tout de suite pour que l'écran
          // lance la lecture, l'état reste `rendering` puisque la vidéo complète
          // n'est pas encore là.
          _previewVideoUrl = previewUrl;
          notifyListeners();
        },
      );
      print(
          "DEBUG-D19-21: pollRenderJob result=$result runtimeType=${result.runtimeType} isNull=${result == null}");
      print(
          "DEBUG-D19-22: result['render']=${result['render']} runtimeType=${result['render']?.runtimeType} isNull=${result['render'] == null}");
      final render = result['render'] as Map<String, dynamic>;
      print(
          "DEBUG-D19-23: render['status']=${render['status']} runtimeType=${render['status']?.runtimeType}");
      final status = render['status'] as String;

      if (status == 'done') {
        _renderVideoUrl = render['video_url'] as String?;
        _previewVideoUrl = null;
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
        _previewVideoUrl = null;
      }

      _setState(SmartWhiteboardState.idle);
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Recharge un projet et son storyboard depuis son ID.
  /// Utilisé quand l'utilisateur ouvre un projet depuis la liste.
  Future<void> loadProject(String projectId) async {
    _setState(SmartWhiteboardState.loading);
    _errorMessage = null;

    try {
      final result = await _projectService.getProject(projectId);
      if (result['success'] != true) {
        _setError(result['error'] as String? ?? 'Failed to load project');
        return;
      }

      final projectJson = result['project'] as Map<String, dynamic>?;
      if (projectJson == null) {
        _setError('Project payload missing');
        return;
      }

      _currentProjectId = projectJson['id'] as String? ?? projectId;

      final storyboardJson =
          projectJson['storyboard_json'] as Map<String, dynamic>?;
      if (storyboardJson == null || storyboardJson.isEmpty) {
        _setError('Project storyboard missing');
        return;
      }

      // MÊME PRÉCAUTION QU'À LA GÉNÉRATION, et elle est indispensable ici.
      // Quand l'étudiant ROUVRE un cours, le JSON vient de la base et porte
      // encore `engine`, la narration par bloc, `emphasis` et `key_words`.
      // Sans cette ligne, `_storyboardOrigine` resterait nul, la fusion
      // n'aurait rien à préserver, et le premier enregistrement effacerait le
      // moteur — exactement le défaut qu'on vient de corriger, revenu par la
      // porte de derrière.
      _storyboardOrigine = storyboardJson;

      // UNE CAPSULE 3D N'EST PAS ANALYSABLE, ET CE CHEMIN L'IGNORAIT.
      //
      // `generateStoryboard` sait depuis le 12/08 qu'une capsule n'a ni
      // `blocks` ni `export_settings`, et que `Storyboard.fromJson` transtype
      // ces champs en non-nullable (cf. le commentaire de cette méthode).
      // `loadProject` appelait pourtant le même `fromJson` : rouvrir un cours
      // 3D depuis « Mes cours » affichait à l'étudiant une erreur Dart brute,
      // « type 'Null' is not a subtype of type 'String' in type cast ».
      //
      // La correction a été portée à la génération et pas à la relecture — la
      // couche qu'on regarde, pas celle qui suit. C'est le défaut de famille de
      // ce dépôt, et il valait ici pour TOUTE capsule déjà fabriquée.
      final scenes = storyboardJson['scenes'];
      final estCapsule = scenes is List &&
          scenes.isNotEmpty &&
          scenes.first is Map &&
          (scenes.first as Map).containsKey('gestes');

      if (estCapsule) {
        // ON RESTAURE AUSSI LE TYPE DE PRODUCTION.
        // `_typeProduction` ne vivait qu'en mémoire, écrit par l'écran de
        // saisie. Après une relance de l'application il retombait à `vision2`,
        // et l'écran d'aperçu interrogeait alors la MAUVAISE file
        // (`whiteboard_renders` au lieu de `studio_etat_travail`) pour un cours
        // dont le JSON en base porte pourtant `engine: studio`.
        // La vérité est dans le storyboard, pas dans un drapeau volatil.
        _typeProduction = 'studio';
        _currentStoryboard = null;
        _currentProject = null;
        _setState(SmartWhiteboardState.rendering);
        return;
      }

      _currentStoryboard = Storyboard.fromJson(storyboardJson);
      _currentProject = WhiteboardProject.fromJson({
        ...projectJson,
        'storyboard': storyboardJson,
      });

      _setState(SmartWhiteboardState.editing);
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
      print(
          "DEBUG-D19-27: loadProjects response=$response runtimeType=${response.runtimeType} isNull=${response == null}");

      // La RPC renvoie soit une liste directement, soit un objet
      // { success: true, projects: [...] }. On gère les deux formes.
      if (response is List) {
        _projects = response;
      } else if (response is Map && response['projects'] is List) {
        _projects = response['projects'] as List<dynamic>;
      } else {
        _projects = [];
      }
      print("DEBUG-D19-29: loadProjects _projects length=${_projects.length}");

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
    _previewVideoUrl = null;
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
    _previewVideoUrl = null;
    _errorMessage = null;
    _setState(SmartWhiteboardState.idle);
  }
}
