import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../providers/student_challenges_provider.dart';
import '../../widgets/student_video_player.dart';
import 'student_challenge_video_editor_screen.dart';

class StudentChallengeDetailScreen extends StatefulWidget {
  final String challengeId;
  final String initialTitle;
  final String initialDescription;
  final String initialType;
  final String initialDifficulty;
  final int initialPoints;
  final bool requiresSubmission;
  final bool requiresAdminReview;

  const StudentChallengeDetailScreen({
    super.key,
    required this.challengeId,
    required this.initialTitle,
    required this.initialDescription,
    required this.initialType,
    required this.initialDifficulty,
    required this.initialPoints,
    required this.requiresSubmission,
    required this.requiresAdminReview,
  });

  @override
  State<StudentChallengeDetailScreen> createState() => _StudentChallengeDetailScreenState();
}

class _StudentChallengeDetailScreenState extends State<StudentChallengeDetailScreen> {
  final TextEditingController _submissionTextController = TextEditingController();

  bool _loadingLeaderboard = false;
  List<Map<String, dynamic>> _participationVideos = [];
  bool _loadingVideos = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<StudentChallengesProvider>();
      await Future.wait([
        provider.loadMyParticipations(),
        provider.loadStats(),
      ]);
      await _loadParticipationVideosIfAny(provider);
      await _loadLeaderboard();
    });
  }

  @override
  void dispose() {
    _submissionTextController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _loadingLeaderboard = true;
    });
    final provider = context.read<StudentChallengesProvider>();
    await provider.loadLeaderboard(widget.challengeId);
    if (!mounted) return;
    setState(() {
      _loadingLeaderboard = false;
    });
  }

  Future<void> _loadParticipationVideosIfAny(
    StudentChallengesProvider provider,
  ) async {
    final participation = _findMyParticipation(provider);
    final participationId = participation?['participation_id']?.toString() ??
        participation?['id']?.toString() ??
        '';

    if (participationId.isEmpty) {
      return;
    }

    setState(() {
      _loadingVideos = true;
    });

    final videos = await provider.listMyChallengeVideos(participationId);
    if (!mounted) {
      return;
    }

    setState(() {
      _participationVideos = videos;
      _loadingVideos = false;
    });
  }

  Future<void> _reloadParticipationVideos(String participationId) async {
    final provider = context.read<StudentChallengesProvider>();
    setState(() {
      _loadingVideos = true;
    });
    final videos = await provider.listMyChallengeVideos(participationId);
    if (!mounted) {
      return;
    }
    setState(() {
      _participationVideos = videos;
      _loadingVideos = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentChallengesProvider>(
      builder: (context, provider, child) {
        final participation = _findMyParticipation(provider);
        final String myStatus = participation?['status']?.toString() ?? '';
        int? myScore;
        final p = participation;
        if (p != null && p['score'] is int) {
          myScore = p['score'] as int;
        } else {
          myScore = null;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          appBar: AppBar(
            elevation: 0,
            centerTitle: false,
            title: Text(widget.initialTitle.isEmpty
                ? 'Challenge'
                : widget.initialTitle),
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
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(myStatus: myStatus, myScore: myScore),
                const SizedBox(height: 16),
                _buildActionsSection(provider, participation, myStatus),
                const SizedBox(height: 16),
                _buildParticipationVideosSection(provider, participation),
                const SizedBox(height: 24),
                _buildLeaderboardSection(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic>? _findMyParticipation(StudentChallengesProvider provider) {
    for (final p in provider.participations) {
      if (p['challenge_id']?.toString() == widget.challengeId) {
        return p;
      }
    }
    return null;
  }

  Widget _buildHeaderCard({
    required String myStatus,
    required int? myScore,
  }) {
    final type = widget.initialType;
    final difficulty = widget.initialDifficulty;
    final points = widget.initialPoints;

    final metaParts = <String>[];
    if (type.isNotEmpty) {
      metaParts.add(type == 'mission' ? 'Mission' : 'Concours');
    }
    if (difficulty.isNotEmpty) {
      metaParts.add('Difficulté: $difficulty');
    }
    if (points > 0) {
      metaParts.add('$points points');
    }

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
              widget.initialTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.initialDescription.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.initialDescription,
                style: const TextStyle(fontSize: 14),
              ),
            ],
            if (metaParts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: metaParts
                    .map(
                      (m) => Chip(
                        label: Text(
                          m,
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: const Color(0xFFE5F9E7),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (myStatus.isNotEmpty || myScore != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Mon avancement',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                myStatus.isNotEmpty ? 'Statut: $myStatus' : 'Statut: non défini',
                style: const TextStyle(fontSize: 13),
              ),
              if (myScore != null)
                Text(
                  'Score: $myScore',
                  style: const TextStyle(fontSize: 13),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipationVideosSection(
    StudentChallengesProvider provider,
    Map<String, dynamic>? participation,
  ) {
    final hasParticipation = participation != null;
    final participationId = participation?['participation_id']?.toString() ??
        participation?['id']?.toString() ??
        '';

    if (!hasParticipation || participationId.isEmpty) {
      return const SizedBox.shrink();
    }

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
            const Text(
              'Vidéos de ma participation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingVideos)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_participationVideos.isEmpty)
              const Text(
                'Tu n\'as pas encore ajouté de vidéo supplémentaire pour ce challenge.',
                style: TextStyle(fontSize: 13),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _participationVideos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final v = _participationVideos[index];
                  final videoUrl = v['video_url']?.toString() ?? '';
                  final thumbnailUrl = v['thumbnail_url']?.toString() ?? '';
                  final createdAtRaw = v['created_at']?.toString() ?? '';
                  String subtitle = '';
                  if (createdAtRaw.isNotEmpty) {
                    subtitle = 'Ajoutée le $createdAtRaw';
                  }

                  return InkWell
                  (
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (videoUrl.isEmpty) {
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _ParticipationVideoPreviewScreen(
                            videoUrl: videoUrl,
                            participationId: participationId,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: thumbnailUrl.isNotEmpty
                                ? Image.network(
                                    thumbnailUrl,
                                    width: 96,
                                    height: 54,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 96,
                                    height: 54,
                                    color: const Color(0xFFE5E7EB),
                                    child: const Icon(
                                      Icons.play_circle_outline,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vidéo ${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF9CA3AF),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: provider.isSaving
                    ? null
                    : () async {
                        final added =
                            await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => StudentChallengeVideoEditorScreen(
                              challengeId: widget.challengeId,
                              participationId: participationId,
                              asAdditionalVideo: true,
                            ),
                          ),
                        );
                        if (added == true && mounted) {
                          await _reloadParticipationVideos(participationId);
                        }
                      },
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une autre vidéo de challenge'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(
    StudentChallengesProvider provider,
    Map<String, dynamic>? participation,
    String myStatus,
  ) {
    final hasParticipation = participation != null;
    final participationId = participation?['participation_id']?.toString() ??
        participation?['id']?.toString() ??
        '';

    final canSubmit = widget.requiresSubmission &&
        hasParticipation &&
        myStatus != 'completed' &&
        myStatus != 'won';

    final canMarkCompleted = !widget.requiresAdminReview &&
        hasParticipation &&
        myStatus != 'completed' &&
        myStatus != 'won';

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
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (!hasParticipation)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: provider.isSaving
                      ? null
                      : () async {
                          final ok = await provider.joinChallenge(
                            challengeId: widget.challengeId,
                          );
                          if (!mounted) return;
                          if (!ok && provider.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(provider.error!)),
                            );
                          }
                        },
                  icon: const Icon(Icons.flag),
                  label: const Text('Rejoindre ce challenge'),
                ),
              )
            else ...[
              if (canSubmit) ...[
                const Text(
                  'Soumission',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        provider.isSaving || participationId.isEmpty
                            ? null
                            : () async {
                                final published =
                                    await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        StudentChallengeVideoEditorScreen(
                                      challengeId: widget.challengeId,
                                      participationId: participationId,
                                    ),
                                  ),
                                );
                                if (published == true && context.mounted) {
                                  await Future.wait([
                                    provider.loadMyParticipations(),
                                    provider.loadStats(),
                                  ]);
                                }
                              },
                    icon: const Icon(Icons.video_call),
                    label: const Text('Créer une vidéo de challenge'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _submissionTextController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Description / réponse (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: provider.isSaving || participationId.isEmpty
                        ? null
                        : () async {
                            final ok = await provider.submitChallenge(
                              participationId: participationId,
                              submissionText:
                                  _submissionTextController.text.trim(),
                              submissionUrl: null,
                            );
                            if (!mounted) return;
                            if (!ok && provider.error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(provider.error!)),
                              );
                            } else if (ok) {
                              _submissionTextController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Soumission envoyée.'),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.send),
                    label: const Text('Soumettre ma participation'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (canMarkCompleted)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: provider.isSaving || participationId.isEmpty
                        ? null
                        : () async {
                            final ok = await provider.markChallengeCompleted(
                              participationId: participationId,
                            );
                            if (!mounted) return;
                            if (!ok && provider.error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(provider.error!)),
                              );
                            } else if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Challenge marqué comme terminé.'),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Marquer comme terminé'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardSection(StudentChallengesProvider provider) {
    final leaderboard = provider.leaderboard;

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
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Classement du challenge',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadingLeaderboard ? null : _loadLeaderboard,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Recharger le classement',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingLeaderboard)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (leaderboard.isEmpty)
              const Text(
                'Aucun classement disponible pour le moment. Les résultats apparaîtront ici quand les participations seront validées.',
                style: TextStyle(fontSize: 13),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: leaderboard.length,
                itemBuilder: (context, index) {
                  final entry = leaderboard[index];
                  final userId = entry['user_id']?.toString() ?? '';
                  final score = entry['score'] is int
                      ? entry['score'] as int
                      : null;
                  final rank = entry['rank'] is int
                      ? entry['rank'] as int
                      : null;
                  final status = entry['status']?.toString() ?? '';

                  final position = rank ?? (index + 1);

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF1EA75C),
                      child: Text(
                        '$position',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    title: Text(
                      userId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      [
                        if (score != null) 'Score: $score',
                        if (status.isNotEmpty) 'Statut: $status',
                      ].join(' • '),
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ParticipationVideoPreviewScreen extends StatefulWidget {
  final String videoUrl;
  final String participationId;

  const _ParticipationVideoPreviewScreen({
    super.key,
    required this.videoUrl,
    required this.participationId,
  });

  @override
  State<_ParticipationVideoPreviewScreen> createState() => _ParticipationVideoPreviewScreenState();
}

class _ParticipationVideoPreviewScreenState extends State<_ParticipationVideoPreviewScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  Map<String, dynamic>? _overlays;

  @override
  void initState() {
    super.initState();
    final url = widget.videoUrl;
    if (url.isEmpty) {
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      controller.setLooping(true);
      controller.play();
      setState(() {
        _initialized = true;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _initialized = false;
      });
    });

    _loadOverlays();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadOverlays() async {
    final provider = Provider.of<StudentChallengesProvider>(context, listen: false);

    Map<String, dynamic>? video;
    try {
      video = await provider.getChallengeVideoById(widget.participationId);
    } catch (_) {
      // L'erreur éventuelle sera déjà exposée via provider.error si besoin.
    }

    if (!mounted) {
      return;
    }

    if (video == null) {
      return;
    }

    final rawOverlays = video['overlays'] ?? video['layers'];
    Map<String, dynamic>? overlays;
    if (rawOverlays is Map) {
      overlays = Map<String, dynamic>.from(rawOverlays);
    }

    if (overlays == null) {
      return;
    }

    setState(() {
      _overlays = overlays;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Prévisualisation de la vidéo'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _controller != null && _initialized
              ? StudentVideoPlayer(
                  controller: _controller!,
                  overlays: _overlays,
                )
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
