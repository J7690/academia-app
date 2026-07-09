import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/models/storyboard_models.dart';

void main() {
  group('Storyboard Models Tests', () {
    group('ExportSettings', () {
      test('should serialize and deserialize correctly', () {
        final settings = ExportSettings.v1Default;
        final json = settings.toJson();
        final deserialized = ExportSettings.fromJson(json);

        expect(deserialized.format, equals(settings.format));
        expect(deserialized.resolution.width, equals(settings.resolution.width));
        expect(deserialized.resolution.height, equals(settings.resolution.height));
        expect(deserialized.frameRate, equals(settings.frameRate));
        expect(deserialized.videoCodec, equals(settings.videoCodec));
        expect(deserialized.audioCodec, equals(settings.audioCodec));
      });

      test('copyWith should work correctly', () {
        final settings = ExportSettings.v1Default;
        final copied = settings.copyWith(frameRate: 60);

        expect(copied.frameRate, equals(60));
        expect(copied.format, equals(settings.format));
      });
    });

    group('Resolution', () {
      test('should serialize and deserialize correctly', () {
        final resolution = const Resolution(width: 1080, height: 1920);
        final json = resolution.toJson();
        final deserialized = Resolution.fromJson(json);

        expect(deserialized.width, equals(resolution.width));
        expect(deserialized.height, equals(resolution.height));
      });

      test('copyWith should work correctly', () {
        final resolution = const Resolution(width: 1080, height: 1920);
        final copied = resolution.copyWith(width: 720);

        expect(copied.width, equals(720));
        expect(copied.height, equals(resolution.height));
      });
    });

    group('Narration', () {
      test('should serialize and deserialize correctly', () {
        final narration = Narration(
          mode: NarrationMode.tts,
          audioUrl: 'https://example.com/audio.mp3',
          durationMs: 60000,
          language: 'fr',
          voice: 'fr-FR',
        );
        final json = narration.toJson();
        final deserialized = Narration.fromJson(json);

        expect(deserialized.mode, equals(narration.mode));
        expect(deserialized.audioUrl, equals(narration.audioUrl));
        expect(deserialized.durationMs, equals(narration.durationMs));
        expect(deserialized.language, equals(narration.language));
        expect(deserialized.voice, equals(narration.voice));
      });

      test('copyWith should work correctly', () {
        final narration = Narration(mode: NarrationMode.none);
        final copied = narration.copyWith(mode: NarrationMode.tts);

        expect(copied.mode, equals(NarrationMode.tts));
      });
    });

    group('BlockStyle', () {
      test('should serialize and deserialize correctly', () {
        final style = const BlockStyle(
          fontSize: 16,
          fontWeight: 'bold',
          color: '#000000',
        );
        final json = style.toJson();
        final deserialized = BlockStyle.fromJson(json);

        expect(deserialized.fontSize, equals(style.fontSize));
        expect(deserialized.fontWeight, equals(style.fontWeight));
        expect(deserialized.color, equals(style.color));
      });

      test('copyWith should work correctly', () {
        final style = const BlockStyle(fontSize: 16);
        final copied = style.copyWith(fontSize: 24);

        expect(copied.fontSize, equals(24));
      });
    });

    group('TitleBlock', () {
      test('should serialize and deserialize correctly', () {
        final block = const TitleBlock(
          id: '1',
          content: 'Introduction',
          order: 0,
        );
        final json = block.toJson();
        final deserialized = Block.fromJson(json) as TitleBlock;

        expect(deserialized.id, equals(block.id));
        expect(deserialized.content, equals(block.content));
        expect(deserialized.order, equals(block.order));
        expect(deserialized.type, equals(BlockType.title));
      });

      test('copyWith should work correctly', () {
        final block = const TitleBlock(
          id: '1',
          content: 'Introduction',
          order: 0,
        );
        final copied = block.copyWith(content: 'Nouveau titre');

        expect(copied.content, equals('Nouveau titre'));
        expect(copied.id, equals(block.id));
      });
    });

    group('ParagraphBlock', () {
      test('should serialize and deserialize correctly', () {
        final block = const ParagraphBlock(
          id: '2',
          content: 'Ceci est un paragraphe.',
          order: 1,
        );
        final json = block.toJson();
        final deserialized = Block.fromJson(json) as ParagraphBlock;

        expect(deserialized.id, equals(block.id));
        expect(deserialized.content, equals(block.content));
        expect(deserialized.order, equals(block.order));
        expect(deserialized.type, equals(BlockType.paragraph));
      });

      test('copyWith should work correctly', () {
        final block = const ParagraphBlock(
          id: '2',
          content: 'Ceci est un paragraphe.',
          order: 1,
        );
        final copied = block.copyWith(content: 'Nouveau paragraphe');

        expect(copied.content, equals('Nouveau paragraphe'));
      });
    });

    group('FormulaBlock', () {
      test('should serialize and deserialize correctly', () {
        final block = const FormulaBlock(
          id: '3',
          content: 'E = mc^2',
          order: 2,
          format: 'latex',
        );
        final json = block.toJson();
        final deserialized = Block.fromJson(json) as FormulaBlock;

        expect(deserialized.id, equals(block.id));
        expect(deserialized.content, equals(block.content));
        expect(deserialized.format, equals(block.format));
        expect(deserialized.type, equals(BlockType.formula));
      });

      test('copyWith should work correctly', () {
        final block = const FormulaBlock(
          id: '3',
          content: 'E = mc^2',
          order: 2,
        );
        final copied = block.copyWith(content: 'F = ma');

        expect(copied.content, equals('F = ma'));
      });
    });

    group('DefinitionBlock', () {
      test('should serialize and deserialize correctly', () {
        final block = const DefinitionBlock(
          id: '4',
          term: 'Dérivée',
          definition: 'Taux de variation',
          example: 'f(x) = x^2, f\'(x) = 2x',
          order: 3,
        );
        final json = block.toJson();
        final deserialized = Block.fromJson(json) as DefinitionBlock;

        expect(deserialized.id, equals(block.id));
        expect(deserialized.term, equals(block.term));
        expect(deserialized.definition, equals(block.definition));
        expect(deserialized.example, equals(block.example));
        expect(deserialized.type, equals(BlockType.definition));
      });

      test('copyWith should work correctly', () {
        final block = const DefinitionBlock(
          id: '4',
          term: 'Dérivée',
          definition: 'Taux de variation',
          order: 3,
        );
        final copied = block.copyWith(term: 'Intégrale');

        expect(copied.term, equals('Intégrale'));
      });
    });

    group('ExerciseBlock', () {
      test('should serialize and deserialize correctly', () {
        final block = const ExerciseBlock(
          id: '5',
          question: 'Calculer la dérivée de f(x) = x^2',
          hint: 'Utiliser la formule (x^n)\' = nx^(n-1)',
          solution: 'f\'(x) = 2x',
          order: 4,
        );
        final json = block.toJson();
        final deserialized = Block.fromJson(json) as ExerciseBlock;

        expect(deserialized.id, equals(block.id));
        expect(deserialized.question, equals(block.question));
        expect(deserialized.hint, equals(block.hint));
        expect(deserialized.solution, equals(block.solution));
        expect(deserialized.type, equals(BlockType.exercise));
      });

      test('copyWith should work correctly', () {
        final block = const ExerciseBlock(
          id: '5',
          question: 'Calculer la dérivée de f(x) = x^2',
          order: 4,
        );
        final copied = block.copyWith(question: 'Nouvelle question');

        expect(copied.question, equals('Nouvelle question'));
      });
    });

    group('CorrectionBlock', () {
      test('should serialize and deserialize correctly', () {
        final block = const CorrectionBlock(
          id: '6',
          exerciseId: '5',
          steps: ['Étape 1', 'Étape 2', 'Étape 3'],
          explanation: 'Explication détaillée',
          order: 5,
        );
        final json = block.toJson();
        final deserialized = Block.fromJson(json) as CorrectionBlock;

        expect(deserialized.id, equals(block.id));
        expect(deserialized.exerciseId, equals(block.exerciseId));
        expect(deserialized.steps, equals(block.steps));
        expect(deserialized.explanation, equals(block.explanation));
        expect(deserialized.type, equals(BlockType.correction));
      });

      test('copyWith should work correctly', () {
        final block = const CorrectionBlock(
          id: '6',
          exerciseId: '5',
          steps: ['Étape 1'],
          explanation: 'Explication',
          order: 5,
        );
        final copied = block.copyWith(steps: ['Nouvelle étape']);

        expect(copied.steps, equals(['Nouvelle étape']));
      });
    });

    group('Scene', () {
      test('should serialize and deserialize correctly', () {
        final scene = Scene(
          id: 'scene1',
          order: 0,
          title: 'Introduction',
          durationMs: 5000,
          blocks: [
            const TitleBlock(id: '1', content: 'Introduction', order: 0),
            const ParagraphBlock(id: '2', content: 'Contenu', order: 1),
          ],
        );
        final json = scene.toJson();
        final deserialized = Scene.fromJson(json);

        expect(deserialized.id, equals(scene.id));
        expect(deserialized.order, equals(scene.order));
        expect(deserialized.title, equals(scene.title));
        expect(deserialized.durationMs, equals(scene.durationMs));
        expect(deserialized.blocks.length, equals(scene.blocks.length));
      });

      test('copyWith should work correctly', () {
        final scene = Scene(
          id: 'scene1',
          order: 0,
          title: 'Introduction',
          durationMs: 5000,
          blocks: [],
        );
        final copied = scene.copyWith(title: 'Nouveau titre');

        expect(copied.title, equals('Nouveau titre'));
      });
    });

    group('Storyboard', () {
      test('should serialize and deserialize correctly', () {
        final storyboard = Storyboard(
          version: '1.0',
          createdAt: DateTime(2026, 6, 23),
          createdBy: 'user123',
          subject: 'Mathématiques',
          renderer: RendererId.scientific,
          theme: ThemeId.scientific,
          narrationMode: NarrationMode.none,
          exportSettings: ExportSettings.v1Default,
          scenes: [
            Scene(
              id: 'scene1',
              order: 0,
              title: 'Introduction',
              durationMs: 5000,
              blocks: [],
            ),
          ],
        );
        final json = storyboard.toJson();
        final deserialized = Storyboard.fromJson(json);

        expect(deserialized.version, equals(storyboard.version));
        expect(deserialized.subject, equals(storyboard.subject));
        expect(deserialized.renderer, equals(storyboard.renderer));
        expect(deserialized.theme, equals(storyboard.theme));
        expect(deserialized.narrationMode, equals(storyboard.narrationMode));
        expect(deserialized.scenes.length, equals(storyboard.scenes.length));
      });

      test('copyWith should work correctly', () {
        final storyboard = Storyboard(
          version: '1.0',
          createdAt: DateTime(2026, 6, 23),
          createdBy: 'user123',
          subject: 'Mathématiques',
          renderer: RendererId.scientific,
          theme: ThemeId.scientific,
          narrationMode: NarrationMode.none,
          exportSettings: ExportSettings.v1Default,
          scenes: [],
        );
        final copied = storyboard.copyWith(subject: 'Physique');

        expect(copied.subject, equals('Physique'));
      });
    });

    group('WhiteboardProject', () {
      test('should serialize and deserialize correctly', () {
        final project = WhiteboardProject(
          id: 'project1',
          studentId: 'student123',
          subject: 'Mathématiques',
          status: ProjectStatus.draft,
          createdAt: DateTime(2026, 6, 23),
          updatedAt: DateTime(2026, 6, 23),
          rendererId: RendererId.scientific,
          themeId: ThemeId.scientific,
          narrationMode: NarrationMode.none,
          storyboard: Storyboard(
            version: '1.0',
            createdAt: DateTime(2026, 6, 23),
            createdBy: 'student123',
            subject: 'Mathématiques',
            renderer: RendererId.scientific,
            theme: ThemeId.scientific,
            narrationMode: NarrationMode.none,
            exportSettings: ExportSettings.v1Default,
            scenes: [],
          ),
        );
        final json = project.toJson();
        final deserialized = WhiteboardProject.fromJson(json);

        expect(deserialized.id, equals(project.id));
        expect(deserialized.studentId, equals(project.studentId));
        expect(deserialized.subject, equals(project.subject));
        expect(deserialized.status, equals(project.status));
        expect(deserialized.rendererId, equals(project.rendererId));
        expect(deserialized.themeId, equals(project.themeId));
        expect(deserialized.narrationMode, equals(project.narrationMode));
        expect(deserialized.storyboard.version, equals(project.storyboard.version));
      });

      test('copyWith should work correctly', () {
        final project = WhiteboardProject(
          id: 'project1',
          studentId: 'student123',
          subject: 'Mathématiques',
          status: ProjectStatus.draft,
          createdAt: DateTime(2026, 6, 23),
          updatedAt: DateTime(2026, 6, 23),
          rendererId: RendererId.scientific,
          themeId: ThemeId.scientific,
          narrationMode: NarrationMode.none,
          storyboard: Storyboard(
            version: '1.0',
            createdAt: DateTime(2026, 6, 23),
            createdBy: 'student123',
            subject: 'Mathématiques',
            renderer: RendererId.scientific,
            theme: ThemeId.scientific,
            narrationMode: NarrationMode.none,
            exportSettings: ExportSettings.v1Default,
            scenes: [],
          ),
        );
        final copied = project.copyWith(status: ProjectStatus.completed);

        expect(copied.status, equals(ProjectStatus.completed));
      });
    });

    group('RenderJob', () {
      test('should serialize and deserialize correctly', () {
        final job = RenderJob(
          id: 'job1',
          projectId: 'project1',
          status: RenderJobStatus.queued,
          videoUrl: null,
          durationMs: null,
          errorMessage: null,
          progress: 0,
          createdAt: DateTime(2026, 6, 23),
          completedAt: null,
        );
        final json = job.toJson();
        final deserialized = RenderJob.fromJson(json);

        expect(deserialized.id, equals(job.id));
        expect(deserialized.projectId, equals(job.projectId));
        expect(deserialized.status, equals(job.status));
        expect(deserialized.progress, equals(job.progress));
      });

      test('copyWith should work correctly', () {
        final job = RenderJob(
          id: 'job1',
          projectId: 'project1',
          status: RenderJobStatus.queued,
          createdAt: DateTime(2026, 6, 23),
        );
        final copied = job.copyWith(status: RenderJobStatus.processing);

        expect(copied.status, equals(RenderJobStatus.processing));
      });
    });

    group('Data Contract Compatibility', () {
      test('Storyboard → Scene → Block integrity', () {
        final block = const TitleBlock(id: '1', content: 'Test', order: 0);
        final scene = Scene(
          id: 'scene1',
          order: 0,
          title: 'Test Scene',
          durationMs: 5000,
          blocks: [block],
        );
        final storyboard = Storyboard(
          version: '1.0',
          createdAt: DateTime(2026, 6, 23),
          createdBy: 'user123',
          subject: 'Test',
          renderer: RendererId.scientific,
          theme: ThemeId.scientific,
          narrationMode: NarrationMode.none,
          exportSettings: ExportSettings.v1Default,
          scenes: [scene],
        );

        // Serialize and deserialize
        final json = storyboard.toJson();
        final deserialized = Storyboard.fromJson(json);

        // Verify integrity
        expect(deserialized.scenes.length, equals(1));
        expect(deserialized.scenes.first.blocks.length, equals(1));
        expect(
          deserialized.scenes.first.blocks.first.id,
          equals(block.id),
        );
      });

      test('All block types V1 are supported', () {
        final blocks = [
          const TitleBlock(id: '1', content: 'Title', order: 0),
          const ParagraphBlock(id: '2', content: 'Paragraph', order: 1),
          const FormulaBlock(id: '3', content: 'E=mc^2', order: 2),
          const DefinitionBlock(
            id: '4',
            term: 'Term',
            definition: 'Definition',
            order: 3,
          ),
          const ExerciseBlock(
            id: '5',
            question: 'Question',
            order: 4,
          ),
          const CorrectionBlock(
            id: '6',
            exerciseId: '5',
            steps: ['Step 1'],
            explanation: 'Explanation',
            order: 5,
          ),
        ];

        for (final block in blocks) {
          final json = block.toJson();
          final deserialized = Block.fromJson(json);
          expect(deserialized.type, equals(block.type));
        }
      });
    });
  });
}
