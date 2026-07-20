import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/academia_session.dart';
import '../../../providers/academia_session_provider.dart';
import '../../../providers/td_gamification_provider.dart';
import '../../../providers/td_messages_provider.dart';
import '../../../theme/td_theme.dart';
import '../../live/academia_classroom_screen.dart';
import '../student_td_root_screen.dart' show StudentTdMessagesScreen;

/// Écran d'accès à un TD inscrit : rejoint la séance live en cours si
/// disponible (moteur unifié AcademiaSession, session_type = 'td'),
/// sinon affiche la prochaine séance programmée et l'accès à la
/// messagerie avec l'admin/enseignant.
///
/// Remplace le TODO historique "Navigate to enrollment detail / messages"
/// de TdMyEnrollmentsTab — c'était le seul chaînon manquant de
/// l'unification Live identifiée dans l'audit Student (Live/Cours/TD/Concours).
class TdEnrollmentAccessScreen extends StatefulWidget {
  final Map<String, dynamic> enrollment;

  const TdEnrollmentAccessScreen({super.key, required this.enrollment});

  @override
  State<TdEnrollmentAccessScreen> createState() =>
      _TdEnrollmentAccessScreenState();
}

class _TdEnrollmentAccessScreenState extends State<TdEnrollmentAccessScreen> {
  bool _loading = true;

  String? get _enrollmentId =>
      (widget.enrollment['id'] ?? widget.enrollment['enrollment_id'])
          ?.toString();

  String? get _programId => (widget.enrollment['program_id'] ??
          widget.enrollment['td_program_id'])
      ?.toString();

  String? get _teacherId => (widget.enrollment['assigned_teacher_id'] ??
          widget.enrollment['teacher_id'])
      ?.toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await context
          .read<AcademiaSessionProvider>()
          .loadAvailableSessions(sessionType: 'td');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Filtre les sessions TD pertinentes pour cette inscription :
  /// priorité au rattachement par programme, puis par enseignant assigné,
  /// et si aucune info de rattachement n'est disponible, on affiche
  /// tout ce que le serveur a jugé accessible (RLS déjà appliqué côté RPC).
  List<AcademiaSession> _relevantSessions(List<AcademiaSession> all) {
    final tdSessions =
        all.where((s) => s.type == SessionType.td).toList(growable: false);
    final programId = _programId;
    final teacherId = _teacherId;
    if (programId != null && programId.isNotEmpty) {
      final matched =
          tdSessions.where((s) => s.programId == programId).toList();
      if (matched.isNotEmpty) return matched;
    }
    if (teacherId != null && teacherId.isNotEmpty) {
      final matched =
          tdSessions.where((s) => s.hostId == teacherId).toList();
      if (matched.isNotEmpty) return matched;
    }
    return tdSessions;
  }

  Future<void> _openMessages() async {
    final id = _enrollmentId;
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'ouvrir la messagerie pour ce TD."),
        ),
      );
      return;
    }
    final messagesProvider = context.read<TdMessagesProvider>();
    await messagesProvider.loadMessages(id);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentTdMessagesScreen(enrollmentId: id),
      ),
    );
  }

  void _joinSession(AcademiaSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AcademiaClassroomScreen(
          session: session,
          isHost: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.enrollment['program_title']?.toString() ?? 'Mon TD';
    final sessions = context.watch<AcademiaSessionProvider>().sessions;
    final relevant = _relevantSessions(sessions);
    final live = relevant.where((s) => s.isLive).toList();
    final upcoming = relevant.where((s) => s.isUpcoming).toList()
      ..sort((a, b) {
        final da = a.scheduledStart ?? DateTime.now();
        final db = b.scheduledStart ?? DateTime.now();
        return da.compareTo(db);
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        backgroundColor: TdTheme.studentTdPrimary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (live.isNotEmpty) ...[
                    const Text(
                      'En direct maintenant',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...live.map((s) => _LiveSessionTile(
                          session: s,
                          onJoin: () => _joinSession(s),
                        )),
                    const SizedBox(height: 20),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: TdTheme.cardDecoration(),
                      child: Row(
                        children: [
                          Icon(Icons.videocam_off_outlined,
                              color: TdTheme.textTertiary),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "Aucune séance en direct pour le moment.",
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (upcoming.isNotEmpty) ...[
                    const Text(
                      'Prochaines séances',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...upcoming.map((s) => _UpcomingSessionTile(session: s)),
                    const SizedBox(height: 20),
                  ],
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TdTheme.studentTdPrimary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _openMessages,
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text("Contacter l'admin / enseignant"),
                  ),
                ],
              ),
            ),
    );
  }
}

class _LiveSessionTile extends StatelessWidget {
  final AcademiaSession session;
  final VoidCallback onJoin;

  const _LiveSessionTile({required this.session, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: TdTheme.cardDecoration(
        borderColor: Colors.red.withOpacity(0.4),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.white, size: 8),
                SizedBox(width: 4),
                Text('LIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              session.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ElevatedButton(
            onPressed: onJoin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );
  }
}

class _UpcomingSessionTile extends StatelessWidget {
  final AcademiaSession session;

  const _UpcomingSessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final d = session.scheduledStart;
    final label = d == null
        ? 'Date à confirmer'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à '
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: TdTheme.cardDecoration(),
      child: Row(
        children: [
          Icon(Icons.event, size: 18, color: TdTheme.studentTdPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(session.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          Text(label,
              style: TextStyle(fontSize: 11, color: TdTheme.textTertiary)),
        ],
      ),
    );
  }
}
