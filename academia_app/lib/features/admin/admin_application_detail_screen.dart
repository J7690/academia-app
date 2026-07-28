import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_application_messages_provider.dart';
import '../../providers/admin_applications_provider.dart';
import '../../providers/admin_application_payments_provider.dart';
import '../../utils/responsive.dart';
import '../../widgets/adaptive_dialog.dart';
import 'admin_application_status.dart';

/// Seuil à partir duquel on bascule sur un affichage deux colonnes
/// (informations à gauche, conversation à droite).
const double _kTwoPaneBreakpoint = 900;

class AdminApplicationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> application;

  const AdminApplicationDetailScreen({super.key, required this.application});

  @override
  State<AdminApplicationDetailScreen> createState() =>
      _AdminApplicationDetailScreenState();
}

class _AdminApplicationDetailScreenState
    extends State<AdminApplicationDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  // Contrôleurs explicites : évite toute ambiguïté quand plusieurs zones
  // défilantes cohabitent (panneau d'infos + conversation).
  final ScrollController _infoScrollController = ScrollController();
  final ScrollController _messagesScrollController = ScrollController();
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
    _infoScrollController.dispose();
    _messagesScrollController.dispose();
    try {
      context.read<AdminApplicationsProvider>().loadApplications();
    } catch (_) {}
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Boîte de dialogue « Modifier les préférences » — désormais adaptative :
  // contenu scrollable, hauteur limitée à l'espace réellement disponible,
  // boutons Annuler / Enregistrer toujours visibles même clavier ouvert.
  // ---------------------------------------------------------------------
  Future<void> _showEditPreferencesDialog(BuildContext context) async {
    final app = widget.application;

    final degreeController = TextEditingController(
      text: (app['requested_degree_level']?.toString() ?? '').trim(),
    );
    final modeController = TextEditingController(
      text: (app['requested_study_mode']?.toString() ?? '').trim(),
    );
    final scheduleController = TextEditingController(
      text: (app['requested_schedule']?.toString() ?? '').trim(),
    );
    final discountDetailsController = TextEditingController(
      text: (app['discount_details']?.toString() ?? '').trim(),
    );

    bool discountRequested = app['discount_requested'] == true;
    bool saving = false;

    await showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AdaptiveDialog(
              title: const Text('Modifier les préférences de candidature'),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final appId = app['id']?.toString();
                          if (appId == null || appId.isEmpty) {
                            Navigator.of(dialogContext).pop();
                            return;
                          }

                          setDialogState(() => saving = true);

                          final provider =
                              context.read<AdminApplicationsProvider>();
                          final messenger = ScaffoldMessenger.of(context);
                          final ok =
                              await provider.updateApplicationPreferences(
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

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Préférences de candidature mises à jour.',
                                ),
                              ),
                            );
                            if (Navigator.of(dialogContext).canPop()) {
                              Navigator.of(dialogContext).pop();
                            }
                          } else {
                            setDialogState(() => saving = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  provider.error ??
                                      'Erreur lors de la mise à jour des préférences.',
                                ),
                              ),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: degreeController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: "Niveau d'étude souhaité",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: modeController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText:
                          "Mode d'étude souhaité (présentiel, en ligne, etc.)",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scheduleController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Disponibilités / horaires préférés',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: discountRequested,
                    onChanged: (value) {
                      setDialogState(() => discountRequested = value ?? false);
                    },
                    title: const Text(
                      'Demande de réduction ou échelonnement des frais',
                    ),
                  ),
                  if (discountRequested) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: discountDetailsController,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText:
                            'Détail de la demande de réduction / échelonnement',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );

    degreeController.dispose();
    modeController.dispose();
    scheduleController.dispose();
    discountDetailsController.dispose();
  }

  Future<void> _forwardToUniversity() async {
    final app = widget.application;
    final appId = app['id']?.toString();
    if (appId == null || appId.isEmpty) return;

    final provider = context.read<AdminApplicationsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok =
        await provider.forwardApplicationToUniversity(applicationId: appId);

    if (!mounted) return;
    if (ok) {
      setState(() {
        app['sent_to_university'] = true;
        app['sent_to_university_at'] = DateTime.now().toIso8601String();
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Candidature transmise à l'université."),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            provider.error ??
                "Erreur lors de la transmission de la candidature à l'université.",
          ),
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    final appId = widget.application['id']?.toString();
    if (appId == null || appId.isEmpty) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<AdminApplicationMessagesProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final bool ok = _target == 'student'
        ? await provider.sendToStudent(applicationId: appId, content: text)
        : await provider.sendToUniversity(applicationId: appId, content: text);

    if (!mounted) return;
    if (ok) {
      _messageController.clear();
      try {
        await context.read<AdminApplicationsProvider>().loadApplications();
      } catch (_) {}
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? "Erreur lors de l'envoi du message.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Le corps se redimensionne quand le clavier s'ouvre : le composeur
      // reste visible au lieu d'être poussé hors écran.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Candidature - Admin'),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _kTwoPaneBreakpoint;
            return isWide
                ? _buildTwoPane(context, constraints)
                : _buildSinglePane(context, constraints);
          },
        ),
      ),
    );
  }

  // -------------------------- Téléphone / tablette étroite -----------------
  Widget _buildSinglePane(BuildContext context, BoxConstraints constraints) {
    // Le panneau d'informations est repliable et son contenu déplié est
    // limité à une fraction de la hauteur disponible : il ne peut plus
    // écraser la conversation ni déborder de l'écran.
    final infoMaxHeight = math.max(180.0, constraints.maxHeight * 0.55);

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: EdgeInsets.zero,
              title: _buildCompactSummary(context),
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: infoMaxHeight),
                  child: Scrollbar(
                    controller: _infoScrollController,
                    child: SingleChildScrollView(
                      controller: _infoScrollController,
                      primary: false,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _buildInfoContent(context, compact: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildMessagesList(context)),
        _buildComposer(context, compact: true),
      ],
    );
  }

  // -------------------------- Ordinateur / grand écran ---------------------
  Widget _buildTwoPane(BuildContext context, BoxConstraints constraints) {
    // Largeur du panneau gauche : proportionnelle, bornée. Pas de valeur figée.
    final double infoWidth = constraints.maxWidth * 0.34;
    final double clampedInfoWidth =
        math.min(460.0, math.max(320.0, infoWidth));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: clampedInfoWidth,
          child: Scrollbar(
            controller: _infoScrollController,
            child: SingleChildScrollView(
              controller: _infoScrollController,
              primary: false,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompactSummary(context),
                  const SizedBox(height: 16),
                  _buildInfoContent(context, compact: false),
                ],
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Expanded(child: _buildMessagesList(context)),
              _buildComposer(context, compact: false),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------- Blocs ----------------------------------
  Widget _buildCompactSummary(BuildContext context) {
    final app = widget.application;
    final theme = Theme.of(context);
    final status = app['status']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          app['program_title']?.toString() ?? 'Programme inconnu',
          style: theme.textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          app['university_name']?.toString() ?? '',
          style: theme.textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Pill(
              label: adminStatusLabel(status),
              color: adminStatusColor(status),
            ),
            _Pill(
              label: 'Étudiant : ${app['student_full_name'] ?? '—'}',
              color: const Color(0xFF6B7280),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoContent(BuildContext context, {required bool compact}) {
    final app = widget.application;
    final sentToUniversity = app['sent_to_university'] == true;
    final sentToUniversityAt =
        (app['sent_to_university_at']?.toString() ?? '').trim();
    final requestedDegree =
        (app['requested_degree_level']?.toString() ?? '').trim();
    final requestedMode = (app['requested_study_mode']?.toString() ?? '').trim();
    final requestedSchedule =
        (app['requested_schedule']?.toString() ?? '').trim();
    final discountRequested = app['discount_requested'] == true;
    final discountDetails = (app['discount_details']?.toString() ?? '').trim();
    final studentComment = (app['student_comment']?.toString() ?? '').trim();
    final hasPreferencesSection = requestedDegree.isNotEmpty ||
        requestedMode.isNotEmpty ||
        requestedSchedule.isNotEmpty ||
        discountRequested ||
        studentComment.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          sentToUniversity
              ? (sentToUniversityAt.isNotEmpty
                  ? "Transmise à l'université le $sentToUniversityAt"
                  : "Transmise à l'université")
              : "Pas encore transmise à l'université",
          style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
        ),
        const SizedBox(height: 12),
        _buildPaymentsSection(context, compact: compact),
        if (hasPreferencesSection) ...[
          const SizedBox(height: 16),
          Text(
            'Préférences de candidature',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                    if (discountDetails.isNotEmpty) Text(discountDetails),
                  ],
                  if (studentComment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      "Commentaire de l'étudiant",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(studentComment),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Les actions se replient toujours sur plusieurs lignes si besoin.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => _showEditPreferencesDialog(context),
              icon: const Icon(Icons.edit),
              label: const Text('Modifier les préférences'),
            ),
            if (!sentToUniversity)
              ElevatedButton.icon(
                onPressed: _forwardToUniversity,
                icon: const Icon(Icons.send),
                label: const Text("Transmettre à l'université"),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentsSection(BuildContext context, {required bool compact}) {
    return Consumer<AdminApplicationPaymentsProvider>(
      builder: (context, paymentsProvider, child) {
        final appId = widget.application['id']?.toString();
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
            mainAxisSize: MainAxisSize.min,
            children: payments.map((p) {
              return _PaymentCard(
                payment: p,
                applicationId: appId,
                provider: paymentsProvider,
                onFeedback: (message) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                },
              );
            }).toList(),
          );
        }

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Paiements liés à la candidature',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                content,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessagesList(BuildContext context) {
    return Consumer<AdminApplicationMessagesProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.messages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Erreur : ${provider.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final messages = provider.messages;
        if (messages.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                "Aucun message pour le moment. Utilisez le champ ci-dessous pour répondre à l'étudiant ou contacter l'université.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            // Largeur maximale d'une bulle : proportion de la largeur réelle.
            final bubbleMaxWidth = constraints.maxWidth *
                (constraints.maxWidth < AppBreakpoints.mobile ? 0.86 : 0.7);

            return ListView.builder(
              controller: _messagesScrollController,
              primary: false,
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < AppBreakpoints.mobile
                    ? 12
                    : 20,
                vertical: 12,
              ),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return _MessageBubble(
                  message: messages[index],
                  maxWidth: bubbleMaxWidth,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildComposer(BuildContext context, {required bool compact}) {
    final destinationSelector = DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _target,
        isDense: true,
        borderRadius: BorderRadius.circular(12),
        items: const [
          DropdownMenuItem(value: 'student', child: Text('→ Étudiant')),
          DropdownMenuItem(value: 'university', child: Text('→ Université')),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => _target = value);
        },
      ),
    );

    final field = TextField(
      controller: _messageController,
      minLines: 1,
      maxLines: 5,
      textInputAction: TextInputAction.newline,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(
        hintText: 'Écrire un message...',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );

    final sendButton = IconButton.filled(
      icon: const Icon(Icons.send),
      tooltip: 'Envoyer',
      onPressed: _sendMessage,
    );

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(compact ? 8 : 16, 8, compact ? 8 : 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Sous ~420 px, le sélecteur passe sur sa propre ligne pour
              // laisser au champ de saisie une largeur utilisable.
              if (constraints.maxWidth < 420) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: destinationSelector,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: field),
                        const SizedBox(width: 8),
                        sendButton,
                      ],
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: destinationSelector,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: field),
                  const SizedBox(width: 8),
                  sendButton,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets d'appoint
// ---------------------------------------------------------------------------

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.maxWidth});

  final Map<String, dynamic> message;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final senderRole = message['sender_role']?.toString() ?? '';
    final audience = message['audience']?.toString() ?? '';
    final content = message['content']?.toString() ?? '';
    final createdAtMsg = message['created_at']?.toString() ?? '';

    String label;
    Alignment alignment;
    Color color;

    if (senderRole == 'student') {
      label = 'Étudiant';
      alignment = Alignment.centerLeft;
      color = Colors.blue.withValues(alpha: 0.1);
    } else if (senderRole == 'university') {
      label = 'Université';
      alignment = Alignment.centerLeft;
      color = Colors.green.withValues(alpha: 0.1);
    } else {
      if (audience == 'student') {
        label = 'Vous → Étudiant';
      } else if (audience == 'university') {
        label = 'Vous → Université';
      } else {
        label = 'Vous';
      }
      alignment = Alignment.centerRight;
      color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
    }

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(content),
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
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.applicationId,
    required this.provider,
    required this.onFeedback,
  });

  final Map<String, dynamic> payment;
  final String? applicationId;
  final AdminApplicationPaymentsProvider provider;
  final void Function(String message) onFeedback;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final amountDue = p['amount_due']?.toString() ?? '';
    final amountPaid = p['amount_paid']?.toString() ?? '';
    final channel = p['channel']?.toString() ?? '';
    final payStatus = p['status']?.toString() ?? '';
    final ref = p['reference_code']?.toString() ?? '';
    final extRef = p['external_reference']?.toString() ?? '';
    final payId = p['id']?.toString() ?? '';
    final shortId = payId.isNotEmpty
        ? payId.substring(0, math.min(8, payId.length))
        : '';

    final enabled = applicationId != null &&
        applicationId!.isNotEmpty &&
        payId.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Paiement $shortId',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(payStatus, style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            if (amountDue.isNotEmpty) Text('Montant dû : $amountDue XOF'),
            if (amountPaid.isNotEmpty)
              Text('Montant payé déclaré : $amountPaid XOF'),
            if (channel.isNotEmpty) Text('Canal : $channel'),
            if (ref.isNotEmpty)
              Text('Référence plateforme : $ref',
                  softWrap: true, overflow: TextOverflow.visible),
            if (extRef.isNotEmpty)
              Text('Référence externe : $extRef',
                  softWrap: true, overflow: TextOverflow.visible),
            const SizedBox(height: 8),
            // Les trois actions se replient ligne par ligne sur téléphone.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: !enabled
                      ? null
                      : () async {
                          final ok = await provider.verifyPayment(
                            paymentId: payId,
                            decision: 'valid',
                            comment: null,
                            applicationId: applicationId!,
                          );
                          if (!ok) {
                            onFeedback(provider.error ??
                                'Erreur lors de la validation du paiement.');
                          }
                        },
                  icon: const Icon(Icons.verified, size: 18),
                  label: const Text('Valider'),
                ),
                OutlinedButton.icon(
                  onPressed: !enabled
                      ? null
                      : () async {
                          final ok = await provider.verifyPayment(
                            paymentId: payId,
                            decision: 'invalid',
                            comment: null,
                            applicationId: applicationId!,
                          );
                          if (!ok) {
                            onFeedback(provider.error ??
                                'Erreur lors du rejet du paiement.');
                          }
                        },
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Rejeter'),
                ),
                ElevatedButton.icon(
                  onPressed: !enabled
                      ? null
                      : () async {
                          final ok = await provider.confirmPayment(
                            paymentId: payId,
                            applicationId: applicationId!,
                          );
                          onFeedback(ok
                              ? 'Paiement confirmé et reçu généré.'
                              : (provider.error ??
                                  'Erreur lors de la confirmation du paiement.'));
                        },
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Confirmer + reçu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
