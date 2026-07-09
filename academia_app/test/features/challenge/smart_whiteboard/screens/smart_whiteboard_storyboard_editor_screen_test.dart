import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/screens/smart_whiteboard_storyboard_editor_screen.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/models/storyboard_models.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateMocks([SmartWhiteboardService, SmartWhiteboardRenderService, SmartWhiteboardNarrationService, SupabaseClient])
import 'smart_whiteboard_storyboard_editor_screen_test.mocks.dart';

void main() {
  group('SmartWhiteboardStoryboardEditorScreen Widget Tests', () {
    late MockSmartWhiteboardService mockProjectService;
    late MockSmartWhiteboardRenderService mockRenderService;
    late MockSmartWhiteboardNarrationService mockNarrationService;

    setUp(() {
      mockProjectService = MockSmartWhiteboardService();
      mockRenderService = MockSmartWhiteboardRenderService();
      mockNarrationService = MockSmartWhiteboardNarrationService();
    });

    testWidgets('should display empty storyboard when no initial storyboard', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => SmartWhiteboardProvider(
              projectService: mockProjectService,
              renderService: mockRenderService,
              narrationService: mockNarrationService,
            ),
            child: const SmartWhiteboardStoryboardEditorScreen(),
          ),
        ),
      );

      expect(find.text('Éditeur de Storyboard'), findsOneWidget);
    });

    testWidgets('should display scenes when storyboard has scenes', (tester) async {
      final storyboard = Storyboard(
        version: "1.0",
        createdAt: DateTime.now(),
        createdBy: "user",
        subject: "Test Subject",
        renderer: RendererId.scientific,
        theme: ThemeId.scientific,
        narrationMode: NarrationMode.none,
        exportSettings: const ExportSettings.v1Default,
        scenes: [
          Scene(
            id: 'scene-1',
            order: 0,
            title: 'Scene 1',
            durationMs: 5000,
            blocks: [
              TitleBlock(
                id: 'block-1',
                order: 0,
                visible: true,
                content: 'Test Title',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => SmartWhiteboardProvider(
              projectService: mockProjectService,
              renderService: mockRenderService,
              narrationService: mockNarrationService,
            ),
            child: SmartWhiteboardStoryboardEditorScreen(
              initialStoryboard: storyboard,
            ),
          ),
        ),
      );

      expect(find.text('Éditeur de Storyboard'), findsOneWidget);
      expect(find.text('Scène 1: Scene 1'), findsOneWidget);
    });

    testWidgets('should validate empty storyboard', (tester) async {
      final emptyStoryboard = Storyboard(
        version: "1.0",
        createdAt: DateTime.now(),
        createdBy: "user",
        subject: "Test Subject",
        renderer: RendererId.scientific,
        theme: ThemeId.scientific,
        narrationMode: NarrationMode.none,
        exportSettings: const ExportSettings.v1Default,
        scenes: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => SmartWhiteboardProvider(
              projectService: mockProjectService,
              renderService: mockRenderService,
              narrationService: mockNarrationService,
            ),
            child: SmartWhiteboardStoryboardEditorScreen(
              initialStoryboard: emptyStoryboard,
            ),
          ),
        ),
      );

      // Try to save
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.text('Le storyboard ne peut pas être vide'), findsOneWidget);
    });
  });
}
