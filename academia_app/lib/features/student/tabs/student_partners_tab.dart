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
  String? _selectedUniversitySlug;

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
                      onTap: () {
                        final id = uni['id']?.toString();
                        final slug = uni['slug']?.toString();
                        if (id == null) return;
                        setState(() {
                          _selectedUniversityId = id;
                          _selectedUniversitySlug = slug;
                        });
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
    if (_selectedUniversitySlug == null || _selectedUniversitySlug!.isEmpty) {
      return const Center(
        child: Text('Sélectionnez une université pour voir son mini-site.'),
      );
    }

    final slug = _selectedUniversitySlug!;
    String? universityName;
    final selectedId = _selectedUniversityId;
    if (selectedId != null) {
      for (final uni in provider.universities) {
        final id = uni['id']?.toString();
        if (id == selectedId) {
          universityName = uni['name']?.toString();
          break;
        }
      }
    }

    return StudentUniversitySiteScreen(
      key: ValueKey(slug),
      universitySlug: slug,
      universityName: universityName,
    );
  }
}
