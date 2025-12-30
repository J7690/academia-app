import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/student_dossier_documents_provider.dart';

class StudentDossierDocumentsScreen extends StatefulWidget {
  const StudentDossierDocumentsScreen({super.key});

  @override
  State<StudentDossierDocumentsScreen> createState() => _StudentDossierDocumentsScreenState();
}

class _StudentDossierDocumentsScreenState extends State<StudentDossierDocumentsScreen> {
  String _selectedType = 'PIECE_IDENTITE';

  static const List<String> _documentTypes = [
    'PIECE_IDENTITE',
    'PHOTO_IDENTITE',
    'CV',
    'DIPLOME_BEPC',
    'DIPLOME_BAC',
    'RELEVE_BAC',
    'DIPLOME_SUP',
    'RELEVES_SUP',
    'LETTRE_MOTIVATION',
    'CERTIFICAT_LANGUE',
    'AUTRE',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentDossierDocumentsProvider>().loadDocuments();
    });
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
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
        const SnackBar(content: Text('Impossible de lire le contenu du fichier.')),
      );
      return;
    }

    final provider = context.read<StudentDossierDocumentsProvider>();
    final success = await provider.addDocument(
      bytes: bytes,
      fileName: fileName,
      documentType: _selectedType,
      mimeType: file.extension,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document de dossier ajouté avec succès.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Erreur lors de l\'upload.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes documents de dossier'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ces documents ne sont pas envoyés automatiquement aux universités. '
                  'Ils sont conservés par la plateforme et transmis par un administrateur après accord.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Type de document',
                          border: OutlineInputBorder(),
                        ),
                        items: _documentTypes
                            .map(
                              (t) => DropdownMenuItem<String>(
                                value: t,
                                child: Text(t),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedType = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _pickAndUpload,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Uploader'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<StudentDossierDocumentsProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.documents.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return Center(child: Text('Erreur : ${provider.error}'));
                }

                final docs = provider.documents;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Aucun document de dossier envoyé pour le moment.'),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final type = doc['document_type']?.toString() ?? '';
                    final path = doc['storage_path']?.toString() ?? '';
                    final uploadedAt = doc['uploaded_at']?.toString() ?? '';
                    final status = doc['status']?.toString() ?? '';

                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(type.isNotEmpty ? type : 'Document'),
                      subtitle: Text(path),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility),
                            tooltip: 'Voir',
                            onPressed: () async {
                              final provider =
                                  context.read<StudentDossierDocumentsProvider>();
                              final url = await provider.createSignedUrl(path);
                              if (!context.mounted) return;
                              if (url == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      provider.error ??
                                          'Impossible d\'ouvrir le document.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              final uri = Uri.parse(url);
                              final opened = await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                              if (!opened && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Impossible d\'ouvrir le document.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: 'Supprimer',
                            onPressed: () async {
                              final id = doc['id']?.toString();
                              if (id == null || id.isEmpty) {
                                return;
                              }

                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title:
                                      const Text('Supprimer ce document ?'),
                                  content: const Text(
                                    'Cette action est définitive.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: const Text('Annuler'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: const Text('Supprimer'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm != true || !context.mounted) return;

                              final provider =
                                  context.read<StudentDossierDocumentsProvider>();
                              final ok = await provider.deleteDocument(
                                documentId: id,
                                storagePath: path,
                              );

                              if (!context.mounted) return;

                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Document supprimé avec succès.',
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      provider.error ??
                                          'Erreur lors de la suppression.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (status.isNotEmpty)
                                Text(
                                  status,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              if (uploadedAt.isNotEmpty)
                                Text(
                                  uploadedAt,
                                  style: const TextStyle(fontSize: 11),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1EA75C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Retour'),
            ),
          ),
        ),
      ),
    );
  }
}
