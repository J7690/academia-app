import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/smart_whiteboard_provider.dart';

/// Écran de liste des projets Smart Whiteboard
/// 
/// Permet de visualiser tous les projets de l'utilisateur,
/// de les filtrer par statut et d'effectuer des actions (éditer, supprimer, dupliquer).
class SmartWhiteboardProjectsListScreen extends StatefulWidget {
  const SmartWhiteboardProjectsListScreen({super.key});

  @override
  State<SmartWhiteboardProjectsListScreen> createState() => _SmartWhiteboardProjectsListScreenState();
}

class _SmartWhiteboardProjectsListScreenState extends State<SmartWhiteboardProjectsListScreen> {
  ProjectStatusFilter _selectedFilter = ProjectStatusFilter.all;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final provider = context.read<SmartWhiteboardProvider>();
    await provider.loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Projets'),
        backgroundColor: const Color(0xFF1EA75C),
        actions: [
          PopupMenuButton<ProjectStatusFilter>(
            icon: const Icon(Icons.filter_list),
            onSelected: (filter) {
              setState(() {
                _selectedFilter = filter;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ProjectStatusFilter.all,
                child: Text('Tous'),
              ),
              const PopupMenuItem(
                value: ProjectStatusFilter.draft,
                child: Text('Brouillons'),
              ),
              const PopupMenuItem(
                value: ProjectStatusFilter.generating,
                child: Text('En génération'),
              ),
              const PopupMenuItem(
                value: ProjectStatusFilter.ready,
                child: Text('Prêts'),
              ),
              const PopupMenuItem(
                value: ProjectStatusFilter.rendering,
                child: Text('En rendu'),
              ),
              const PopupMenuItem(
                value: ProjectStatusFilter.done,
                child: Text('Terminés'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<SmartWhiteboardProvider>(
        builder: (context, provider, child) {
          if (provider.state == SmartWhiteboardState.loading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final projects = _filterProjects(provider.projects);

          if (projects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun projet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/smart-whiteboard-input');
                    },
                    child: const Text('Créer un projet'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return _buildProjectCard(project);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/smart-whiteboard-input');
        },
        backgroundColor: const Color(0xFF1EA75C),
        child: const Icon(Icons.add),
      ),
    );
  }

  List<dynamic> _filterProjects(List<dynamic> projects) {
    switch (_selectedFilter) {
      case ProjectStatusFilter.all:
        return projects;
      case ProjectStatusFilter.draft:
        return projects.where((p) => p['status'] == 'draft').toList();
      case ProjectStatusFilter.generating:
        return projects.where((p) => p['status'] == 'generating').toList();
      case ProjectStatusFilter.ready:
        return projects.where((p) => p['status'] == 'ready').toList();
      case ProjectStatusFilter.rendering:
        return projects.where((p) => p['status'] == 'rendering').toList();
      case ProjectStatusFilter.done:
        return projects.where((p) => p['status'] == 'done').toList();
    }
  }

  Widget _buildProjectCard(dynamic project) {
    final status = project['status'] as String;
    final subject = project['subject'] as String;
    final createdAt = project['created_at'] as String;

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: _getStatusIcon(status),
        title: Text(subject),
        subtitle: Text('Créé le ${_formatDate(createdAt)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _handleEdit(project),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _handleDelete(project),
            ),
          ],
        ),
        onTap: () => _handleTap(project),
      ),
    );
  }

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'draft':
        return const Icon(Icons.edit_note, color: Colors.grey);
      case 'generating':
        return const Icon(Icons.autorenew, color: Colors.blue);
      case 'ready':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'rendering':
        return const Icon(Icons.movie_creation, color: Colors.orange);
      case 'done':
        return const Icon(Icons.play_circle, color: Colors.green);
      default:
        return const Icon(Icons.help);
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _handleEdit(dynamic project) {
    final projectId = project['id'] as String;
    Navigator.pushNamed(
      context,
      '/smart-whiteboard-editor',
      arguments: {'projectId': projectId},
    );
  }

  void _handleDelete(dynamic project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le projet'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce projet ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(project);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(dynamic project) async {
    final provider = context.read<SmartWhiteboardProvider>();
    await provider.deleteProject(project['id'] as String);

    if (!mounted) return;

    if (provider.state == SmartWhiteboardState.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${provider.errorMessage}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Projet supprimé')),
      );
      _loadProjects();
    }
  }

  void _handleTap(dynamic project) {
    final status = project['status'] as String;
    
    if (status == 'done') {
      final renderId = project['render_id'] as String?;
      final videoUrl = project['video_url'] as String?;
      Navigator.pushNamed(
        context,
        '/smart-whiteboard-preview',
        arguments: {
          'projectId': project['id'],
          'renderId': renderId,
          'videoUrl': videoUrl,
        },
      );
    } else {
      Navigator.pushNamed(
        context,
        '/smart-whiteboard-editor',
        arguments: {'projectId': project['id']},
      );
    }
  }
}

enum ProjectStatusFilter {
  all,
  draft,
  generating,
  ready,
  rendering,
  done,
}
