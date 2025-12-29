import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_payment_receipts_provider.dart';
import 'admin_payment_detail_screen.dart';

class AdminPaymentReceiptsScreen extends StatelessWidget {
  const AdminPaymentReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminPaymentReceiptsProvider>(
      create: (_) => AdminPaymentReceiptsProvider()..loadAllReceipts(),
      child: const _AdminPaymentReceiptsBody(),
    );
  }
}

class _AdminPaymentReceiptsBody extends StatefulWidget {
  const _AdminPaymentReceiptsBody();

  @override
  State<_AdminPaymentReceiptsBody> createState() => _AdminPaymentReceiptsBodyState();
}

class _AdminPaymentReceiptsBodyState extends State<_AdminPaymentReceiptsBody> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminPaymentReceiptsProvider>(
      builder: (context, receiptsProvider, child) {
        final isLoading = receiptsProvider.isLoading;
        final error = receiptsProvider.error;
        final all = receiptsProvider.receipts;

        List<Map<String, dynamic>> filtered = all;
        final q = _query.trim().toLowerCase();
        if (q.isNotEmpty) {
          filtered = all.where((r) {
            bool contains(dynamic value) {
              final s = value?.toString().toLowerCase() ?? '';
              return s.contains(q);
            }

            return contains(r['receipt_number']) ||
                contains(r['reference_code']) ||
                contains(r['payment_reason']) ||
                contains(r['payment_status']) ||
                contains(r['program_title']) ||
                contains(r['university_name']);
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
                            'Rechercher par reçu, référence, statut, programme ou université',
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
                      receiptsProvider.reload();
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
                            receiptsProvider.reload();
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
                      'Aucun reçu trouvé pour les critères actuels.',
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
                    final r = filtered[index];
                    final paymentId = r['payment_id']?.toString() ?? '';
                    final receiptNumber = r['receipt_number']?.toString() ?? '';
                    final issuedAt = r['issued_at']?.toString() ?? '';
                    final paymentStatus = r['payment_status']?.toString() ?? '';
                    final amountDue = r['amount_due']?.toString() ?? '';
                    final amountPaid = r['amount_paid']?.toString() ?? '';
                    final currency = r['currency']?.toString() ?? '';
                    final paymentReason = r['payment_reason']?.toString() ?? '';
                    final programTitle = r['program_title']?.toString() ?? '';
                    final universityName =
                        r['university_name']?.toString() ?? '';
                    final referenceCode =
                        r['reference_code']?.toString() ?? '';
                    final externalReference =
                        r['external_reference']?.toString() ?? '';

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
                                      'Reçu $receiptNumber',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _statusChip(paymentStatus),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (issuedAt.isNotEmpty)
                                Text(
                                  'Émis le $issuedAt',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              const SizedBox(height: 4),
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
                              if (paymentReason.isNotEmpty)
                                Text(
                                  'Type : $paymentReason',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (amountDue.isNotEmpty)
                                Text('Montant dû : $amountDue $currency'),
                              if (amountPaid.isNotEmpty)
                                Text('Montant payé : $amountPaid $currency'),
                              if (referenceCode.isNotEmpty)
                                Text('Référence paiement : $referenceCode'),
                              if (externalReference.isNotEmpty)
                                Text(
                                  'Référence opérateur : $externalReference',
                                ),
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
