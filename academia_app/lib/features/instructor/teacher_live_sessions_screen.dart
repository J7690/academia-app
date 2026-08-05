import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/academia_session.dart';
import '../../providers/academia_session_provider.dart';
import '../../providers/instructor_online_courses_provider.dart';
import '../live/academia_classroom_screen.dart';
import '../live/session_summary_screen.dart';

/// Écran enseignant — création et pilotage des séances en direct du moteur
/// unifié (`app.academia_sessions`).
///
/// C'était le chaînon manquant : `AcademiaSessionProvider` était écrit et
/// fonctionnel, mais aucun écran ne l'appelait en création. La table restait
/// donc vide, et le Studio Live ne pouvait pas être testé de bout en bout.
///
/// Cycle de vie exposé ici :
///
///   brouillon ──publier──> planifiée ──démarrer──> en cours ──terminer──> terminée
///        ^                     │
///        └────remettre─────────┘
///
/// Tant qu'une séance est en brouillon, elle n'apparaît pas aux étudiants.
class TeacherLiveSessionsScreen extends StatefulWidget {
  const TeacherLiveSessionsScreen({super.key});

  @override
  State<TeacherLiveSessionsScreen> createState() =>
      _TeacherLiveSessionsScreenState();
}

class _TeacherLiveSessionsScreenState extends State<TeacherLiveSessionsScreen> {
  static const _accent = Color(0xFF6C5CE7);
  static const _red = Color(0xFFE14D4D);
  static const _teal = Color(0xFF12B886);
  static const _amber = Color(0xFFF0A020);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AcademiaSessionProvider>().loadMySessions();
      context.read<InstructorOnlineCoursesProvider>().loadMyCourses();
    });
  }

  Future<void> _reload() =>
      context.read<AcademiaSessionProvider>().loadMySessions();

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? _red : null,
      ),
    );
  }

  // ─── Actions ────────────────────────────────────────────────────────

  Future<void> _publish(AcademiaSession s, String status) async {
    final provider = context.read<AcademiaSessionProvider>();
    final ok = await provider.setSessionStatus(s.id, status);
    if (!mounted) return;
    if (ok) {
      _toast(switch (status) {
        'scheduled' => 'Séance publiée — elle apparaît maintenant aux étudiants.',
        'draft' => 'Séance remise en brouillon.',
        _ => 'Séance annulée.',
      });
      await _reload();
    } else {
      _toast(provider.error ?? 'Action impossible.', error: true);
    }
  }

  Future<void> _start(AcademiaSession s) async {
    final provider = context.read<AcademiaSessionProvider>();
    final result = await provider.startSession(s.id);
    if (!mounted) return;
    if (result == null) {
      _toast(provider.error ?? 'Impossible de démarrer la séance.', error: true);
      return;
    }
    await _reload();
    if (!mounted) return;
    final fresh = provider.sessions.firstWhere(
      (e) => e.id == s.id,
      orElse: () => s,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AcademiaClassroomScreen(session: fresh, isHost: true),
      ),
    );
    await _reload();
  }

  Future<void> _rejoin(AcademiaSession s) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AcademiaClassroomScreen(session: s, isHost: true),
      ),
    );
    await _reload();
  }

  Future<void> _openSummary(AcademiaSession s) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionSummaryScreen(
          sessionId: s.id,
          sessionTitle: s.title,
          isHost: true,
        ),
      ),
    );
  }

  Future<void> _end(AcademiaSession s) async {
    final provider = context.read<AcademiaSessionProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminer la séance'),
        content: Text('« ${s.title} » sera clôturée pour tous les participants.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await provider.endSession(s.id);
    if (!mounted) return;
    ok ? _toast('Séance terminée.') : _toast(provider.error ?? 'Erreur.', error: true);
    await _reload();
  }

  // ─── Formulaire ─────────────────────────────────────────────────────

  Future<void> _openForm({AcademiaSession? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SessionForm(existing: existing),
    );
    if (saved == true) await _reload();
  }

  // ─── Rendu ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('Mes séances en direct'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.videocam_outlined),
        label: const Text('Créer une séance'),
      ),
      body: Consumer<AcademiaSessionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.sessions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = provider.sessions;
          final running = all.where((s) => s.status == SessionStatus.running).toList();
          final published = all
              .where((s) =>
                  s.status == SessionStatus.scheduled ||
                  s.status == SessionStatus.approved)
              .toList();
          final drafts = all.where((s) => s.status == SessionStatus.draft).toList();
          final past = all
              .where((s) =>
                  s.status == SessionStatus.ended ||
                  s.status == SessionStatus.cancelled)
              .toList();

          if (all.isEmpty) {
            return _EmptyState(onCreate: () => _openForm());
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (provider.error != null)
                  _Banner(text: provider.error!, color: _red),
                if (running.isNotEmpty) ...[
                  const _SectionTitle('En cours'),
                  ...running.map((s) => _card(s)),
                  const SizedBox(height: 20),
                ],
                if (published.isNotEmpty) ...[
                  const _SectionTitle('Publiées — visibles par les étudiants'),
                  ...published.map((s) => _card(s)),
                  const SizedBox(height: 20),
                ],
                if (drafts.isNotEmpty) ...[
                  const _SectionTitle('Brouillons — invisibles pour les étudiants'),
                  ...drafts.map((s) => _card(s)),
                  const SizedBox(height: 20),
                ],
                if (past.isNotEmpty) ...[
                  const _SectionTitle('Passées'),
                  ...past.map((s) => _card(s)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(AcademiaSession s) {
    final (label, color) = switch (s.status) {
      SessionStatus.running => ('EN COURS', _red),
      SessionStatus.scheduled || SessionStatus.approved => ('Publiée', _teal),
      SessionStatus.draft => ('Brouillon', _amber),
      SessionStatus.ended => ('Terminée', Colors.grey),
      SessionStatus.cancelled => ('Annulée', Colors.grey),
      _ => (s.status.name, Colors.grey),
    };

    final meta = <String>[
      _typeLabel(s.type),
      if (s.scheduledStart != null) _formatDate(s.scheduledStart!),
      if (s.currentParticipants > 0) '${s.currentParticipants} présents',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: s.status == SessionStatus.running
              ? _red.withValues(alpha: 0.4)
              : const Color(0xFFE2E5EA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500, color: color),
                ),
              ),
              const Spacer(),
              if (s.status == SessionStatus.draft ||
                  s.status == SessionStatus.scheduled ||
                  s.status == SessionStatus.approved)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  onPressed: () => _openForm(existing: s),
                  tooltip: 'Modifier',
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(s.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(meta.join(' · '),
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF5C6270))),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (s.status == SessionStatus.draft) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  onPressed: () => _publish(s, 'scheduled'),
                  icon: const Icon(Icons.publish, size: 17),
                  label: const Text('Publier'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _start(s),
                  icon: const Icon(Icons.play_arrow, size: 17),
                  label: const Text('Démarrer maintenant'),
                ),
              ],
              if (s.status == SessionStatus.scheduled ||
                  s.status == SessionStatus.approved) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _red),
                  onPressed: () => _start(s),
                  icon: const Icon(Icons.videocam, size: 17),
                  label: const Text('Démarrer'),
                ),
                OutlinedButton(
                  onPressed: () => _publish(s, 'draft'),
                  child: const Text('Remettre en brouillon'),
                ),
              ],
              if (s.status == SessionStatus.running) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _red),
                  onPressed: () => _rejoin(s),
                  icon: const Icon(Icons.login, size: 17),
                  label: const Text('Rejoindre la salle'),
                ),
                OutlinedButton(
                  onPressed: () => _end(s),
                  child: const Text('Terminer'),
                ),
              ],
              // Une séance terminée garde une valeur : sa fiche. C'est la
              // seule porte d'entrée de l'enseignant vers la synthèse quand
              // il a quitté la salle sans passer par « Terminer ».
              if (s.status == SessionStatus.ended)
                OutlinedButton.icon(
                  onPressed: () => _openSummary(s),
                  icon: const Icon(Icons.description_outlined, size: 17),
                  label: const Text('Fiche de séance'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _typeLabel(SessionType t) => switch (t) {
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

  static String _formatDate(DateTime d) {
    final l = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)} à ${two(l.hour)}h${two(l.minute)}';
  }
}

// ─── Formulaire de création / modification ────────────────────────────

class _SessionForm extends StatefulWidget {
  final AcademiaSession? existing;
  const _SessionForm({this.existing});

  @override
  State<_SessionForm> createState() => _SessionFormState();
}

class _SessionFormState extends State<_SessionForm> {
  static const _accent = Color(0xFF6C5CE7);

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();

  String _type = 'course';
  String? _courseId;
  DateTime _start = DateTime.now().add(const Duration(hours: 1));
  int _durationMinutes = 90;
  int _maxParticipants = 100;

  bool _chat = true;
  bool _quiz = true;
  bool _whiteboard = true;
  bool _screenShare = true;
  bool _handRaise = true;
  bool _recording = false;

  // L'orientation ne figure volontairement pas ici. Ce n'est pas une matière :
  // ni chapitre, ni exercice, ni quiz, ni tableau blanc. La faire passer par ce
  // formulaire produisait un écran dont les trois quarts des champs restaient
  // vides. Elle dispose désormais de son propre parcours — conseillers,
  // créneaux, réservation — et de son mode de studio.
  /// VALEUR COUPLÉE — à modifier des DEUX côtés :
  /// `student_live_sessions_tab._filters`. Un type créable ici mais absent
  /// là-bas produit une séance publiée que le filtre étudiant escamote.
  static const _types = <String, String>{
    'course': 'Cours',
    'td': 'TD',
    'prep_concours': 'Prépa concours',
    'masterclass': 'Masterclass',
    'revision_collective': 'Révision collective',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _descCtrl.text = e.description ?? '';
      _subjectCtrl.text = e.subject ?? '';
      _type = _typeToDb(e.type);
      _courseId = e.courseId;
      if (e.scheduledStart != null) _start = e.scheduledStart!.toLocal();
      if (e.scheduledStart != null && e.scheduledEnd != null) {
        _durationMinutes =
            e.scheduledEnd!.difference(e.scheduledStart!).inMinutes;
      }
      _maxParticipants = e.maxParticipants ?? 100;
      _chat = e.isChatEnabled;
      _quiz = e.isQuizEnabled;
      _whiteboard = e.isWhiteboardEnabled;
      _screenShare = e.isScreenShareEnabled;
      _handRaise = e.isHandRaiseEnabled;
      _recording = e.isRecordingEnabled;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  static String _typeToDb(SessionType t) => switch (t) {
        SessionType.course => 'course',
        SessionType.td => 'td',
        SessionType.prepConcours => 'prep_concours',
        SessionType.orientation => 'orientation',
        SessionType.conference => 'conference',
        SessionType.masterclass => 'masterclass',
        SessionType.livePedagogique => 'live_pedagogique',
        SessionType.revisionCollective => 'revision_collective',
        SessionType.examBlanc => 'exam_blanc',
        SessionType.gameChallenge => 'game_challenge',
      };

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null) return;
    setState(() {
      _start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final provider = context.read<AcademiaSessionProvider>();
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donnez un titre à la séance.')),
      );
      return;
    }

    final sessionId = await provider.upsertSession(
      sessionId: widget.existing?.id,
      sessionType: _type,
      title: title,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      subject: _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim(),
      courseId: _type == 'course' ? _courseId : null,
      scheduledStart: _start,
      scheduledEnd: _start.add(Duration(minutes: _durationMinutes)),
      maxParticipants: _maxParticipants,
      isChatEnabled: _chat,
      isQuizEnabled: _quiz,
      isWhiteboardEnabled: _whiteboard,
      isScreenShareEnabled: _screenShare,
      isHandRaiseEnabled: _handRaise,
      isRecordingEnabled: _recording,
    );

    if (!mounted) return;
    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Enregistrement impossible.'),
          backgroundColor: const Color(0xFFE14D4D),
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<InstructorOnlineCoursesProvider>().courses;
    final isEditing = widget.existing != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
              child: Row(
                children: [
                  Text(
                    isEditing ? 'Modifier la séance' : 'Créer une séance',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                children: [
                  const _Label('Type de séance'),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: _types.entries
                        .map((e) => ChoiceChip(
                              label: Text(e.value),
                              selected: _type == e.key,
                              onSelected: (_) => setState(() => _type = e.key),
                            ))
                        .toList(),
                  ),
                  if (_type == 'course') ...[
                    const _Label('Rattacher à un cours'),
                    _Field(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: _courseId,
                          hint: const Text('Aucun cours'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Aucun cours'),
                            ),
                            ...courses.map((c) => DropdownMenuItem<String?>(
                                  value: c['id']?.toString(),
                                  child: Text(
                                    (c['title'] ?? 'Sans titre').toString(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (v) => setState(() => _courseId = v),
                        ),
                      ),
                    ),
                  ],
                  const _Label('Titre'),
                  _Field(
                    child: TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Correction des exercices 8 à 14',
                      ),
                    ),
                  ),
                  const _Label('Description'),
                  _Field(
                    child: TextField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Ce que la séance couvrira',
                      ),
                    ),
                  ),
                  const _Label('Matière'),
                  _Field(
                    child: TextField(
                      controller: _subjectCtrl,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Analyse, Mécanique…',
                      ),
                    ),
                  ),
                  const _Label('Début'),
                  InkWell(
                    onTap: _pickDateTime,
                    child: _Field(
                      child: Row(
                        children: [
                          const Icon(Icons.event, size: 19, color: Color(0xFF5C6270)),
                          const SizedBox(width: 9),
                          Text(_TeacherLiveSessionsScreenState._formatDate(_start)),
                          const Spacer(),
                          const Icon(Icons.edit_calendar_outlined,
                              size: 18, color: Color(0xFF8A90A0)),
                        ],
                      ),
                    ),
                  ),
                  const _Label('Durée prévue'),
                  Wrap(
                    spacing: 7,
                    children: [30, 60, 90, 120]
                        .map((m) => ChoiceChip(
                              label: Text(m < 60 ? '$m min' : '${m ~/ 60} h${m % 60 == 0 ? '' : '30'}'),
                              selected: _durationMinutes == m,
                              onSelected: (_) =>
                                  setState(() => _durationMinutes = m),
                            ))
                        .toList(),
                  ),
                  const _Label('Participants maximum'),
                  Wrap(
                    spacing: 7,
                    children: [12, 30, 100, 300]
                        .map((n) => ChoiceChip(
                              label: Text('$n'),
                              selected: _maxParticipants == n,
                              onSelected: (_) =>
                                  setState(() => _maxParticipants = n),
                            ))
                        .toList(),
                  ),
                  const _Label('Fonctionnalités de la séance'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E5EA)),
                    ),
                    child: Column(
                      children: [
                        _Toggle('Chat', _chat, (v) => setState(() => _chat = v)),
                        _Toggle('Quiz en direct', _quiz,
                            (v) => setState(() => _quiz = v)),
                        _Toggle('Tableau blanc', _whiteboard,
                            (v) => setState(() => _whiteboard = v)),
                        _Toggle('Partage d\'écran', _screenShare,
                            (v) => setState(() => _screenShare = v)),
                        _Toggle('Main levée', _handRaise,
                            (v) => setState(() => _handRaise = v)),
                        _Toggle(
                          'Enregistrement',
                          _recording,
                          (v) => setState(() => _recording = v),
                          subtitle:
                              'Consomme le quota de transcodage LiveKit — 60 min par mois sur l\'offre gratuite.',
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Consumer<AcademiaSessionProvider>(
                    builder: (context, p, _) => FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: p.isSaving ? null : _save,
                      icon: p.isSaving
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check),
                      label: Text(isEditing
                          ? 'Enregistrer les modifications'
                          : 'Créer en brouillon'),
                    ),
                  ),
                  if (!isEditing)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'La séance est créée en brouillon. Elle n\'apparaîtra aux étudiants qu\'après publication.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF5C6270)),
                        textAlign: TextAlign.center,
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
}

// ─── Petits composants ────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 7),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8A90A0),
          ),
        ),
      );
}

class _Field extends StatelessWidget {
  final Widget child;
  const _Field({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E5EA)),
        ),
        child: child,
      );
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;
  final bool last;

  const _Toggle(this.label, this.value, this.onChanged,
      {this.subtitle, this.last = false});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFEDEFF2))),
        ),
        child: SwitchListTile(
          dense: true,
          title: Text(label, style: const TextStyle(fontSize: 14)),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A90A0))),
          value: value,
          activeColor: const Color(0xFF6C5CE7),
          onChanged: onChanged,
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF8A90A0),
          ),
        ),
      );
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: TextStyle(fontSize: 13, color: color)),
      );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_outlined,
                  size: 46, color: Color(0xFF8A90A0)),
              const SizedBox(height: 14),
              const Text(
                'Aucune séance pour le moment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              const Text(
                'Créez votre première séance en direct. Elle restera en brouillon tant que vous ne l\'aurez pas publiée.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Color(0xFF5C6270)),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7)),
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Créer une séance'),
              ),
            ],
          ),
        ),
      );
}
