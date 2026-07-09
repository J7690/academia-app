import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:academia_app/features/challenge/smart_whiteboard/services/smart_whiteboard_narration_service.dart';

@GenerateMocks([SupabaseClient, SupabaseStorageClient])
import 'smart_whiteboard_narration_service_test.mocks.dart';

void main() {
  late SmartWhiteboardNarrationService service;
  late MockSupabaseClient mockSupabase;
  late MockSupabaseStorageClient mockStorage;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockStorage = MockSupabaseStorageClient();
    when(mockSupabase.storage).thenReturn(mockStorage);
    service = SmartWhiteboardNarrationService(mockSupabase);
  });

  group('SmartWhiteboardNarrationService', () {
    test('uploadNarration should upload file to whiteboard-narrations bucket', () async {
      when(mockStorage.from('whiteboard-narrations')).thenReturn(mockStorage);
      when(mockStorage.upload(any, any, fileOptions: anyNamed('fileOptions')))
          .thenAnswer((_) async => 'narrations/test-project-id/test-audio.mp3');
      when(mockStorage.getPublicUrl(any)).thenReturn('https://example.com/narrations/test-project-id/test-audio.mp3');

      final mockFile = File('/tmp/test-audio.mp3');
      
      final url = await service.uploadNarration(
        projectId: 'test-project-id',
        audioFile: mockFile,
        fileName: 'test-audio.mp3',
      );

      expect(url, 'https://example.com/narrations/test-project-id/test-audio.mp3');
      verify(mockStorage.from('whiteboard-narrations')).called(1);
      verify(mockStorage.upload(
        'narrations/test-project-id/test-audio.mp3',
        mockFile,
        fileOptions: anyNamed('fileOptions'),
      )).called(1);
    });

    test('deleteNarration should delete file from whiteboard-narrations bucket', () async {
      when(mockStorage.from('whiteboard-narrations')).thenReturn(mockStorage);
      when(mockStorage.remove(any)).thenAnswer((_) async => []);

      await service.deleteNarration(
        projectId: 'test-project-id',
        fileName: 'test-audio.mp3',
      );

      verify(mockStorage.from('whiteboard-narrations')).called(1);
      verify(mockStorage.remove(['narrations/test-project-id/test-audio.mp3'])).called(1);
    });

    test('getNarrationUrl should return public URL', () {
      when(mockStorage.from('whiteboard-narrations')).thenReturn(mockStorage);
      when(mockStorage.getPublicUrl('narrations/test-project-id/test-audio.mp3'))
          .thenReturn('https://example.com/narrations/test-project-id/test-audio.mp3');

      final url = service.getNarrationUrl(
        projectId: 'test-project-id',
        fileName: 'test-audio.mp3',
      );

      expect(url, 'https://example.com/narrations/test-project-id/test-audio.mp3');
      verify(mockStorage.from('whiteboard-narrations')).called(1);
      verify(mockStorage.getPublicUrl('narrations/test-project-id/test-audio.mp3')).called(1);
    });
  });
}
