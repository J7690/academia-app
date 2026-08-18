import 'dart:typed_data';

import 'package:animate_do/animate_do.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/student_application_files_provider.dart';
import '../../providers/student_application_messages_provider.dart';
import '../../providers/student_applications_provider.dart';
import '../../providers/student_application_payments_provider.dart';
import '../../widgets/bobodo_state.dart';
import '../../widgets/ligdicash_payment_sheet.dart';
import '../../widgets/bobodo_view.dart';
import '../../services/analytics_tracking_service.dart';
import '../../widgets/adaptive_dialog.dart';
import '../../widgets/app_snack.dart';
import '../../services/app_error_messages.dart';

class StudentApplicationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> application;
  final int initialTabIndex;

  const StudentApplicationDetailScreen({
    super.key,
    required this.application,
    this.initialTabIndex = 0,
  });

  @override
  State<StudentApplicationDetailScreen> createState() => _StudentApplicationDetailScreenState();
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final display = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      child: Center(
        child: Text(
          display,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _StudentApplicationDetailScreenState extends State<StudentApplicationDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _hasUnreadMessages = false;
  bool _messagesLoaded = false;

  @override
  void initState() {
    super.initState();
    AnalyticsTrackingService.instance.init();
    AnalyticsTrackingService.instance.trackScreen('student_application_detail');
    _hasUnreadMessages = widget.application['has_unread_for_student'] == true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appId = widget.application['id']?.toString();
      if (appId != null && appId.isNotEmpty) {
        context.read<StudentApplicationFilesProvider>().loadFiles(appId);
        try {
          context.read<StudentApplicationPaymentsProvider>().loadPayments(appId);
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    try {
      context.read<StudentApplicationsProvider>().loadApplications();
    } catch (_) {}
    super.dispose();
  }

  void _handleTabTap(int index) {
    if (index != 1) {
      return;
    }
    final appId = widget.application['id']?.toString();
    if (appId == null || appId.isEmpty) {
      return;
    }
    if (!_messagesLoaded) {
      context.read<StudentApplicationMessagesProvider>().loadMessages(appId);
      _messagesLoaded = true;
    }
    if (_hasUnreadMessages) {
      setState(() {
        _hasUnreadMessages = false;
      });
    }
  }

  Future<void> _pickAndUploadFile() async {
    final appId = widget.application['id']?.toString();
    if (appId == null || appId.isEmpty) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    final fileName = file.name;

    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de lire le contenu du fichier.')),
      );
      return;
    }

    final provider = context.read<StudentApplicationFilesProvider>();
    final success = await provider.addFile(
      applicationId: appId,
      bytes: bytes as Uint8List,
      fileName: fileName,
      fileType: 'document',
      mimeType: file.extension,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document ajouté avec succès.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Erreur lors de l\'upload.')),
      );
    }
  }

  void _showDeclarePaymentSheet(BuildContext context) {
    final appId = widget.application['id']?.toString();
    if (appId == null || appId.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final amountController = TextEditingController();
        final referenceController = TextEditingController();
        final noteController = TextEditingController();
        String? selectedChannel;
        bool isSubmitting = false;

        Future<void> submit() async {
          if (isSubmitting) return;

          final rawAmount = amountController.text.trim().replaceAll(',', '.');
          final amount = double.tryParse(rawAmount);
          if (amount == null || amount <= 0) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text('Veuillez saisir un montant valide.'),
              ),
            );
            return;
          }

          if (selectedChannel == null || selectedChannel!.isEmpty) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text('Veuillez sélectionner un canal de paiement.'),
              ),
            );
            return;
          }

          isSubmitting = true;
          final paymentsProvider =
              context.read<StudentApplicationPaymentsProvider>();
          final ok = await paymentsProvider.createAndDeclarePayment(
            applicationId: appId,
            paymentReason: 'application_fee',
            channel: selectedChannel!,
            amount: amount,
            externalReference: referenceController.text.trim().isEmpty
                ? null
                : referenceController.text.trim(),
            studentNote: noteController.text.trim().isEmpty
                ? null
                : noteController.text.trim(),
          );

          if (!ctx.mounted) return;

          if (ok) {
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Paiement déclaré, en attente de vérification.'),
              ),
            );
          } else {
            final err = paymentsProvider.error ??
                'Erreur lors de la déclaration du paiement.';
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(err)),
            );
            isSubmitting = false;
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Déclarer un paiement',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Indiquez le montant et le canal utilisé pour le paiement.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Canal de paiement',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    RadioListTile<String>(
                      title: const Text('Orange Money'),
                      value: 'orange_money',
                      groupValue: selectedChannel,
                      onChanged: (value) {
                        setState(() {
                          selectedChannel = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Moov Money'),
                      value: 'moov_money',
                      groupValue: selectedChannel,
                      onChanged: (value) {
                        setState(() {
                          selectedChannel = value;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Telecel Money'),
                      value: 'telecel_money',
                      groupValue: selectedChannel,
                      onChanged: (value) {
                        setState(() {
                          selectedChannel = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Montant payé (XOF)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Référence transaction / reçu (optionnel)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note pour l\'administration (optionnel)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting ? null : submit,
                        icon: const Icon(Icons.check),
                        label: const Text('Valider la déclaration'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final status = app['status']?.toString() ?? '';
    final createdAtRaw = app['created_at']?.toString() ?? '';
    final submittedAtRaw = app['submitted_at']?.toString() ?? '';
    final motivation = app['motivation_text']?.toString() ?? '';
    final appId = app['id']?.toString() ?? '';
    final programTitle = app['program_title']?.toString() ?? '';
    final degreeLevel = app['degree_level']?.toString() ?? '';
    final universityName = app['university_name']?.toString() ?? '';

    final statusColor = _applicationStatusColor(status);
    final statusLabel = _applicationStatusLabel(status);
    final createdAt = _formatApplicationDate(createdAtRaw);
    final submittedAt = _formatApplicationDate(submittedAtRaw);

    final bobodoState = _bobodoStateForStatus(status);
    final bobodoText = _bobodoHeaderTextForStatus(status);

    String statusLine = '';
    if (status == 'accepted' && submittedAt.isNotEmpty) {
      statusLine = 'Acceptée le $submittedAt';
    } else if (status == 'under_review' && submittedAt.isNotEmpty) {
      statusLine = 'En étude depuis le $submittedAt';
    } else if (submittedAt.isNotEmpty) {
      statusLine = 'Soumise le $submittedAt';
    } else if (createdAt.isNotEmpty) {
      statusLine = 'Créée le $createdAt';
    }

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Détail de la candidature'),
          bottom: TabBar(
            isScrollable: true,
            onTap: _handleTabTap,
            tabs: [
              const Tab(text: 'Documents'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Messages'),
                    if (_hasUnreadMessages) ...[
                      const SizedBox(width: 6),
                      const _CountBadge(count: 1),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
                padding: EdgeInsets.zero,
                children: [
                FadeInDown(
                  duration: const Duration(milliseconds: 400),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.1),
                            statusColor.withOpacity(0.02),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      statusColor.withOpacity(0.2),
                                      statusColor.withOpacity(0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: BobodoView(
                                    state: bobodoState,
                                    size: 56,
                                    text: bobodoText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (programTitle.isNotEmpty)
                                      Text(
                                        degreeLevel.isNotEmpty
                                            ? '$programTitle · $degreeLevel'
                                            : programTitle,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0A2540),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (universityName.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        universityName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF6B7280),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: statusColor.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: statusColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (statusLine.isNotEmpty)
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today_outlined,
                                                size: 14,
                                                color: const Color(0xFF9CA3AF),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                statusLine,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF9CA3AF),
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (motivation.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.format_quote,
                                        color: statusColor.withOpacity(0.5),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Message de motivation',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0A2540),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    motivation,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF4B5563),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Consumer<StudentApplicationPaymentsProvider>(
                  builder: (context, paymentsProvider, child) {
                    final payments = paymentsProvider.payments;
                    Widget content;
                    if (paymentsProvider.isLoading && payments.isEmpty) {
                      content = const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: LinearProgressIndicator(minHeight: 2),
                      );
                    } else if (paymentsProvider.error != null) {
                      content = Text(
                        'Erreur paiement : ${paymentsProvider.error}',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      );
                    } else if (payments.isEmpty) {
                      content = const Text(
                        'Aucun paiement n\'a encore été déclaré pour cette candidature.',
                        style: TextStyle(fontSize: 13),
                      );
                    } else {
                      final p = payments.first;
                      final amountDue = p['amount_due']?.toString() ?? '';
                      final amountPaid = p['amount_paid']?.toString() ?? '';
                      final channel = p['channel']?.toString() ?? '';
                      final payStatus = p['status']?.toString() ?? '';
                      final ref = p['reference_code']?.toString() ?? '';

                      content = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (amountDue.isNotEmpty)
                            Text('Montant à payer : $amountDue XOF'),
                          if (amountPaid.isNotEmpty)
                            Text('Montant déclaré : $amountPaid XOF'),
                          if (channel.isNotEmpty)
                            Text('Canal : $channel'),
                          if (payStatus.isNotEmpty)
                            Text('Statut paiement : $payStatus'),
                          if (ref.isNotEmpty)
                            Text(
                              'Référence : $ref',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      );
                    }

                    return FadeInUp(
                      duration: const Duration(milliseconds: 350),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3275D0).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.payments_outlined,
                                    color: Color(0xFF3275D0),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Frais de courtage',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0A2540),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: appId.isEmpty
                                      ? null
                                      : () async {
                                          // 1. TOUJOURS récupérer le frais de courtage admin
                                          double amountDue = 0;
                                          try {
                                            final feeResp = await Supabase.instance.client.rpc(
                                              'app_get_program_brokerage_fee',
                                              params: {'p_application_id': appId},
                                            );
                                            final feeData = feeResp as Map<String, dynamic>?;
                                            if (feeData == null || feeData['success'] != true) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(feeData?['error']?.toString() ?? 'Erreur récupération tarif')),
                                              );
                                              return;
                                            }
                                            final brokerageFee = (feeData['brokerage_fee'] as num?)?.toDouble() ?? 0;
                                            if (brokerageFee <= 0) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Les frais de courtage ne sont pas encore définis pour ce programme.')),
                                              );
                                              return;
                                            }
                                            amountDue = brokerageFee;
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            AppSnack.error(context, e);
                                            return;
                                          }

                                          // 2. Réutiliser paiement pending existant ou en créer un nouveau
                                          String paymentId = '';
                                          final existingPending = payments.isNotEmpty &&
                                              payments.first['status'] == 'pending'
                                              ? payments.first
                                              : null;

                                          if (existingPending != null) {
                                            paymentId = existingPending['id']?.toString() ?? '';
                                            // Synchroniser le montant avec le brokerage_fee admin
                                            try {
                                              await Supabase.instance.client.rpc(
                                                'app_update_payment_amount_from_brokerage',
                                                params: {'p_payment_id': paymentId},
                                              );
                                            } catch (_) {}
                                          } else {
                                            // Créer un nouveau paiement
                                            try {
                                              final resp = await Supabase.instance.client.rpc(
                                                'app_create_application_payment',
                                                params: {
                                                  'p_application_id': appId,
                                                  'p_payment_reason': 'application_fee',
                                                  'p_amount_due': amountDue,
                                                },
                                              );
                                              final data = resp as Map<String, dynamic>?;
                                              if (data == null || data['success'] != true) {
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(data?['error']?.toString() ?? 'Erreur création paiement')),
                                                );
                                                return;
                                              }
                                              paymentId = data['payment_id']?.toString() ?? '';
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              AppSnack.error(context, e);
                                              return;
                                            }
                                          }

                                          if (paymentId.isEmpty || !context.mounted) return;

                                          LigdiCashPaymentSheet.show(
                                            context: context,
                                            paymentType: 'application',
                                            paymentId: paymentId,
                                            amount: amountDue,
                                            description: 'Frais de courtage — candidature',
                                            onSuccess: () {
                                              paymentsProvider.loadPayments(appId);
                                            },
                                          );
                                        },
                                  icon: const Icon(Icons.payment),
                                  label: const Text(
                                    'Payer maintenant',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            content,
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(),
                FadeInUp(
                  duration: const Duration(milliseconds: 350),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Documents de candidature',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: _pickAndUploadFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Ajouter un document'),
                        ),
                      ],
                    ),
                  ),
                ),
                Consumer<StudentApplicationFilesProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading && provider.files.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (provider.error != null) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                              child:
                                  Text(AppError.messageFor(provider.error))),
                        );
                      }

                      final files = provider.files;
                      if (files.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text('Aucun document ajouté pour cette candidature.'),
                          ),
                        );
                      }

                      return FadeInUp(
                        duration: const Duration(milliseconds: 350),
                        child: Column(
                          children: List.generate(files.length, (index) {
                            final file = files[index];
                            final type = file['file_type']?.toString() ?? '';
                            final path = file['storage_path']?.toString() ?? '';
                            final uploadedAt = file['uploaded_at']?.toString() ?? '';

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3275D0).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.insert_drive_file,
                                          size: 20,
                                          color: Color(0xFF3275D0),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              type.isNotEmpty ? type : 'Document',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF0A2540),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              path,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility, size: 20),
                                        tooltip: 'Voir',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(6),
                                        onPressed: () async {
                                          final provider = context
                                              .read<StudentApplicationFilesProvider>();
                                          final url =
                                              await provider.createSignedUrl(path);
                                          if (!context.mounted) return;
                                          if (url == null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  provider.error ??
                                                      'Impossible d\'ouvrir le document.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          final uri = Uri.parse(url);
                                          final opened = await launchUrl(
                                            uri,
                                            mode: LaunchMode.externalApplication,
                                          );
                                          if (!opened && context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Impossible d\'ouvrir le document.',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20),
                                        tooltip: 'Supprimer',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(6),
                                        onPressed: () async {
                                          final id = file['id']?.toString();
                                          if (id == null || id.isEmpty || appId.isEmpty) {
                                            return;
                                          }
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            useSafeArea: true,
                                            builder: (ctx) => AdaptiveDialog(
                                              maxWidth: 420,
                                              title: const Text(
                                                  'Supprimer ce document ?'),
                                              child: const Text(
                                                'Cette action est définitive.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(ctx).pop(false),
                                                  child: const Text('Annuler'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.of(ctx).pop(true),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFEF4444),
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  child: const Text('Supprimer'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm != true || !context.mounted) {
                                            return;
                                          }
                                          final provider = context
                                              .read<StudentApplicationFilesProvider>();
                                          final ok = await provider.deleteFile(
                                            fileId: id,
                                            storagePath: path,
                                            applicationId: appId,
                                          );
                                          if (!context.mounted) return;
                                          if (ok) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Document supprimé avec succès.',
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  provider.error ??
                                                      'Erreur lors de la suppression.',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      if (uploadedAt.isNotEmpty)
                                        Text(
                                          uploadedAt,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                ],
            ),
            Column(
              children: [
                Expanded(
                  child: Consumer<StudentApplicationMessagesProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading && provider.messages.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (provider.error != null) {
                        return Center(
                            child: Text(AppError.messageFor(provider.error)));
                      }

                      final messages = provider.messages;
                      if (messages.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Aucun message pour le moment. Utilisez le champ ci-dessous pour poser vos questions de négociation (réductions, conditions, etc.).',
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
                          final content = msg['content']?.toString() ?? '';
                          final createdAtMsg = msg['created_at']?.toString() ?? '';

                          final isStudent = senderRole == 'student';
                          final alignment =
                              isStudent ? Alignment.centerRight : Alignment.centerLeft;
                          final Color bubbleColor = isStudent
                              ? const Color(0xFF3275D0).withValues(alpha: 0.12)
                              : Theme.of(context).colorScheme.surfaceContainerHighest;
                          final Color textColor = isStudent
                              ? const Color(0xFF0A2540)
                              : const Color(0xFF111827);
                          final label = isStudent ? 'Vous' : 'Plateforme / Admin';

                          return Align(
                            alignment: alignment,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.8,
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: bubbleColor,
                                borderRadius: BorderRadius.circular(16),
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
                                  Text(
                                    content,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 13,
                                    ),
                                  ),
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
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText:
                                'Écrire un message de négociation (réduction, conditions...)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF3275D0),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: () async {
                            final appId = widget.application['id']?.toString();
                            if (appId == null || appId.isEmpty) return;
                            final text = _messageController.text.trim();
                            if (text.isEmpty) return;

                            final provider =
                                context.read<StudentApplicationMessagesProvider>();
                            final ok = await provider.sendMessage(
                              applicationId: appId,
                              content: text,
                            );
                            if (!mounted) return;
                            if (ok) {
                              _messageController.clear();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.error ??
                                        'Erreur lors de l\'envoi du message.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1EA75C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Retour'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _applicationStatusColor(String? status) {
  switch (status) {
    case 'submitted':
      return const Color(0xFF3275D0); // Bleu - soumise
    case 'under_review':
      return const Color(0xFFF6A623); // Orange - en étude
    case 'accepted':
      return const Color(0xFF1B8F5A); // Vert - acceptée
    case 'rejected':
      return const Color(0xFFE53935); // Rouge - refusée
    case 'canceled':
      return const Color(0xFF6B7280); // Gris bleuté - annulée
    case 'draft':
    default:
      return const Color(0xFF9CA3AF); // Gris neutre - brouillon / inconnu
  }
}

String _applicationStatusLabel(String? status) {
  switch (status) {
    case 'draft':
      return 'Brouillon';
    case 'submitted':
      return 'Soumise';
    case 'under_review':
      return 'En étude';
    case 'accepted':
      return 'Acceptée';
    case 'rejected':
      return 'Refusée';
    case 'canceled':
      return 'Annulée';
    default:
      return status ?? 'Inconnu';
  }
}

String _formatApplicationDate(String? value) {
  if (value == null || value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final year = parsed.year.toString();
  return '$day/$month/$year';
}

BobodoState _bobodoStateForStatus(String? status) {
  switch (status) {
    case 'accepted':
      return BobodoState.success;
    case 'rejected':
    case 'canceled':
      return BobodoState.warning;
    case 'submitted':
    case 'under_review':
      return BobodoState.thinking;
    case 'draft':
    default:
      return BobodoState.idle;
  }
}

String _bobodoHeaderTextForStatus(String? status) {
  switch (status) {
    case 'draft':
      return 'Tu peux compléter cette candidature à ton rythme. Quand tout est rempli, tu te rapproches du badge \"Dossier prêt\".';
    case 'submitted':
      return 'Candidature soumise. Tu viens de valider une étape clé vers le badge \"Dossier complet\".';
    case 'under_review':
      return 'Candidature en étude. Tu as déjà fait ta part, je te préviens dès qu\'une décision tombe.';
    case 'accepted':
      return 'Candidature acceptée 🎓. Tu peux considérer cette admission comme ton badge \"Admission confirmée\".';
    case 'rejected':
      return 'Cette candidature a été refusée. On peut regarder ensemble d\'autres options adaptées à ton profil.';
    case 'canceled':
      return 'Cette candidature a été annulée. Tu peux en créer une nouvelle si nécessaire, je t\'accompagne étape par étape.';
    default:
      return 'Je t\'aide à suivre l\'avancement de cette candidature et tes futures récompenses étape par étape.';
  }
}
