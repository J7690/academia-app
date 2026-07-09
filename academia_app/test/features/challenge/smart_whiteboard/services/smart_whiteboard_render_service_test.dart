import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart';

@GenerateMocks([SupabaseClient])
import 'smart_whiteboard_render_service_test.mocks.dart';

void main() {
  late SmartWhiteboardRenderService service;
  late MockSupabaseClient mockSupabase;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    service = SmartWhiteboardRenderService(mockSupabase);
  });

  group('SmartWhiteboardRenderService', () {
    test('createRenderJob should call whiteboard_create_render_job RPC', () async {
      when(mockSupabase.rpc(
        'whiteboard_create_render_job',
        params: anyNamed('params'),
      )).thenAnswer((_) async => {
        'success': true,
        'render_id': 'test-render-id',
        'project_id': 'test-project-id',
      });

      final result = await service.createRenderJob('test-project-id');

      expect(result['success'], true);
      expect(result['render_id'], 'test-render-id');
      verify(mockSupabase.rpc(
        'whiteboard_create_render_job',
        params: {
          'p_project_id': 'test-project-id',
        },
      )).called(1);
    });

    test('getRenderStatus should call whiteboard_get_render_status RPC', () async {
      when(mockSupabase.rpc(
        'whiteboard_get_render_status',
        params: anyNamed('params'),
      )).thenAnswer((_) async => {
        'success': true,
        'render': {
          'id': 'test-render-id',
          'status': 'processing',
          'video_url': null,
        },
      });

      final result = await service.getRenderStatus('test-render-id');

      expect(result['success'], true);
      expect(result['render']['status'], 'processing');
      verify(mockSupabase.rpc(
        'whiteboard_get_render_status',
        params: {
          'p_render_id': 'test-render-id',
        },
      )).called(1);
    });

    test('waitForRenderCompletion should poll until done', () async {
      int callCount = 0;
      when(mockSupabase.rpc(
        'whiteboard_get_render_status',
        params: anyNamed('params'),
      )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return {
            'success': true,
            'render': {
              'id': 'test-render-id',
              'status': 'processing',
              'video_url': null,
            },
          };
        } else {
          return {
            'success': true,
            'render': {
              'id': 'test-render-id',
              'status': 'done',
              'video_url': 'https://example.com/video.mp4',
            },
          };
        }
      });

      final result = await service.waitForRenderCompletion(
        'test-render-id',
        pollingInterval: const Duration(milliseconds: 100),
      );

      expect(result['render']['status'], 'done');
      expect(result['render']['video_url'], 'https://example.com/video.mp4');
      expect(callCount, 2);
    });

    test('waitForRenderCompletion should timeout after duration', () async {
      when(mockSupabase.rpc(
        'whiteboard_get_render_status',
        params: anyNamed('params'),
      )).thenAnswer((_) async => {
        'success': true,
        'render': {
          'id': 'test-render-id',
          'status': 'processing',
          'video_url': null,
        },
      });

      expect(
        () => service.waitForRenderCompletion(
          'test-render-id',
          timeout: const Duration(milliseconds: 100),
          pollingInterval: const Duration(milliseconds: 50),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('getRenderVideoUrl should return null if not done', () async {
      when(mockSupabase.rpc(
        'whiteboard_get_render_status',
        params: anyNamed('params'),
      )).thenAnswer((_) async => {
        'success': true,
        'render': {
          'id': 'test-render-id',
          'status': 'processing',
          'video_url': null,
        },
      });

      final url = await service.getRenderVideoUrl('test-render-id');

      expect(url, null);
    });

    test('getRenderVideoUrl should return URL if done', () async {
      when(mockSupabase.rpc(
        'whiteboard_get_render_status',
        params: anyNamed('params'),
      )).thenAnswer((_) async => {
        'success': true,
        'render': {
          'id': 'test-render-id',
          'status': 'done',
          'video_url': 'https://example.com/video.mp4',
        },
      });

      final url = await service.getRenderVideoUrl('test-render-id');

      expect(url, 'https://example.com/video.mp4');
    });
  });
}
