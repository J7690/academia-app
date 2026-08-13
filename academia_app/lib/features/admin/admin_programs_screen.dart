import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/admin_programs_provider.dart';
import '../../providers/admin_universities_provider.dart';

class AdminProgramsScreen extends StatefulWidget {
  const AdminProgramsScreen({super.key});

  @override
  State<AdminProgramsScreen> createState() => _AdminProgramsScreenState();
}

class _AdminProgramsScreenState extends State<AdminProgramsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProgramsProvider>().loadPrograms();
    });
  }

  /// Ouvre le formulaire de création/édition d'un programme.
  ///
  /// Permet à l'admin de gérer directement les formations d'un partenaire
  /// sans compte dédié (ex: ANGE Auto École — permis de conduire).
  Future<void> _showProgramDialog({Map<String, dynamic>? existing}) async {
    final programsProvider = context.read<AdminProgramsProvider>();
    final universitiesProvider = context.read<AdminUniversitiesProvider>();

    if (universitiesProvider.universities.isEmpty) {
      await universitiesProvider.loadUniversities();
    }
    if (!mounted) return;

    final universities = universitiesProvider.universities;
    if (universities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun établissement partenaire disponible.'),
        ),
      );
      return;
    }

    final isEdit = existing != null;
    String? selectedUniversityId =
        existing?['university_id']?.toString() ??
            (universities.length == 1
                ? universities.first['id']?.toString()
                : null);

    final titleController =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final descriptionController = TextEditingController(
        text: existing?['description']?.toString() ?? '');
    final degreeController = TextEditingController(
        text: existing?['degree_level']?.toString() ?? '');
    final modeController =
        TextEditingController(text: existing?['mode']?.toString() ?? '');
    final durationController = TextEditingController(
        text: existing?['duration_months']?.toString() ?? '');
    final feesController = TextEditingController(
        text: existing?['tuition_fees']?.toString() ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: Text(
                isEdit ? 'Modifier le programme' : 'Nouveau programme',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedUniversityId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Établissement partenaire',
                      ),
                      items: universities.map((u) {
                        final id = u['id']?.toString() ?? '';
                        final name = u['name']?.toString() ?? '';
                        final isAutoEcole =
                            (u['partner_type'] ?? '').toString() ==
                                'auto_ecole';
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            isAutoEcole ? '🚗 $name' : name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: isEdit
                          ? null
                          : (value) {
                              setStateDialog(() {
                                selectedUniversityId = value;
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titre (ex: Permis B, Licence Informatique)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (facultatif)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: degreeController,
                      decoration: const InputDecoration(
                        labelText:
                            'Niveau (ex: Licence, Master, Permis B...)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: modeController,
                      decoration: const InputDecoration(
                        labelText: 'Mode (ex: Présentiel, En ligne)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Durée en mois (facultatif)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: feesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Frais de formation (FCFA, facultatif)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty ||
                        selectedUniversityId == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Le titre et l\'établissement sont obligatoires.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedUniversityId == null) return;

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final degree = degreeController.text.trim();
    final mode = modeController.text.trim();
    final duration = int.tryParse(durationController.text.trim());
    final fees = num.tryParse(feesController.text.trim());

    final success = await programsProvider.upsertProgram(
      universityId: selectedUniversityId!,
      programId: existing?['id']?.toString(),
      title: title,
      description: description.isEmpty ? null : description,
      degreeLevel: degree.isEmpty ? null : degree,
      mode: mode.isEmpty ? null : mode,
      durationMonths: duration,
      tuitionFees: fees,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (isEdit
                  ? 'Programme mis à jour.'
                  : 'Programme créé avec succès.')
              : programsProvider.error ??
                  'Erreur lors de l\'enregistrement du programme.',
        ),
      ),
    );
  }

  Future<void> _openWebsite(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir le site.")),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de l'ouverture du site.")),
      );
    }
  }

  Future<void> _confirmDeleteProgram(
    BuildContext context,
    AdminProgramsProvider provider,
    String programId,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer le programme'),
          content: Text(
            "Ce programme et tous ses cours seront définitivement supprimés de la base de données.\n\nTitre : " +
                title,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await provider.deleteProgram(programId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Programme et ses cours supprimés définitivement.'
              : provider.error ??
                  'Erreur lors de la suppression du programme.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: const Text('Programmes - Admin'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProgramDialog(),
        backgroundColor: const Color(0xFF1EA75C),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau programme'),
      ),
      body: Consumer<AdminProgramsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.programs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.error!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: provider.loadPrograms,
                    child: const Text('Recharger'),
                  ),
                ],
              ),
            );
          }

          final programs = provider.programs;
          if (programs.isEmpty) {
            return const Center(
              child: Text(
                'Aucun programme disponible.\nUtilisez « Nouveau programme » pour en créer un.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: programs.length,
            itemBuilder: (context, index) {
              final program = programs[index];
              final title = program['title']?.toString() ?? '';
              final universityName = program['university_name']?.toString() ?? '';
              final degree = program['degree_level']?.toString() ?? '';
              final mode = program['mode']?.toString() ?? '';
              final isActive = program['is_active'] == true;
              final highlighted = program['highlighted'] == true;
              final websiteUrl = program['university_website_url']?.toString();
              final programId = program['id']?.toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  universityName,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    if (degree.isNotEmpty)
                                      Chip(label: Text(degree)),
                                    if (mode.isNotEmpty)
                                      Chip(label: Text(mode)),
                                    Chip(
                                      label: Text(
                                        isActive ? 'Actif' : 'Inactif',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isActive
                                              ? const Color(0xFF1EA75C)
                                              : const Color(0xFFFF3B30),
                                        ),
                                      ),
                                      backgroundColor: isActive
                                          ? const Color(0xFFE5F9E7)
                                          : const Color(0xFFFEE2E2),
                                    ),
                                    if (highlighted)
                                      Chip(
                                        label: const Text(
                                          'En vedette',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFFF59E0B),
                                          ),
                                        ),
                                        backgroundColor:
                                            const Color(0xFFFEF3C7),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              IconButton(
                                tooltip: 'Modifier ce programme',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _showProgramDialog(existing: program),
                              ),
                              Switch(
                                value: isActive,
                                onChanged: (value) async {
                                  if (programId == null) return;
                                  await provider.updateProgramStatus(
                                    programId: programId,
                                    isActive: value,
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: highlighted
                                    ? 'Retirer des programmes en vedette'
                                    : 'Mettre en vedette',
                                icon: Icon(
                                  highlighted ? Icons.star : Icons.star_border,
                                  color: highlighted ? Colors.orange : null,
                                ),
                                onPressed: () async {
                                  if (programId == null) return;
                                  await provider.updateProgramStatus(
                                    programId: programId,
                                    highlighted: !highlighted,
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: "Voir le site de l'université",
                                icon: const Icon(Icons.open_in_new),
                                onPressed: (websiteUrl == null || websiteUrl.trim().isEmpty)
                                    ? null
                                    : () => _openWebsite(websiteUrl),
                              ),
                              IconButton(
                                tooltip: 'Supprimer ce programme',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: programId == null
                                    ? null
                                    : () => _confirmDeleteProgram(
                                          context,
                                          provider,
                                          programId,
                                          title,
                                        ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
