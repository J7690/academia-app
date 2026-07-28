import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/academia_session.dart';
import '../../providers/admin_learning_sessions_provider.dart';
import '../live/academia_classroom_screen.dart';

/// Supervision administrateur du Studio Live.
///
/// Réplique de la vue enseignant, mais sur **toutes** les séances de la
/// plateforme — y compris les brouillons que personne d'autre ne voit — et
/// avec les pouvoirs de modération.
///
/// Ce que l'administrateur peut faire de plus que l'enseignant :
///
/// * voir les séances de tous les hôtes, avec leur nom et leur adresse
/// * voir les brouillons non publiés
/// * publier ou dépublier la séance d'un enseignant
/// * **interrompre une séance en cours** et déconnecter ses participants
/// * annuler, rejeter, remettre en brouillon
/// * entrer dans n'importe quelle salle pour observer
/// * consulter le registre de présence de n'importe quelle séance
///
/// Chaque action de modération est tracée dans `app.admin_audit_log`.
class AdminStudioLiveScreen extends StatefulWidget {
  const AdminStudioLiveScreen({super.key});

  @override
  State<AdminStudioLiveScreen> createState() => _AdminStudioLiveScreenState();
}

class _AdminStudioLiveScreenState extends State<AdminStudioLiveScreen> {
  static const _accent = Color(0xFF6C5CE7);
  static const _red = Color(0xFFE14D4D);
  static const _teal = Color(0xFF12B886);
  static const _amber = Color(0xFFF0A020);

  String? _statusFilter;
  String? _typeFilter;
  final _searchCtrl = TextEditingController();

  static const _statuses = <String?, String>{
    null: 'Tous',
    'running': 'En cours',
    'scheduled': 'Planifiées',
    'draft': 'Brouillons',
    'ended': 'Terminées',
    'cancelled': 'Annulées',
  };

  static const _types = <String?, String>{
    null: 'Tous types',
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() => context.read<AdminLearningSessionsProvider>().load(
        status: _statusFilter,
        sessionType: _typeFilter,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? _red : null),
    );
  }

  // ─── Actions ────────────────────────────────────────────────────────

  Future<void> _changeStatus(Map<String, dynamic> s, String status) async {
    final provider = context.read<AdminLearningSessionsProvider>();
    final ok = await provider.updateStatus(s['id'].toString(), status);
    if (!mounted) return;
    if (ok) {
      _toast('Statut mis à jour : $status');
      await _load();
    } else {
      _toast(provider.error ?? 'Action impossible.', error: true);
    }
  }

  Future<void> _forceEnd(Map<String, dynamic> s) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Interrompre la séance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '« ${s['title']} » sera immédiatement terminée et tous ses '
              'participants déconnectés.',
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 6),
            Text(
              'Hôte : ${s['host_name'] ?? 'inconnu'}',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF5C6270)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Motif (tracé dans le journal)',
                hintText: 'Contenu inapproprié, erreur de planification…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Interrompre'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<AdminLearningSessionsProvider>();
    final n = await provider.forceEnd(
      s['id'].toString(),
      reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
    );
    if (!mounted) return;
    if (n == null) {
      _toast(provider.error ?? 'Interruption impossible.', error: true);
    } else {
      _toast('Séance interrompue. $n participant(s) déconnecté(s).');
      await _load();
    }
  }

  Future<void> _observe(Map<String, dynamic> s) async {
    final session = AcademiaSession.fromJson(s);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AcademiaClassroomScreen(session: session, isHost: false),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _showParticipants(Map<String, dynamic> s) async {
    final provider = context.read<AdminLearningSessionsProvider>();
    await provider.loadParticipants(s['id'].toString());
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ParticipantsSheet(title: s['title']?.toString() ?? ''),
    );
  }

  // ─── Rendu ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: Consumer<AdminLearningSessionsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.sessions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const Text('Studio Live — supervision',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                const Text(
                  'Toutes les séances de la plateforme, brouillons compris. '
                  'Chaque action de modération est tracée.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF5C6270)),
                ),
                const SizedBox(height: 16),
                _StatsRow(stats: provider.stats),
                const SizedBox(height: 16),
                _buildFilters(),
                const SizedBox(height: 8),
                if (provider.error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(provider.error!,
                        style: const TextStyle(fontSize: 13, color: _red)),
                  ),
                if (provider.sessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.videocam_off_outlined,
                            size: 42, color: Color(0xFF8A90A0)),
                        SizedBox(height: 12),
                        Text('Aucune séance ne correspond aux filtres',
                            style: TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                else
                  ...provider.sessions.map(_sessionCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: TextField(
            controller: _searchCtrl,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Rechercher un titre, un enseignant, un e-mail…',
              prefixIcon: const Icon(Icons.search, size: 19),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, size: 18),
                onPressed: _load,
              ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E5EA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E5EA)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._statuses.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _statusFilter == e.key,
                      onSelected: (_) {
                        setState(() => _statusFilter = e.key);
                        _load();
                      },
                    ),
                  )),
              const SizedBox(width: 8),
              ..._types.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _typeFilter == e.key,
                      selectedColor: _accent.withValues(alpha: 0.18),
                      onSelected: (_) {
                        setState(() => _typeFilter = e.key);
                        _load();
                      },
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sessionCard(Map<String, dynamic> s) {
    final status = (s['status'] ?? '').toString();
    final isRunning = status == 'running';
    final (label, color) = switch (status) {
      'running' => ('EN COURS', _red),
      'scheduled' || 'approved' => ('Publiée', _teal),
      'draft' => ('Brouillon', _amber),
      'ended' => ('Terminée', Colors.grey),
      'cancelled' => ('Annulée', Colors.grey),
      'rejected' => ('Rejetée', _red),
      _ => (status, Colors.grey),
    };

    final enLigne = _asInt(s['participants_en_ligne']);
    final total = _asInt(s['participants_total']);
    final messages = _asInt(s['messages_total']);
    final interrompue =
        (s['metadata'] is Map) && (s['metadata']['interrompue_par_admin'] == true);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRunning ? _red.withValues(alpha: 0.4) : const Color(0xFFE2E5EA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(text: label, color: color),
              const SizedBox(width: 6),
              _Pill(
                  text: _typeLabel((s['session_type'] ?? '').toString()),
                  color: _accent),
              if (interrompue) ...[
                const SizedBox(width: 6),
                const _Pill(text: 'Interrompue par un admin', color: _red),
              ],
              const Spacer(),
              if (isRunning)
                Text('$enLigne en ligne',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: _red)),
            ],
          ),
          const SizedBox(height: 8),
          Text(s['title']?.toString() ?? 'Sans titre',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 15, color: Color(0xFF8A90A0)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${s['host_name'] ?? 'Hôte inconnu'}'
                  '${s['host_email'] != null ? ' · ${s['host_email']}' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF5C6270)),
                ),
              ),
            ],
          ),
          if (s['course_title'] != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.menu_book_outlined,
                    size: 15, color: Color(0xFF8A90A0)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(s['course_title'].toString(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF5C6270))),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            children: [
              _Meta(icon: Icons.groups_outlined, text: '$total inscrits'),
              _Meta(icon: Icons.chat_bubble_outline, text: '$messages messages'),
              if (s['scheduled_start'] != null)
                _Meta(
                    icon: Icons.schedule,
                    text: _formatDate(s['scheduled_start'].toString())),
            ],
          ),
          const Divider(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isRunning) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _red),
                  onPressed: () => _forceEnd(s),
                  icon: const Icon(Icons.stop_circle_outlined, size: 17),
                  label: const Text('Interrompre'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _observe(s),
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  label: const Text('Observer'),
                ),
              ],
              if (status == 'draft')
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  onPressed: () => _changeStatus(s, 'scheduled'),
                  icon: const Icon(Icons.publish, size: 17),
                  label: const Text('Publier'),
                ),
              if (status == 'scheduled' || status == 'approved') ...[
                OutlinedButton(
                  onPressed: () => _changeStatus(s, 'draft'),
                  child: const Text('Dépublier'),
                ),
                OutlinedButton(
                  onPressed: () => _changeStatus(s, 'cancelled'),
                  child: const Text('Annuler'),
                ),
              ],
              OutlinedButton.icon(
                onPressed: () => _showParticipants(s),
                icon: const Icon(Icons.list_alt, size: 17),
                label: const Text('Participants'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static int _asInt(dynamic v) =>
      v is int ? v : int.tryParse('${v ?? 0}') ?? 0;

  static String _typeLabel(String t) => switch (t) {
        'course' => 'Cours',
        'td' => 'TD',
        'prep_concours' => 'Prépa concours',
        'orientation' => 'Orientation',
        'conference' => 'Conférence',
        'masterclass' => 'Masterclass',
        'live_pedagogique' => 'Live pédagogique',
        'revision_collective' => 'Révision collective',
        'exam_blanc' => 'Examen blanc',
        'game_challenge' => 'Challenge',
        _ => t,
      };

  static String _formatDate(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}h${two(d.minute)}';
  }
}

// ─── Composants ───────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    int v(String k) {
      final x = stats[k];
      return x is int ? x : int.tryParse('${x ?? 0}') ?? 0;
    }

    final cards = <(String, int, Color)>[
      ('En cours', v('en_cours'), const Color(0xFFE14D4D)),
      ('En ligne', v('participants_en_ligne'), const Color(0xFF12B886)),
      ('Planifiées', v('planifiees'), const Color(0xFF6C5CE7)),
      ('Brouillons', v('brouillons'), const Color(0xFFF0A020)),
      ('Terminées', v('terminees'), const Color(0xFF8A90A0)),
    ];

    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (_, i) {
          final (label, value, color) = cards[i];
          return Container(
            width: 108,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E5EA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A90A0))),
                const SizedBox(height: 4),
                Text('$value',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ParticipantsSheet extends StatelessWidget {
  final String title;
  const _ParticipantsSheet({required this.title});

  @override
  Widget build(BuildContext context) {
    final participants =
        context.watch<AdminLearningSessionsProvider>().participants;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Registre de présence',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: Color(0xFF5C6270))),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: participants.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Aucun participant enregistré.',
                          style: TextStyle(color: Color(0xFF5C6270))),
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    itemCount: participants.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = participants[i];
                      final online = p['is_online'] == true;
                      final role = (p['role'] ?? 'participant').toString();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: online
                              ? const Color(0xFF12B886)
                              : const Color(0xFFD3D1C7),
                          child: Text(
                            (p['display_name']?.toString() ?? '?')
                                .characters
                                .take(1)
                                .toString()
                                .toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                            p['display_name']?.toString() ?? 'Sans nom',
                            style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                          role == 'host' ? 'Hôte' : 'Participant',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          online ? 'En ligne' : 'Hors ligne',
                          style: TextStyle(
                            fontSize: 12,
                            color: online
                                ? const Color(0xFF12B886)
                                : const Color(0xFF8A90A0),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w500, color: color)),
      );
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF8A90A0)),
          const SizedBox(width: 4),
          Text(text,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF8A90A0))),
        ],
      );
}
