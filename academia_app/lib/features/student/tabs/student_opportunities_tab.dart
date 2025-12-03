import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_opportunities_provider.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';

class StudentOpportunitiesTab extends StatefulWidget {
  const StudentOpportunitiesTab({super.key});

  @override
  State<StudentOpportunitiesTab> createState() => _StudentOpportunitiesTabState();
}

class _StudentOpportunitiesTabState extends State<StudentOpportunitiesTab> {
  String _searchQuery = '';
  String? _selectedType; // internship, job, other

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reload();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final provider = context.read<StudentOpportunitiesProvider>();
    await provider.loadOpportunities(
      type: _selectedType,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
  }

  Future<void> _applyToOpportunity(Map<String, dynamic> opportunity) async {
    final provider = context.read<StudentOpportunitiesProvider>();
    final id = opportunity['id']?.toString();
    if (id == null) return;

    final messageController = TextEditingController();
    String? cvStoragePath;
    String? cvFileName;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Postuler à cette opportunité'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message (optionnel)',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: false,
                        withData: true,
                        type: FileType.custom,
                        allowedExtensions: const [
                          'pdf',
                          'jpg',
                          'jpeg',
                          'png',
                          'doc',
                          'docx',
                        ],
                      );

                      if (result == null || result.files.isEmpty) {
                        return;
                      }

                      final file = result.files.first;
                      final bytes = file.bytes;
                      final fileName = file.name;

                      if (bytes == null) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Impossible de lire le contenu du fichier.',
                            ),
                          ),
                        );
                        return;
                      }

                      final path = await provider.uploadCvFile(
                        opportunityId: id,
                        bytes: bytes,
                        fileName: fileName,
                        mimeType: file.extension,
                      );

                      if (!mounted) return;

                      if (path != null) {
                        setState(() {
                          cvStoragePath = path;
                          cvFileName = fileName;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('CV ajouté avec succès.'),
                          ),
                        );
                      } else if (provider.error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(provider.error!)),
                        );
                      }
                    },
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      cvFileName == null
                          ? 'Joindre un CV (PDF, image, Word)'
                          : 'CV ajouté : $cvFileName',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await provider.applyForOpportunity(
                  opportunityId: id,
                  message: messageController.text.trim().isEmpty
                      ? null
                      : messageController.text.trim(),
                  cvUrl: cvStoragePath,
                );
                if (!mounted) return;
                if (success) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Envoyer la candidature'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Candidature envoyée avec succès.')),
      );
    } else if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Opportunités',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText:
                          'Rechercher un stage, un emploi ou une opportunité (titre, organisation, ville...)',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _reload();
                    },
                  ),
                  const SizedBox(height: 8),
                  Consumer<StudentOpportunitiesProvider>(
                    builder: (context, provider, child) {
                      final types = provider.types;
                      return Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Tous'),
                            selected: _selectedType == null,
                            onSelected: (_) {
                              setState(() {
                                _selectedType = null;
                              });
                              _reload();
                            },
                          ),
                          for (final t in types)
                            ChoiceChip(
                              label: Text(
                                t['label']?.toString() ??
                                    (t['code']?.toString() ?? ''),
                              ),
                              selected:
                                  _selectedType == t['code']?.toString(),
                              onSelected: (_) {
                                setState(() {
                                  _selectedType =
                                      t['code']?.toString() ?? _selectedType;
                                });
                                _reload();
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<StudentOpportunitiesProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading && provider.opportunities.isEmpty) {
                    return const LoadingWidget(
                      message: 'Chargement des opportunités...',
                    );
                  }

                  if (provider.error != null && provider.opportunities.isEmpty) {
                    return CustomErrorWidget(
                      error: provider.error!,
                      onRetry: _reload,
                    );
                  }

                  final opportunities = provider.opportunities;
                  if (opportunities.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Aucune opportunité disponible pour le moment. Reviens voir régulièrement !',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: opportunities.length,
                    itemBuilder: (context, index) {
                      final opp = opportunities[index];
                      final title = opp['title']?.toString() ?? '';
                      final org = opp['organization_name']?.toString() ?? '';
                      final type = opp['type']?.toString() ?? '';
                      final city = opp['city']?.toString() ?? '';
                      final country = opp['country']?.toString() ?? '';
                      final shortDesc = opp['short_description']?.toString() ?? '';

                      return Card(
                        margin: EdgeInsets.zero,
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                org,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (type.isNotEmpty)
                                    Chip(
                                      label: Text(
                                        type,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (city.isNotEmpty || country.isNotEmpty)
                                    Chip(
                                      label: Text(
                                        '$city, $country',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                              if (shortDesc.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Text(
                                    shortDesc,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ] else
                                const Spacer(),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: () => _applyToOpportunity(opp),
                                  icon: const Icon(Icons.send, size: 16),
                                  label: const Text(
                                    'Postuler',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(0, 32),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
