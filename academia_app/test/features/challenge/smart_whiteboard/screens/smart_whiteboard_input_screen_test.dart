import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/screens/smart_whiteboard_input_screen.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/services/smart_whiteboard_service.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/services/smart_whiteboard_render_service.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/services/smart_whiteboard_narration_service.dart';

@GenerateMocks([
  SmartWhiteboardService,
  SmartWhiteboardRenderService,
  SmartWhiteboardNarrationService,
])
import 'smart_whiteboard_input_screen_test.mocks.dart';

void main() {
  late MockSmartWhiteboardService mockProjectService;
  late MockSmartWhiteboardRenderService mockRenderService;
  late MockSmartWhiteboardNarrationService mockNarrationService;
  late SmartWhiteboardProvider provider;

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

  Widget createTestWidget() {
    return MaterialApp(
      home: ChangeNotifierProvider<SmartWhiteboardProvider>.value(
        value: provider,
        child: const SmartWhiteboardInputScreen(),
      ),
    );
  }

  group('SmartWhiteboardInputScreen', () {
    testWidgets('should display mode selector', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Mode de saisie'), findsOneWidget);
      expect(find.text('Sujet simple'), findsOneWidget);
      expect(find.text('Texte complet'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Cours existant'), findsOneWidget);
    });

    testWidgets('should display subject input field', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Sujet'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('should show content input when mode is not simple subject', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Tap on "Texte complet" mode
      await tester.tap(find.text('Texte complet'));
      await tester.pumpAndSettle();

      expect(find.text('Contenu'), findsOneWidget);
      expect(find.text('Collez votre texte complet ici...'), findsOneWidget);
    });

    testWidgets('should show theme selector', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Thème'), findsOneWidget);
      expect(find.text('Scientifique'), findsOneWidget);
      expect(find.text('Cahier'), findsOneWidget);
    });

    testWidgets('should show renderer selector', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Renderer'), findsOneWidget);
      expect(find.text('Scientifique'), findsOneWidget);
      expect(find.text('Cahier'), findsOneWidget);
    });

    testWidgets('should show narration mode selector', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Narration'), findsOneWidget);
      expect(find.text('Aucune'), findsOneWidget);
      expect(find.text('TTS'), findsOneWidget);
      expect(find.text('Enregistrement'), findsOneWidget);
    });

    testWidgets('should show error when subject is empty', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Tap generate button without entering subject
      await tester.tap(find.text('Générer le Storyboard'));
      await tester.pumpAndSettle();

      expect(find.text('Veuillez saisir un sujet'), findsOneWidget);
    });

    testWidgets('should call createProject when subject is valid', (WidgetTester tester) async {
      when(mockProjectService.createProject(
        subject: anyNamed('subject'),
        rendererId: anyNamed('rendererId'),
        themeId: anyNamed('themeId'),
        narrationMode: anyNamed('narrationMode'),
      )).thenAnswer((_) async => {
        'success': true,
        'project_id': 'test-project-id',
      });

      await tester.pumpWidget(createTestWidget());

      // Enter subject
      await tester.enterText(find.byType(TextField).first, 'Test Subject');
      await tester.pumpAndSettle();

      // Tap generate button
      await tester.tap(find.text('Générer le Storyboard'));
      await tester.pumpAndSettle();

      verify(mockProjectService.createProject(
        subject: 'Test Subject',
        rendererId: anyNamed('rendererId'),
        themeId: anyNamed('themeId'),
        narrationMode: anyNamed('narrationMode'),
      )).called(1);
    });

    testWidgets('should show error when RPC fails', (WidgetTester tester) async {
      when(mockProjectService.createProject(
        subject: anyNamed('subject'),
        rendererId: anyNamed('rendererId'),
        themeId: anyNamed('themeId'),
        narrationMode: anyNamed('narrationMode'),
      )).thenAnswer((_) async => {
        'success': false,
        'error': 'RPC Error',
      });

      await tester.pumpWidget(createTestWidget());

      // Enter subject
      await tester.enterText(find.byType(TextField).first, 'Test Subject');
      await tester.pumpAndSettle();

      // Tap generate button
      await tester.tap(find.text('Générer le Storyboard'));
      await tester.pumpAndSettle();

      expect(find.text('Erreur: RPC Error'), findsOneWidget);
    });

    testWidgets('should navigate to placeholder on success', (WidgetTester tester) async {
      when(mockProjectService.createProject(
        subject: anyNamed('subject'),
        rendererId: anyNamed('rendererId'),
        themeId: anyNamed('themeId'),
        narrationMode: anyNamed('narrationMode'),
      )).thenAnswer((_) async => {
        'success': true,
        'project_id': 'test-project-id',
      });

      await tester.pumpWidget(createTestWidget());

      // Enter subject
      await tester.enterText(find.byType(TextField).first, 'Test Subject');
      await tester.pumpAndSettle();

      // Tap generate button
      await tester.tap(find.text('Générer le Storyboard'));
      await tester.pumpAndSettle();

      // Wait for storyboard generation
      await tester.pump(const Duration(milliseconds: 100));

      // Should navigate to placeholder
      expect(find.text('Placeholder'), findsOneWidget);
      expect(find.text('Storyboard généré avec succès !'), findsOneWidget);
    });

    testWidgets('should show loading indicator during generation', (WidgetTester tester) async {
      when(mockProjectService.createProject(
        subject: anyNamed('subject'),
        rendererId: anyNamed('rendererId'),
        themeId: anyNamed('themeId'),
        narrationMode: anyNamed('narrationMode'),
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return {
          'success': true,
          'project_id': 'test-project-id',
        };
      });

      await tester.pumpWidget(createTestWidget());

      // Enter subject
      await tester.enterText(find.byType(TextField).first, 'Test Subject');
      await tester.pumpAndSettle();

      // Tap generate button
      await tester.tap(find.text('Générer le Storyboard'));
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
