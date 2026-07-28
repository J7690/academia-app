import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_communities_provider.dart';
import '../../widgets/adaptive_dialog.dart';

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
      useSafeArea: true,
      builder: (dialogContext) {
        return Consumer<AdminCommunitiesProvider>(
          builder: (context, p, child) {
            final posts = p.posts;
            return AdaptiveDialog(
              maxWidth: 560,
              title: Text('Messages - $name'),
              child: posts.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Aucun message pour cette communauté.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          final postId = post['id']?.toString() ?? '';
                          final content =
                              (post['content'] ?? '').toString();
                          final isPinned = post['is_pinned'] == true;
                          final createdAt =
                              (post['created_at'] ?? '').toString();

                          return Card(
                            margin:
                                const EdgeInsets.symmetric(vertical: 4.0),
                            child: ListTile(
                              title: Text(
                                content.isNotEmpty
                                    ? content
                                    : '(message sans texte)',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                createdAt.isNotEmpty
                                    ? createdAt
                                    : '',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: isPinned
                                        ? 'Retirer des messages épinglés'
                                        : 'Épingler ce message',
                                    icon: Icon(
                                      isPinned
                                          ? Icons.push_pin
                                          : Icons.push_pin_outlined,
                                      color: isPinned
                                          ? Colors.orange
                                          : Colors.grey,
                                    ),
                                    onPressed: postId.isEmpty
                                        ? null
                                        : () async {
                                            final ok =
                                                await p.pinPost(
                                              postId: postId,
                                              isPinned: !isPinned,
                                            );
                                            if (!dialogContext.mounted) return;
                                            if (!ok && p.error != null) {
                                              ScaffoldMessenger.of(
                                                      dialogContext)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(p.error!),
                                                ),
                                              );
                                            } else {
                                              await p.loadPosts(communityId);
                                            }
                                          },
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: postId.isEmpty
                                        ? null
                                        : () async {
                                            final ok = await p.deletePost(
                                              postId,
                                            );
                                            if (!dialogContext.mounted) return;
                                            if (!ok && p.error != null) {
                                              ScaffoldMessenger.of(
                                                      dialogContext)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(p.error!),
                                                ),
                                              );
                                            } else {
                                              await p.loadPosts(communityId);
                                            }
                                          },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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

  Future<void> _confirmDeleteCommunity(
    BuildContext context,
    AdminCommunitiesProvider provider,
    Map<String, dynamic> community,
  ) async {
    final communityId = community['id']?.toString() ?? '';
    final name = community['name']?.toString() ?? '';
    if (communityId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      useSafeArea: true,
      builder: (dialogContext) {
        return AdaptiveDialog(
          maxWidth: 460,
          title: const Text('Supprimer la communauté'),
          child: Text(
            'Cette opération supprimera définitivement le groupe "$name" et toutes ses données associées (messages, membres, sondages...). Continuer ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final ok = await provider.deleteCommunity(communityId: communityId);
    if (!mounted) return;
    if (!ok && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  Future<void> _openMembersDialog(
    BuildContext context,
    AdminCommunitiesProvider provider,
    Map<String, dynamic> community,
  ) async {
    final communityId = community['id']?.toString() ?? '';
    final name = community['name']?.toString() ?? '';
    if (communityId.isEmpty) return;

    await provider.loadMembers(communityId);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (dialogContext) {
        return Consumer<AdminCommunitiesProvider>(
          builder: (context, p, child) {
            final members = p.members;
            return AdaptiveDialog(
              maxWidth: 520,
              title: Text('Membres - $name'),
              child: members.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Aucun membre pour cette communauté.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final m = members[index];
                          final userId = m['user_id']?.toString() ?? '';
                          final displayName =
                              (m['user_display_name'] ?? '').toString();
                          final email = (m['user_email'] ?? '').toString();
                          final role = (m['role'] ?? '').toString();
                          final isActive = m['is_active'] != false;
                          final isBanned = m['is_banned'] == true;

                          return ListTile(
                            title: Text(
                              displayName.isNotEmpty
                                  ? displayName
                                  : email,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              [
                                if (email.isNotEmpty) email,
                                if (role.isNotEmpty) 'Rôle: $role',
                                if (isBanned)
                                  'Banni'
                                else if (isActive)
                                  'Actif'
                                else
                                  'Inactif',
                              ].join(' • '),
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isBanned)
                                  IconButton(
                                    tooltip: 'Retirer du groupe',
                                    icon: const Icon(
                                      Icons.person_remove_alt_1_outlined,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: userId.isEmpty
                                        ? null
                                        : () async {
                                            final ok = await p.banUser(
                                              communityId: communityId,
                                              userId: userId,
                                            );
                                            if (!dialogContext.mounted) return;
                                            if (!ok && p.error != null) {
                                              ScaffoldMessenger.of(
                                                      dialogContext)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(p.error!),
                                                ),
                                              );
                                            } else {
                                              await p.loadMembers(
                                                communityId,
                                              );
                                            }
                                          },
                                  ),
                              ],
                            ),
                          );
                        },
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

  Future<void> _openJoinRequestsDialog(
    BuildContext context,
    AdminCommunitiesProvider provider,
    Map<String, dynamic> community,
  ) async {
    final communityId = community['id']?.toString() ?? '';
    final name = community['name']?.toString() ?? '';
    if (communityId.isEmpty) return;

    await provider.loadJoinRequests(communityId);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (dialogContext) {
        return Consumer<AdminCommunitiesProvider>(
          builder: (context, p, child) {
            final requests = p.joinRequests;
            return AdaptiveDialog(
              maxWidth: 520,
              title: Text('Demandes d\'adhésion - $name'),
              child: requests.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Aucune demande d\'adhésion en attente pour cette communauté.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final r = requests[index];
                          final requestId = r['id']?.toString() ?? '';
                          final displayName =
                              (r['user_display_name'] ?? '').toString();
                          final email = (r['user_email'] ?? '').toString();
                          final createdAt = (r['created_at'] ?? '').toString();

                          return ListTile(
                            title: Text(
                              displayName.isNotEmpty
                                  ? displayName
                                  : email,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              createdAt.isNotEmpty
                                  ? 'Demande créée le $createdAt'
                                  : 'Demande en attente',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Refuser',
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: requestId.isEmpty
                                      ? null
                                      : () async {
                                          final ok =
                                              await p.handleJoinRequest(
                                            communityId: communityId,
                                            requestId: requestId,
                                            action: 'reject',
                                          );
                                          if (!dialogContext.mounted) return;
                                          if (!ok && p.error != null) {
                                            ScaffoldMessenger.of(dialogContext)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(p.error!),
                                              ),
                                            );
                                          }
                                        },
                                ),
                                IconButton(
                                  tooltip: 'Accepter',
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  ),
                                  onPressed: requestId.isEmpty
                                      ? null
                                      : () async {
                                          final ok =
                                              await p.handleJoinRequest(
                                            communityId: communityId,
                                            requestId: requestId,
                                            action: 'accept',
                                          );
                                          if (!dialogContext.mounted) return;
                                          if (!ok && p.error != null) {
                                            ScaffoldMessenger.of(dialogContext)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(p.error!),
                                              ),
                                            );
                                          }
                                        },
                                ),
                              ],
                            ),
                          );
                        },
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

              final info = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                          kind == 'official' ? 'Officiel' : 'Groupe étudiant',
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
              );

              final toggles = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: isActive,
                    onChanged: id == null
                        ? null
                        : (value) async {
                            final ok = await provider.updateCommunityStatus(
                              communityId: id,
                              isActive: value,
                            );
                            if (!context.mounted) return;
                            if (!ok && provider.error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(provider.error!)),
                              );
                            }
                          },
                  ),
                  IconButton(
                    tooltip: isFeatured
                        ? 'Retirer des communautés en vedette'
                        : 'Mettre en vedette',
                    icon: Icon(
                      isFeatured ? Icons.star : Icons.star_border,
                      color: isFeatured ? Colors.orange : Colors.grey,
                    ),
                    onPressed: id == null
                        ? null
                        : () async {
                            final ok = await provider.updateCommunityStatus(
                              communityId: id,
                              isFeatured: !isFeatured,
                            );
                            if (!context.mounted) return;
                            if (!ok && provider.error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(provider.error!)),
                              );
                            }
                          },
                  ),
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      _showCommunityDialog(context, provider, existing: c);
                    },
                  ),
                ],
              );

              final secondaryActions = Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: id == null
                        ? null
                        : () => _openMembersDialog(context, provider, c),
                    icon: const Icon(Icons.group_outlined, size: 18),
                    label: const Text('Membres'),
                  ),
                  TextButton.icon(
                    onPressed: id == null
                        ? null
                        : () => _openJoinRequestsDialog(context, provider, c),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('Demandes'),
                  ),
                  TextButton.icon(
                    onPressed: id == null
                        ? null
                        : () => _openPostsDialog(context, provider, c),
                    icon: const Icon(Icons.forum_outlined, size: 18),
                    label: const Text('Messages'),
                  ),
                  TextButton.icon(
                    onPressed: id == null
                        ? null
                        : () => _openModerationDialog(context, provider, c),
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    label: const Text('Modération'),
                  ),
                  TextButton.icon(
                    onPressed: id == null
                        ? null
                        : () => _confirmDeleteCommunity(context, provider, c),
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 18),
                    label: const Text('Supprimer'),
                  ),
                ],
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 520;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: narrow
                            ? [info, const SizedBox(height: 8), toggles, secondaryActions]
                            : [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: info),
                                    const SizedBox(width: 8),
                                    toggles,
                                  ],
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: secondaryActions,
                                ),
                              ],
                      );
                    },
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
      useSafeArea: true,
      builder: (dialogContext) {
        return Consumer<AdminCommunitiesProvider>(
          builder: (context, p, child) {
            final events = p.moderationEvents;
            return AdaptiveDialog(
              maxWidth: 520,
              title: Text('Modération - $name'),
              child: events.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Aucun événement de modération pour cette communauté.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
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
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AdaptiveDialog(
              title: Text(
                existing == null
                    ? 'Nouvelle communauté'
                    : 'Modifier la communauté',
              ),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
}
