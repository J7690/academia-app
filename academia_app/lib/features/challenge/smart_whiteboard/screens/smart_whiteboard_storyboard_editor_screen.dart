import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../providers/smart_whiteboard_provider.dart';
import '../models/storyboard_models.dart';

/// Écran d'édition de Storyboard Smart Whiteboard
///
/// Permet de modifier un storyboard généré par OpenRouter avant le rendu.
///
/// Fonctionnalités :
/// - Affichage des scènes et blocs
/// - Édition du contenu (titre, paragraphe, définition, exercice, correction, formule)
/// - Gestion des blocs (ajouter, supprimer, déplacer)
/// - Validation selon le contrat PHASE_D3A21_GENERATION_CONTRACT_LOCK.md
/// - Sauvegarde via SmartWhiteboardService
class SmartWhiteboardStoryboardEditorScreen extends StatefulWidget {
  final String? projectId;
  final Storyboard? initialStoryboard;

  const SmartWhiteboardStoryboardEditorScreen({
    super.key,
    this.projectId,
    this.initialStoryboard,
  });

  @override
  State<SmartWhiteboardStoryboardEditorScreen> createState() =>
      _SmartWhiteboardStoryboardEditorScreenState();
}

class _SmartWhiteboardStoryboardEditorScreenState
    extends State<SmartWhiteboardStoryboardEditorScreen> {
  late Storyboard _storyboard;
  final ScrollController _scrollController = ScrollController();
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoadingProject = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _storyboard = widget.initialStoryboard ?? _createEmptyStoryboard();
    _initializeControllers();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadInitialStoryboard());
  }

  Future<void> _loadInitialStoryboard() async {
    final provider = context.read<SmartWhiteboardProvider>();
    if (widget.projectId != null && widget.initialStoryboard == null) {
      setState(() => _isLoadingProject = true);
      await provider.loadProject(widget.projectId!);
      if (!mounted) return;
      if (provider.errorMessage != null) {
        setState(() {
          _loadError = provider.errorMessage;
          _isLoadingProject = false;
        });
        return;
      }
    }

    final providerStoryboard = provider.currentStoryboard;
    if (providerStoryboard != null && _storyboard.scenes.isEmpty) {
      setState(() {
        for (final controller in _controllers.values) {
          controller.dispose();
        }
        _controllers.clear();
        _storyboard = providerStoryboard;
        _initializeControllers();
      });
    }
    if (mounted) {
      setState(() => _isLoadingProject = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Storyboard _createEmptyStoryboard() {
    return Storyboard(
      version: "1.0",
      createdAt: DateTime.now(),
      createdBy: "user",
      subject: "Nouveau Storyboard",
      renderer: RendererId.scientific,
      theme: ThemeId.scientific,
      narrationMode: NarrationMode.none,
      exportSettings: ExportSettings.v1Default,
      scenes: [],
    );
  }

  void _initializeControllers() {
    // Créer des controllers pour chaque bloc
    for (final scene in _storyboard.scenes) {
      for (final block in scene.blocks) {
        _controllers[block.id] = TextEditingController(text: block.content);
      }
    }
  }

  void _updateBlockContent(String blockId, String newContent) {
    setState(() {
      for (final scene in _storyboard.scenes) {
        for (final block in scene.blocks) {
          if (block.id == blockId) {
            // Recréer le bloc avec le nouveau contenu
            final updatedBlock = _updateBlockContentInBlock(block, newContent);
            final updatedBlocks = List<Block>.from(scene.blocks);
            final index = updatedBlocks.indexWhere((b) => b.id == blockId);
            if (index != -1) {
              updatedBlocks[index] = updatedBlock;
            }
            final updatedScene = scene.copyWith(blocks: updatedBlocks);
            final updatedScenes = List<Scene>.from(_storyboard.scenes);
            final sceneIndex = _storyboard.scenes.indexOf(scene);
            if (sceneIndex != -1) {
              updatedScenes[sceneIndex] = updatedScene;
            }
            _storyboard = _storyboard.copyWith(scenes: updatedScenes);
            break;
          }
        }
      }
    });
  }

  Block _updateBlockContentInBlock(Block block, String newContent) {
    if (block is TitleBlock) {
      return block.copyWith(content: newContent);
    } else if (block is ParagraphBlock) {
      return block.copyWith(content: newContent);
    } else if (block is FormulaBlock) {
      return block.copyWith(content: newContent);
    } else if (block is DefinitionBlock) {
      return block.copyWith(definition: newContent);
    } else if (block is ExerciseBlock) {
      return block.copyWith(question: newContent);
    } else if (block is CorrectionBlock) {
      return block.copyWith(explanation: newContent);
    } else if (block is DiagramBlock) {
      return block.copyWith(content: newContent);
    } else if (block is GraphBlock) {
      return block.copyWith(content: newContent);
    }
    return block;
  }

  void _addBlock(Scene scene) {
    setState(() {
      final newBlock = ParagraphBlock(
        id: 'block-${DateTime.now().millisecondsSinceEpoch}',
        order: scene.blocks.length,
        visible: true,
        content: '',
        style: const BlockStyle(
            fontSize: 16, fontWeight: 'normal', color: '#000000'),
      );
      final updatedBlocks = List<Block>.from(scene.blocks)..add(newBlock);
      final updatedScene = scene.copyWith(blocks: updatedBlocks);
      final updatedScenes = List<Scene>.from(_storyboard.scenes);
      final sceneIndex = _storyboard.scenes.indexOf(scene);
      if (sceneIndex != -1) {
        updatedScenes[sceneIndex] = updatedScene;
      }
      _storyboard = _storyboard.copyWith(scenes: updatedScenes);
      _controllers[newBlock.id] = TextEditingController(text: '');
    });
  }

  void _deleteBlock(Scene scene, Block block) {
    setState(() {
      final updatedBlocks = List<Block>.from(scene.blocks)..remove(block);
      final updatedScene = scene.copyWith(blocks: updatedBlocks);
      final updatedScenes = List<Scene>.from(_storyboard.scenes);
      final sceneIndex = _storyboard.scenes.indexOf(scene);
      if (sceneIndex != -1) {
        updatedScenes[sceneIndex] = updatedScene;
      }
      _storyboard = _storyboard.copyWith(scenes: updatedScenes);
      _controllers[block.id]?.dispose();
      _controllers.remove(block.id);
    });
  }

  void _moveBlock(Scene scene, Block block, int direction) {
    setState(() {
      final updatedBlocks = List<Block>.from(scene.blocks);
      final index = updatedBlocks.indexOf(block);
      final newIndex = index + direction;

      if (newIndex >= 0 && newIndex < updatedBlocks.length) {
        updatedBlocks.removeAt(index);
        updatedBlocks.insert(newIndex, block);

        // Mettre à jour l'ordre
        for (int i = 0; i < updatedBlocks.length; i++) {
          updatedBlocks[i] = _updateBlockOrder(updatedBlocks[i], i);
        }

        final updatedScene = scene.copyWith(blocks: updatedBlocks);
        final updatedScenes = List<Scene>.from(_storyboard.scenes);
        final sceneIndex = _storyboard.scenes.indexOf(scene);
        if (sceneIndex != -1) {
          updatedScenes[sceneIndex] = updatedScene;
        }
        _storyboard = _storyboard.copyWith(scenes: updatedScenes);
      }
    });
  }

  Block _updateBlockOrder(Block block, int newOrder) {
    if (block is TitleBlock) {
      return block.copyWith(order: newOrder);
    } else if (block is ParagraphBlock) {
      return block.copyWith(order: newOrder);
    } else if (block is FormulaBlock) {
      return block.copyWith(order: newOrder);
    } else if (block is DefinitionBlock) {
      return block.copyWith(order: newOrder);
    } else if (block is ExerciseBlock) {
      return block.copyWith(order: newOrder);
    } else if (block is CorrectionBlock) {
      return block.copyWith(order: newOrder);
    } else if (block is DiagramBlock) {
      return block.copyWith(order: newOrder);
    } else if (block is GraphBlock) {
      return block.copyWith(order: newOrder);
    }
    return block;
  }

  bool _validateStoryboard() {
    // Purge automatique des blocs vides ajoutés par l'utilisateur
    setState(() {
      final purgedScenes = _storyboard.scenes.map((scene) {
        final filteredBlocks =
            scene.blocks.where((b) => b.content.trim().isNotEmpty).toList();
        return scene.copyWith(blocks: filteredBlocks);
      }).toList();
      _storyboard = _storyboard.copyWith(scenes: purgedScenes);
    });

    if (_storyboard.scenes.isEmpty) {
      _showError('Le storyboard ne peut pas être vide');
      return false;
    }

    for (final scene in _storyboard.scenes) {
      if (scene.blocks.isEmpty) {
        _showError('Scène "${scene.title}" : ajoutez au moins un bloc');
        return false;
      }
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveStoryboard() async {
    if (!_validateStoryboard()) {
      return;
    }

    final provider = context.read<SmartWhiteboardProvider>();

    try {
      await provider.updateStoryboard(_storyboard);

      if (provider.errorMessage != null) {
        _showError(provider.errorMessage!);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storyboard sauvegardé')),
      );

      Navigator.pop(context);
    } catch (e) {
      _showError('Erreur lors de la sauvegarde: $e');
    }
  }

  Future<void> _saveAndRender() async {
    if (!_validateStoryboard()) {
      return;
    }

    final provider = context.read<SmartWhiteboardProvider>();

    try {
      await provider.updateStoryboard(_storyboard);

      if (provider.errorMessage != null) {
        _showError(provider.errorMessage!);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Storyboard sauvegardé, lancement du rendu...')),
      );

      await provider.createRenderJob();

      if (!mounted) return;

      if (provider.errorMessage != null) {
        _showError(provider.errorMessage!);
        return;
      }

      Navigator.of(context).pushNamed('/smart-whiteboard-preview');
    } catch (e) {
      _showError('Erreur: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Éditeur de Storyboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.movie_creation),
            onPressed: _saveAndRender,
            tooltip: 'Lancer le rendu',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveStoryboard,
          ),
        ],
      ),
      body: _isLoadingProject
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Text(_loadError!))
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _storyboard.scenes.length,
                  itemBuilder: (context, sceneIndex) {
                    final scene = _storyboard.scenes[sceneIndex];
                    return _buildSceneCard(scene, sceneIndex);
                  },
                ),
      floatingActionButton: _isLoadingProject || _loadError != null
          ? null
          : FloatingActionButton(
              onPressed: () {
                if (_storyboard.scenes.isNotEmpty) {
                  _addBlock(_storyboard.scenes.last);
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildSceneCard(Scene scene, int sceneIndex) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: Text('Scène ${sceneIndex + 1}: ${scene.title}'),
        subtitle: Text('${scene.blocks.length} bloc(s)'),
        children: [
          ...scene.blocks.asMap().entries.map((entry) {
            final blockIndex = entry.key;
            final block = entry.value;
            return _buildBlockTile(scene, block, blockIndex);
          }),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Ajouter un bloc'),
            onTap: () => _addBlock(scene),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockTile(Scene scene, Block block, int blockIndex) {
    final controller = _controllers[block.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: _getBlockIcon(block),
          title: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: _getBlockTypeLabel(block),
              hintText: _getBlockHint(block),
            ),
            maxLines: null,
            onChanged: (value) => _updateBlockContent(block.id, value),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed:
                    blockIndex > 0 ? () => _moveBlock(scene, block, -1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                onPressed: blockIndex < scene.blocks.length - 1
                    ? () => _moveBlock(scene, block, 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteBlock(scene, block),
              ),
            ],
          ),
        ),
        if (block is FormulaBlock) _buildFormulaPreview(block.content),
      ],
    );
  }

  Widget _buildFormulaPreview(String latex) {
    if (latex.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aperçu',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Math.tex(
              latex,
              textStyle: const TextStyle(fontSize: 22),
              onErrorFallback: (err) => Text(
                'Formule LaTeX invalide',
                style: TextStyle(color: Colors.red.shade400, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Icon _getBlockIcon(Block block) {
    if (block is TitleBlock) {
      return const Icon(Icons.title);
    } else if (block is ParagraphBlock) {
      return const Icon(Icons.text_fields);
    } else if (block is FormulaBlock) {
      return const Icon(Icons.functions);
    } else if (block is DefinitionBlock) {
      return const Icon(Icons.book);
    } else if (block is ExerciseBlock) {
      return const Icon(Icons.edit_note);
    } else if (block is CorrectionBlock) {
      return const Icon(Icons.check_circle);
    } else if (block is DiagramBlock) {
      return const Icon(Icons.account_tree);
    } else if (block is GraphBlock) {
      return const Icon(Icons.show_chart);
    }
    return const Icon(Icons.help);
  }

  String _getBlockTypeLabel(Block block) {
    if (block is TitleBlock) {
      return 'Titre';
    } else if (block is ParagraphBlock) {
      return 'Paragraphe';
    } else if (block is FormulaBlock) {
      return 'Formule (LaTeX)';
    } else if (block is DefinitionBlock) {
      return 'Définition';
    } else if (block is ExerciseBlock) {
      return 'Exercice';
    } else if (block is CorrectionBlock) {
      return 'Correction';
    } else if (block is DiagramBlock) {
      return 'Diagramme (Mermaid)';
    } else if (block is GraphBlock) {
      return 'Graphe de fonction';
    }
    return 'Bloc';
  }

  String _getBlockHint(Block block) {
    if (block is TitleBlock) {
      return 'Entrez le titre...';
    } else if (block is ParagraphBlock) {
      return 'Entrez le paragraphe...';
    } else if (block is FormulaBlock) {
      return r'Ex: \frac{-b \pm \sqrt{b^2-4ac}}{2a}';
    } else if (block is DefinitionBlock) {
      return 'Entrez la définition...';
    } else if (block is ExerciseBlock) {
      return 'Entrez l\'exercice...';
    } else if (block is CorrectionBlock) {
      return 'Entrez la correction...';
    } else if (block is DiagramBlock) {
      return 'Ex: graph TD; A-->B; B-->C';
    } else if (block is GraphBlock) {
      return 'Ex: y = x^2 - 2x + 1';
    }
    return 'Entrez le contenu...';
  }
}
