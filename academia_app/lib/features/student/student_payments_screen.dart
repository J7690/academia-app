import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/student_application_payments_provider.dart';
import '../../providers/student_applications_provider.dart';
import '../../utils/payment_receipt_pdf.dart';
import 'widgets/student_mobile_scaffold.dart';

class StudentPaymentsScreen extends StatefulWidget {
  const StudentPaymentsScreen({super.key});

  @override
  State<StudentPaymentsScreen> createState() => _StudentPaymentsScreenState();
}

class _StudentPaymentsScreenState extends State<StudentPaymentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<StudentApplicationPaymentsProvider>().loadMyPayments();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return StudentMobileScaffold(
      appBar: AppBar(
        title: const Text('Mes paiements'),
      ),
      body: Consumer2<StudentApplicationPaymentsProvider, StudentApplicationsProvider>(
        builder: (context, paymentsProvider, applicationsProvider, child) {
          final payments = paymentsProvider.payments;
          final isLoading = paymentsProvider.isLoading;
          final error = paymentsProvider.error;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PaymentChannelsSection(
                onChannelTap: (channel) {
                  _openCreateProfilePaymentFlow(
                    context,
                    paymentsProvider,
                    initialChannel: channel,
                  );
                },
              ),
              const SizedBox(height: 16),
              _PaymentReasonsSection(),
              const SizedBox(height: 16),
              _CreatePaymentSection(
                hasApplications: applicationsProvider.applications.isNotEmpty,
                onCreateForApplication: () {
                  _openCreateApplicationPaymentFlow(
                    context,
                    applicationsProvider,
                    paymentsProvider,
                  );
                },
                onCreateForProfile: () {
                  _openCreateProfilePaymentFlow(
                    context,
                    paymentsProvider,
                  );
                },
              ),
              const SizedBox(height: 24),
              _PaymentsHistorySection(
                payments: payments,
                isLoading: isLoading,
                error: error,
                onReload: () {
                  paymentsProvider.loadMyPayments();
                },
                onDeclarePayment: (payment) {
                  _openDeclareExistingPaymentFlow(
                    context,
                    paymentsProvider,
                    payment,
                  );
                },
              ),
            ],
          );
        },
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
    );
  }

  Future<void> _openDeclareExistingPaymentFlow(
    BuildContext context,
    StudentApplicationPaymentsProvider paymentsProvider,
    Map<String, dynamic> payment,
  ) async {
    final paymentId = payment['id']?.toString() ?? '';
    if (paymentId.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de trouver l\'identifiant du paiement.'),
        ),
      );
      return;
    }

    final rawAmount = payment['amount_due'];
    double? amountDue;
    if (rawAmount is num) {
      amountDue = rawAmount.toDouble();
    } else if (rawAmount is String) {
      amountDue = double.tryParse(rawAmount.replaceAll(',', '.'));
    }

    if (amountDue == null || amountDue <= 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Montant dû invalide pour ce paiement. Merci de contacter l\'administration.',
          ),
        ),
      );
      return;
    }

    String? selectedChannel;
    String externalRef = '';
    String studentNote = '';
    String? localError;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + bottomInset,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Déclarer un paiement existant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Montant dû : ${amountDue!.toStringAsFixed(0)} XOF',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedChannel,
                      decoration: const InputDecoration(
                        labelText: 'Canal de paiement',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'orange_money',
                          child: Text('Orange Money'),
                        ),
                        DropdownMenuItem(
                          value: 'moov_money',
                          child: Text('Moov Money'),
                        ),
                        DropdownMenuItem(
                          value: 'telecel_money',
                          child: Text('Telecel Money'),
                        ),
                        DropdownMenuItem(
                          value: 'cash',
                          child: Text('Espèces / guichet'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedChannel = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText:
                            'Référence opérateur / ID transaction (obligatoire pour Orange/Moov/Telecel)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          externalRef = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note pour l\'administration (optionnel)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          studentNote = value;
                        });
                      },
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        localError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                },
                          child: const Text('Annuler'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (selectedChannel == null ||
                                      selectedChannel!.isEmpty) {
                                    setState(() {
                                      localError =
                                          'Choisis un canal de paiement.';
                                    });
                                    return;
                                  }
                                  final extTrimmed = externalRef.trim();
                                  if ((selectedChannel == 'orange_money' ||
                                          selectedChannel == 'moov_money' ||
                                          selectedChannel == 'telecel_money') &&
                                      extTrimmed.isEmpty) {
                                    setState(() {
                                      localError =
                                          'Saisis l\'ID de transaction ou la référence figurant dans ton SMS de paiement.';
                                    });
                                    return;
                                  }

                                  setState(() {
                                    isSubmitting = true;
                                    localError = null;
                                  });

                                  bool success = false;
                                  try {
                                    success = await paymentsProvider
                                        .declareExistingPayment(
                                      paymentId: paymentId,
                                      channel: selectedChannel!,
                                      amount: amountDue!,
                                      externalReference:
                                          extTrimmed.isEmpty ? null : extTrimmed,
                                      studentNote: studentNote.isEmpty
                                          ? null
                                          : studentNote,
                                    );
                                  } catch (e) {
                                    setState(() {
                                      localError = e.toString();
                                    });
                                  } finally {
                                    setState(() {
                                      isSubmitting = false;
                                    });
                                  }

                                  if (!context.mounted) {
                                    return;
                                  }

                                  if (success) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Paiement déclaré, en attente de vérification.',
                                        ),
                                      ),
                                    );
                                  } else {
                                    final providerError = paymentsProvider.error ??
                                        'Erreur lors de la déclaration du paiement.';
                                    setState(() {
                                      localError = providerError;
                                    });
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Déclarer le paiement'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCreateApplicationPaymentFlow(
    BuildContext context,
    StudentApplicationsProvider applicationsProvider,
    StudentApplicationPaymentsProvider paymentsProvider,
  ) async {
    if (applicationsProvider.applications.isEmpty) {
      try {
        await applicationsProvider.loadApplications();
      } catch (_) {}
    }

    final apps = applicationsProvider.applications;
    if (apps.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tu dois d\'abord avoir au moins une candidature pour déclarer un paiement.',
          ),
        ),
      );
      return;
    }

    String? selectedApplicationId = apps.first['id']?.toString();
    String selectedReason = 'application_fee';
    String? selectedChannel;
    String amountText = '';
    String externalRef = '';
    String studentNote = '';
    String? localError;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + bottomInset,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Déclarer un paiement pour une candidature',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedApplicationId,
                      decoration: const InputDecoration(
                        labelText: 'Candidature',
                        border: OutlineInputBorder(),
                      ),
                      items: apps.map((app) {
                        final id = app['id']?.toString() ?? '';
                        final programTitle =
                            app['program_title']?.toString() ?? '';
                        final universityName =
                            app['university_name']?.toString() ?? '';
                        String label = programTitle;
                        if (universityName.isNotEmpty) {
                          label = '$programTitle · $universityName';
                        }
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedApplicationId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: const InputDecoration(
                        labelText: 'Type de paiement',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'application_fee',
                          child: Text('Frais de dossier'),
                        ),
                        DropdownMenuItem(
                          value: 'registration_fee',
                          child: Text('Frais d\'inscription'),
                        ),
                        DropdownMenuItem(
                          value: 'tuition_deposit',
                          child: Text('Acompte scolarité'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('Autre paiement'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedReason = value ?? 'application_fee';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedChannel,
                      decoration: const InputDecoration(
                        labelText: 'Canal de paiement',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'orange_money',
                          child: Text('Orange Money'),
                        ),
                        DropdownMenuItem(
                          value: 'moov_money',
                          child: Text('Moov Money'),
                        ),
                        DropdownMenuItem(
                          value: 'telecel_money',
                          child: Text('Telecel Money'),
                        ),
                        DropdownMenuItem(
                          value: 'cash',
                          child: Text('Espèces / guichet'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedChannel = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Montant (XOF)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          amountText = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText:
                            'Référence opérateur / ID transaction (obligatoire pour Orange/Moov/Telecel)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          externalRef = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note pour l\'administration (optionnel)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          studentNote = value;
                        });
                      },
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        localError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                },
                          child: const Text('Annuler'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (selectedApplicationId == null ||
                                      selectedApplicationId!.isEmpty) {
                                    setState(() {
                                      localError =
                                          'Sélectionne d\'abord une candidature.';
                                    });
                                    return;
                                  }
                                  if (selectedChannel == null ||
                                      selectedChannel!.isEmpty) {
                                    setState(() {
                                      localError =
                                          'Choisis un canal de paiement.';
                                    });
                                    return;
                                  }
                                  final extTrimmed = externalRef.trim();
                                  if ((selectedChannel == 'orange_money' ||
                                          selectedChannel == 'moov_money' ||
                                          selectedChannel == 'telecel_money') &&
                                      extTrimmed.isEmpty) {
                                    setState(() {
                                      localError =
                                          'Saisis l\'ID de transaction ou la référence figurant dans ton SMS de paiement.';
                                    });
                                    return;
                                  }
                                  final normalized =
                                      amountText.replaceAll(',', '.');
                                  final amount = double.tryParse(normalized);
                                  if (amount == null || amount <= 0) {
                                    setState(() {
                                      localError =
                                          'Saisis un montant valide (supérieur à 0).';
                                    });
                                    return;
                                  }

                                  setState(() {
                                    isSubmitting = true;
                                    localError = null;
                                  });

                                  bool success = false;
                                  try {
                                    success =
                                        await paymentsProvider.createAndDeclarePayment(
                                      applicationId: selectedApplicationId!,
                                      paymentReason: selectedReason,
                                      channel: selectedChannel!,
                                      amount: amount,
                                      externalReference:
                                          extTrimmed.isEmpty ? null : extTrimmed,
                                      studentNote: studentNote.isEmpty
                                          ? null
                                          : studentNote,
                                    );
                                  } catch (e) {
                                    setState(() {
                                      localError = e.toString();
                                    });
                                  } finally {
                                    setState(() {
                                      isSubmitting = false;
                                    });
                                  }

                                  if (!context.mounted) {
                                    return;
                                  }

                                  if (success) {
                                    Navigator.of(context).pop();
                                    try {
                                      await paymentsProvider.loadMyPayments();
                                    } catch (_) {}
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Paiement déclaré, en attente de vérification.',
                                        ),
                                      ),
                                    );
                                  } else {
                                    final providerError =
                                        paymentsProvider.error ??
                                            'Erreur lors de la déclaration du paiement.';
                                    setState(() {
                                      localError = providerError;
                                    });
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Déclarer le paiement'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCreateProfilePaymentFlow(
    BuildContext context,
    StudentApplicationPaymentsProvider paymentsProvider, {
    String? initialChannel,
  }) async {
    String selectedReason = 'registration_fee';
    String? selectedChannel = initialChannel;
    String amountText = '';
    String externalRef = '';
    String studentNote = '';
    String? localError;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + bottomInset,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Déclarer un paiement lié à mon profil',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: const InputDecoration(
                        labelText: 'Type de paiement',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'application_fee',
                          child: Text('Frais de dossier'),
                        ),
                        DropdownMenuItem(
                          value: 'registration_fee',
                          child: Text('Frais d\'inscription'),
                        ),
                        DropdownMenuItem(
                          value: 'tuition_deposit',
                          child: Text('Acompte scolarité'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('Autre paiement'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedReason = value ?? 'registration_fee';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedChannel,
                      decoration: const InputDecoration(
                        labelText: 'Canal de paiement',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'orange_money',
                          child: Text('Orange Money'),
                        ),
                        DropdownMenuItem(
                          value: 'moov_money',
                          child: Text('Moov Money'),
                        ),
                        DropdownMenuItem(
                          value: 'telecel_money',
                          child: Text('Telecel Money'),
                        ),
                        DropdownMenuItem(
                          value: 'cash',
                          child: Text('Espèces / guichet'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedChannel = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Montant (XOF)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          amountText = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText:
                            'Référence opérateur / ID transaction (obligatoire pour Orange/Moov/Telecel)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          externalRef = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note pour l\'administration (optionnel)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          studentNote = value;
                        });
                      },
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        localError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                },
                          child: const Text('Annuler'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (selectedChannel == null ||
                                      selectedChannel!.isEmpty) {
                                    setState(() {
                                      localError =
                                          'Choisis un canal de paiement.';
                                    });
                                    return;
                                  }
                                  final extTrimmed = externalRef.trim();
                                  if ((selectedChannel == 'orange_money' ||
                                          selectedChannel == 'moov_money' ||
                                          selectedChannel == 'telecel_money') &&
                                      extTrimmed.isEmpty) {
                                    setState(() {
                                      localError =
                                          'Saisis l\'ID de transaction ou la référence figurant dans ton SMS de paiement.';
                                    });
                                    return;
                                  }
                                  final normalized =
                                      amountText.replaceAll(',', '.');
                                  final amount = double.tryParse(normalized);
                                  if (amount == null || amount <= 0) {
                                    setState(() {
                                      localError =
                                          'Saisis un montant valide (supérieur à 0).';
                                    });
                                    return;
                                  }

                                  setState(() {
                                    isSubmitting = true;
                                    localError = null;
                                  });

                                  bool success = false;
                                  try {
                                    success = await paymentsProvider
                                        .createAndDeclareProfilePayment(
                                      paymentReason: selectedReason,
                                      channel: selectedChannel!,
                                      amount: amount,
                                      externalReference:
                                          extTrimmed.isEmpty ? null : extTrimmed,
                                      studentNote: studentNote.isEmpty
                                          ? null
                                          : studentNote,
                                    );
                                  } catch (e) {
                                    setState(() {
                                      localError = e.toString();
                                    });
                                  } finally {
                                    setState(() {
                                      isSubmitting = false;
                                    });
                                  }

                                  if (!context.mounted) {
                                    return;
                                  }

                                  if (success) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Paiement de profil déclaré, en attente de vérification.',
                                        ),
                                      ),
                                    );
                                  } else {
                                    final providerError =
                                        paymentsProvider.error ??
                                            'Erreur lors de la déclaration du paiement.';
                                    setState(() {
                                      localError = providerError;
                                    });
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Déclarer le paiement'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _labelForReason(String reason) {
    switch (reason) {
      case 'application_fee':
        return 'Frais de dossier';
      case 'registration_fee':
        return 'Frais d\'inscription';
      case 'tuition_deposit':
        return 'Acompte scolarité';
      default:
        return 'Paiement';
    }
  }

  Widget _statusChip(String status) {
    String label;
    Color color;
    switch (status) {
      case 'pending':
        label = 'En attente';
        color = Colors.orange;
        break;
      case 'declared_by_student':
        label = 'Déclaré';
        color = Colors.blueGrey;
        break;
      case 'under_verification':
        label = 'En vérification';
        color = Colors.blue;
        break;
      case 'confirmed':
        label = 'Confirmé';
        color = Colors.green;
        break;
      case 'rejected':
        label = 'Rejeté';
        color = Colors.red;
        break;
      case 'cancelled':
        label = 'Annulé';
        color = Colors.grey;
        break;
      default:
        label = status.isEmpty ? 'Inconnu' : status;
        color = Colors.grey;
        break;
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PaymentChannelsSection extends StatelessWidget {
  final void Function(String channel)? onChannelTap;

  const _PaymentChannelsSection({this.onChannelTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Moyens de paiement disponibles',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChannelChip(
                  label: 'Orange Money',
                  icon: Icons.phone_iphone,
                  onTap: () => onChannelTap?.call('orange_money'),
                ),
                _ChannelChip(
                  label: 'Moov Money',
                  icon: Icons.phone_android,
                  onTap: () => onChannelTap?.call('moov_money'),
                ),
                _ChannelChip(
                  label: 'Telecel Money',
                  icon: Icons.smartphone,
                  onTap: () => onChannelTap?.call('telecel_money'),
                ),
                _ChannelChip(
                  label: 'Espèces / guichet',
                  icon: Icons.storefront,
                  onTap: () => onChannelTap?.call('cash'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _ChannelChip({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        icon,
        size: 18,
      ),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _PaymentReasonsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Types de paiements',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            _ReasonRow(
              title: 'Frais de dossier',
              description:
                  'Paiement lié à l\'étude de ton dossier pour une candidature.',
            ),
            SizedBox(height: 4),
            _ReasonRow(
              title: 'Frais d\'inscription',
              description:
                  'Paiement demandé lors de l\'inscription définitive.',
            ),
            SizedBox(height: 4),
            _ReasonRow(
              title: 'Acompte scolarité',
              description:
                  'Premier versement sur les frais de scolarité d\'une formation.',
            ),
            SizedBox(height: 4),
            _ReasonRow(
              title: 'Autres paiements',
              description:
                  'Autres frais liés à ton parcours (tests, pénalités, etc.).',
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  final String title;
  final String description;

  const _ReasonRow({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 18,
          color: Colors.green,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _labelForReason(String reason) {
    switch (reason) {
      case 'application_fee':
        return 'Frais de dossier';
      case 'registration_fee':
        return 'Frais d\'inscription';
      case 'tuition_deposit':
        return 'Acompte scolarité';
      default:
        return 'Paiement';
    }
  }

  Widget _statusChip(String status) {
    String label;
    Color color;
    switch (status) {
      case 'pending':
        label = 'En attente';
        color = Colors.orange;
        break;
      case 'declared_by_student':
        label = 'Déclaré';
        color = Colors.blueGrey;
        break;
      case 'under_verification':
        label = 'En vérification';
        color = Colors.blue;
        break;
      case 'confirmed':
        label = 'Confirmé';
        color = Colors.green;
        break;
      case 'rejected':
        label = 'Rejeté';
        color = Colors.red;
        break;
      case 'cancelled':
        label = 'Annulé';
        color = Colors.grey;
        break;
      default:
        label = status.isEmpty ? 'Inconnu' : status;
        color = Colors.grey;
        break;
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _CreatePaymentSection extends StatelessWidget {
  final bool hasApplications;
  final VoidCallback onCreateForApplication;
  final VoidCallback onCreateForProfile;

  const _CreatePaymentSection({
    required this.hasApplications,
    required this.onCreateForApplication,
    required this.onCreateForProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Créer un paiement',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choisis d\'abord si ton paiement concerne une candidature précise '
              'ou ton profil (par exemple pour l\'inscription générale).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: hasApplications ? onCreateForApplication : null,
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Payer pour une candidature'),
            ),
            if (!hasApplications) ...[
              const SizedBox(height: 4),
              const Text(
                'Tu n\'as pas encore de candidature. Crée une candidature pour '
                'pouvoir lier un paiement à une formation.',
                style: TextStyle(fontSize: 11),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onCreateForProfile,
              icon: const Icon(Icons.person_outline),
              label: const Text('Payer pour mon profil'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentsHistorySection extends StatelessWidget {
  final List<Map<String, dynamic>> payments;
  final bool isLoading;
  final String? error;
  final VoidCallback onReload;
  final void Function(Map<String, dynamic> payment)? onDeclarePayment;

  const _PaymentsHistorySection({
    required this.payments,
    required this.isLoading,
    required this.error,
    required this.onReload,
    this.onDeclarePayment,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && payments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (error != null && payments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: onReload,
                child: const Text('Recharger'),
              ),
            ],
          ),
        ),
      );
    }

    if (payments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Tu n\'as encore aucun paiement enregistré.\n'
            'Les paiements que tu déclares pour tes candidatures ou ton profil '
            'apparaîtront ici.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sortedPayments = [...payments];

    DateTime _parseDate(Map<String, dynamic> row, String key) {
      final value = row[key];
      if (value == null) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.tryParse(value.toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    sortedPayments.sort((a, b) {
      final aCreated = _parseDate(a, 'created_at');
      final bCreated = _parseDate(b, 'created_at');
      final aUpdated = _parseDate(a, 'updated_at');
      final bUpdated = _parseDate(b, 'updated_at');

      final aKey = aUpdated.isAfter(aCreated) ? aUpdated : aCreated;
      final bKey = bUpdated.isAfter(bCreated) ? bUpdated : bCreated;

      return bKey.compareTo(aKey);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historique des paiements',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedPayments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final p = sortedPayments[index];
            final reason = p['payment_reason']?.toString() ?? '';
            final status = p['status']?.toString() ?? '';
            final amountDue = p['amount_due']?.toString() ?? '';
            final amountPaid = p['amount_paid']?.toString() ?? '';
            final channel = p['channel']?.toString() ?? '';
            final ref = p['reference_code']?.toString() ?? '';
            final extRef = p['external_reference']?.toString() ?? '';
            final createdAt = p['created_at']?.toString() ?? '';
            final hasApplication = p['application_id'] != null;
            final isTdAccess = reason == 'td_access';

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _labelForReason(reason),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusChip(status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (createdAt.isNotEmpty)
                      Text(
                        'Créé le $createdAt',
                        style: const TextStyle(fontSize: 12),
                      ),
                    const SizedBox(height: 4),
                    if (amountDue.isNotEmpty)
                      Text('Montant dû : $amountDue XOF'),
                    if (amountPaid.isNotEmpty)
                      Text('Montant payé déclaré : $amountPaid XOF'),
                    if (channel.isNotEmpty)
                      Text('Canal : $channel'),
                    if (ref.isNotEmpty)
                      Text('Référence : $ref'),
                    if (extRef.isNotEmpty)
                      Text('Référence externe : $extRef'),
                    if (isTdAccess &&
                        (status == 'pending' ||
                            status == 'declared_by_student' ||
                            status == 'under_verification'))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextButton.icon(
                          onPressed: () {
                            onDeclarePayment?.call(p);
                          },
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: const Text(
                            'Déclarer / mettre à jour ce paiement',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    if (status == 'confirmed')
                      TextButton.icon(
                        onPressed: () async {
                          final paymentsProvider =
                              Provider.of<StudentApplicationPaymentsProvider>(
                            context,
                            listen: false,
                          );
                          final paymentId = p['id']?.toString() ?? '';
                          if (paymentId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Impossible de trouver l\'identifiant du paiement.',
                                ),
                              ),
                            );
                            return;
                          }
                          final receipts = await paymentsProvider
                              .getReceiptsForPayment(paymentId);
                          if (receipts.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Aucun reçu n\'est encore disponible pour ce paiement.',
                                ),
                              ),
                            );
                            return;
                          }
                          await generateAndSharePaymentReceiptPdf(
                            payment: p,
                            receipt: receipts.first,
                          );
                        },
                        icon: const Icon(
                          Icons.picture_as_pdf,
                          size: 16,
                        ),
                        label: const Text(
                          'Télécharger le reçu',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      hasApplication
                          ? 'Lié à une candidature.'
                          : 'Paiement lié à ton profil.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _labelForReason(String reason) {
    switch (reason) {
      case 'application_fee':
        return 'Frais de dossier';
      case 'registration_fee':
        return 'Frais d\'inscription';
      case 'tuition_deposit':
        return 'Acompte scolarité';
      default:
        return 'Paiement';
    }
  }

  Widget _statusChip(String status) {
    String label;
    Color color;
    switch (status) {
      case 'pending':
        label = 'En attente';
        color = Colors.orange;
        break;
      case 'declared_by_student':
        label = 'Déclaré';
        color = Colors.blueGrey;
        break;
      case 'under_verification':
        label = 'En vérification';
        color = Colors.blue;
        break;
      case 'confirmed':
        label = 'Confirmé';
        color = Colors.green;
        break;
      case 'rejected':
        label = 'Rejeté';
        color = Colors.red;
        break;
      case 'cancelled':
        label = 'Annulé';
        color = Colors.grey;
        break;
      default:
        label = status.isEmpty ? 'Inconnu' : status;
        color = Colors.grey;
        break;
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
