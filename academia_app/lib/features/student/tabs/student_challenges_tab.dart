import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// tiktoklikescroller retiré : incompatible avec AndroidView PlatformViews.
// On utilise PageView.builder + _TikTokScrollPhysics custom à la place.
import '../../../providers/student_challenges_provider.dart';
import '../../../services/adaptive_quality_service.dart';
import '../../../services/video_analytics_service.dart';
import '../../../services/video_cache_service.dart';
import '../../../services/video_preload_service.dart';
import '../../../services/video_share_service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../video/academia_playback_engine.dart';
import '../../../widgets/video_overlays_layer.dart';
import '../../../widgets/bobodo_state.dart';
import '../../../widgets/bobodo_view.dart';
import '../student_challenge_detail_screen.dart';
import '../student_challenge_video_editor_screen.dart';
import '../challenge_camera_capture_screen.dart';
import '../student_social_profile_screen.dart';
import '../student_dashboard_nav_controller.dart';
import '../student_recently_deleted_videos_screen.dart';
import '../challenge_live_screen.dart';

class StudentChallengesFeedScreen extends StatelessWidget {
  const StudentChallengesFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _ChallengeVideosFeed(),
      ),
    );
  }

}

class _TimedVideoOverlaysLayer extends StatefulWidget {
  final Map<String, dynamic>? overlays;
  final AcademiaPlaybackController? controller;

  const _TimedVideoOverlaysLayer({
    required this.overlays,
    required this.controller,
  });

  @override
  State<_TimedVideoOverlaysLayer> createState() => _TimedVideoOverlaysLayerState();
}

class _TimedVideoOverlaysLayerState extends State<_TimedVideoOverlaysLayer> {
  Timer? _timer;
  double _positionMs = 0.0;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant _TimedVideoOverlaysLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _positionMs = 0.0;
      _timer?.cancel();
      _startPolling();
    }
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      final ctrl = widget.controller;
      if (ctrl == null || !ctrl.isAttached) return;
      try {
        final pos = await ctrl.getPosition();
        if (!mounted) return;
        setState(() {
          _positionMs = pos.toDouble();
        });
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VideoOverlaysLayer(
      overlays: widget.overlays,
      positionMs: _positionMs,
    );
  }
}

class StudentChallengesTab extends StatelessWidget {
  const StudentChallengesTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Feed plein écran immersif — plus de TabBar.
    // L'accès aux Challenges se fait via le bouton dans la bottom bar
    // ou la colonne d'actions droite.
    return const Scaffold(
      backgroundColor: Colors.black,
      body: _ChallengeVideosFeed(),
    );
  }
}

// ---------------------------------------------------------------------------
// Challenges list body (sub-tab 2)
// ---------------------------------------------------------------------------

class _ChallengesListBody extends StatefulWidget {
  const _ChallengesListBody();

  @override
  State<_ChallengesListBody> createState() => _ChallengesListBodyState();
}

class _ChallengesListBodyState extends State<_ChallengesListBody> {
  String _searchQuery = '';
  String _typeFilter = 'all';
  bool _onlyJoined = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<StudentChallengesProvider>();
      await provider.loadChallenges();
      if (!mounted) return;
      await provider.loadMyParticipations();
      if (!mounted) return;
      await provider.loadStats();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _buildHeaderContent(),
          ),
          Expanded(
            child: _buildChallengesList(),
          ),
        ],
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
        Consumer<StudentChallengesProvider>(
          builder: (context, provider, child) {
            final stats = provider.stats;
            final totalJoined = stats == null
                ? 0
                : stats['total_joined'] as int? ?? 0;
            final totalCompleted = stats == null
                ? 0
                : stats['total_completed'] as int? ?? 0;
            final totalPoints = stats == null
                ? 0
                : stats['total_points'] as int? ?? 0;

            final bool hasJoined = totalJoined > 0;
            final bool hasCompleted = totalCompleted > 0;
            final bool hasPoints = totalPoints > 0;

            BobodoState state;
            if (!hasJoined && !hasCompleted && !hasPoints) {
              state = BobodoState.idle;
            } else if (hasCompleted || hasPoints) {
              state = BobodoState.success;
            } else {
              state = BobodoState.thinking;
            }

            String text;
            if (!hasJoined) {
              text =
                  'Les challenges vidéo te permettent de t\'entraîner, gagner des points et montrer ce que tu sais faire. Rejoins ton premier challenge pour débloquer tes premiers badges.';
            } else if (!hasCompleted) {
              text =
                  'Tu as déjà rejoint des challenges, bravo. En les terminant, tu marques des points et construis ton badge de progression pas à pas.';
            } else {
              text =
                  'Tu as déjà validé des challenges et gagné des points : continue, chaque mission terminée renforce ton profil et tes futurs badges sur Academia.';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: BobodoView(
                        state: state,
                        size: 52,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (stats != null)
                  Card(
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
                  ),
              ],
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

// ---------------------------------------------------------------------------
// Generic comments & report helpers (used by feed actions)
// ---------------------------------------------------------------------------

Future<void> _showGenericCommentsSheet(
  BuildContext context,
  StudentChallengesProvider provider,
  String videoType,
  String videoId,
) async {
  List<Map<String, dynamic>> comments =
      await provider.loadVideoComments(videoType, videoId);
  final controller = TextEditingController();
  final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

  String formatRelative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }

  Future<void> reload(StateSetter setModalState) async {
    final fresh = await provider.loadVideoComments(videoType, videoId);
    setModalState(() {
      comments = fresh;
    });
  }

  // ignore: use_build_context_synchronously
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0B0B0B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Commentaires (${comments.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => reload(setModalState),
                            icon: const Icon(Icons.refresh, color: Colors.white70),
                            tooltip: 'Rafraîchir',
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close, color: Colors.white70),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      Expanded(
                        child: comments.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Aucun commentaire pour le moment.',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: comments.length,
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                itemBuilder: (context, index) {
                                  final c = comments[index];
                                  final content = c['content']?.toString() ?? '';
                                  final userId = c['user_id']?.toString() ?? '';
                                  final displayName = c['display_name']?.toString().trim();
                                  final avatarUrl = c['avatar_url']?.toString().trim();
                                  final commentId = c['id']?.toString() ?? '';
                                  final isOwn = userId == currentUserId;

                                  DateTime? createdAt;
                                  final createdRaw = c['created_at']?.toString();
                                  if (createdRaw != null && createdRaw.isNotEmpty) {
                                    createdAt = DateTime.tryParse(createdRaw);
                                  }

                                  final name = (displayName != null && displayName.isNotEmpty)
                                      ? displayName
                                      : '@${userId.isNotEmpty ? userId.substring(0, 8) : 'user'}';
                                  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: const Color(0xFF1EA75C),
                                          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                              ? NetworkImage(avatarUrl)
                                              : null,
                                          child: (avatarUrl == null || avatarUrl.isEmpty)
                                              ? Text(
                                                  initial,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
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
                                                        color: Colors.white70,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  if (createdAt != null)
                                                    Text(
                                                      formatRelative(createdAt.toLocal()),
                                                      style: const TextStyle(
                                                        color: Colors.white38,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                content,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isOwn && commentId.isNotEmpty)
                                          IconButton(
                                            onPressed: () async {
                                              final ok = await provider.deleteVideoComment(
                                                commentId: commentId,
                                                videoType: videoType,
                                                videoId: videoId,
                                              );
                                              if (!sheetContext.mounted) return;
                                              if (!ok && provider.error != null) {
                                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                                  SnackBar(content: Text(provider.error!)),
                                                );
                                                return;
                                              }
                                              await reload(setModalState);
                                            },
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          left: 12,
                          right: 12,
                          bottom: 12 + MediaQuery.of(sheetContext).viewInsets.bottom,
                          top: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                maxLines: 4,
                                minLines: 1,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Ajouter un commentaire...',
                                  hintStyle: TextStyle(color: Colors.white54),
                                  filled: true,
                                  fillColor: Color(0xFF111111),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(999)),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF1EA75C),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: () async {
                                  final text = controller.text.trim();
                                  if (text.isEmpty) return;
                                  final ok = await provider.addVideoComment(
                                    videoType: videoType,
                                    videoId: videoId,
                                    content: text,
                                  );
                                  if (!sheetContext.mounted) return;
                                  if (!ok && provider.error != null) {
                                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                                      SnackBar(content: Text(provider.error!)),
                                    );
                                    return;
                                  }
                                  controller.clear();
                                  await reload(setModalState);
                                },
                                icon: const Icon(Icons.send, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}

Future<void> _showGenericReportDialog(
  BuildContext context,
  StudentChallengesProvider provider,
  String videoType,
  String videoId,
) async {
  final reasonController = TextEditingController();
  final detailsController = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Signaler la vidéo'),
        content: SingleChildScrollView(
          child: Column(
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
              final ok = await provider.reportVideo(
                videoType: videoType,
                videoId: videoId,
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

// ---------------------------------------------------------------------------
// TikTok-style video feed (sub-tab 1)
// ---------------------------------------------------------------------------

class _ChallengeVideosFeed extends StatefulWidget {
  const _ChallengeVideosFeed();

  @override
  State<_ChallengeVideosFeed> createState() => _ChallengeVideosFeedState();
}

class _ChallengeVideosFeedState extends State<_ChallengeVideosFeed> {
  bool _initialized = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _pageSize = 20;

  // PageView controller — compatible avec AndroidView PlatformViews
  // viewportFraction < 1 force Flutter à pré-rendre les pages adjacentes
  final PageController _pageController = PageController(viewportFraction: 0.999);

  // Auto-pause on swipe: track controllers per page index
  final Map<int, AcademiaPlaybackController> _controllers = {};
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _initialized) return;
      _initialized = true;
      // Initialize adaptive quality monitoring
      AdaptiveQualityService.init();
      final provider = context.read<StudentChallengesProvider>();
      await provider.loadChallengeVideos(limit: _pageSize);
      if (!mounted) return;
      final videos = provider.videos;
      debugPrint('[FEED] Loaded ${videos.length} videos');
      setState(() {
        _hasMore = videos.length >= _pageSize;
      });
      // Preload first few videos
      _preloadAdjacentVideos(0, videos);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int newIndex) {
    debugPrint('[FEED] Page changed: $_currentPage -> $newIndex');

    // Stop analytics for previous video
    final provider = context.read<StudentChallengesProvider>();
    final videos = provider.videos;
    if (_currentPage < videos.length) {
      VideoAnalyticsService.onVideoStopped();
    }

    // Pause all controllers except the new active one
    for (final entry in _controllers.entries) {
      if (entry.key != newIndex && entry.value.isAttached) {
        entry.value.pause();
        debugPrint('[FEED]   Paused controller at index ${entry.key}');
      }
    }
    _currentPage = newIndex;

    // Start analytics for new video
    if (newIndex < videos.length) {
      final video = videos[newIndex];
      final videoId = video['participation_id']?.toString() ?? video['video_id']?.toString() ?? '';
      if (videoId.isNotEmpty) {
        VideoAnalyticsService.onVideoStarted(
          videoId: videoId,
          videoType: video['video_type']?.toString() ?? 'challenge',
          participationId: video['participation_id']?.toString(),
        );
      }
    }
    final newCtrl = _controllers[newIndex];
    if (newCtrl != null && newCtrl.isAttached) {
      newCtrl.play();
      debugPrint('[FEED]   Playing controller at index $newIndex');
    } else {
      debugPrint('[FEED]   No controller ready at index $newIndex (attached=${newCtrl?.isAttached})');
    }
    // Clean up controllers far from current (keep only N-2..N+2)
    final removed = <int>[];
    _controllers.removeWhere((key, _) {
      if ((key - newIndex).abs() > 2) {
        removed.add(key);
        return true;
      }
      return false;
    });
    if (removed.isNotEmpty) {
      debugPrint('[FEED]   Cleaned up controllers: $removed');
    }

    // Preload adjacent videos
    _preloadAdjacentVideos(newIndex, videos);
  }

  void _preloadAdjacentVideos(int currentIndex, List<Map<String, dynamic>> videos) {
    final urlsToPreload = <String>[];
    for (int i = 1; i <= 3; i++) {
      final nextIdx = currentIndex + i;
      if (nextIdx < videos.length) {
        final url = AdaptiveQualityService.selectBestUrlFromVideo(videos[nextIdx]);
        if (url.isNotEmpty) {
          // Cache best URL for quick access
          final videoId = videos[nextIdx]['participation_id']?.toString() ?? videos[nextIdx]['video_id']?.toString() ?? '';
          if (videoId.isNotEmpty) {
            VideoCacheService.putBestUrl(videoId, url);
          }
          urlsToPreload.add(url);
        }
      }
    }
    if (urlsToPreload.isNotEmpty) {
      VideoPreloadService.preloadUrls(urlsToPreload);
    }
  }

  Future<void> _reloadAfterDeletion() async {
    final provider = context.read<StudentChallengesProvider>();
    _controllers.clear();
    _currentPage = 0;
    VideoPreloadService.clear();
    await provider.loadChallengeVideos(limit: _pageSize);
    if (!mounted) return;
    final videos = provider.videos;
    setState(() {
      _hasMore = videos.length >= _pageSize;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentChallengesProvider>(
      builder: (context, provider, child) {
        final videos = provider.videos;

        if (provider.isLoadingVideos && videos.isEmpty) {
          return const LoadingWidget(
            message: 'Chargement des vidéos...',
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
              physics: const _TikTokPageScrollPhysics(),
              itemCount: videos.length,
              onPageChanged: (index) {
                _onPageChanged(index);
                _loadMoreIfNeeded(index, videos);
              },
              itemBuilder: (context, index) {
                final video = videos[index];
                return _ChallengeVideoItem(
                  key: ValueKey('video_${video['video_type']}_${video['participation_id'] ?? video['video_id']}_$index'),
                  video: video,
                  isActive: index == _currentPage,
                  onDeleted: _reloadAfterDeletion,
                  onControllerReady: (ctrl) {
                    _controllers[index] = ctrl;
                  },
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
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

  Widget _buildTikTokBottomBar(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isCompactHeight = screenHeight < 700;
    final isCompactWidth = screenWidth < 360;
    final bool isCompact = isCompactHeight || isCompactWidth;

    final double iconSize = isCompact ? 22 : 26;
    final double labelFontSize = isCompact ? 9 : 10;
    final double centralButtonSize = isCompact ? 38 : 44;
    final double centralIconSize = isCompact ? 22 : 26;
    final double verticalPadding = isCompact ? 6 : 8;

    Widget buildNavItem({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: iconSize),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: labelFontSize,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // TikTok-style progress bar synced with actual video playback
          SizedBox(
            height: 3,
            child: _VideoProgressBar(
              key: ValueKey('progress_page_$_currentPage'),
              controller: _controllers[_currentPage],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 4,
              vertical: verticalPadding,
            ),
            decoration: const BoxDecoration(
              color: Colors.black,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 1. Accueil
                buildNavItem(
                  icon: Icons.home_filled,
                  label: 'Accueil',
                  onTap: () {
                    _pauseAllControllers();
                    StudentDashboardNavController.setIndex(0);
                  },
                ),
                // 2. Challenges
                buildNavItem(
                  icon: Icons.emoji_events_outlined,
                  label: 'Challenges',
                  onTap: () {
                    _pauseAllControllers();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          backgroundColor: const Color(0xFFF3F4F6),
                          appBar: AppBar(
                            title: const Text('Challenges'),
                            backgroundColor: const Color(0xFF1EA75C),
                            foregroundColor: Colors.white,
                          ),
                          body: const _ChallengesListBody(),
                        ),
                      ),
                    ).then((_) {
                      if (!mounted) return;
                      final ctrl = _controllers[_currentPage];
                      if (ctrl != null && ctrl.isAttached) ctrl.play();
                    });
                  },
                ),
                // 3. Bouton + central (créer une vidéo)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openCreateVideoFromFeed(context),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: centralButtonSize,
                          height: centralButtonSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(centralButtonSize / 4),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1EA75C).withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.add,
                            color: Colors.white,
                            size: centralIconSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 4. Jeux
                buildNavItem(
                  icon: Icons.sports_esports,
                  label: 'Jeux',
                  onTap: () {
                    _pauseAllControllers();
                    Navigator.of(context).pushNamed('/games').then((_) {
                      if (!mounted) return;
                      final ctrl = _controllers[_currentPage];
                      if (ctrl != null && ctrl.isAttached) ctrl.play();
                    });
                  },
                ),
                // 5. Live TikTok
                buildNavItem(
                  icon: Icons.sensors,
                  label: 'Live',
                  onTap: () {
                    _pauseAllControllers();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChallengeLiveScreen(),
                      ),
                    ).then((_) {
                      if (!mounted) return;
                      final ctrl = _controllers[_currentPage];
                      if (ctrl != null && ctrl.isAttached) ctrl.play();
                    });
                  },
                ),
                // 6. Profil TikTok-like
                buildNavItem(
                  icon: Icons.person_outline,
                  label: 'Profil',
                  onTap: () {
                    final userId = Supabase.instance.client.auth.currentUser?.id;
                    if (userId == null) return;
                    _pauseAllControllers();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentSocialProfileScreen(
                          userId: userId,
                        ),
                      ),
                    ).then((_) {
                      if (!mounted) return;
                      final ctrl = _controllers[_currentPage];
                      if (ctrl != null && ctrl.isAttached) ctrl.play();
                    });
                  },
                ),
              ],
            ),
          ),
        ],
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

  /// Ouvre directement la caméra TikTok. Après capture, passe au Studio.
  Future<void> _openCreateVideoFromFeed(BuildContext context) async {
    if (!context.mounted) return;

    // Pause toutes les vidéos du feed avant de naviguer
    _pauseAllControllers();

    final segments = await Navigator.of(context).push<List<XFile>?>(
      MaterialPageRoute(
        builder: (_) => const ChallengeCameraCaptureScreen(),
      ),
    );

    if (!mounted) return;

    // Si l'utilisateur a capturé des segments, ouvrir le Studio avec les segments
    if (segments != null && segments.isNotEmpty) {
      final published = await Navigator.of(context).push<bool?>(
        MaterialPageRoute(
          builder: (_) => StudentChallengeVideoEditorScreen(
            videoType: 'free',
            initialMode: 'camera',
            initialSegments: segments,
          ),
        ),
      );

      if (!mounted) return;
      await _onReturnFromStudio(published == true);
      return;
    }

    if (!mounted) return;
    final ctrl = _controllers[_currentPage];
    if (ctrl != null && ctrl.isAttached) {
      ctrl.play();
    }
  }

  /// Called when returning from the Studio. If [published] is true,
  /// reloads the feed and scrolls to index 0 (the just-published video).
  Future<void> _onReturnFromStudio(bool published) async {
    final provider = context.read<StudentChallengesProvider>();
    if (published) {
      // Reload the feed to include the newly published video
      await provider.loadChallengeVideos(limit: _pageSize);
      if (!mounted) return;
      // Scroll to the first video (most recent = the one just published)
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _currentPage = 0;
    } else {
      // Resume playback on the current video
      final ctrl = _controllers[_currentPage];
      if (ctrl != null && ctrl.isAttached) {
        ctrl.play();
      }
    }
  }

  /// Pause tous les controllers vidéo (utilisé avant navigation)
  void _pauseAllControllers() {
    for (final entry in _controllers.entries) {
      if (entry.value.isAttached) {
        entry.value.pause();
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Custom PageScrollPhysics : spring rapide + seuil de drag réduit.
// Rend le swipe entre vidéos plus facile et naturel (style TikTok).
// ---------------------------------------------------------------------------
class _TikTokPageScrollPhysics extends PageScrollPhysics {
  const _TikTokPageScrollPhysics({super.parent});

  @override
  _TikTokPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _TikTokPageScrollPhysics(parent: buildParent(ancestor));
  }

  // Spring rapide : snap vif sans oscillation
  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.8,
        stiffness: 100,
        damping: 14,
      );

  // Seuil de vitesse réduit : un petit flick suffit pour changer de page
  @override
  double get minFlingVelocity => 50.0;

  // Seuil de drag réduit : ~15% de la page suffit (au lieu de ~50%)
  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}

class _ChallengeVideoItem extends StatefulWidget {
  final Map<String, dynamic> video;
  final ValueChanged<AcademiaPlaybackController>? onControllerReady;
  final Future<void> Function()? onDeleted;
  final bool isActive;

  const _ChallengeVideoItem({
    Key? key,
    required this.video,
    required this.isActive,
    this.onControllerReady,
    this.onDeleted,
  }) : super(key: key);

  @override
  State<_ChallengeVideoItem> createState() => _ChallengeVideoItemState();
}

class _ChallengeVideoItemState extends State<_ChallengeVideoItem> {
  bool _initialized = false;

  String? _errorMessage;
  String _selectedUrl = '';

  // TikTok-style controls
  final AcademiaPlaybackController _playbackController = AcademiaPlaybackController();
  bool _isPaused = false;
  bool _showPauseIcon = false;

  // Custom double-tap detection (avoids 300ms GestureDetector delay)
  DateTime _lastTapTime = DateTime(2000);
  Offset _lastTapPosition = Offset.zero;
  Timer? _singleTapTimer;

  // Double-tap heart animation
  final List<_HeartAnimData> _hearts = [];
  final math.Random _rng = math.Random();

  String get _videoLabel {
    final vt = widget.video['video_type']?.toString() ?? '?';
    final vid = widget.video['participation_id']?.toString() ??
        widget.video['video_id']?.toString() ?? '?';
    return '$vt/$vid';
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[VIDEO_ITEM] initState  label=$_videoLabel  isActive=${widget.isActive}');
    widget.onControllerReady?.call(_playbackController);
    _startInit();
  }

  @override
  void didUpdateWidget(covariant _ChallengeVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      debugPrint('[VIDEO_ITEM] didUpdateWidget  label=$_videoLabel  isActive: ${oldWidget.isActive} -> ${widget.isActive}');
    }
  }

  Future<void> _startInit() async {
    String url = '';

    // 0) Check cache first
    final videoId = widget.video['participation_id']?.toString() ?? widget.video['video_id']?.toString() ?? '';
    if (videoId.isNotEmpty) {
      final cached = VideoCacheService.getBestUrl(videoId);
      if (cached != null && cached.isNotEmpty) {
        url = cached;
        debugPrint('[VIDEO_ITEM] Cache hit for $videoId');
      }
    }

    // 1) Use AdaptiveQualityService for smart URL selection
    if (url.isEmpty) {
      url = AdaptiveQualityService.selectBestUrlFromVideo(widget.video);
    }

    // Cache the resolved URL
    if (url.isNotEmpty && videoId.isNotEmpty) {
      VideoCacheService.putBestUrl(videoId, url);
    }

    _selectedUrl = url;

    debugPrint('[VIDEO_ITEM] _startInit  label=$_videoLabel  url=${_selectedUrl.length > 80 ? _selectedUrl.substring(0, 80) : _selectedUrl}');

    if (_selectedUrl.isEmpty) {
      _setError("Aucune URL vidéo disponible (renditions absentes ou invalides).");
      return;
    }

    if (!mounted) return;
    debugPrint('[VIDEO_ITEM] _startInit OK -> _initialized=true  label=$_videoLabel');
    setState(() => _initialized = true);
  }

  Future<void> _reportPlaybackError({
    required String videoUrl,
    String? renditionKey,
    required String errorMessage,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[VideoPlaybackError] url=$videoUrl rendition=$renditionKey error=$errorMessage',
      );
    }
    // on ignore les erreurs de télémétrie
  }

  void _setError(String msg) {
    debugPrint('[VIDEO_ITEM] ERROR  label=$_videoLabel  msg=$msg');
    final urlForTelemetry = _selectedUrl.isNotEmpty
        ? _selectedUrl
        : '';

    setState(() {
      _errorMessage = msg;
      _initialized = false;
    });

    if (urlForTelemetry.isNotEmpty) {
      _reportPlaybackError(
        videoUrl: urlForTelemetry,
        renditionKey: null,
        errorMessage: msg,
      );
    }
  }

  void _onSingleTap() async {
    if (!_initialized) return;
    final isPlaying = await _playbackController.toggle();
    if (!mounted) return;
    setState(() {
      _isPaused = !isPlaying;
      _showPauseIcon = true;
    });
    if (!_isPaused) {
      // Hide pause icon after a short delay when resuming
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_isPaused) {
          setState(() => _showPauseIcon = false);
        }
      });
    }
  }

  void _onDoubleTap(TapDownDetails details, BuildContext ctx) {
    // Spawn heart animation at tap position
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final id = DateTime.now().microsecondsSinceEpoch;
    setState(() {
      _hearts.add(_HeartAnimData(
        id: id,
        x: local.dx,
        y: local.dy,
        rotation: (_rng.nextDouble() - 0.5) * 0.6,
      ));
    });

    // Trigger like if not already liked
    final video = widget.video;
    final hasLiked = video['has_liked'] == true;
    if (!hasLiked) {
      final provider = ctx.read<StudentChallengesProvider>();
      final videoType = video['video_type']?.toString() ?? 'challenge';
      final isChallenge = videoType != 'free';
      final participationId = video['participation_id']?.toString() ?? '';
      final videoId = video['video_id']?.toString() ?? '';

      if (isChallenge && participationId.isNotEmpty) {
        provider.likeChallengeVideo(participationId: participationId);
      } else if (videoType.isNotEmpty && videoId.isNotEmpty) {
        provider.likeVideo(videoType: videoType, videoId: videoId);
      }
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_initialized) return;
    final now = DateTime.now();
    final dt = now.difference(_lastTapTime).inMilliseconds;
    final pos = details.globalPosition;

    if (dt < 300 && (pos - _lastTapPosition).distance < 50) {
      // Double-tap detected — cancel pending single-tap, fire heart
      _singleTapTimer?.cancel();
      _singleTapTimer = null;
      _lastTapTime = DateTime(2000);
      _onDoubleTap(TapDownDetails(globalPosition: pos), context);
    } else {
      // Potential single-tap — schedule with short delay to allow double-tap
      _lastTapTime = now;
      _lastTapPosition = pos;
      _singleTapTimer?.cancel();
      _singleTapTimer = Timer(const Duration(milliseconds: 300), () {
        _onSingleTap();
      });
    }
  }

  @override
  void dispose() {
    debugPrint('[VIDEO_ITEM] dispose  label=$_videoLabel');
    _singleTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final videoType = video['video_type']?.toString() ?? 'challenge';
    final isChallenge = videoType != 'free';
    final challengeTitle = isChallenge
        ? (video['challenge_title']?.toString() ?? '')
        : (video['title']?.toString() ?? '');
    final challengeType = isChallenge
        ? (video['challenge_type']?.toString() ?? '')
        : '';
    final difficulty =
        isChallenge ? (video['difficulty']?.toString() ?? '') : '';
    final points = isChallenge && video['points'] is int
        ? video['points'] as int
        : null;
    final likesCount = video['likes_count'] is int ? video['likes_count'] as int : 0;
    final commentsCount =
        video['comments_count'] is int ? video['comments_count'] as int : 0;
    final favoritesCount =
        video['favorites_count'] is int ? video['favorites_count'] as int : 0;
    final hasLiked = video['has_liked'] == true;
    final hasFavorited = video['has_favorited'] == true;
    final participationId = video['participation_id']?.toString() ?? '';
    final videoId = video['video_id']?.toString() ?? '';
    final videoAssetId = video['video_asset_id']?.toString() ?? '';
    final videoUrl = video['video_url']?.toString() ?? '';
    final parentParticipationId =
        video['parent_participation_id']?.toString() ?? '';
    final remixType = video['remix_type']?.toString() ?? '';
    final allowDownload = video['allow_download'] == true;
    final authorUserId = video['user_id']?.toString() ?? video['owner_id']?.toString() ?? '';
    final authorName = video['display_name']?.toString() ?? video['user_name']?.toString() ?? '';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final isOwner = currentUserId.isNotEmpty && authorUserId.isNotEmpty && currentUserId == authorUserId;

    Map<String, dynamic>? videoRenditions;
    final rawRenditions = video['video_renditions'];
    if (rawRenditions is Map) {
      videoRenditions = Map<String, dynamic>.from(rawRenditions);
    }

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

    if (_errorMessage != null) {
      return Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          _buildOverlayMeta(
            challengeTitle: challengeTitle,
            metaParts: metaParts,
            remixType: remixType,
            parentParticipationId: parentParticipationId,
            authorUserId: authorUserId,
            authorName: authorName,
            context: context,
          ),
          _buildRightActions(
            context: context,
            participationId: participationId,
            videoType: videoType,
            videoId: videoId,
            videoAssetId: videoAssetId,
            videoRenditions: videoRenditions,
            likesCount: likesCount,
            favoritesCount: favoritesCount,
            commentsCount: commentsCount,
            hasLiked: hasLiked,
            hasFavorited: hasFavorited,
            videoUrl: videoUrl,
            parentParticipationId: parentParticipationId,
            remixType: remixType,
            isChallenge: isChallenge,
            isOwner: isOwner,
            allowDownload: allowDownload,
            onDeleted: widget.onDeleted,
          ),
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _handleTapUp,
            child: Container(
              color: Colors.black,
              child: _initialized
                  ? Center(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AcademiaPlaybackEngine.view(
                                url: _selectedUrl,
                                autoplay: widget.isActive,
                                looping: true,
                                muted: false,
                                showControls: false,
                                fit: BoxFit.cover,
                                playbackController: _playbackController,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _TimedVideoOverlaysLayer(
                                overlays: overlays,
                                controller: _playbackController,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
            ),
          ),
        ),
        // Pause icon overlay
        if (_showPauseIcon)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _isPaused ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pause,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Double-tap heart animations
        ..._hearts.map((h) => _DoubleTapHeart(key: ValueKey(h.id), data: h, onDone: () {
          if (mounted) setState(() => _hearts.removeWhere((e) => e.id == h.id));
        })),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 280,
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
        _buildOverlayMeta(
          challengeTitle: challengeTitle,
          metaParts: metaParts,
          remixType: remixType,
          parentParticipationId: parentParticipationId,
          authorUserId: authorUserId,
          authorName: authorName,
          context: context,
        ),
        _buildRightActions(
          context: context,
          participationId: participationId,
          videoType: videoType,
          videoId: videoId,
          videoAssetId: videoAssetId,
          videoRenditions: videoRenditions,
          likesCount: likesCount,
          favoritesCount: favoritesCount,
          commentsCount: commentsCount,
          hasLiked: hasLiked,
          hasFavorited: hasFavorited,
          videoUrl: videoUrl,
          parentParticipationId: parentParticipationId,
          remixType: remixType,
          isChallenge: isChallenge,
          isOwner: isOwner,
          allowDownload: allowDownload,
          onDeleted: widget.onDeleted,
        ),
      ],
    );
  }

  Widget _buildOverlayMeta({
    required String challengeTitle,
    required List<String> metaParts,
    required String remixType,
    required String parentParticipationId,
    required String authorUserId,
    required String authorName,
    required BuildContext context,
  }) {
    return Positioned(
      left: 12,
      right: 72,
      bottom: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (authorUserId.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StudentSocialProfileScreen(
                      userId: authorUserId,
                      displayName: authorName.isNotEmpty ? authorName : null,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      authorName.isNotEmpty ? authorName : '@${authorUserId.substring(0, 8)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (challengeTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                challengeTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
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
                              parentParticipationId: parentParticipationId,
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
    );
  }

  Widget _buildRightActions({
    required BuildContext context,
    required String participationId,
    required String videoType,
    required String videoId,
    required String videoAssetId,
    required Map<String, dynamic>? videoRenditions,
    required int likesCount,
    required int favoritesCount,
    required int commentsCount,
    required bool hasLiked,
    required bool hasFavorited,
    required String videoUrl,
    required String parentParticipationId,
    required String remixType,
    required bool isChallenge,
    required bool isOwner,
    required bool allowDownload,
    required Future<void> Function()? onDeleted,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactWidth = screenWidth < 360;
    final double rightPadding = isCompactWidth ? 10 : 14;

    return Positioned(
      right: rightPadding,
      bottom: 120,
      child: _ChallengeVideoActions(
        participationId: participationId,
        videoType: videoType,
        videoId: videoId,
        videoAssetId: videoAssetId,
        videoRenditions: videoRenditions,
        likesCount: likesCount,
        favoritesCount: favoritesCount,
        commentsCount: commentsCount,
        hasLiked: hasLiked,
        hasFavorited: hasFavorited,
        videoUrl: videoUrl,
        parentParticipationId: parentParticipationId,
        remixType: remixType,
        isChallenge: isChallenge,
        isOwner: isOwner,
        allowDownload: allowDownload,
        onDeleted: onDeleted,
      ),
    );
  }
}

class _ChallengeVideoActions extends StatelessWidget {
  final String participationId;
  final String videoType;
  final String videoId;
  final String videoAssetId;
  final Map<String, dynamic>? videoRenditions;
  final int likesCount;
  final int favoritesCount;
  final int commentsCount;
  final bool hasLiked;
  final bool hasFavorited;
  final String videoUrl;
  final String parentParticipationId;
  final String remixType;
  final bool isChallenge;
  final bool isOwner;
  final bool allowDownload;
  final Future<void> Function()? onDeleted;

  const _ChallengeVideoActions({
    Key? key,
    required this.participationId,
    required this.videoType,
    required this.videoId,
    required this.videoAssetId,
    required this.videoRenditions,
    required this.likesCount,
    required this.favoritesCount,
    required this.commentsCount,
    required this.hasLiked,
    required this.hasFavorited,
    required this.videoUrl,
    required this.parentParticipationId,
    required this.remixType,
    required this.isChallenge,
    required this.isOwner,
    required this.allowDownload,
    required this.onDeleted,
  }) : super(key: key);

  static Future<bool> _ensureMediaSavePermission() async {
    if (kIsWeb) return false;

    if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      return status.isGranted;
    }

    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) return true;

    final photosStatus = await Permission.photos.request();
    if (photosStatus.isGranted) return true;

    final videosStatus = await Permission.videos.request();
    return videosStatus.isGranted;
  }

  static Future<bool> _downloadWatermarkedWithProgressSheet({
    required BuildContext context,
    required StudentChallengesProvider provider,
    required String videoType,
    required String videoId,
    required String videoAssetId,
    required String fallbackVideoUrl,
    required Map<String, dynamic>? videoRenditions,
  }) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Téléchargement non supporté sur le web.')),
      );
      return false;
    }

    final existing = _pickWatermarkedUrlFromRenditions(videoRenditions).trim();

    final ValueNotifier<String> phase = ValueNotifier<String>('prepare');
    final ValueNotifier<String> message = ValueNotifier<String>('Préparation de la vidéo...');
    final ValueNotifier<double?> progress = ValueNotifier<double?>(null);
    final ValueNotifier<bool> canClose = ValueNotifier<bool>(false);
    bool cancelled = false;
    bool started = false;

    Future<T?> _withTimeout<T>(Future<T> f, Duration d) async {
      try {
        return await f.timeout(d);
      } catch (_) {
        return null;
      }
    }

    Future<void> run() async {
      try {
        String urlToDownload = existing;

        if (urlToDownload.isEmpty && videoAssetId.trim().isNotEmpty) {
          debugPrint(
            '[watermark-download] request export_watermarked asset=$videoAssetId',
          );
          final resp = await _withTimeout<Map<String, dynamic>?>(
            provider.requestVideoExportWatermarked(
              videoAssetId: videoAssetId,
            ),
            const Duration(seconds: 20),
          );

          if (resp == null) {
            phase.value = 'error';
            message.value = provider.error ??
                'Impossible de préparer la vidéo. Réessaie plus tard.';
            canClose.value = true;
            return;
          }

          final status = resp['status']?.toString() ?? '';
          final url = resp['url']?.toString() ?? '';
          debugPrint(
            '[watermark-download] request response status=$status urlLen=${url.length}',
          );
          if (status == 'ready' && url.trim().isNotEmpty) {
            urlToDownload = url.trim();
          }
        }

        if (urlToDownload.isEmpty && videoAssetId.trim().isNotEmpty) {
          phase.value = 'prepare';
          message.value = 'Préparation de la vidéo (logo)...';
          final deadline = DateTime.now().add(const Duration(seconds: 90));

          String lastStatus = '';

          while (!cancelled && DateTime.now().isBefore(deadline)) {
            final st = await _withTimeout<Map<String, dynamic>?>(
              provider.getVideoExportWatermarkedStatus(
                videoAssetId: videoAssetId,
              ),
              const Duration(seconds: 20),
            );

            if (st == null) {
              phase.value = 'error';
              message.value = provider.error ??
                  'Erreur lors de la vérification de l\'export.';
              canClose.value = true;
              return;
            }

            final status = st['status']?.toString() ?? '';
            final url = st['url']?.toString() ?? '';

            if (status.isNotEmpty && status != lastStatus) {
              lastStatus = status;
              message.value = 'Préparation de la vidéo (logo)... ($status)';
              debugPrint(
                '[watermark-download] poll status=$status urlLen=${url.length}',
              );
            }

            if (status == 'ready' && url.trim().isNotEmpty) {
              urlToDownload = url.trim();
              break;
            }

            if (status == 'failed') {
              phase.value = 'error';
              message.value = st['error']?.toString() ??
                  'Échec de la préparation de la vidéo.';
              canClose.value = true;
              return;
            }

            if (status == 'unknown') {
              debugPrint('[watermark-download] poll unknown status payload=$st');
            }

            await Future.delayed(const Duration(seconds: 2));
          }

          if (cancelled) {
            canClose.value = true;
            return;
          }

          if (urlToDownload.isEmpty) {
            phase.value = 'error';
            message.value =
                'Préparation trop longue. Réessaie dans quelques instants.';
            canClose.value = true;
            return;
          }
        }

        if (urlToDownload.isEmpty) {
          if (fallbackVideoUrl.trim().isNotEmpty) {
            urlToDownload = fallbackVideoUrl.trim();
          } else {
            phase.value = 'error';
            message.value = 'Lien vidéo indisponible.';
            canClose.value = true;
            return;
          }
        }

        if (cancelled) {
          canClose.value = true;
          return;
        }

        final okPerm = await _ensureMediaSavePermission();
        if (!okPerm) {
          phase.value = 'error';
          message.value = 'Permission refusée pour enregistrer la vidéo.';
          canClose.value = true;
          return;
        }

        phase.value = 'download';
        message.value = 'Téléchargement...';
        progress.value = 0.0;

        final client = http.Client();
        try {
          final uri = Uri.parse(urlToDownload);
          final req = http.Request('GET', uri);
          final res = await client.send(req);

          if (res.statusCode != 200) {
            phase.value = 'error';
            message.value = 'Erreur HTTP ${res.statusCode}.';
            canClose.value = true;
            return;
          }

          final total = res.contentLength;
          int received = 0;
          final tmpDir = await getTemporaryDirectory();
          final safeName = 'academia_${videoType}_$videoId';
          final file = File('${tmpDir.path}/$safeName.mp4');
          final sink = file.openWrite();
          try {
            await for (final chunk in res.stream) {
              if (cancelled) {
                await sink.flush();
                await sink.close();
                canClose.value = true;
                return;
              }
              sink.add(chunk);
              received += chunk.length;
              if (total != null && total > 0) {
                final p = received / total;
                progress.value = p.clamp(0.0, 1.0);
              } else {
                progress.value = null;
              }
            }
          } finally {
            await sink.flush();
            await sink.close();
          }

          phase.value = 'save';
          message.value = 'Enregistrement dans la galerie...';
          progress.value = null;

          final dynamic result = await SaverGallery.saveFile(
            filePath: file.path,
            fileName: '$safeName.mp4',
            androidRelativePath: 'Movies',
            skipIfExists: false,
          );

          final ok = (result is Map) ? result['isSuccess'] == true : false;
          if (ok) {
            phase.value = 'done';
            message.value = 'Vidéo enregistrée dans la galerie.';
            canClose.value = true;
          } else {
            phase.value = 'error';
            message.value = 'Impossible d\'enregistrer la vidéo.';
            canClose.value = true;
          }
        } finally {
          client.close();
        }
      } catch (e) {
        phase.value = 'error';
        message.value = 'Erreur lors du téléchargement: $e';
        canClose.value = true;
      }
    }

    final bool? sheetResult = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.black87,
      builder: (sheetContext) {
        if (!started) {
          started = true;
          Future.microtask(run);
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Téléchargement',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<String>(
                  valueListenable: message,
                  builder: (_, msg, __) {
                    return Text(
                      msg,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    );
                  },
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<double?>(
                  valueListenable: progress,
                  builder: (_, p, __) {
                    return LinearProgressIndicator(
                      value: p,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 6,
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: canClose,
                        builder: (_, closable, __) {
                          return OutlinedButton(
                            onPressed: () {
                              if (!closable) {
                                cancelled = true;
                                message.value = 'Annulation...';
                                return;
                              }
                              Navigator.of(sheetContext).pop(phase.value == 'done');
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                            ),
                            child: Text(
                              closable ? 'Fermer' : 'Annuler',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    phase.dispose();
    message.dispose();
    progress.dispose();
    canClose.dispose();

    return sheetResult == true;
  }

  static String _pickWatermarkedUrlFromVideo(Map<String, dynamic> video) {
    final renditions = video['video_renditions'];
    if (renditions is Map) {
      final r = Map<String, dynamic>.from(renditions);
      final url = r['export_watermarked']?.toString().trim() ?? '';
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  static String _pickWatermarkedUrlFromRenditions(Map<String, dynamic>? renditions) {
    if (renditions == null) return '';
    final url = renditions['export_watermarked']?.toString().trim() ?? '';
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<StudentChallengesProvider>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () async {
            await showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.black87,
              builder: (sheetContext) {
                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (allowDownload)
                        ListTile(
                          leading: const Icon(
                            Icons.download,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Télécharger',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () async {
                            Navigator.of(sheetContext).pop();

                            final ok = await _downloadWatermarkedWithProgressSheet(
                              context: context,
                              provider: provider,
                              videoType: videoType,
                              videoId: videoId,
                              videoAssetId: videoAssetId,
                              fallbackVideoUrl: videoUrl,
                              videoRenditions: videoRenditions,
                            );
                            if (!context.mounted) return;
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vidéo enregistrée dans la galerie')),
                              );
                            }
                          },
                        ),
                      if (isOwner)
                        SwitchListTile(
                          secondary: const Icon(
                            Icons.download_for_offline,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Autoriser le téléchargement',
                            style: TextStyle(color: Colors.white),
                          ),
                          value: allowDownload,
                          onChanged: (value) async {
                            final ok = await provider.setVideoAllowDownload(
                              videoType: videoType,
                              videoId: videoId,
                              allowDownload: value,
                            );
                            if (!sheetContext.mounted) return;
                            if (!ok) {
                              if (provider.error != null) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(content: Text(provider.error!)),
                                );
                              }
                              return;
                            }
                            await onDeleted?.call();
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                      ListTile(
                        leading: const Icon(
                          Icons.history,
                          color: Colors.white,
                        ),
                        title: const Text(
                          'Récemment supprimées',
                          style: TextStyle(color: Colors.white),
                        ),
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          final restored = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => const StudentRecentlyDeletedVideosScreen(),
                            ),
                          );
                          if (restored == true) {
                            await onDeleted?.call();
                          }
                        },
                      ),
                      if (isOwner)
                        ListTile(
                          leading: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          title: const Text(
                            'Supprimer',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                          onTap: () async {
                            final confirmed = await showDialog<bool>(
                              context: sheetContext,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: const Text('Supprimer cette vidéo ?'),
                                  content: const Text(
                                    'Elle sera déplacée dans "Récemment supprimées".',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(false),
                                      child: const Text('Annuler'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(true),
                                      child: const Text('Supprimer'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirmed != true) return;

                            final ok = await provider.softDeleteVideo(
                              videoType: videoType,
                              videoId: videoId,
                            );
                            if (!sheetContext.mounted) return;

                            if (!ok) {
                              if (provider.error != null) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(content: Text(provider.error!)),
                                );
                              }
                              return;
                            }

                            Navigator.of(sheetContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vidéo supprimée')),
                            );
                            await onDeleted?.call();
                          },
                        ),
                      ListTile(
                        leading: const Icon(Icons.close, color: Colors.white70),
                        title: const Text('Annuler', style: TextStyle(color: Colors.white70)),
                        onTap: () => Navigator.of(sheetContext).pop(),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            );
          },
          icon: const Icon(Icons.more_horiz, color: Colors.white),
        ),
        const SizedBox(height: 4),
        IconButton(
          onPressed: () async {
            bool ok = false;

            // Vidéos de challenge → on conserve la logique basée sur participationId.
            if (isChallenge && participationId.isNotEmpty) {
              if (hasLiked) {
                ok = await provider.unlikeChallengeVideo(
                  participationId: participationId,
                );
              } else {
                ok = await provider.likeChallengeVideo(
                  participationId: participationId,
                );
              }
            }
            // Autres types de vidéos (par ex. free) → RPC générique basée sur
            // (video_type, video_id) pour le feed unifié.
            else if (videoType.isNotEmpty && videoId.isNotEmpty) {
              if (hasLiked) {
                ok = await provider.unlikeVideo(
                  videoType: videoType,
                  videoId: videoId,
                );
              } else {
                ok = await provider.likeVideo(
                  videoType: videoType,
                  videoId: videoId,
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Impossible d\'identifier cette vidéo pour le like.'),
                ),
              );
              return;
            }

            if (!ok && provider.error != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(provider.error!)),
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
            bool ok = false;

            if (isChallenge && participationId.isNotEmpty) {
              if (hasFavorited) {
                ok = await provider.unfavoriteChallengeVideo(
                  participationId: participationId,
                );
              } else {
                ok = await provider.favoriteChallengeVideo(
                  participationId: participationId,
                );
              }
            } else if (videoType.isNotEmpty && videoId.isNotEmpty) {
              if (hasFavorited) {
                ok = await provider.unfavoriteVideo(
                  videoType: videoType,
                  videoId: videoId,
                );
              } else {
                ok = await provider.favoriteVideo(
                  videoType: videoType,
                  videoId: videoId,
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Impossible d\'identifier cette vidéo pour les favoris.',
                  ),
                ),
              );
              return;
            }
            if (!ok && provider.error != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(provider.error!)),
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
            // Challenges → on garde le flux historique basé sur participationId.
            if (isChallenge && participationId.isNotEmpty) {
              await _showCommentsSheet(context, provider, participationId);
              return;
            }

            // Autres vidéos (ex: free) → commentaires génériques (video_type, video_id).
            if (videoType.isNotEmpty && videoId.isNotEmpty) {
              await _showGenericCommentsSheet(
                context,
                provider,
                videoType,
                videoId,
              );
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Impossible d\'identifier cette vidéo pour les commentaires.',
                ),
              ),
            );
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
        if (allowDownload)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () async {
                  final ok = await _downloadWatermarkedWithProgressSheet(
                    context: context,
                    provider: provider,
                    videoType: videoType,
                    videoId: videoId,
                    videoAssetId: videoAssetId,
                    fallbackVideoUrl: videoUrl,
                    videoRenditions: videoRenditions,
                  );
                  if (!context.mounted) return;
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vidéo enregistrée dans la galerie'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.download, color: Colors.white),
                tooltip: 'Télécharger',
              ),
              const SizedBox(height: 4),
            ],
          ),
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
              await VideoShareService.shareVideo(
                videoUrl: videoUrl,
                videoId: videoId.isNotEmpty ? videoId : participationId,
                participationId: participationId.isNotEmpty ? participationId : null,
                title: 'Vidéo de challenge Academia',
              );
            } catch (_) {
              await Clipboard.setData(ClipboardData(text: videoUrl));
              await VideoShareService.copyLink(
                videoUrl: videoUrl,
                videoId: videoId.isNotEmpty ? videoId : participationId,
              );
              if (!context.mounted) return;
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
          onPressed: () async {
            // Vidéos de challenge → pipeline historique basé sur participationId.
            if (isChallenge && participationId.isNotEmpty) {
              if (remixType == 'duo') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Tu ne peux pas créer un duo à partir d\'un duo.',
                    ),
                  ),
                );
                return;
              }

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
              final newParticipationId = result['participation_id'] ?? '';
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
              return;
            }

            // Autres vidéos (free, etc.) → duo générique basé sur (video_type, video_id).
            if (videoType.isEmpty || videoId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Impossible d\'identifier cette vidéo pour le duo.',
                  ),
                ),
              );
              return;
            }

            if (remixType == 'duo') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Tu ne peux pas créer un duo à partir d\'un duo.',
                  ),
                ),
              );
              return;
            }

            final result = await provider.startDuoVideo(
              videoType: videoType,
              videoId: videoId,
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

            final newVideoId = result['video_id']?.toString() ?? '';
            if (newVideoId.isEmpty) {
              return;
            }

            // ignore: use_build_context_synchronously
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StudentChallengeVideoEditorScreen(
                  videoType: 'free',
                  freeVideoId: newVideoId,
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
            // Challenges → RPC historique basée sur participationId.
            if (isChallenge && participationId.isNotEmpty) {
              await _showReportDialog(context, provider, participationId);
              return;
            }

            // Autres vidéos → signalement générique (video_type, video_id).
            if (videoType.isNotEmpty && videoId.isNotEmpty) {
              await _showGenericReportDialog(
                context,
                provider,
                videoType,
                videoId,
              );
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Impossible d\'identifier cette vidéo pour le signalement.',
                ),
              ),
            );
          },
          icon: const Icon(
            Icons.flag_outlined,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const StudentChallengesTab(),
              ),
            );
          },
          icon: const Icon(
            Icons.emoji_events_outlined,
            color: Colors.white,
          ),
          tooltip: 'Voir les challenges',
        ),
      ],
    );
  }

  static Future<void> _showCommentsSheet(
    BuildContext context,
    StudentChallengesProvider provider,
    String participationId,
  ) async {
    await _showGenericCommentsSheet(
      context,
      provider,
      'challenge',
      participationId,
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
          content: SingleChildScrollView(
            child: Column(
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
  Map<String, dynamic>? _overlays;
  bool _isLoading = true;
  String? _error;
  String _url = '';

  @override
  void initState() {
    super.initState();
    _loadVideoAndOverlays();
  }

  @override
  void dispose() {
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

    String url = '';

    final playback = video['playback'];
    if (playback is Map) {
      final playbackMap = Map<String, dynamic>.from(playback);
      url = playbackMap['best_url']?.toString().trim() ?? '';
    }

    if (url.isEmpty) {
      final renditions = video['video_renditions'];
      if (renditions is Map) {
        final r = Map<String, dynamic>.from(renditions);
        final url480 = r['480p']?.toString() ?? '';
        final urlDefault = r['default']?.toString() ?? '';
        final urlLegacy = r['legacy_primary']?.toString() ?? '';
        if (url480.isNotEmpty) {
          url = url480;
        } else if (urlDefault.isNotEmpty) {
          url = urlDefault;
        } else if (urlLegacy.isNotEmpty) {
          url = urlLegacy;
        } else {
          // Fallback: use first available rendition URL
          for (final v in r.values) {
            final s = v?.toString() ?? '';
            if (s.isNotEmpty && s.startsWith('http')) {
              url = s;
              break;
            }
          }
        }
      }
    }

    if (url.isEmpty) {
      final rawUrl = video['video_url']?.toString() ?? '';
      url = rawUrl.trim();
    }

    if (url.isEmpty) {
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

    setState(() {
      _url = url;
      _overlays = overlays;
      _isLoading = false;
    });
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
              : _url.isNotEmpty
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: AcademiaPlaybackEngine.view(
                            url: _url,
                            autoplay: true,
                            looping: true,
                            muted: false,
                            showControls: true,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: VideoOverlaysLayer(overlays: _overlays),
                          ),
                        ),
                      ],
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

// ---------------------------------------------------------------------------
// TikTok-style double-tap heart animation helpers
// ---------------------------------------------------------------------------

class _HeartAnimData {
  final int id;
  final double x;
  final double y;
  final double rotation;

  const _HeartAnimData({
    required this.id,
    required this.x,
    required this.y,
    required this.rotation,
  });
}

class _DoubleTapHeart extends StatefulWidget {
  final _HeartAnimData data;
  final VoidCallback onDone;

  const _DoubleTapHeart({
    super.key,
    required this.data,
    required this.onDone,
  });

  @override
  State<_DoubleTapHeart> createState() => _DoubleTapHeartState();
}

class _DoubleTapHeartState extends State<_DoubleTapHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _translateY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _translateY = Tween<double>(begin: 0, end: -80).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    _ctrl.forward().then((_) {
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.data.x - 36,
      top: widget.data.y - 36,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _translateY.value),
            child: Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Transform.rotate(
                  angle: widget.data.rotation,
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.redAccent,
                    size: 72,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TikTok-style progress bar synced with actual video playback.
// Polls position/duration from the native player via AcademiaPlaybackController.
// ---------------------------------------------------------------------------
class _VideoProgressBar extends StatefulWidget {
  final AcademiaPlaybackController? controller;

  const _VideoProgressBar({super.key, this.controller});

  @override
  State<_VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<_VideoProgressBar> {
  Timer? _timer;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant _VideoProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _progress = 0.0;
      _timer?.cancel();
      _startPolling();
    }
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      final ctrl = widget.controller;
      if (ctrl == null || !ctrl.isAttached) return;
      try {
        final pos = await ctrl.getPosition();
        final dur = await ctrl.getDuration();
        if (!mounted) return;
        if (dur > 0) {
          setState(() {
            _progress = (pos / dur).clamp(0.0, 1.0);
          });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: _progress,
      backgroundColor: Colors.white.withValues(alpha: 0.3),
      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
      minHeight: 3,
    );
  }
}
