import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_course_library_provider.dart';
import '../../../providers/online_courses_catalog_provider.dart';
import '../../../providers/student_online_courses_provider.dart';
import '../course_resource_viewer_screen.dart';
import '../online_course_detail_screen.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../../../widgets/bobodo_state.dart';
import '../../../widgets/bobodo_view.dart';

class StudentCoursesTab extends StatefulWidget {
  const StudentCoursesTab({super.key});

  @override
  State<StudentCoursesTab> createState() => _StudentCoursesTabState();
}

class _StudentCoursesTabState extends State<StudentCoursesTab> {
  String _searchQuery = '';
  String _typeFilter = 'all'; // all, video, audio, document

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentCourseLibraryProvider>().loadLibrary();
      context.read<OnlineCoursesCatalogProvider>().loadPublicCourses();
      context.read<StudentOnlineCoursesProvider>().loadMyCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bibliothèque de cours',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ressources pédagogiques organisées par domaine et matière.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: BobodoView(
                        state: BobodoState.thinking,
                        size: 40,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Tu peux utiliser ces ressources pour consolider tes cours, préparer tes évaluations et enrichir ton dossier. Je t’aide à rester organisé(e) dans ta révision.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un cours, une matière ou une ressource...',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildTypeChip('Tous', 'all'),
                    _buildTypeChip('Vidéos', 'video'),
                    _buildTypeChip('Audios', 'audio'),
                    _buildTypeChip('Documents', 'document'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer3<OnlineCoursesCatalogProvider,
                StudentOnlineCoursesProvider, StudentCourseLibraryProvider>(
              builder: (context, catalogProvider, myCoursesProvider,
                  libraryProvider, child) {
                if (libraryProvider.isLoading && libraryProvider.domains.isEmpty) {
                  return const LoadingWidget(
                    message: 'Chargement de la bibliothèque de cours...',
                  );
                }

                if (libraryProvider.error != null) {
                  return CustomErrorWidget(
                    error: libraryProvider.error!,
                    onRetry: () => libraryProvider.loadLibrary(),
                  );
                }

                final filteredDomains = _filterDomains(libraryProvider.domains);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _buildOnlineCoursesSection(
                      context,
                      catalogProvider,
                      myCoursesProvider,
                    ),
                    const SizedBox(height: 16),
                    if (filteredDomains.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Aucune ressource trouvée pour ces critères.',
                          ),
                        ),
                      )
                    else
                      ...filteredDomains.map((domain) {
                        final title = (domain['title'] ?? '').toString();
                        final description =
                            (domain['description'] ?? '').toString();
                        final units =
                            (domain['units'] as List<dynamic>? ?? const [])
                                .whereType<Map<String, dynamic>>()
                                .toList(growable: false);

                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
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
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    description,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                ...units.map((unit) => _buildUnitSection(unit)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String value) {
    final selected = _typeFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: selected ? const Color(0xFF006D3C) : Colors.black87,
        ),
      ),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _typeFilter = value;
        });
      },
      selectedColor: const Color(0xFFE5F9E7),
      backgroundColor: const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? const Color(0xFF1EA75C) : Colors.transparent,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterDomains(
    List<Map<String, dynamic>> domains,
  ) {
    if (_searchQuery.isEmpty && _typeFilter == 'all') {
      return domains;
    }

    final List<Map<String, dynamic>> result = [];

    for (final domain in domains) {
      final domainTitle = (domain['title'] ?? '').toString().toLowerCase();
      final domainDescription =
          (domain['description'] ?? '').toString().toLowerCase();
      final units =
          (domain['units'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);

      final List<Map<String, dynamic>> filteredUnits = [];

      for (final unit in units) {
        final unitTitle = (unit['title'] ?? '').toString().toLowerCase();
        final unitDescription =
            (unit['description'] ?? '').toString().toLowerCase();
        final resources =
            (unit['resources'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .toList(growable: false);

        final List<Map<String, dynamic>> filteredResources = [];

        for (final res in resources) {
          final resTitle = (res['title'] ?? '').toString().toLowerCase();
          final resDescription =
              (res['description'] ?? '').toString().toLowerCase();
          final resType = (res['resource_type'] ?? '').toString().toLowerCase();

          final matchesType = _typeFilter == 'all' ||
              (_typeFilter == 'video' && resType.contains('video')) ||
              (_typeFilter == 'audio' && resType.contains('audio')) ||
              (_typeFilter == 'document' &&
                  (resType.contains('pdf') ||
                      resType.contains('doc') ||
                      resType.contains('ppt') ||
                      resType.contains('file')));

          final matchesSearch = _searchQuery.isEmpty ||
              domainTitle.contains(_searchQuery) ||
              domainDescription.contains(_searchQuery) ||
              unitTitle.contains(_searchQuery) ||
              unitDescription.contains(_searchQuery) ||
              resTitle.contains(_searchQuery) ||
              resDescription.contains(_searchQuery);

          if (matchesType && matchesSearch) {
            filteredResources.add(res);
          }
        }

        if (filteredResources.isNotEmpty) {
          final newUnit = Map<String, dynamic>.from(unit);
          newUnit['resources'] = filteredResources;
          filteredUnits.add(newUnit);
        }
      }

      if (filteredUnits.isNotEmpty) {
        final newDomain = Map<String, dynamic>.from(domain);
        newDomain['units'] = filteredUnits;
        result.add(newDomain);
      }
    }

    return result;
  }

  Widget _buildOnlineCoursesSection(
    BuildContext context,
    OnlineCoursesCatalogProvider catalog,
    StudentOnlineCoursesProvider myCoursesProvider,
  ) {
    final catalogCourses = catalog.courses;
    final myCourses = myCoursesProvider.myCourses;

    final isLoadingCatalog = catalog.isLoading;
    final isLoadingMy = myCoursesProvider.isLoading;

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cours en ligne',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Découvre les cours en ligne structurés (vidéo, chapitres, progression).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (isLoadingCatalog || isLoadingMy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            if (myCourses.isNotEmpty) ...[
              const Text(
                'Mes cours en ligne',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...myCourses.take(3).map((c) {
                final title = (c['title'] ?? '').toString();
                final courseId = (c['course_id'] ?? '').toString();
                final accessType = (c['access_type'] ?? '').toString();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    accessType.isNotEmpty
                        ? 'Accès : $accessType'
                        : 'Cours en ligne',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (courseId.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OnlineCourseDetailScreen(
                          courseId: courseId,
                          initialTitle: title,
                          initiallyEnrolled: true,
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
              if (myCourses.length > 3)
                Text(
                  '+ ${myCourses.length - 3} autre(s) cours',
                  style: const TextStyle(fontSize: 12),
                ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Catalogue des cours en ligne',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (catalog.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  catalog.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            if (catalogCourses.isEmpty && !isLoadingCatalog)
              const Text(
                'Aucun cours en ligne disponible pour le moment.',
                style: TextStyle(fontSize: 12),
              )
            else
              ...catalogCourses.take(5).map((c) {
                final title = (c['title'] ?? '').toString();
                final shortDescription =
                    (c['short_description'] ?? '').toString();
                final level = (c['level'] ?? '').toString();
                final category = (c['category'] ?? '').toString();
                final courseId = (c['id'] ?? '').toString();

                final metaParts = <String>[];
                if (category.isNotEmpty) metaParts.add(category);
                if (level.isNotEmpty) metaParts.add(level);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (shortDescription.isNotEmpty)
                        Text(
                          shortDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (metaParts.isNotEmpty)
                        Text(
                          metaParts.join(' • '),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (courseId.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OnlineCourseDetailScreen(
                          courseId: courseId,
                          initialTitle: title,
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitSection(Map<String, dynamic> unit) {
    final title = (unit['title'] ?? '').toString();
    final description = (unit['description'] ?? '').toString();
    final resources =
        (unit['resources'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);

    if (resources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              description,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              int crossAxisCount;
              if (width < 600) {
                crossAxisCount = 1;
              } else if (width < 1000) {
                crossAxisCount = 2;
              } else {
                crossAxisCount = 3;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3,
                ),
                itemCount: resources.length,
                itemBuilder: (context, index) {
                  final res = resources[index];
                  return _buildResourceTile(res);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResourceTile(Map<String, dynamic> res) {
    final title = (res['title'] ?? '').toString();
    final description = (res['description'] ?? '').toString();
    final type = (res['resource_type'] ?? '').toString().toLowerCase();

    IconData icon;
    Color cardColor;
    if (type.contains('video')) {
      icon = Icons.play_circle_fill;
      cardColor = const Color(0xFFE6F4EA);
    } else if (type.contains('audio')) {
      icon = Icons.audiotrack;
      cardColor = const Color(0xFFE3F2FD);
    } else {
      icon = Icons.insert_drive_file;
      cardColor = const Color(0xFFF5F5F5);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1EA75C)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: description.isNotEmpty
            ? Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CourseResourceViewerScreen(resource: res),
            ),
          );
        },
      ),
    );
  }
}
