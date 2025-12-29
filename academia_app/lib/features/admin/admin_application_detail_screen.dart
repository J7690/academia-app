import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_application_messages_provider.dart';
import '../../providers/admin_applications_provider.dart';
import '../../providers/admin_application_payments_provider.dart';

class AdminApplicationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> application;

  const AdminApplicationDetailScreen({super.key, required this.application});

  @override
  State<AdminApplicationDetailScreen> createState() => _AdminApplicationDetailScreenState();
}

class _AdminApplicationDetailScreenState extends State<AdminApplicationDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  String _target = 'student';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appId = widget.application['id']?.toString();
      if (appId != null && appId.isNotEmpty) {
        context.read<AdminApplicationMessagesProvider>().loadMessages(appId);
        try {
          context
              .read<AdminApplicationPaymentsProvider>()
              .loadPaymentsForApplication(appId);
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    try {
      context.read<AdminApplicationsProvider>().loadApplications();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _showEditPreferencesDialog(BuildContext context) async {
    final app = widget.application;
    final initialDegree =
        (app['requested_degree_level']?.toString() ?? '').trim();
    final initialMode =
        (app['requested_study_mode']?.toString() ?? '').trim();
    final initialSchedule =
        (app['requested_schedule']?.toString() ?? '').trim();
    final initialDiscountRequested = app['discount_requested'] == true;
    final initialDiscountDetails =
        (app['discount_details']?.toString() ?? '').trim();

    final degreeController = TextEditingController(text: initialDegree);
    final modeController = TextEditingController(text: initialMode);
    final scheduleController = TextEditingController(text: initialSchedule);
    final discountDetailsController =
        TextEditingController(text: initialDiscountDetails);

    bool discountRequested = initialDiscountRequested;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifier les préférences de candidature'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: degreeController,
                      decoration: const InputDecoration(
                        labelText: "Niveau d'étude souhaité",
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: modeController,
                      decoration: const InputDecoration(
                        labelText:
                            "Mode d'étude souhaité (présentiel, en ligne, etc.)",
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: scheduleController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Disponibilités / horaires préférés',
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: discountRequested,
                      onChanged: (value) {
                        setState(() {
                          discountRequested = value ?? false;
                        });
                      },
                      title: const Text(
                        'Demande de réduction ou échelonnement des frais',
                      ),
                    ),
                    if (discountRequested) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: discountDetailsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText:
                              'Détail de la demande de réduction / échelonnement',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final appId = app['id']?.toString();
                    if (appId == null || appId.isEmpty) {
                      Navigator.of(context).pop();
                      return;
                    }

                    final provider =
                        context.read<AdminApplicationsProvider>();
                    final ok = await provider.updateApplicationPreferences(
                      applicationId: appId,
                      requestedDegreeLevel: degreeController.text,
                      requestedStudyMode: modeController.text,
                      requestedSchedule: scheduleController.text,
                      discountRequested: discountRequested,
                      discountDetails: discountDetailsController.text,
                    );

                    if (!mounted) return;
                    if (ok) {
                      setState(() {
                        app['requested_degree_level'] =
                            degreeController.text.trim();
                        app['requested_study_mode'] =
                            modeController.text.trim();
                        app['requested_schedule'] =
                            scheduleController.text.trim();
                        app['discount_requested'] = discountRequested;
                        app['discount_details'] =
                            discountDetailsController.text.trim();
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Préférences de candidature mises à jour.',
                          ),
                        ),
                      );
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            provider.error ??
                                'Erreur lors de la mise à jour des préférences.',
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
    final app = widget.application;
    final studentName = app['student_full_name']?.toString() ?? '';
    final programTitle = app['program_title']?.toString() ?? '';
    final universityName = app['university_name']?.toString() ?? '';
    final status = app['status']?.toString() ?? '';
    final sentToUniversity = app['sent_to_university'] == true;
    final sentToUniversityAt =
        (app['sent_to_university_at']?.toString() ?? '').trim();
    final requestedDegree =
        (app['requested_degree_level']?.toString() ?? '').trim();
    final requestedMode =
        (app['requested_study_mode']?.toString() ?? '').trim();
    final requestedSchedule =
        (app['requested_schedule']?.toString() ?? '').trim();
    final discountRequested = app['discount_requested'] == true;
    final discountDetails =
        (app['discount_details']?.toString() ?? '').trim();
    final studentComment =
        (app['student_comment']?.toString() ?? '').trim();
    final hasPreferencesSection =
        requestedDegree.isNotEmpty ||
        requestedMode.isNotEmpty ||
        requestedSchedule.isNotEmpty ||
        discountRequested ||
        studentComment.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Candidature - Admin'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(programTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(universityName),
                const SizedBox(height: 4),
                Text('Étudiant : $studentName'),
                const SizedBox(height: 4),
                Text('Statut : $status'),
                const SizedBox(height: 4),
                Text(
                  sentToUniversity
                      ? (sentToUniversityAt.isNotEmpty
                          ? "Transmise à l'université le $sentToUniversityAt"
                          : "Transmise à l'université")
                      : "Pas encore transmise à l'université",
                ),
                const SizedBox(height: 12),
                Consumer<AdminApplicationPaymentsProvider>(
                  builder: (context, paymentsProvider, child) {
                    final appId = app['id']?.toString();
                    final payments = paymentsProvider.payments;

                    Widget content;
                    if (paymentsProvider.isLoading && payments.isEmpty) {
                      content = const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: LinearProgressIndicator(minHeight: 2),
                      );
                    } else if (paymentsProvider.error != null) {
                      content = Text(
                        'Erreur paiements : ${paymentsProvider.error}',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      );
                    } else if (payments.isEmpty) {
                      content = const Text(
                        'Aucun paiement enregistré pour cette candidature.',
                        style: TextStyle(fontSize: 13),
                      );
                    } else {
                      content = Column(
                        children: payments.map((p) {
                          final amountDue = p['amount_due']?.toString() ?? '';
                          final amountPaid = p['amount_paid']?.toString() ?? '';
                          final channel = p['channel']?.toString() ?? '';
                          final payStatus = p['status']?.toString() ?? '';
                          final ref = p['reference_code']?.toString() ?? '';
                          final extRef = p['external_reference']?.toString() ?? '';
                          final payId = p['id']?.toString() ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Paiement ${payId.isNotEmpty ? payId.substring(0, 8) : ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        payStatus,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (amountDue.isNotEmpty)
                                    Text('Montant dû : $amountDue XOF'),
                                  if (amountPaid.isNotEmpty)
                                    Text('Montant payé déclaré : $amountPaid XOF'),
                                  if (channel.isNotEmpty)
                                    Text('Canal : $channel'),
                                  if (ref.isNotEmpty)
                                    Text('Référence plateforme : $ref'),
                                  if (extRef.isNotEmpty)
                                    Text('Référence externe : $extRef'),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: appId == null ||
                                                appId.isEmpty ||
                                                payId.isEmpty
                                            ? null
                                            : () async {
                                                final ok = await paymentsProvider
                                                    .verifyPayment(
                                                  paymentId: payId,
                                                  decision: 'valid',
                                                  comment: null,
                                                  applicationId: appId,
                                                );
                                                if (!mounted) return;
                                                if (!ok) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        paymentsProvider
                                                                .error ??
                                                            'Erreur lors de la validation du paiement.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                        icon: const Icon(Icons.verified),
                                        label: const Text('Valider'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: appId == null ||
                                                appId.isEmpty ||
                                                payId.isEmpty
                                            ? null
                                            : () async {
                                                final ok = await paymentsProvider
                                                    .verifyPayment(
                                                  paymentId: payId,
                                                  decision: 'invalid',
                                                  comment: null,
                                                  applicationId: appId,
                                                );
                                                if (!mounted) return;
                                                if (!ok) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        paymentsProvider
                                                                .error ??
                                                            'Erreur lors du rejet du paiement.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                        icon: const Icon(Icons.clear),
                                        label: const Text('Rejeter'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: appId == null ||
                                                appId.isEmpty ||
                                                payId.isEmpty
                                            ? null
                                            : () async {
                                                final ok = await paymentsProvider
                                                    .confirmPayment(
                                                  paymentId: payId,
                                                  applicationId: appId,
                                                );
                                                if (!mounted) return;
                                                if (ok) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Paiement confirmé et reçu généré.',
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        paymentsProvider
                                                                .error ??
                                                            'Erreur lors de la confirmation du paiement.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                        icon: const Icon(Icons.receipt_long),
                                        label: const Text('Confirmer + reçu'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Paiements liés à la candidature',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            content,
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (hasPreferencesSection) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Préférences de candidature',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (requestedDegree.isNotEmpty)
                            Text('Niveau souhaité : $requestedDegree'),
                          if (requestedMode.isNotEmpty)
                            Text('Mode souhaité : $requestedMode'),
                          if (requestedSchedule.isNotEmpty)
                            Text('Horaires souhaités : $requestedSchedule'),
                          if (discountRequested) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Demande de réduction / échelonnement des frais',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (discountDetails.isNotEmpty)
                              Text(discountDetails),
                          ],
                          if (studentComment.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Commentaire de l\'étudiant',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(studentComment),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          _showEditPreferencesDialog(context);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Modifier les préférences'),
                      ),
                      const SizedBox(width: 8),
                      if (!sentToUniversity)
                        ElevatedButton.icon(
                          onPressed: () async {
                            final appId = app['id']?.toString();
                            if (appId == null || appId.isEmpty) return;

                            final provider =
                                context.read<AdminApplicationsProvider>();
                            final ok = await provider
                                .forwardApplicationToUniversity(
                              applicationId: appId,
                            );

                            if (!mounted) return;
                            if (ok) {
                              setState(() {
                                app['sent_to_university'] = true;
                                app['sent_to_university_at'] =
                                    DateTime.now().toIso8601String();
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Candidature transmise à l'université.",
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.error ??
                                        "Erreur lors de la transmission de la candidature à l'université.",
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.send),
                          label: const Text("Transmettre à l'université"),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<AdminApplicationMessagesProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return Center(child: Text('Erreur : ${provider.error}'));
                }

                final messages = provider.messages;
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Aucun message pour le moment. Utilisez le champ ci-dessous pour répondre à l\'étudiant ou contacter l\'université.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final senderRole = msg['sender_role']?.toString() ?? '';
                    final audience = msg['audience']?.toString() ?? '';
                    final content = msg['content']?.toString() ?? '';
                    final createdAtMsg = msg['created_at']?.toString() ?? '';

                    String label;
                    Alignment alignment;
                    Color color;

                    if (senderRole == 'student') {
                      label = 'Étudiant';
                      alignment = Alignment.centerLeft;
                      color = Colors.blue.withOpacity(0.1);
                    } else if (senderRole == 'university') {
                      label = 'Université';
                      alignment = Alignment.centerLeft;
                      color = Colors.green.withOpacity(0.1);
                    } else {
                      if (audience == 'student') {
                        label = 'Vous → Étudiant';
                      } else if (audience == 'university') {
                        label = 'Vous → Université';
                      } else {
                        label = 'Vous';
                      }
                      alignment = Alignment.centerRight;
                      color = Theme.of(context).colorScheme.primary.withOpacity(0.1);
                    }

                    return Align(
                      alignment: alignment,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(content),
                            if (createdAtMsg.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                createdAtMsg,
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _target,
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('→ Étudiant')),
                    DropdownMenuItem(value: 'university', child: Text('→ Université')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _target = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    final appId = widget.application['id']?.toString();
                    if (appId == null || appId.isEmpty) return;
                    final text = _messageController.text.trim();
                    if (text.isEmpty) return;

                    final provider = context.read<AdminApplicationMessagesProvider>();
                    bool ok;
                    if (_target == 'student') {
                      ok = await provider.sendToStudent(applicationId: appId, content: text);
                    } else {
                      ok = await provider.sendToUniversity(applicationId: appId, content: text);
                    }

                    if (!mounted) return;
                    if (ok) {
                      _messageController.clear();
                      try {
                        await context.read<AdminApplicationsProvider>().loadApplications();
                      } catch (_) {}
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            provider.error ?? 'Erreur lors de l\'envoi du message.',
                          ),
                        ),
                      );
                    }
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
