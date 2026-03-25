import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/prep_theme.dart';
import '../../live/livekit_room_screen.dart';

/// Onglet Lives — Sessions live concours planifiées par les enseignants.
class PrepLivesTab extends StatefulWidget {
  const PrepLivesTab({super.key});

  @override
  State<PrepLivesTab> createState() => _PrepLivesTabState();
}

class _PrepLivesTabState extends State<PrepLivesTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.rpc('app_prep_student_list_live_sessions');
      if (res is List) {
        _sessions = res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('[PrepLivesTab] load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'revision': return '📖 Révision';
      case 'exam_blanc': return '📝 Exam blanc';
      case 'qa': return '❓ Q&A';
      default: return type ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: PrepTheme.primary));
    }

    return RefreshIndicator(
      color: PrepTheme.primary,
      onRefresh: _load,
      child: _sessions.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.videocam_off_outlined, size: 48, color: PrepTheme.textTertiary),
                      const SizedBox(height: 12),
                      const Text('Aucune session live prévue',
                          style: TextStyle(color: PrepTheme.textTertiary, fontSize: 14)),
                      const SizedBox(height: 6),
                      const Text('Les enseignants planifieront des cours de révision,\nexams blancs et sessions Q&A.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: PrepTheme.textTertiary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final s = _sessions[index];
                return FadeInUp(
                  delay: Duration(milliseconds: 40 * index),
                  duration: const Duration(milliseconds: 350),
                  child: _LiveSessionCard(
                    session: s,
                    typeLabel: _typeLabel(s['session_type']?.toString()),
                    onJoin: () => _joinSession(s),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _joinSession(Map<String, dynamic> session) async {
    final sessionId = session['id']?.toString();
    final provider = (session['provider'] ?? '').toString().toLowerCase();
    final joinUrl = (session['join_url'] ?? '').toString();
    final status = (session['status'] ?? '').toString();

    if (sessionId == null) return;

    // Register participation
    try {
      await Supabase.instance.client.rpc('app_prep_student_join_live_session', params: {
        'p_session_id': sessionId,
      });
    } catch (e) {
      debugPrint('[PrepLivesTab] join error: $e');
    }

    if (status == 'ended') {
      final replayUrl = (session['replay_url'] ?? '').toString();
      if (replayUrl.isNotEmpty) {
        final uri = Uri.tryParse(replayUrl);
        if (uri != null && mounted) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le replay n\'est pas encore disponible.')),
        );
      }
      return;
    }

    if (provider == 'livekit') {
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LivekitRoomScreen(sessionId: sessionId),
        ));
      }
    } else if (joinUrl.isNotEmpty) {
      final uri = Uri.tryParse(joinUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}

class _LiveSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final String typeLabel;
  final VoidCallback onJoin;

  const _LiveSessionCard({required this.session, required this.typeLabel, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final title = (session['title'] ?? '').toString();
    final concours = session['concours_type']?.toString();
    final subject = session['subject_name']?.toString();
    final status = (session['status'] ?? '').toString();
    final startAt = session['start_at']?.toString() ?? '';
    final participants = (session['participant_count'] as int?) ?? 0;
    final myPart = session['my_participation'];
    final hasJoined = myPart != null;

    final isRunning = status == 'running';
    final isEnded = status == 'ended';
    final replayUrl = (session['replay_url'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: PrepTheme.cardBox(
        borderColor: isRunning ? PrepTheme.primary.withAlpha(80) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: (isRunning ? PrepTheme.primary : PrepTheme.textTertiary).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isRunning ? Icons.videocam : isEnded ? Icons.replay : Icons.event,
                  color: isRunning ? PrepTheme.primary : PrepTheme.textTertiary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(typeLabel, style: const TextStyle(fontSize: 11, color: PrepTheme.textTertiary)),
                  ],
                ),
              ),
              if (isRunning)
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
                      Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (concours != null) ...[PrepTheme.chip(concours, PrepTheme.primary), const SizedBox(width: 6)],
              if (subject != null) PrepTheme.chip(subject, PrepTheme.success),
              const Spacer(),
              Text('$participants participants', style: const TextStyle(fontSize: 10, color: PrepTheme.textTertiary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (startAt.isNotEmpty)
                Text(startAt.length >= 16 ? startAt.substring(0, 16).replaceAll('T', ' ') : startAt,
                    style: const TextStyle(fontSize: 11, color: PrepTheme.textTertiary)),
              const Spacer(),
              if (isRunning)
                ElevatedButton.icon(
                  onPressed: onJoin,
                  icon: const Icon(Icons.videocam, size: 16),
                  label: Text(hasJoined ? 'Rejoindre' : 'Participer', style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PrepTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                )
              else if (isEnded && replayUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: onJoin,
                  icon: const Icon(Icons.replay, size: 16),
                  label: const Text('Replay', style: TextStyle(fontSize: 12)),
                )
              else
                Text(
                  isEnded ? 'Terminée' : 'À venir',
                  style: TextStyle(fontSize: 12, color: isEnded ? PrepTheme.textTertiary : PrepTheme.primary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
