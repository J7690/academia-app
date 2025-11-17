import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../student_university_site_screen.dart';
import '../../../providers/student_offers_provider.dart';
import '../../../providers/student_applications_provider.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';

class StudentPartnersTab extends StatefulWidget {
  const StudentPartnersTab({super.key});

  @override
  State<StudentPartnersTab> createState() => _StudentPartnersTabState();
}

class _StudentPartnersTabState extends State<StudentPartnersTab> {
  String? _selectedUniversityId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentOffersProvider>().loadPartnerUniversities();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentOffersProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.universities.isEmpty) {
          return const LoadingWidget(message: 'Chargement des universités partenaires...');
        }

        if (provider.error != null) {
          return CustomErrorWidget(
            error: provider.error!,
            onRetry: () => provider.loadPartnerUniversities(),
          );
        }

        final universities = provider.universities;

        if (universities.isEmpty) {
          return const Center(
            child: Text('Aucune université partenaire disponible.'),
          );
        }

        return Row(
          children: [
            // Liste des universités
            SizedBox(
              width: 260,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: universities.length,
                itemBuilder: (context, index) {
                  final uni = universities[index];
                  final selected = uni['id'] == _selectedUniversityId;
                  final slug = uni['slug']?.toString();
                  return Card(
                    color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(uni['name']?.toString() ?? ''),
                      subtitle: Text(
                        '${uni['city'] ?? ''}, ${uni['country'] ?? ''}',
                      ),
                      trailing: TextButton.icon(
                        onPressed: (slug == null || slug.isEmpty)
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => StudentUniversitySiteScreen(
                                      universitySlug: slug,
                                      universityName: uni['name']?.toString(),
                                    ),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.school_outlined),
                        label: const Text('Mini-site'),
                      ),
                      onTap: () async {
                        final id = uni['id']?.toString();
                        if (id == null) return;
                        setState(() {
                          _selectedUniversityId = id;
                        });
                        await provider.loadProgramsByUniversity(id);
                      },
                    ),
                  );
                },
              ),
            ),
            const VerticalDivider(width: 1),
            // Programmes de l'université sélectionnée
            Expanded(
              child: _buildProgramsColumn(context, provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgramsColumn(BuildContext context, StudentOffersProvider provider) {
    if (_selectedUniversityId == null) {
      return const Center(
        child: Text('Sélectionnez une université pour voir ses programmes.'),
      );
    }

    final programs = provider.programsByUniversity;

    if (provider.isLoading && programs.isEmpty) {
      return const LoadingWidget(message: 'Chargement des programmes...');
    }

    if (provider.error != null) {
      return CustomErrorWidget(
        error: provider.error!,
        onRetry: () {
          final id = _selectedUniversityId;
          if (id != null) {
            provider.loadProgramsByUniversity(id);
          }
        },
      );
    }

    if (programs.isEmpty) {
      return const Center(
        child: Text('Aucun programme disponible pour cette université.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: programs.length,
      itemBuilder: (context, index) {
        final program = programs[index];
        final title = program['title']?.toString() ?? '';
        final degree = program['degree_level']?.toString() ?? '';
        final mode = program['mode']?.toString() ?? '';
        final programId = (program['program_id'] ?? program['id'])?.toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(title),
            subtitle: Wrap(
              spacing: 8,
              children: [
                if (degree.isNotEmpty)
                  Chip(label: Text(degree)),
                if (mode.isNotEmpty)
                  Chip(label: Text(mode)),
              ],
            ),
            trailing: TextButton.icon(
              onPressed: programId == null
                  ? null
                  : () async {
                      final applicationsProvider =
                          context.read<StudentApplicationsProvider>();
                      final success = await applicationsProvider
                          .createApplication(programId: programId);
                      if (!context.mounted) return;
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Candidature créée avec succès.'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              applicationsProvider.error ??
                                  'Erreur lors de la création de la candidature.',
                            ),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.send),
              label: const Text('Candidater'),
            ),
          ),
        );
      },
    );
  }
}
