import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_payments_provider.dart';
import 'admin_payment_detail_screen.dart';

class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminPaymentsProvider>(
      create: (_) => AdminPaymentsProvider(),
      child: const _AdminPaymentsBody(),
    );
  }
}

class _AdminPaymentsBody extends StatefulWidget {
  const _AdminPaymentsBody();

  @override
  State<_AdminPaymentsBody> createState() => _AdminPaymentsBodyState();
}

class _AdminPaymentsBodyState extends State<_AdminPaymentsBody> {
  String _query = '';
  String? _actionPaymentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<AdminPaymentsProvider>().loadAllPayments();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminPaymentsProvider>(
      builder: (context, paymentsProvider, child) {
        final isLoading = paymentsProvider.isLoading;
        final error = paymentsProvider.error;
        final all = paymentsProvider.payments;

        List<Map<String, dynamic>> filtered = all;
        final q = _query.trim().toLowerCase();
        if (q.isNotEmpty) {
          filtered = all.where((p) {
            bool contains(dynamic value) {
              final s = value?.toString().toLowerCase() ?? '';
              return s.contains(q);
            }

            return contains(p['student_id']) ||
                contains(p['application_id']) ||
                contains(p['payment_reason']) ||
                contains(p['status']) ||
                contains(p['reference_code']) ||
                contains(p['program_title']) ||
                contains(p['university_name']);
          }).toList(growable: false);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText:
                            'Filtrer par étudiant, candidature, référence ou statut',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Recharger',
                    onPressed: () {
                      paymentsProvider.reload();
                    },
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            if (isLoading && all.isEmpty)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null && all.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          error,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            paymentsProvider.reload();
                          },
                          child: const Text('Recharger'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Aucun paiement trouvé pour les critères actuels.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    final paymentId = p['id']?.toString() ?? '';
                    final studentId = p['student_id']?.toString() ?? '';
                    final applicationId = p['application_id']?.toString() ?? '';
                    final reason = p['payment_reason']?.toString() ?? '';
                    final status = p['status']?.toString() ?? '';
                    final amountDue = p['amount_due']?.toString() ?? '';
                    final amountPaid = p['amount_paid']?.toString() ?? '';
                    final channel = p['channel']?.toString() ?? '';
                    final ref = p['reference_code']?.toString() ?? '';
                    final extRef = p['external_reference']?.toString() ?? '';
                    final createdAt = p['created_at']?.toString() ?? '';
                    final programTitle = p['program_title']?.toString() ?? '';
                    final universityName =
                        p['university_name']?.toString() ?? '';

                    final isPending = status == 'pending';
                    final isDeclared = status == 'declared_by_student';
                    final isUnderVerification = status == 'under_verification';
                    final isActingOnThis = _actionPaymentId == paymentId;

                    final studentShort =
                        studentId.isNotEmpty && studentId.length > 8
                            ? '${studentId.substring(0, 8)}…'
                            : studentId;
                    final appShort =
                        applicationId.isNotEmpty && applicationId.length > 8
                            ? '${applicationId.substring(0, 8)}…'
                            : applicationId;

                    return InkWell(
                      onTap: paymentId.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AdminPaymentDetailScreen(
                                    paymentId: paymentId,
                                  ),
                                ),
                              );
                            },
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                              if (studentShort.isNotEmpty)
                                Text(
                                  'Étudiant : $studentShort',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (appShort.isNotEmpty)
                                Text(
                                  'Candidature : $appShort',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (programTitle.isNotEmpty)
                                Text(
                                  'Programme : $programTitle',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (universityName.isNotEmpty)
                                Text(
                                  'Université : $universityName',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (isPending || isDeclared || isUnderVerification)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 8.0, bottom: 4.0),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (isDeclared || isUnderVerification)
                                        TextButton.icon(
                                          onPressed: (paymentId.isEmpty ||
                                                  isActingOnThis)
                                              ? null
                                              : () {
                                                  _handleConfirmPayment(
                                                    context,
                                                    paymentsProvider,
                                                    paymentId,
                                                  );
                                                },
                                          icon: isActingOnThis &&
                                                  (isDeclared ||
                                                      isUnderVerification)
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons
                                                      .check_circle_outline,
                                                  size: 16,
                                                ),
                                          label: const Text(
                                            'Confirmer & générer un reçu',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      if (isPending ||
                                          isDeclared ||
                                          isUnderVerification)
                                        TextButton.icon(
                                          onPressed: (paymentId.isEmpty ||
                                                  isActingOnThis)
                                              ? null
                                              : () {
                                                  _handleVerifyPayment(
                                                    context,
                                                    paymentsProvider,
                                                    paymentId,
                                                    true,
                                                  );
                                                },
                                          icon: const Icon(
                                            Icons.verified,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Marquer valide',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      if (isPending ||
                                          isDeclared ||
                                          isUnderVerification)
                                        TextButton.icon(
                                          onPressed: (paymentId.isEmpty ||
                                                  isActingOnThis)
                                              ? null
                                              : () {
                                                  _handleRejectPayment(
                                                    context,
                                                    paymentsProvider,
                                                    paymentId,
                                                  );
                                                },
                                          icon: const Icon(
                                            Icons.cancel_outlined,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Rejeter',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
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
                            ],
                          ),
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

  Future<void> _handleVerifyPayment(
    BuildContext context,
    AdminPaymentsProvider provider,
    String paymentId,
    bool isValid,
  ) async {
    setState(() {
      _actionPaymentId = paymentId;
    });
    bool success = false;
    try {
      success = await provider.verifyPayment(
        paymentId: paymentId,
        isValid: isValid,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _actionPaymentId = null;
      });
    }

    if (!mounted) return;
    final message = success
        ? 'Paiement mis à jour.'
        : (provider.error ?? 'Erreur lors de la mise à jour du paiement.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleRejectPayment(
    BuildContext context,
    AdminPaymentsProvider provider,
    String paymentId,
  ) async {
    String comment = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rejeter le paiement ?'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'Commentaire (optionnel)',
            ),
            maxLines: 3,
            onChanged: (value) {
              comment = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Rejeter'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _actionPaymentId = paymentId;
    });

    bool success = false;
    try {
      success = await provider.verifyPayment(
        paymentId: paymentId,
        isValid: false,
        comment: comment.isEmpty ? null : comment,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _actionPaymentId = null;
      });
    }

    if (!mounted) return;
    final message = success
        ? 'Paiement rejeté.'
        : (provider.error ?? 'Erreur lors du rejet du paiement.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleConfirmPayment(
    BuildContext context,
    AdminPaymentsProvider provider,
    String paymentId,
  ) async {
    setState(() {
      _actionPaymentId = paymentId;
    });

    bool success = false;
    try {
      success = await provider.confirmPayment(paymentId);
    } finally {
      if (!mounted) return;
      setState(() {
        _actionPaymentId = null;
      });
    }

    if (!mounted) return;
    final message = success
        ? 'Paiement confirmé et reçu généré.'
        : (provider.error ??
            'Erreur lors de la confirmation du paiement.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
