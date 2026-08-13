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
  ProductionType _selectedProduction = ProductionType.tableau;

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
    // Le choix de l'etudiant decide de la file de fabrication.
    provider.choisirTypeProduction(_selectedProduction.apiValue);

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
        actions: [
          // LE CHEMIN DE RETOUR VERS SES COURS.
          //
          // L'écran « Mes cours » était déclaré dans les routes mais poussé
          // depuis NULLE PART : la seule entrée créait toujours un projet
          // neuf. Mesuré le 07/08 : 125 storyboards générés — donc payés —
          // dont le rendu n'a jamais été lancé, et 7 cours dont le rendu a
          // échoué sans que l'étudiant puisse le relancer.
          //
          // Relancer un rendu ne coûte aucun crédit : il suffisait de pouvoir
          // y revenir. Le libellé est écrit en toutes lettres, pas en icône
          // seule — quelqu'un qui découvre l'application doit comprendre sans
          // deviner.
          TextButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/smart-whiteboard-projects'),
            icon: const Icon(Icons.folder_open, color: Colors.white, size: 19),
            label: const Text('Mes cours',
                style: TextStyle(color: Colors.white, fontSize: 13.5)),
          ),
        ],
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
                // Type de production — le choix qui décide de la NATURE de la
                // vidéo, donc posé avant tout le reste.
                const Text(
                  'Type de vidéo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildProductionSelector(),
                const SizedBox(height: 24),

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

  /// Le choix le plus structurant de l'écran : quel genre de vidéo.
  ///
  /// Il est posé EN PREMIER, avant même le mode de saisie, parce qu'il ne
  /// change pas la mise en forme mais la nature du produit — un tableau qu'on
  /// écrit, ou une animation qu'on regarde. Le sujet et la narration, eux,
  /// sont identiques : c'est la même IA qui les écrit, et l'étudiant paie une
  /// seule fois.
  Widget _buildProductionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ProductionType>(
          segments: const [
            ButtonSegment(
              value: ProductionType.tableau,
              icon: Icon(Icons.edit_outlined),
              label: Text('Tableau'),
            ),
            ButtonSegment(
              value: ProductionType.animation,
              icon: Icon(Icons.auto_awesome_outlined),
              label: Text('Animation 3D'),
            ),
          ],
          selected: {_selectedProduction},
          onSelectionChanged: (Set<ProductionType> newSelection) {
            setState(() {
              _selectedProduction = newSelection.first;
            });
          },
        ),
        const SizedBox(height: 8),
        Text(
          _selectedProduction.description,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280), height: 1.4),
        ),
      ],
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

/// Les deux façons de fabriquer la vidéo d'un même cours.
///
/// Le sujet, le storyboard et la narration sont IDENTIQUES : c'est la même
/// génération par IA, donc le même coût en crédits. Seul le moteur de rendu
/// change, et avec lui la nature du résultat.
///
/// La valeur `apiValue` est celle que le champ `engine` porte jusqu'au worker.
/// `vision2` était jusqu'ici imposée à la compilation
/// (`BackendHosts.whiteboardEngine`) ; elle devient un choix de l'étudiant,
/// comme le prévoyait déjà le commentaire de ce réglage.
enum ProductionType {
  /// Tableau manuscrit : l'écriture se trace au fil de la parole, avec
  /// annotations. Rendu sur le serveur du projet, sans GPU.
  tableau,

  /// Animation 3D : géométrie lumineuse, caméra mobile, sound design. Rendu
  /// sur une machine à carte graphique, louée à la seconde.
  animation;

  String get apiValue => this == ProductionType.tableau ? 'vision2' : 'studio';

  String get description => this == ProductionType.tableau
      ? "Le cours s'écrit au tableau pendant que la voix l'explique, avec les "
          "mots-clés entourés. Prêt en deux à trois minutes."
      : "Le cours devient une animation en volume — formes lumineuses, caméra "
          "qui se déplace, ambiance sonore. Rendu plus long.";
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
