import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/supabase_provider.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import '../widgets/data_table_widget.dart';

/// Écran principal utilisant les méthodes Supabase validées
/// Force l'utilisation du système automatisé
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Lancer l'audit automatique au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupabaseProvider>().auditDatabase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academia - Projet Supabase'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<SupabaseProvider>().auditDatabase();
            },
            tooltip: 'Rafraîchir l\'audit',
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: () => _showCreateTableDialog(context),
            tooltip: 'Créer une table',
          ),
        ],
      ),
      body: Consumer<SupabaseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const LoadingWidget(message: 'Audit de la base de données en cours...');
          }
          
          if (provider.error != null) {
            return CustomErrorWidget(
              error: provider.error!,
              onRetry: () => provider.auditDatabase(),
            );
          }
          
          if (provider.data.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.table_chart, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucune donnée disponible',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Lancez un audit pour voir les tables',
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
                    Icon(Icons.table_chart, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${provider.data.length} tables détectées',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Via méthodes validées',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showActionMenu(context),
        child: const Icon(Icons.add),
        tooltip: 'Actions',
      ),
    );
  }

  void _showCreateTableDialog(BuildContext context) {
    final tableNameController = TextEditingController();
    final columnNameController = TextEditingController();
    String selectedType = 'TEXT';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer une table (via méthode validée)'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tableNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la table',
                  hintText: 'ex: users, products, etc.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: columnNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la colonne',
                  hintText: 'ex: id, name, email, etc.',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Type de données'),
                items: const [
                  DropdownMenuItem(value: 'TEXT', child: Text('TEXT')),
                  DropdownMenuItem(value: 'INTEGER', child: Text('INTEGER')),
                  DropdownMenuItem(value: 'SERIAL PRIMARY KEY', child: Text('SERIAL PRIMARY KEY')),
                  DropdownMenuItem(value: 'TIMESTAMPTZ DEFAULT NOW()', child: Text('TIMESTAMP')),
                  DropdownMenuItem(value: 'BOOLEAN', child: Text('BOOLEAN')),
                ],
                onChanged: (value) => setState(() => selectedType = value!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (tableNameController.text.isNotEmpty && columnNameController.text.isNotEmpty) {
                Navigator.pop(context);
                
                final success = await context.read<SupabaseProvider>().createTable(
                  tableNameController.text,
                  [
                    {'name': columnNameController.text, 'type': selectedType},
                  ],
                );
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Table créée avec succès via méthode validée')),
                  );
                  // Rafraîchir l'audit
                  context.read<SupabaseProvider>().auditDatabase();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: ${context.read<SupabaseProvider>().error}')),
                  );
                }
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Auditer la base de données'),
            subtitle: const Text('Via méthode RPC validée'),
            onTap: () {
              Navigator.pop(context);
              context.read<SupabaseProvider>().auditDatabase();
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: const Text('Créer une table'),
            subtitle: const Text('Via méthode RPC validée'),
            onTap: () {
              Navigator.pop(context);
              _showCreateTableDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Voir les données'),
            subtitle: const Text('Via méthode API validée'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/data');
            },
          ),
        ],
      ),
    );
  }
}
