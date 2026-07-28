import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/academia_session.dart';
import '../../providers/academia_session_provider.dart';
import '../../providers/orientation_provider.dart';
import '../live/academia_classroom_screen.dart';
import '../student/student_settings_screen.dart';
import 'counselor_sessions_tab.dart';
import 'counselor_sheets.dart';
import 'orientation_theme.dart';

/// Tableau de bord du conseiller d'orientation.
///
/// Construit sur le même patron que le tableau de bord enseignant — barre
/// d'onglets défilante, accès aux réglages, onglet Revenus branché sur le
/// circuit de paiement existant — mais avec les outils du métier :
/// agenda de consultations, dossiers d'élèves, fiches d'orientation.
///
/// **Adaptativité**
///
/// Aucune largeur n'est figée. Chaque contenu s'appuie sur [LayoutBuilder] ou
/// [Wrap], les feuilles de dialogue sont défilantes, et les textes longs sont
/// tronqués plutôt que de déborder. L'écran a été pensé pour tenir aussi bien
/// sur un téléphone de 320 points de large que sur une tablette.
class CounselorDashboardScreen extends StatefulWidget {
  const CounselorDashboardScreen({super.key});

  @override
  State<CounselorDashboardScreen> createState() =>
      _CounselorDashboardScreenState();
}

class _CounselorDashboardScreenState extends State<CounselorDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final p = context.read<OrientationProvider>();
    await p.loadMyProfile();
    await p.loadMyBookings();
    await p.loadCounselorWorkspace();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: OrientationTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          titleSpacing: 16,
          title: Consumer<OrientationProvider>(
            builder: (context, p, _) {
              final nom = p.myProfile?['full_name']?.toString() ?? 'Conseiller';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Orientation',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  Text(
                    nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, color: OrientationTheme.textMuted),
                  ),
                ],
              );
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh, color: OrientationTheme.text),
              onPressed: _reload,
            ),
            IconButton(
              tooltip: 'Réglages',
              icon: const Icon(Icons.settings_outlined,
                  color: OrientationTheme.text),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StudentSettingsScreen(),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: OrientationTheme.accent,
            unselectedLabelColor: OrientationTheme.textMuted,
            indicatorColor: OrientationTheme.accent,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Accueil'),
              Tab(icon: Icon(Icons.event_note_outlined, size: 18), text: 'Consultations'),
              Tab(icon: Icon(Icons.video_call_outlined, size: 18), text: 'Mes séances'),
              Tab(icon: Icon(Icons.schedule, size: 18), text: 'Mes créneaux'),
              Tab(icon: Icon(Icons.description_outlined, size: 18), text: 'Fiches'),
              Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 18), text: 'Revenus'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CounselorHomeTab(),
            _CounselorBookingsTab(),
            CounselorSessionsTab(),
            _CounselorAvailabilityTab(),
            _CounselorRecordsTab(),
            _CounselorRevenueTab(),
          ],
        ),
      ),
    );
  }
}

// ═══ Accueil ═══════════════════════════════════════════════════════════

class _CounselorHomeTab extends StatelessWidget {
  const _CounselorHomeTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<OrientationProvider>(
      builder: (context, p, _) {
        final profile = p.myProfile;
        if (profile == null && p.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final prochains = p.bookings.where((b) {
          final d = DateTime.tryParse('${b['scheduled_at']}');
          return (b['status'] == 'confirmed' || b['status'] == 'pending') &&
              d != null &&
              d.isAfter(DateTime.now().subtract(const Duration(hours: 1)));
        }).toList()
          ..sort((a, b) => '${a['scheduled_at']}'.compareTo('${b['scheduled_at']}'));

        return RefreshIndicator(
          onRefresh: () async {
            await p.loadMyProfile();
            await p.loadMyBookings();
            await p.loadCounselorWorkspace();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (!p.isBookable) const _NotBookableBanner(),
              _StatsGrid(stats: p.stats),
              const SizedBox(height: 20),
              const _SectionTitle('Prochaine consultation'),
              if (prochains.isEmpty)
                const _EmptyBlock(
                  icon: Icons.event_available_outlined,
                  title: 'Rien de prévu',
                  body: 'Les élèves qui réservent un créneau apparaissent ici, '
                      'avec leur question et leur dossier.',
                )
              else
                _BookingCard(
                  booking: prochains.first,
                  onChanged: () async {
                    await p.loadMyBookings();
                    await p.loadCounselorWorkspace();
                  },
                ),
              const SizedBox(height: 20),
              const _SectionTitle('Mon profil'),
              const _ProfileSummaryCard(),
            ],
          ),
        );
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsGrid({required this.stats});

  int _v(String k) {
    final x = stats[k];
    return x is int ? x : int.tryParse('${x ?? 0}') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final cards = <(String, int, IconData, Color)>[
      ("Aujourd'hui", _v('aujourdhui'), Icons.today_outlined, OrientationTheme.teal),
      ('À venir', _v('a_venir'), Icons.event_outlined, OrientationTheme.accent),
      ('Terminées', _v('terminees'), Icons.check_circle_outline, OrientationTheme.textMuted),
      ('Fiches à écrire', _v('fiches_a_rediger'), Icons.edit_note, OrientationTheme.amber),
    ];

    // Deux colonnes sur téléphone, quatre dès qu'il y a la place. Le calcul
    // dépend de la largeur réelle, pas d'un seuil d'appareil.
    return LayoutBuilder(
      builder: (context, constraints) {
        final colonnes = constraints.maxWidth >= 560 ? 4 : 2;
        const espace = 10.0;
        final largeur =
            (constraints.maxWidth - espace * (colonnes - 1)) / colonnes;
        return Wrap(
          spacing: espace,
          runSpacing: espace,
          children: cards.map((c) {
            final (label, valeur, icone, couleur) = c;
            return SizedBox(
              width: largeur,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                decoration: OrientationTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icone, size: 19, color: couleur),
                    const SizedBox(height: 8),
                    Text('$valeur',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: couleur)),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          color: OrientationTheme.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _NotBookableBanner extends StatelessWidget {
  const _NotBookableBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OrientationTheme.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrientationTheme.amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.visibility_off_outlined,
                  size: 19, color: OrientationTheme.amberDark),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Vous n\'apparaissez pas encore aux élèves',
                  style: OrientationTheme.warningTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Tant que vous n\'avez posé aucun créneau, personne ne peut vous '
            'réserver. Rendez-vous dans l\'onglet « Mes créneaux ».',
            style: OrientationTheme.warningBody,
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrientationProvider>();
    final profile = p.myProfile;
    if (profile == null) {
      return const _EmptyBlock(
        icon: Icons.person_outline,
        title: 'Profil indisponible',
        body: 'Rechargez la page.',
      );
    }

    final specialites =
        (profile['specialites'] as List?)?.cast<String>() ?? const [];
    final langues = (profile['langues'] as List?)?.cast<String>() ?? const [];
    final tarif = (profile['tarif_fcfa'] as num?)?.toInt() ?? 0;
    final gaps = p.profileGaps;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OrientationTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: OrientationTheme.accent.withValues(alpha: 0.15),
                child: Text(
                  (profile['full_name']?.toString() ?? '?')
                      .characters
                      .take(1)
                      .toString()
                      .toUpperCase(),
                  style: const TextStyle(
                      color: OrientationTheme.accent,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile['full_name']?.toString() ?? 'Conseiller',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        OrientationLabels.kind(profile['kind']?.toString()),
                        '${profile['duree_minutes'] ?? 45} min',
                        tarif == 0 ? 'Gratuit' : '$tarif FCFA',
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: OrientationTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Pill(
                text: p.isBookable ? 'Visible' : 'Masqué',
                color: p.isBookable
                    ? OrientationTheme.teal
                    : OrientationTheme.amber,
              ),
            ],
          ),
          if (specialites.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: specialites
                  .map((s) => _Pill(
                      text: OrientationLabels.speciality(s),
                      color: OrientationTheme.accent))
                  .toList(),
            ),
          ],
          if (langues.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              'Langues : ${langues.map(OrientationLabels.langue).join(', ')}',
              style: const TextStyle(
                  fontSize: 12.5, color: OrientationTheme.textMuted),
            ),
          ],
          if (gaps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: OrientationTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('À compléter',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: OrientationTheme.textMuted)),
                  const SizedBox(height: 5),
                  ...gaps.map((g) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('· $g',
                            style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: OrientationTheme.textSecondary)),
                      )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const CounselorProfileSheet(),
              ),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Modifier mon profil'),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══ Consultations ═════════════════════════════════════════════════════

class _CounselorBookingsTab extends StatelessWidget {
  const _CounselorBookingsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<OrientationProvider>(
      builder: (context, p, _) {
        final aVenir = p.bookings
            .where((b) => b['status'] == 'confirmed' || b['status'] == 'pending')
            .toList()
          ..sort((a, b) =>
              '${a['scheduled_at']}'.compareTo('${b['scheduled_at']}'));
        final passees = p.bookings
            .where((b) => b['status'] == 'done' || b['status'] == 'cancelled')
            .toList()
          ..sort((a, b) =>
              '${b['scheduled_at']}'.compareTo('${a['scheduled_at']}'));

        Future<void> recharger() async {
          await p.loadMyBookings();
          await p.loadCounselorWorkspace();
        }

        return RefreshIndicator(
          onRefresh: recharger,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (aVenir.isEmpty && passees.isEmpty)
                const _EmptyBlock(
                  icon: Icons.event_note_outlined,
                  title: 'Aucune consultation',
                  body: 'Dès qu\'un élève réservera un créneau, vous le '
                      'retrouverez ici avec son dossier.',
                ),
              if (aVenir.isNotEmpty) ...[
                const _SectionTitle('À venir'),
                ...aVenir.map((b) =>
                    _BookingCard(booking: b, onChanged: recharger)),
                const SizedBox(height: 18),
              ],
              if (passees.isNotEmpty) ...[
                const _SectionTitle('Historique'),
                ...passees.map((b) =>
                    _BookingCard(booking: b, onChanged: recharger, passee: true)),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Carte d'une consultation, côté conseiller.
///
/// Elle porte tout ce qui se fait autour d'un rendez-vous : ouvrir la salle du
/// Studio, consulter le dossier de l'élève, rédiger la fiche, clôturer.
class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Future<void> Function() onChanged;
  final bool passee;

  const _BookingCard({
    required this.booking,
    required this.onChanged,
    this.passee = false,
  });

  @override
  Widget build(BuildContext context) {
    final quand = DateTime.tryParse('${booking['scheduled_at']}')?.toLocal();
    final eleve = booking['student_name']?.toString() ?? 'Élève';
    final motif = booking['motif']?.toString() ?? '';
    final ficheExiste = booking['fiche_existe'] == true;
    final imminent = quand != null &&
        !passee &&
        quand.difference(DateTime.now()).inMinutes.abs() <= 20;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: OrientationTheme.cardDecoration.copyWith(
        border: Border.all(
          color: imminent
              ? OrientationTheme.teal.withValues(alpha: 0.5)
              : OrientationTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (imminent)
                const _Pill(text: 'C\'est maintenant', color: OrientationTheme.teal),
              if (passee)
                _Pill(
                  text: booking['status'] == 'done' ? 'Terminée' : 'Annulée',
                  color: OrientationTheme.textMuted,
                ),
              if (ficheExiste)
                const _Pill(text: 'Fiche rédigée', color: OrientationTheme.accent),
            ],
          ),
          if (imminent || passee || ficheExiste) const SizedBox(height: 8),
          Text(
            eleve,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
          ),
          if (quand != null) ...[
            const SizedBox(height: 3),
            Text(
              '${OrientationLabels.dateComplete(quand)} · ${booking['duree_minutes'] ?? 45} min',
              style: const TextStyle(
                  fontSize: 12.5, color: OrientationTheme.textSecondary),
            ),
          ],
          if (motif.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: OrientationTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SA QUESTION',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600,
                          color: OrientationTheme.textMuted)),
                  const SizedBox(height: 4),
                  Text(motif,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: OrientationTheme.textSecondary)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 13),
          // Wrap plutôt que Row : quatre boutons ne tiennent pas sur une seule
          // ligne en 320 points de large.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!passee)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: imminent
                        ? OrientationTheme.teal
                        : OrientationTheme.accent,
                  ),
                  onPressed: () => _ouvrirStudio(context),
                  icon: const Icon(Icons.videocam, size: 17),
                  label: const Text('Ouvrir la salle'),
                ),
              OutlinedButton.icon(
                onPressed: () => _ouvrirDossier(context),
                icon: const Icon(Icons.folder_shared_outlined, size: 17),
                label: const Text('Dossier'),
              ),
              OutlinedButton.icon(
                onPressed: () => _ouvrirFiche(context),
                icon: const Icon(Icons.description_outlined, size: 17),
                label: Text(ficheExiste ? 'La fiche' : 'Rédiger la fiche'),
              ),
              if (!passee)
                TextButton(
                  onPressed: () => _cloturer(context),
                  child: const Text('Clôturer'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _ouvrirStudio(BuildContext context) async {
    final sessionId = booking['session_id']?.toString();
    final messenger = ScaffoldMessenger.of(context);
    if (sessionId == null || sessionId.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Cette consultation n\'a pas de salle associée.')));
      return;
    }
    final sessions = context.read<AcademiaSessionProvider>();
    final session = await sessions.getSession(sessionId);
    if (!context.mounted) return;
    if (session == null) {
      messenger.showSnackBar(
          SnackBar(content: Text(sessions.error ?? 'Salle introuvable.')));
      return;
    }
    await sessions.startSession(sessionId);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AcademiaClassroomScreen(session: session, isHost: true),
      ),
    );
    await onChanged();
  }

  Future<void> _ouvrirDossier(BuildContext context) async {
    final p = context.read<OrientationProvider>();
    await p.loadStudentFile(booking['id'].toString());
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudentFileSheet(eleve: booking['student_name']?.toString()),
    );
  }

  Future<void> _ouvrirFiche(BuildContext context) async {
    final p = context.read<OrientationProvider>();
    final id = booking['id'].toString();
    await p.loadRecord(id);
    if (!context.mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrientationRecordSheet(
        bookingId: id,
        eleve: booking['student_name']?.toString() ?? 'Élève',
      ),
    );
    if (saved == true) await onChanged();
  }

  Future<void> _cloturer(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clôturer la consultation'),
        content: const Text(
          'Le rendez-vous passera dans l\'historique et la salle sera fermée. '
          'Vous pourrez toujours rédiger ou modifier la fiche ensuite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
    if (confirme != true || !context.mounted) return;

    final error = await context
        .read<OrientationProvider>()
        .completeBooking(booking['id'].toString());
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'Consultation clôturée.'),
      backgroundColor: error != null ? OrientationTheme.red : null,
    ));
    await onChanged();
  }
}

// ═══ Créneaux ══════════════════════════════════════════════════════════

class _CounselorAvailabilityTab extends StatelessWidget {
  const _CounselorAvailabilityTab();

  @override
  Widget build(BuildContext context) => const CounselorAvailabilityEditor();
}

// ═══ Fiches ════════════════════════════════════════════════════════════

class _CounselorRecordsTab extends StatelessWidget {
  const _CounselorRecordsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<OrientationProvider>(
      builder: (context, p, _) {
        final records = p.records;
        return RefreshIndicator(
          onRefresh: p.loadCounselorWorkspace,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const Text(
                'Chaque consultation donne lieu à une fiche que l\'élève et sa '
                'famille emportent. C\'est le livrable de votre travail.',
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: OrientationTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              if (records.isEmpty)
                const _EmptyBlock(
                  icon: Icons.description_outlined,
                  title: 'Aucune fiche rédigée',
                  body: 'Après une consultation, rédigez la fiche depuis '
                      'l\'onglet Consultations.',
                )
              else
                ...records.map((r) => _RecordCard(record: r)),
            ],
          ),
        );
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  const _RecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final quand = DateTime.tryParse('${record['scheduled_at']}')?.toLocal();
    final partagee = record['is_shared'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: OrientationTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record['student_name']?.toString() ?? 'Élève',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              _Pill(
                text: partagee ? 'Partagée' : 'Brouillon',
                color: partagee
                    ? OrientationTheme.teal
                    : OrientationTheme.amber,
              ),
            ],
          ),
          if (quand != null) ...[
            const SizedBox(height: 3),
            Text(OrientationLabels.dateComplete(quand),
                style: const TextStyle(
                    fontSize: 12.5, color: OrientationTheme.textMuted)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final p = context.read<OrientationProvider>();
                final id = record['booking_id'].toString();
                await p.loadRecord(id);
                if (!context.mounted) return;
                final saved = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => OrientationRecordSheet(
                    bookingId: id,
                    eleve: record['student_name']?.toString() ?? 'Élève',
                  ),
                );
                if (saved == true) await p.loadCounselorWorkspace();
              },
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('Ouvrir la fiche'),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══ Revenus ═══════════════════════════════════════════════════════════

class _CounselorRevenueTab extends StatelessWidget {
  const _CounselorRevenueTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<OrientationProvider>(
      builder: (context, p, _) {
        final b = p.balance;
        int montant(String k) {
          final x = b[k];
          if (x is int) return x;
          if (x is num) return x.round();
          return int.tryParse('${x ?? 0}') ?? 0;
        }

        // La plateforme ne fait pas accumuler de solde : chaque revenu part
        // aussitôt en file de versement. Afficher un « solde disponible »
        // aurait affiché zéro en permanence, quel que soit le travail fait.
        final devise = b['currency']?.toString() ?? 'XOF';
        final gagne = montant('total_earned');
        final enCours = montant('en_cours_de_versement');
        final bloque = montant('bloque_faute_de_numero');
        final verse = montant('deja_verse');
        final numero = b['payout_phone']?.toString();
        final numeroManquant = b['numero_manquant'] == true;

        return RefreshIndicator(
          onRefresh: p.loadCounselorWorkspace,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: OrientationTheme.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL GAGNÉ',
                        style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.75))),
                    const SizedBox(height: 7),
                    // FittedBox : un montant à sept chiffres ne déborde pas
                    // sur un écran étroit, il se réduit.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${OrientationLabels.montant(gagne)} $devise',
                        style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Vos revenus partent automatiquement vers votre mobile '
                      'money : rien ne dort sur un compte.',
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              if (numeroManquant) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: OrientationTheme.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: OrientationTheme.amber.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${OrientationLabels.montant(bloque)} $devise en attente '
                        'de votre numéro',
                        style: OrientationTheme.warningTitle,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Renseignez votre numéro mobile money : les versements '
                        'repartiront aussitôt.',
                        style: OrientationTheme.warningBody,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final colonnes = c.maxWidth >= 480 ? 3 : 1;
                  const espace = 10.0;
                  final largeur =
                      (c.maxWidth - espace * (colonnes - 1)) / colonnes;
                  final lignes = <(String, String)>[
                    ('En cours de versement',
                        '${OrientationLabels.montant(enCours)} $devise'),
                    ('Déjà versé', '${OrientationLabels.montant(verse)} $devise'),
                    ('Numéro de versement', numero ?? 'non renseigné'),
                  ];
                  return Wrap(
                    spacing: espace,
                    runSpacing: espace,
                    children: lignes
                        .map((l) => SizedBox(
                              width: largeur,
                              child: Container(
                                padding: const EdgeInsets.all(13),
                                decoration: OrientationTheme.cardDecoration,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(l.$1,
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              color: OrientationTheme.textMuted)),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        l.$2,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: OrientationTheme.accent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => _demanderRetrait(context, numero),
                  icon: const Icon(Icons.smartphone_outlined, size: 18),
                  label: Text(numero == null
                      ? 'Renseigner mon numéro de versement'
                      : 'Modifier mon numéro de versement'),
                ),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Activité'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: OrientationTheme.cardDecoration,
                child: Column(
                  children: [
                    _LigneActivite(
                      label: 'Consultations terminées',
                      valeur: '${b['consultations_terminees'] ?? 0}',
                    ),
                    const Divider(height: 20),
                    _LigneActivite(
                      label: 'Consultations à venir',
                      valeur: '${b['consultations_a_venir'] ?? 0}',
                    ),
                    const Divider(height: 20),
                    _LigneActivite(
                      label: 'Fiches rédigées',
                      valeur: '${b['fiches_redigees'] ?? 0}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Chaque consultation terminée et chaque séance collective '
                'close vous crédite immédiatement. Le versement part seul '
                'vers votre numéro mobile money — vous n\'avez aucune demande '
                'à formuler.',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: OrientationTheme.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _demanderRetrait(BuildContext context, String? phoneActuel) async {
    final controller = TextEditingController(text: phoneActuel ?? '');
    final messenger = ScaffoldMessenger.of(context);

    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Numéro de versement'),
        // Contenu défilant et sans largeur fixe : la boîte s'adapte à
        // l'écran, y compris quand le clavier réduit la hauteur disponible.
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vos revenus sont versés automatiquement sur ce numéro mobile '
                'money. Les versements déjà en attente repartiront dès que '
                'vous l\'aurez enregistré.',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Numéro de téléphone',
                  hintText: '70 00 00 00',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (phone == null || phone.isEmpty || !context.mounted) return;
    final error =
        await context.read<OrientationProvider>().requestPayout(phone);
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'Numéro enregistré. Vos versements y partiront.'),
      backgroundColor: error != null ? OrientationTheme.red : null,
    ));
  }
}

class _LigneActivite extends StatelessWidget {
  final String label;
  final String valeur;
  const _LigneActivite({required this.label, required this.valeur});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13.5, color: OrientationTheme.textSecondary)),
          ),
          const SizedBox(width: 8),
          Text(valeur,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      );
}

// ═══ Composants partagés ═══════════════════════════════════════════════

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
            color: OrientationTheme.textMuted,
          ),
        ),
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
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w500, color: color),
        ),
      );
}

class _EmptyBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _EmptyBlock(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
        decoration: OrientationTheme.cardDecoration,
        child: Column(
          children: [
            Icon(icon, size: 38, color: OrientationTheme.textMuted),
            const SizedBox(height: 13),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: OrientationTheme.textSecondary)),
          ],
        ),
      );
}
