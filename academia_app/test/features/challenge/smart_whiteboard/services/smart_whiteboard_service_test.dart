import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart';

@GenerateMocks([SupabaseClient])
import 'smart_whiteboard_service_test.mocks.dart';

void main() {
  late SmartWhiteboardService service;
  late MockSupabaseClient mockSupabase;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    service = SmartWhiteboardService(mockSupabase);
  });

  group('SmartWhiteboardService', () {
    test('createProject should call whiteboard_create_project RPC', () async {
      when(mockSupabase.rpc(
        'whiteboard_create_project',
        params: anyNamed('params'),
      )).thenAnswer((_) async => {
        'success': true,
        'project_id': 'test-project-id',
      });

      final result = await service.createProject(
        subject: 'Test Subject',
        rendererId: 'scientific',
        themeId: 'scientific',
      );

      expect(result['success'], true);
      expect(result['project_id'], 'test-project-id');
      verify(mockSupabase.rpc(
        'whiteboard_create_project',
        params: {
          'p_subject': 'Test Subject',
          'p_renderer_id': 'scientific',
          'p_theme_id': 'scientific',
          'p_narration_mode': 'none',
          'p_storyboard_json': {},
        },
      )).called(1);
    });

    test('getProject should call whiteboard_get_project RPC', () async {
      when(mockSupabase.rpc(
        'whiteboard_get_project',
        params: anyNamed('params'),
      )).thenAnswer((_) async => {
        'success': true,
        'project': {
          'id': 'test-project-id',
          'subject': 'Test Subject',
        },
      });

      final result = await service.getProject('test-project-id');

      expect(result['success'], true);
      verify(mockSupabase.rpc(
        'whiteboard_get_project',
        params: {
          'p_project_id': 'test-project-id',
        },
      )).called(1);
    });

    test('updateProject should call whiteboard_update_project RPC', () async {
      when(mockSupabase.rpc(
        'whiteboard_update_project',
        params: anyNamed('params'),
      )).thenAnswer((_) async => {
        'success': true,
        'project_id': 'test-project-id',
      });

      final result = await service.updateProject(
        projectId: 'test-project-id',
        subject: 'Updated Subject',
      );

      expect(result['success'], true);
      verify(mockSupabase.rpc(
        'whiteboard_update_project',
        params: anyNamed('params'),
      )).called(1);
    });

    test('listProjects should call whiteboard_list_projects RPC', () async {
      when(mockSupabase.rpc(
        'whiteboard_list_projects',
        params: anyNamed('params'),
      )).thenAnswer((_) async => {
        'success': true,
        'projects': [],
      });

      final result = await service.listProjects();

      expect(result['success'], true);
      verify(mockSupabase.rpc(
        'whiteboard_list_projects',
        params: anyNamed('params'),
      )).called(1);
    });

    test('deleteProject should call whiteboard_delete_project RPC', () async {
      when(mockSupabase.rpc(
        'whiteboard_delete_project',
        params: anyNamed('params'),
      )).thenAnswer((_) async => {
        'success': true,
        'project_id': 'test-project-id',
      });

      final result = await service.deleteProject('test-project-id');

      expect(result['success'], true);
      verify(mockSupabase.rpc(
        'whiteboard_delete_project',
        params: {
          'p_project_id': 'test-project-id',
        },
      )).called(1);
    });
  });
}
