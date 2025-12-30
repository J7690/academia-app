import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/student_application_files_provider.dart';
import '../../providers/student_application_messages_provider.dart';
import '../../providers/student_applications_provider.dart';
import '../../providers/student_application_payments_provider.dart';

class StudentApplicationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> application;

  const StudentApplicationDetailScreen({super.key, required this.application});

  @override
  State<StudentApplicationDetailScreen> createState() => _StudentApplicationDetailScreenState();
}

class _StudentApplicationDetailScreenState extends State<StudentApplicationDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _hasUnreadMessages = false;
  bool _messagesLoaded = false;

  @override
  void initState() {
    super.initState();
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
                      'Choisissez le canal utilisé et indiquez le montant réellement payé.'
                      '\nLe paiement se fait en dehors de la plateforme, ici vous enregistrez seulement la preuve.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Canal de paiement',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    RadioListTile<String>(
                      title: const Text('Espèces (cash)'),
                      value: 'cash',
                      groupValue: selectedChannel,
                      onChanged: (value) {
                        setState(() {
                          selectedChannel = value;
                        });
                      },
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
    final createdAt = app['created_at']?.toString() ?? '';
    final motivation = app['motivation_text']?.toString() ?? '';
    final appId = app['id']?.toString() ?? '';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Détail de la candidature'),
          bottom: TabBar(
            onTap: _handleTabTap,
            tabs: [
              const Tab(text: 'Documents'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Messages'),
                    if (_hasUnreadMessages) ...[
                      const SizedBox(width: 4),
                      const _NotificationDot(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Statut : $status'),
                      const SizedBox(height: 4),
                      if (createdAt.isNotEmpty) Text('Créée le : $createdAt'),
                      const SizedBox(height: 8),
                      if (motivation.isNotEmpty) ...[
                        const Text('Motivation :'),
                        const SizedBox(height: 4),
                        Text(motivation),
                      ],
                    ],
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

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Paiement de la candidature',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: appId.isEmpty
                                      ? null
                                      : () => _showDeclarePaymentSheet(context),
                                  icon: const Icon(Icons.payment),
                                  label: const Text('Déclarer un paiement'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            content,
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                Expanded(
                  child: Consumer<StudentApplicationFilesProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading && provider.files.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (provider.error != null) {
                        return Center(child: Text('Erreur : ${provider.error}'));
                      }

                      final files = provider.files;
                      if (files.isEmpty) {
                        return const Center(
                          child: Text('Aucun document ajouté pour cette candidature.'),
                        );
                      }

                      return ListView.builder(
                        itemCount: files.length,
                        itemBuilder: (context, index) {
                          final file = files[index];
                          final type = file['file_type']?.toString() ?? '';
                          final path = file['storage_path']?.toString() ?? '';
                          final uploadedAt = file['uploaded_at']?.toString() ?? '';

                          return ListTile(
                            leading: const Icon(Icons.insert_drive_file),
                            title: Text(type.isNotEmpty ? type : 'Document'),
                            subtitle: Text(path),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility),
                                  tooltip: 'Voir',
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
                                  icon: const Icon(Icons.delete),
                                  tooltip: 'Supprimer',
                                  onPressed: () async {
                                    final id = file['id']?.toString();
                                    if (id == null || id.isEmpty || appId.isEmpty) {
                                      return;
                                    }

                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text(
                                            'Supprimer ce document ?'),
                                        content: const Text(
                                          'Cette action est définitive.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: const Text('Annuler'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
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
                                Text(
                                  uploadedAt,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
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
                        return Center(child: Text('Erreur : ${provider.error}'));
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
                          final color = isStudent
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                              : Theme.of(context).colorScheme.surfaceVariant;
                          final label = isStudent ? 'Vous' : 'Plateforme / Admin';

                          return Align(
                            alignment: alignment,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
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
                          decoration: const InputDecoration(
                            hintText:
                                'Écrire un message de négociation (réduction, conditions...)',
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
                    borderRadius: BorderRadius.circular(999),
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

class _NotificationDot extends StatelessWidget {
  const _NotificationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }
}
