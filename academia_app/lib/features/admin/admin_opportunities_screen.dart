import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/admin_opportunities_provider.dart';

class AdminOpportunitiesScreen extends StatefulWidget {
  const AdminOpportunitiesScreen({super.key});

  @override
  State<AdminOpportunitiesScreen> createState() => _AdminOpportunitiesScreenState();
}

class _AdminOpportunitiesScreenState extends State<AdminOpportunitiesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminOpportunitiesProvider>();
      provider.loadOpportunities();
      provider.loadTypes();
    });
  }

  Future<void> _showTypesDialog() async {
    final provider = context.read<AdminOpportunitiesProvider>();
    await provider.loadTypes();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Types d\'opportunités'),
          content: Consumer<AdminOpportunitiesProvider>(
            builder: (context, provider, child) {
              final types = provider.types;
              if (types.isEmpty) {
                return const SizedBox(
                  width: 300,
                  child: Text(
                    'Aucun type configuré pour le moment. Ajoutez vos propres types (ex: Stage, Emploi, Bourse, ...).',
                  ),
                );
              }
              return SizedBox(
                width: 320,
                height: 320,
                child: ListView.builder(
                  itemCount: types.length,
                  itemBuilder: (context, index) {
                    final t = types[index];
                    final code = t['code']?.toString() ?? '';
                    final label = t['label']?.toString() ?? '';
                    final isActive = t['is_active'] != false;
                    return ListTile(
                      title: Text(label.isNotEmpty ? label : code),
                      subtitle: Text(code),
                      trailing: Switch(
                        value: isActive,
                        onChanged: (value) async {
                          await provider.upsertType(
                            typeId: t['id']?.toString(),
                            code: code,
                            label: label,
                            sortOrder: t['sort_order'] as int?,
                            isActive: value,
                          );
                        },
                      ),
                      onTap: () {
                        _showEditTypeDialog(existing: t);
                      },
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Fermer'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _showEditTypeDialog();
              },
              icon: const Icon(Icons.add),
              label: const Text('Nouveau type'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditTypeDialog({Map<String, dynamic>? existing}) async {
    final provider = context.read<AdminOpportunitiesProvider>();
    final codeController = TextEditingController(
      text: existing != null ? existing['code']?.toString() ?? '' : '',
    );
    final labelController = TextEditingController(
      text: existing != null ? existing['label']?.toString() ?? '' : '',
    );
    int? sortOrder = existing != null ? existing['sort_order'] as int? : 0;
    bool isActive = existing != null ? (existing['is_active'] != false) : true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Nouveau type' : 'Modifier le type'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Code (ex: internship, job)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Libellé (ex: Stage, Emploi)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ordre d\'affichage',
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value.trim());
                    sortOrder = parsed ?? sortOrder;
                  },
                  controller: TextEditingController(
                    text: (sortOrder ?? 0).toString(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: isActive,
                  onChanged: (value) {
                    isActive = value;
                  },
                  title: const Text('Actif'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final code = codeController.text.trim();
                final label = labelController.text.trim();
                if (code.isEmpty || label.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Merci de renseigner code et libellé.'),
                    ),
                  );
                  return;
                }
                final success = await provider.upsertType(
                  typeId: existing?['id']?.toString(),
                  code: code,
                  label: label,
                  sortOrder: sortOrder,
                  isActive: isActive,
                );
                if (!mounted) return;
                if (success) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showApplicationsDialog(Map<String, dynamic> opportunity) async {
    final provider = context.read<AdminOpportunitiesProvider>();
    final opportunityId = opportunity['id']?.toString();
    if (opportunityId == null) return;

    await provider.loadApplicationsForOpportunity(opportunityId);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Consumer<AdminOpportunitiesProvider>(
          builder: (context, provider, child) {
            final applications = provider.applications;
            final title = opportunity['title']?.toString() ?? '';
            return AlertDialog(
              title: Text('Candidatures - $title'),
              content: SizedBox(
                width: 500,
                height: 450,
                child: applications.isEmpty
                    ? const Center(
                        child: Text('Aucune candidature pour cette opportunité.'),
                      )
                    : ListView.builder(
                        itemCount: applications.length,
                        itemBuilder: (context, index) {
                          final app = applications[index];
                          final applicationId = app['application_id']?.toString() ?? app['id']?.toString() ?? '';
                          final studentId = app['student_id']?.toString() ?? '';
                          final status = app['status']?.toString() ?? 'submitted';
                          final message = app['message']?.toString() ?? '';
                          final createdAt = app['created_at']?.toString() ?? '';
                          final cvUrl = app['cv_url']?.toString() ?? '';
                          final adminNotes = app['admin_notes']?.toString() ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          studentId.isNotEmpty
                                              ? 'Étudiant: ${studentId.substring(0, 8)}...'
                                              : 'Étudiant inconnu',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      _ApplicationStatusBadge(status: status),
                                    ],
                                  ),
                                  if (createdAt.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Soumise le: ${_formatDate(createdAt)}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                  if (message.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      message,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                  if (adminNotes.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.note, size: 14, color: Colors.amber),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              adminNotes,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: status,
                                          decoration: const InputDecoration(
                                            labelText: 'Statut',
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          items: const [
                                            DropdownMenuItem(value: 'submitted', child: Text('Soumise')),
                                            DropdownMenuItem(value: 'pending', child: Text('En attente')),
                                            DropdownMenuItem(value: 'accepted', child: Text('Acceptée')),
                                            DropdownMenuItem(value: 'rejected', child: Text('Refusée')),
                                          ],
                                          onChanged: (newStatus) async {
                                            if (newStatus == null || newStatus == status) return;
                                            final success = await provider.updateApplicationStatus(
                                              applicationId: applicationId,
                                              status: newStatus,
                                              opportunityId: opportunityId,
                                            );
                                            if (!context.mounted) return;
                                            if (success) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Statut mis à jour')),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(provider.error ?? 'Erreur')),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (cvUrl.isNotEmpty)
                                        IconButton(
                                          tooltip: 'Voir le CV',
                                          icon: const Icon(Icons.description),
                                          onPressed: () async {
                                            final signedUrl = await provider.createCvSignedUrl(cvUrl);
                                            if (!context.mounted) return;
                                            if (signedUrl == null) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(provider.error ?? 'Impossible d\'ouvrir le CV.'),
                                                ),
                                              );
                                              return;
                                            }
                                            final uri = Uri.tryParse(signedUrl);
                                            if (uri == null) return;
                                            try {
                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                            } catch (_) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Erreur lors de l\'ouverture du CV.')),
                                              );
                                            }
                                          },
                                        ),
                                      IconButton(
                                        tooltip: 'Ajouter une note',
                                        icon: const Icon(Icons.edit_note),
                                        onPressed: () => _showAddNoteDialog(
                                          context,
                                          provider,
                                          applicationId,
                                          opportunityId,
                                          status,
                                          adminNotes,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Fermer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddNoteDialog(
    BuildContext context,
    AdminOpportunitiesProvider provider,
    String applicationId,
    String opportunityId,
    String currentStatus,
    String currentNotes,
  ) async {
    final notesController = TextEditingController(text: currentNotes);
    
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Note admin'),
          content: TextField(
            controller: notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (visibles uniquement par les admins)',
              hintText: 'Ajouter une note sur cette candidature...',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await provider.updateApplicationStatus(
                  applicationId: applicationId,
                  status: currentStatus,
                  adminNotes: notesController.text.trim(),
                  opportunityId: opportunityId,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Note enregistrée')),
                  );
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _showOpportunityDialog({Map<String, dynamic>? existing}) async {
    final provider = context.read<AdminOpportunitiesProvider>();

    final titleController =
        TextEditingController(text: existing != null ? existing['title']?.toString() ?? '' : '');
    final shortDescriptionController = TextEditingController(
        text: existing != null ? existing['short_description']?.toString() ?? '' : '');
    final descriptionController = TextEditingController(
        text: existing != null ? existing['description']?.toString() ?? '' : '');
    final organizationController = TextEditingController(
        text: existing != null ? existing['organization_name']?.toString() ?? '' : '');
    final countryController = TextEditingController(
        text: existing != null ? existing['country']?.toString() ?? '' : '');
    final cityController = TextEditingController(
        text: existing != null ? existing['city']?.toString() ?? '' : '');

    final types = provider.types;
    String? type = existing != null
        ? existing['type']?.toString()
        : (types.isNotEmpty ? types.first['code']?.toString() : null);
    bool isRemote = existing != null ? (existing['is_remote_possible'] == true) : false;
    bool isFeatured = existing != null ? (existing['is_featured'] == true) : false;
    bool isActive = existing != null ? (existing['is_active'] != false) : true;
    String status = existing != null ? (existing['status']?.toString() ?? 'draft') : 'draft';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Créer une opportunité' : 'Modifier une opportunité'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: shortDescriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Résumé court',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description détaillée',
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                  ),
                  items: types
                      .map(
                        (t) => DropdownMenuItem<String>(
                          value: t['code']?.toString(),
                          child: Text(
                            t['label']?.toString() ??
                                (t['code']?.toString() ?? ''),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: types.isEmpty
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            type = value;
                          });
                        },
                ),
                if (types.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Aucun type configuré. Utilisez "Gérer les types" pour en créer.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: organizationController,
                  decoration: const InputDecoration(
                    labelText: "Organisation",
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: countryController,
                  decoration: const InputDecoration(
                    labelText: 'Pays',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'Ville',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: isRemote,
                  onChanged: (value) {
                    setState(() {
                      isRemote = value;
                    });
                  },
                  title: const Text('Télétravail possible'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Statut',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('Brouillon')),
                    DropdownMenuItem(value: 'published', child: Text('Publié')),
                    DropdownMenuItem(value: 'archived', child: Text('Archivé')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      status = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: isActive,
                  onChanged: (value) {
                    setState(() {
                      isActive = value;
                    });
                  },
                  title: const Text('Actif'),
                ),
                SwitchListTile(
                  value: isFeatured,
                  onChanged: (value) {
                    setState(() {
                      isFeatured = value;
                    });
                  },
                  title: const Text('En vedette'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final shortDesc = shortDescriptionController.text.trim();
                final org = organizationController.text.trim();
                final country = countryController.text.trim();
                final city = cityController.text.trim();
                if (title.isEmpty ||
                    shortDesc.isEmpty ||
                    org.isEmpty ||
                    country.isEmpty ||
                    city.isEmpty ||
                    (type == null || type!.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Merci de remplir tous les champs obligatoires (y compris le type).',
                      ),
                    ),
                  );
                  return;
                }
                final success = await provider.upsertOpportunity(
                  opportunityId: existing?['id']?.toString(),
                  title: title,
                  shortDescription: shortDesc,
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  type: type!,
                  organizationName: org,
                  country: country,
                  city: city,
                  isRemotePossible: isRemote,
                  status: status,
                  isActive: isActive,
                  isFeatured: isFeatured,
                );
                if (!mounted) return;
                if (success) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
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
        title: const Text('Opportunités - Admin'),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showTypesDialog,
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Gérer les types',
          ),
        ],
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
        onPressed: () => _showOpportunityDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle opportunité'),
      ),
      body: Consumer<AdminOpportunitiesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.opportunities.isEmpty) {
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
                    onPressed: provider.loadOpportunities,
                    child: const Text('Recharger'),
                  ),
                ],
              ),
            );
          }

          final opportunities = provider.opportunities;
          if (opportunities.isEmpty) {
            return const Center(
              child: Text('Aucune opportunité disponible.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: opportunities.length,
            itemBuilder: (context, index) {
              final opp = opportunities[index];
              final id = opp['id']?.toString();
              final title = opp['title']?.toString() ?? '';
              final org = opp['organization_name']?.toString() ?? '';
              final type = opp['type']?.toString() ?? '';
              final city = opp['city']?.toString() ?? '';
              final country = opp['country']?.toString() ?? '';
              final status = opp['status']?.toString() ?? '';
              final isFeatured = opp['is_featured'] == true;
              final isActive = opp['is_active'] != false;

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
                                  org,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    if (type.isNotEmpty)
                                      Chip(label: Text(type)),
                                    if (city.isNotEmpty || country.isNotEmpty)
                                      Chip(label: Text('$city, $country')),
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
                                    if (status.isNotEmpty)
                                      Chip(label: Text(status)),
                                    if (isFeatured)
                                      Chip(
                                        label: const Text(
                                          'En vedette',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFFF59E0B),
                                          ),
                                        ),
                                        backgroundColor: const Color(0xFFFEF3C7),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Switch(
                                value: isActive,
                                onChanged: (value) async {
                                  if (id == null) return;
                                  await provider.updateOpportunityStatus(
                                    opportunityId: id,
                                    isActive: value,
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: isFeatured
                                    ? 'Retirer des opportunités en vedette'
                                    : 'Mettre en vedette',
                                icon: Icon(
                                  isFeatured ? Icons.star : Icons.star_border,
                                  color: isFeatured ? Colors.orange : null,
                                ),
                                onPressed: () async {
                                  if (id == null) return;
                                  await provider.updateOpportunityStatus(
                                    opportunityId: id,
                                    isFeatured: !isFeatured,
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: 'Modifier',
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  _showOpportunityDialog(existing: opp);
                                },
                              ),
                              IconButton(
                                tooltip: 'Voir les candidatures',
                                icon: const Icon(Icons.people_outline),
                                onPressed: () {
                                  _showApplicationsDialog(opp);
                                },
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

/// Badge coloré pour le statut d'une candidature
class _ApplicationStatusBadge extends StatelessWidget {
  final String status;

  const _ApplicationStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: config.textColor,
        ),
      ),
    );
  }

  _StatusConfig _getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return _StatusConfig(
          label: 'Soumise',
          bgColor: const Color(0xFFE0F2FE),
          textColor: const Color(0xFF0369A1),
        );
      case 'pending':
        return _StatusConfig(
          label: 'En attente',
          bgColor: const Color(0xFFFEF3C7),
          textColor: const Color(0xFFD97706),
        );
      case 'accepted':
        return _StatusConfig(
          label: 'Acceptée',
          bgColor: const Color(0xFFD1FAE5),
          textColor: const Color(0xFF059669),
        );
      case 'rejected':
        return _StatusConfig(
          label: 'Refusée',
          bgColor: const Color(0xFFFEE2E2),
          textColor: const Color(0xFFDC2626),
        );
      default:
        return _StatusConfig(
          label: status,
          bgColor: const Color(0xFFF3F4F6),
          textColor: const Color(0xFF6B7280),
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final Color bgColor;
  final Color textColor;

  _StatusConfig({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });
}
