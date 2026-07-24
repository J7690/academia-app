import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
// tiktoklikescroller retiré : incompatible avec AndroidView PlatformViews.
// On utilise PageView.builder + _TikTokScrollPhysics custom à la place.
import '../../../providers/student_challenges_provider.dart';
import '../../../services/adaptive_quality_service.dart';
import '../../../services/video_analytics_service.dart';
import '../../../services/video_cache_service.dart';
import '../../../services/video_share_service.dart';
import '../../../games/services/watermark_service.dart';
import '../../../services/video_orientation_service.dart';
import '../../../services/video_player_lifecycle_service.dart';
import '../../../widgets/adaptive_video_container.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../video/academia_playback_engine.dart';
import '../../../widgets/video_overlays_layer.dart';
import '../../../widgets/report_content_sheet.dart';
import '../../../widgets/bobodo_state.dart';
import '../../challenge/smart_whiteboard/screens/smart_whiteboard_input_screen.dart';
import '../../../widgets/bobodo_view.dart';
import '../student_challenge_detail_screen.dart';
import '../student_challenge_video_editor_screen.dart';
import '../challenge_camera_capture_screen.dart';
import '../student_social_profile_screen.dart';
import '../student_dashboard_nav_controller.dart';
import '../student_recently_deleted_videos_screen.dart';
import '../challenge_live_screen.dart';
import '../../../games/services/game_live_service.dart';

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
                                        if (!isOwn && commentId.isNotEmpty)
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
                                            onSelected: (val) {
                                              if (val == 'report') {
                                                ReportContentSheet.show(context,
                                                  contentType: 'comment', contentId: commentId,
                                                  targetUserId: userId, contentPreview: content.length > 80 ? '${content.substring(0, 80)}...' : content);
                                              } else if (val == 'block') {
                                                UserModerationSheet.show(context, userId: userId, userName: name);
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(value: 'report', child: Text('Signaler', style: TextStyle(fontSize: 13))),
                                              PopupMenuItem(value: 'block', child: Text('Bloquer l\'auteur', style: TextStyle(fontSize: 13, color: Colors.red))),
                                            ],
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

/// Immutable snapshot used by Selector to avoid PageView rebuilds on unrelated
/// provider changes (likes, comments, etc.).
class _FeedState {
  final List<Map<String, dynamic>> videos;
  final bool isLoading;
  final String? error;
  const _FeedState({required this.videos, required this.isLoading, this.error});
}

class _ChallengeVideosFeed extends StatefulWidget {
  const _ChallengeVideosFeed();

  @override
  State<_ChallengeVideosFeed> createState() => _ChallengeVideosFeedState();
}

class _ChallengeVideosFeedState extends State<_ChallengeVideosFeed>
    with WidgetsBindingObserver {
  bool _initialized = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _pageSize = 20;

  // PageView controller — viewportFraction < 1 forces Flutter to pre-build adjacent pages.
  // This ensures N-1 and N+1 ExoPlayer instances exist and buffer while current plays.
  final PageController _pageController = PageController(viewportFraction: 0.9999);

  // Auto-pause on swipe: track controllers per page index
  final Map<int, AcademiaPlaybackController> _controllers = {};
  // Active page index — single source of truth. Driving it via a notifier lets
  // the progress bar + each video page react WITHOUT rebuilding the PageView
  // (the Selector's shouldRebuild blocks page-change rebuilds).
  final ValueNotifier<int> _activeIndex = ValueNotifier<int>(0);
  int get _currentPage => _activeIndex.value;
  // Controller bound to the progress bar; refreshed on page change and when the
  // active page's controller attaches (so the bar never stays on a stale player).
  final ValueNotifier<AcademiaPlaybackController?> _activeController =
      ValueNotifier<AcademiaPlaybackController?>(null);
  bool _wasPlayingBeforeBackground = false;

  // Live sessions en cours (Presence)
  List<Map<String, dynamic>> _livePlayers = [];
  StreamSubscription<List<Map<String, dynamic>>>? _liveSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('[RUNTIME LIFECYCLE] _ChallengeVideosFeed initState');
    WidgetsBinding.instance.addObserver(this);
    // Écouter les joueurs en live via Presence
    _liveSubscription = GameLiveService.watchLivePlayers().listen((players) {
      if (mounted) setState(() => _livePlayers = players);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _initialized) return;
      _initialized = true;
      // Initialize adaptive quality monitoring
      AdaptiveQualityService.init();
      final provider = context.read<StudentChallengesProvider>();
      await provider.loadChallengeVideos(limit: _pageSize);
      if (!mounted) return;
      final videos = provider.videos;
      debugPrint('[RUNTIME T0] Feed ouvert - videos=${videos.length}');
      setState(() {
        _hasMore = videos.length >= _pageSize;
      });
      // Preload first few videos
      _preloadAdjacentVideos(0, videos);
    });
  }

  @override
  void dispose() {
    debugPrint('[RUNTIME LIFECYCLE] _ChallengeVideosFeed dispose - _controllers size=${_controllers.length}');
    // Unregister all controllers from lifecycle service
    for (final entry in _controllers.entries) {
      VideoPlayerLifecycleService().unregisterController('feed_${entry.key}');
    }
    _controllers.clear();
    WidgetsBinding.instance.removeObserver(this);
    _liveSubscription?.cancel();
    _pageController.dispose();
    _activeIndex.dispose();
    _activeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // App going to background — pause all video immediately
        final currentCtrl = _controllers[_currentPage];
        _wasPlayingBeforeBackground =
            currentCtrl != null && currentCtrl.isAttached;
        _pauseAllControllers();
        debugPrint('[FEED] Lifecycle $state → paused all controllers');
        break;
      case AppLifecycleState.resumed:
        // App returning to foreground — resume only the active video if autoplay is enabled
        if (_wasPlayingBeforeBackground && !_feedAudioSuspended && VideoPlayerLifecycleService().feedAutoplayEnabled) {
          final currentCtrl = _controllers[_currentPage];
          if (currentCtrl != null && currentCtrl.isAttached) {
            currentCtrl.play();
            debugPrint('[FEED] Lifecycle resumed → playing index $_currentPage');
          }
          _wasPlayingBeforeBackground = false;
        }
        break;
    }
  }

  void _onPageChanged(int newIndex) {
    final previous = _activeIndex.value;
    debugPrint('[RUNTIME PRELOAD] Page changed: $previous -> $newIndex - _controllers size=${_controllers.length}');

    final provider = context.read<StudentChallengesProvider>();
    final videos = provider.videos;

    // Stop analytics for previous video
    if (previous < videos.length) {
      VideoAnalyticsService.onVideoStopped();
    }

    // Single source of truth: flip the active page. Each video page then
    // mutes/unmutes + pauses/plays itself and the progress bar rebinds —
    // WITHOUT rebuilding the PageView (the Selector blocks that).
    _activeIndex.value = newIndex;

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
      VideoPlayerLifecycleService().registerController('feed_$newIndex', newCtrl, 'feed');
    }

    // Authoritative enforcement: exactly the active player is audible & playing,
    // every other feed player is paused AND muted.
    _applyActivePlayback();

    // Clean up controllers far from current (keep only N-3..N+3)
    final removed = <int>[];
    _controllers.removeWhere((key, _) {
      if ((key - newIndex).abs() > 3) {
        removed.add(key);
        VideoPlayerLifecycleService().unregisterController('feed_$key');
        return true;
      }
      return false;
    });
    if (removed.isNotEmpty) {
      debugPrint('[RUNTIME PRELOAD]   Cleaned up controllers: $removed - new size=${_controllers.length}');
    }

    // Preload adjacent videos
    _preloadAdjacentVideos(newIndex, videos);
  }

  /// Authoritative single-playback enforcement. Exactly the active page plays
  /// with sound; every other feed player is paused AND muted. Re-applied on
  /// page change and whenever a controller attaches, so a late-created native
  /// player (whose `autoplay` creation param can race the page change) can never
  /// bleed audio from videos "below" the current one.
  void _applyActivePlayback() {
    final active = _activeIndex.value;
    // Keep the progress bar bound to the live controller (may be null until the
    // page's player attaches — re-applied from onControllerReady).
    _activeController.value = _controllers[active];

    final bool autoplayOk =
        !_feedAudioSuspended && VideoPlayerLifecycleService().feedAutoplayEnabled;

    for (final entry in _controllers.entries) {
      final ctrl = entry.value;
      if (!ctrl.isAttached) continue;
      if (autoplayOk && entry.key == active) {
        ctrl.setVolume(1.0);
        ctrl.play();
      } else {
        ctrl.pause();
        ctrl.setVolume(0.0);
      }
    }
  }

  void _preloadAdjacentVideos(int currentIndex, List<Map<String, dynamic>> videos) {
    // Cache best URLs for quick access — actual buffering is done natively by ExoPlayer
    for (int i = 1; i <= 3; i++) {
      final nextIdx = currentIndex + i;
      if (nextIdx < videos.length) {
        final url = AdaptiveQualityService.selectBestUrlFromVideo(videos[nextIdx]);
        if (url.isNotEmpty) {
          final videoId = videos[nextIdx]['participation_id']?.toString() ?? videos[nextIdx]['video_id']?.toString() ?? '';
          if (videoId.isNotEmpty) {
            VideoCacheService.putBestUrl(videoId, url);
          }
        }
      }
    }
  }

  Future<void> _reloadAfterDeletion() async {
    final provider = context.read<StudentChallengesProvider>();
    _controllers.clear();
    _activeIndex.value = 0;
    _activeController.value = null;
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
    // Use Selector to only rebuild when the video list identity changes,
    // not on likes/comments/other provider fields.
    return Selector<StudentChallengesProvider, _FeedState>(
      selector: (_, p) => _FeedState(
        videos: p.videos,
        isLoading: p.isLoadingVideos,
        error: p.error,
      ),
      shouldRebuild: (prev, next) {
        // Rebuild only when video list, loading state, or error actually change
        return !identical(prev.videos, next.videos) ||
            prev.isLoading != next.isLoading ||
            prev.error != next.error;
      },
      builder: (context, state, child) {
        final videos = state.videos;

        if (state.isLoading && videos.isEmpty) {
          return const LoadingWidget(
            message: 'Chargement des vidéos...',
          );
        }

        if (state.error != null && videos.isEmpty) {
          return CustomErrorWidget(
            error: state.error!,
            onRetry: () => context.read<StudentChallengesProvider>().loadChallengeVideos(),
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
              allowImplicitScrolling: true, // Pre-build off-screen pages
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
                  index: index,
                  activeIndex: _activeIndex,
                  onDeleted: _reloadAfterDeletion,
                  onControllerReady: (ctrl) {
                    _controllers[index] = ctrl;
                    // A freshly-attached player must immediately obey
                    // single-playback, and the progress bar must bind to it if
                    // this is the active page.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _applyActivePlayback();
                    });
                  },
                );
              },
            ),
            // Live bubbles at top
            if (_livePlayers.isNotEmpty)
              Positioned(
                top: MediaQuery.of(context).padding.top + 4,
                left: 0,
                right: 0,
                child: _buildLiveBubbles(),
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

  Widget _buildLiveBubbles() {
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _livePlayers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final player = _livePlayers[i];
          final name = (player['player_name'] ?? player['user_id'] ?? '').toString();
          final gameType = (player['game_type'] ?? '').toString();
          final sessionId = (player['session_id'] ?? '').toString();
          final avatarUrl = (player['player_avatar'] ?? '').toString();
          final displayName = name.length > 8 ? '${name.substring(0, 8)}…' : name;

          return GestureDetector(
            onTap: () {
              _pauseAllControllers();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChallengeLiveScreen(
                    sessionId: sessionId,
                    isHost: false,
                  ),
                ),
              ).then((_) {
                if (!mounted) return;
                final ctrl = _controllers[_currentPage];
                if (ctrl != null && ctrl.isAttached) ctrl.play();
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red, width: 2.5),
                      ),
                      child: ClipOval(
                        child: avatarUrl.isNotEmpty
                            ? Image.network(avatarUrl, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.person, color: Colors.white54, size: 28),
                                ))
                            : Container(
                                color: Colors.grey[800],
                                child: const Icon(Icons.sports_esports, color: Colors.white54, size: 28),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: -4,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LIVE',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  displayName.isNotEmpty ? displayName : gameType,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
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
          // TikTok-style progress bar synced with actual video playback.
          // Bound to the active controller via a notifier so it rebinds on page
          // change (the Selector won't rebuild the bottom bar on swipe).
          ValueListenableBuilder<AcademiaPlaybackController?>(
            valueListenable: _activeController,
            builder: (_, ctrl, __) => SizedBox(
              height: 3,
              child: _VideoProgressBar(
                key: ObjectKey(ctrl),
                controller: ctrl,
              ),
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
                // 2. Arène (hub : Challenges, Live, Duo, Compétitions, Classements)
                buildNavItem(
                  icon: Icons.emoji_events_outlined,
                  label: 'Arène',
                  onTap: () {
                    _pauseAllControllers();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          backgroundColor: const Color(0xFFF3F4F6),
                          appBar: AppBar(
                            title: const Text('Arène'),
                            backgroundColor: const Color(0xFF1EA75C),
                            foregroundColor: Colors.white,
                          ),
                          body: const _AreneHubBody(),
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
                // 5. Profil TikTok-like
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

  /// Ouvre le menu de création (Filmer, Importer, Publication, Smart Whiteboard)
  Future<void> _openCreateVideoFromFeed(BuildContext context) async {
    if (!context.mounted) return;

    debugPrint('[RUNTIME T1] Clic sur + - _controllers size=${_controllers.length}');

    // Suspend feed audio (pause + mute) before showing menu.
    _suspendFeedAudio();

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.black87,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Créer du contenu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.videocam, color: Color(0xFF1EA75C)),
                title: const Text('Filmer une vidéo', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext, 'camera');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF1EA75C)),
                title: const Text('Importer de la galerie', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext, 'gallery');
                },
              ),
              ListTile(
                leading: const Icon(Icons.article, color: Color(0xFF1EA75C)),
                title: const Text('Publication texte', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext, 'text');
                },
              ),
              ListTile(
                leading: const Icon(Icons.dashboard, color: Color(0xFF1EA75C)),
                title: const Text('Smart Whiteboard', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext, 'whiteboard');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (!mounted) return;

    // Release feed audio if menu was cancelled
    if (result == null) {
      _releaseFeedAudio();
      final ctrl = _controllers[_currentPage];
      if (ctrl != null && ctrl.isAttached) {
        ctrl.play();
      }
      return;
    }

    // Handle selected option
    switch (result) {
      case 'camera':
        await _openCameraCapture(context);
        break;
      case 'gallery':
        await _openGalleryImport(context);
        break;
      case 'text':
        await _openTextPublication(context);
        break;
      case 'whiteboard':
        await _openSmartWhiteboard(context);
        break;
    }
  }

  /// Ouvre la caméra TikTok
  Future<void> _openCameraCapture(BuildContext context) async {
    if (!context.mounted) return;

    debugPrint('[RUNTIME T2] Ouverture CameraCapture - _controllers size=${_controllers.length}');

    final segments = await Navigator.of(context).push<List<XFile>?>(
      MaterialPageRoute(
        builder: (_) => const ChallengeCameraCaptureScreen(),
      ),
    );

    if (!mounted) return;

    debugPrint('[RUNTIME T3] Retour Galerie - segments=${segments?.length ?? 0} - _controllers size=${_controllers.length}');

    // Si l'utilisateur a capturé des segments, ouvrir le Studio avec les segments
    if (segments != null && segments.isNotEmpty) {
      await _openStudioWithSegments(context, segments, 'camera');
    } else {
      _releaseFeedAudio();
      final ctrl = _controllers[_currentPage];
      if (ctrl != null && ctrl.isAttached) {
        ctrl.play();
      }
    }
  }

  /// Ouvre l'import galerie
  Future<void> _openGalleryImport(BuildContext context) async {
    if (!context.mounted) return;

    debugPrint('[RUNTIME T2] Ouverture Import Galerie - _controllers size=${_controllers.length}');

    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);

      if (!mounted) return;

      debugPrint('[RUNTIME T3] Retour Galerie - picked=${picked != null} - _controllers size=${_controllers.length}');

      if (picked != null) {
        await _openStudioWithSegments(context, [picked], 'gallery');
      } else {
        _releaseFeedAudio();
        final ctrl = _controllers[_currentPage];
        if (ctrl != null && ctrl.isAttached) {
          ctrl.play();
        }
      }
    } catch (e) {
      debugPrint('[Gallery] Picker error: $e');
      if (!mounted) return;
      _releaseFeedAudio();
      final ctrl = _controllers[_currentPage];
      if (ctrl != null && ctrl.isAttached) {
        ctrl.play();
      }
    }
  }

  /// Ouvre la publication texte
  Future<void> _openTextPublication(BuildContext context) async {
    if (!context.mounted) return;

    debugPrint('[RUNTIME T2] Ouverture Publication Texte - _controllers size=${_controllers.length}');

    // TODO: Implement text publication
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Publication texte à implémenter')),
    );

    _releaseFeedAudio();
    final ctrl = _controllers[_currentPage];
    if (ctrl != null && ctrl.isAttached) {
      ctrl.play();
    }
  }

  /// Ouvre Smart Whiteboard
  Future<void> _openSmartWhiteboard(BuildContext context) async {
    if (!context.mounted) return;

    debugPrint('[RUNTIME T2] Ouverture Smart Whiteboard - _controllers size=${_controllers.length}');

    final result = await Navigator.of(context).push<bool?>(
      MaterialPageRoute(
        builder: (_) => const SmartWhiteboardInputScreen(),
      ),
    );

    if (!mounted) return;
    await _onReturnFromStudio(result == true);
  }

  /// Ouvre le Studio avec des segments (réutilisé par camera et gallery)
  Future<void> _openStudioWithSegments(BuildContext context, List<XFile> segments, String mode) async {
    if (!context.mounted) return;

    // Keep feed audio suspended (pause + mute) before the editor.
    _suspendFeedAudio();
    
    debugPrint('[RUNTIME T4] Vidéo sélectionnée - _controllers size=${_controllers.length}');
    
    debugPrint('[RUNTIME T5] Ouverture Editor - _controllers size=${_controllers.length}');
    
    // Log memory before opening editor
    debugPrint('[RUNTIME MEMORY] Before opening editor - ${_getMemoryInfo()}');
    
    final published = await Navigator.of(context).push<bool?>(
      MaterialPageRoute(
        builder: (_) => StudentChallengeVideoEditorScreen(
          videoType: 'free',
          initialMode: mode,
          initialSegments: segments,
        ),
      ),
    );

    if (!mounted) return;
    await _onReturnFromStudio(published == true);
  }

  /// Called when returning from the Studio. If [published] is true,
  /// reloads the feed and scrolls to index 0 (the just-published video).
  Future<void> _onReturnFromStudio(bool published) async {
    final provider = context.read<StudentChallengesProvider>();
    // Re-enable feed audio now that we are back on the feed.
    _releaseFeedAudio();
    if (published) {
      // Reload the feed to include the newly published video
      await provider.loadChallengeVideos(limit: _pageSize);
      if (!mounted) return;
      // Scroll to the first video (most recent = the one just published)
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _activeIndex.value = 0;
      _activeController.value = null;
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
    debugPrint('[RUNTIME] _pauseAllControllers - _controllers size=${_controllers.length}');
    int pausedCount = 0;
    for (final entry in _controllers.entries) {
      if (entry.value.isAttached) {
        entry.value.pause();
        pausedCount++;
      }
    }
    debugPrint('[RUNTIME] _pauseAllControllers - paused=$pausedCount');
  }

  /// True while the feed is left for the Studio/another route: feed players
  /// must stay paused AND muted so their audio never bleeds into the Studio.
  bool _feedAudioSuspended = false;

  /// Fully suspend feed audio when leaving the feed (Studio, etc.): pause AND
  /// mute every feed player, and block feed playback until [_releaseFeedAudio].
  void _suspendFeedAudio() {
    _feedAudioSuspended = true;
    for (final entry in _controllers.entries) {
      if (entry.value.isAttached) {
        entry.value.pause();
        entry.value.setVolume(0.0);
      }
    }
    debugPrint('[FEED_AUDIO] suspended (paused + muted) ${_controllers.length} controllers');
  }

  /// Release the suspension when returning to the feed: unmute every player so
  /// the active video plays with sound again.
  void _releaseFeedAudio() {
    _feedAudioSuspended = false;
    // Re-assert single-playback: only the active video regains sound, every
    // other feed player stays paused + muted.
    _applyActivePlayback();
    debugPrint('[FEED_AUDIO] released → single-playback re-applied (${_controllers.length} controllers)');
  }

  /// Get memory info for runtime monitoring
  String _getMemoryInfo() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'controllers=${_controllers.length}';
    }
    return 'controllers=${_controllers.length}';
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

  // Ultra-fast spring: instant snap like TikTok (no bounce)
  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.3,
        stiffness: 200,
        damping: 22,
      );

  // Very low fling threshold: lightest touch triggers page change
  @override
  double get minFlingVelocity => 30.0;

  // Low drag threshold: ~10% of page height triggers transition
  @override
  double get dragStartDistanceMotionThreshold => 2.0;
}

class _ChallengeVideoItem extends StatefulWidget {
  final Map<String, dynamic> video;
  final ValueChanged<AcademiaPlaybackController>? onControllerReady;
  final Future<void> Function()? onDeleted;
  final int index;
  final ValueListenable<int> activeIndex;

  const _ChallengeVideoItem({
    Key? key,
    required this.video,
    required this.index,
    required this.activeIndex,
    this.onControllerReady,
    this.onDeleted,
  }) : super(key: key);

  @override
  State<_ChallengeVideoItem> createState() => _ChallengeVideoItemState();
}

class _ChallengeVideoItemState extends State<_ChallengeVideoItem>
    with AutomaticKeepAliveClientMixin {
  bool _initialized = false;
  // This page is the live one. Drives autoplay/mute so each page manages its own
  // audio independently of the pruned controllers map.
  late bool _isActive = widget.activeIndex.value == widget.index;

  String? _errorMessage;
  String _selectedUrl = '';
  double _videoAspectRatio = 16.0 / 9.0; // Default to horizontal

  @override
  bool get wantKeepAlive => true;

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
    debugPrint('[RUNTIME LIFECYCLE] _ChallengeVideoItem initState - label=$_videoLabel isActive=$_isActive');
    widget.activeIndex.addListener(_handleActiveIndexChanged);
    widget.onControllerReady?.call(_playbackController);
    _startInit();
  }

  void _handleActiveIndexChanged() {
    final active = widget.activeIndex.value == widget.index;
    if (active == _isActive) return;
    if (!mounted) {
      _isActive = active;
      return;
    }
    // Rebuild so the player view's autoplay/muted props flip → the engine applies
    // play/pause + volume. Makes each page responsible for its own audio.
    setState(() => _isActive = active);
  }

  @override
  void didUpdateWidget(covariant _ChallengeVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex) {
      oldWidget.activeIndex.removeListener(_handleActiveIndexChanged);
      widget.activeIndex.addListener(_handleActiveIndexChanged);
    }
    final active = widget.activeIndex.value == widget.index;
    if (active != _isActive) {
      _isActive = active;
    }
  }

  Future<void> _startInit() async {
    String url = '';

    // Extract video dimensions from renditions to calculate aspect ratio
    _extractVideoDimensions();

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

    debugPrint('[VIDEO_ITEM] _startInit  label=$_videoLabel  url=${_selectedUrl.length > 80 ? _selectedUrl.substring(0, 80) : _selectedUrl}  aspectRatio=$_videoAspectRatio');

    if (_selectedUrl.isEmpty) {
      _setError("Aucune URL vidéo disponible (renditions absentes ou invalides).");
      return;
    }

    if (!mounted) return;
    debugPrint('[VIDEO_ITEM] _startInit OK -> _initialized=true  label=$_videoLabel');
    setState(() => _initialized = true);
  }

  void _extractVideoDimensions() {
    // Try to extract dimensions from video_renditions
    final renditions = widget.video['video_renditions'];
    if (renditions is Map) {
      final r = Map<String, dynamic>.from(renditions);
      
      // Check for width/height in renditions
      final width = r['width']?.toInt();
      final height = r['height']?.toInt();
      
      if (width != null && height != null && width > 0 && height > 0) {
        _videoAspectRatio = width / height;
        debugPrint('[VIDEO_ITEM] Dimensions from renditions: ${width}x${height} -> aspectRatio=$_videoAspectRatio');
        return;
      }
      
      // Check individual rendition dimensions
      for (final key in ['1080p', '720p', '480p', '360p', 'default']) {
        final rendition = r[key];
        if (rendition is Map) {
          final rw = rendition['width']?.toInt();
          final rh = rendition['height']?.toInt();
          if (rw != null && rh != null && rw > 0 && rh > 0) {
            _videoAspectRatio = rw / rh;
            debugPrint('[VIDEO_ITEM] Dimensions from rendition $key: ${rw}x${rh} -> aspectRatio=$_videoAspectRatio');
            return;
          }
        }
      }
    }
    
    // Try to extract from video metadata
    final videoWidth = widget.video['width']?.toInt();
    final videoHeight = widget.video['height']?.toInt();
    if (videoWidth != null && videoHeight != null && videoWidth > 0 && videoHeight > 0) {
      _videoAspectRatio = videoWidth / videoHeight;
      debugPrint('[VIDEO_ITEM] Dimensions from video metadata: ${videoWidth}x${videoHeight} -> aspectRatio=$_videoAspectRatio');
      return;
    }
    
    // Fallback to default horizontal
    _videoAspectRatio = 16.0 / 9.0;
    debugPrint('[VIDEO_ITEM] No dimensions found, using default aspectRatio=$_videoAspectRatio');
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

  BoxFit _getOptimalBoxFit() {
    // Detect video orientation from aspect ratio
    final orientation = VideoOrientationService.detectFromRatio(
      _videoAspectRatio > 0 ? _videoAspectRatio : 16.0 / 9.0,
    );
    
    // Return optimal BoxFit based on orientation
    return VideoOrientationService.getOptimalBoxFit(orientation);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_initialized) return;
    final now = DateTime.now();
    final dt = now.difference(_lastTapTime).inMilliseconds;
    final pos = details.globalPosition;

    if (dt < 250 && (pos - _lastTapPosition).distance < 60) {
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
      _singleTapTimer = Timer(const Duration(milliseconds: 180), () {
        _onSingleTap();
      });
    }
  }

  @override
  void dispose() {
    debugPrint('[VIDEO_ITEM] dispose  label=$_videoLabel');
    widget.activeIndex.removeListener(_handleActiveIndexChanged);
    _singleTapTimer?.cancel();
    super.dispose();
  }

  /// Résout l'URL du poster (miniature) depuis le manifest ou les données vidéo.
  String _resolvePosterUrl(Map<String, dynamic> video) {
    final playback = video['playback'];
    String posterUrl = '';
    if (playback is Map) {
      posterUrl = (playback['poster_url'] ?? '').toString().trim();
    }
    if (posterUrl.isEmpty) {
      posterUrl = (video['poster_url'] ?? video['thumbnail_url'] ?? '').toString().trim();
    }
    return posterUrl;
  }

  Widget _buildLoadingPlaceholder(Map<String, dynamic> video) {
    final posterUrl = _resolvePosterUrl(video);

    if (posterUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            posterUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          ),
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          ),
        ],
      );
    }

    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white54,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    final video = widget.video;
    final videoType = video['video_type']?.toString() ?? 'challenge';
    final isChallenge = videoType != 'free';
    final challengeTitle = isChallenge
        ? (video['challenge_title']?.toString() ?? '')
        : (video['title']?.toString() ?? '');
    final challengeType = isChallenge
        ? (video['challenge_type']?.toString() ?? '')
        : '';
    // final difficulty = isChallenge ? (video['difficulty']?.toString() ?? '') : '';
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
    // Signal contextuel unique
    if (challengeType.isNotEmpty) {
      metaParts.add(
        challengeType == 'mission' ? '🎯 Mission' : '⚔️ Concours',
      );
    }
    // Récompense
    if (points != null && points > 0) {
      metaParts.add('$points pts');
    }
    // Statut personnel (si disponible)
    final myStatus = video['my_status']?.toString() ?? '';
    if (myStatus.isNotEmpty) {
      metaParts.add(myStatus);
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
            authorUserId: authorUserId,
            authorName: authorName,
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
                                autoplay: _isActive,
                                looping: true,
                                muted: !_isActive,
                                showControls: false,
                                // Plein écran net façon TikTok : on remplit le cadre
                                // 9:16 (les bords qui débordent sont rognés), sans flou
                                // ni perte de définition. Cf. recherche TikTok 9:16.
                                fit: BoxFit.cover,
                                playbackController: _playbackController,
                                videoAspectRatio: _videoAspectRatio > 0 ? _videoAspectRatio : null,
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
                  : _buildLoadingPlaceholder(video),
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
          height: 120,
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
          authorUserId: authorUserId,
          authorName: authorName,
          onDeleted: widget.onDeleted,
        ),
        // Sélecteur de flux (Pour toi / Challenges / Live) — visuel façon TikTok.
        // Le filtrage réel du feed sera branché ensuite ; ici on pose l'UI.
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 0,
          right: 0,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _feedTab(context, 'Pour toi', false),
                const SizedBox(width: 18),
                _feedTab(context, 'Challenges', true),
                const SizedBox(width: 18),
                _feedTab(context, 'Live', false),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _feedTab(BuildContext context, String label, bool active) {
    return GestureDetector(
      onTap: active
          ? null
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bientôt disponible')),
              );
            },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white70,
              fontSize: 16,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
          const SizedBox(height: 3),
          if (active) Container(width: 20, height: 2.5, color: Colors.white),
        ],
      ),
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
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  authorName.isNotEmpty ? authorName : '@${authorUserId.substring(0, 8)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (challengeTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                challengeTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (metaParts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                metaParts.join(' • '),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
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
    required String authorUserId,
    required String authorName,
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
        authorUserId: authorUserId,
        authorName: authorName,
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
  final String authorUserId;
  final String authorName;
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
    required this.authorUserId,
    required this.authorName,
    required this.onDeleted,
  }) : super(key: key);

  static Future<bool> _ensureMediaSavePermission() async {
    if (kIsWeb) return false;

    if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      return status.isGranted;
    }

    // Android: saver_gallery docs say SDK 29+ with skipIfExists:false
    // does NOT require any permission. Only SDK < 29 needs storage.
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = deviceInfo.version.sdkInt;
      debugPrint('[DL-PERM] Android SDK=$sdkInt');
      if (sdkInt >= 29) {
        // Scoped storage: no permission needed for saving
        debugPrint('[DL-PERM] SDK>=29, no permission needed');
        return true;
      }
      // SDK < 29: need WRITE_EXTERNAL_STORAGE
      final storageStatus = await Permission.storage.request();
      debugPrint('[DL-PERM] SDK<29, storage permission=$storageStatus');
      return storageStatus.isGranted;
    }

    return false;
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
      debugPrint('╔══════════════════════════════════════════════════════');
      debugPrint('║ [DL-FLOW] ══ DOWNLOAD START ══');
      debugPrint('║ videoType=$videoType');
      debugPrint('║ videoId=$videoId');
      debugPrint('║ videoAssetId="$videoAssetId"');
      debugPrint('║ fallbackVideoUrl="${fallbackVideoUrl.length > 60 ? '${fallbackVideoUrl.substring(0, 60)}...' : fallbackVideoUrl}"');
      debugPrint('║ existing rendition URL="${existing.length > 60 ? '${existing.substring(0, 60)}...' : existing}"');
      debugPrint('║ videoRenditions=$videoRenditions');
      debugPrint('╚══════════════════════════════════════════════════════');
      try {
        String urlToDownload = existing;
        // Vrai indicateur : la vidéo pointée est-elle filigranée côté serveur ?
        // Si on retombe sur la source brute, on appliquera le filigrane localement.
        bool serverWatermarked = existing.isNotEmpty;
        debugPrint('[DL-FLOW] STEP 0: urlToDownload from existing="${urlToDownload.isEmpty ? "(empty)" : "len=${urlToDownload.length}"}"');

        // ── 1. Try server-side watermarked rendition (quick check) ──
        // If we have a fallback URL, use a very short timeout (3s) so we
        // don't waste time waiting for a server rendition that may not exist.
        // If no fallback, allow longer timeout (10s) + polling.
        final bool hasFallback = fallbackVideoUrl.trim().isNotEmpty;
        // On attend réellement le rendu filigrané côté serveur (Kamatera),
        // même si un fallback existe : le logo Academia doit toujours être présent.
        // Le rendu serveur est rapide (quelques secondes) ; en dernier recours
        // seulement, on incruste le filigrane localement (cf. STEP 5b).
        const rpcTimeout = Duration(seconds: 12);
        debugPrint('[DL-FLOW] hasFallback=$hasFallback → rpcTimeout=${rpcTimeout.inSeconds}s');

        if (urlToDownload.isEmpty && videoAssetId.trim().isNotEmpty) {
          debugPrint('[DL-FLOW] STEP 1: requesting server export for asset=$videoAssetId');
          phase.value = 'prepare';
          message.value = 'Préparation en cours...';

          final resp = await _withTimeout<Map<String, dynamic>?>(
            provider.requestVideoExportWatermarked(videoAssetId: videoAssetId),
            rpcTimeout,
          );

          debugPrint('[DL-FLOW] STEP 1 result: resp=${resp == null ? "NULL (timeout or error)" : resp.toString()}');
          if (resp != null) {
            final status = resp['status']?.toString() ?? '';
            final url = resp['url']?.toString() ?? '';
            debugPrint('[DL-FLOW] STEP 1: status="$status" urlLen=${url.length}');
            if (status == 'ready' && url.trim().isNotEmpty) {
              urlToDownload = url.trim();
              serverWatermarked = true;
              debugPrint('[DL-FLOW] STEP 1: GOT URL from server rendition');
            } else {
              debugPrint('[DL-FLOW] STEP 1: NOT ready, will poll or fallback');
            }
          } else {
            debugPrint('[DL-FLOW] STEP 1: provider.error="${provider.error}"');
          }
        } else {
          debugPrint('[DL-FLOW] STEP 1 SKIP: existing="${urlToDownload.isNotEmpty ? "has URL" : "(empty)"}" assetId="${videoAssetId.trim().isEmpty ? "(empty)" : videoAssetId}"');
        }

        // ── 2. Brief polling — only if no fallback URL available ──
        // When a fallback exists, skip polling entirely (saves 15s+ of wait).
        if (urlToDownload.isEmpty && videoAssetId.trim().isNotEmpty) {
          debugPrint('[DL-FLOW] STEP 2: start polling (15s max) for watermarked rendition...');
          final deadline = DateTime.now().add(const Duration(seconds: 15));
          int pollCount = 0;

          while (!cancelled && DateTime.now().isBefore(deadline)) {
            await Future.delayed(const Duration(seconds: 3));
            pollCount++;
            debugPrint('[DL-FLOW] STEP 2: poll #$pollCount...');
            final st = await _withTimeout<Map<String, dynamic>?>(
              provider.getVideoExportWatermarkedStatus(videoAssetId: videoAssetId),
              const Duration(seconds: 8),
            );
            if (st == null) {
              debugPrint('[DL-FLOW] STEP 2: poll #$pollCount returned NULL — breaking');
              break;
            }

            final status = st['status']?.toString() ?? '';
            final url = st['url']?.toString() ?? '';
            debugPrint('[DL-FLOW] STEP 2: poll #$pollCount status="$status" urlLen=${url.length}');

            if (status == 'ready' && url.trim().isNotEmpty) {
              urlToDownload = url.trim();
              serverWatermarked = true;
              debugPrint('[DL-FLOW] STEP 2: GOT URL from polling');
              break;
            }
            if (status == 'failed') {
              debugPrint('[DL-FLOW] STEP 2: status=failed — breaking');
              break;
            }
          }
          debugPrint('[DL-FLOW] STEP 2 done: urlToDownload="${urlToDownload.isEmpty ? "(empty)" : "len=${urlToDownload.length}"}"');
        } else {
          debugPrint('[DL-FLOW] STEP 2 SKIP: ${hasFallback ? "has fallback, skip polling" : "urlToDownload=${urlToDownload.isNotEmpty ? "has URL" : "(empty)"}"}');
        }

        // ── 3. Fallback: use source video URL (already watermarked locally) ──
        if (urlToDownload.isEmpty && fallbackVideoUrl.trim().isNotEmpty) {
          debugPrint('[DL-FLOW] STEP 3: using FALLBACK URL (source video, NOT watermarked)');
          urlToDownload = fallbackVideoUrl.trim();
          serverWatermarked = false;
        } else if (urlToDownload.isEmpty) {
          debugPrint('[DL-FLOW] STEP 3: NO fallback available either! fallbackVideoUrl="${fallbackVideoUrl}"');
        } else {
          debugPrint('[DL-FLOW] STEP 3 SKIP: already have URL');
        }

        if (urlToDownload.isEmpty) {
          debugPrint('[DL-FLOW] ✘ ABORT: no URL available at all');
          phase.value = 'error';
          message.value = 'Vidéo indisponible. Réessaie plus tard.';
          canClose.value = true;
          return;
        }

        if (cancelled) {
          debugPrint('[DL-FLOW] ✘ ABORT: cancelled by user');
          canClose.value = true;
          return;
        }

        debugPrint('[DL-FLOW] STEP 4: requesting storage permission...');
        final okPerm = await _ensureMediaSavePermission();
        debugPrint('[DL-FLOW] STEP 4: permission=$okPerm');
        if (!okPerm) {
          phase.value = 'error';
          message.value = 'Permission refusée pour enregistrer la vidéo.';
          canClose.value = true;
          return;
        }

        // ── 4. Download ──
        debugPrint('[DL-FLOW] STEP 5: downloading from URL="${urlToDownload.length > 80 ? '${urlToDownload.substring(0, 80)}...' : urlToDownload}"');
        phase.value = 'download';
        message.value = 'Téléchargement en cours...';
        progress.value = 0.0;

        final client = http.Client();
        try {
          final uri = Uri.parse(urlToDownload);
          debugPrint('[DL-FLOW] STEP 5: parsed URI scheme=${uri.scheme} host=${uri.host} path=${uri.path.length > 50 ? '${uri.path.substring(0, 50)}...' : uri.path}');
          final req = http.Request('GET', uri);
          debugPrint('[DL-FLOW] STEP 5: sending HTTP GET...');
          final res = await client.send(req);
          debugPrint('[DL-FLOW] STEP 5: HTTP response status=${res.statusCode} contentLength=${res.contentLength}');

          if (res.statusCode != 200) {
            debugPrint('[DL-FLOW] ✘ ABORT: HTTP ${res.statusCode}');
            phase.value = 'error';
            message.value = 'Impossible de télécharger la vidéo.';
            canClose.value = true;
            return;
          }

          final total = res.contentLength;
          int received = 0;
          final tmpDir = await getTemporaryDirectory();
          final safeName = 'academia_${videoType}_$videoId';
          File file = File('${tmpDir.path}/$safeName.mp4');
          debugPrint('[DL-FLOW] STEP 5: saving to ${file.path} (total=${total ?? "unknown"} bytes)');
          final sink = file.openWrite();
          try {
            await for (final chunk in res.stream) {
              if (cancelled) {
                debugPrint('[DL-FLOW] ✘ ABORT: cancelled during download at $received bytes');
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

          final fileSize = await file.length();
          debugPrint('[DL-FLOW] STEP 5 done: downloaded $received bytes, file size=$fileSize bytes');

          // ── 4b. Filigrane de repli (garantie « logo toujours présent ») ──
          // Si la vidéo téléchargée n'a PAS été filigranée côté serveur
          // (on est retombé sur la source brute), on incruste le logo Academia
          // localement, avec le même rythme TikTok (saut 4 coins / 5s).
          if (!serverWatermarked) {
            debugPrint('[DL-FLOW] STEP 5b: source non filigranée → filigrane local Academia');
            phase.value = 'save';
            message.value = 'Application du filigrane Academia...';
            progress.value = null;
            try {
              final wmPath = await WatermarkService.addWatermark(file.path);
              if (wmPath != file.path && await File(wmPath).exists()) {
                file = File(wmPath);
                debugPrint('[DL-FLOW] STEP 5b: filigrane local appliqué → $wmPath');
              } else {
                debugPrint('[DL-FLOW] STEP 5b: filigrane local ignoré (pas de sortie)');
              }
            } catch (e) {
              debugPrint('[DL-FLOW] STEP 5b: erreur filigrane local: $e');
            }
          }

          // ── 5. Save to gallery ──
          debugPrint('[DL-FLOW] STEP 6: saving to gallery...');
          phase.value = 'save';
          message.value = 'Enregistrement dans la galerie...';
          progress.value = null;

          final SaveResult result = await SaverGallery.saveFile(
            filePath: file.path,
            fileName: '$safeName.mp4',
            androidRelativePath: 'Movies',
            skipIfExists: false,
          );
          debugPrint('[DL-FLOW] STEP 6: SaverGallery result=$result isSuccess=${result.isSuccess} error=${result.errorMessage}');

          final ok = result.isSuccess;
          debugPrint('[DL-FLOW] STEP 6: isSuccess=$ok');
          if (ok) {
            debugPrint('[DL-FLOW] ✔ SUCCESS: video saved to gallery');
            phase.value = 'done';
            message.value = 'Vidéo enregistrée dans ta galerie !';
            progress.value = 1.0;
            canClose.value = true;
          } else {
            debugPrint('[DL-FLOW] ✘ FAIL: SaverGallery returned false');
            phase.value = 'error';
            message.value = 'Impossible d\'enregistrer la vidéo.';
            canClose.value = true;
          }
        } finally {
          client.close();
        }
      } catch (e, stackTrace) {
        debugPrint('[DL-FLOW] ✘ EXCEPTION: $e');
        debugPrint('[DL-FLOW] ✘ STACK: ${stackTrace.toString().split('\n').take(5).join('\n')}');
        phase.value = 'error';
        message.value = 'Une erreur est survenue. Réessaie.';
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
          Future.microtask(() async {
            await run();
            // Auto-close after success or error
            if (phase.value == 'done' || phase.value == 'error') {
              await Future.delayed(const Duration(milliseconds: 1500));
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop(phase.value == 'done');
              }
            }
          });
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
        // Avatar auteur + Suivre (visuel façon TikTok ; le suivi réel arrive
        // avec son backend — l'appui ouvre déjà le profil du créateur).
        if (authorUserId.isNotEmpty) ...[
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
            child: SizedBox(
              width: 52,
              height: 58,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade800,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF1EA75C),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Action principale: Like
        IconButton(
          onPressed: () async {
            bool ok = false;
            if (isChallenge && participationId.isNotEmpty) {
              if (hasLiked) {
                ok = await provider.unlikeChallengeVideo(participationId: participationId);
              } else {
                ok = await provider.likeChallengeVideo(participationId: participationId);
              }
            } else if (videoType.isNotEmpty && videoId.isNotEmpty) {
              if (hasLiked) {
                ok = await provider.unlikeVideo(videoType: videoType, videoId: videoId);
              } else {
                ok = await provider.likeVideo(videoType: videoType, videoId: videoId);
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Impossible d\'identifier cette vidéo pour le like.')),
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
            size: 34,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
        Text(
          '$likesCount',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        const SizedBox(height: 8),
        // Commentaires (action visible)
        IconButton(
          onPressed: () async {
            if (isChallenge && participationId.isNotEmpty) {
              await _showCommentsSheet(context, provider, participationId);
            } else if (videoType.isNotEmpty && videoId.isNotEmpty) {
              await _showGenericCommentsSheet(
                context,
                provider,
                videoType,
                videoId,
              );
            }
          },
          icon: const Icon(
            Icons.chat_bubble_outline,
            color: Colors.white,
            size: 32,
            shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
        Text(
          '$commentsCount',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        const SizedBox(height: 8),
        // Favori (action visible)
        IconButton(
          onPressed: () async {
            bool ok = false;
            if (isChallenge && participationId.isNotEmpty) {
              ok = hasFavorited
                  ? await provider.unfavoriteChallengeVideo(participationId: participationId)
                  : await provider.favoriteChallengeVideo(participationId: participationId);
            } else if (videoType.isNotEmpty && videoId.isNotEmpty) {
              ok = hasFavorited
                  ? await provider.unfavoriteVideo(videoType: videoType, videoId: videoId)
                  : await provider.favoriteVideo(videoType: videoType, videoId: videoId);
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
            size: 34,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
        Text(
          '$favoritesCount',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        const SizedBox(height: 8),
        // Télécharger — action mise en avant (moteur de partage externe)
        if (allowDownload) ...[
          GestureDetector(
            onTap: () async {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1EA75C),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.download, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Enregistrer',
                  style: TextStyle(color: Color(0xFFA3D65C), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Partage
        IconButton(
          onPressed: () async {
            await VideoShareService.shareVideo(
              videoUrl: videoUrl,
              videoId: videoId.isNotEmpty ? videoId : participationId,
              title: isChallenge ? 'Challenge Academia' : 'Vidéo Academia',
            );
          },
          icon: const Icon(
            Icons.share,
            color: Colors.white,
            size: 32,
            shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 8),
        // Menu "..." pour actions secondaires
        IconButton(
          icon: const Icon(
            Icons.more_horiz,
            color: Colors.white,
            size: 30,
            shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
          onPressed: () async {
            await showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.black87,
              isScrollControlled: true,
              builder: (sheetContext) {
                return SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Signaler
                        ListTile(
                          leading: const Icon(Icons.flag_outlined, color: Colors.white),
                          title: const Text('Signaler', style: TextStyle(color: Colors.white)),
                          onTap: () async {
                            Navigator.of(sheetContext).pop();
                            await _showGenericReportDialog(
                              context,
                              provider,
                              videoType,
                              videoId,
                            );
                          },
                        ),
                        if (isOwner) ...[
                          const Divider(color: Colors.white24),
                          ListTile(
                            leading: const Icon(Icons.download_for_offline, color: Colors.white),
                            title: const Text('Autoriser le téléchargement', style: TextStyle(color: Colors.white)),
                            trailing: Switch(
                              value: allowDownload,
                              onChanged: (value) async {
                                final ok = await provider.setVideoAllowDownload(
                                  videoType: videoType,
                                  videoId: videoId,
                                  allowDownload: value,
                                );
                                if (!sheetContext.mounted) return;
                                if (!ok && provider.error != null) {
                                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                                    SnackBar(content: Text(provider.error!)),
                                  );
                                }
                              },
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.history, color: Colors.white),
                            title: const Text('Récemment supprimées', style: TextStyle(color: Colors.white)),
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
                          ListTile(
                            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            title: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: sheetContext,
                                builder: (dialogContext) {
                                  return AlertDialog(
                                    title: const Text('Supprimer cette vidéo ?'),
                                    content: const Text('Elle sera déplacée dans "Récemment supprimées".'),
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
                            if (!ok && provider.error != null) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text(provider.error!)),
                              );
                              return;
                            }
                            Navigator.of(sheetContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vidéo supprimée')),
                            );
                            await onDeleted?.call();
                          },
                        ),
                      ],
                        ListTile(
                          leading: const Icon(Icons.close, color: Colors.white70),
                          title: const Text('Annuler', style: TextStyle(color: Colors.white70)),
                          onTap: () => Navigator.of(sheetContext).pop(),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 8),
        // Rang personnel (si disponible)
        Consumer<StudentChallengesProvider>(
          builder: (context, provider, child) {
            final myRank = provider.videos
                .firstWhere(
                  (v) => (v['participation_id']?.toString() ?? v['video_id']?.toString() ?? '') == 
                         (participationId.isNotEmpty ? participationId : videoId),
                  orElse: () => <String, dynamic>{},
                )['my_rank'];
            if (myRank == null) return const SizedBox.shrink();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                const SizedBox(height: 2),
                Text(
                  '#$myRank',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// Helper functions for comments and reporting (moved outside class for reuse)
Future<void> _showCommentsSheet(
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
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final ctrl = widget.controller;
      if (ctrl == null || !ctrl.isAttached) return;
      try {
        final pos = await ctrl.getPosition();
        final dur = await ctrl.getDuration();
        if (!mounted) return;
        if (dur > 0) {
          final newProgress = (pos / dur).clamp(0.0, 1.0);
          // Only rebuild if progress changed meaningfully (>0.5%)
          if ((newProgress - _progress).abs() > 0.005) {
            setState(() {
              _progress = newProgress;
            });
          }
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

/// Hub « Arène » — regroupe les modes compétitifs (Phase 2 de la charte UI).
/// Challenges et Live sont opérationnels ; Duo / Compétitions / Classements
/// sont signalés « Bientôt » tant que leur backend n'existe pas (aucun faux lien).
class _AreneHubBody extends StatelessWidget {
  const _AreneHubBody();

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bientôt disponible')),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool soon = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(subtitle),
        trailing: soon
            ? const Text('Bientôt', style: TextStyle(color: Colors.grey, fontSize: 12))
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _tile(
          context,
          icon: Icons.emoji_events,
          color: const Color(0xFF1EA75C),
          title: 'Challenges',
          subtitle: 'Relève les défis et grimpe au classement',
          onTap: () {
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
            );
          },
        ),
        _tile(
          context,
          icon: Icons.sensors,
          color: const Color(0xFFE0245E),
          title: 'Live',
          subtitle: 'Passe en direct devant la communauté',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ChallengeLiveScreen(isHost: true),
              ),
            );
          },
        ),
        _tile(
          context,
          icon: Icons.groups,
          color: const Color(0xFF7C4DFF),
          title: 'Duo',
          subtitle: 'Défie un ami en duo',
          soon: true,
          onTap: () => _soon(context),
        ),
        _tile(
          context,
          icon: Icons.military_tech,
          color: const Color(0xFFF5A623),
          title: 'Compétitions',
          subtitle: 'Tournois et saisons',
          soon: true,
          onTap: () => _soon(context),
        ),
        _tile(
          context,
          icon: Icons.leaderboard,
          color: const Color(0xFF2D9CDB),
          title: 'Classements',
          subtitle: 'Top créateurs et récompenses',
          soon: true,
          onTap: () => _soon(context),
        ),
      ],
    );
  }
}
