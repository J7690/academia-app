import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_td_catalog_provider.dart';

class AdminTdCatalogScreen extends StatefulWidget {
  const AdminTdCatalogScreen({super.key});

  @override
  State<AdminTdCatalogScreen> createState() => _AdminTdCatalogScreenState();
}

class _AdminTdCatalogScreenState extends State<AdminTdCatalogScreen> {
  String? _selectedFieldId;
  String? _selectedProgramId;
  String? _selectedCollectionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminTdCatalogProvider>().loadFields();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminTdCatalogProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('TD - Filières, programmes & séances'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1000;
            final children = [
              Expanded(child: _buildFieldsColumn(context, provider)),
              const SizedBox(width: 12),
              Expanded(child: _buildProgramsColumn(context, provider)),
              const SizedBox(width: 12),
              Expanded(child: _buildCollectionsAndSessions(context, provider)),
            ];

            if (!isWide) {
              return Column(
                children: [
                  Expanded(child: _buildFieldsColumn(context, provider)),
                  const SizedBox(height: 12),
                  Expanded(child: _buildProgramsColumn(context, provider)),
                  const SizedBox(height: 12),
                  Expanded(child: _buildCollectionsAndSessions(context, provider)),
                ],
              );
            }

            return Row(children: children);
          },
        ),
      ),
    );
  }

  Widget _buildFieldsColumn(
    BuildContext context,
    AdminTdCatalogProvider provider,
  ) {
    final fields = provider.fields;

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text('Filières TD'),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Ajouter une filière',
              onPressed: () => _promptCreateField(context, provider),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: fields.isEmpty
                ? const Center(child: Text('Aucune filière TD.'))
                : ListView.builder(
                    itemCount: fields.length,
                    itemBuilder: (context, index) {
                      final f = fields[index];
                      final id = f['id']?.toString() ?? '';
                      final name = f['name']?.toString() ?? '';
                      final status = f['status']?.toString() ?? '';
                      final selected = _selectedFieldId == id;

                      return ListTile(
                        selected: selected,
                        title: Text(name),
                        subtitle: Text('Statut: $status'),
                        onTap: () {
                          setState(() {
                            _selectedFieldId = id;
                            _selectedProgramId = null;
                            _selectedCollectionId = null;
                          });
                          if (id.isNotEmpty) {
                            provider.loadPrograms(fieldId: id);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramsColumn(
    BuildContext context,
    AdminTdCatalogProvider provider,
  ) {
    final programs = provider.programs;
    final hasField = _selectedFieldId != null && _selectedFieldId!.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text('Programmes TD'),
            subtitle: Text(
              hasField
                  ? 'Filière sélectionnée: $_selectedFieldId'
                  : 'Sélectionnez d\'abord une filière.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Ajouter un programme TD',
              onPressed: hasField
                  ? () => _promptCreateProgram(context, provider)
                  : null,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: !hasField
                ? const Center(
                    child: Text('Sélectionnez une filière pour voir les programmes.'),
                  )
                : (programs.isEmpty
                    ? const Center(child: Text('Aucun programme TD.'))
                    : ListView.builder(
                        itemCount: programs.length,
                        itemBuilder: (context, index) {
                          final p = programs[index];
                          final id = p['id']?.toString() ?? '';
                          final title = p['title']?.toString() ?? '';
                          final level = p['level']?.toString() ?? '';
                          final price = p['price']?.toString() ?? '';
                          final status = p['status']?.toString() ?? '';
                          final selected = _selectedProgramId == id;

                          return ListTile(
                            selected: selected,
                            title: Text(title),
                            subtitle: Text('Niveau: $level · Prix: $price · Statut: $status'),
                            onTap: () {
                              setState(() {
                                _selectedProgramId = id;
                                _selectedCollectionId = null;
                              });
                              if (id.isNotEmpty) {
                                provider.loadCollections(programId: id);
                              }
                            },
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsAndSessions(
    BuildContext context,
    AdminTdCatalogProvider provider,
  ) {
    final collections = provider.collections;
    final sessions = provider.sessions;
    final hasProgram = _selectedProgramId != null && _selectedProgramId!.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text('Collections & séances TD'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.playlist_add),
                  tooltip: 'Ajouter une collection',
                  onPressed: hasProgram
                      ? () => _promptCreateCollection(context, provider)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.note_add_outlined),
                  tooltip: 'Ajouter une séance',
                  onPressed: _selectedCollectionId != null &&
                          _selectedCollectionId!.isNotEmpty
                      ? () => _promptCreateSession(context, provider)
                      : null,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: !hasProgram
                ? const Center(
                    child: Text(
                      'Sélectionnez un programme pour gérer les collections et séances.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                'Collections',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: collections.isEmpty
                                  ? const Center(child: Text('Aucune collection.'))
                                  : ListView.builder(
                                      itemCount: collections.length,
                                      itemBuilder: (context, index) {
                                        final c = collections[index];
                                        final id = c['id']?.toString() ?? '';
                                        final title = c['title']?.toString() ?? '';
                                        final selected = _selectedCollectionId == id;
                                        return ListTile(
                                          selected: selected,
                                          title: Text(title),
                                          onTap: () {
                                            setState(() {
                                              _selectedCollectionId = id;
                                            });
                                            if (id.isNotEmpty) {
                                              provider.loadSessions(collectionId: id);
                                            }
                                          },
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                'Séances',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: sessions.isEmpty
                                  ? const Center(child: Text('Aucune séance.'))
                                  : ListView.builder(
                                      itemCount: sessions.length,
                                      itemBuilder: (context, index) {
                                        final s = sessions[index];
                                        final title = s['title']?.toString() ?? '';
                                        final isPreview = s['is_preview'] == true;
                                        return ListTile(
                                          leading: Icon(
                                            isPreview
                                                ? Icons.visibility
                                                : Icons.lock,
                                          ),
                                          title: Text(title),
                                          subtitle: Text(
                                            isPreview
                                                ? 'Prévisualisation'
                                                : 'Contenu verrouillé',
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptCreateField(
    BuildContext context,
    AdminTdCatalogProvider provider,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouvelle filière TD'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nom de la filière',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;
    final name = controller.text.trim();
    final ok = await provider.createField(name: name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Filière TD créée.' : provider.error ?? 'Erreur lors de la création.',
        ),
      ),
    );
  }

  Future<void> _promptCreateProgram(
    BuildContext context,
    AdminTdCatalogProvider provider,
  ) async {
    final levelController = TextEditingController();
    final titleController = TextEditingController();
    final priceController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouveau programme TD'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: levelController,
                decoration: const InputDecoration(
                  labelText: 'Niveau (ex: L1, L2...)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Prix (XOF)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final title = titleController.text.trim();
    final level = levelController.text.trim();
    final priceText = priceController.text.replaceAll(',', '.').trim();
    final fieldId = _selectedFieldId ?? '';
    final price = double.tryParse(priceText) ?? 0;

    final ok = await provider.createProgram(
      fieldId: fieldId,
      level: level,
      title: title,
      price: price,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Programme TD créé.' : provider.error ?? 'Erreur lors de la création.',
        ),
      ),
    );
  }

  Future<void> _promptCreateCollection(
    BuildContext context,
    AdminTdCatalogProvider provider,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouvelle collection TD'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Titre de la collection',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;
    final title = controller.text.trim();
    final programId = _selectedProgramId ?? '';
    final ok = await provider.createCollection(programId: programId, title: title);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Collection TD créée.' : provider.error ?? 'Erreur lors de la création.',
        ),
      ),
    );
  }

  Future<void> _promptCreateSession(
    BuildContext context,
    AdminTdCatalogProvider provider,
  ) async {
    final titleController = TextEditingController();
    bool isPreview = false;
    DateTime? scheduledAt;
    final durationController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Nouvelle séance TD'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre de la séance',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          scheduledAt == null
                              ? 'Aucune date/heure programmée'
                              : 'Programmée le '
                                  '${scheduledAt!.day.toString().padLeft(2, '0')}/'
                                  '${scheduledAt!.month.toString().padLeft(2, '0')}/'
                                  '${scheduledAt!.year} '
                                  '${scheduledAt!.hour.toString().padLeft(2, '0')}:'
                                  '${scheduledAt!.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          final now = DateTime.now();
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: scheduledAt ?? now,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 5),
                          );
                          if (pickedDate == null) return;

                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              scheduledAt ?? now,
                            ),
                          );
                          if (pickedTime == null) return;

                          setStateDialog(() {
                            scheduledAt = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        },
                        child: const Text('Choisir date/heure'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Durée (minutes, optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isPreview,
                        onChanged: (value) {
                          setStateDialog(() {
                            isPreview = value ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text('Séance en mode prévisualisation (gratuite)'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;
    final title = titleController.text.trim();
    final collectionId = _selectedCollectionId ?? '';
    final durationText = durationController.text.trim();
    final duration = int.tryParse(durationText);
    final ok = await provider.createSession(
      collectionId: collectionId,
      title: title,
      isPreview: isPreview,
      scheduledAt: scheduledAt,
      durationMinutes: duration,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Séance TD créée.' : provider.error ?? 'Erreur lors de la création.',
        ),
      ),
    );
  }
}
