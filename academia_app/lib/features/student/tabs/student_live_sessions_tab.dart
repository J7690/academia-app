import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/academia_session.dart';
import '../../../providers/academia_session_provider.dart';
import '../../../providers/student_live_sessions_provider.dart';
import '../../../theme/academia_palette.dart';
import '../../../widgets/academia_motion.dart';
import '../../../widgets/academia_ui.dart';
import '../../live/academia_classroom_screen.dart';

/// Onglet Lives — refonte « Ciel Academia ».
///
/// Cet onglet est un onglet de **temps**, pas de catalogue. Il est donc
/// organisé sur un axe temporel :
///   1. En-tête navy → ciel + compteurs
///   2. Filtres par type de séance
///   3. « Maintenant » — le seul bloc à porter le rouge
///   4. « Aujourd'hui » — timeline horaire
///   5. « À venir » — le reste de la semaine
///   6. « Replays » — grille de vignettes
///
/// Source principale : `app_learning_list_available_sessions`, le moteur
/// unifié `app.academia_sessions` (cours, TD, prépa, orientation, masterclass).
/// Source secondaire, temporaire : `app_student_list_my_online_course_live_sessions`,
/// fusionnée dans la timeline le temps de la convergence.
class StudentLiveSessionsTab extends StatefulWidget {
  const StudentLiveSessionsTab({super.key});

  @override
  State<StudentLiveSessionsTab> createState() => _StudentLiveSessionsTabState();
}

class _StudentLiveSessionsTabState extends State<StudentLiveSessionsTab> {
  static const _accent = AcademiaPalette.blue;

  String? _typeFilter;

  static const _filters = <String?, String>{
    null: 'Tout',
    'course': 'Cours',
    'td': 'TD',
    'prep_concours': 'Prépa',
    'orientation': 'Orientation',
    'masterclass': 'Masterclass',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final unified = context.read<AcademiaSessionProvider>();
    final legacy = context.read<StudentLiveSessionsProvider>();
    await Future.wait([
      unified.loadAvailableSessions(sessionType: _typeFilter),
      unified.loadReplays(sessionType: _typeFilter),
      legacy.loadMySessions(),
    ]);
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _join(AcademiaSession session) async {
    final provider = context.read<AcademiaSessionProvider>();
    final joined = await provider.joinSession(session.id);
    if (!mounted) return;
    if (joined == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Impossible de rejoindre la séance.'),
          backgroundColor: AcademiaPalette.live,
        ),
      );
      return;
    }
    final myId = Supabase.instance.client.auth.currentUser?.id;
    await Navigator.of(context).push(
      AcademiaPageRoute(
        builder: (_) => AcademiaClassroomScreen(
          session: session,
          isHost: myId != null && myId == session.hostId,
        ),
      ),
    );
    if (mounted) await _load();
  }

  void _remind(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rappel activé pour « $title ».'),
        backgroundColor: AcademiaPalette.green600,
      ),
    );
  }

  // ─── Rendu ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AcademiaPalette.skyBackground),
      child: Consumer2<AcademiaSessionProvider, StudentLiveSessionsProvider>(
        builder: (context, unified, legacy, _) {
          if (unified.isLoading && unified.sessions.isEmpty) {
            // Squelettes plutôt qu'un indicateur : l'écran garde sa forme,
            // et le contenu ne saute pas quand les données arrivent.
            return ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: const [
                AcademiaHeader(
                  title: 'Lives',
                  subtitle:
                      'Cours, TD, prépa concours et orientation — tout ce qui se passe en direct.',
                  gradient: AcademiaPalette.livesHeader,
                ),
                SizedBox(height: 22),
                AcademiaSkeletonList(count: 2, height: 128),
                SizedBox(height: 6),
                AcademiaSkeletonList(count: 2, height: 104),
              ],
            );
          }

          final sessions = unified.sessions;
          final live = sessions.where((s) => s.isLive).toList(growable: false);

          final scheduled = sessions.where((s) => !s.isLive).toList()
            ..sort((a, b) {
              final x = a.scheduledStart;
              final y = b.scheduledStart;
              if (x == null && y == null) return 0;
              if (x == null) return 1;
              if (y == null) return -1;
              return x.compareTo(y);
            });

          final today = scheduled.where(_isToday).toList(growable: false);
          final later =
              scheduled.where((s) => !_isToday(s)).toList(growable: false);

          // Les replays viennent d'un appel dédié et paginé
          // (`app_learning_list_replays`) : l'historique ne doit pas peser
          // sur le chargement des séances à venir.
          final replays = unified.replays;

          final legacySessions = _typeFilter == null || _typeFilter == 'course'
              ? legacy.sessions
              : const <Map<String, dynamic>>[];

          // Les séances héritées portent leur propre date : on les range dans
          // la bonne section plutôt que de tout empiler sous « Aujourd'hui ».
          final legacyToday = legacySessions
              .where((s) => _isSameDayAsToday(_legacyStart(s)))
              .toList(growable: false);
          final legacyLater = legacySessions
              .where((s) => !_isSameDayAsToday(_legacyStart(s)))
              .toList(growable: false);

          final isEmpty = live.isEmpty &&
              today.isEmpty &&
              later.isEmpty &&
              replays.isEmpty &&
              legacySessions.isEmpty;

          return RefreshIndicator(
            color: _accent,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                AcademiaHeader(
                  title: 'Lives',
                  subtitle:
                      'Cours, TD, prépa concours et orientation — tout ce qui se passe en direct.',
                  gradient: AcademiaPalette.livesHeader,
                  stats: [
                    AcademiaHeaderStat('${live.length}', 'en direct'),
                    AcademiaHeaderStat('${today.length}', "aujourd'hui"),
                    AcademiaHeaderStat('${later.length}', 'à venir'),
                  ],
                ),
                const SizedBox(height: 16),
                _filterBar(),
                const SizedBox(height: 4),
                if (unified.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AcademiaErrorBanner(
                      message: unified.error!,
                      onRetry: _load,
                    ),
                  ),
                if (isEmpty)
                  const AcademiaEmptyState(
                    icon: Icons.videocam_outlined,
                    title: 'Aucune séance en direct pour le moment',
                    message:
                        "Tes enseignants n'ont pas encore publié de séance. "
                        'Reviens bientôt, ou active un rappel depuis un cours.',
                    accent: _accent,
                  ),
                if (live.isNotEmpty) ...[
                  AcademiaSectionHeader(
                    title: 'Maintenant',
                    kicker: 'En direct',
                    count: '${live.length}',
                    accent: AcademiaPalette.live,
                    leading: const AcademiaPulseDot(),
                  ),
                  ...live.asMap().entries.map(
                        (e) => AcademiaEntrance(
                          index: e.key,
                          child: _liveHeroCard(e.value),
                        ),
                      ),
                ],
                if (today.isNotEmpty || legacyToday.isNotEmpty) ...[
                  AcademiaSectionHeader(
                    kicker: "Aujourd'hui",
                    title: 'Le reste de ta journée',
                    accent: _accent,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ...today.asMap().entries.map(
                              (e) => AcademiaEntrance(
                                index: e.key,
                                from: AcademiaEntranceFrom.left,
                                child: _timelineRow(
                                  time: _timeLabel(e.value.scheduledStart),
                                  relative:
                                      _relativeLabel(e.value.scheduledStart),
                                  isNext: e.key == 0,
                                  child: _scheduledCard(e.value),
                                ),
                              ),
                            ),
                        ...legacyToday.asMap().entries.map(
                              (e) => AcademiaEntrance(
                                index: today.length + e.key,
                                from: AcademiaEntranceFrom.left,
                                child: _timelineRow(
                                  time: _legacyTimeLabel(e.value),
                                  relative:
                                      _relativeLabel(_legacyStart(e.value)),
                                  isNext: false,
                                  child: _legacyCard(e.value),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
                if (later.isNotEmpty || legacyLater.isNotEmpty) ...[
                  AcademiaSectionHeader(
                    kicker: 'À venir',
                    title: 'Les prochains jours',
                    count: '${later.length + legacyLater.length}',
                    accent: _accent,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        ...later.asMap().entries.map(
                              (e) => AcademiaEntrance(
                                index: e.key,
                                from: AcademiaEntranceFrom.left,
                                child: _timelineRow(
                                  time: _dayLabel(e.value.scheduledStart),
                                  relative:
                                      _timeLabel(e.value.scheduledStart),
                                  isNext: false,
                                  child: _scheduledCard(e.value),
                                ),
                              ),
                            ),
                        ...legacyLater.asMap().entries.map(
                              (e) => AcademiaEntrance(
                                index: later.length + e.key,
                                from: AcademiaEntranceFrom.left,
                                child: _timelineRow(
                                  time: _legacyDayLabel(e.value),
                                  relative: _legacyTimeLabel(e.value),
                                  isNext: false,
                                  child: _legacyCard(e.value),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
                if (replays.isNotEmpty) ...[
                  AcademiaSectionHeader(
                    kicker: 'Rattraper',
                    title: 'Replays',
                    count: '${replays.length}',
                    accent: _accent,
                  ),
                  _replayGrid(replays),
                  if (unified.hasMoreReplays)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Center(
                        child: unified.isLoadingReplays
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _accent,
                                ),
                              )
                            : _smallButton(
                                label: 'Voir plus de replays',
                                icon: Icons.expand_more_rounded,
                                filled: false,
                                color: _accent,
                                onTap: () => unified.loadReplays(
                                  sessionType: _typeFilter,
                                  append: true,
                                ),
                              ),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Filtres ──────────────────────────────────────────────────────────

  Widget _filterBar() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _filters.entries
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AcademiaFilterChip(
                  label: entry.value,
                  selected: _typeFilter == entry.key,
                  accent: _accent,
                  onTap: () {
                    setState(() => _typeFilter = entry.key);
                    _load();
                  },
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  // ─── Carte « en direct » ──────────────────────────────────────────────

  Widget _liveHeroCard(AcademiaSession session) {
    final features = <String>[
      if (session.isChatEnabled) 'Chat',
      if (session.isQuizEnabled) 'Quiz',
      if (session.isWhiteboardEnabled) 'Tableau',
      if (session.isScreenShareEnabled) 'Partage d\'écran',
      if (session.isHandRaiseEnabled) 'Main levée',
    ];

    final elapsed = _elapsedLabel(session.actualStart);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AcademiaPalette.surface,
        borderRadius: BorderRadius.circular(AcademiaPalette.rXl),
        border: Border.all(color: AcademiaPalette.live.withValues(alpha: 0.25)),
        boxShadow: AcademiaPalette.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AcademiaCover(
            height: 150,
            imageUrl: session.thumbnailUrl,
            seed: session.title,
            gradient: AcademiaPalette.livesHeader,
            icon: Icons.videocam_rounded,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AcademiaPalette.rXl),
            ),
            overlays: [
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: AcademiaPalette.live,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AcademiaPulseDot(color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        elapsed == null ? 'EN DIRECT' : 'EN DIRECT · $elapsed',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (session.currentParticipants > 0)
                Positioned(
                  top: 12,
                  right: 12,
                  child: AcademiaCoverTag(
                    label: '${session.currentParticipants} présents',
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AcademiaBadge(
                  label: _typeLabel(session.type).toUpperCase(),
                  color: _accent,
                ),
                const SizedBox(height: 8),
                Text(
                  session.title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                    color: AcademiaPalette.ink,
                  ),
                ),
                if ((session.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    session.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.2,
                      height: 1.45,
                      color: AcademiaPalette.muted,
                    ),
                  ),
                ],
                if ((session.hostDisplayName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _hostRow(session),
                ],
                if (features.isNotEmpty) ...[
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: features.map(_featurePill).toList(growable: false),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AcademiaPalette.onAir,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow:
                          AcademiaPalette.shadowAccent(AcademiaPalette.live),
                    ),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _join(session),
                      icon: const Icon(Icons.videocam_rounded, size: 18),
                      label: const Text(
                        'Rejoindre le direct',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hostRow(AcademiaSession session) {
    final name = session.hostDisplayName ?? '';
    final subject = session.subject ?? '';
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            gradient: AcademiaPalette.cool,
            shape: BoxShape.circle,
          ),
          child: Text(
            _initials(name),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AcademiaPalette.ink,
                ),
              ),
              if (subject.isNotEmpty)
                Text(
                  subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AcademiaPalette.faint,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _featurePill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AcademiaPalette.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AcademiaPalette.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AcademiaPalette.muted,
          ),
        ),
      );

  // ─── Timeline ─────────────────────────────────────────────────────────

  Widget _timelineRow({
    required String time,
    required String relative,
    required bool isNext,
    required Widget child,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 54,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AcademiaPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    relative,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AcademiaPalette.faint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 24,
            child: Stack(
              children: [
                Positioned(
                  left: 11,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: AcademiaPalette.border),
                ),
                Positioned(
                  top: 14,
                  left: 6,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AcademiaPalette.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isNext
                            ? AcademiaPalette.live
                            : AcademiaPalette.blueLight,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduledCard(AcademiaSession session) {
    final meta = <String>[
      if ((session.hostDisplayName ?? '').isNotEmpty) session.hostDisplayName!,
      if ((session.subject ?? '').isNotEmpty) session.subject!,
      if (session.maxParticipants != null)
        '${session.currentParticipants}/${session.maxParticipants} inscrits',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: AcademiaPalette.surface,
        borderRadius: BorderRadius.circular(AcademiaPalette.rMd),
        border: Border.all(color: AcademiaPalette.border),
        boxShadow: AcademiaPalette.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AcademiaBadge(
            label: _typeLabel(session.type).toUpperCase(),
            color: _typeColor(session.type),
          ),
          const SizedBox(height: 7),
          Text(
            session.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.2,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AcademiaPalette.ink,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              meta,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.8,
                color: AcademiaPalette.muted,
              ),
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              _smallButton(
                label: 'Me rappeler',
                icon: Icons.notifications_none_rounded,
                filled: true,
                color: _accent,
                onTap: () => _remind(session.title),
              ),
              const SizedBox(width: 7),
              _smallButton(
                label: 'Entrer',
                icon: Icons.login_rounded,
                filled: false,
                color: _accent,
                onTap: () => _join(session),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legacyCard(Map<String, dynamic> session) {
    final title = (session['title'] ?? '').toString();
    final courseTitle = (session['course_title'] ?? '').toString();
    final status = (session['status'] ?? '').toString();
    final providerName = (session['provider'] ?? '').toString();
    final joinUrl = (session['join_url'] ?? '').toString();
    final replayUrl = (session['replay_video_url'] ?? '').toString();
    final sessionId = session['id']?.toString();
    final isLivekit = providerName.toLowerCase() == 'livekit';
    final isRunning = status == 'running';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: AcademiaPalette.surface,
        borderRadius: BorderRadius.circular(AcademiaPalette.rMd),
        border: Border.all(
          color: isRunning
              ? AcademiaPalette.live.withValues(alpha: 0.3)
              : AcademiaPalette.border,
        ),
        boxShadow: AcademiaPalette.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AcademiaBadge(
                label: 'COURS EN LIGNE',
                color: AcademiaPalette.teal,
              ),
              if (isRunning) ...[
                const SizedBox(width: 6),
                const AcademiaBadge(
                  label: 'EN DIRECT',
                  color: AcademiaPalette.live,
                  pulsing: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.2,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AcademiaPalette.ink,
            ),
          ),
          if (courseTitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              courseTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.8,
                color: AcademiaPalette.muted,
              ),
            ),
          ],
          const SizedBox(height: 9),
          if (isLivekit && status != 'ended' && sessionId != null)
            _smallButton(
              label: isRunning ? 'Rejoindre le direct' : 'Rejoindre',
              icon: isRunning ? Icons.videocam_rounded : Icons.login_rounded,
              filled: true,
              color: isRunning ? AcademiaPalette.live : _accent,
              onTap: () {
                Navigator.of(context).push(
                  AcademiaPageRoute(
                    builder: (_) => AcademiaClassroomScreen(
                      session: AcademiaSession(
                        id: sessionId,
                        type: SessionType.course,
                        status: SessionStatus.running,
                        provider: SessionProvider.livekit,
                        title: title,
                        hostId: '',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                      isHost: false,
                    ),
                  ),
                );
              },
            )
          else if (joinUrl.isNotEmpty || replayUrl.isNotEmpty)
            _smallButton(
              label: joinUrl.isNotEmpty ? 'Rejoindre' : 'Voir le replay',
              icon: joinUrl.isNotEmpty
                  ? Icons.login_rounded
                  : Icons.play_circle_outline_rounded,
              filled: false,
              color: _accent,
              onTap: () => _openExternalUrl(
                joinUrl.isNotEmpty ? joinUrl : replayUrl,
              ),
            ),
        ],
      ),
    );
  }

  Widget _smallButton({
    required String label,
    required IconData icon,
    required bool filled,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AcademiaTapScale(
      onTap: onTap,
      scale: 0.93,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? color : AcademiaPalette.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: filled ? color : AcademiaPalette.borderStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: filled ? Colors.white : AcademiaPalette.text),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.8,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : AcademiaPalette.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Replays ──────────────────────────────────────────────────────────

  Widget _replayGrid(List<AcademiaSession> replays) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 560
              ? 2
              : constraints.maxWidth < 980
                  ? 3
                  : 4;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 11,
              crossAxisSpacing: 11,
              mainAxisExtent: 138,
            ),
            itemCount: replays.length,
            itemBuilder: (context, index) => AcademiaEntrance(
              index: index,
              child: _replayCard(replays[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _replayCard(AcademiaSession session) {
    return AcademiaTapScale(
      onTap: () {
        final url = session.replayUrl;
        if (url != null && url.isNotEmpty) _openExternalUrl(url);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AcademiaPalette.surface,
          borderRadius: BorderRadius.circular(AcademiaPalette.rMd),
          border: Border.all(color: AcademiaPalette.border),
          boxShadow: AcademiaPalette.shadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AcademiaCover(
              height: 78,
              imageUrl: session.thumbnailUrl,
              seed: session.title,
              icon: Icons.play_circle_outline_rounded,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AcademiaPalette.rMd),
              ),
              overlays: [
                Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 30,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: AcademiaCoverTag(
                    label: _durationLabel(session),
                    background: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AcademiaPalette.ink,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      [
                        _typeLabel(session.type),
                        if ((session.hostDisplayName ?? '').isNotEmpty)
                          session.hostDisplayName!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.3,
                        color: AcademiaPalette.faint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Utilitaires ──────────────────────────────────────────────────────

  static bool _isToday(AcademiaSession s) {
    final start = s.scheduledStart;
    if (start == null) return false;
    final local = start.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _timeLabel(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    return '${_two(local.hour)}h${_two(local.minute)}';
  }

  static String _dayLabel(DateTime? date) {
    if (date == null) return '—';
    const days = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
    final local = date.toLocal();
    return days[(local.weekday - 1) % 7];
  }

  static String _relativeLabel(DateTime? date) {
    if (date == null) return '';
    final diff = date.toLocal().difference(DateTime.now());
    if (diff.isNegative) return 'en cours';
    if (diff.inMinutes < 60) return 'dans ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'dans ${diff.inHours} h';
    return 'dans ${diff.inDays} j';
  }

  static String? _elapsedLabel(DateTime? actualStart) {
    if (actualStart == null) return null;
    final diff = DateTime.now().difference(actualStart.toLocal());
    if (diff.isNegative) return null;
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    return '${diff.inHours} h ${_two(diff.inMinutes % 60)}';
  }

  /// Date de début d'une séance héritée (`online_course_live_sessions`).
  static DateTime? _legacyStart(Map<String, dynamic> session) =>
      DateTime.tryParse((session['start_at'] ?? '').toString());

  static String _legacyTimeLabel(Map<String, dynamic> session) {
    final parsed = _legacyStart(session);
    return parsed == null ? '—' : _timeLabel(parsed);
  }

  static String _legacyDayLabel(Map<String, dynamic> session) {
    final parsed = _legacyStart(session);
    return parsed == null ? '—' : _dayLabel(parsed);
  }

  /// Sans date exploitable, une séance héritée est traitée comme « du jour » :
  /// mieux vaut la montrer trop tôt que la cacher.
  static bool _isSameDayAsToday(DateTime? date) {
    if (date == null) return true;
    final local = date.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  static String _durationLabel(AcademiaSession session) {
    final start = session.actualStart ?? session.scheduledStart;
    final end = session.actualEnd ?? session.scheduledEnd;
    if (start == null || end == null) return 'Replay';
    final diff = end.difference(start);
    if (diff.inMinutes <= 0) return 'Replay';
    if (diff.inHours == 0) return '${diff.inMinutes} min';
    return '${diff.inHours}h${_two(diff.inMinutes % 60)}';
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  static String _typeLabel(SessionType type) => switch (type) {
        SessionType.course => 'Cours',
        SessionType.td => 'TD',
        SessionType.prepConcours => 'Prépa concours',
        SessionType.orientation => 'Orientation',
        SessionType.conference => 'Conférence',
        SessionType.masterclass => 'Masterclass',
        SessionType.livePedagogique => 'Live pédagogique',
        SessionType.revisionCollective => 'Révision collective',
        SessionType.examBlanc => 'Examen blanc',
        SessionType.gameChallenge => 'Challenge',
      };

  static Color _typeColor(SessionType type) => switch (type) {
        SessionType.course => AcademiaPalette.green600,
        SessionType.td => AcademiaPalette.blue,
        SessionType.prepConcours => AcademiaPalette.purple,
        SessionType.orientation => AcademiaPalette.teal,
        SessionType.conference => AcademiaPalette.blue,
        SessionType.masterclass => AcademiaPalette.amber,
        SessionType.livePedagogique => AcademiaPalette.green600,
        SessionType.revisionCollective => AcademiaPalette.teal,
        SessionType.examBlanc => AcademiaPalette.orange,
        SessionType.gameChallenge => AcademiaPalette.purple,
      };
}
