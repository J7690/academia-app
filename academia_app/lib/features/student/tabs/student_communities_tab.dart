import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_communities_provider.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../student_community_detail_screen.dart';

class StudentCommunitiesTab extends StatefulWidget {
  const StudentCommunitiesTab({super.key});

  @override
  State<StudentCommunitiesTab> createState() => _StudentCommunitiesTabState();
}

class _StudentCommunitiesTabState extends State<StudentCommunitiesTab> {
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StudentCommunitiesProvider>();
      provider.loadCommunities();
      provider.loadMyCommunities();
      provider.loadMyCommunitiesActivity();
      provider.loadMyChats();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final provider = context.read<StudentCommunitiesProvider>();
    await provider.loadCommunities(
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
    await provider.loadMyCommunities();
    await provider.loadMyCommunitiesActivity();
    await provider.loadMyChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateGroupSheet,
        backgroundColor: const Color(0xFF1EA75C),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Communautés',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Un endroit pour discuter, poser des questions et réviser avec d\'autres étudiants.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Rechercher une communauté (nom, description, catégorie...)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim();
                      });
                      _reload();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<StudentCommunitiesProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading && provider.communities.isEmpty) {
                    return const LoadingWidget(
                      message: 'Chargement des communautés...',
                    );
                  }

                  if (provider.error != null && provider.communities.isEmpty) {
                    return CustomErrorWidget(
                      error: provider.error!,
                      onRetry: _reload,
                    );
                  }

                  final all = provider.communities;
                  final unreadById = provider.unreadByCommunityId;
                  final chats = provider.myChats;

                  // Construire un index des dates de jointure à partir de la RPC "mes communautés"
                  final joinedAtById = <String, DateTime>{};
                  for (final mc in provider.myCommunities) {
                    final id = mc['community_id']?.toString();
                    final joinedAtRaw = mc['joined_at']?.toString();
                    if (id == null || joinedAtRaw == null) continue;
                    final parsed = DateTime.tryParse(joinedAtRaw);
                    if (parsed != null) {
                      joinedAtById[id] = parsed;
                    }
                  }

                  final my = all
                      .where((c) => c['is_member'] == true)
                      .toList(growable: true);

                  // Trier les communautés de l'étudiant par date de jointure (les plus récentes en premier)
                  my.sort((a, b) {
                    final idA = a['id']?.toString();
                    final idB = b['id']?.toString();
                    final dateA =
                        idA != null ? joinedAtById[idA] : null;
                    final dateB =
                        idB != null ? joinedAtById[idB] : null;

                    if (dateA == null && dateB == null) return 0;
                    if (dateA == null) return 1;
                    if (dateB == null) return -1;
                    return dateB.compareTo(dateA);
                  });

                  final discover = all
                      .where((c) => c['is_member'] != true)
                      .toList(growable: false);

                  return RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        _buildChatsSection(context, chats),
                        const SizedBox(height: 16),
                        _buildSection(
                          context: context,
                          title: 'Mes discussions actives',
                          emptyText:
                              'Tu n\'as encore rejoint aucune communauté. Rejoins un groupe ci-dessous pour commencer à échanger.',
                          communities: my,
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          context: context,
                          title: 'Découvrir par centres d\'intérêt',
                          emptyText:
                              'Aucune communauté ne correspond à ta recherche pour le moment.',
                          communities: discover,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formate l'heure style WhatsApp (ex: 14:30, Hier, 25/12/2025)
  String _formatWhatsAppTime(String? rawDateTime) {
    if (rawDateTime == null) return '';
    final parsed = DateTime.tryParse(rawDateTime);
    if (parsed == null) return '';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(parsed.year, parsed.month, parsed.day);
    
    if (messageDate == today) {
      // Aujourd'hui : afficher l'heure (format 24h comme WhatsApp)
      return DateFormat('HH:mm').format(parsed);
    } else if (messageDate == yesterday) {
      return 'Hier';
    } else if (now.difference(parsed).inDays < 7) {
      // Cette semaine : afficher le jour
      return DateFormat('EEEE', 'fr_FR').format(parsed);
    } else {
      // Plus ancien : afficher la date
      return DateFormat('dd/MM/yyyy').format(parsed);
    }
  }

  Widget _buildChatsSection(
    BuildContext context,
    List<Map<String, dynamic>> chats,
  ) {
    // Style WhatsApp : fond blanc, pas de card arrondie
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chats.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Crée ton premier groupe ou rejoins une communauté pour commencer à discuter.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final communityId = chat['community_id']?.toString() ?? '';
                final name = chat['name']?.toString() ?? '';
                final lastMessage = chat['last_message_content']?.toString() ?? '';
                final authorDisplay =
                    chat['last_message_author_display']?.toString() ?? '';
                final dynamic rawUnread = chat['unread_count'];
                int unreadCount = 0;
                if (rawUnread is int) {
                  unreadCount = rawUnread;
                } else if (rawUnread is num) {
                  unreadCount = rawUnread.toInt();
                }
                final lastMessageAtRaw = chat['last_message_at']?.toString();
                final timeLabel = _formatWhatsAppTime(lastMessageAtRaw);

                final bool isUnread = unreadCount > 0;
                final String previewText;
                if (lastMessage.isEmpty) {
                  previewText = 'Aucun message pour le moment';
                } else if (authorDisplay.isNotEmpty) {
                  previewText = '$authorDisplay: $lastMessage';
                } else {
                  previewText = lastMessage;
                }

                return InkWell(
                  onTap: communityId.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudentCommunityDetailScreen(
                                communityId: communityId,
                                initialName: name,
                                initialDescription:
                                    chat['description']?.toString() ?? '',
                              ),
                            ),
                          );
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Avatar style WhatsApp (plus grand, 50px)
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: _getAvatarColor(name),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    timeLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isUnread
                                          ? const Color(0xFF25D366)
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      previewText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isUnread
                                            ? Colors.black87
                                            : Colors.grey.shade600,
                                        fontWeight: isUnread
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF25D366),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        unreadCount > 99 ? '99+' : '$unreadCount',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Génère une couleur d'avatar basée sur le nom (style WhatsApp)
  Color _getAvatarColor(String name) {
    if (name.isEmpty) return Colors.grey;
    final colors = [
      const Color(0xFF25D366), // Vert WhatsApp
      const Color(0xFF128C7E), // Teal WhatsApp
      const Color(0xFF075E54), // Vert foncé WhatsApp
      const Color(0xFF34B7F1), // Bleu WhatsApp
      const Color(0xFFE91E63), // Rose
      const Color(0xFF9C27B0), // Violet
      const Color(0xFF673AB7), // Violet foncé
      const Color(0xFF3F51B5), // Indigo
      const Color(0xFFFF5722), // Orange
      const Color(0xFF795548), // Marron
    ];
    final index = name.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  void _openCreateGroupSheet() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final categoryController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottomInset + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nouveau groupe',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du groupe *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Catégorie (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final provider =
                        context.read<StudentCommunitiesProvider>();
                    final communityId = await provider.createGroup(
                      name: nameController.text,
                      description: descriptionController.text,
                      category: categoryController.text.isEmpty
                          ? null
                          : categoryController.text,
                    );
                    if (!mounted) return;
                    if (communityId == null) {
                      if (provider.error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(provider.error!)),
                        );
                      }
                      return;
                    }

                    Navigator.of(context).pop();

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentCommunityDetailScreen(
                          communityId: communityId,
                          initialName: nameController.text.trim(),
                          initialDescription: descriptionController.text.trim(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Créer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1EA75C),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required String emptyText,
    required List<Map<String, dynamic>> communities,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        int crossAxisCount;
        if (maxWidth < 600) {
          crossAxisCount = 1;
        } else if (maxWidth < 1000) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 3;
        }
        final spacing = 12.0;
        final itemWidth =
            (maxWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;

        return Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (communities.isEmpty)
                  Text(
                    emptyText,
                    style: const TextStyle(fontSize: 13),
                  )
                else
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final c in communities)
                        SizedBox(
                          width: itemWidth,
                          child: _buildCommunityCard(context, c),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommunityCard(BuildContext context, Map<String, dynamic> c) {
    final id = c['id']?.toString() ?? '';
    final name = c['name']?.toString() ?? '';
    final description = c['description']?.toString() ?? '';
    final category = c['category']?.toString() ?? '';
    final isMember = c['is_member'] == true;
    final unreadCount = context
        .read<StudentCommunitiesProvider>()
        .unreadByCommunityId[id] ??
        0;
    final membersCount = c['members_count'] is int ? c['members_count'] as int : null;

    final subtitleParts = <String>[];
    if (category.isNotEmpty) subtitleParts.add(category);
    if (membersCount != null) {
      subtitleParts.add('$membersCount membre${membersCount > 1 ? 's' : ''}');
    }

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: id.isEmpty
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StudentCommunityDetailScreen(
                      communityId: id,
                      initialName: name,
                      initialDescription: description,
                    ),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              if (description.isNotEmpty)
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              if (subtitleParts.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitleParts.join(' • '),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              if (isMember && unreadCount > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1EA75C),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$unreadCount message${unreadCount > 1 ? 's' : ''} non lus',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              if (isMember) ...[
                const SizedBox(height: 4),
                const Text(
                  'Tu es membre de ce groupe. Appuie pour reprendre la discussion.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: _buildMembershipButton(context, id, isMember),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipButton(
    BuildContext context,
    String communityId,
    bool isMember,
  ) {
    final provider = context.read<StudentCommunitiesProvider>();
    if (provider.isSaving) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return TextButton(
      onPressed: communityId.isEmpty
          ? null
          : () async {
              final ok = isMember
                  ? await provider.leaveCommunity(communityId: communityId)
                  : await provider.joinCommunity(communityId: communityId);
              if (!mounted) return;
              if (!ok && provider.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(provider.error!)),
                );
              }
            },
      child: Text(
        isMember ? 'Quitter' : 'Rejoindre',
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}
