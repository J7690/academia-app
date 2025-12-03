import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../providers/admin_challenges_provider.dart';
import '../../widgets/student_video_player.dart';

class AdminChallengesScreen extends StatefulWidget {
  const AdminChallengesScreen({super.key});

  @override
  State<AdminChallengesScreen> createState() => _AdminChallengesScreenState();
}

class _AdminChallengesScreenState extends State<AdminChallengesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminChallengesProvider>().loadChallenges();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: const Text('Challenges - Admin'),
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
            onPressed: context.read<AdminChallengesProvider>().loadChallenges,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recharger',
          ),
          IconButton(
            onPressed: () {
              final provider = context.read<AdminChallengesProvider>();
              _openReportsDialog(context, provider);
            },
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Signalements',
          ),
          IconButton(
            onPressed: () {
              final provider = context.read<AdminChallengesProvider>();
              _openAssetsDialog(context, provider);
            },
            icon: const Icon(Icons.video_library_outlined),
            tooltip: 'Assets vidéo',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final provider = context.read<AdminChallengesProvider>();
          _showChallengeDialog(context, provider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouveau challenge'),
      ),
      body: Consumer<AdminChallengesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.challenges.isEmpty) {
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
                    onPressed: provider.loadChallenges,
                    child: const Text('Recharger'),
                  ),
                ],
              ),
            );
          }

          final challenges = provider.challenges;
          if (challenges.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Aucun challenge n\'a encore été créé. Utilisez le bouton ci-dessous pour créer le premier.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: challenges.length,
            itemBuilder: (context, index) {
              final c = challenges[index];
              final id = c['id']?.toString();
              final title = c['title']?.toString() ?? '';
              final description = c['description']?.toString() ?? '';
              final type = c['challenge_type']?.toString() ?? '';
              final difficulty = c['difficulty']?.toString() ?? '';
              final points = c['points'] is int ? c['points'] as int : null;
              final startAt = c['start_at']?.toString() ?? '';
              final endAt = c['end_at']?.toString() ?? '';
              final isActive = c['is_active'] != false;
              final isFeatured = c['is_featured'] == true;
              final participantsCount = c['participants_count'] is int
                  ? c['participants_count'] as int
                  : null;
              final completedCount = c['completed_count'] is int
                  ? c['completed_count'] as int
                  : null;
              final averageScore = c['average_score'];

              final metaParts = <String>[];
              if (type.isNotEmpty) {
                metaParts.add(type == 'mission' ? 'Mission' : 'Concours');
              }
              if (difficulty.isNotEmpty) {
                metaParts.add('Difficulté: $difficulty');
              }
              if (points != null) {
                metaParts.add('$points points');
              }
              if (startAt.isNotEmpty) {
                metaParts.add('Début: $startAt');
              }
              if (endAt.isNotEmpty) {
                metaParts.add('Fin: $endAt');
              }

              final statsParts = <String>[];
              if (participantsCount != null) {
                statsParts.add(
                  '$participantsCount participation${participantsCount > 1 ? 's' : ''}',
                );
              }
              if (completedCount != null) {
                statsParts.add(
                  '$completedCount terminé${completedCount > 1 ? 's' : ''}',
                );
              }
              if (averageScore != null) {
                statsParts.add('Score moyen: $averageScore');
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
                              title,
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
                            if (statsParts.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                statsParts.join(' • '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black87,
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
                                            .updateChallengeStatus(
                                          challengeId: id,
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
                                    ? 'Retirer des challenges en vedette'
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
                                            .updateChallengeStatus(
                                          challengeId: id,
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
                              _showChallengeDialog(
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
                                    _openParticipationsDialog(
                                      context,
                                      provider,
                                      c,
                                    );
                                  },
                            icon: const Icon(Icons.people_outline),
                            label: const Text('Participations'),
                          ),
                          TextButton.icon(
                            onPressed: id == null
                                ? null
                                : () {
                                    _openVideosDialog(
                                      context,
                                      provider,
                                      c,
                                    );
                                  },
                            icon: const Icon(Icons.ondemand_video),
                            label: const Text('Vidéos'),
                          ),
                          TextButton.icon(
                            onPressed: id == null
                                ? null
                                : () {
                                    _openLeaderboardDialog(
                                      context,
                                      provider,
                                      c,
                                    );
                                  },
                            icon: const Icon(Icons.leaderboard_outlined),
                            label: const Text('Classement'),
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

  Future<void> _showChallengeDialog(
    BuildContext context,
    AdminChallengesProvider provider, {
    Map<String, dynamic>? existing,
  }) async {
    final titleController =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final slugController =
        TextEditingController(text: existing?['slug']?.toString() ?? '');
    final descriptionController = TextEditingController(
      text: existing?['description']?.toString() ?? '',
    );
    final difficultyController = TextEditingController(
      text: existing?['difficulty']?.toString() ?? '',
    );
    final pointsController = TextEditingController(
      text: existing?['points']?.toString() ?? '',
    );
    final maxParticipantsController = TextEditingController(
      text: existing?['max_participants']?.toString() ?? '',
    );
    final startAtController = TextEditingController(
      text: existing?['start_at']?.toString() ?? '',
    );
    final endAtController = TextEditingController(
      text: existing?['end_at']?.toString() ?? '',
    );
    String type = existing?['challenge_type']?.toString() ?? 'mission';
    bool requiresSubmission = existing?['requires_submission'] == true;
    bool requiresAdminReview = existing?['requires_admin_review'] == true;
    bool isActive = existing == null || existing['is_active'] != false;
    bool isFeatured = existing?['is_featured'] == true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Nouveau challenge'
                    : 'Modifier le challenge',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titre du challenge',
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
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(
                        labelText: 'Type de challenge',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'mission',
                          child: Text('Mission'),
                        ),
                        DropdownMenuItem(
                          value: 'contest',
                          child: Text('Concours'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setStateDialog(() {
                          type = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: difficultyController,
                      decoration: const InputDecoration(
                        labelText: 'Difficulté (optionnelle)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Points attribués (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: maxParticipantsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nombre max. de participants (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: startAtController,
                      decoration: const InputDecoration(
                        labelText:
                            'Date/heure de début (ISO, optionnel, ex: 2025-01-01T09:00:00Z)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: endAtController,
                      decoration: const InputDecoration(
                        labelText:
                            'Date/heure de fin (ISO, optionnel, ex: 2025-01-31T23:59:59Z)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: requiresSubmission,
                      onChanged: (value) {
                        setStateDialog(() {
                          requiresSubmission = value;
                        });
                      },
                      title: const Text('Nécessite une soumission (texte/lien)'),
                    ),
                    SwitchListTile(
                      value: requiresAdminReview,
                      onChanged: (value) {
                        setStateDialog(() {
                          requiresAdminReview = value;
                        });
                      },
                      title:
                          const Text('Nécessite une validation admin (notation)'),
                    ),
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

    final title = titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    final points = int.tryParse(pointsController.text.trim());
    final maxParticipants =
        int.tryParse(maxParticipantsController.text.trim());
    final startAtText = startAtController.text.trim();
    final endAtText = endAtController.text.trim();
    final DateTime? startAt =
        startAtText.isEmpty ? null : DateTime.tryParse(startAtText);
    final DateTime? endAt =
        endAtText.isEmpty ? null : DateTime.tryParse(endAtText);

    final ok = await provider.upsertChallenge(
      challengeId: existing?['id']?.toString(),
      slug: slugController.text.trim().isEmpty
          ? null
          : slugController.text.trim(),
      title: title,
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      challengeType: type,
      difficulty: difficultyController.text.trim().isEmpty
          ? null
          : difficultyController.text.trim(),
      points: points,
      startAt: startAt,
      endAt: endAt,
      maxParticipants: maxParticipants,
      requiresSubmission: requiresSubmission,
      requiresAdminReview: requiresAdminReview,
      isActive: isActive,
      isFeatured: isFeatured,
    );

    if (!mounted) return;
    if (!ok && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  Future<void> _openParticipationsDialog(
    BuildContext context,
    AdminChallengesProvider provider,
    Map<String, dynamic> challenge,
  ) async {
    final challengeId = challenge['id']?.toString() ?? '';
    final title = challenge['title']?.toString() ?? '';
    if (challengeId.isEmpty) return;

    final participations = await provider.loadParticipations(challengeId);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Participations - $title'),
          content: SizedBox(
            width: 520,
            height: 420,
            child: participations.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune participation pour ce challenge pour le moment.',
                      style: TextStyle(fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: participations.length,
                    itemBuilder: (context, index) {
                      final p = participations[index];
                      final participationId =
                          p['id']?.toString() ?? '';
                      final userId = p['user_id']?.toString() ?? '';
                      final status = p['status']?.toString() ?? '';
                      final score = p['score'];
                      final rank = p['rank'];
                      final submittedAt =
                          p['submitted_at']?.toString() ?? '';
                      final completedAt =
                          p['completed_at']?.toString() ?? '';

                      final details = <String>[];
                      if (submittedAt.isNotEmpty) {
                        details.add('Soumis le: $submittedAt');
                      }
                      if (completedAt.isNotEmpty) {
                        details.add('Terminé le: $completedAt');
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userId,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Statut: $status',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (score != null || rank != null)
                                Text(
                                  [
                                    if (score != null) 'Score: $score',
                                    if (rank != null) 'Rang: $rank',
                                  ].join(' • '),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (details.isNotEmpty)
                                Text(
                                  details.join(' • '),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: participationId.isEmpty
                                      ? null
                                      : () async {
                                          await _showReviewDialog(
                                            dialogContext,
                                            provider,
                                            participationId,
                                            status,
                                            score,
                                            rank,
                                            challengeId,
                                            title,
                                          );
                                        },
                                  child: const Text(
                                    'Revoir / Noter',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
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
  }

  Future<void> _showReviewDialog(
    BuildContext context,
    AdminChallengesProvider provider,
    String participationId,
    String currentStatus,
    dynamic currentScore,
    dynamic currentRank,
    String challengeId,
    String challengeTitle,
  ) async {
    String status = currentStatus.isEmpty ? 'completed' : currentStatus;
    final scoreController = TextEditingController(
      text: currentScore?.toString() ?? '',
    );
    final rankController = TextEditingController(
      text: currentRank?.toString() ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Revue de participation - $challengeTitle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Terminé'),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('Rejeté'),
                      ),
                      DropdownMenuItem(
                        value: 'won',
                        child: Text('Gagnant'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() {
                        status = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: scoreController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Score (optionnel)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: rankController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Rang (optionnel)',
                    ),
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

    final int? score = int.tryParse(scoreController.text.trim());
    final int? rank = int.tryParse(rankController.text.trim());

    final ok = await provider.reviewParticipation(
      participationId: participationId,
      status: status,
      score: score,
      rank: rank,
    );

    if (!mounted) return;
    if (!ok && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    } else if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Participation mise à jour.'),
        ),
      );
      await provider.loadParticipations(challengeId);
    }
  }

  Future<void> _openLeaderboardDialog(
    BuildContext context,
    AdminChallengesProvider provider,
    Map<String, dynamic> challenge,
  ) async {
    final challengeId = challenge['id']?.toString() ?? '';
    final title = challenge['title']?.toString() ?? '';
    if (challengeId.isEmpty) return;

    final leaderboard = await provider.loadLeaderboard(challengeId);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Classement - $title'),
          content: SizedBox(
            width: 480,
            height: 380,
            child: leaderboard.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun classement disponible pour ce challenge.',
                      style: TextStyle(fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: leaderboard.length,
                    itemBuilder: (context, index) {
                      final e = leaderboard[index];
                      final userId = e['user_id']?.toString() ?? '';
                      final score = e['score'];
                      final rank = e['rank'];
                      final status = e['status']?.toString() ?? '';

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
  }

  Future<void> _openVideosDialog(
    BuildContext context,
    AdminChallengesProvider provider,
    Map<String, dynamic> challenge,
  ) async {
    final challengeId = challenge['id']?.toString() ?? '';
    final title = challenge['title']?.toString() ?? '';
    if (challengeId.isEmpty) return;

    final videos = await provider.loadChallengeVideos(
      challengeId: challengeId,
      moderationStatus: null,
      hasPendingReports: null,
    );
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Vidéos - $title'),
          content: SizedBox(
            width: 560,
            height: 460,
            child: videos.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune vidéo pour ce challenge pour le moment.',
                      style: TextStyle(fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: videos.length,
                    itemBuilder: (context, index) {
                      final v = videos[index];
                      final participationId =
                          v['participation_id']?.toString() ?? '';
                      final userId = v['user_id']?.toString() ?? '';
                      final videoUrl = v['video_url']?.toString() ?? '';
                      final moderationStatus =
                          v['moderation_status']?.toString() ?? '';
                      final reportsCount = v['reports_count'] is int
                          ? v['reports_count'] as int
                          : 0;
                      final pendingReportsCount =
                          v['pending_reports_count'] is int
                              ? v['pending_reports_count'] as int
                              : 0;
                      final likesCount = v['likes_count'] is int
                          ? v['likes_count'] as int
                          : 0;
                      final commentsCount = v['comments_count'] is int
                          ? v['comments_count'] as int
                          : 0;

                      final chips = <String>[];
                      if (likesCount > 0) {
                        chips.add('$likesCount like${likesCount > 1 ? 's' : ''}');
                      }
                      if (commentsCount > 0) {
                        chips.add(
                          '$commentsCount commentaire${commentsCount > 1 ? 's' : ''}',
                        );
                      }
                      if (reportsCount > 0) {
                        chips.add(
                          '$reportsCount signalement${reportsCount > 1 ? 's' : ''}',
                        );
                      }
                      if (pendingReportsCount > 0) {
                        chips.add(
                          '$pendingReportsCount en attente',
                        );
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userId,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Statut modération: ${moderationStatus.isEmpty ? 'pending' : moderationStatus}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (chips.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  chips.join(' • '),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                              if (videoUrl.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: () {
                                    _openVideoPreviewDialog(
                                      dialogContext,
                                      videoUrl,
                                    );
                                  },
                                  child: const Text(
                                    'Voir la vidéo',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  TextButton(
                                    onPressed: participationId.isEmpty
                                        ? null
                                        : () async {
                                            final ok = await provider
                                                .reviewChallengeVideo(
                                              participationId:
                                                  participationId,
                                              moderationStatus: 'approved',
                                            );
                                            if (!mounted) return;
                                            if (!ok &&
                                                provider.error != null) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error!,
                                                  ),
                                                ),
                                              );
                                            } else if (ok) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content:
                                                      Text('Vidéo approuvée.'),
                                                ),
                                              );
                                            }
                                          },
                                    child: const Text(
                                      'Approuver',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: participationId.isEmpty
                                        ? null
                                        : () async {
                                            final ok = await provider
                                                .reviewChallengeVideo(
                                              participationId:
                                                  participationId,
                                              moderationStatus: 'rejected',
                                            );
                                            if (!mounted) return;
                                            if (!ok &&
                                                provider.error != null) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error!,
                                                  ),
                                                ),
                                              );
                                            } else if (ok) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content:
                                                      Text('Vidéo rejetée.'),
                                                ),
                                              );
                                            }
                                          },
                                    child: const Text(
                                      'Rejeter',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: participationId.isEmpty
                                        ? null
                                        : () async {
                                            final ok = await provider
                                                .reviewChallengeVideo(
                                              participationId:
                                                  participationId,
                                              moderationStatus: 'blocked_ai',
                                              reason:
                                                  'Bloquée par la modération IA/admin.',
                                            );
                                            if (!mounted) return;
                                            if (!ok &&
                                                provider.error != null) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error!,
                                                  ),
                                                ),
                                              );
                                            } else if (ok) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Vidéo bloquée (IA/modération).',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    child: const Text(
                                      'Bloquer (IA)',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: participationId.isEmpty
                                        ? null
                                        : () {
                                            _openParticipationExtraVideosDialog(
                                              dialogContext,
                                              provider,
                                              challengeId: challengeId,
                                              participationId: participationId,
                                              userId: userId,
                                            );
                                          },
                                    child: const Text(
                                      'Vidéos supplémentaires',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: participationId.isEmpty
                                        ? null
                                        : () async {
                                            final ok = await provider
                                                .deleteChallengeVideo(
                                              participationId:
                                                  participationId,
                                            );
                                            if (!mounted) return;
                                            if (!ok &&
                                                provider.error != null) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error!,
                                                  ),
                                                ),
                                              );
                                            } else if (ok) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Vidéo supprimée / désactivée.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    child: const Text(
                                      'Supprimer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: userId.isEmpty
                                        ? null
                                        : () async {
                                            final ok = await provider
                                                .banUserFromChallenges(
                                              userId: userId,
                                              reason:
                                                  'Violation des règles des challenges (vidéo).',
                                              bannedUntil: null,
                                            );
                                            if (!mounted) return;
                                            if (!ok &&
                                                provider.error != null) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error!,
                                                  ),
                                                ),
                                              );
                                            } else if (ok) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Utilisateur banni des challenges.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    child: const Text(
                                      'Bannir utilisateur',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
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
  }

  Future<void> _openParticipationExtraVideosDialog(
    BuildContext context,
    AdminChallengesProvider provider, {
    required String challengeId,
    required String participationId,
    required String userId,
  }) async {
    final videos = await provider.loadParticipationExtraVideos(
      challengeId: challengeId,
      participationId: participationId,
    );
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Vidéos supplémentaires - $userId'),
          content: SizedBox(
            width: 520,
            height: 420,
            child: videos.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune vidéo supplémentaire pour cette participation.',
                      style: TextStyle(fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: videos.length,
                    itemBuilder: (context, index) {
                      final v = videos[index];
                      final videoId = v['id']?.toString() ?? '';
                      final videoUrl = v['video_url']?.toString() ?? '';
                      final createdAt = v['created_at']?.toString() ?? '';

                      final details = <String>[];
                      if (createdAt.isNotEmpty) {
                        details.add('Ajoutée le $createdAt');
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
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
                              if (details.isNotEmpty)
                                Text(
                                  details.join(' • '),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  TextButton(
                                    onPressed: videoUrl.isEmpty
                                        ? null
                                        : () {
                                            _openVideoPreviewDialog(
                                              dialogContext,
                                              videoUrl,
                                            );
                                          },
                                    child: const Text(
                                      'Voir la vidéo',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: videoId.isEmpty
                                        ? null
                                        : () async {
                                            final ok = await provider
                                                .deleteParticipationExtraVideo(
                                              videoId: videoId,
                                            );
                                            if (!mounted) return;
                                            if (!ok &&
                                                provider.error != null) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error!,
                                                  ),
                                                ),
                                              );
                                            } else if (ok) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Vidéo supplémentaire supprimée.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    child: const Text(
                                      'Supprimer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
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
  }

  Future<void> _openVideoPreviewDialog(
    BuildContext context,
    String videoUrl,
  ) async {
    if (videoUrl.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    try {
      await controller.initialize();
      controller.setLooping(true);
      controller.play();
    } catch (_) {
      controller.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de lire la vidéo.'),
        ),
      );
      return;
    }

    if (!mounted) {
      controller.dispose();
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Prévisualisation de la vidéo'),
          content: SizedBox(
            width: 480,
            child: StudentVideoPlayer(controller: controller),
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

    controller.dispose();
  }

  Future<void> _openReportsDialog(
    BuildContext context,
    AdminChallengesProvider provider,
  ) async {
    final reports = await provider.loadChallengeReports(status: 'pending');
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Signalements de vidéos de challenges'),
          content: SizedBox(
            width: 600,
            height: 480,
            child: reports.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun signalement en attente.',
                      style: TextStyle(fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final r = reports[index];
                      final reportId = r['id']?.toString() ?? '';
                      final participationId =
                          r['participation_id']?.toString() ?? '';
                      final reporterId = r['reporter_id']?.toString() ?? '';
                      final reason = r['reason']?.toString() ?? '';
                      final details = r['details']?.toString() ?? '';
                      final status = r['status']?.toString() ?? '';
                      final videoUrl = r['video_url']?.toString() ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reporter: $reporterId',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Raison: $reason',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (details.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  details,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Statut: $status',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black87,
                                ),
                              ),
                              if (videoUrl.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: () {
                                    _openVideoPreviewDialog(
                                      dialogContext,
                                      videoUrl,
                                    );
                                  },
                                  child: const Text(
                                    'Voir la vidéo signalée',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  TextButton(
                                    onPressed: reportId.isEmpty
                                        ? null
                                        : () async {
                                            final ok = await provider
                                                .updateChallengeReportStatus(
                                              reportId: reportId,
                                              status: 'reviewed',
                                            );
                                            if (!mounted) return;
                                            if (!ok &&
                                                provider.error != null) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error!,
                                                  ),
                                                ),
                                              );
                                            } else if (ok) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Signalement marqué comme traité.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    child: const Text(
                                      'Marquer comme traité',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: reportId.isEmpty
                                        ? null
                                        : () async {
                                            final ok = await provider
                                                .updateChallengeReportStatus(
                                              reportId: reportId,
                                              status: 'dismissed',
                                            );
                                            if (!mounted) return;
                                            if (!ok &&
                                                provider.error != null) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error!,
                                                  ),
                                                ),
                                              );
                                            } else if (ok) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Signalement ignoré.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    child: const Text(
                                      'Ignorer',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: participationId.isEmpty
                                        ? null
                                        : () async {
                                            final ok = await provider
                                                .deleteChallengeVideo(
                                              participationId:
                                                  participationId,
                                            );
                                            if (!mounted) return;
                                            if (!ok &&
                                                provider.error != null) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error!,
                                                  ),
                                                ),
                                              );
                                            } else if (ok) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Vidéo supprimée suite au signalement.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    child: const Text(
                                      'Supprimer la vidéo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
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
  }

  Future<void> _openAssetsDialog(
    BuildContext context,
    AdminChallengesProvider provider,
  ) async {
    final assets = await provider.loadChallengeVideoAssets();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Assets vidéo académiques'),
          content: SizedBox(
            width: 560,
            height: 460,
            child: assets.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun asset vidéo défini pour le moment.',
                      style: TextStyle(fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: assets.length,
                    itemBuilder: (context, index) {
                      final a = assets[index];
                      final assetId = a['id']?.toString() ?? '';
                      final category = a['category']?.toString() ?? '';
                      final label = a['label']?.toString() ?? '';
                      final assetUrl = a['asset_url']?.toString() ?? '';
                      final isActive = a['is_active'] == true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Catégorie: $category',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                assetUrl,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  TextButton(
                                    onPressed: assetId.isEmpty
                                        ? null
                                        : () async {
                                            final ok = await provider
                                                .upsertChallengeVideoAsset(
                                              assetId: assetId,
                                              category: category,
                                              label: label,
                                              assetUrl: assetUrl,
                                              isActive: !isActive,
                                            );
                                            if (!mounted) return;
                                            if (!ok &&
                                                provider.error != null) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error!,
                                                  ),
                                                ),
                                              );
                                            } else if (ok) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    isActive
                                                        ? 'Asset désactivé.'
                                                        : 'Asset activé.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    child: Text(
                                      isActive ? 'Désactiver' : 'Activer',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: assetId.isEmpty
                                        ? null
                                        : () async {
                                            final ok = await provider
                                                .deleteChallengeVideoAsset(
                                              assetId: assetId,
                                            );
                                            if (!mounted) return;
                                            if (!ok &&
                                                provider.error != null) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    provider.error!,
                                                  ),
                                                ),
                                              );
                                            } else if (ok) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Asset supprimé.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    child: const Text(
                                      'Supprimer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
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
  }
}
