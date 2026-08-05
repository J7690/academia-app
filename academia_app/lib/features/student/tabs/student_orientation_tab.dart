import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/academia_session_provider.dart';
import '../../../providers/orientation_provider.dart';
import '../../../providers/orientation_quiz_provider.dart';
import '../../../theme/academia_palette.dart';
import '../../../widgets/academia_motion.dart';
import '../../../widgets/academia_ui.dart';
import '../../live/academia_classroom_screen.dart';
import '../../live/session_summary_screen.dart';
import '../../orientation/orientation_booking_sheet.dart';
import '../../orientation/orientation_quiz_screen.dart';
import '../../orientation/orientation_theme.dart' show OrientationLabels;

/// Onglet Orientation étudiant — « Ciel Academia », accent teal.
///
/// L'écran précédent ouvrait sur la liste des conseillers. Sans conseiller
/// inscrit, l'étudiant tombait sur du vide et ne revenait pas. Ici, le **test
/// d'orientation** passe en accroche : gratuit, quatre minutes, il fonctionne
/// même quand personne n'est disponible — et son résultat devient l'argument
/// qui mène à la consultation.
///
/// Construction :
///   1. En-tête teal + compteurs
///   2. Test d'orientation (trois états : à faire, en cours, résultat)
///   3. Prochain rendez-vous
///   4. Conseillers, avec leurs premiers créneaux
///   5. Fiches d'orientation
class StudentOrientationTab extends StatefulWidget {
  const StudentOrientationTab({super.key});

  @override
  State<StudentOrientationTab> createState() => _StudentOrientationTabState();
}

class _StudentOrientationTabState extends State<StudentOrientationTab> {
  static const _accent = AcademiaPalette.teal;

  final GlobalKey _counselorsKey = GlobalKey();
  String? _kindFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final orientation = context.read<OrientationProvider>();
    final quiz = context.read<OrientationQuizProvider>();

    await orientation.loadMyProfile();
    if (!mounted) return;

    await Future.wait([
      orientation.loadMyBookings(),
      if (!orientation.isCounselor) quiz.load(),
      if (!orientation.isCounselor)
        orientation.searchCounselors(kind: _kindFilter),
    ]);
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AcademiaPalette.live : _accent,
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────

  Future<void> _openQuiz() async {
    final done = await Navigator.of(context).push<bool>(
      AcademiaPageRoute(builder: (_) => const OrientationQuizScreen()),
    );
    if (done == true && mounted) {
      _toast('Ton profil est prêt.');
    }
  }

  Future<void> _retakeQuiz() async {
    await context.read<OrientationQuizProvider>().reset();
    if (mounted) await _openQuiz();
  }

  void _scrollToCounselors() {
    final ctx = _counselorsKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  Future<void> _book(Map<String, dynamic> counselor) async {
    final booked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrientationBookingSheet(counselor: counselor),
    );
    if (booked == true && mounted) {
      _toast('Rendez-vous confirmé. Tu le retrouveras ici et dans tes Lives.');
      await context.read<OrientationProvider>().loadMyBookings();
    }
  }

  Future<void> _joinBooking(Map<String, dynamic> booking) async {
    final sessionId = booking['session_id']?.toString();
    if (sessionId == null || sessionId.isEmpty) {
      _toast("Cette consultation n'a pas encore de salle.", error: true);
      return;
    }
    final sessions = context.read<AcademiaSessionProvider>();
    final session = await sessions.getSession(sessionId);
    if (!mounted) return;
    if (session == null) {
      _toast(sessions.error ?? 'Salle introuvable.', error: true);
      return;
    }
    await sessions.joinSession(sessionId);
    if (!mounted) return;
    await Navigator.of(context).push(
      AcademiaPageRoute(
        builder: (_) =>
            AcademiaClassroomScreen(session: session, isHost: false),
      ),
    );
  }

  // ─── Rendu ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer2<OrientationProvider, OrientationQuizProvider>(
      builder: (context, orientation, quiz, _) {
        // Cet onglet ne sert QUE l'étudiant. Le conseiller n'arrive jamais
        // jusqu'ici : `auth_wrapper` route `orientation_counselor` vers
        // `CounselorDashboardScreen`. La branche qui renvoyait vers
        // `OrientationScreen` était donc morte, et maintenait en vie un écran
        // de 1 600 lignes que plus rien n'atteignait.
        final bookings = orientation.bookings;
        final aVenir = bookings
            .where((b) => b['status'] == 'confirmed' || b['status'] == 'pending')
            .toList()
          ..sort((a, b) => '${a['scheduled_at']}'.compareTo('${b['scheduled_at']}'));
        final fiches =
            bookings.where((b) => b['fiche_existe'] == true).toList(growable: false);
        final counselors = orientation.counselors;

        return DecoratedBox(
          decoration: const BoxDecoration(gradient: AcademiaPalette.skyBackground),
          child: RefreshIndicator(
            color: _accent,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                AcademiaHeader(
                  title: 'Orientation',
                  subtitle:
                      'Trouve ta voie, puis parle à quelqu’un qui la connaît.',
                  gradient: AcademiaPalette.orientationHeader,
                  stats: [
                    AcademiaHeaderStat('${aVenir.length}', 'RDV à venir'),
                    AcademiaHeaderStat('${counselors.length}', 'conseillers'),
                    AcademiaHeaderStat('${fiches.length}', 'fiches'),
                  ],
                ),
                const SizedBox(height: 18),
                if (orientation.error != null)
                  AcademiaErrorBanner(
                    message: orientation.error!,
                    onRetry: _load,
                  ),
                _quizSection(quiz),
                if (aVenir.isNotEmpty) ...[
                  const AcademiaSectionHeader(
                    kicker: 'Mon suivi',
                    title: 'Prochain rendez-vous',
                    accent: _accent,
                  ),
                  ...aVenir.take(2).toList().asMap().entries.map(
                        (e) => AcademiaEntrance(
                          index: e.key,
                          child: _bookingCard(e.value),
                        ),
                      ),
                ],
                _counselorsSection(orientation, counselors),
                if (fiches.isNotEmpty) ...[
                  const AcademiaSectionHeader(
                    kicker: 'Mes documents',
                    title: 'Fiches d’orientation',
                    accent: _accent,
                  ),
                  ...fiches.asMap().entries.map(
                        (e) => AcademiaEntrance(
                          index: e.key,
                          child: _ficheCard(e.value),
                        ),
                      ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // 2 ─ Test d'orientation -----------------------------------------------

  Widget _quizSection(OrientationQuizProvider quiz) {
    if (quiz.isLoading && quiz.questions.isEmpty) {
      return const AcademiaSkeletonList(count: 1, height: 180);
    }

    if (quiz.isCompleted && quiz.result != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AcademiaSectionHeader(
            kicker: 'Ton test',
            title: 'Ce que dit ton profil',
            accent: _accent,
          ),
          AcademiaEntrance(
            child: OrientationQuizResultCard(
              result: quiz.result!,
              onTalkToCounselor: _scrollToCounselors,
              onRetake: _retakeQuiz,
            ),
          ),
        ],
      );
    }

    return AcademiaEntrance(child: _quizHero(quiz));
  }

  Widget _quizHero(OrientationQuizProvider quiz) {
    final resuming = quiz.hasStarted;
    final remaining = (quiz.total - quiz.answered).clamp(0, quiz.total);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: resuming
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00363B), AcademiaPalette.teal, Color(0xFF16A34A)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AcademiaPalette.teal,
                  AcademiaPalette.blue,
                  AcademiaPalette.blueLight,
                ],
              ),
        borderRadius: BorderRadius.circular(AcademiaPalette.rXl),
        boxShadow: AcademiaPalette.shadowAccent(AcademiaPalette.teal),
      ),
      child: AcademiaTapScale(
        onTap: _openQuiz,
        scale: 0.98,
        child: Stack(
          children: [
            Positioned(
              right: -50,
              top: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      resuming ? 'REPRENDRE' : 'GRATUIT · 4 MINUTES',
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  Text(
                    resuming
                        ? 'Tu y es presque'
                        : 'Quelle filière est faite pour toi ?',
                    style: const TextStyle(
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 7),
                  SizedBox(
                    width: 280,
                    child: Text(
                      resuming
                          ? 'Il te reste $remaining question(s), à peine deux minutes.'
                          : '${quiz.total} questions sur ce que tu aimes, ce que tu '
                              'réussis et la vie que tu veux. À la fin : ton profil '
                              'et trois pistes qui te correspondent.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  if (resuming) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: quiz.progress),
                        duration: AcademiaMotion.slow,
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Question ${quiz.answered + 1} sur ${quiz.total}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          resuming ? 'Continuer' : 'Commencer le test',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AcademiaPalette.teal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 17, color: AcademiaPalette.teal),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3 ─ Rendez-vous ------------------------------------------------------

  Widget _bookingCard(Map<String, dynamic> booking) {
    final when = DateTime.tryParse('${booking['scheduled_at']}');
    final counselor = '${booking['counselor_name'] ?? ''}';
    final motif = '${booking['motif'] ?? ''}';
    final duree = booking['duree_minutes'];
    final soon = when != null &&
        when.toLocal().difference(DateTime.now()).inHours < 24 &&
        !when.toLocal().isBefore(DateTime.now().subtract(const Duration(hours: 2)));

    final meta = <String>[
      if (counselor.isNotEmpty) counselor,
      if (duree is num) '${duree.toInt()} min',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AcademiaPalette.surface,
        borderRadius: BorderRadius.circular(AcademiaPalette.rLg),
        border: Border(
          left: BorderSide(
            color: soon ? AcademiaPalette.live : _accent,
            width: 4,
          ),
          top: const BorderSide(color: AcademiaPalette.border),
          right: const BorderSide(color: AcademiaPalette.border),
          bottom: const BorderSide(color: AcademiaPalette.border),
        ),
        boxShadow: AcademiaPalette.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (soon) ...[
                const AcademiaPulseDot(),
                const SizedBox(width: 6),
              ],
              Text(
                _whenLabel(when).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: soon ? AcademiaPalette.live : _accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            motif.isEmpty ? 'Entretien d’orientation' : motif,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AcademiaPalette.ink,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              meta,
              style: const TextStyle(
                fontSize: 11.5,
                color: AcademiaPalette.muted,
              ),
            ),
          ],
          const SizedBox(height: 11),
          AcademiaTapScale(
            onTap: () => _joinBooking(booking),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: soon ? AcademiaPalette.live : _accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_rounded,
                      size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    soon ? 'Rejoindre' : 'Ouvrir la salle',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4 ─ Conseillers ------------------------------------------------------

  Widget _counselorsSection(
    OrientationProvider provider,
    List<Map<String, dynamic>> counselors,
  ) {
    return Column(
      key: _counselorsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AcademiaSectionHeader(
          kicker: 'Aller plus loin',
          title: 'Conseillers',
          accent: _accent,
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _kindChip('Tous', null),
              _kindChip('Scolaire', 'orientation'),
              _kindChip('Professionnelle', 'career'),
              _kindChip('Études à l’étranger', 'etudes_etranger'),
              _kindChip('Reconversion', 'reconversion'),
              _kindChip('Psychologue', 'psychologue'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (provider.isLoading && counselors.isEmpty)
          const AcademiaSkeletonList(count: 2, height: 150)
        else if (counselors.isEmpty)
          AcademiaEmptyState(
            icon: Icons.person_search_outlined,
            title: 'Aucun conseiller pour ce filtre',
            message: _kindFilter == null
                ? 'Le service ouvrira prochainement. En attendant, le test '
                    'd’orientation est déjà disponible : il est gratuit.'
                : 'Essaie un autre type d’accompagnement.',
            accent: _accent,
            actionLabel: _kindFilter == null ? null : 'Voir tous',
            onAction: () {
              setState(() => _kindFilter = null);
              context.read<OrientationProvider>().searchCounselors();
            },
          )
        else
          ...counselors.asMap().entries.map(
                (e) => AcademiaEntrance(
                  index: e.key,
                  child: _counselorCard(e.value),
                ),
              ),
      ],
    );
  }

  Widget _kindChip(String label, String? kind) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AcademiaFilterChip(
        label: label,
        selected: _kindFilter == kind,
        accent: _accent,
        onTap: () {
          setState(() => _kindFilter = kind);
          context.read<OrientationProvider>().searchCounselors(kind: kind);
        },
      ),
    );
  }

  Widget _counselorCard(Map<String, dynamic> counselor) {
    final name = '${counselor['full_name'] ?? ''}';
    final kind = '${counselor['kind'] ?? ''}';
    final bio = '${counselor['bio'] ?? ''}';
    final note = counselor['note_moyenne'];
    final consultations = counselor['consultations'];
    final tarif = counselor['tarif_fcfa'];
    final duree = counselor['duree_minutes'];
    final specialites = (counselor['specialites'] as List? ?? const [])
        .map((e) => '$e')
        .toList(growable: false);
    final langues = (counselor['langues'] as List? ?? const [])
        .map((e) => OrientationLabels.langue('$e'))
        .toList(growable: false);
    final slots = (counselor['prochains_creneaux'] as List? ?? const [])
        .map((e) => DateTime.tryParse('$e'))
        .whereType<DateTime>()
        .toList(growable: false);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AcademiaPalette.surface,
        borderRadius: BorderRadius.circular(AcademiaPalette.rLg),
        border: Border.all(color: AcademiaPalette.border),
        boxShadow: AcademiaPalette.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AcademiaPalette.coverFor(name),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AcademiaPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        OrientationLabels.kind(kind),
                        if (langues.isNotEmpty) langues.join(', '),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AcademiaPalette.muted,
                      ),
                    ),
                    if (note is num) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: AcademiaPalette.amber),
                          const SizedBox(width: 3),
                          Text(
                            note.toStringAsFixed(1).replaceAll('.', ','),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AcademiaPalette.amber,
                            ),
                          ),
                          if (consultations is num && consultations > 0)
                            Text(
                              ' · ${consultations.toInt()} consultation(s)',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AcademiaPalette.faint,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              bio,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AcademiaPalette.muted,
              ),
            ),
          ],
          if (specialites.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: specialites
                  .take(3)
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          OrientationLabels.speciality(s),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: _accent,
                          ),
                        ),
                      ))
                  .toList(growable: false),
            ),
          ],
          if (slots.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: slots.map((slot) {
                final today = _isToday(slot);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: today
                        ? _accent.withValues(alpha: 0.06)
                        : AcademiaPalette.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: today ? _accent : AcademiaPalette.border,
                    ),
                  ),
                  child: Text(
                    _slotLabel(slot),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: today ? _accent : AcademiaPalette.ink,
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 11),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AcademiaPalette.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tarif is num && tarif > 0
                            ? '${OrientationLabels.montant(tarif.toInt())} FCFA'
                            : 'Gratuit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: tarif is num && tarif > 0
                              ? AcademiaPalette.ink
                              : AcademiaPalette.success,
                        ),
                      ),
                      if (duree is num)
                        Text(
                          '${duree.toInt()} minutes',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AcademiaPalette.faint,
                          ),
                        ),
                    ],
                  ),
                ),
                AcademiaTapScale(
                  onTap: () => _book(counselor),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: AcademiaPalette.shadowAccent(_accent),
                    ),
                    child: const Text(
                      'Réserver',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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

  // 5 ─ Fiches -----------------------------------------------------------

  /// Ouvre le compte rendu de l'entretien, version élève.
  ///
  /// La carte portait un chevron mais aucun geste : elle annonçait une fiche
  /// consultable et ne menait nulle part. L'élève ne voit que la version
  /// publiée — tant que le conseiller n'a pas relu, l'écran le dit.
  Future<void> _ouvrirFiche(Map<String, dynamic> booking) async {
    final sessionId = booking['session_id']?.toString();
    if (sessionId == null || sessionId.isEmpty) {
      _toast("Cette consultation n'a pas de compte rendu.", error: true);
      return;
    }
    final when = DateTime.tryParse('${booking['scheduled_at']}');
    await Navigator.of(context).push(
      AcademiaPageRoute(
        builder: (_) => SessionSummaryScreen(
          sessionId: sessionId,
          sessionTitle: when == null
              ? 'Entretien d\'orientation'
              : 'Entretien du ${when.toLocal().day}/${when.toLocal().month}',
          isHost: false,
        ),
      ),
    );
  }

  Widget _ficheCard(Map<String, dynamic> booking) {
    final when = DateTime.tryParse('${booking['scheduled_at']}');
    final counselor = '${booking['counselor_name'] ?? ''}';

    return AcademiaTapScale(
      onTap: () => _ouvrirFiche(booking),
      child: Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AcademiaPalette.surface,
        borderRadius: BorderRadius.circular(AcademiaPalette.rLg),
        border: Border.all(color: AcademiaPalette.border),
        boxShadow: AcademiaPalette.shadowSoft,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AcademiaPalette.amber50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.description_outlined,
                size: 19, color: Color(0xFFB7791F)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  when == null
                      ? 'Fiche d’orientation'
                      : 'Fiche du ${when.toLocal().day}/${when.toLocal().month}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AcademiaPalette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  counselor.isEmpty
                      ? 'Synthèse et prochaines étapes'
                      : '$counselor · synthèse et prochaines étapes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.8,
                    color: AcademiaPalette.faint,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              size: 20, color: AcademiaPalette.faint),
        ],
      ),
      ),
    );
  }

  // ─── Utilitaires ──────────────────────────────────────────────────────

  static String _two(int v) => v.toString().padLeft(2, '0');

  static bool _isToday(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  static String _slotLabel(DateTime date) {
    final local = date.toLocal();
    final heure = '${_two(local.hour)}h${_two(local.minute)}';
    if (_isToday(local)) return 'Auj. $heure';
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (local.year == tomorrow.year &&
        local.month == tomorrow.month &&
        local.day == tomorrow.day) {
      return 'Demain $heure';
    }
    const jours = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
    return '${jours[(local.weekday - 1) % 7]} $heure';
  }

  static String _whenLabel(DateTime? date) {
    if (date == null) return 'Date à confirmer';
    final local = date.toLocal();
    final diff = local.difference(DateTime.now());
    final base = OrientationLabels.dateComplete(local);
    if (diff.isNegative) return base;
    if (diff.inHours < 1) return '$base · dans ${diff.inMinutes} min';
    if (diff.inHours < 48) return '$base · dans ${diff.inHours} h';
    return base;
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }
}
