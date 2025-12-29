import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_payment_detail_provider.dart';
import '../../utils/payment_receipt_pdf.dart';

class AdminPaymentDetailScreen extends StatelessWidget {
  final String paymentId;

  const AdminPaymentDetailScreen({super.key, required this.paymentId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminPaymentDetailProvider>(
      create: (_) => AdminPaymentDetailProvider()..loadDetail(paymentId),
      child: const _AdminPaymentDetailBody(),
    );
  }
}

class _AdminPaymentDetailBody extends StatelessWidget {
  const _AdminPaymentDetailBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail du paiement'),
      ),
      body: Consumer<AdminPaymentDetailProvider>(
        builder: (context, provider, child) {
          final isLoading = provider.isLoading;
          final error = provider.error;
          final payment = provider.payment;
          final receipts = provider.receipts;
          final proofs = provider.proofs;

          if (isLoading && payment == null && error == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (error != null && payment == null) {
            return Center(
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
                        final args =
                            ModalRoute.of(context)?.settings.arguments;
                        final String? id =
                            args is String ? args : payment?['id']?.toString();
                        if (id != null && id.isNotEmpty) {
                          Provider.of<AdminPaymentDetailProvider>(
                            context,
                            listen: false,
                          ).loadDetail(id);
                        }
                      },
                      child: const Text('Recharger'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (payment == null) {
            return const Center(
              child: Text('Paiement introuvable.'),
            );
          }

          final status = payment['status']?.toString() ?? '';
          final reason = payment['payment_reason']?.toString() ?? '';
          final amountDue = payment['amount_due']?.toString() ?? '';
          final amountPaid = payment['amount_paid']?.toString() ?? '';
          final currency = payment['currency']?.toString() ?? '';
          final channel = payment['channel']?.toString() ?? '';
          final refCode = payment['reference_code']?.toString() ?? '';
          final extRef = payment['external_reference']?.toString() ?? '';
          final programTitle = payment['program_title']?.toString() ?? '';
          final universityName = payment['university_name']?.toString() ?? '';
          final createdAt = payment['created_at']?.toString() ?? '';
          final declaredAt = payment['declared_at']?.toString() ?? '';
          final verifiedAt = payment['verified_at']?.toString() ?? '';
          final confirmedAt = payment['confirmed_at']?.toString() ?? '';

          final events = <Map<String, String>>[];

          void addEvent(String time, String title, String? subtitle) {
            if (time.isEmpty) return;
            events.add({
              'time': time,
              'title': title,
              'subtitle': subtitle ?? '',
            });
          }

          addEvent(createdAt, 'Création du paiement', null);
          addEvent(
            declaredAt,
            'Déclaration par l\'étudiant',
            amountPaid.isEmpty
                ? null
                : 'Montant déclaré : $amountPaid $currency · Canal : $channel',
          );
          addEvent(
            verifiedAt,
            'Vérification par l\'administration',
            status.isEmpty ? null : 'Statut après vérification : $status',
          );
          addEvent(
            confirmedAt,
            'Confirmation du paiement',
            status.isEmpty ? null : 'Statut final : $status',
          );

          for (final r in receipts) {
            final issuedAt = r['issued_at']?.toString() ?? '';
            final number = r['receipt_number']?.toString() ?? '';
            addEvent(
              issuedAt,
              'Reçu $number',
              'Émission du reçu',
            );
          }

          events.sort((a, b) => a['time']!.compareTo(b['time']!));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _statusChip(status),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 4),
                        if (amountDue.isNotEmpty)
                          Text('Montant dû : $amountDue $currency'),
                        if (amountPaid.isNotEmpty)
                          Text('Montant payé déclaré : $amountPaid $currency'),
                        if (channel.isNotEmpty)
                          Text('Canal : $channel'),
                        if (refCode.isNotEmpty)
                          Text('Référence paiement : $refCode'),
                        if (extRef.isNotEmpty)
                          Text('Référence opérateur : $extRef'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Historique',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (events.isEmpty)
                          const Text(
                            'Aucun événement historique disponible.',
                            style: TextStyle(fontSize: 12),
                          )
                        else
                          Column(
                            children: [
                              for (var i = 0; i < events.length; i++)
                                _TimelineEntry(
                                  isFirst: i == 0,
                                  isLast: i == events.length - 1,
                                  title: events[i]['title']!,
                                  time: events[i]['time']!,
                                  subtitle: events[i]['subtitle']!,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                if (receipts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reçus',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: receipts.map((r) {
                              final number =
                                  r['receipt_number']?.toString() ?? '';
                              final issuedAt =
                                  r['issued_at']?.toString() ?? '';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Reçu $number'),
                                subtitle: issuedAt.isEmpty
                                    ? null
                                    : Text('Émis le $issuedAt'),
                                trailing: IconButton(
                                  tooltip: 'Télécharger le reçu',
                                  icon: const Icon(Icons.picture_as_pdf),
                                  onPressed: () {
                                    generateAndSharePaymentReceiptPdf(
                                      payment: payment,
                                      receipt: r,
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (proofs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Justificatifs',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: proofs.map((p) {
                              final type = p['proof_type']?.toString() ?? '';
                              final path = p['file_path']?.toString() ?? '';
                              final uploadedAt =
                                  p['uploaded_at']?.toString() ?? '';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(type.isEmpty ? 'Justificatif' : type),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (path.isNotEmpty) Text(path),
                                    if (uploadedAt.isNotEmpty)
                                      Text('Ajouté le $uploadedAt'),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
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

class _TimelineEntry extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final String title;
  final String time;
  final String subtitle;

  const _TimelineEntry({
    required this.isFirst,
    required this.isLast,
    required this.title,
    required this.time,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              alignment: Alignment.center,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: Colors.blue,
              ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
