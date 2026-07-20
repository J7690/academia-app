import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/smart_whiteboard_provider.dart';
import '../models/storyboard_models.dart';

/// Écran de saisie des paramètres initiaux du Smart Whiteboard
/// 
/// Supporte 4 modes UX.1 :
/// - Mode A : Sujet simple
/// - Mode B : Texte complet
/// - Mode C : Plan
/// - Mode D : Cours existant
class SmartWhiteboardInputScreen extends StatefulWidget {
  const SmartWhiteboardInputScreen({super.key});

  @override
  State<SmartWhiteboardInputScreen> createState() => _SmartWhiteboardInputScreenState();
}

class _SmartWhiteboardInputScreenState extends State<SmartWhiteboardInputScreen> {
  // Mode selection
  InputMode _selectedMode = InputMode.simpleSubject;

  // Form controllers
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  // Theme and renderer selection
  ThemeId _selectedTheme = ThemeId.scientific;
  RendererId _selectedRenderer = RendererId.scientific;
  NarrationMode _selectedNarrationMode = NarrationMode.none;

  @override
  void dispose() {
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    final subject = _subjectController.text.trim();
    
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un sujet')),
      );
      return;
    }

    final provider = context.read<SmartWhiteboardProvider>();

    // Create project
    await provider.createProject(
      subject: subject,
      rendererId: _selectedRenderer.name,
      themeId: _selectedTheme.name,
      narrationMode: _selectedNarrationMode.name,
    );

    if (!mounted) return;

    if (provider.state == SmartWhiteboardState.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${provider.errorMessage}')),
      );
      return;
    }

    // Generate storyboard (transmet le mode ET le contenu saisi)
    await provider.generateStoryboard(
      mode: _selectedMode.apiValue,
      content: _selectedMode == InputMode.simpleSubject
          ? ''
          : _contentController.text.trim(),
    );

    if (!mounted) return;

    if (provider.state == SmartWhiteboardState.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${provider.errorMessage}')),
      );
      return;
    }

    // Navigate to storyboard editor
    Navigator.of(context).pushNamed('/smart-whiteboard-editor');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Whiteboard'),
        backgroundColor: const Color(0xFF1EA75C),
      ),
      body: Consumer<SmartWhiteboardProvider>(
        builder: (context, provider, child) {
          if (provider.state == SmartWhiteboardState.loading ||
              provider.state == SmartWhiteboardState.bobodoGenerating) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mode selection
                const Text(
                  'Mode de saisie',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildModeSelector(),
                const SizedBox(height: 24),

                // Subject input
                const Text(
                  'Sujet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Dérivée d\'une fonction',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Content input (for modes B, C, D)
                if (_selectedMode != InputMode.simpleSubject) ...[
                  const Text(
                    'Contenu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contentController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: _getContentHint(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Theme selection
                const Text(
                  'Thème',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildThemeSelector(),
                const SizedBox(height: 24),

                // Renderer selection
                const Text(
                  'Renderer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRendererSelector(),
                const SizedBox(height: 24),

                // Narration mode selection
                const Text(
                  'Narration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildNarrationModeSelector(),
                const SizedBox(height: 32),

                // Generate button
                ElevatedButton(
                  onPressed: _handleGenerate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1EA75C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Générer le Storyboard',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeSelector() {
    return SegmentedButton<InputMode>(
      segments: const [
        ButtonSegment(
          value: InputMode.simpleSubject,
          label: Text('Sujet simple'),
        ),
        ButtonSegment(
          value: InputMode.fullText,
          label: Text('Texte complet'),
        ),
        ButtonSegment(
          value: InputMode.plan,
          label: Text('Plan'),
        ),
        ButtonSegment(
          value: InputMode.existingCourse,
          label: Text('Cours existant'),
        ),
      ],
      selected: {_selectedMode},
      onSelectionChanged: (Set<InputMode> newSelection) {
        setState(() {
          _selectedMode = newSelection.first;
        });
      },
    );
  }

  Widget _buildThemeSelector() {
    return SegmentedButton<ThemeId>(
      segments: const [
        ButtonSegment(
          value: ThemeId.scientific,
          label: Text('Scientifique'),
        ),
        ButtonSegment(
          value: ThemeId.notebook,
          label: Text('Cahier'),
        ),
      ],
      selected: {_selectedTheme},
      onSelectionChanged: (Set<ThemeId> newSelection) {
        setState(() {
          _selectedTheme = newSelection.first;
        });
      },
    );
  }

  Widget _buildRendererSelector() {
    return SegmentedButton<RendererId>(
      segments: const [
        ButtonSegment(
          value: RendererId.scientific,
          label: Text('Scientifique'),
        ),
        ButtonSegment(
          value: RendererId.notebook,
          label: Text('Cahier'),
        ),
      ],
      selected: {_selectedRenderer},
      onSelectionChanged: (Set<RendererId> newSelection) {
        setState(() {
          _selectedRenderer = newSelection.first;
        });
      },
    );
  }

  Widget _buildNarrationModeSelector() {
    return SegmentedButton<NarrationMode>(
      segments: const [
        ButtonSegment(
          value: NarrationMode.none,
          label: Text('Aucune'),
        ),
        ButtonSegment(
          value: NarrationMode.tts,
          label: Text('TTS'),
        ),
        ButtonSegment(
          value: NarrationMode.userRecording,
          label: Text('Enregistrement'),
        ),
      ],
      selected: {_selectedNarrationMode},
      onSelectionChanged: (Set<NarrationMode> newSelection) {
        setState(() {
          _selectedNarrationMode = newSelection.first;
        });
      },
    );
  }

  String _getContentHint() {
    switch (_selectedMode) {
      case InputMode.simpleSubject:
        return '';
      case InputMode.fullText:
        return 'Collez votre texte complet ici...';
      case InputMode.plan:
        return 'Collez votre plan ici...';
      case InputMode.existingCourse:
        return 'Collez le contenu de votre cours ici...';
    }
  }
}

enum InputMode {
  simpleSubject,
  fullText,
  plan,
  existingCourse,
}

extension InputModeApi on InputMode {
  /// Valeur attendue par l'Edge Function whiteboard-generate-storyboard.
  String get apiValue {
    switch (this) {
      case InputMode.simpleSubject:
        return 'simple_subject';
      case InputMode.fullText:
        return 'full_text';
      case InputMode.plan:
        return 'plan';
      case InputMode.existingCourse:
        return 'existing_course';
    }
  }
}
