import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_revenue_split_provider.dart';

class AdminRevenueSplitScreen extends StatelessWidget {
  const AdminRevenueSplitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminRevenueSplitProvider()..loadRules()..loadValidations(),
      child: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminRevenueSplitProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.rules.isEmpty) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (provider.error != null && provider.rules.isEmpty) {
          return Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red)));
        }

        final grouped = provider.rulesByReason;
        final reasons = grouped.keys.toList()..sort((a, b) {
          if (a == '*') return 1;
          if (b == '*') return -1;
          return a.compareTo(b);
        });

        return RefreshIndicator(
          onRefresh: () async {
            await provider.loadRules();
            await provider.loadValidations();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Répartition des revenus',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'Configurez le pourcentage que chaque acteur reçoit pour chaque type de paiement. Le total doit être 100%.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              ...reasons.map((reason) => _ReasonCard(
                reason: reason,
                rules: grouped[reason]!,
                provider: provider,
              )),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showAddRuleDialog(context, provider),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter une règle'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddRuleDialog(BuildContext context, AdminRevenueSplitProvider provider) async {
    String reason = 'application_fee';
    String beneficiary = 'platform';
    final percentCtrl = TextEditingController(text: '0.10');
    final maxCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle règle de split'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: reason,
                decoration: const InputDecoration(labelText: 'Type de paiement', border: OutlineInputBorder()),
                items: AdminRevenueSplitProvider.reasonLabels.entries.map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => reason = v ?? reason,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: beneficiary,
                decoration: const InputDecoration(labelText: 'Bénéficiaire', border: OutlineInputBorder()),
                items: AdminRevenueSplitProvider.beneficiaryLabels.entries.map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => beneficiary = v ?? beneficiary,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: percentCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Pourcentage (ex: 0.15 = 15%)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Plafond max (XOF, optionnel)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1EA75C), foregroundColor: Colors.white),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final pct = double.tryParse(percentCtrl.text.replaceAll(',', '.')) ?? 0;
    final maxAmt = double.tryParse(maxCtrl.text);
    await provider.upsertRule(
      paymentReason: reason,
      beneficiaryType: beneficiary,
      percentage: pct,
      maxAmount: maxAmt,
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  final String reason;
  final List<Map<String, dynamic>> rules;
  final AdminRevenueSplitProvider provider;

  const _ReasonCard({required this.reason, required this.rules, required this.provider});

  @override
  Widget build(BuildContext context) {
    final label = AdminRevenueSplitProvider.reasonLabels[reason] ?? reason;
    final isValid = provider.isReasonValid(reason);
    final total = provider.reasonTotal(reason);
    final totalPct = (total * 100).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isValid ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isValid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$totalPct%${isValid ? ' ✅' : ' ⚠️'}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isValid ? const Color(0xFF166534) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...rules.map((rule) {
              final bType = rule['beneficiary_type']?.toString() ?? '';
              final bLabel = AdminRevenueSplitProvider.beneficiaryLabels[bType] ?? bType;
              final pct = rule['percentage'];
              double pctVal = 0;
              if (pct is num) pctVal = pct.toDouble();
              final pctStr = '${(pctVal * 100).toStringAsFixed(1)}%';
              final maxAmt = rule['max_amount'];
              final isActive = rule['is_active'] == true;
              final ruleId = rule['id']?.toString() ?? '';

              Color barColor;
              switch (bType) {
                case 'platform': barColor = const Color(0xFF2563EB); break;
                case 'university': barColor = const Color(0xFF7C3AED); break;
                case 'instructor': barColor = const Color(0xFF0891B2); break;
                case 'commercial': barColor = const Color(0xFFEA580C); break;
                case 'merchant': barColor = const Color(0xFFDB2777); break;
                default: barColor = const Color(0xFF6B7280);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(width: 4, height: 28, decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? const Color(0xFF111827) : const Color(0xFF9CA3AF))),
                          if (maxAmt != null && maxAmt.toString() != 'null')
                            Text('Plafond: $maxAmt XOF', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                        ],
                      ),
                    ),
                    // Percentage bar
                    SizedBox(
                      width: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(pctStr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: barColor)),
                          const SizedBox(height: 2),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pctVal.clamp(0, 1),
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor: AlwaysStoppedAnimation<Color>(barColor),
                              minHeight: 5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _editRule(context, rule),
                      child: const Icon(Icons.edit, size: 16, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _editRule(BuildContext context, Map<String, dynamic> rule) async {
    final ruleId = rule['id']?.toString() ?? '';
    final bType = rule['beneficiary_type']?.toString() ?? '';
    final pct = rule['percentage'];
    double pctVal = 0;
    if (pct is num) pctVal = pct.toDouble();
    final maxAmt = rule['max_amount'];
    final desc = rule['description']?.toString() ?? '';

    final percentCtrl = TextEditingController(text: pctVal.toString());
    final maxCtrl = TextEditingController(text: maxAmt != null && maxAmt.toString() != 'null' ? maxAmt.toString() : '');
    final descCtrl = TextEditingController(text: desc);

    final bLabel = AdminRevenueSplitProvider.beneficiaryLabels[bType] ?? bType;
    final reasonLabel = AdminRevenueSplitProvider.reasonLabels[reason] ?? reason;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$reasonLabel → $bLabel'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: percentCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Pourcentage (ex: 0.15 = 15%)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Plafond max XOF (vide = pas de plafond)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1EA75C), foregroundColor: Colors.white),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      final newPct = double.tryParse(percentCtrl.text.replaceAll(',', '.')) ?? pctVal;
      final newMax = double.tryParse(maxCtrl.text);
      await provider.upsertRule(
        paymentReason: reason,
        beneficiaryType: bType,
        percentage: newPct,
        maxAmount: newMax,
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      );
    } else if (result == 'delete' && ruleId.isNotEmpty) {
      await provider.deleteRule(ruleId);
    }
  }
}
