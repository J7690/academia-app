import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/prep_concours_provider.dart';
import 'prep_chapters_screen.dart';

class PrepConcoursHomeScreen extends StatefulWidget {
  const PrepConcoursHomeScreen({super.key});

  @override
  State<PrepConcoursHomeScreen> createState() => _PrepConcoursHomeScreenState();
}

class _PrepConcoursHomeScreenState extends State<PrepConcoursHomeScreen> {
  bool _initialized = false;

  Future<bool> _checkAccess() async {
    final client = Supabase.instance.client;
    final dynamic res = await client.rpc(
      'app_has_feature_access',
      params: {'p_feature_key': 'prep_concours'},
    );
    return res == true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccess().then((allowed) async {
        if (!mounted) return;
        if (!allowed) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Prépa concours'),
                content: const Text(
                  'Cette fonctionnalité est réservée aux comptes ayant accès au module.\n\nContacte le support ou souscris à l’offre correspondante.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Fermer'),
                  ),
                ],
              );
            },
          );
          if (!mounted) return;
          Navigator.of(context).pop();
          return;
        }
        context.read<PrepConcoursProvider>().loadSubjects();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        title: const Text('Préparation concours'),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer<PrepConcoursProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.subjects.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.subjects.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: provider.loadSubjects,
                      child: const Text('Recharger'),
                    ),
                  ],
                ),
              ),
            );
          }

          final subjects = provider.subjects;
          if (subjects.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Aucune matière n\'est encore disponible.\n(Le module est prêt, il manque juste le contenu.)',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final s = subjects[index];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text(s.title),
                  subtitle: s.description != null && s.description!.trim().isNotEmpty
                      ? Text(
                          s.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      : const Text('Commencer'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PrepChaptersScreen(subject: s),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
