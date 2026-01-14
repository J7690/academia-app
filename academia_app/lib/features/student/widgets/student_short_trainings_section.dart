import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_short_trainings_provider.dart';
import '../../../providers/student_profile_provider.dart';
import '../../../providers/student_short_training_messages_provider.dart';
import '../../../providers/student_home_slots_provider.dart';

class StudentShortTrainingsSection extends StatefulWidget {
  const StudentShortTrainingsSection({super.key});

  @override
  State<StudentShortTrainingsSection> createState() => _StudentShortTrainingsSectionState();
}

class _StudentShortTrainingsSectionState extends State<StudentShortTrainingsSection> {
  Future<void> _openMessagesSheet(String registrationId, String title) async {
    final messagesProvider =
        context.read<StudentShortTrainingMessagesProvider>();
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
            height: 380,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Messages avec Nexium Group',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: Consumer<StudentShortTrainingMessagesProvider>(
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
                              'Aucun message pour le moment. Utilisez le champ ci-dessous pour poser vos questions (organisation, paiement, etc.).',
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

                          final isStudent = senderRole == 'student';
                          final alignment = isStudent
                              ? Alignment.centerRight
                              : Alignment.centerLeft;
                          final color = isStudent
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant;
                          final label =
                              isStudent ? 'Vous' : 'Nexium / Plateforme';

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
                              'Écrire un message (organisation, paiement, etc.)',
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
                        final ok = await messagesProvider.sendMessage(
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
  Future<void> _openRegistrationDialog(
    BuildContext context,
    Map<String, dynamic> session,
  ) async {
    final trainingsProvider = context.read<StudentShortTrainingsProvider>();
    final profileProvider = context.read<StudentProfileProvider>();
    final profile = profileProvider.profile;
    final phoneFromProfile = profile?['phone']?.toString() ?? '';

    final phoneController = TextEditingController(text: phoneFromProfile);
    final companyController = TextEditingController();
    final notesController = TextEditingController();

    String? preferredChannel;
    String? paymentMethod;
    bool wantsInvoice = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final title = session['title']?.toString() ?? '';
        final startAt = session['start_at']?.toString() ?? '';
        final location = session['location']?.toString() ?? '';
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: const Text('Confirmation d\'inscription'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (startAt.isNotEmpty || location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text([
                        if (startAt.isNotEmpty) startAt,
                        if (location.isNotEmpty) location,
                      ].join(' · ')),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        hintText: 'Numéro où Nexium peut vous joindre',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: preferredChannel,
                      decoration: const InputDecoration(
                        labelText: 'Canal de contact préféré',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'whatsapp',
                          child: Text('WhatsApp'),
                        ),
                        DropdownMenuItem(
                          value: 'phone',
                          child: Text('Appel téléphonique'),
                        ),
                        DropdownMenuItem(
                          value: 'email',
                          child: Text('Email'),
                        ),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          preferredChannel = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Mode de paiement prévu',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'mobile_money',
                          child: Text('Mobile money'),
                        ),
                        DropdownMenuItem(
                          value: 'cash',
                          child: Text('Espèces sur place'),
                        ),
                        DropdownMenuItem(
                          value: 'bank_transfer',
                          child: Text('Virement bancaire'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('Autre'),
                        ),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          paymentMethod = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: wantsInvoice,
                      onChanged: (value) {
                        setStateDialog(() {
                          wantsInvoice = value;
                        });
                      },
                      title: const Text('Souhaite une facture'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: companyController,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'entreprise (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Message pour Nexium (optionnel)',
                      ),
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
                    final sessionId = session['session_id']?.toString() ?? '';
                    if (sessionId.isEmpty) {
                      Navigator.of(dialogContext).pop();
                      return;
                    }

                    final ok = await trainingsProvider.registerForSessionWithDetails(
                      sessionId: sessionId,
                      contactPhone: phoneController.text.trim().isEmpty
                          ? null
                          : phoneController.text.trim(),
                      preferredChannel: preferredChannel,
                      paymentMethod: paymentMethod,
                      wantsInvoice: wantsInvoice,
                      companyName: companyController.text.trim().isEmpty
                          ? null
                          : companyController.text.trim(),
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                    );

                    if (!mounted) return;
                    Navigator.of(dialogContext).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Inscription enregistrée.'
                              : trainingsProvider.error ??
                                  'Erreur lors de l\'inscription.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Valider mon inscription'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<StudentShortTrainingsProvider>();
      await provider.loadPublicSessions();
      await provider.loadMyTrainings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Consumer<StudentShortTrainingsProvider>(
          builder: (context, provider, child) {
            final slotsProvider = context.watch<StudentHomeSlotsProvider>();
            final slotItems =
                slotsProvider.getItemsForSlot('desktop_short_trainings');

            List<Map<String, dynamic>> sessions;
            if (slotItems.isNotEmpty) {
              sessions = slotItems
                  .map((item) => item['short_training_session'])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList(growable: false);
            } else {
              sessions = provider.publicSessions;
            }

            if (provider.isLoading && sessions.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.error != null && sessions.isEmpty) {
              return Center(child: Text(provider.error!));
            }

            if (sessions.isEmpty) {
              return const SizedBox.shrink();
            }

            final width = constraints.maxWidth;
            final crossAxisCount = width >= 1100
                ? 3
                : width >= 700
                    ? 2
                    : 1;
            const spacing = 12.0;
            final cardWidth = crossAxisCount == 1
                ? width
                : (width - (crossAxisCount - 1) * spacing) / crossAxisCount;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Formations courtes Nexium Group',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: sessions.take(5).map((session) {
                    final title = session['title']?.toString() ?? '';
                    final category = session['category']?.toString() ?? '';
                    final modality = session['modality']?.toString() ?? '';
                    final location = session['location']?.toString() ?? '';
                    final startAt = session['start_at']?.toString() ?? '';
                    final sessionId = session['session_id']?.toString() ?? '';
                    final dynamic rawPrice = session['price'];
                    num priceValue;
                    if (rawPrice is num) {
                      priceValue = rawPrice;
                    } else {
                      priceValue = 0;
                    }
                    final bool isInt = priceValue % 1 == 0;
                    final String formattedPrice =
                        isInt ? priceValue.toInt().toString() : priceValue.toString();

                    final metaParts = <String>[
                      if (category.isNotEmpty) category,
                      if (modality.isNotEmpty) modality,
                      if (location.isNotEmpty) location,
                      if (startAt.isNotEmpty) startAt,
                    ];

                    return SizedBox(
                      width: cardWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0D000000),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0x80F6A623),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0A2540),
                                ),
                              ),
                              if (metaParts.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  metaParts.join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                'Frais de participation : $formattedPrice FCFA',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF3275D0),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: sessionId.isEmpty
                                      ? null
                                      : () {
                                          _openRegistrationDialog(context, session);
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3275D0),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('S\'inscrire'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (provider.myTrainings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Mes inscriptions aux formations courtes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: provider.myTrainings.map((registration) {
                      final regTitle = registration['title']?.toString() ?? '';
                      final regLocation =
                          registration['location']?.toString() ?? '';
                      final regStartAt =
                          registration['start_at']?.toString() ?? '';
                      final regStatus =
                          registration['status']?.toString() ?? '';
                      final registrationId =
                          registration['registration_id']?.toString() ?? '';

                      final lastMessageAtStr =
                          registration['last_message_at']?.toString();
                      final lastReadAtStr =
                          registration['student_last_read_at']?.toString();
                      DateTime? lastMessageAt;
                      DateTime? lastReadAt;
                      if (lastMessageAtStr != null && lastMessageAtStr.isNotEmpty) {
                        lastMessageAt = DateTime.tryParse(lastMessageAtStr);
                      }
                      if (lastReadAtStr != null && lastReadAtStr.isNotEmpty) {
                        lastReadAt = DateTime.tryParse(lastReadAtStr);
                      }
                      final hasNewMessages = lastMessageAt != null &&
                          (lastReadAt == null || lastMessageAt.isAfter(lastReadAt));

                      final subtitleParts = <String>[
                        if (regLocation.isNotEmpty) regLocation,
                        if (regStartAt.isNotEmpty) regStartAt,
                        if (regStatus.isNotEmpty) 'Statut: $regStatus',
                      ];

                      return SizedBox(
                        width: cardWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D000000),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0x80F6A623),
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  regTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0A2540),
                                  ),
                                ),
                                if (subtitleParts.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitleParts
                                        .where((e) => e.isNotEmpty)
                                        .join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (regStatus.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.blueGrey.withOpacity(0.06),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          regStatus,
                                          style: const TextStyle(
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: registrationId.isEmpty
                                          ? null
                                          : () {
                                              _openMessagesSheet(
                                                registrationId,
                                                regTitle,
                                              );
                                            },
                                      icon:
                                          const Icon(Icons.chat_bubble_outline),
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('Messages'),
                                          if (hasNewMessages) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFFF3B30),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
