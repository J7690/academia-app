import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/academia_session.dart';
import '../../providers/academia_session_provider.dart';
import '../../providers/orientation_provider.dart';
import '../live/academia_classroom_screen.dart';

/// Conseil d'orientation — un écran, deux points de vue.
///
/// L'élève cherche un conseiller et réserve un créneau. Le conseiller voit ses
/// rendez-vous, le dossier de l'élève avant l'entretien, et rédige la fiche.
///
/// L'orientation ne passe plus par le studio de cours : elle a son parcours
/// propre, et la séance qu'elle ouvre est en mode orientation — sans quiz,
/// sans tableau blanc, sans enregistrement par défaut.
class OrientationScreen extends StatefulWidget {
  const OrientationScreen({super.key});

  @override
  State<OrientationScreen> createState() => _OrientationScreenState();
}

class _OrientationScreenState extends State<OrientationScreen> {
  static const _accent = Color(0xFF6C5CE7);
  static const _red = Color(0xFFE14D4D);
  static const _teal = Color(0xFF12B886);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<OrientationProvider>();
      // Le profil d'abord : il détermine si l'on affiche l'espace conseiller
      // ou la recherche côté élève.
      await p.loadMyProfile();
      await p.loadMyBookings();
      if (!p.isCounselor) await p.searchCounselors();
    });
  }

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: error ? _red : null));
  }

  Future<void> _openBooking(Map<String, dynamic> counselor) async {
    final booked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrientationBookingSheet(counselor: counselor),
    );
    if (booked == true && mounted) {
      _toast('Rendez-vous confirmé. Vous le retrouverez ici et dans vos Lives.');
      await context.read<OrientationProvider>().loadMyBookings();
    }
  }

  Future<void> _joinSession(Map<String, dynamic> booking) async {
    final sessionId = booking['session_id']?.toString();
    if (sessionId == null || sessionId.isEmpty) {
      _toast('Cette consultation n\'a pas de salle associée.', error: true);
      return;
    }
    final sessions = context.read<AcademiaSessionProvider>();
    final session = await sessions.getSession(sessionId);
    if (!mounted) return;
    if (session == null) {
      _toast(sessions.error ?? 'Salle introuvable.', error: true);
      return;
    }
    final isCounselor = booking['je_suis_le_conseiller'] == true;
    if (isCounselor) {
      await sessions.startSession(sessionId);
    } else {
      await sessions.joinSession(sessionId);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AcademiaClassroomScreen(session: session, isHost: isCounselor),
      ),
    );
  }

  // ─── Rendu ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('Orientation'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<OrientationProvider>(
        builder: (context, p, _) {
          if (p.isLoading && p.bookings.isEmpty && p.counselors.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final aVenir = p.bookings
              .where((b) => b['status'] == 'confirmed' || b['status'] == 'pending')
              .toList();
          final passees = p.bookings.where((b) => b['status'] == 'done').toList();

          return RefreshIndicator(
            onRefresh: () async {
              await p.loadMyProfile();
              await p.loadMyBookings();
              if (!p.isCounselor) await p.searchCounselors();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  p.isCounselor
                      ? 'Vos consultations'
                      : 'Trouver un conseiller d\'orientation',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  p.isCounselor
                      ? 'Le dossier de chaque élève est chargé avant l\'entretien.'
                      : 'Un entretien personnalisé, et une fiche d\'orientation à '
                          'emporter à la fin.',
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF5C6270)),
                ),
                const SizedBox(height: 18),

                if (p.error != null) _Banner(text: p.error!, color: _red),

                // ─── Espace conseiller ───────────────────────────────
                if (p.isCounselor) ...[
                  if (!p.isBookable) _notBookableBanner(p),
                  _myProfileCard(p),
                  const SizedBox(height: 6),
                ],

                if (aVenir.isNotEmpty) ...[
                  const _Heading('Rendez-vous à venir'),
                  ...aVenir.map((b) => _bookingCard(b, aVenir: true)),
                  const SizedBox(height: 18),
                ] else if (p.isCounselor) ...[
                  const _Heading('Rendez-vous à venir'),
                  _Card(
                    child: Column(
                      children: [
                        const Icon(Icons.event_available_outlined,
                            size: 34, color: Color(0xFF8A90A0)),
                        const SizedBox(height: 10),
                        Text(
                          p.isBookable
                              ? 'Aucun rendez-vous pour l\'instant'
                              : 'Personne ne peut encore vous réserver',
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.isBookable
                              ? 'Les élèves qui réserveront un créneau apparaîtront ici, '
                                  'avec leur question et leur dossier.'
                              : 'Posez vos créneaux de disponibilité pour apparaître '
                                  'dans la recherche des élèves.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, height: 1.5, color: Color(0xFF5C6270)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                if (!p.isCounselor) ...[
                  const _Heading('Conseillers disponibles'),
                  if (p.counselors.isEmpty)
                    const _EmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'Aucun conseiller pour le moment',
                      body: 'Le service d\'orientation ouvrira prochainement. '
                          'Vous serez prévenu.',
                    )
                  else
                    ...p.counselors.map(_counselorCard),
                ],

                if (passees.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const _Heading('Consultations passées'),
                  ...passees.map((b) => _bookingCard(b, aVenir: false)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Espace conseiller ──────────────────────────────────────────────

  /// Un conseiller sans créneau n'existe pas pour les élèves. Le lui dire
  /// franchement vaut mieux que de le laisser attendre des rendez-vous qui
  /// ne viendront jamais.
  Widget _notBookableBanner(OrientationProvider p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0A020).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0A020).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.visibility_off_outlined,
                  size: 19, color: Color(0xFFB07510)),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Vous n\'apparaissez pas encore aux élèves',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7A5510)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Tant que vous n\'avez aucun créneau de disponibilité, personne ne '
            'peut vous réserver.',
            style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF7A5510)),
          ),
          const SizedBox(height: 11),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB07510)),
            onPressed: _openAvailability,
            icon: const Icon(Icons.schedule, size: 17),
            label: const Text('Poser mes créneaux'),
          ),
        ],
      ),
    );
  }

  Widget _myProfileCard(OrientationProvider p) {
    final profile = p.myProfile;
    if (profile == null) return const SizedBox.shrink();

    final specialites = (profile['specialites'] as List?)?.cast<String>() ?? const [];
    final langues = (profile['langues'] as List?)?.cast<String>() ?? const [];
    final tarif = (profile['tarif_fcfa'] as num?)?.toInt() ?? 0;
    final gaps = p.profileGaps;

    return _Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: _accent.withValues(alpha: 0.15),
                child: Text(
                  (profile['full_name']?.toString() ?? '?')
                      .characters.take(1).toString().toUpperCase(),
                  style: const TextStyle(
                      color: _accent, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile['full_name']?.toString() ?? 'Conseiller',
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      [
                        _kindLabel(profile['kind']?.toString()),
                        '${profile['duree_minutes'] ?? 45} min',
                        tarif == 0 ? 'Gratuit' : '$tarif FCFA',
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF5C6270)),
                    ),
                  ],
                ),
              ),
              if (p.isBookable)
                const _Pill(text: 'Visible', color: _teal)
              else
                const _Pill(text: 'Masqué', color: Color(0xFFF0A020)),
            ],
          ),
          if (specialites.isNotEmpty) ...[
            const SizedBox(height: 11),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: specialites
                  .map((s) => _Pill(text: _specialityLabel(s), color: _accent))
                  .toList(),
            ),
          ],
          if (langues.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Langues : ${langues.join(', ')}',
                style: const TextStyle(
                    fontSize: 12.5, color: Color(0xFF8A90A0))),
          ],
          if (p.myAvailability.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_availabilitySummary(p.myAvailability),
                style: const TextStyle(
                    fontSize: 12.5, height: 1.5, color: Color(0xFF5C6270))),
          ],
          if (gaps.isNotEmpty) ...[
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('À compléter',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8A90A0))),
                  const SizedBox(height: 5),
                  ...gaps.map((g) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('· $g',
                            style: const TextStyle(
                                fontSize: 12.5, color: Color(0xFF5C6270))),
                      )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 13),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _openProfileEditor,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Mon profil'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _openAvailability,
                icon: const Icon(Icons.schedule, size: 17),
                label: const Text('Mes créneaux'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _availabilitySummary(List<Map<String, dynamic>> slots) {
    const jours = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
    final parJour = <int, List<String>>{};
    for (final s in slots) {
      final d = (s['weekday'] as num?)?.toInt() ?? 0;
      final debut = s['start_time'].toString().substring(0, 5);
      final fin = s['end_time'].toString().substring(0, 5);
      parJour.putIfAbsent(d, () => []).add('$debut-$fin');
    }
    final parts = parJour.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return parts
        .map((e) => '${jours[e.key]} ${e.value.join(', ')}')
        .join(' · ');
  }

  Future<void> _openProfileEditor() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProfileEditorSheet(),
    );
    if (saved == true && mounted) _toast('Profil mis à jour.');
  }

  Future<void> _openAvailability() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AvailabilitySheet(),
    );
    if (saved == true && mounted) {
      _toast('Créneaux enregistrés. Vous êtes maintenant réservable.');
    }
  }

  Widget _counselorCard(Map<String, dynamic> c) {
    final specialites = (c['specialites'] as List?)?.cast<String>() ?? const [];
    final langues = (c['langues'] as List?)?.cast<String>() ?? const [];
    final note = c['note_moyenne'];
    final tarif = (c['tarif_fcfa'] as num?)?.toInt() ?? 0;

    return _Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _accent.withValues(alpha: 0.15),
                child: Text(
                  (c['full_name']?.toString() ?? '?')
                      .characters
                      .take(1)
                      .toString()
                      .toUpperCase(),
                  style: const TextStyle(
                      color: _accent, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['full_name']?.toString() ?? 'Conseiller',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      [
                        _kindLabel(c['kind']?.toString()),
                        if (langues.isNotEmpty) langues.join(', '),
                        '${c['duree_minutes'] ?? 45} min',
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF5C6270)),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.star, size: 14, color: Color(0xFFF0A020)),
                        const SizedBox(width: 4),
                        Text('$note · ${c['consultations'] ?? 0} consultations',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF8A90A0))),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (c['bio'] != null && c['bio'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(c['bio'].toString(),
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: Color(0xFF5C6270))),
          ],
          if (specialites.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: specialites
                  .map((s) => _Pill(text: _specialityLabel(s), color: _accent))
                  .toList(),
            ),
          ],
          const SizedBox(height: 13),
          Row(
            children: [
              Text(
                tarif == 0 ? 'Gratuit' : '$tarif FCFA',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: tarif == 0 ? _teal : const Color(0xFF14161A)),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _accent),
                onPressed: () => _openBooking(c),
                icon: const Icon(Icons.event_available, size: 17),
                label: const Text('Prendre rendez-vous'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> b, {required bool aVenir}) {
    final quand = DateTime.tryParse('${b['scheduled_at']}')?.toLocal();
    final estConseiller = b['je_suis_le_conseiller'] == true;
    final autre = estConseiller
        ? (b['student_name']?.toString() ?? 'Élève')
        : (b['counselor_name']?.toString() ?? 'Conseiller');
    final imminent = quand != null &&
        quand.difference(DateTime.now()).inMinutes.abs() <= 15;

    return _Card(
      margin: const EdgeInsets.only(bottom: 10),
      border: imminent ? _teal.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(
                  text: estConseiller ? 'Vous conseillez' : 'Consultation',
                  color: _accent),
              if (imminent) ...[
                const SizedBox(width: 6),
                const _Pill(text: 'C\'est maintenant', color: _teal),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(autre,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (quand != null) ...[
            const SizedBox(height: 3),
            Text(_formatDate(quand),
                style: const TextStyle(
                    fontSize: 12.5, color: Color(0xFF5C6270))),
          ],
          if (b['motif'] != null && b['motif'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(b['motif'].toString(),
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.45, color: Color(0xFF5C6270))),
            ),
          ],
          if (aVenir) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: imminent ? _teal : _accent),
                  onPressed: () => _joinSession(b),
                  icon: const Icon(Icons.videocam, size: 17),
                  label: Text(estConseiller ? 'Démarrer' : 'Rejoindre'),
                ),
                if (estConseiller) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _openRecord(b),
                    child: Text(
                        b['fiche_existe'] == true ? 'La fiche' : 'Créer la fiche'),
                  ),
                ],
              ],
            ),
          ] else if (b['fiche_existe'] == true) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openRecord(b),
              icon: const Icon(Icons.description_outlined, size: 17),
              label: const Text('Fiche d\'orientation'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openRecord(Map<String, dynamic> booking) async {
    final p = context.read<OrientationProvider>();
    final id = booking['id'].toString();
    await Future.wait([p.loadRecord(id), p.loadStudentFile(id)]);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordSheet(
        bookingId: id,
        canEdit: booking['je_suis_le_conseiller'] == true,
      ),
    );
  }

  static String _kindLabel(String? k) => switch (k) {
        'orientation' => 'Orientation scolaire',
        'career' => 'Orientation professionnelle',
        'etudes_etranger' => 'Études à l\'étranger',
        'reconversion' => 'Reconversion',
        'psychologue' => 'Psychologue scolaire',
        _ => 'Conseiller',
      };

  static String _specialityLabel(String s) =>
      s.replaceAll('_', ' ').replaceFirstMapped(
          RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());

  static String _formatDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    const mois = [
      'janv.', 'févr.', 'mars', 'avril', 'mai', 'juin',
      'juill.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    return '${d.day} ${mois[d.month - 1]} à ${two(d.hour)}h${two(d.minute)}';
  }
}

// ─── Feuille de réservation ───────────────────────────────────────────

/// Feuille de réservation d'un créneau. Publique : réutilisée par
/// l'onglet Orientation étudiant.
class OrientationBookingSheet extends StatefulWidget {
  final Map<String, dynamic> counselor;
  const OrientationBookingSheet({super.key, required this.counselor});

  @override
  State<OrientationBookingSheet> createState() => _OrientationBookingSheetState();
}

class _OrientationBookingSheetState extends State<OrientationBookingSheet> {
  final _motifCtrl = TextEditingController();
  DateTime? _selected;
  bool _accepteEnregistrement = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<OrientationProvider>()
          .loadSlots(widget.counselor['user_id'].toString());
    });
  }

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_selected == null) return;
    final p = context.read<OrientationProvider>();
    final sessionId = await p.book(
      counselorId: widget.counselor['user_id'].toString(),
      slot: _selected!,
      motif: _motifCtrl.text.trim().isEmpty ? null : _motifCtrl.text.trim(),
      consentRecording: _accepteEnregistrement,
    );
    if (!mounted) return;
    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(p.error ?? 'Réservation impossible.'),
          backgroundColor: const Color(0xFFE14D4D),
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrientationProvider>();
    final parJour = <String, List<DateTime>>{};
    for (final s in p.slots) {
      final local = s.toLocal();
      final key = '${local.year}-${local.month}-${local.day}';
      parJour.putIfAbsent(key, () => []).add(local);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Choisir un créneau',
                            style: TextStyle(
                                fontSize: 16.5, fontWeight: FontWeight.w600)),
                        Text(
                          '${widget.counselor['full_name']} · ${p.slotDuration} min',
                          style: const TextStyle(
                              fontSize: 12.5, color: Color(0xFF5C6270)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: p.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : parJour.isEmpty
                      ? const _EmptyState(
                          icon: Icons.event_busy_outlined,
                          title: 'Aucun créneau disponible',
                          body: 'Ce conseiller n\'a pas de disponibilité sur '
                              'les deux prochaines semaines.',
                        )
                      : ListView(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            ...parJour.entries.map((e) {
                              final jour = e.value.first;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Heading(_jourLabel(jour)),
                                  Wrap(
                                    spacing: 7,
                                    runSpacing: 7,
                                    children: e.value.map((s) {
                                      final sel = _selected == s;
                                      return ChoiceChip(
                                        label: Text(
                                            '${s.hour.toString().padLeft(2, '0')}h'
                                            '${s.minute.toString().padLeft(2, '0')}'),
                                        selected: sel,
                                        onSelected: (_) =>
                                            setState(() => _selected = s),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                              );
                            }),
                            const _Heading('Votre question'),
                            _Card(
                              child: TextField(
                                controller: _motifCtrl,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText:
                                      'Décrivez ce qui vous préoccupe. Le conseiller '
                                      'préparera l\'entretien à partir de cela.',
                                  hintStyle: TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Accord préalable à l'enregistrement. Coupé par
                            // défaut : l'entretien reste privé tant que
                            // l'élève n'a rien accordé, et le conseiller doit
                            // de toute façon donner le sien.
                            CheckboxListTile(
                              value: _accepteEnregistrement,
                              onChanged: (v) => setState(
                                  () => _accepteEnregistrement = v ?? false),
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              activeColor: const Color(0xFF6C5CE7),
                              title: const Text(
                                'J\'accepte que l\'entretien soit enregistré',
                                style: TextStyle(fontSize: 13),
                              ),
                              subtitle: const Text(
                                'Pour pouvoir le réécouter. L\'enregistrement '
                                'ne démarrera que si le conseiller donne aussi '
                                'son accord, et un bandeau restera visible '
                                'pendant tout l\'entretien.',
                                style: TextStyle(fontSize: 11.5, height: 1.4),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF6C5CE7),
                                minimumSize: const Size.fromHeight(48),
                              ),
                              onPressed: (_selected == null || p.isBooking)
                                  ? null
                                  : _confirm,
                              child: p.isBooking
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text('Confirmer le rendez-vous'),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _accepteEnregistrement
                                  ? 'La consultation reste privée : seuls vous '
                                      'et le conseiller y avez accès.'
                                  : 'La consultation est privée et ne sera pas '
                                      'enregistrée.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF8A90A0)),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  static String _jourLabel(DateTime d) {
    const jours = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
    ];
    const mois = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return '${jours[d.weekday - 1]} ${d.day} ${mois[d.month - 1]}';
  }
}

// ─── Feuille de la fiche d'orientation ────────────────────────────────

class _RecordSheet extends StatelessWidget {
  final String bookingId;
  final bool canEdit;
  const _RecordSheet({required this.bookingId, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrientationProvider>();
    final record = p.record;
    final file = p.studentFile;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Fiche d\'orientation',
                      style: TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (canEdit && file != null) ...[
              const _Heading('Dossier de l\'élève'),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(file['nom']?.toString() ?? 'Élève',
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
                    if (file['motif'] != null) ...[
                      const SizedBox(height: 8),
                      Text('Sa question : ${file['motif']}',
                          style: const TextStyle(
                              fontSize: 13, height: 1.5)),
                    ],
                    if (file['profil_psychotechnique'] != null) ...[
                      const SizedBox(height: 10),
                      const _Pill(
                          text: 'Test psychotechnique passé',
                          color: Color(0xFF12B886)),
                    ],
                  ],
                ),
              ),
            ],
            const _Heading('Contenu'),
            if (record == null)
              _EmptyState(
                icon: Icons.description_outlined,
                title: canEdit
                    ? 'Fiche non commencée'
                    : 'Fiche en cours de rédaction',
                body: canEdit
                    ? 'Rédigez la fiche pendant ou après l\'entretien, puis '
                        'partagez-la avec l\'élève et sa famille.'
                    : 'Votre conseiller la partagera dès qu\'elle sera prête.',
              )
            else
              _Card(
                child: Text(
                  const JsonPreview().format(record['content']),
                  style: const TextStyle(fontSize: 13, height: 1.55),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rendu lisible d'une fiche encore libre de structure.
///
/// La fiche est stockée en JSON pour rester souple pendant la phase de
/// rodage : chaque conseiller n'a pas les mêmes rubriques. Une mise en page
/// figée viendra quand le format se sera stabilisé à l'usage.
class JsonPreview {
  const JsonPreview();

  String format(dynamic content) {
    if (content is! Map) return 'Aucun contenu.';
    final buffer = StringBuffer();
    content.forEach((key, value) {
      final label = key.toString().replaceAll('_', ' ');
      buffer.writeln(label.toUpperCase());
      if (value is List) {
        for (final item in value) {
          buffer.writeln('  · ${item is Map ? item.values.join(' — ') : item}');
        }
      } else {
        buffer.writeln('  $value');
      }
      buffer.writeln();
    });
    return buffer.toString().trim();
  }
}

// ─── Composants ───────────────────────────────────────────────────────

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8A90A0))),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;
  final Color? border;
  const _Card({required this.child, this.margin, this.border});

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border ?? const Color(0xFFE2E5EA)),
        ),
        child: child,
      );
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
  final IconData icon;
  final String title;
  final String body;
  const _EmptyState(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, size: 40, color: const Color(0xFF8A90A0)),
            const SizedBox(height: 13),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: Color(0xFF5C6270))),
          ],
        ),
      );
}

// ─── Édition du profil par le conseiller lui-même ─────────────────────

/// L'administrateur pose le minimum à la création ; le conseiller affine
/// ensuite depuis son compte, comme le fait un commercial ou un marchand.
class _ProfileEditorSheet extends StatefulWidget {
  const _ProfileEditorSheet();

  @override
  State<_ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends State<_ProfileEditorSheet> {
  late final TextEditingController _nameC;
  late final TextEditingController _bioC;
  late final TextEditingController _tarifC;
  late String _kind;
  late int _duree;
  late Set<String> _specialites;
  late Set<String> _langues;

  static const _kinds = <String, String>{
    'orientation': 'Orientation scolaire',
    'career': 'Orientation professionnelle',
    'etudes_etranger': 'Études à l\'étranger',
    'reconversion': 'Reconversion',
    'psychologue': 'Psychologue scolaire',
  };

  static const _specialiteOptions = <String, String>{
    'filieres_scientifiques': 'Filières scientifiques',
    'filieres_litteraires': 'Filières littéraires',
    'concours_fonction_publique': 'Concours fonction publique',
    'etudes_superieures': 'Études supérieures',
    'ecoles_professionnelles': 'Écoles professionnelles',
    'bourses': 'Bourses',
  };

  static const _langueOptions = <String, String>{
    'fr': 'Français',
    'moore': 'Mooré',
    'dioula': 'Dioula',
    'fulfulde': 'Fulfuldé',
    'en': 'Anglais',
  };

  @override
  void initState() {
    super.initState();
    final p = context.read<OrientationProvider>().myProfile ?? const {};
    _nameC = TextEditingController(text: p['full_name']?.toString() ?? '');
    _bioC = TextEditingController(text: p['bio']?.toString() ?? '');
    _tarifC = TextEditingController(text: '${p['tarif_fcfa'] ?? 0}');
    _kind = p['kind']?.toString() ?? 'orientation';
    _duree = (p['duree_minutes'] as num?)?.toInt() ?? 45;
    _specialites = ((p['specialites'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    _langues = ((p['langues'] as List?) ?? const ['fr'])
        .map((e) => e.toString())
        .toSet();
    if (_langues.isEmpty) _langues.add('fr');
  }

  @override
  void dispose() {
    _nameC.dispose();
    _bioC.dispose();
    _tarifC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = context.read<OrientationProvider>();
    final error = await p.updateMyProfile(
      fullName: _nameC.text.trim(),
      kind: _kind,
      specialites: _specialites.toList(),
      langues: _langues.toList(),
      bio: _bioC.text.trim(),
      tarifFcfa: int.tryParse(_tarifC.text.trim()) ?? 0,
      dureeMinutes: _duree,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: const Color(0xFFE14D4D)),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<OrientationProvider>().isBooking;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Mon profil de conseiller',
                        style: TextStyle(
                            fontSize: 16.5, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                children: [
                  const Text(
                    'Ces informations sont celles que les élèves voient avant '
                    'de vous choisir.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF8A90A0)),
                  ),
                  const _Heading('Nom affiché'),
                  _Card(
                    child: TextField(
                      controller: _nameC,
                      decoration: const InputDecoration(
                          border: InputBorder.none, hintText: 'Votre nom'),
                    ),
                  ),
                  const _Heading('Type de conseil'),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: _kinds.entries
                        .map((e) => ChoiceChip(
                              label: Text(e.value,
                                  style: const TextStyle(fontSize: 12)),
                              selected: _kind == e.key,
                              onSelected: (_) => setState(() => _kind = e.key),
                            ))
                        .toList(),
                  ),
                  const _Heading('Spécialités'),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: _specialiteOptions.entries
                        .map((e) => FilterChip(
                              label: Text(e.value,
                                  style: const TextStyle(fontSize: 12)),
                              selected: _specialites.contains(e.key),
                              onSelected: (v) => setState(() => v
                                  ? _specialites.add(e.key)
                                  : _specialites.remove(e.key)),
                            ))
                        .toList(),
                  ),
                  const _Heading('Langues parlées'),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: _langueOptions.entries
                        .map((e) => FilterChip(
                              label: Text(e.value,
                                  style: const TextStyle(fontSize: 12)),
                              selected: _langues.contains(e.key),
                              onSelected: (v) => setState(() {
                                v ? _langues.add(e.key) : _langues.remove(e.key);
                                if (_langues.isEmpty) _langues.add('fr');
                              }),
                            ))
                        .toList(),
                  ),
                  const _Heading('Présentation'),
                  _Card(
                    child: TextField(
                      controller: _bioC,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText:
                            'Votre parcours, votre façon d\'accompagner. '
                            'C\'est ce qui décide un élève à vous choisir.',
                        hintStyle: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const _Heading('Tarif et durée'),
                  Row(
                    children: [
                      Expanded(
                        child: _Card(
                          child: TextField(
                            controller: _tarifC,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                border: InputBorder.none,
                                labelText: 'FCFA (0 = gratuit)'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Card(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: _duree,
                              items: const [30, 45, 60, 90]
                                  .map((m) => DropdownMenuItem(
                                      value: m, child: Text('$m minutes')))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _duree = v ?? 45),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: busy ? null : _save,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Enregistrer'),
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

// ─── Agenda hebdomadaire du conseiller ────────────────────────────────

/// Le conseiller déclare ses plages une fois ; elles se répètent chaque
/// semaine. La base les découpe ensuite en créneaux de sa durée et retire ce
/// qui est déjà réservé — aucun calcul ici.
class _AvailabilitySheet extends StatefulWidget {
  const _AvailabilitySheet();

  @override
  State<_AvailabilitySheet> createState() => _AvailabilitySheetState();
}

class _AvailabilitySheetState extends State<_AvailabilitySheet> {
  static const _jours = [
    'Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'
  ];

  // weekday -> liste de {start, end}
  final Map<int, List<_Plage>> _plages = {};

  @override
  void initState() {
    super.initState();
    for (final s in context.read<OrientationProvider>().myAvailability) {
      final d = (s['weekday'] as num?)?.toInt() ?? 0;
      _plages.putIfAbsent(d, () => []).add(_Plage(
            start: s['start_time'].toString().substring(0, 5),
            end: s['end_time'].toString().substring(0, 5),
          ));
    }
  }

  int get _total => _plages.values.fold(0, (a, b) => a + b.length);

  Future<void> _addPlage(int weekday) async {
    final debut = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Début de la plage',
    );
    if (debut == null || !mounted) return;
    final fin = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (debut.hour + 3).clamp(0, 23), minute: 0),
      helpText: 'Fin de la plage',
    );
    if (fin == null) return;

    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    if (fmt(fin).compareTo(fmt(debut)) <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('L\'heure de fin doit suivre l\'heure de début.')));
      return;
    }
    setState(() => _plages
        .putIfAbsent(weekday, () => [])
        .add(_Plage(start: fmt(debut), end: fmt(fin))));
  }

  /// Reprend les plages du premier jour renseigné sur tous les jours de
  /// semaine. Poser sept fois le même horaire à la main est fastidieux.
  void _dupliquerEnSemaine() {
    List<_Plage>? modele;
    for (final entry in _plages.entries) {
      if (entry.value.isNotEmpty) {
        modele = entry.value;
        break;
      }
    }
    if (modele == null) return;
    final copie = modele;
    setState(() {
      for (var d = 1; d <= 5; d++) {
        _plages[d] =
            copie.map((p) => _Plage(start: p.start, end: p.end)).toList();
      }
    });
  }

  Future<void> _save() async {
    final provider = context.read<OrientationProvider>();
    final slots = <Map<String, dynamic>>[];
    _plages.forEach((weekday, list) {
      for (final p in list) {
        slots.add({
          'weekday': weekday,
          'start_time': p.start,
          'end_time': p.end,
        });
      }
    });

    final error = await provider.setMyAvailability(slots);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: const Color(0xFFE14D4D)),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<OrientationProvider>().isBooking;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mes créneaux',
                            style: TextStyle(
                                fontSize: 16.5, fontWeight: FontWeight.w600)),
                        Text('$_total plage(s) par semaine',
                            style: const TextStyle(
                                fontSize: 12.5, color: Color(0xFF5C6270))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                children: [
                  const Text(
                    'Déclarez vos plages une fois : elles se répètent chaque '
                    'semaine. Elles seront découpées automatiquement selon la '
                    'durée de vos consultations.',
                    style: TextStyle(
                        fontSize: 12.5, height: 1.5, color: Color(0xFF8A90A0)),
                  ),
                  if (_total > 0) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _dupliquerEnSemaine,
                        icon: const Icon(Icons.copy_all_outlined, size: 17),
                        label: const Text('Appliquer du lundi au vendredi'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  ...List.generate(7, (i) {
                    final jour = (i + 1) % 7; // commence au lundi
                    final list = _plages[jour] ?? const <_Plage>[];
                    return _Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(_jours[jour],
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.add_circle_outline,
                                    size: 21, color: Color(0xFF6C5CE7)),
                                onPressed: () => _addPlage(jour),
                              ),
                            ],
                          ),
                          if (list.isEmpty)
                            const Text('Indisponible',
                                style: TextStyle(
                                    fontSize: 12.5, color: Color(0xFF8A90A0)))
                          else
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: list
                                  .map((p) => Chip(
                                        label: Text('${p.start} – ${p.end}',
                                            style:
                                                const TextStyle(fontSize: 12)),
                                        onDeleted: () => setState(
                                            () => _plages[jour]!.remove(p)),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: busy ? null : _save,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_total == 0
                            ? 'Enregistrer (aucune disponibilité)'
                            : 'Enregistrer mes créneaux'),
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

class _Plage {
  final String start;
  final String end;
  _Plage({required this.start, required this.end});
}
