import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/teacher_prep_live_sessions_provider.dart';
import '../../theme/prep_theme.dart';
import '../live/livekit_room_screen.dart';

/// Écran enseignant — Sessions live CONCOURS (distinct des sessions cours en ligne).
/// Types : révision, exam blanc, Q&A — liés au module prep concours BF.
class TeacherPrepLiveSessionsScreen extends StatefulWidget {
  const TeacherPrepLiveSessionsScreen({super.key});

  @override
  State<TeacherPrepLiveSessionsScreen> createState() =>
      _TeacherPrepLiveSessionsScreenState();
}

class _TeacherPrepLiveSessionsScreenState
    extends State<TeacherPrepLiveSessionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherPrepLiveSessionsProvider>().loadMySessions();
    });
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'draft': return 'Brouillon';
      case 'approved': return 'Approuvée';
      case 'running': return 'En cours';
      case 'ended': return 'Terminée';
      default: return status ?? 'Inconnu';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'draft': return const Color(0xFF6B7280);
      case 'approved': return PrepTheme.success;
      case 'running': return PrepTheme.primary;
      case 'ended': return const Color(0xFF6B7280);
      default: return const Color(0xFF6B7280);
    }
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
    return Consumer<TeacherPrepLiveSessionsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.sessions.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: PrepTheme.primary));
        }

        return RefreshIndicator(
          color: PrepTheme.primary,
          onRefresh: provider.loadMySessions,
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Sessions Live Concours',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: PrepTheme.textPrimary)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context, provider),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Planifier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PrepTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(provider.error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),

              if (provider.sessions.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.videocam_off_outlined,
                            size: 48, color: PrepTheme.textTertiary),
                        const SizedBox(height: 12),
                        const Text('Aucune session live concours',
                            style: TextStyle(color: PrepTheme.textTertiary)),
                        const SizedBox(height: 8),
                        const Text(
                          'Planifiez des cours de révision, exams blancs\nou sessions Q&A pour les candidats.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: PrepTheme.textTertiary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...provider.sessions.map((s) => _SessionCard(
                      session: s,
                      statusLabel: _statusLabel(s['status']?.toString()),
                      statusColor: _statusColor(s['status']?.toString()),
                      typeLabel: _typeLabel(s['session_type']?.toString()),
                      onStart: () async {
                        final id = s['id']?.toString();
                        if (id == null) return;
                        final ok = await provider.startSession(id);
                        if (ok && mounted) {
                          final prov = s['provider']?.toString() ?? '';
                          if (prov.toLowerCase() == 'livekit') {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => LivekitRoomScreen(sessionId: id),
                            ));
                          }
                        }
                      },
                      onEnd: () async {
                        final id = s['id']?.toString();
                        if (id == null) return;
                        await provider.endSession(id);
                      },
                      onEdit: () =>
                          _showCreateDialog(context, provider, existing: s),
                    )),
            ],
          ),
        );
      },
    );
  }

  void _showCreateDialog(BuildContext context,
      TeacherPrepLiveSessionsProvider provider,
      {Map<String, dynamic>? existing}) {
    final titleCtrl =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description']?.toString() ?? '');
    final joinUrlCtrl =
        TextEditingController(text: existing?['join_url']?.toString() ?? '');
    String sessionType =
        existing?['session_type']?.toString() ?? 'revision';
    String? concoursType = existing?['concours_type']?.toString();
    String? subjectName = existing?['subject_name']?.toString();
    String providerName =
        existing?['provider']?.toString() ?? 'livekit';
    DateTime startAt = existing?['start_at'] != null
        ? DateTime.tryParse(existing!['start_at'].toString()) ?? DateTime.now()
        : DateTime.now().add(const Duration(hours: 1));

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text(
              existing == null
                  ? 'Nouvelle session live concours'
                  : 'Modifier la session',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Titre *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: sessionType,
                    decoration: const InputDecoration(
                        labelText: 'Type de session',
                        border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(
                          value: 'revision', child: Text('📖 Révision')),
                      DropdownMenuItem(
                          value: 'exam_blanc', child: Text('📝 Exam blanc')),
                      DropdownMenuItem(
                          value: 'qa', child: Text('❓ Q&A')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => sessionType = v ?? 'revision'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: concoursType,
                    decoration: const InputDecoration(
                        labelText: 'Concours', border: OutlineInputBorder()),
                    items: [
                      'ENAREF', 'ADMIN_CIVIL', 'DOUANE', 'GREFFIERS',
                      'SANTE', 'EDUCATION', 'GRH', 'PARAMILITAIRE'
                    ]
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => concoursType = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: subjectName,
                    decoration: const InputDecoration(
                        labelText: 'Matière', border: OutlineInputBorder()),
                    items: [
                      'Culture Générale', 'Actualités BF',
                      'Droit Constitutionnel', 'Droit Administratif',
                      'Économie', 'Finances Publiques', 'Fiscalité',
                      'Français', 'Tests Psychotechniques', 'Mathématiques'
                    ]
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => subjectName = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: providerName,
                    decoration: const InputDecoration(
                        labelText: 'Plateforme',
                        border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(
                          value: 'livekit', child: Text('LiveKit (in-app)')),
                      DropdownMenuItem(
                          value: 'zoom', child: Text('Zoom (lien externe)')),
                      DropdownMenuItem(
                          value: 'meet',
                          child: Text('Google Meet (lien externe)')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => providerName = v ?? 'livekit'),
                  ),
                  const SizedBox(height: 12),
                  if (providerName != 'livekit')
                    TextField(
                      controller: joinUrlCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Lien Zoom / Meet',
                          hintText: 'https://...',
                          border: OutlineInputBorder()),
                    ),
                  if (providerName != 'livekit') const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date et heure',
                        style: TextStyle(fontSize: 14)),
                    subtitle: Text(
                      '${startAt.day}/${startAt.month}/${startAt.year} à ${startAt.hour}h${startAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing:
                        const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: startAt,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date == null) return;
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(startAt),
                      );
                      if (time == null) return;
                      setDialogState(() {
                        startAt = DateTime(date.year, date.month, date.day,
                            time.hour, time.minute);
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: PrepTheme.primary),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop();
                await provider.upsertSession(
                  sessionId: existing?['id']?.toString(),
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  sessionType: sessionType,
                  concoursType: concoursType,
                  subjectName: subjectName,
                  provider: providerName,
                  joinUrl: joinUrlCtrl.text.trim().isEmpty
                      ? null
                      : joinUrlCtrl.text.trim(),
                  startAt: startAt,
                );
              },
              child: Text(existing == null ? 'Créer' : 'Modifier',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final String statusLabel;
  final Color statusColor;
  final String typeLabel;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onEdit;

  const _SessionCard({
    required this.session,
    required this.statusLabel,
    required this.statusColor,
    required this.typeLabel,
    required this.onStart,
    required this.onEnd,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final title = (session['title'] ?? '').toString();
    final concoursType = session['concours_type']?.toString();
    final subjectName = session['subject_name']?.toString();
    final startAt = session['start_at']?.toString() ?? '';
    final status = (session['status'] ?? 'draft').toString();
    final participants = (session['participant_count'] as int?) ?? 0;
    final providerName = (session['provider'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: PrepTheme.cardBox(
        borderColor: status == 'running'
            ? PrepTheme.primary.withAlpha(80)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  status == 'running'
                      ? Icons.videocam
                      : Icons.event,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('$typeLabel · $statusLabel',
                        style: TextStyle(fontSize: 11, color: statusColor)),
                  ],
                ),
              ),
              Text('$participants',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: PrepTheme.primary)),
              const Icon(Icons.people, size: 14, color: PrepTheme.textTertiary),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (concoursType != null) ...[
                PrepTheme.chip(concoursType, PrepTheme.primary),
                const SizedBox(width: 6),
              ],
              if (subjectName != null)
                PrepTheme.chip(subjectName, PrepTheme.success),
              const Spacer(),
              if (startAt.isNotEmpty)
                Text(startAt.substring(0, 16).replaceAll('T', ' '),
                    style: const TextStyle(
                        fontSize: 10, color: PrepTheme.textTertiary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (status == 'draft' || status == 'approved')
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Modifier', style: TextStyle(fontSize: 12)),
                ),
              if (status == 'draft' || status == 'approved')
                ElevatedButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label:
                      const Text('Démarrer', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PrepTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                ),
              if (status == 'running')
                ElevatedButton.icon(
                  onPressed: onEnd,
                  icon: const Icon(Icons.stop, size: 16),
                  label:
                      const Text('Terminer', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                ),
              if (status == 'running' &&
                  providerName.toLowerCase() == 'livekit')
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final id = session['id']?.toString();
                      if (id == null) return;
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LivekitRoomScreen(sessionId: id),
                      ));
                    },
                    icon: const Icon(Icons.videocam, size: 16),
                    label: const Text('Rejoindre',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PrepTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
