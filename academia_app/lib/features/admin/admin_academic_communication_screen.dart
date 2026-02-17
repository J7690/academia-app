import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_academic_announcements_provider.dart';
import '../../providers/admin_academic_events_provider.dart';

class AdminAcademicCommunicationScreen extends StatefulWidget {
  const AdminAcademicCommunicationScreen({super.key});

  @override
  State<AdminAcademicCommunicationScreen> createState() =>
      _AdminAcademicCommunicationScreenState();
}

class _AdminAcademicCommunicationScreenState
    extends State<AdminAcademicCommunicationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminAcademicAnnouncementsProvider>().loadAnnouncements();
      context.read<AdminAcademicEventsProvider>().loadEvents();
    });
  }

  DateTime? _parseDateTimeFromInput(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    final parts = trimmed.split(' ');
    final datePart = parts[0];
    final dateSegments = datePart.split('/');
    if (dateSegments.length == 3) {
      final day = int.tryParse(dateSegments[0]);
      final month = int.tryParse(dateSegments[1]);
      final year = int.tryParse(dateSegments[2]);
      if (day != null && month != null && year != null) {
        int hour = 9;
        int minute = 0;
        if (parts.length > 1) {
          final timeSegments = parts[1].split(':');
          if (timeSegments.isNotEmpty) {
            final parsedHour = int.tryParse(timeSegments[0]);
            if (parsedHour != null) {
              hour = parsedHour;
            }
          }
          if (timeSegments.length > 1) {
            final parsedMinute = int.tryParse(timeSegments[1]);
            if (parsedMinute != null) {
              minute = parsedMinute;
            }
          }
        }
        return DateTime(year, month, day, hour, minute);
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const SizedBox(height: 8),
          const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Color(0xFF1EA75C),
            tabs: [
              Tab(text: 'Annonces'),
              Tab(text: 'Calendrier'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                _AdminAnnouncementsView(parseDateTimeFromInput: _parseDateTimeFromInput),
                _AdminEventsView(parseDateTimeFromInput: _parseDateTimeFromInput),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAnnouncementsView extends StatelessWidget {
  final DateTime? Function(String) parseDateTimeFromInput;

  const _AdminAnnouncementsView({
    required this.parseDateTimeFromInput,
  });

  Future<void> _openAnnouncementDialog(
    BuildContext context,
    AdminAcademicAnnouncementsProvider provider, {
    Map<String, dynamic>? existing,
  }) async {
    final titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final summaryController = TextEditingController(
      text: existing?['summary']?.toString() ?? '',
    );
    final bodyController = TextEditingController(
      text: existing?['body']?.toString() ?? '',
    );
    final categoryController = TextEditingController(
      text: existing?['category']?.toString() ?? '',
    );
    final urgency = (existing?['urgency_level']?.toString() ?? 'info').toLowerCase();
    String urgencyLevel =
        urgency == 'critical' || urgency == 'important' ? urgency : 'info';

    final visibleFromController = TextEditingController(
      text: existing?['visible_from']?.toString() ?? '',
    );
    final visibleUntilController = TextEditingController(
      text: existing?['visible_until']?.toString() ?? '',
    );
    bool isPublished = existing?['is_published'] == true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Nouvelle annonce officielle'
                    : 'Modifier l\'annonce',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titre *',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: summaryController,
                      decoration: const InputDecoration(
                        labelText: 'Résumé (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bodyController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Contenu *',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie (ex: system, exam...)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: urgencyLevel,
                      decoration: const InputDecoration(
                        labelText: 'Niveau d\'urgence',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'info',
                          child: Text('Info'),
                        ),
                        DropdownMenuItem(
                          value: 'important',
                          child: Text('Important'),
                        ),
                        DropdownMenuItem(
                          value: 'critical',
                          child: Text('Critique'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setStateDialog(() {
                          urgencyLevel = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: visibleFromController,
                      decoration: const InputDecoration(
                        labelText: 'Visible à partir du (ISO ou jj/MM/aaaa HH:mm)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: visibleUntilController,
                      decoration: const InputDecoration(
                        labelText: 'Visible jusqu\'au (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: isPublished,
                      onChanged: (value) {
                        setStateDialog(() {
                          isPublished = value;
                        });
                      },
                      title: const Text('Publié (visible côté étudiant)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final body = bodyController.text.trim();
                    if (title.isEmpty || body.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Merci de renseigner au moins titre et contenu.'),
                        ),
                      );
                      return;
                    }
                    final DateTime? visibleFrom =
                        parseDateTimeFromInput(visibleFromController.text);
                    final DateTime? visibleUntil =
                        parseDateTimeFromInput(visibleUntilController.text);

                    final ok = await provider.upsertAnnouncement(
                      announcementId: existing?['id']?.toString(),
                      title: title,
                      body: body,
                      summary: summaryController.text.trim().isEmpty
                          ? null
                          : summaryController.text.trim(),
                      urgencyLevel: urgencyLevel,
                      category: categoryController.text.trim().isEmpty
                          ? null
                          : categoryController.text.trim(),
                      isPublished: isPublished,
                      visibleFrom: visibleFrom,
                      visibleUntil: visibleUntil,
                    );
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Annonce enregistrée.'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            provider.error ??
                                'Erreur lors de l\'enregistrement de l\'annonce.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteAnnouncement(
    BuildContext context,
    AdminAcademicAnnouncementsProvider provider,
    Map<String, dynamic> announcement,
  ) async {
    final id = announcement['id']?.toString();
    if (id == null || id.isEmpty) return;
    final title = announcement['title']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer l\'annonce'),
          content: Text(
            'Cette annonce ne sera plus visible côté étudiant.\n\nTitre : ' +
                title,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final ok = await provider.deleteAnnouncement(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Annonce supprimée.'
              : provider.error ??
                  'Erreur lors de la suppression de l\'annonce.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminAcademicAnnouncementsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.announcements.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.announcements.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.error!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: provider.loadAnnouncements,
                    child: const Text('Recharger'),
                  ),
                ],
              ),
            ),
          );
        }

        final announcements = provider.announcements;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Annonces officielles',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openAnnouncementDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvelle annonce'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: announcements.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Aucune annonce configurée pour le moment.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: announcements.length,
                      itemBuilder: (context, index) {
                        final a = announcements[index];
                        final title = a['title']?.toString() ?? '';
                        final summary = (a['summary']?.toString() ?? '').trim();
                        final body = (a['body']?.toString() ?? '').trim();
                        final urgency =
                            (a['urgency_level']?.toString() ?? 'info').toLowerCase();
                        final isPublished = a['is_published'] == true;

                        Color chipColor;
                        String chipText;
                        if (urgency == 'critical') {
                          chipColor = const Color(0xFFDC2626);
                          chipText = 'Critique';
                        } else if (urgency == 'important') {
                          chipColor = const Color(0xFFF97316);
                          chipText = 'Important';
                        } else {
                          chipColor = const Color(0xFF3B82F6);
                          chipText = 'Info';
                        }

                        final preview = summary.isNotEmpty
                            ? summary
                            : (body.length > 200
                                ? body.substring(0, 200) + '…'
                                : body);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title.isEmpty
                                            ? 'Annonce sans titre'
                                            : title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: Text(
                                        chipText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                      backgroundColor: chipColor,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (preview.isNotEmpty)
                                  Text(
                                    preview,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (isPublished)
                                      const Text(
                                        'Publié',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF16A34A),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      )
                                    else
                                      const Text(
                                        'Brouillon',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          tooltip: 'Modifier',
                                          onPressed: () => _openAnnouncementDialog(
                                            context,
                                            provider,
                                            existing: a,
                                          ),
                                        ),
                                        IconButton(
                                          icon:
                                              const Icon(Icons.delete_outline_rounded),
                                          tooltip: 'Supprimer',
                                          onPressed: () => _confirmDeleteAnnouncement(
                                            context,
                                            provider,
                                            a,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AdminEventsView extends StatelessWidget {
  final DateTime? Function(String) parseDateTimeFromInput;

  const _AdminEventsView({
    required this.parseDateTimeFromInput,
  });

  Future<void> _openEventDialog(
    BuildContext context,
    AdminAcademicEventsProvider provider, {
    Map<String, dynamic>? existing,
  }) async {
    final titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: existing?['description']?.toString() ?? '',
    );
    final typeController = TextEditingController(
      text: existing?['event_type']?.toString() ?? '',
    );
    final countryController = TextEditingController(
      text: existing?['country']?.toString() ?? '',
    );
    final cityController = TextEditingController(
      text: existing?['city']?.toString() ?? '',
    );
    final locationController = TextEditingController(
      text: existing?['location']?.toString() ?? '',
    );
    final levelController = TextEditingController(
      text: existing?['level']?.toString() ?? '',
    );
    final tagsController = TextEditingController(
      text: (existing?['tags'] as List<dynamic>?)?.join(', ') ?? '',
    );
    bool isAllDay = existing?['is_all_day'] == true;
    bool isPublished = existing?['is_published'] == true;
    bool isHighlighted = existing?['is_highlighted'] == true;

    final startAtController = TextEditingController(
      text: existing?['start_at']?.toString() ?? '',
    );
    final endAtController = TextEditingController(
      text: existing?['end_at']?.toString() ?? '',
    );
    final registrationOpenController = TextEditingController(
      text: existing?['registration_open_at']?.toString() ?? '',
    );
    final registrationDeadlineController = TextEditingController(
      text: existing?['registration_deadline_at']?.toString() ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Nouvel événement académique'
                    : 'Modifier l\'événement',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titre *',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: typeController,
                      decoration: const InputDecoration(
                        labelText: 'Type (ex: exam, registration, holiday...)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: countryController,
                      decoration: const InputDecoration(
                        labelText: 'Pays (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cityController,
                      decoration: const InputDecoration(
                        labelText: 'Ville (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Lieu (adresse, amphi, lien visio...)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: levelController,
                      decoration: const InputDecoration(
                        labelText: 'Niveau / cycle (optionnel, ex: L1, M2...)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: tagsController,
                      decoration: const InputDecoration(
                        labelText:
                            'Tags (optionnel, séparés par des virgules, ex: concours, bourse)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: startAtController,
                      decoration: const InputDecoration(
                        labelText: 'Début (ISO ou jj/MM/aaaa HH:mm)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: endAtController,
                      decoration: const InputDecoration(
                        labelText: 'Fin (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: registrationOpenController,
                      decoration: const InputDecoration(
                        labelText:
                            'Ouverture des inscriptions (optionnel, ISO ou jj/MM/aaaa HH:mm)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: registrationDeadlineController,
                      decoration: const InputDecoration(
                        labelText:
                            'Date limite d\'inscription (optionnel, ISO ou jj/MM/aaaa HH:mm)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: isAllDay,
                      onChanged: (value) {
                        setStateDialog(() {
                          isAllDay = value;
                        });
                      },
                      title: const Text('Toute la journée'),
                    ),
                    SwitchListTile(
                      value: isPublished,
                      onChanged: (value) {
                        setStateDialog(() {
                          isPublished = value;
                        });
                      },
                      title: const Text('Publié (visible côté étudiant)'),
                    ),
                    SwitchListTile(
                      value: isHighlighted,
                      onChanged: (value) {
                        setStateDialog(() {
                          isHighlighted = value;
                        });
                      },
                      title: const Text('Mettre en avant'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Merci de renseigner au moins le titre.'),
                        ),
                      );
                      return;
                    }

                    final DateTime? startAt =
                        parseDateTimeFromInput(startAtController.text);
                    final DateTime? endAt =
                        parseDateTimeFromInput(endAtController.text);
                    final DateTime? registrationOpenAt =
                        parseDateTimeFromInput(registrationOpenController.text);
                    final DateTime? registrationDeadlineAt =
                        parseDateTimeFromInput(
                          registrationDeadlineController.text,
                        );

                    final tagsText = tagsController.text.trim();
                    final tags = tagsText.isEmpty
                        ? null
                        : tagsText
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();

                    final ok = await provider.upsertEvent(
                      eventId: existing?['id']?.toString(),
                      title: title,
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      eventType: typeController.text.trim().isEmpty
                          ? 'other'
                          : typeController.text.trim(),
                      country: countryController.text.trim().isEmpty
                          ? null
                          : countryController.text.trim(),
                      city: cityController.text.trim().isEmpty
                          ? null
                          : cityController.text.trim(),
                      location: locationController.text.trim().isEmpty
                          ? null
                          : locationController.text.trim(),
                      level: levelController.text.trim().isEmpty
                          ? null
                          : levelController.text.trim(),
                      tags: tags,
                      isAllDay: isAllDay,
                      startAt: startAt,
                      endAt: endAt,
                      registrationOpenAt: registrationOpenAt,
                      registrationDeadlineAt: registrationDeadlineAt,
                      isPublished: isPublished,
                      isHighlighted: isHighlighted,
                    );
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Événement enregistré.'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            provider.error ??
                                'Erreur lors de l\'enregistrement de l\'événement.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteEvent(
    BuildContext context,
    AdminAcademicEventsProvider provider,
    Map<String, dynamic> event,
  ) async {
    final id = event['id']?.toString();
    if (id == null || id.isEmpty) return;
    final title = event['title']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer l\'événement'),
          content: Text(
            'Cet événement ne sera plus visible côté étudiant.\n\nTitre : ' +
                title,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final ok = await provider.deleteEvent(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Événement supprimé.'
              : provider.error ??
                  'Erreur lors de la suppression de l\'événement.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminAcademicEventsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.events.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.events.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.error!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: provider.loadEvents,
                    child: const Text('Recharger'),
                  ),
                ],
              ),
            ),
          );
        }

        final events = provider.events;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Événements académiques',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openEventDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvel événement'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: events.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Aucun événement académique configuré pour le moment.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final e = events[index];
                        final title = e['title']?.toString() ?? '';
                        final description =
                            (e['description']?.toString() ?? '').trim();
                        final type = (e['event_type']?.toString() ?? '')
                            .trim()
                            .toLowerCase();
                        final city = (e['city']?.toString() ?? '').trim();
                        final location =
                            (e['location']?.toString() ?? '').trim();
                        final isAllDay = e['is_all_day'] == true;
                        final isPublished = e['is_published'] == true;
                        final isHighlighted = e['is_highlighted'] == true;

                        final startAt = e['start_at']?.toString() ?? '';
                        final endAt = e['end_at']?.toString() ?? '';

                        String dateLine = '';
                        if (startAt.isNotEmpty && endAt.isNotEmpty) {
                          dateLine = isAllDay
                              ? 'Du $startAt au $endAt (toute la journée)'
                              : '$startAt — $endAt';
                        } else if (startAt.isNotEmpty) {
                          dateLine = isAllDay
                              ? '$startAt (toute la journée)'
                              : startAt;
                        }

                        final placeLine = [
                          if (city.isNotEmpty) city,
                          if (location.isNotEmpty) location,
                        ].join(' · ');

                        Color chipColor;
                        String chipText;
                        switch (type) {
                          case 'exam':
                            chipColor = const Color(0xFFDC2626);
                            chipText = 'Examen';
                            break;
                          case 'registration':
                            chipColor = const Color(0xFF2563EB);
                            chipText = 'Inscriptions';
                            break;
                          case 'holiday':
                            chipColor = const Color(0xFF16A34A);
                            chipText = 'Vacances';
                            break;
                          case 'scholarship':
                            chipColor = const Color(0xFFF97316);
                            chipText = 'Bourse';
                            break;
                          default:
                            chipColor = const Color(0xFF6B7280);
                            chipText = type.isEmpty ? 'Événement' : type;
                        }

                        final preview = description.isNotEmpty
                            ? (description.length > 200
                                ? description.substring(0, 200) + '…'
                                : description)
                            : '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title.isEmpty
                                            ? 'Événement sans titre'
                                            : title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: Text(
                                        chipText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                      backgroundColor: chipColor,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
                                ),
                                if (dateLine.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    dateLine,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
                                if (placeLine.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    placeLine,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                                if (preview.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    preview,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        if (isPublished)
                                          const Text(
                                            'Publié',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF16A34A),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )
                                        else
                                          const Text(
                                            'Brouillon',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                        if (isHighlighted) ...[
                                          const SizedBox(width: 8),
                                          const Text(
                                            'En vedette',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFFF97316),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          tooltip: 'Modifier',
                                          onPressed: () => _openEventDialog(
                                            context,
                                            provider,
                                            existing: e,
                                          ),
                                        ),
                                        IconButton(
                                          icon:
                                              const Icon(Icons.delete_outline_rounded),
                                          tooltip: 'Supprimer',
                                          onPressed: () => _confirmDeleteEvent(
                                            context,
                                            provider,
                                            e,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
