import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_actor_balances_provider.dart';

class AdminActorBalancesScreen extends StatelessWidget {
  const AdminActorBalancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminActorBalancesProvider()..loadBalances(),
      child: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  String _fmt(dynamic v) {
    if (v == null) return '0';
    if (v is num) return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminActorBalancesProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  DropdownButton<String>(
                    value: provider.typeFilter,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Tous')),
                      DropdownMenuItem(value: 'commercial', child: Text('Commerciaux')),
                      DropdownMenuItem(value: 'instructor', child: Text('Enseignants')),
                      DropdownMenuItem(value: 'university', child: Text('Universités')),
                      DropdownMenuItem(value: 'merchant', child: Text('Marchands')),
                    ],
                    onChanged: (v) => provider.setTypeFilter(v ?? ''),
                  ),
                  const SizedBox(width: 8),
                  Text('${provider.balances.length} acteur(s)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () => provider.loadBalances(),
                    tooltip: 'Recharger',
                  ),
                ],
              ),
            ),
            if (provider.isLoading && provider.balances.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else if (provider.error != null && provider.balances.isEmpty)
              Expanded(child: Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red))))
            else if (provider.balances.isEmpty)
              const Expanded(child: Center(child: Text('Aucun solde acteur enregistré.')))
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: provider.balances.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final b = provider.balances[index];
                    return _BalanceCard(balance: b, fmt: _fmt);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final Map<String, dynamic> balance;
  final String Function(dynamic) fmt;

  const _BalanceCard({required this.balance, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final actorType = balance['actor_type']?.toString() ?? '';
    final displayName = balance['display_name']?.toString() ?? '';
    final available = balance['available_balance'];
    final pending = balance['pending_balance'];
    final totalEarned = balance['total_earned'];
    final totalWithdrawn = balance['total_withdrawn'];
    final currency = balance['currency']?.toString() ?? 'XOF';

    IconData typeIcon;
    Color typeColor;
    String typeLabel;
    switch (actorType) {
      case 'commercial':
        typeIcon = Icons.people;
        typeColor = const Color(0xFFEA580C);
        typeLabel = 'Commercial';
        break;
      case 'instructor':
        typeIcon = Icons.school;
        typeColor = const Color(0xFF0891B2);
        typeLabel = 'Enseignant';
        break;
      case 'university':
        typeIcon = Icons.apartment;
        typeColor = const Color(0xFF7C3AED);
        typeLabel = 'Université';
        break;
      case 'merchant':
        typeIcon = Icons.storefront;
        typeColor = const Color(0xFFDB2777);
        typeLabel = 'Marchand';
        break;
      default:
        typeIcon = Icons.account_circle;
        typeColor = const Color(0xFF6B7280);
        typeLabel = actorType;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName.isNotEmpty ? displayName : 'Acteur inconnu',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(typeLabel, style: TextStyle(fontSize: 11, color: typeColor)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${fmt(available)} $currency',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                    const Text('Disponible', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MiniStat(label: 'En attente', value: '${fmt(pending)} $currency', color: const Color(0xFFCA8A04)),
                _MiniStat(label: 'Total gagné', value: '${fmt(totalEarned)} $currency', color: const Color(0xFF2563EB)),
                _MiniStat(label: 'Total retiré', value: '${fmt(totalWithdrawn)} $currency', color: const Color(0xFF6B7280)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
      ],
    );
  }
}
