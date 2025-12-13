import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/admin_prep_concours_provider.dart';
import '../../../services/prep_ai_service.dart';

class AdminPrepConcoursScreen extends StatefulWidget {
  const AdminPrepConcoursScreen({super.key});

  @override
  State<AdminPrepConcoursScreen> createState() => _AdminPrepConcoursScreenState();
}

class _AdminPrepConcoursScreenState extends State<AdminPrepConcoursScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminPrepConcoursProvider>();
      provider.loadSourceDocuments();
      provider.loadAiGenerations();
    });
  }

  Future<void> _openGenerationDetail(AdminPrepAiGeneration gen) async {
    final output = gen.outputJson;
    final outputText = output == null ? '' : output.toString();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Génération IA'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    gen.id,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text('status: ${gen.status}'),
                  if (gen.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text('error: ${gen.errorMessage}'),
                  ],
                  if (outputText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'output_json',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(outputText),
                  ],
                ],
              ),
            ),
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
  }

  Future<void> _openGenerateDialog() async {
    final subjectIdController = TextEditingController();
    final promptController = TextEditingController();
    final numController = TextEditingController(text: '10');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Générer QCM (IA)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectIdController,
                  decoration: const InputDecoration(
                    labelText: 'Subject ID (UUID) *',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: numController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de questions',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: promptController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Contexte (optionnel)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final subjectId = subjectIdController.text.trim();
                if (subjectId.isEmpty) return;

                final num = int.tryParse(numController.text.trim()) ?? 10;

                Navigator.of(dialogContext).pop();

                try {
                  final res = await PrepAiService.generatePrepQcm(
                    subjectId: subjectId,
                    generationType: 'mcq',
                    prompt: promptController.text.trim().isEmpty
                        ? null
                        : promptController.text.trim(),
                    numQuestions: num,
                  );
                  if (!context.mounted) return;
                  final generationId = (res['generation_id'] ?? '').toString();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        generationId.isEmpty
                            ? 'Génération terminée.'
                            : 'Génération terminée: $generationId',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: const Text('Générer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCreateDialog() async {
    final provider = context.read<AdminPrepConcoursProvider>();

    final yearController = TextEditingController();
    final docTypeController = TextEditingController();
    final statusController = TextEditingController(text: 'received');
    final extractedTextController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nouveau document source'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Année (optionnel)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: docTypeController,
                  decoration: const InputDecoration(labelText: 'Type (optionnel)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: statusController,
                  decoration: const InputDecoration(labelText: 'Statut'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: extractedTextController,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Texte extrait (optionnel)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: provider.isSaving
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final year = int.tryParse(yearController.text.trim());
                      final ok = await provider.upsertSourceDocument(
                        year: year,
                        docType: docTypeController.text.trim().isEmpty
                            ? null
                            : docTypeController.text.trim(),
                        extractedText: extractedTextController.text.trim().isEmpty
                            ? null
                            : extractedTextController.text.trim(),
                        status: statusController.text.trim().isEmpty
                            ? 'received'
                            : statusController.text.trim(),
                      );
                      if (!context.mounted) return;
                      if (ok) {
                        Navigator.of(dialogContext).pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Document créé.')),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(provider.error ?? 'Erreur lors de la création.'),
                          ),
                        );
                      }
                    },
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openDetail(AdminPrepSourceDocument doc) async {
    final provider = context.read<AdminPrepConcoursProvider>();
    final textController = TextEditingController(text: doc.extractedText ?? '');
    String selectedStatus = doc.status;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setStateSheet) {
              return SizedBox(
                height: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Document',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      doc.id,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      items: const [
                        DropdownMenuItem(value: 'received', child: Text('received')),
                        DropdownMenuItem(value: 'extracted', child: Text('extracted')),
                        DropdownMenuItem(value: 'indexed', child: Text('indexed')),
                        DropdownMenuItem(value: 'validated', child: Text('validated')),
                        DropdownMenuItem(value: 'published', child: Text('published')),
                        DropdownMenuItem(value: 'rejected', child: Text('rejected')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setStateSheet(() {
                          selectedStatus = value;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Statut'),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: textController,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        decoration: const InputDecoration(
                          labelText: 'Texte extrait',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: provider.isSaving
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final ok = await provider.updateSourceDocumentText(
                                      documentId: doc.id,
                                      extractedText: textController.text,
                                    );
                                    if (!context.mounted) return;
                                    if (ok) {
                                      messenger.showSnackBar(
                                        const SnackBar(content: Text('Texte mis à jour.')),
                                      );
                                    } else {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text(provider.error ?? 'Erreur.')),
                                      );
                                    }
                                  },
                            child: const Text('Enregistrer texte'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: provider.isSaving
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final ok = await provider.setSourceDocumentStatus(
                                      documentId: doc.id,
                                      status: selectedStatus,
                                    );
                                    if (!context.mounted) return;
                                    if (ok) {
                                      messenger.showSnackBar(
                                        const SnackBar(content: Text('Statut mis à jour.')),
                                      );
                                    } else {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text(provider.error ?? 'Erreur.')),
                                      );
                                    }
                                  },
                            child: const Text('Mettre à jour statut'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: const Text('Prépa concours - Admin'),
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
        actions: [
          IconButton(
            onPressed: context.read<AdminPrepConcoursProvider>().loadSourceDocuments,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recharger',
          ),
          IconButton(
            onPressed: _openGenerateDialog,
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Générer (IA)',
          ),
          IconButton(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Ajouter',
          ),
        ],
      ),
      body: Consumer<AdminPrepConcoursProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.documents.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.documents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.error!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: provider.loadSourceDocuments,
                    child: const Text('Recharger'),
                  ),
                ],
              ),
            );
          }

          final docs = provider.documents;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucun document source.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _openCreateDialog,
                    child: const Text('Créer un premier document'),
                  ),
                ],
              ),
            );
          }

          final generations = provider.generations;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (generations.isNotEmpty) ...[
                const Text(
                  'Générations IA',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (final g in generations.take(10))
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text('Gen ${g.id.substring(0, 8)}…'),
                      subtitle: Text('status: ${g.status} • type: ${g.generationType}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (g.status == 'validated')
                            TextButton(
                              onPressed: provider.isSaving
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      final ok = await context
                                          .read<AdminPrepConcoursProvider>()
                                          .publishAiGeneration(generationId: g.id);
                                      if (!context.mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            ok
                                                ? 'Publication OK.'
                                                : (context
                                                        .read<AdminPrepConcoursProvider>()
                                                        .error ??
                                                    'Publication échouée.'),
                                          ),
                                        ),
                                      );
                                    },
                              child: const Text('Publier'),
                            ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => _openGenerationDetail(g),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Documents sources',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final d in docs) ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text('Document ${d.id.substring(0, 8)}…'),
                    subtitle: Text(() {
                      final subtitleParts = <String>[];
                      if (d.docType != null && d.docType!.isNotEmpty) {
                        subtitleParts.add(d.docType!);
                      }
                      if (d.year != null) {
                        subtitleParts.add(d.year.toString());
                      }
                      subtitleParts.add('status: ${d.status}');
                      return subtitleParts.join(' • ');
                    }()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openDetail(d),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
