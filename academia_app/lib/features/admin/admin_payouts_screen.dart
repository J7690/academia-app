import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_payout_provider.dart';

class AdminPayoutsScreen extends StatelessWidget {
  const AdminPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminPayoutProvider()..loadPayouts(),
      child: const _AdminPayoutsBody(),
    );
  }
}

class _AdminPayoutsBody extends StatelessWidget {
  const _AdminPayoutsBody();

  String _fmt(dynamic v) {
    if (v == null) return '0';
    if (v is num) return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    return v.toString();
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminPayoutProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            // Filter bar + trigger button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  DropdownButton<String>(
                    value: provider.statusFilter,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('En attente')),
                      DropdownMenuItem(value: 'processing', child: Text('En cours')),
                      DropdownMenuItem(value: 'completed', child: Text('Complétés')),
                      DropdownMenuItem(value: 'failed', child: Text('Échoués')),
                      DropdownMenuItem(value: '', child: Text('Tous')),
                    ],
                    onChanged: (v) => provider.setStatusFilter(v ?? 'pending'),
                  ),
                  const SizedBox(width: 8),
                  Text('${provider.total} résultats', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: provider.isProcessing
                        ? null
                        : () async {
                            final ok = await provider.triggerPayouts(allPending: true);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? 'Payouts déclenchés avec succès.' : provider.error ?? 'Erreur')),
                            );
                          },
                    icon: provider.isProcessing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, size: 16),
                    label: const Text('Déclencher les versements', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1EA75C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () => provider.loadPayouts(),
                    tooltip: 'Recharger',
                  ),
                ],
              ),
            ),

            // List
            if (provider.isLoading && provider.payouts.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else if (provider.error != null && provider.payouts.isEmpty)
              Expanded(child: Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red))))
            else if (provider.payouts.isEmpty)
              const Expanded(child: Center(child: Text('Aucun payout trouvé.')))
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: provider.payouts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final p = provider.payouts[index];
                    return _PayoutCard(payout: p, fmt: _fmt, fmtDate: _fmtDate);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PayoutCard extends StatelessWidget {
  final Map<String, dynamic> payout;
  final String Function(dynamic) fmt;
  final String Function(String) fmtDate;

  const _PayoutCard({required this.payout, required this.fmt, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final type = payout['beneficiary_type']?.toString() ?? '';
    final phone = payout['beneficiary_phone']?.toString() ?? '';
    final amount = payout['amount'];
    final status = payout['status']?.toString() ?? '';
    final reason = payout['reason']?.toString() ?? '';
    final createdAt = payout['created_at']?.toString() ?? '';
    final processedAt = payout['processed_at']?.toString() ?? '';
    final errorMsg = payout['error_message']?.toString() ?? '';
    final retryCount = payout['retry_count'] ?? 0;

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'pending':
        statusColor = const Color(0xFFCA8A04);
        statusLabel = 'En attente';
        break;
      case 'processing':
        statusColor = const Color(0xFF2563EB);
        statusLabel = 'En cours';
        break;
      case 'completed':
        statusColor = const Color(0xFF16A34A);
        statusLabel = 'Complété';
        break;
      case 'failed':
        statusColor = const Color(0xFFDC2626);
        statusLabel = 'Échoué';
        break;
      default:
        statusColor = const Color(0xFF6B7280);
        statusLabel = status;
    }

    String typeLabel;
    IconData typeIcon;
    switch (type) {
      case 'commercial':
        typeLabel = 'Commercial';
        typeIcon = Icons.people;
        break;
      case 'university':
        typeLabel = 'Université';
        typeIcon = Icons.apartment;
        break;
      case 'merchant':
        typeLabel = 'Marchand';
        typeIcon = Icons.storefront;
        break;
      case 'instructor':
        typeLabel = 'Enseignant';
        typeIcon = Icons.school;
        break;
      default:
        typeLabel = type;
        typeIcon = Icons.account_circle;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(typeIcon, size: 18, color: const Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text(typeLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (reason.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(reason, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${fmt(amount)} XOF', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                if (phone.isNotEmpty)
                  Text('→ $phone', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
            const SizedBox(height: 4),
            if (createdAt.isNotEmpty)
              Text('Créé : ${fmtDate(createdAt)}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            if (processedAt.isNotEmpty && processedAt != 'null')
              Text('Traité : ${fmtDate(processedAt)}', style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
            if (errorMsg.isNotEmpty && errorMsg != 'null')
              Text('Erreur : $errorMsg', style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
            if (retryCount is int && retryCount > 0)
              Text('Tentatives : $retryCount', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }
}
