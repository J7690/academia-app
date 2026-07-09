import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/services/smart_whiteboard_narration_service.dart';

@GenerateMocks([
  SmartWhiteboardService,
  SmartWhiteboardRenderService,
  SmartWhiteboardNarrationService,
])
import 'smart_whiteboard_provider_test.mocks.dart';

void main() {
  late SmartWhiteboardProvider provider;
  late MockSmartWhiteboardService mockProjectService;
  late MockSmartWhiteboardRenderService mockRenderService;
  late MockSmartWhiteboardNarrationService mockNarrationService;

  setUp(() {
    mockProjectService = MockSmartWhiteboardService();
    mockRenderService = MockSmartWhiteboardRenderService();
    mockNarrationService = MockSmartWhiteboardNarrationService();
    provider = SmartWhiteboardProvider(
      projectService: mockProjectService,
      renderService: mockRenderService,
      narrationService: mockNarrationService,
    );
  });

  group('SmartWhiteboardProvider', () {
    test('initial state should be idle', () {
      expect(provider.state, SmartWhiteboardState.idle);
      expect(provider.errorMessage, null);
    });

    test('createProject should set loading then idle on success', () async {
      when(mockProjectService.createProject(
        subject: anyNamed('subject'),
        rendererId: anyNamed('rendererId'),
        themeId: anyNamed('themeId'),
        narrationMode: anyNamed('narrationMode'),
      )).thenAnswer((_) async => {
        'success': true,
        'project_id': 'test-project-id',
      });

      await provider.createProject(
        subject: 'Test Subject',
        rendererId: 'scientific',
        themeId: 'scientific',
      );

      expect(provider.state, SmartWhiteboardState.idle);
      expect(provider.currentProjectId, 'test-project-id');
    });

    test('createProject should set error on failure', () async {
      when(mockProjectService.createProject(
        subject: anyNamed('subject'),
        rendererId: anyNamed('rendererId'),
        themeId: anyNamed('themeId'),
        narrationMode: anyNamed('narrationMode'),
      )).thenAnswer((_) async => {
        'success': false,
        'error': 'Test error',
      });

      await provider.createProject(
        subject: 'Test Subject',
        rendererId: 'scientific',
        themeId: 'scientific',
      );

      expect(provider.state, SmartWhiteboardState.error);
      expect(provider.errorMessage, 'Test error');
    });

    test('generateStoryboard should set bobodoGenerating then editing', () async {
      provider._currentProjectId = 'test-project-id';

      await provider.generateStoryboard();

      expect(provider.state, SmartWhiteboardState.editing);
      expect(provider.currentStoryboard, isNotNull);
    });

    test('addScene should add scene to storyboard', () {
      provider._currentStoryboard = const Storyboard(
        version: '1.0',
        createdAt: '2024-01-01T00:00:00Z',
        createdBy: 'user-id',
        subject: 'Test',
        renderer: 'scientific',
        theme: 'scientific',
        narrationMode: 'none',
        exportSettings: ExportSettings.v1Default,
        scenes: [],
      );

      final scene = Scene(
        id: 'scene-1',
        order: 0,
        title: 'Test Scene',
        durationMs: 5000,
        blocks: [],
      );

      provider.addScene(scene);

      expect(provider.currentStoryboard!.scenes.length, 1);
      expect(provider.currentStoryboard!.scenes[0].id, 'scene-1');
    });

    test('deleteScene should remove scene from storyboard', () {
      final scene = Scene(
        id: 'scene-1',
        order: 0,
        title: 'Test Scene',
        durationMs: 5000,
        blocks: [],
      );

      provider._currentStoryboard = const Storyboard(
        version: '1.0',
        createdAt: '2024-01-01T00:00:00Z',
        createdBy: 'user-id',
        subject: 'Test',
        renderer: 'scientific',
        theme: 'scientific',
        narrationMode: 'none',
        exportSettings: ExportSettings.v1Default,
        scenes: [],
      );

      provider.addScene(scene);
      provider.deleteScene('scene-1');

      expect(provider.currentStoryboard!.scenes.length, 0);
    });

    test('createRenderJob should set loading then rendering on success', () async {
      provider._currentProjectId = 'test-project-id';

      when(mockProjectService.updateProject(
        projectId: anyNamed('projectId'),
        storyboardJson: anyNamed('storyboardJson'),
      )).thenAnswer((_) async => {
        'success': true,
        'project_id': 'test-project-id',
      });

      when(mockRenderService.createRenderJob(any)).thenAnswer((_) async => {
        'success': true,
        'render_id': 'test-render-id',
        'project_id': 'test-project-id',
      });

      await provider.createRenderJob();

      expect(provider.state, SmartWhiteboardState.rendering);
      expect(provider.currentRenderJobId, 'test-render-id');
    });

    test('pollRenderJob should set done on success', () async {
      provider._currentRenderJobId = 'test-render-id';

      when(mockRenderService.waitForRenderCompletion(any, timeout: anyNamed('timeout'), pollingInterval: anyNamed('pollingInterval')))
          .thenAnswer((_) async => {
        'success': true,
        'render': {
          'id': 'test-render-id',
          'status': 'done',
          'video_url': 'https://example.com/video.mp4',
        },
      });

      await provider.pollRenderJob();

      expect(provider.state, SmartWhiteboardState.done);
      expect(provider.renderVideoUrl, 'https://example.com/video.mp4');
    });

    test('pollRenderJob should set error on failure', () async {
      provider._currentRenderJobId = 'test-render-id';

      when(mockRenderService.waitForRenderCompletion(any, timeout: anyNamed('timeout'), pollingInterval: anyNamed('pollingInterval')))
          .thenAnswer((_) async => {
        'success': true,
        'render': {
          'id': 'test-render-id',
          'status': 'failed',
          'error_message': 'Render failed',
        },
      });

      await provider.pollRenderJob();

      expect(provider.state, SmartWhiteboardState.error);
      expect(provider.errorMessage, 'Render failed');
    });

    test('reset should clear all data', () {
      provider._currentProjectId = 'test-project-id';
      provider._currentRenderJobId = 'test-render-id';
      provider._errorMessage = 'Test error';
      provider._setState(SmartWhiteboardState.error);

      provider.reset();

      expect(provider.state, SmartWhiteboardState.idle);
      expect(provider.currentProjectId, null);
      expect(provider.currentRenderJobId, null);
      expect(provider.errorMessage, null);
    });

    test('updateStoryboard should call service and update storyboard', () async {
      provider._currentProjectId = 'test-project-id';

      when(mockProjectService.updateProject(
        projectId: anyNamed('projectId'),
        storyboardJson: anyNamed('storyboardJson'),
      )).thenAnswer((_) async => {
        'success': true,
        'project': {
          'id': 'test-project-id',
          'storyboard_json': {
            'version': '1.0',
            'created_at': '2024-01-01T00:00:00Z',
            'created_by': 'user-id',
            'subject': 'Test',
            'renderer': 'scientific',
            'theme': 'scientific',
            'narration_mode': 'none',
            'export_settings': ExportSettings.v1Default.toJson(),
            'scenes': [],
          },
        },
      });

      final storyboard = const Storyboard(
        version: '1.0',
        createdAt: '2024-01-01T00:00:00Z',
        createdBy: 'user-id',
        subject: 'Test',
        renderer: 'scientific',
        theme: 'scientific',
        narrationMode: 'none',
        exportSettings: ExportSettings.v1Default,
        scenes: [],
      );

      await provider.updateStoryboard(storyboard);

      expect(provider.state, SmartWhiteboardState.editing);
      expect(provider.currentStoryboard, isNotNull);
      verify(mockProjectService.updateProject(
        projectId: 'test-project-id',
        storyboardJson: anyNamed('storyboardJson'),
      )).called(1);
    });

    test('updateStoryboard should set error on failure', () async {
      provider._currentProjectId = 'test-project-id';

      when(mockProjectService.updateProject(
        projectId: anyNamed('projectId'),
        storyboardJson: anyNamed('storyboardJson'),
      )).thenAnswer((_) async => {
        'success': false,
        'error': 'Update failed',
      });

      final storyboard = const Storyboard(
        version: '1.0',
        createdAt: '2024-01-01T00:00:00Z',
        createdBy: 'user-id',
        subject: 'Test',
        renderer: 'scientific',
        theme: 'scientific',
        narrationMode: 'none',
        exportSettings: ExportSettings.v1Default,
        scenes: [],
      );

      await provider.updateStoryboard(storyboard);

      expect(provider.state, SmartWhiteboardState.error);
      expect(provider.errorMessage, 'Update failed');
    });
  });
}
