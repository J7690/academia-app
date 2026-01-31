import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_td_catalog_provider.dart';
import '../../providers/student_td_enrollments_provider.dart';
import '../../providers/student_td_requests_provider.dart';
import '../../providers/td_messages_provider.dart';
import '../../widgets/bobodo_state.dart';
import '../../widgets/bobodo_view.dart';
import '../share/share_service.dart';
import '../share/share_mode_provider.dart';
import '../share/widgets/share_signature.dart';

class StudentTdRootScreen extends StatefulWidget {
  const StudentTdRootScreen({super.key});

  @override
  State<StudentTdRootScreen> createState() => _StudentTdRootScreenState();
}

class _StudentTdRootScreenState extends State<StudentTdRootScreen> {
  final GlobalKey _shareBoundaryKey = GlobalKey();
  final ShareService _shareService = ShareService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StudentTdCatalogProvider>().loadPrograms();
      context.read<StudentTdEnrollmentsProvider>().loadMyEnrollments();
      context.read<StudentTdRequestsProvider>().loadMyRequests();
    });
  }

  Future<void> _shareCurrentView() async {
    await _shareService.shareCurrentView(
      context: context,
      boundaryKey: _shareBoundaryKey,
      shareText:
          'Découvert via Academia – Module TD (Travaux dirigés) de mon espace étudiant.',
    );
  }

  void _openShareOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.web),
                title: const Text('Vue complète de l\'espace TD'),
                subtitle: const Text(
                  'Capture tout l\'écran du module TD (onglet actuel).',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareCurrentView();
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Carte "Mes TD actifs"'),
                subtitle: const Text(
                  'Met en avant le nombre de TD actifs et quelques titres.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareTdActiveCard();
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Carte prochaine séance TD'),
                subtitle: const Text(
                  'Partage la date de ta prochaine séance TD.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _shareTdNextSessionCard();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareTdActiveCard() async {
    final provider = context.read<StudentTdEnrollmentsProvider>();
    final enrollments = provider.enrollments;
    final active = enrollments
        .where((e) => (e['access_status'] ?? '').toString() == 'active')
        .toList(growable: false);

    final titles = <String>{};
    for (final e in active) {
      final title = (e['program_title'] ?? 'Programme TD').toString().trim();
      if (title.isNotEmpty) {
        titles.add(title);
      }
      if (titles.length >= 3) break;
    }

    await _shareService.shareCustomCard(
      context: context,
      card: _StudentTdShareActiveCard(
        activeCount: active.length,
        programTitles: titles.toList(growable: false),
      ),
      shareText:
          'Mes TD actifs sur Academia – Module TD (Travaux dirigés).',
    );
  }

  Future<void> _shareTdNextSessionCard() async {
    final provider = context.read<StudentTdEnrollmentsProvider>();
    final nextSessions = provider.nextSessions;

    DateTime? nextSessionAt;
    if (nextSessions.isNotEmpty) {
      for (final s in nextSessions) {
        final raw = s['scheduled_at'];
        if (raw == null) continue;
        final dt = DateTime.tryParse(raw.toString());
        if (dt == null) continue;
        if (nextSessionAt == null || dt.isBefore(nextSessionAt)) {
          nextSessionAt = dt;
        }
      }
    }

    String subtitle;
    if (nextSessionAt != null) {
      final d = nextSessionAt;
      final day = d.day.toString().padLeft(2, '0');
      final month = d.month.toString().padLeft(2, '0');
      final year = d.year.toString();
      final hour = d.hour.toString().padLeft(2, '0');
      final minute = d.minute.toString().padLeft(2, '0');
      subtitle = 'Le $day/$month/$year à $hour:$minute';
    } else {
      subtitle = 'Aucune séance TD programmée pour le moment.';
    }

    await _shareService.shareCustomCard(
      context: context,
      card: _StudentTdShareNextSessionCard(
        title: 'Ma prochaine séance TD',
        subtitle: subtitle,
      ),
      shareText:
          'Ma prochaine séance de Travaux dirigés sur Academia.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: RepaintBoundary(
        key: _shareBoundaryKey,
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFFF3F4F6),
              appBar: AppBar(
                title: const Text('TD - Travaux dirigés'),
                actions: [
                  Consumer<ShareModeProvider>(
                    builder: (context, shareMode, _) {
                      final isBusy = shareMode.isBusy;
                      return IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: isBusy ? null : _openShareOptions,
                        tooltip: 'Partager mon espace TD',
                      );
                    },
                  ),
                ],
                bottom: TabBar(
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Catalogue TD'),
                    Tab(text: 'Mes TD'),
                    Tab(text: 'Mes demandes'),
                  ],
                ),
              ),
              body: const TabBarView(
                children: [
                  _StudentTdCatalogTab(),
                  _StudentTdMyEnrollmentsTab(),
                  _StudentTdRequestsTab(),
                ],
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: IgnorePointer(
                child: Consumer<ShareModeProvider>(
                  builder: (context, shareMode, _) {
                    if (!shareMode.isShareModeEnabled) {
                      return const SizedBox.shrink();
                    }
                    return const ShareSignature();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentTdShareActiveCard extends StatelessWidget {
  final int activeCount;
  final List<String> programTitles;

  const _StudentTdShareActiveCard({
    required this.activeCount,
    required this.programTitles,
  });

  @override
  Widget build(BuildContext context) {
    final hasActive = activeCount > 0;
    final titles = programTitles.take(3).toList(growable: false);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 10),
              blurRadius: 30,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Academia – Module TD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hasActive
                      ? "J'ai $activeCount TD actif(s) en ce moment."
                      : 'Je prépare mes futurs Travaux dirigés.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (hasActive && titles.isNotEmpty) ...[
                  const Text(
                    'Programmes en cours:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...titles.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Dès que mes premiers TD seront activés, ils apparaîtront ici.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            const Positioned(
              right: 16,
              bottom: 16,
              child: ShareSignature(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentTdShareNextSessionCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StudentTdShareNextSessionCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ma prochaine séance de Travaux dirigés',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A2540),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Partagé depuis mon espace étudiant Academia.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const Positioned(
              right: 16,
              bottom: 16,
              child: ShareSignature(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentTdCatalogTab extends StatelessWidget {
  const _StudentTdCatalogTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentTdCatalogProvider>();
    final programs = provider.programs;

    return RefreshIndicator(
      onRefresh: () => provider.loadPrograms(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: programs.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(right: 12.0),
                        child: BobodoView(
                          state: BobodoState.thinking,
                          size: 40,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Les TD sont organisés par l\'administrateur. Parcours le catalogue et, si rien ne correspond, tu peux demander un TD adapté à ton niveau.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF4F46E5),
                      child: Icon(Icons.help_outline, color: Colors.white, size: 20),
                    ),
                    title: const Text(
                      'Je ne trouve pas mon TD',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Demande un TD spécifique à l\'administrateur si aucun programme ne correspond.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _promptCreateRequest(context),
                  ),
                ),
              ],
            );
          }

          final p = programs[index - 1];
          final title = p['title']?.toString() ?? '';
          final level = p['level']?.toString() ?? '';
          final modality = p['modality']?.toString() ?? '';
          final price = p['price'];
          final currency = p['currency']?.toString() ?? 'XOF';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              title: Text(title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  if (level.isNotEmpty || modality.isNotEmpty)
                    Text(
                      [
                        if (level.isNotEmpty) 'Niveau: $level',
                        if (modality.isNotEmpty) 'Modalité: $modality',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (price != null)
                    Text(
                      'Prix: $price $currency',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _StudentTdProgramDetailScreen(program: p),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _promptCreateRequest(BuildContext context) async {
    final subjectController = TextEditingController();
    final levelController = TextEditingController();
    final descriptionController = TextEditingController();
    final scheduleController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Demander un TD non proposé'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Décris le TD que tu souhaites suivre. L\'administrateur pourra programmer un nouveau TD adapté.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Matière / sujet (obligatoire)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: levelController,
                  decoration: const InputDecoration(
                    labelText: 'Niveau (ex: Terminale, L1, L2...)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Ce dont tu as besoin (exercices, préparation examen...)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: scheduleController,
                  decoration: const InputDecoration(
                    labelText: 'Créneaux souhaités (soir, week-end...)',
                    border: OutlineInputBorder(),
                  ),
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
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final subject = subjectController.text.trim();
    if (subject.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le sujet du TD est obligatoire pour envoyer une demande.'),
        ),
      );
      return;
    }

    final provider = context.read<StudentTdRequestsProvider>();
    final ok = await provider.createRequest(
      fieldId: null,
      level: levelController.text.trim().isEmpty
          ? null
          : levelController.text.trim(),
      subject: subject,
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      preferredModality: null,
      preferredSchedule: scheduleController.text.trim().isEmpty
          ? null
          : scheduleController.text.trim(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Demande TD envoyée à l\'administrateur.'
              : provider.error ?? 'Erreur lors de l\'envoi de la demande TD.',
        ),
      ),
    );
  }
}

class _StudentTdProgramDetailScreen extends StatefulWidget {
  const _StudentTdProgramDetailScreen({required this.program});

  final Map<String, dynamic> program;

  @override
  State<_StudentTdProgramDetailScreen> createState() => _StudentTdProgramDetailScreenState();
}

class _StudentTdProgramDetailScreenState extends State<_StudentTdProgramDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final programId = widget.program['id']?.toString() ?? '';
      if (programId.isNotEmpty) {
        context.read<StudentTdCatalogProvider>().loadProgramDetail(programId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;
    final programId = program['id']?.toString() ?? '';
    final title = program['title']?.toString() ?? '';
    final description = program['description']?.toString() ?? '';
    final level = program['level']?.toString() ?? '';
    final modality = program['modality']?.toString() ?? '';
    final price = program['price'];
    final currency = program['currency']?.toString() ?? 'XOF';

    final catalogProvider = context.watch<StudentTdCatalogProvider>();
    final detail = catalogProvider.programDetail;

    DateTime? nextSessionAt;
    if (detail != null) {
      final collections = detail['collections'];
      if (collections is List) {
        for (final c in collections) {
          if (c is! Map) continue;
          final sessions = c['sessions'];
          if (sessions is! List) continue;
          for (final s in sessions) {
            if (s is! Map) continue;
            final raw = s['scheduled_at'];
            if (raw == null) continue;
            final dt = DateTime.tryParse(raw.toString());
            if (dt == null) continue;
            if (nextSessionAt == null || dt.isBefore(nextSessionAt!)) {
              nextSessionAt = dt;
            }
          }
        }
      }
    }

    String? nextSessionLabel;
    if (nextSessionAt != null) {
      final d = nextSessionAt!;
      final day = d.day.toString().padLeft(2, '0');
      final month = d.month.toString().padLeft(2, '0');
      final year = d.year.toString();
      final hour = d.hour.toString().padLeft(2, '0');
      final minute = d.minute.toString().padLeft(2, '0');
      nextSessionLabel = 'Prochaine séance programmée le $day/$month/$year à $hour:$minute';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (level.isNotEmpty || modality.isNotEmpty)
              Text(
                [
                  if (level.isNotEmpty) 'Niveau: $level',
                  if (modality.isNotEmpty) 'Modalité: $modality',
                ].join(' · '),
                style: const TextStyle(fontSize: 13),
              ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (price != null)
                      Text(
                        'Prix: $price $currency',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2540),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (nextSessionLabel != null) ...[
              const SizedBox(height: 12),
              Text(
                nextSessionLabel!,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final numericPrice = price is num ? price as num : null;
                  if (programId.isEmpty || numericPrice == null || numericPrice <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Ce TD n\'a pas encore de prix défini par l\'administration. Merci de réessayer plus tard.',
                        ),
                      ),
                    );
                    return;
                  }

                  final studentNotes = await _promptPersonalization(context);
                  if (studentNotes == null) {
                    // L'étudiant a annulé le formulaire de personnalisation.
                    return;
                  }

                  final enrollmentsProvider =
                      context.read<StudentTdEnrollmentsProvider>();
                  final ok = await enrollmentsProvider.createEnrollmentAndPayment(
                    programId: programId,
                    collectionId: null,
                    accessScope: 'program',
                    amountDue: numericPrice.toDouble(),
                    studentNotes: studentNotes,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Demande TD enregistrée. Déclare ton paiement dans l\'onglet Paiements.'
                            : enrollmentsProvider.error ??
                                'Erreur lors de la création de la demande TD.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Je veux ce TD (paiement manuel)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _promptPersonalization(BuildContext context) async {
  final typeController = TextEditingController();
  final scheduleController = TextEditingController();
  final placeController = TextEditingController();
  final notesController = TextEditingController();

  final result = await showDialog<String?>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Personnaliser ce TD'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Type de TD souhaité (ex: individuel, petit groupe)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: scheduleController,
                decoration: const InputDecoration(
                  labelText: 'Créneaux souhaités (jours / heures)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: placeController,
                decoration: const InputDecoration(
                  labelText: 'Lieu préféré (en ligne, présentiel, ville...)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Autres précisions (niveau exact, chapitres, etc.)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final parts = <String>[];
              final type = typeController.text.trim();
              final schedule = scheduleController.text.trim();
              final place = placeController.text.trim();
              final notes = notesController.text.trim();

              if (type.isNotEmpty) {
                parts.add('Type de TD: $type');
              }
              if (schedule.isNotEmpty) {
                parts.add('Créneaux souhaités: $schedule');
              }
              if (place.isNotEmpty) {
                parts.add('Lieu préféré: $place');
              }
              if (notes.isNotEmpty) {
                parts.add('Précisions: $notes');
              }

              final combined = parts.join(' | ');
              Navigator.of(context).pop(combined);
            },
            child: const Text('Valider'),
          ),
        ],
      );
    },
  );

  return result;
}

class _StudentTdMyEnrollmentsTab extends StatelessWidget {
  const _StudentTdMyEnrollmentsTab();

  @override
  Widget build(BuildContext context) {
    final enrollmentsProvider = context.watch<StudentTdEnrollmentsProvider>();
    final messagesProvider = context.watch<TdMessagesProvider>();
    final enrollments = enrollmentsProvider.enrollments;

    // Calculer quelques infos de cockpit
    final nextSessions = enrollmentsProvider.nextSessions;
    DateTime? nextSessionAt;
    if (nextSessions.isNotEmpty) {
      for (final s in nextSessions) {
        final raw = s['scheduled_at'];
        if (raw == null) continue;
        final dt = DateTime.tryParse(raw.toString());
        if (dt == null) continue;
        if (nextSessionAt == null || dt.isBefore(nextSessionAt)) {
          nextSessionAt = dt;
        }
      }
    }

    final activeCount = enrollments
        .where((e) => (e['access_status'] ?? '').toString() == 'active')
        .length;
    final unreadCount = enrollmentsProvider.unreadMessagesCount;

    return RefreshIndicator(
      onRefresh: enrollmentsProvider.loadMyEnrollments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: enrollments.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            String? nextLabel;
            if (nextSessionAt != null) {
              final d = nextSessionAt;
              final day = d.day.toString().padLeft(2, '0');
              final month = d.month.toString().padLeft(2, '0');
              final year = d.year.toString();
              final hour = d.hour.toString().padLeft(2, '0');
              final minute = d.minute.toString().padLeft(2, '0');
              nextLabel = 'Prochaine séance prévue le $day/$month/$year à $hour:$minute';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(right: 12.0),
                          child: BobodoView(
                            state: BobodoState.thinking,
                            size: 40,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeCount > 0
                                    ? 'Tu as $activeCount TD actifs en ce moment.'
                                    : "Tu n'as pas encore de TD actif.",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (nextLabel != null)
                                Text(
                                  nextLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF4B5563),
                                  ),
                                )
                              else
                                const Text(
                                  'Dès que ton admin programme une séance, elle apparaîtra ici.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              if (unreadCount > 0)
                                Text(
                                  'Tu as $unreadCount message(s) non lu(s) avec l\'admin TD.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            );
          }

          final e = enrollments[index - 1];
          final enrollmentId = e['id']?.toString() ?? '';
          final title = e['program_title']?.toString() ?? 'Programme TD';
          final level = e['program_level']?.toString() ?? '';
          final accessStatus = e['access_status']?.toString() ?? '';
          final assignmentStatus = e['assignment_status']?.toString() ?? '';
          final teacherId = e['assigned_teacher_id']?.toString();
          final paymentStatus = e['payment_status']?.toString() ?? '';

          Color statusColor;
          if (accessStatus == 'pending_payment') {
            statusColor = Colors.orange;
          } else if (accessStatus == 'waiting_admin') {
            statusColor = Colors.blue;
          } else if (accessStatus == 'active') {
            statusColor = Colors.green;
          } else {
            statusColor = Colors.grey;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          accessStatus,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        backgroundColor: statusColor,
                      ),
                    ],
                  ),
                  if (level.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Niveau: $level',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Paiement: ${paymentStatus.isEmpty ? 'N/A' : paymentStatus}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Affectation: $assignmentStatus',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (teacherId != null && teacherId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Enseignant assigné (ID interne): $teacherId',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (accessStatus == 'active')
                        ElevatedButton.icon(
                          onPressed: () {
                            // L\'accès réel (docs, lives) sera branché plus tard.
                          },
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Accéder au TD'),
                        ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          if (enrollmentId.isEmpty) return;
                          await messagesProvider.loadMessages(enrollmentId);
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _StudentTdMessagesScreen(
                                enrollmentId: enrollmentId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_outlined, size: 18),
                        label: const Text('Contacter l\'admin'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StudentTdMessagesScreen extends StatelessWidget {
  const _StudentTdMessagesScreen({required this.enrollmentId});

  final String enrollmentId;

  @override
  Widget build(BuildContext context) {
    final messagesProvider = context.watch<TdMessagesProvider>();
    final messages = messagesProvider.messagesFor(enrollmentId);
    final controller = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages TD avec l\'admin'),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text('Aucun message pour ce TD.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final m = messages[index];
                      final senderRole = m['sender_role']?.toString() ?? '';
                      final content = m['content']?.toString() ?? '';
                      final createdAt = m['created_at']?.toString() ?? '';

                      final isStudent = senderRole == 'student';
                      final align = isStudent
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start;
                      final bgColor = isStudent
                          ? const Color(0xFFE3F2FD)
                          : const Color(0xFFE8F5E9);

                      return Align(
                        alignment: isStudent
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: align,
                            children: [
                              Text(
                                content,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$senderRole · $createdAt',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message à l\'admin...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    await messagesProvider.sendMessage(
                      enrollmentId: enrollmentId,
                      threadType: 'student_admin',
                      content: text,
                    );
                    controller.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentTdRequestsTab extends StatelessWidget {
  const _StudentTdRequestsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentTdRequestsProvider>();
    final requests = provider.requests;

    return RefreshIndicator(
      onRefresh: provider.loadMyRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final r = requests[index];
          final subject = r['subject']?.toString() ?? '';
          final level = r['level']?.toString() ?? '';
          final status = r['status']?.toString() ?? '';
          final description = r['description']?.toString() ?? '';
          final preferredSchedule = r['preferred_schedule']?.toString() ?? '';
          final createdProgramTitle = r['created_program_title']?.toString() ?? '';

          Color statusColor;
          if (status == 'pending') {
            statusColor = Colors.orange;
          } else if (status == 'in_review') {
            statusColor = Colors.blue;
          } else if (status == 'planned') {
            statusColor = Colors.purple;
          } else if (status == 'converted') {
            statusColor = Colors.green;
          } else if (status == 'rejected') {
            statusColor = Colors.red;
          } else {
            statusColor = Colors.grey;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject.isEmpty ? 'Demande TD' : subject,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          status.isEmpty ? 'Inconnu' : status,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        backgroundColor: statusColor,
                      ),
                    ],
                  ),
                  if (level.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Niveau: $level',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  if (preferredSchedule.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Créneaux souhaités: $preferredSchedule',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                  if (createdProgramTitle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Programme créé: $createdProgramTitle',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
