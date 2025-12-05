import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../providers/student_challenges_provider.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/student_video_player.dart';
import '../student_challenge_detail_screen.dart';
import '../student_challenge_video_editor_screen.dart';
import '../student_profile_screen.dart';

class StudentChallengesTab extends StatefulWidget {
  const StudentChallengesTab({super.key});

  @override
  State<StudentChallengesTab> createState() => _StudentChallengesTabState();
}

class _StudentChallengesTabState extends State<StudentChallengesTab> {
  String _searchQuery = '';
  String _typeFilter = 'all'; // all, mission, contest
  bool _onlyJoined = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StudentChallengesProvider>();
      provider.loadChallenges();
      provider.loadMyParticipations();
      provider.loadStats();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final provider = context.read<StudentChallengesProvider>();
    final type = _typeFilter == 'all' ? null : _typeFilter;
    await provider.loadChallenges(
      type: type,
      search: _searchQuery.isEmpty ? null : _searchQuery,
      onlyJoined: _onlyJoined,
    );
    await Future.wait([
      provider.loadMyParticipations(),
      provider.loadStats(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: SafeArea(
          child: Column(
            children: [
              Builder(
                builder: (context) {
                  final tabController = DefaultTabController.of(context);
                  if (tabController == null) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _buildHeaderContent(),
                    );
                  }
                  return AnimatedBuilder(
                    animation: tabController,
                    builder: (context, _) {
                      final isVideosTab = tabController.index == 1;
                      if (isVideosTab) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: _buildHeaderContent(),
                      );
                    },
                  );
                },
              ),
              const TabBar(
                labelColor: Color(0xFF1EA75C),
                unselectedLabelColor: Colors.black87,
                indicatorColor: Color(0xFF1EA75C),
                tabs: [
                  Tab(text: 'Challenges'),
                  Tab(text: 'Vidéos de challenges'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildChallengesList(),
                    const _ChallengeVideosFeed(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildHeaderContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Challenges',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Participe à des missions et concours pour gagner des points et progresser.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        Consumer<StudentChallengesProvider>(
          builder: (context, provider, child) {
            final stats = provider.stats;
            if (stats == null) {
              return const SizedBox.shrink();
            }
            final totalJoined = stats['total_joined'] as int? ?? 0;
            final totalCompleted = stats['total_completed'] as int? ?? 0;
            final totalPoints = stats['total_points'] as int? ?? 0;
            return Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Challenges rejoints', totalJoined),
                    _buildStatItem('Terminés', totalCompleted),
                    _buildStatItem('Points gagnés', totalPoints),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Rechercher un challenge (titre, description...)',
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
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildTypeChip('Tous', 'all'),
            _buildTypeChip('Missions', 'mission'),
            _buildTypeChip('Concours', 'contest'),
            FilterChip(
              label: const Text(
                'Mes challenges',
                style: TextStyle(fontSize: 13),
              ),
              selected: _onlyJoined,
              onSelected: (selected) {
                setState(() {
                  _onlyJoined = selected;
                });
                _reload();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String label, String value) {
    final selected = _typeFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: selected ? const Color(0xFF006D3C) : Colors.black87,
        ),
      ),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _typeFilter = value;
        });
        _reload();
      },
      selectedColor: const Color(0xFFE5F9E7),
      backgroundColor: const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? const Color(0xFF1EA75C) : Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildChallengesList() {
    return Consumer<StudentChallengesProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.challenges.isEmpty) {
          return const LoadingWidget(
            message: 'Chargement des challenges...',
          );
        }

        if (provider.error != null && provider.challenges.isEmpty) {
          return CustomErrorWidget(
            error: provider.error!,
            onRetry: _reload,
          );
        }

        final all = provider.challenges;
        final my = all
            .where((c) => c['is_joined'] == true)
            .toList(growable: false);
        final discover = all
            .where((c) => c['is_joined'] != true)
            .toList(growable: false);

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _buildSection(
                context: context,
                title: 'Mes challenges',
                emptyText:
                    'Tu n\'as pas encore rejoint de challenge. Découvre ceux disponibles ci-dessous.',
                challenges: my,
              ),
              const SizedBox(height: 16),
              _buildSection(
                context: context,
                title: 'Découvrir des challenges',
                emptyText:
                    'Aucun challenge ne correspond à ta recherche pour le moment.',
                challenges: discover,
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
    required List<Map<String, dynamic>> challenges,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final crossAxisCount = maxWidth > 700 ? 3 : 2;
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
                if (challenges.isEmpty)
                  Text(
                    emptyText,
                    style: const TextStyle(fontSize: 13),
                  )
                else
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final c in challenges)
                        SizedBox(
                          width: itemWidth,
                          child: _buildChallengeTile(context, c),
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

  Widget _buildChallengeTile(BuildContext context, Map<String, dynamic> c) {
    final id = c['id']?.toString() ?? '';
    final title = c['title']?.toString() ?? '';
    final description = c['description']?.toString() ?? '';
    final type = c['challenge_type']?.toString() ?? '';
    final difficulty = c['difficulty']?.toString() ?? '';
    final points = c['points'] is int ? c['points'] as int : null;
    final participantsCount = c['participants_count'] is int
        ? c['participants_count'] as int
        : null;
    final myStatus = c['my_status']?.toString() ?? '';
    final myScore = c['my_score'] is int ? c['my_score'] as int : null;
    final isJoined = c['is_joined'] == true;

    final metaParts = <String>[];
    if (type.isNotEmpty) metaParts.add(type == 'mission' ? 'Mission' : 'Concours');
    if (difficulty.isNotEmpty) metaParts.add('Difficulté: $difficulty');
    if (points != null && points > 0) metaParts.add('$points points');
    if (participantsCount != null) {
      metaParts.add('$participantsCount participant${participantsCount > 1 ? 's' : ''}');
    }

    String secondaryLine = '';
    if (myStatus.isNotEmpty) {
      secondaryLine = 'Mon statut: $myStatus';
      if (myScore != null) {
        secondaryLine = '$secondaryLine • Score: $myScore';
      }
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
                    builder: (_) => StudentChallengeDetailScreen(
                      challengeId: id,
                      initialTitle: title,
                      initialDescription: description,
                      initialType: type,
                      initialDifficulty: difficulty,
                      initialPoints: points ?? 0,
                      requiresSubmission:
                          c['requires_submission'] == true,
                      requiresAdminReview:
                          c['requires_admin_review'] == true,
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
                title,
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
              if (metaParts.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  metaParts.join(' • '),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              if (secondaryLine.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  secondaryLine,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: _buildActionButton(context, id, isJoined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String challengeId,
    bool isJoined,
  ) {
    final provider = context.read<StudentChallengesProvider>();
    if (provider.isSaving) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return TextButton(
      onPressed: challengeId.isEmpty
          ? null
          : () async {
              if (!isJoined) {
                final ok = await provider.joinChallenge(
                  challengeId: challengeId,
                );
                if (!mounted) return;
                if (!ok && provider.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.error!)),
                  );
                }
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StudentChallengeDetailScreen(
                      challengeId: challengeId,
                      initialTitle: '',
                      initialDescription: '',
                      initialType: '',
                      initialDifficulty: '',
                      initialPoints: 0,
                      requiresSubmission: false,
                      requiresAdminReview: false,
                    ),
                  ),
                );
              }
            },
      child: Text(
        isJoined ? 'Voir' : 'Rejoindre',
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

class _ChallengeVideosFeed extends StatefulWidget {
  const _ChallengeVideosFeed();

  @override
  State<_ChallengeVideosFeed> createState() => _ChallengeVideosFeedState();
}

class _ChallengeVideosFeedState extends State<_ChallengeVideosFeed> {
  bool _initialized = false;
  final PageController _pageController = PageController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _initialized) return;
      _initialized = true;
      final provider = context.read<StudentChallengesProvider>();
      await provider.loadChallengeVideos(limit: _pageSize);
      if (!mounted) return;
      final videos = provider.videos;
      setState(() {
        _hasMore = videos.length >= _pageSize;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentChallengesProvider>(
      builder: (context, provider, child) {
        final videos = provider.videos;

        if (provider.isLoading && videos.isEmpty) {
          return const LoadingWidget(
            message: 'Chargement des vidéos de challenges...',
          );
        }

        if (provider.error != null && videos.isEmpty) {
          return CustomErrorWidget(
            error: provider.error!,
            onRetry: () => provider.loadChallengeVideos(),
          );
        }

        if (videos.isEmpty) {
          return _buildEmptyTikTokShell(context);
        }

        return Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: videos.length,
              onPageChanged: (index) {
                _loadMoreIfNeeded(index, videos);
              },
              itemBuilder: (context, index) {
                final video = videos[index];
                return _ChallengeVideoItem(video: video);
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: _buildTikTokBottomBar(context),
            ),
            if (_isLoadingMore)
              Positioned(
                right: 16,
                top: 40,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _loadMoreIfNeeded(int currentIndex, List<Map<String, dynamic>> videos) async {
    if (!_hasMore || _isLoadingMore) {
      return;
    }
    if (videos.isEmpty) {
      return;
    }
    final thresholdIndex = videos.length - 3;
    if (currentIndex < thresholdIndex) {
      return;
    }
    final last = videos.last;
    final createdAtRaw = last['created_at']?.toString() ?? '';
    if (createdAtRaw.isEmpty) {
      return;
    }
    DateTime? cursor;
    try {
      cursor = DateTime.parse(createdAtRaw);
    } catch (_) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
    });
    final provider = context.read<StudentChallengesProvider>();
    final beforeCount = provider.videos.length;
    await provider.loadChallengeVideos(
      cursor: cursor,
      limit: _pageSize,
      append: true,
    );
    if (!mounted) {
      return;
    }
    final afterCount = provider.videos.length;
    final fetched = afterCount - beforeCount;
    setState(() {
      _isLoadingMore = false;
      if (fetched < _pageSize) {
        _hasMore = false;
      }
    });
  }

  void _goToFeedHome() {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildTikTokBottomBar(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompact = screenHeight < 700;

    final double iconSize = isCompact ? 20 : 22;
    final double labelFontSize = isCompact ? 11 : 13;
    final double centralButtonSize = isCompact ? 34 : 40;
    final double centralIconSize = isCompact ? 20 : 22;
    final double verticalPadding = isCompact ? 3 : 5;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 52),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: _goToFeedHome,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.home,
                          color: Colors.white,
                          size: iconSize,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Flux',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: labelFontSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _openCreateVideoFromFeed(context),
                  child: Container(
                    width: centralButtonSize,
                    height: centralButtonSize,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(centralButtonSize / 2),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: centralIconSize,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: iconSize,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StudentProfileScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Profil',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: labelFontSize,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTikTokShell(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.slow_motion_video,
                color: Colors.white70,
                size: 72,
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucune vidéo de challenge n\'est disponible pour le moment.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sois le premier à en publier une en créant une vidéo de challenge.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _openCreateVideoFromFeed(context),
                icon: const Icon(Icons.videocam),
                label: const Text('Créer une vidéo de challenge'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _askVideoCreationMode(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Comment veux-tu créer ta vidéo ?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Se filmer avec la caméra'),
                onTap: () {
                  Navigator.of(sheetContext).pop('camera');
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Uploader une vidéo depuis l\'appareil'),
                onTap: () {
                  Navigator.of(sheetContext).pop('gallery');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCreateVideoFromFeed(BuildContext context) async {
    final provider = context.read<StudentChallengesProvider>();
    final participations = provider.participations;

    if (participations.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Aucun challenge rejoint'),
            content: const Text(
              'Pour créer une vidéo de challenge, tu dois d\'abord rejoindre un challenge depuis l\'onglet "Challenges".',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    final selection = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Choisis le challenge pour ta vidéo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: participations.length,
                  itemBuilder: (itemContext, index) {
                    final p = participations[index];
                    final participationId =
                        p['participation_id']?.toString() ??
                            p['id']?.toString() ??
                            '';
                    final challengeId = p['challenge_id']?.toString() ?? '';
                    final title = p['title']?.toString() ?? 'Challenge';

                    if (participationId.isEmpty || challengeId.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return ListTile(
                      title: Text(title),
                      onTap: () {
                        Navigator.of(sheetContext).pop(<String, String>{
                          'challenge_id': challengeId,
                          'participation_id': participationId,
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selection == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final mode = await _askVideoCreationMode(context);
    if (mode == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final challengeId = selection['challenge_id'];
    final participationId = selection['participation_id'];
    if (challengeId == null || challengeId.isEmpty ||
        participationId == null || participationId.isEmpty) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentChallengeVideoEditorScreen(
          challengeId: challengeId,
          participationId: participationId,
          initialMode: mode,
        ),
      ),
    );
  }
}

class _ChallengeVideoItem extends StatefulWidget {
  final Map<String, dynamic> video;

  const _ChallengeVideoItem({Key? key, required this.video}) : super(key: key);

  @override
  State<_ChallengeVideoItem> createState() => _ChallengeVideoItemState();
}

class _ChallengeVideoItemState extends State<_ChallengeVideoItem> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final url = widget.video['video_url']?.toString() ?? '';
    if (url.isNotEmpty) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      controller
          .initialize()
          .then((_) {
            if (!mounted) return;
            controller.setLooping(true);
            controller.play();
            setState(() {
              _initialized = true;
            });
          })
          .catchError((_) {
            if (!mounted) return;
            controller.dispose();
            if (mounted) {
              setState(() {
                _controller = null;
                _initialized = false;
              });
            }
          });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final challengeTitle = video['challenge_title']?.toString() ?? '';
    final challengeType = video['challenge_type']?.toString() ?? '';
    final difficulty = video['difficulty']?.toString() ?? '';
    final points = video['points'] is int ? video['points'] as int : null;
    final likesCount = video['likes_count'] is int ? video['likes_count'] as int : 0;
    final commentsCount =
        video['comments_count'] is int ? video['comments_count'] as int : 0;
    final favoritesCount =
        video['favorites_count'] is int ? video['favorites_count'] as int : 0;
    final hasLiked = video['has_liked'] == true;
    final hasFavorited = video['has_favorited'] == true;
    final participationId = video['participation_id']?.toString() ?? '';
    final videoUrl = video['video_url']?.toString() ?? '';
    final parentParticipationId =
        video['parent_participation_id']?.toString() ?? '';
    final remixType = video['remix_type']?.toString() ?? '';

    Map<String, dynamic>? overlays;
    final rawOverlays = video['overlays'] ?? video['layers'];
    if (rawOverlays is Map) {
      overlays = Map<String, dynamic>.from(rawOverlays);
    }

    final metaParts = <String>[];
    if (challengeType.isNotEmpty) {
      metaParts.add(
        challengeType == 'mission' ? 'Mission' : 'Concours',
      );
    }
    if (difficulty.isNotEmpty) {
      metaParts.add('Difficulté: $difficulty');
    }
    if (points != null && points > 0) {
      metaParts.add('$points points');
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: _controller == null
                ? const Center(
                    child: Text(
                      'Vidéo indisponible',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : _initialized
                    ? Center(
                        child: StudentVideoPlayer(
                          controller: _controller!,
                          overlays: overlays,
                          feedMode: true,
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(),
                      ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 220,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 80,
          bottom: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (challengeTitle.isNotEmpty)
                Text(
                  challengeTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (metaParts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    metaParts.join(' • '),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
              if (remixType == 'duo' || parentParticipationId.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: parentParticipationId.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _DuoParentVideoPreviewScreen(
                                  parentParticipationId:
                                      parentParticipationId,
                                ),
                              ),
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Duo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 96,
          child: _ChallengeVideoActions(
            participationId: participationId,
            likesCount: likesCount,
            favoritesCount: favoritesCount,
            commentsCount: commentsCount,
            hasLiked: hasLiked,
            hasFavorited: hasFavorited,
            videoUrl: videoUrl,
            parentParticipationId: parentParticipationId,
            remixType: remixType,
          ),
        ),
      ],
    );
  }
}

class _ChallengeVideoActions extends StatelessWidget {
  final String participationId;
  final int likesCount;
  final int favoritesCount;
  final int commentsCount;
  final bool hasLiked;
  final bool hasFavorited;
  final String videoUrl;
  final String parentParticipationId;
  final String remixType;

  const _ChallengeVideoActions({
    Key? key,
    required this.participationId,
    required this.likesCount,
    required this.favoritesCount,
    required this.commentsCount,
    required this.hasLiked,
    required this.hasFavorited,
    required this.videoUrl,
    required this.parentParticipationId,
    required this.remixType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.read<StudentChallengesProvider>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () async {
            if (hasLiked) {
              await provider.unlikeChallengeVideo(
                participationId: participationId,
              );
            } else {
              await provider.likeChallengeVideo(
                participationId: participationId,
              );
            }
          },
          icon: Icon(
            hasLiked ? Icons.favorite : Icons.favorite_border,
            color: hasLiked ? Colors.redAccent : Colors.white,
          ),
        ),
        Text(
          '$likesCount',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        const SizedBox(height: 12),
        IconButton(
          onPressed: () async {
            if (hasFavorited) {
              await provider.unfavoriteChallengeVideo(
                participationId: participationId,
              );
            } else {
              await provider.favoriteChallengeVideo(
                participationId: participationId,
              );
            }
          },
          icon: Icon(
            hasFavorited ? Icons.star : Icons.star_border,
            color: hasFavorited ? Colors.amber : Colors.white,
          ),
        ),
        Text(
          '$favoritesCount',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        const SizedBox(height: 12),
        IconButton(
          onPressed: () async {
            await _showCommentsSheet(context, provider, participationId);
          },
          icon: const Icon(
            Icons.chat_bubble_outline,
            color: Colors.white,
          ),
        ),
        Text(
          '$commentsCount',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        const SizedBox(height: 12),
        IconButton(
          onPressed: () async {
            if (videoUrl.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lien vidéo indisponible pour le partage.'),
                ),
              );
              return;
            }
            try {
              await Share.share(
                videoUrl,
                subject: 'Vidéo de challenge Academia',
              );
            } catch (_) {
              await Clipboard.setData(ClipboardData(text: videoUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Lien de la vidéo copié dans le presse-papiers.'),
                ),
              );
            }
          },
          icon: const Icon(
            Icons.share,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        IconButton(
          onPressed: remixType == 'duo'
              ? null
              : () async {
                  final result = await provider.startDuoChallengeVideo(
                    parentParticipationId: participationId,
                  );
                  if (result == null) {
                    if (provider.error != null) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(provider.error!)),
                      );
                    }
                    return;
                  }
                  final newParticipationId =
                      result['participation_id'] ?? '';
                  final challengeId = result['challenge_id'] ?? '';
                  if (newParticipationId.isEmpty || challengeId.isEmpty) {
                    return;
                  }

                  // ignore: use_build_context_synchronously
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudentChallengeVideoEditorScreen(
                        challengeId: challengeId,
                        participationId: newParticipationId,
                      ),
                    ),
                  );
                },
          icon: const Icon(
            Icons.video_call,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        IconButton(
          onPressed: () async {
            await _showReportDialog(context, provider, participationId);
          },
          icon: const Icon(
            Icons.flag_outlined,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  static Future<void> _showCommentsSheet(
    BuildContext context,
    StudentChallengesProvider provider,
    String participationId,
  ) async {
    final comments =
        await provider.loadChallengeVideoComments(participationId);
    final controller = TextEditingController();

    // ignore: use_build_context_synchronously
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Commentaires',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (comments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Aucun commentaire pour le moment.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final c = comments[index];
                      final content = c['content']?.toString() ?? '';
                      final userId = c['user_id']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    content,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 2,
                minLines: 1,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Ajouter un commentaire...',
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Color(0xFF111111),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      return;
                    }
                    final ok = await provider.addChallengeVideoComment(
                      participationId: participationId,
                      content: text,
                    );
                    if (!sheetContext.mounted) return;
                    if (!ok && provider.error != null) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text(provider.error!)),
                      );
                    } else if (ok) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  child: const Text('Publier'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _showReportDialog(
    BuildContext context,
    StudentChallengesProvider provider,
    String participationId,
  ) async {
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Signaler la vidéo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Motif (obligatoire)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Détails (optionnel)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonController.text.trim();
                final details = detailsController.text.trim();
                final ok = await provider.reportChallengeVideo(
                  participationId: participationId,
                  reason: reason,
                  details: details.isEmpty ? null : details,
                );
                if (!dialogContext.mounted) return;
                if (!ok && provider.error != null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(provider.error!)),
                  );
                } else if (ok) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    );
  }
}

class _DuoParentVideoPreviewScreen extends StatefulWidget {
  final String parentParticipationId;

  const _DuoParentVideoPreviewScreen({
    Key? key,
    required this.parentParticipationId,
  }) : super(key: key);

  @override
  State<_DuoParentVideoPreviewScreen> createState() =>
      _DuoParentVideoPreviewScreenState();
}

class _DuoParentVideoPreviewScreenState
    extends State<_DuoParentVideoPreviewScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  Map<String, dynamic>? _overlays;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideoAndOverlays();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadVideoAndOverlays() async {
    final provider = context.read<StudentChallengesProvider>();

    Map<String, dynamic>? video;
    try {
      video = await provider.getChallengeVideoById(
        widget.parentParticipationId,
      );
    } catch (_) {
      // L'erreur éventuelle sera déjà exposée via provider.error si besoin.
    }

    if (!mounted) {
      return;
    }

    if (video == null) {
      setState(() {
        _isLoading = false;
        _error = 'Vidéo originale introuvable.';
      });
      return;
    }

    final url =
        video['video_url']?.toString() ?? video['submission_url']?.toString();

    if (url == null || url.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Aucune URL vidéo disponible pour la vidéo originale.';
      });
      return;
    }

    final rawOverlays = video['overlays'] ?? video['layers'];
    Map<String, dynamic>? overlays;
    if (rawOverlays is Map) {
      overlays = Map<String, dynamic>.from(rawOverlays);
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) {
        return;
      }
      controller.setLooping(true);
      controller.play();
      setState(() {
        _initialized = true;
        _overlays = overlays;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = false;
        _overlays = overlays;
        _isLoading = false;
        _error = 'Erreur lors du chargement de la vidéo originale.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Vidéo originale du duo'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const CircularProgressIndicator()
              : _controller != null && _initialized
                  ? StudentVideoPlayer(
                      controller: _controller!,
                      overlays: _overlays,
                    )
                  : _error != null
                      ? Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        )
                      : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
