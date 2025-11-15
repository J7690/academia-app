import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/supabase_provider.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import '../widgets/data_table_widget.dart';

/// Écran de gestion des données utilisant les méthodes validées
/// Force l'utilisation des méthodes API REST validées
class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final _tableNameController = TextEditingController();
  final _dataController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des données - Méthodes validées'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section lecture de données
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list_alt, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Lire des données',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'API REST validée',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tableNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nom de la table',
                              hintText: 'ex: users, products',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (_tableNameController.text.isNotEmpty) {
                              context.read<SupabaseProvider>().readData(_tableNameController.text);
                            }
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('Lire'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Section insertion de données
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_circle, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text(
                          'Insérer des données',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'API REST validée',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _dataController,
                      decoration: const InputDecoration(
                        labelText: 'Données JSON',
                        hintText: '{"name": "test", "value": 123}',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showInsertDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Insérer les données'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Section résultats
            Expanded(
              child: Consumer<SupabaseProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const LoadingWidget(message: 'Opération en cours...');
                  }
                  
                  if (provider.error != null) {
                    return CustomErrorWidget(
                      error: provider.error!,
                      onRetry: () {
                        if (_tableNameController.text.isNotEmpty) {
                          provider.readData(_tableNameController.text);
                        }
                      },
                    );
                  }
                  
                  if (provider.data.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.data_array, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Aucune donnée à afficher',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Sélectionnez une table pour voir les données',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return Column(
                    children: [
                      // Header avec statistiques
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Row(
                          children: [
                            Icon(Icons.data_array, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              '${provider.data.length} enregistrements',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Table: ${_tableNameController.text}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Table des données
                      Expanded(
                        child: DataTableWidget(data: provider.data),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInsertDialog(BuildContext context) {
    if (_tableNameController.text.isEmpty || _dataController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.fromEntries(
        _dataController.text
            .replaceAll('{', '')
            .replaceAll('}', '')
            .split(',')
            .map((e) {
              final parts = e.split(':').map((s) => s.trim().replaceAll('"', '')).toList();
              if (parts.length == 2) {
                return MapEntry(parts[0], parts[1]);
              }
              return MapEntry('', '');
            })
            .where((entry) => entry.key.isNotEmpty)
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur JSON: ${e.toString()}')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer l\'insertion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Table: ${_tableNameController.text}'),
            const SizedBox(height: 8),
            Text('Données: ${_dataController.text}'),
            const SizedBox(height: 16),
            const Text('Cette action utilisera la méthode API REST validée.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final success = await context.read<SupabaseProvider>().insertData(
                _tableNameController.text,
                data,
              );
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Données insérées avec succès via méthode validée')),
                );
                // Rafraîchir les données
                context.read<SupabaseProvider>().readData(_tableNameController.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: ${context.read<SupabaseProvider>().error}')),
                );
              }
            },
            child: const Text('Insérer'),
          ),
        ],
      ),
    );
  }
}
