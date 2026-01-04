import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_communities_provider.dart';

class AdminCommunitiesScreen extends StatefulWidget {
  const AdminCommunitiesScreen({super.key});

  @override
  State<AdminCommunitiesScreen> createState() => _AdminCommunitiesScreenState();
}

class _AdminCommunitiesScreenState extends State<AdminCommunitiesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminCommunitiesProvider>().loadCommunities();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: const Text('Communautés - Admin'),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: context.read<AdminCommunitiesProvider>().loadCommunities,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recharger',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final provider = context.read<AdminCommunitiesProvider>();
          _showCommunityDialog(context, provider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle communauté'),
      ),
      body: Consumer<AdminCommunitiesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.communities.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.error!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: provider.loadCommunities,
                    child: const Text('Recharger'),
                  ),
                ],
              ),
            );
          }

          final communities = provider.communities;
          if (communities.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Aucune communauté n\'a encore été créée. Utilisez le bouton ci-dessous pour créer la première.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: communities.length,
            itemBuilder: (context, index) {
              final c = communities[index];
              final id = c['id']?.toString();
              final name = c['name']?.toString() ?? '';
              final description = c['description']?.toString() ?? '';
              final category = c['category']?.toString() ?? '';
              final visibility = c['visibility']?.toString() ?? '';
              final isActive = c['is_active'] != false;
              final isFeatured = c['is_featured'] == true;
              final kind = (c['kind']?.toString() ?? 'student_group');
              final status = (c['status']?.toString() ?? 'active');
              final moderationState =
                  (c['moderation_state']?.toString() ?? 'clean');
              final membersCount = c['members_count'] is int
                  ? c['members_count'] as int
                  : null;
              final postsCount = c['posts_count'] is int
                  ? c['posts_count'] as int
                  : null;

              final metaParts = <String>[];
              if (category.isNotEmpty) metaParts.add(category);
              if (visibility.isNotEmpty) metaParts.add('Visibilité: $visibility');
              if (membersCount != null) {
                metaParts.add('$membersCount membre${membersCount > 1 ? 's' : ''}');
              }
              if (postsCount != null) {
                metaParts.add('$postsCount message${postsCount > 1 ? 's' : ''}');
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                description,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  label: Text(
                                    kind == 'official'
                                        ? 'Officiel'
                                        : 'Groupe étudiant',
                                  ),
                                  backgroundColor: kind == 'official'
                                      ? const Color(0xFFE0F2FE)
                                      : const Color(0xFFE5F4EA),
                                ),
                                Chip(
                                  label: Text(
                                    () {
                                      switch (status) {
                                        case 'restricted':
                                          return 'Restreint';
                                        case 'suspended':
                                          return 'Suspendu';
                                        case 'closed':
                                          return 'Fermé';
                                        default:
                                          return 'Actif';
                                      }
                                    }(),
                                  ),
                                  backgroundColor: () {
                                    switch (status) {
                                      case 'restricted':
                                        return const Color(0xFFFFF7E0);
                                      case 'suspended':
                                      case 'closed':
                                        return const Color(0xFFFFE4E6);
                                      default:
                                        return const Color(0xFFE5F4EA);
                                    }
                                  }(),
                                ),
                                Chip(
                                  label: Text(
                                    () {
                                      switch (moderationState) {
                                        case 'flagged':
                                          return 'Signalé';
                                        case 'under_review':
                                          return 'En revue';
                                        default:
                                          return 'Clean';
                                      }
                                    }(),
                                  ),
                                  backgroundColor: () {
                                    switch (moderationState) {
                                      case 'flagged':
                                        return const Color(0xFFFFF7E0);
                                      case 'under_review':
                                        return const Color(0xFFE0EAFF);
                                      default:
                                        return const Color(0xFFE5F4EA);
                                    }
                                  }(),
                                ),
                              ],
                            ),
                            if (metaParts.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                metaParts.join(' • '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isActive,
                                onChanged: id == null
                                    ? null
                                    : (value) async {
                                        final ok = await provider
                                            .updateCommunityStatus(
                                          communityId: id,
                                          isActive: value,
                                        );
                                        if (!context.mounted) return;
                                        if (!ok && provider.error != null) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(provider.error!),
                                            ),
                                          );
                                        }
                                      },
                              ),
                              IconButton(
                                tooltip: isFeatured
                                    ? 'Retirer des communautés en vedette'
                                    : 'Mettre en vedette',
                                icon: Icon(
                                  isFeatured
                                      ? Icons.star
                                      : Icons.star_border,
                                  color:
                                      isFeatured ? Colors.orange : Colors.grey,
                                ),
                                onPressed: id == null
                                    ? null
                                    : () async {
                                        final ok = await provider
                                            .updateCommunityStatus(
                                          communityId: id,
                                          isFeatured: !isFeatured,
                                        );
                                        if (!context.mounted) return;
                                        if (!ok && provider.error != null) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(provider.error!),
                                            ),
                                          );
                                        }
                                      },
                              ),
                            ],
                          ),
                          IconButton(
                            tooltip: 'Modifier',
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              _showCommunityDialog(
                                context,
                                provider,
                                existing: c,
                              );
                            },
                          ),
                          TextButton.icon(
                            onPressed: id == null
                                ? null
                                : () {
                                    _openPostsDialog(context, provider, c);
                                  },
                            icon: const Icon(Icons.forum_outlined),
                            label: const Text('Messages'),
                          ),
                          TextButton.icon(
                            onPressed: id == null
                                ? null
                                : () {
                                    _openModerationDialog(
                                      context,
                                      provider,
                                      c,
                                    );
                                  },
                            icon: const Icon(Icons.shield_outlined),
                            label: const Text('Modération'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openModerationDialog(
    BuildContext context,
    AdminCommunitiesProvider provider,
    Map<String, dynamic> community,
  ) async {
    final communityId = community['id']?.toString() ?? '';
    final name = community['name']?.toString() ?? '';
    if (communityId.isEmpty) return;

    await provider.loadModerationEvents(communityId);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer<AdminCommunitiesProvider>(
          builder: (context, p, child) {
            final events = p.moderationEvents;
            return AlertDialog(
              title: Text('Modération - $name'),
              content: SizedBox(
                width: 480,
                height: 360,
                child: events.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun événement de modération pour cette communauté.',
                          style: TextStyle(fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          final eventId = event['id']?.toString() ?? '';
                          final source = event['source']?.toString() ?? '';
                          final reason = event['reason']?.toString() ?? '';
                          final createdAt =
                              (event['created_at'] ?? '').toString();
                          final resolvedAt =
                              (event['resolved_at'] ?? '').toString();
                          final isResolved =
                              resolvedAt.isNotEmpty && resolvedAt != 'null';

                          return Card(
                            margin:
                                const EdgeInsets.symmetric(vertical: 4.0),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reason.isEmpty
                                        ? '(raison non définie)'
                                        : reason,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Source: $source',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (createdAt.isNotEmpty)
                                    Text(
                                      'Créé: $createdAt',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  if (isResolved)
                                    Text(
                                      'Résolu: $resolvedAt',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: eventId.isEmpty || isResolved
                                            ? null
                                            : () async {
                                                final ok = await p
                                                    .resolveModerationEvent(
                                                  eventId: eventId,
                                                  resolution:
                                                      'Marqué comme clean depuis le panneau admin.',
                                                  newModerationState: 'clean',
                                                  newStatus: 'active',
                                                );
                                                if (!dialogContext.mounted) {
                                                  return;
                                                }
                                                if (!ok && p.error != null) {
                                                  ScaffoldMessenger.of(
                                                          dialogContext)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        p.error!,
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  await p.loadModerationEvents(
                                                    communityId,
                                                  );
                                                }
                                              },
                                        child: const Text(
                                          'Marquer clean',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Fermer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCommunityDialog(
    BuildContext context,
    AdminCommunitiesProvider provider, {
    Map<String, dynamic>? existing,
  }) async {
    final nameController =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final slugController =
        TextEditingController(text: existing?['slug']?.toString() ?? '');
    final descriptionController = TextEditingController(
      text: existing?['description']?.toString() ?? '',
    );
    final categoryController =
        TextEditingController(text: existing?['category']?.toString() ?? '');
    String visibility =
        existing?['visibility']?.toString() ?? 'public';
    bool isActive = existing == null || existing['is_active'] != false;
    bool isFeatured = existing?['is_featured'] == true;
    String kind = existing?['kind']?.toString() ?? 'student_group';
    String status = existing?['status']?.toString() ?? 'active';
    String moderationState =
        existing?['moderation_state']?.toString() ?? 'clean';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Nouvelle communauté'
                    : 'Modifier la communauté',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la communauté',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: slugController,
                      decoration: const InputDecoration(
                        labelText:
                            'Slug (optionnel, utilisé pour les URLs internes)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optionnelle)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText:
                            'Catégorie (optionnelle, ex: orientation, tech, campus...)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: kind,
                      decoration: const InputDecoration(
                        labelText: 'Type de communauté',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'student_group',
                          child: Text('Groupe étudiant'),
                        ),
                        DropdownMenuItem(
                          value: 'official',
                          child: Text('Officiel (piloté par Academia)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setStateDialog(() {
                          kind = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: 'Statut du groupe',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Actif'),
                        ),
                        DropdownMenuItem(
                          value: 'restricted',
                          child: Text('Restreint (visible, mais accès limité)'),
                        ),
                        DropdownMenuItem(
                          value: 'suspended',
                          child: Text('Suspendu temporairement'),
                        ),
                        DropdownMenuItem(
                          value: 'closed',
                          child: Text('Fermé (archivé)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setStateDialog(() {
                          status = value;
                          if (status == 'suspended' || status == 'closed') {
                            isActive = false;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: moderationState,
                      decoration: const InputDecoration(
                        labelText: 'État de modération',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'clean',
                          child: Text('Clean'),
                        ),
                        DropdownMenuItem(
                          value: 'flagged',
                          child: Text('Signalé'),
                        ),
                        DropdownMenuItem(
                          value: 'under_review',
                          child: Text('En revue'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setStateDialog(() {
                          moderationState = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: visibility,
                      decoration: const InputDecoration(
                        labelText: 'Visibilité',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'public',
                          child: Text('Publique'),
                        ),
                        DropdownMenuItem(
                          value: 'private',
                          child: Text('Privée (MVP: non listée)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setStateDialog(() {
                          visibility = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (value) {
                        setStateDialog(() {
                          isActive = value;
                        });
                      },
                      title: const Text('Actif'),
                    ),
                    SwitchListTile(
                      value: isFeatured,
                      onChanged: (value) {
                        setStateDialog(() {
                          isFeatured = value;
                        });
                      },
                      title: const Text('En vedette'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    final ok = await provider.upsertCommunity(
      communityId: existing?['id']?.toString(),
      slug: slugController.text.trim().isEmpty
          ? null
          : slugController.text.trim(),
      name: name,
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      category: categoryController.text.trim().isEmpty
          ? null
          : categoryController.text.trim(),
      visibility: visibility,
      isActive: isActive,
      isFeatured: isFeatured,
      kind: kind,
      status: status,
      moderationState: moderationState,
    );

    if (!mounted) return;
    if (!ok && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  Future<void> _openPostsDialog(
    BuildContext context,
    AdminCommunitiesProvider provider,
    Map<String, dynamic> community,
  ) async {
    final communityId = community['id']?.toString() ?? '';
    final name = community['name']?.toString() ?? '';
    if (communityId.isEmpty) return;

    await provider.loadPosts(communityId);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer<AdminCommunitiesProvider>(
          builder: (context, p, child) {
            final posts = p.posts;
            return AlertDialog(
              title: Text('Messages - $name'),
              content: SizedBox(
                width: 480,
                height: 360,
                child: posts.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun message dans cette communauté pour le moment.',
                          style: TextStyle(fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          final postId = post['id']?.toString() ?? '';
                          final authorId = post['author_id']?.toString() ?? '';
                          final content =
                              (post['content'] ?? '').toString();
                          final createdAt =
                              (post['created_at'] ?? '').toString();

                          return Card(
                            margin:
                                const EdgeInsets.symmetric(vertical: 4.0),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    content,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Auteur: $authorId',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (createdAt.isNotEmpty)
                                    Text(
                                      createdAt,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: postId.isEmpty
                                            ? null
                                            : () async {
                                                final ok = await p.deletePost(
                                                  postId,
                                                );
                                                if (!dialogContext.mounted) {
                                                  return;
                                                }
                                                if (!ok && p.error != null) {
                                                  ScaffoldMessenger.of(
                                                          dialogContext)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        p.error!,
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  await p.loadPosts(
                                                    communityId,
                                                  );
                                                }
                                              },
                                        child: const Text(
                                          'Supprimer',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: authorId.isEmpty
                                            ? null
                                            : () async {
                                                final ok = await p.banUser(
                                                  communityId: communityId,
                                                  userId: authorId,
                                                );
                                                if (!dialogContext.mounted) {
                                                  return;
                                                }
                                                if (!ok && p.error != null) {
                                                  ScaffoldMessenger.of(
                                                          dialogContext)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        p.error!,
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  ScaffoldMessenger.of(
                                                          dialogContext)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Utilisateur banni de cette communauté.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                        child: const Text(
                                          'Bannir auteur',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFEF4444),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Fermer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
