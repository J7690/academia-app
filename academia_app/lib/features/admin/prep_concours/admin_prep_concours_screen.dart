import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/admin_prep_concours_provider.dart';
import '../../../providers/prep_concours_provider.dart';
import '../../../services/prep_ai_service.dart';

class AdminPrepConcoursScreen extends StatefulWidget {
  const AdminPrepConcoursScreen({super.key});

  @override
  State<AdminPrepConcoursScreen> createState() => _AdminPrepConcoursScreenState();
}

class _AdminPrepConcoursScreenState extends State<AdminPrepConcoursScreen> {
  String? _selectedSubjectId;
  String? _docStatus;
  String? _genStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminPrepConcoursProvider>();
      provider.loadSourceDocuments();
      provider.loadAiGenerations();

      context.read<PrepConcoursProvider>().loadSubjects();
    });
  }

  Future<void> _reload() async {
    final admin = context.read<AdminPrepConcoursProvider>();
    await Future.wait([
      admin.loadSourceDocuments(subjectId: _selectedSubjectId, status: _docStatus),
      admin.loadAiGenerations(subjectId: _selectedSubjectId, status: _genStatus),
    ]);
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
    final subjectIdController = TextEditingController(text: _selectedSubjectId ?? '');
    final promptController = TextEditingController();
    final numController = TextEditingController(text: '10');
    String selectedSubjectId = _selectedSubjectId ?? '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final subjects = context.read<PrepConcoursProvider>().subjects;

        return AlertDialog(
          title: const Text('Générer des questions'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subjects.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedSubjectId.isNotEmpty ? selectedSubjectId : null,
                    items: subjects
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.title),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      selectedSubjectId = value ?? '';
                      subjectIdController.text = selectedSubjectId;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Matière *',
                    ),
                  )
                else
                  TextField(
                    controller: subjectIdController,
                    decoration: const InputDecoration(
                      labelText: 'Identifiant matière (technique)',
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
                    labelText: 'Instructions (optionnel)',
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

                  setState(() {
                    _selectedSubjectId = subjectId;
                  });
                  await _reload();
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

  Future<void> _openCreateSubjectDialog() async {
    final titleController = TextEditingController();
    final slugController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Créer une matière'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Nom de la matière *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description (optionnel)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: slugController,
                    decoration: const InputDecoration(
                      labelText: 'Code (optionnel) — ex: culture-generale',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                final provider = context.read<PrepConcoursProvider>();
                final messenger = ScaffoldMessenger.of(context);

                Navigator.of(dialogContext).pop();
                final id = await provider.createSubject(
                  title: title,
                  slug: slugController.text.trim().isEmpty ? null : slugController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                );

                if (!context.mounted) return;

                if (id == null || id.isEmpty) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(provider.error ?? 'Création impossible.')),
                  );
                  return;
                }

                messenger.showSnackBar(
                  const SnackBar(content: Text('Matière créée.')),
                );

                setState(() {
                  _selectedSubjectId = id;
                });
                await _reload();
              },
              child: const Text('Créer'),
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
                      final subjectId = (_selectedSubjectId ?? '').trim();
                      if (subjectId.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Choisis une matière avant de créer un document.')),
                        );
                        return;
                      }
                      final year = int.tryParse(yearController.text.trim());
                      final ok = await provider.upsertSourceDocument(
                        subjectId: subjectId,
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
    final subjects = context.watch<PrepConcoursProvider>().subjects;
    final hasSubjectSelected = (_selectedSubjectId ?? '').trim().isNotEmpty;

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
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recharger',
          ),
          IconButton(
            onPressed: hasSubjectSelected ? _openGenerateDialog : null,
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Générer des questions',
          ),
          IconButton(
            onPressed: hasSubjectSelected ? _openCreateDialog : null,
            icon: const Icon(Icons.add),
            tooltip: 'Ajouter un document',
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
          final generations = provider.generations;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Pilotage',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedSubjectId,
                        items: subjects
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.title),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) async {
                          setState(() {
                            _selectedSubjectId = value;
                          });
                          await _reload();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Matière',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: _openCreateSubjectDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Créer une matière'),
                        ),
                      ),
                      if (!hasSubjectSelected) ...[
                        const SizedBox(height: 8),
                        const Text(
                          "Sélectionne (ou crée) une matière pour pouvoir ajouter des documents et générer des questions.",
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _docStatus,
                              items: const [
                                DropdownMenuItem(value: null, child: Text('Tous (docs)')),
                                DropdownMenuItem(value: 'received', child: Text('received')),
                                DropdownMenuItem(value: 'extracted', child: Text('extracted')),
                                DropdownMenuItem(value: 'indexed', child: Text('indexed')),
                                DropdownMenuItem(value: 'validated', child: Text('validated')),
                                DropdownMenuItem(value: 'published', child: Text('published')),
                                DropdownMenuItem(value: 'rejected', child: Text('rejected')),
                              ],
                              onChanged: (value) async {
                                setState(() {
                                  _docStatus = value;
                                });
                                await _reload();
                              },
                              decoration: const InputDecoration(
                                labelText: 'Statut documents',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _genStatus,
                              items: const [
                                DropdownMenuItem(value: null, child: Text('Tous (IA)')),
                                DropdownMenuItem(value: 'proposed', child: Text('proposed')),
                                DropdownMenuItem(value: 'validated', child: Text('validated')),
                                DropdownMenuItem(value: 'published', child: Text('published')),
                                DropdownMenuItem(value: 'failed', child: Text('failed')),
                              ],
                              onChanged: (value) async {
                                setState(() {
                                  _genStatus = value;
                                });
                                await _reload();
                              },
                              decoration: const InputDecoration(
                                labelText: 'Statut générations',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: hasSubjectSelected ? _openCreateDialog : null,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Ajouter un document'),
                          ),
                          ElevatedButton.icon(
                            onPressed: hasSubjectSelected ? _openGenerateDialog : null,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Générer des questions'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Docs: ${docs.length} • Générations: ${generations.length}',
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Générations IA',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (generations.isEmpty)
                const Card(
                  elevation: 0,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucune génération pour le filtre courant.'),
                  ),
                )
              else
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
                                      await _reload();
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Documents sources',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Aucun document source pour le filtre courant.'),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: _openCreateDialog,
                            child: const Text('Créer un document'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
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
