import 'package:flutter/material.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
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
              const Spacer(),
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
