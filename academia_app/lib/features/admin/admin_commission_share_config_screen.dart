import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_commission_share_config_provider.dart';

class AdminCommissionShareConfigScreen extends StatefulWidget {
  const AdminCommissionShareConfigScreen({super.key});

  @override
  State<AdminCommissionShareConfigScreen> createState() =>
      _AdminCommissionShareConfigScreenState();
}

class _AdminCommissionShareConfigScreenState
    extends State<AdminCommissionShareConfigScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminCommissionShareConfigProvider>().loadConfigs();
    });
  }

  Future<void> _showUpsertDialog({CommissionShareConfig? existing}) async {
    final provider = context.read<AdminCommissionShareConfigProvider>();
    final isEdit = existing != null;

    final nameCtrl = TextEditingController(
        text: existing?.scenarioName ?? '');
    final ownerCtrl = TextEditingController(
        text: existing != null
            ? existing.ownerPercentage.toStringAsFixed(0)
            : '100');
    final promoterCtrl = TextEditingController(
        text: existing != null
            ? existing.promoterPercentage.toStringAsFixed(0)
            : '0');
    final platformCtrl = TextEditingController(
        text: existing != null
            ? existing.platformPercentage.toStringAsFixed(0)
            : '0');
    final creatorCtrl = TextEditingController(
        text: existing != null
            ? existing.creatorPercentage.toStringAsFixed(0)
            : '0');
    final windowCtrl = TextEditingController(
        text: existing != null
            ? existing.promoterWindowDays.toString()
            : '30');
    final descCtrl = TextEditingController(
        text: existing?.description ?? '');
    bool isActive = existing?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Modifier le scénario' : 'Nouveau scénario'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom du scénario',
                        hintText: 'ex: first_click_100, hybrid_80_20',
                      ),
                      enabled: !isEdit,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ownerCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Owner %',
                              suffixText: '%',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: promoterCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Promoteur %',
                              suffixText: '%',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: platformCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Platform %',
                              suffixText: '%',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: creatorCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Créateur %',
                              suffixText: '%',
                              helperText: 'Part du créateur du visuel',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: windowCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Fenêtre promoteur',
                              suffixText: 'jours',
                              helperText: 'Validité du clic promoteur',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Description du scénario',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Actif'),
                      value: isActive,
                      onChanged: (value) => setDialogState(() => isActive = value),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final total = (double.tryParse(ownerCtrl.text) ?? 0) +
                            (double.tryParse(promoterCtrl.text) ?? 0) +
                            (double.tryParse(creatorCtrl.text) ?? 0) +
                            (double.tryParse(platformCtrl.text) ?? 0);
                        return Text(
                          'Total: $total% (owner + promoteur + créateur + plateforme)',
                          style: TextStyle(
                            color: total != 100 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final owner = double.tryParse(ownerCtrl.text) ?? 0;
                    final promoter = double.tryParse(promoterCtrl.text) ?? 0;
                    final platform = double.tryParse(platformCtrl.text) ?? 0;
                    final creator = double.tryParse(creatorCtrl.text) ?? 0;
                    final windowDays = int.tryParse(windowCtrl.text) ?? 30;

                    if (owner + promoter + creator + platform != 100) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Owner + Promoteur + Créateur + Plateforme doivent totaliser 100%'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (nameCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Le nom du scénario est requis'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final success = await provider.upsertConfig(
                      scenarioName: nameCtrl.text,
                      ownerPercentage: owner,
                      promoterPercentage: promoter,
                      platformPercentage: platform,
                      creatorPercentage: creator,
                      promoterWindowDays: windowDays,
                      description: descCtrl.text.isEmpty ? null : descCtrl.text,
                      isActive: isActive,
                    );
                    
                    if (success && dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: const Text('Enregistrer'),
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
          content: Text(isEdit ? 'Scénario modifié' : 'Scénario créé'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _setActiveScenario(String scenarioName) async {
    final provider = context.read<AdminCommissionShareConfigProvider>();
    final success = await provider.setActiveScenario(scenarioName);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scénario activé'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration Partage Commissions'),
      ),
      body: Consumer<AdminCommissionShareConfigProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Erreur: ${provider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadConfigs(),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (provider.configs.isEmpty) {
            return const Center(
              child: Text('Aucun scénario configuré'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.configs.length,
            itemBuilder: (context, index) {
              final config = provider.configs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text(config.scenarioName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Owner: ${config.ownerPercentage}% | '
                        'Promoteur: ${config.promoterPercentage}% | '
                        'Créateur: ${config.creatorPercentage}% | '
                        'Platform: ${config.platformPercentage}%',
                      ),
                      Text(
                        'Fenêtre promoteur: ${config.promoterWindowDays} jours',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (config.description != null)
                        Text(config.description!),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (config.isActive)
                        const Icon(Icons.check_circle, color: Colors.green),
                      IconButton(
                        icon: const Icon(Icons.power_settings_new),
                        onPressed: () => _setActiveScenario(config.scenarioName),
                        tooltip: 'Activer ce scénario',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showUpsertDialog(existing: config),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUpsertDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
