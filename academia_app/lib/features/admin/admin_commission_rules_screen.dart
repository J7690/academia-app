import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_commission_rules_provider.dart';

class AdminCommissionRulesScreen extends StatefulWidget {
  const AdminCommissionRulesScreen({super.key});

  @override
  State<AdminCommissionRulesScreen> createState() =>
      _AdminCommissionRulesScreenState();
}

class _AdminCommissionRulesScreenState
    extends State<AdminCommissionRulesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminCommissionRulesProvider>().loadRules();
    });
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
      case '*':
        return 'Tous types';
      default:
        return reason;
    }
  }

  String _levelLabel(String level) {
    if (level == '*') return 'Tous niveaux';
    return level;
  }

  Future<void> _showUpsertDialog({Map<String, dynamic>? existing}) async {
    final provider = context.read<AdminCommissionRulesProvider>();
    final isEdit = existing != null;

    final reasonCtrl = TextEditingController(
        text: existing?['payment_reason']?.toString() ?? '*');
    final levelCtrl = TextEditingController(
        text: existing?['degree_level']?.toString() ?? '*');
    final rateCtrl = TextEditingController(
        text: existing != null
            ? ((existing['commission_rate'] as num) * 100).toStringAsFixed(1)
            : '10');
    final maxCtrl = TextEditingController(
        text: existing?['max_amount']?.toString() ?? '0');
    final descCtrl = TextEditingController(
        text: existing?['description']?.toString() ?? '');
    final priorityCtrl = TextEditingController(
        text: existing?['priority']?.toString() ?? '0');
    bool isActive = existing?['is_active'] ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Modifier la règle' : 'Nouvelle règle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: reasonCtrl.text,
                      decoration: const InputDecoration(
                          labelText: 'Type de paiement'),
                      items: const [
                        DropdownMenuItem(
                            value: '*', child: Text('Tous types')),
                        DropdownMenuItem(
                            value: 'application_fee',
                            child: Text('Frais de dossier')),
                        DropdownMenuItem(
                            value: 'registration_fee',
                            child: Text("Frais d'inscription")),
                        DropdownMenuItem(
                            value: 'tuition_deposit',
                            child: Text('Acompte scolarité')),
                        DropdownMenuItem(
                            value: 'td_access',
                            child: Text('Accès TD')),
                      ],
                      onChanged: (v) => reasonCtrl.text = v ?? '*',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _knownLevels.contains(levelCtrl.text)
                          ? levelCtrl.text
                          : '*',
                      decoration: const InputDecoration(
                          labelText: 'Niveau de formation'),
                      items: _knownLevels
                          .map((l) => DropdownMenuItem(
                              value: l,
                              child: Text(l == '*' ? 'Tous niveaux' : l)))
                          .toList(),
                      onChanged: (v) => levelCtrl.text = v ?? '*',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rateCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Taux de commission (%)',
                        hintText: 'Ex: 15 pour 15%',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Plafond (XOF)',
                        hintText: '0 = pas de plafond',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Description (optionnel)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priorityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Priorité',
                        hintText: 'Plus élevé = prioritaire',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: (v) =>
                          setDialogState(() => isActive = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: provider.isUpdating
                      ? null
                      : () async {
                          final rate =
                              double.tryParse(rateCtrl.text.replaceAll(',', '.'));
                          if (rate == null || rate < 0 || rate > 100) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Taux invalide (0-100%).')),
                            );
                            return;
                          }
                          final maxAmt =
                              double.tryParse(maxCtrl.text) ?? 0;
                          final priority =
                              int.tryParse(priorityCtrl.text) ?? 0;

                          final ok = await provider.upsertRule(
                            paymentReason: reasonCtrl.text,
                            degreeLevel: levelCtrl.text,
                            commissionRate: rate / 100,
                            maxAmount: maxAmt,
                            description: descCtrl.text.isEmpty
                                ? null
                                : descCtrl.text,
                            priority: priority,
                            isActive: isActive,
                          );
                          if (!dialogContext.mounted) return;
                          if (ok) {
                            Navigator.of(dialogContext).pop(true);
                          } else {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                  content: Text(provider.error ??
                                      'Erreur.')),
                            );
                          }
                        },
                  child: Text(isEdit ? 'Modifier' : 'Créer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(isEdit ? 'Règle modifiée.' : 'Règle créée.')),
      );
    }
  }

  static const _knownLevels = [
    '*',
    'BTS',
    'licence',
    'Licence',
    'LMD',
    'Licence et Master',
    'master',
    'Master',
    'Master1',
    'doctorat',
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminCommissionRulesProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Grille de commissions',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => provider.loadRules(),
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Actualiser',
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showUpsertDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Paramétrez le taux de commission par type de paiement et niveau de formation. '
                'Les commissions sont créées automatiquement à la confirmation d\'un paiement.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              if (provider.isLoading && provider.rules.isEmpty)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (provider.error != null && provider.rules.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Text(provider.error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => provider.loadRules(),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              else if (provider.rules.isEmpty)
                const Center(
                  child: Text('Aucune règle configurée.',
                      style: TextStyle(color: Color(0xFF6B7280))),
                )
              else
                ...provider.rules.map((rule) {
                  final reason =
                      (rule['payment_reason'] ?? '*').toString();
                  final level =
                      (rule['degree_level'] ?? '*').toString();
                  final rate = rule['commission_rate'] as num? ?? 0;
                  final maxAmt = rule['max_amount'] as num? ?? 0;
                  final currency =
                      (rule['currency'] ?? 'XOF').toString();
                  final isActive = rule['is_active'] == true;
                  final desc =
                      (rule['description'] ?? '').toString();
                  final priority = rule['priority'] ?? 0;
                  final ruleId = (rule['id'] ?? '').toString();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFFE5E7EB)
                            : Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB)
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _reasonLabel(reason),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight:
                                              FontWeight.w600,
                                          color:
                                              Color(0xFF2563EB)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C3AED)
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _levelLabel(level),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight:
                                              FontWeight.w600,
                                          color:
                                              Color(0xFF7C3AED)),
                                    ),
                                  ),
                                  if (!isActive) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(
                                                6),
                                      ),
                                      child: const Text('Inactive',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red,
                                              fontWeight:
                                                  FontWeight.w600)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (desc.isNotEmpty)
                                Text(desc,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color:
                                            Color(0xFF6B7280))),
                              Text(
                                'Priorité : $priority',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF9CA3AF)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${(rate * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF16A34A)),
                            ),
                            if (maxAmt > 0)
                              Text(
                                'Max ${maxAmt.toStringAsFixed(0)} $currency',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280)),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () =>
                                      _showUpsertDialog(
                                          existing: rule),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.edit,
                                        size: 16,
                                        color:
                                            Color(0xFF2563EB)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () async {
                                    final confirm =
                                        await showDialog<bool>(
                                      context: context,
                                      builder: (d) => AlertDialog(
                                        title: const Text(
                                            'Supprimer la règle ?'),
                                        content: Text(
                                            'Supprimer : ${_reasonLabel(reason)} × ${_levelLabel(level)}'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(d)
                                                    .pop(false),
                                            child: const Text(
                                                'Annuler'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(d)
                                                    .pop(true),
                                            child: const Text(
                                                'Supprimer',
                                                style: TextStyle(
                                                    color: Colors
                                                        .red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm != true) return;
                                    final ok = await provider
                                        .deleteRule(ruleId);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(ok
                                            ? 'Règle supprimée.'
                                            : (provider.error ??
                                                'Erreur.')),
                                      ),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.delete,
                                        size: 16,
                                        color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
