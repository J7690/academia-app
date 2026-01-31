import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_short_trainings_provider.dart';
import '../../providers/admin_short_training_messages_provider.dart';

class AdminShortTrainingsScreen extends StatefulWidget {
  const AdminShortTrainingsScreen({super.key});

  @override
  State<AdminShortTrainingsScreen> createState() => _AdminShortTrainingsScreenState();
}

class _AdminShortTrainingsScreenState extends State<AdminShortTrainingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminShortTrainingsProvider>().loadTrainings();
    });
  }

  DateTime? _parseDateTimeFromInput(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    // Essayer d'abord le parsing direct (formats ISO comme 2025-12-01T10:00:00)
    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    // Accepter un format français simple : jj/MM/aaaa ou jj/MM/aaaa HH:mm
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

  Future<void> _openTrainingDialog({Map<String, dynamic>? training}) async {
    final provider = context.read<AdminShortTrainingsProvider>();
    final titleController =
        TextEditingController(text: training?['title']?.toString() ?? '');
    final shortDescriptionController = TextEditingController(
        text: training?['short_description']?.toString() ?? '');
    final fullDescriptionController = TextEditingController(
        text: training?['full_description']?.toString() ?? '');
    final categoryController =
        TextEditingController(text: training?['category']?.toString() ?? '');
    final modalityController =
        TextEditingController(text: training?['modality']?.toString() ?? '');
    final durationDaysController = TextEditingController(
        text: training?['duration_days']?.toString() ?? '');
    final priceController =
        TextEditingController(text: training?['price']?.toString() ?? '');
    bool isActive = training == null ? true : training['is_active'] != false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: Text(
                training == null
                    ? 'Nouvelle formation courte'
                    : 'Modifier la formation',
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
                      controller: shortDescriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description courte',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: fullDescriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description détaillée',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: modalityController,
                      decoration: const InputDecoration(
                        labelText: 'Modalité (en ligne, présentiel, hybride...)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: durationDaysController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Durée (en jours)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Prix (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (value) {
                        setStateDialog(() {
                          isActive = value;
                        });
                      },
                      title: const Text('Formation active'),
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
                      return;
                    }
                    final durationText = durationDaysController.text.trim();
                    final priceText = priceController.text.trim();
                    final durationDays = durationText.isEmpty
                        ? null
                        : int.tryParse(durationText);
                    final normalizedPriceText =
                        priceText.replaceAll(',', '.');
                    final price = normalizedPriceText.isEmpty
                        ? null
                        : double.tryParse(normalizedPriceText);

                    final ok = await provider.upsertTraining(
                      trainingId: training?['id']?.toString(),
                      title: title,
                      shortDescription:
                          shortDescriptionController.text.trim().isEmpty
                              ? null
                              : shortDescriptionController.text.trim(),
                      fullDescription:
                          fullDescriptionController.text.trim().isEmpty
                              ? null
                              : fullDescriptionController.text.trim(),
                      category: categoryController.text.trim().isEmpty
                          ? null
                          : categoryController.text.trim(),
                      modality: modalityController.text.trim().isEmpty
                          ? null
                          : modalityController.text.trim(),
                      durationDays: durationDays,
                      price: price,
                      isActive: isActive,
                    );
                    if (!mounted) return;
                    if (ok) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Formation enregistrée.'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            provider.error ??
                                'Erreur lors de l\'enregistrement de la formation.',
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

  Future<void> _openRegistrationMessagesSheet(
    String registrationId,
    String studentName,
  ) async {
    final messagesProvider =
        context.read<AdminShortTrainingMessagesProvider>();
    await messagesProvider.loadMessages(registrationId);
    if (!mounted) return;

    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SizedBox(
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Messages avec l\'étudiant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (studentName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    studentName,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: Consumer<AdminShortTrainingMessagesProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading && provider.messages.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (provider.error != null &&
                          provider.messages.isEmpty) {
                        return Center(child: Text(provider.error!));
                      }

                      final messages = provider.messages;
                      if (messages.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Aucun message pour le moment. Utilisez le champ ci-dessous pour contacter l\'étudiant (organisation, paiement, etc.).',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final senderRole =
                              msg['sender_role']?.toString() ?? '';
                          final content =
                              msg['content']?.toString() ?? '';
                          final createdAt =
                              msg['created_at']?.toString() ?? '';

                          final isAdmin = senderRole == 'admin';
                          final alignment = isAdmin
                              ? Alignment.centerRight
                              : Alignment.centerLeft;
                          final color = isAdmin
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant;
                          final label =
                              isAdmin ? 'Vous' : 'Étudiant';

                          return Align(
                            alignment: alignment,
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(content),
                                  if (createdAt.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      createdAt,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText:
                              'Écrire un message à l\'étudiant (organisation, paiement, etc.)',
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
                        final ok = await messagesProvider.sendToStudent(
                          registrationId: registrationId,
                          content: text,
                        );
                        if (ok) {
                          controller.clear();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openRegistrationsDialog(String sessionId) async {
    final provider = context.read<AdminShortTrainingsProvider>();
    final registrations = await provider.loadRegistrations(sessionId);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Inscriptions à la session'),
          content: SizedBox(
            width: 500,
            child: registrations.isEmpty
                ? const Text('Aucune inscription pour cette session pour le moment.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: registrations.length,
                    itemBuilder: (context, index) {
                      final r = registrations[index];
                      final studentName = r['student_full_name']?.toString() ?? '';
                      final registrationId =
                          r['registration_id']?.toString() ?? '';
                      final profilePhone =
                          (r['contact_phone'] ?? r['student_profile_phone'] ?? '')
                              .toString();
                      final email = r['student_email']?.toString() ?? '';
                      final status = r['status']?.toString() ?? '';
                      final paymentMethod = r['payment_method']?.toString() ?? '';
                      final preferredChannel =
                          r['preferred_channel']?.toString() ?? '';
                      final wantsInvoice = r['wants_invoice'] == true;
                      final companyName = r['company_name']?.toString() ?? '';
                      final createdAt = r['created_at']?.toString() ?? '';

                      final details = <String>[
                        if (profilePhone.isNotEmpty) 'Tel: $profilePhone',
                        if (email.isNotEmpty) 'Email: $email',
                        if (paymentMethod.isNotEmpty) 'Paiement: $paymentMethod',
                        if (preferredChannel.isNotEmpty)
                          'Canal: $preferredChannel',
                        if (wantsInvoice) 'Facture souhaitée',
                        if (companyName.isNotEmpty) 'Entreprise: $companyName',
                        if (createdAt.isNotEmpty) 'Inscrit le: $createdAt',
                      ];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                studentName.isNotEmpty
                                    ? studentName
                                    : 'Étudiant inconnu',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Statut : $status'),
                              if (details.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  details.join(' · '),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              if ((r['notes']?.toString() ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  r['notes'].toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: registrationId.isEmpty
                                      ? null
                                      : () {
                                          _openRegistrationMessagesSheet(
                                            registrationId,
                                            studentName,
                                          );
                                        },
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: const Text('Messages'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSessionsSheet(Map<String, dynamic> training) async {
    final sessions = (training['sessions'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final trainingTitle = training['title']?.toString() ?? '';
    final trainingId = training['id']?.toString() ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SizedBox(
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sessions de la formation',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (trainingTitle.isNotEmpty)
                            Text(
                              trainingTitle,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: trainingId.isEmpty
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              _openSessionDialog(trainingId);
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('Nouvelle session'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: sessions.isEmpty
                      ? const Center(
                          child: Text('Aucune session créée pour cette formation.'),
                        )
                      : ListView.builder(
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final s = sessions[index];
                            final sessionId = s['id']?.toString() ?? '';
                            final startAt = s['start_at']?.toString() ?? '';
                            final endAt = s['end_at']?.toString() ?? '';
                            final location = s['location']?.toString() ?? '';
                            final capacity = s['capacity'];
                            final status = s['status']?.toString() ?? '';

                            final subtitleParts = <String>[
                              if (startAt.isNotEmpty) 'Début: $startAt',
                              if (endAt.isNotEmpty) 'Fin: $endAt',
                              if (location.isNotEmpty) location,
                              if (capacity != null) 'Capacité: $capacity',
                              if (status.isNotEmpty) 'Statut: $status',
                            ];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  startAt.isNotEmpty
                                      ? 'Session du $startAt'
                                      : 'Session',
                                ),
                                subtitle: Text(
                                  subtitleParts.join(' · '),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: sessionId.isEmpty
                                          ? null
                                          : () {
                                              _openRegistrationsDialog(sessionId);
                                            },
                                      child: const Text('Inscriptions'),
                                    ),
                                    TextButton(
                                      onPressed: trainingId.isEmpty
                                          ? null
                                          : () {
                                              Navigator.of(sheetContext).pop();
                                              _openSessionDialog(
                                                trainingId,
                                                session: s,
                                              );
                                            },
                                      child: const Text('Modifier'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSessionDialog(
    String trainingId, {
    Map<String, dynamic>? session,
  }) async {
    final provider = context.read<AdminShortTrainingsProvider>();
    final startAtController = TextEditingController(
      text: session?['start_at']?.toString() ?? '',
    );
    final endAtController = TextEditingController(
      text: session?['end_at']?.toString() ?? '',
    );
    final locationController = TextEditingController(
      text: session?['location']?.toString() ?? '',
    );
    final capacityController = TextEditingController(
      text: session?['capacity']?.toString() ?? '',
    );
    String status = session?['status']?.toString() ?? 'open';
    bool isActive = session == null ? true : session['is_active'] != false;
    final String? sessionId = session?['id']?.toString();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: Text(sessionId == null ? 'Nouvelle session' : 'Modifier la session'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: startAtController,
                      decoration: const InputDecoration(
                        labelText: 'Début (ex: 2025-12-01T10:00:00)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: endAtController,
                      decoration: const InputDecoration(
                        labelText:
                            'Fin (optionnelle, ex: 2025-12-01T12:00:00)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Lieu',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Capacité (optionnelle)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: 'Statut',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'open',
                          child: Text('Ouverte'),
                        ),
                        DropdownMenuItem(
                          value: 'closed',
                          child: Text('Fermée'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text('Annulée'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setStateDialog(() {
                          status = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (value) {
                        setStateDialog(() {
                          isActive = value;
                        });
                      },
                      title: const Text('Session active'),
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
                    final startText = startAtController.text.trim();
                    if (startText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Veuillez renseigner une date de début pour la session.',
                          ),
                        ),
                      );
                      return;
                    }

                    final startAt = _parseDateTimeFromInput(startText);
                    if (startAt == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Format de date invalide. Utilisez par exemple 2025-12-01T10:00:00 ou 01/12/2025 10:00.',
                          ),
                        ),
                      );
                      return;
                    }

                    final endText = endAtController.text.trim();
                    final endAt = endText.isEmpty
                        ? null
                        : _parseDateTimeFromInput(endText);
                    if (endText.isNotEmpty && endAt == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Format de date de fin invalide. Utilisez le même format que pour la date de début.',
                          ),
                        ),
                      );
                      return;
                    }

                    final capacityText = capacityController.text.trim();
                    final capacity = capacityText.isEmpty
                        ? null
                        : int.tryParse(capacityText);

                    final ok = await provider.upsertSession(
                      sessionId: sessionId,
                      trainingId: trainingId,
                      startAt: startAt,
                      endAt: endAt,
                      location: locationController.text.trim().isEmpty
                          ? null
                          : locationController.text.trim(),
                      capacity: capacity,
                      status: status,
                      isActive: isActive,
                    );
                    if (!mounted) return;
                    if (ok) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Session enregistrée.'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            provider.error ??
                                'Erreur lors de l\'enregistrement de la session.',
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminShortTrainingsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.trainings.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(child: Text(provider.error!));
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Formations courtes Nexium Group',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: ouvrir un formulaire de création/édition
                        _openTrainingDialog();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Nouvelle formation'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.trainings.length,
                    itemBuilder: (context, index) {
                      final training = provider.trainings[index];
                      final title = training['title']?.toString() ?? '';
                      final category = training['category']?.toString() ?? '';
                      final modality = training['modality']?.toString() ?? '';
                      final durationDays = training['duration_days'];
                      final isActive = training['is_active'] == true;
                      final sessions = (training['sessions'] as List<dynamic>? ?? [])
                          .cast<Map<String, dynamic>>();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [category, modality]
                                              .where((e) => e.isNotEmpty)
                                              .join(' · '),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (!isActive)
                                    const Chip(
                                      label: Text('Inactif'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (durationDays != null)
                                Text(
                                  'Durée : $durationDays jour(s)',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      _openTrainingDialog(training: training);
                                    },
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Modifier la formation'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () {
                                      _openSessionsSheet(training);
                                    },
                                    icon: const Icon(Icons.event),
                                    label:
                                        Text('Sessions (${sessions.length})'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) {
                                          return AlertDialog(
                                            title: const Text(
                                                'Supprimer la formation courte'),
                                            content: Text(
                                              "Cette formation sera retirée de la plateforme côté étudiant (elle ne sera plus proposée dans les formations courtes).\n\nTitre : " +
                                                  title,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(dialogContext)
                                                        .pop(false),
                                                child: const Text('Annuler'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(dialogContext)
                                                        .pop(true),
                                                child: const Text(
                                                  'Supprimer',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (confirmed != true) return;

                                      final ok = await provider
                                          .deleteTraining(training);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            ok
                                                ? 'Formation supprimée (non visible côté étudiant).'
                                                : provider.error ??
                                                    'Erreur lors de la suppression de la formation.',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                    label: const Text('Supprimer'),
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
            ),
          ),
        );
      },
    );
  }
}
