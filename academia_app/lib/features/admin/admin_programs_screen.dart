import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/admin_programs_provider.dart';

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
              child: Text('Aucun programme disponible.'),
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
