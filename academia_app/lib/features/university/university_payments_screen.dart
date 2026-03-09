import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/university_payments_provider.dart';

class UniversityPaymentsScreen extends StatefulWidget {
  const UniversityPaymentsScreen({super.key});

  @override
  State<UniversityPaymentsScreen> createState() =>
      _UniversityPaymentsScreenState();
}

class _UniversityPaymentsScreenState extends State<UniversityPaymentsScreen> {
  String _query = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UniversityPaymentsProvider>().loadPayments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UniversityPaymentsProvider>(
      builder: (context, provider, _) {
        final isLoading = provider.isLoading;
        final error = provider.error;
        final all = provider.payments;

        List<Map<String, dynamic>> filtered = List.from(all);
        if (_statusFilter != 'all') {
          filtered =
              filtered.where((p) => p['status'] == _statusFilter).toList();
        }
        final q = _query.trim().toLowerCase();
        if (q.isNotEmpty) {
          filtered = filtered.where((p) {
            final name = (p['student_name'] ?? '').toString().toLowerCase();
            final program = (p['program_name'] ?? '').toString().toLowerCase();
            final ref = (p['reference_code'] ?? '').toString().toLowerCase();
            final reason = (p['payment_reason'] ?? '').toString().toLowerCase();
            return name.contains(q) ||
                program.contains(q) ||
                ref.contains(q) ||
                reason.contains(q);
          }).toList();
        }

        return Column(
          children: [
            // Summary cards
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _SummaryCard(
                    label: 'Total',
                    value: provider.totalCount.toString(),
                    color: const Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 8),
                  _SummaryCard(
                    label: 'Confirmés',
                    value: provider.confirmedCount.toString(),
                    color: const Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 8),
                  _SummaryCard(
                    label: 'En cours',
                    value: provider.pendingCount.toString(),
                    color: const Color(0xFFEA580C),
                  ),
                ],
              ),
            ),
            // Filters
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Rechercher étudiant, programme...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _statusFilter,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tous')),
                      DropdownMenuItem(
                          value: 'confirmed', child: Text('Confirmés')),
                      DropdownMenuItem(
                          value: 'declared_by_student',
                          child: Text('Déclarés')),
                      DropdownMenuItem(
                          value: 'under_verification',
                          child: Text('En vérif.')),
                      DropdownMenuItem(
                          value: 'pending', child: Text('En attente')),
                      DropdownMenuItem(
                          value: 'rejected', child: Text('Rejetés')),
                    ],
                    onChanged: (v) =>
                        setState(() => _statusFilter = v ?? 'all'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () => provider.loadPayments(),
                    tooltip: 'Recharger',
                  ),
                ],
              ),
            ),
            // List
            if (isLoading && all.isEmpty)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (error != null && all.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => provider.loadPayments(),
                        child: const Text('Recharger'),
                      ),
                    ],
                  ),
                ),
              )
            else if (filtered.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Aucun paiement trouvé.'),
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
                    return _PaymentCard(payment: p);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;

  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final studentName = payment['student_name']?.toString() ?? '';
    final programName = payment['program_name']?.toString() ?? '';
    final status = payment['status']?.toString() ?? '';
    final reason = payment['payment_reason']?.toString() ?? '';
    final amountDue = payment['amount_due']?.toString() ?? '';
    final amountPaid = payment['amount_paid']?.toString() ?? '';
    final currency = payment['currency']?.toString() ?? 'XOF';
    final channel = payment['channel']?.toString() ?? '';
    final refCode = payment['reference_code']?.toString() ?? '';
    final createdAt = payment['created_at']?.toString() ?? '';
    final declaredAt = payment['declared_at']?.toString() ?? '';
    final confirmedAt = payment['confirmed_at']?.toString() ?? '';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    studentName.isNotEmpty ? studentName : 'Étudiant inconnu',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            if (programName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                programName,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _infoTag(Icons.receipt_long, _reasonLabel(reason)),
                const SizedBox(width: 8),
                if (channel.isNotEmpty)
                  _infoTag(Icons.payment, _channelLabel(channel)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Dû : $amountDue $currency',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 16),
                if (amountPaid.isNotEmpty && amountPaid != 'null')
                  Text(
                    'Payé : $amountPaid $currency',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (refCode.isNotEmpty)
              Text(
                'Réf : $refCode',
                style:
                    const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            if (createdAt.isNotEmpty)
              Text(
                'Créé : ${_formatDate(createdAt)}',
                style:
                    const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            if (declaredAt.isNotEmpty && declaredAt != 'null')
              Text(
                'Déclaré : ${_formatDate(declaredAt)}',
                style:
                    const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            if (confirmedAt.isNotEmpty && confirmedAt != 'null')
              Text(
                'Confirmé : ${_formatDate(confirmedAt)}',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF16A34A)),
              ),
          ],
        ),
      ),
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
        color = const Color(0xFF16A34A);
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
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _infoTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  String _reasonLabel(String reason) {
    switch (reason) {
      case 'application_fee':
        return 'Frais de dossier';
      case 'registration_fee':
        return "Frais d'inscription";
      case 'tuition_deposit':
        return 'Acompte scolarité';
      case 'td_access':
        return 'Accès TD';
      default:
        return 'Paiement';
    }
  }

  String _channelLabel(String channel) {
    switch (channel) {
      case 'orange_money':
        return 'Orange Money';
      case 'moov_money':
        return 'Moov Money';
      case 'telecel_money':
        return 'Telecel Money';
      case 'cash':
        return 'Espèces';
      default:
        return channel;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
