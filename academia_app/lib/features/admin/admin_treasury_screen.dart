import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_treasury_provider.dart';

class AdminTreasuryScreen extends StatelessWidget {
  const AdminTreasuryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminTreasuryProvider()..loadSummary()..loadLedger(),
      child: const _AdminTreasuryBody(),
    );
  }
}

class _AdminTreasuryBody extends StatelessWidget {
  const _AdminTreasuryBody();

  String _fmt(dynamic v) {
    if (v == null) return '0';
    if (v is num) return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminTreasuryProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.summary == null) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (provider.error != null && provider.summary == null) {
          return Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red)));
        }
        final s = provider.summary ?? {};

        return RefreshIndicator(
          onRefresh: () async {
            await provider.loadSummary();
            await provider.loadLedger();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // KPI Row 1
              Row(
                children: [
                  _KpiCard(label: 'Total Entrées', value: '${_fmt(s['total_payin'])} XOF', color: const Color(0xFF16A34A), icon: Icons.arrow_downward),
                  const SizedBox(width: 8),
                  _KpiCard(label: 'Total Sorties', value: '${_fmt(s['total_payout'])} XOF', color: const Color(0xFFDC2626), icon: Icons.arrow_upward),
                ],
              ),
              const SizedBox(height: 8),
              // KPI Row 2
              Row(
                children: [
                  _KpiCard(label: 'Entrées du mois', value: '${_fmt(s['month_payin'])} XOF', color: const Color(0xFF2563EB), icon: Icons.trending_up),
                  const SizedBox(width: 8),
                  _KpiCard(label: 'Sorties du mois', value: '${_fmt(s['month_payout'])} XOF', color: const Color(0xFFEA580C), icon: Icons.trending_down),
                ],
              ),
              const SizedBox(height: 8),
              // KPI Row 3
              Row(
                children: [
                  _KpiCard(label: 'Payouts en attente', value: '${_fmt(s['pending_payouts'])} XOF\n(${_fmt(s['pending_payout_count'])} en file)', color: const Color(0xFFCA8A04), icon: Icons.hourglass_top),
                  const SizedBox(width: 8),
                  _KpiCard(label: 'Abonnés actifs', value: '${_fmt(s['active_subscriptions'])}', color: const Color(0xFF7C3AED), icon: Icons.workspace_premium),
                ],
              ),
              const SizedBox(height: 8),
              // KPI Row 4
              Row(
                children: [
                  _KpiCard(label: 'Commissions commerciales', value: '${_fmt(s['total_commissions_commercial'])} XOF', color: const Color(0xFF0891B2), icon: Icons.people),
                  const SizedBox(width: 8),
                  _KpiCard(label: 'Commissions marketplace', value: '${_fmt(s['total_commissions_marketplace'])} XOF', color: const Color(0xFFDB2777), icon: Icons.storefront),
                ],
              ),
              const SizedBox(height: 24),

              // Ledger
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Grand livre', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('${provider.ledgerTotal} entrées', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
              const SizedBox(height: 8),
              if (provider.ledger.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aucune entrée dans le grand livre.', textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF9CA3AF))),
                )
              else
                ...provider.ledger.map((entry) => _LedgerRow(entry: entry, fmt: _fmt)),
            ],
          ),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _KpiCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  final String Function(dynamic) fmt;

  const _LedgerRow({required this.entry, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final type = entry['transaction_type']?.toString() ?? '';
    final direction = entry['direction']?.toString() ?? '';
    final amount = entry['amount'];
    final desc = entry['description']?.toString() ?? '';
    final createdAt = entry['created_at']?.toString() ?? '';
    final isCredit = direction == 'credit';

    String dateLabel = '';
    try {
      final dt = DateTime.parse(createdAt);
      dateLabel = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      dateLabel = createdAt;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCredit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                color: isCredit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  if (desc.isNotEmpty)
                    Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(dateLabel, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            Text(
              '${isCredit ? '+' : '-'}${fmt(amount)} XOF',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isCredit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
