import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_course_library_provider.dart';
import '../../../providers/online_courses_catalog_provider.dart';
import '../../../providers/student_online_courses_provider.dart';
import '../../../theme/academia_palette.dart';
import '../../../widgets/academia_motion.dart';
import '../../../widgets/academia_ui.dart';
import '../../../widgets/bobodo_state.dart';
import '../../../widgets/bobodo_view.dart';
import '../course_resource_viewer_screen.dart';
import '../online_course_detail_screen.dart';

/// Onglet Cours — refonte « Ciel Academia ».
///
/// Construction, du plus personnel au plus exploratoire :
///   1. En-tête vert Academia + statistiques personnelles
///   2. Recherche flottante
///   3. « Reprendre » — les cours déjà commencés
///   4. Bandeau Bobodo contextuel
///   5. Catalogue en grille (couverture, niveau, durée, prix, CTA)
///   6. Bibliothèque par domaine, en accordéons
class StudentCoursesTab extends StatefulWidget {
  const StudentCoursesTab({super.key});

  @override
  State<StudentCoursesTab> createState() => _StudentCoursesTabState();
}

class _StudentCoursesTabState extends State<StudentCoursesTab> {
  static const _accent = AcademiaPalette.green600;

  final TextEditingController _searchController = TextEditingController();
  final Set<int> _openDomains = <int>{0};

  String _searchQuery = '';
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    await Future.wait([
      context.read<StudentCourseLibraryProvider>().loadLibrary(),
      context.read<OnlineCoursesCatalogProvider>().loadPublicCourses(),
      context.read<StudentOnlineCoursesProvider>().loadMyCourses(),
    ]);
  }

  void _openCourse(String courseId, String title, {bool enrolled = false}) {
    if (courseId.isEmpty) return;
    Navigator.of(context).push(
      AcademiaPageRoute(
        builder: (_) => OnlineCourseDetailScreen(
          courseId: courseId,
          initialTitle: title,
          initiallyEnrolled: enrolled,
        ),
      ),
    );
  }

  // ─── Rendu ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AcademiaPalette.skyBackground),
      child: Consumer3<OnlineCoursesCatalogProvider,
          StudentOnlineCoursesProvider, StudentCourseLibraryProvider>(
        builder: (context, catalog, myCourses, library, _) {
          final domains = _filterDomains(library.domains);
          final catalogCourses = _filterCourses(catalog.courses);
          final resourceCounts = _countResourcesByType(library.domains);

          return RefreshIndicator(
            color: _accent,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: _header(
                        myCourses,
                        library,
                        resourceCounts['all'] ?? 0,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _searchBar(),
                    ),
                  ],
                ),
                if (library.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: AcademiaErrorBanner(
                      message: library.error!,
                      onRetry: _load,
                    ),
                  ),
                _resumeSection(myCourses),
                _bobodoBanner(myCourses),
                _catalogSection(catalog, catalogCourses),
                _librarySection(library, domains, resourceCounts),
              ],
            ),
          );
        },
      ),
    );
  }

  // 1 ─ En-tête ----------------------------------------------------------

  Widget _header(
    StudentOnlineCoursesProvider myCourses,
    StudentCourseLibraryProvider library,
    int resourceCount,
  ) {
    final domainCount = library.domains.length;
    return AcademiaHeader(
      title: 'Cours',
      subtitle: 'Ta bibliothèque, tes cours en ligne, tes ressources.',
      gradient: AcademiaPalette.coursHeader,
      stats: [
        AcademiaHeaderStat('${myCourses.myCourses.length}', 'mes cours'),
        AcademiaHeaderStat('$domainCount', 'domaines'),
        AcademiaHeaderStat('$resourceCount', 'ressources'),
      ],
    );
  }

  // 2 ─ Recherche --------------------------------------------------------

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AcademiaPalette.surface,
          borderRadius: BorderRadius.circular(AcademiaPalette.rMd),
          border: Border.all(color: AcademiaPalette.border),
          boxShadow: AcademiaPalette.shadowCard,
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 13.5, color: AcademiaPalette.text),
          decoration: InputDecoration(
            hintText: 'Cours, matière, ressource…',
            hintStyle:
                const TextStyle(fontSize: 13.5, color: AcademiaPalette.faint),
            prefixIcon: const Icon(Icons.search, size: 20, color: _accent),
            suffixIcon: AcademiaSwitcher(
              child: _searchQuery.isEmpty
                  ? const SizedBox.shrink(key: ValueKey('vide'))
                  : IconButton(
                      key: const ValueKey('effacer'),
                      icon: const Icon(Icons.close,
                          size: 18, color: AcademiaPalette.faint),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
            ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          onChanged: (value) =>
              setState(() => _searchQuery = value.trim().toLowerCase()),
        ),
      ),
    );
  }

  // 3 ─ Reprendre --------------------------------------------------------

  Widget _resumeSection(StudentOnlineCoursesProvider provider) {
    final courses = provider.myCourses;

    if (courses.isEmpty) {
      // Premier chargement : on montre la forme du rail plutôt qu'un vide.
      if (provider.isLoading) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            AcademiaSectionHeader(title: 'Reprendre', accent: _accent),
            AcademiaSkeletonRail(),
          ],
        );
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AcademiaSectionHeader(
          title: 'Reprendre',
          count: '${courses.length} cours',
          accent: _accent,
        ),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => AcademiaEntrance(
              index: index,
              from: AcademiaEntranceFrom.right,
              distance: 24,
              child: _resumeCard(courses[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _resumeCard(Map<String, dynamic> course) {
    final title = (course['title'] ?? '').toString();
    final courseId = (course['course_id'] ?? '').toString();
    final cover = (course['cover_image_url'] ?? '').toString();
    final category = (course['category'] ?? '').toString();
    final level = (course['level'] ?? '').toString();
    final accessType = (course['access_type'] ?? '').toString();

    final meta = <String>[
      if (category.isNotEmpty) category,
      if (level.isNotEmpty) level,
    ].join(' · ');

    return AcademiaTapScale(
      onTap: () => _openCourse(courseId, title, enrolled: true),
      child: Container(
        width: 262,
        decoration: BoxDecoration(
          color: AcademiaPalette.surface,
          borderRadius: BorderRadius.circular(AcademiaPalette.rLg),
          border: Border.all(color: AcademiaPalette.border),
          boxShadow: AcademiaPalette.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AcademiaCover(
              height: 104,
              imageUrl: cover,
              seed: title,
              icon: Icons.menu_book_rounded,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AcademiaPalette.rLg),
              ),
              overlays: [
                if (accessType.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 12,
                    child: AcademiaCoverTag(label: accessType.toUpperCase()),
                  ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: AcademiaPalette.green700, size: 20),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: AcademiaPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta.isEmpty ? 'Cours en ligne' : meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AcademiaPalette.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Text(
                        'Continuer',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _accent,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.arrow_forward_rounded,
                          size: 15, color: _accent),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4 ─ Bobodo -----------------------------------------------------------

  Widget _bobodoBanner(StudentOnlineCoursesProvider provider) {
    final count = provider.myCourses.length;
    final message = count == 0
        ? "Tu n'as pas encore de cours en ligne. Parcours le catalogue plus bas : "
            "certains cours sont gratuits, tu peux commencer aujourd'hui."
        : "Tu suis $count cours en ligne. Pense à alterner vidéo et exercices : "
            "c'est ce qui fait le plus progresser avant une évaluation.";

    return AcademiaBobodoBanner(
      message: message,
      accent: _accent,
      avatar: const SizedBox(
        width: 44,
        child: BobodoView(state: BobodoState.thinking, size: 42),
      ),
    );
  }

  // 5 ─ Catalogue --------------------------------------------------------

  Widget _catalogSection(
    OnlineCoursesCatalogProvider catalog,
    List<Map<String, dynamic>> courses,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AcademiaSectionHeader(
          kicker: 'Découvrir',
          title: 'Cours en ligne',
          count: '${courses.length}',
          accent: _accent,
        ),
        if (catalog.isLoading && catalog.courses.isEmpty)
          const AcademiaSkeletonGrid(count: 4),
        if (catalog.error != null)
          AcademiaErrorBanner(
            message: catalog.error!,
            onRetry: () => catalog.loadPublicCourses(),
          ),
        if (courses.isEmpty && !catalog.isLoading)
          const AcademiaEmptyState(
            icon: Icons.school_outlined,
            title: 'Aucun cours pour ces critères',
            message:
                'Change de filtre ou vide la recherche pour voir tout le catalogue.',
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 560
                    ? 2
                    : constraints.maxWidth < 980
                        ? 3
                        : 4;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 218,
                  ),
                  itemCount: courses.length,
                  itemBuilder: (context, index) => AcademiaEntrance(
                    index: index,
                    child: _catalogCard(courses[index]),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _catalogCard(Map<String, dynamic> course) {
    final id = (course['id'] ?? '').toString();
    final title = (course['title'] ?? '').toString();
    final level = (course['level'] ?? '').toString();
    final category = (course['category'] ?? '').toString();
    final cover = (course['cover_image_url'] ?? '').toString();
    final hours = course['estimated_hours'];
    final price = course['price'];

    final isFree = price == null || (price is num && price <= 0);
    final priceLabel = isFree ? 'Gratuit' : _formatPrice(price);

    final meta = <String>[
      if (category.isNotEmpty) category,
      if (hours is num && hours > 0) '${hours.toInt()} h',
    ].join(' · ');

    return AcademiaTapScale(
      onTap: () => _openCourse(id, title),
      child: Container(
        decoration: BoxDecoration(
          color: AcademiaPalette.surface,
          borderRadius: BorderRadius.circular(AcademiaPalette.rLg),
          border: Border.all(color: AcademiaPalette.border),
          boxShadow: AcademiaPalette.shadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AcademiaCover(
              height: 92,
              imageUrl: cover,
              seed: title,
              icon: Icons.auto_stories_rounded,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AcademiaPalette.rLg),
              ),
              overlays: [
                if (level.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: AcademiaCoverTag(label: level.toUpperCase()),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.4,
                        fontWeight: FontWeight.w700,
                        height: 1.32,
                        color: AcademiaPalette.ink,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.8,
                          color: AcademiaPalette.faint,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            priceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isFree
                                  ? AcademiaPalette.success
                                  : AcademiaPalette.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: isFree
                                ? AcademiaPalette.green50
                                : _accent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            isFree ? 'Ouvrir' : 'Voir',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isFree
                                  ? AcademiaPalette.green700
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 6 ─ Bibliothèque -----------------------------------------------------

  Widget _librarySection(
    StudentCourseLibraryProvider library,
    List<Map<String, dynamic>> domains,
    Map<String, int> counts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AcademiaSectionHeader(
          kicker: 'Bibliothèque',
          title: 'Par domaine',
          count: '${domains.length} domaines',
          accent: _accent,
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _typeChip('Tous', 'all', counts['all'] ?? 0),
              _typeChip('Vidéos', 'video', counts['video'] ?? 0),
              _typeChip('Audios', 'audio', counts['audio'] ?? 0),
              _typeChip('Documents', 'document', counts['document'] ?? 0),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (library.isLoading && library.domains.isEmpty)
          const AcademiaSkeletonList(count: 3, height: 92)
        else if (domains.isEmpty)
          const AcademiaEmptyState(
            icon: Icons.folder_open_outlined,
            title: 'Aucune ressource trouvée',
            message:
                'Essaie un autre mot-clé, ou reviens sur le filtre « Tous ».',
          )
        else
          ...List.generate(
            domains.length,
            (index) => AcademiaEntrance(
              index: index,
              child: _domainCard(domains[index], index),
            ),
          ),
      ],
    );
  }

  Widget _typeChip(String label, String value, int count) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AcademiaFilterChip(
        label: label,
        count: count,
        selected: _typeFilter == value,
        accent: _accent,
        onTap: () => setState(() => _typeFilter = value),
      ),
    );
  }

  Widget _domainCard(Map<String, dynamic> domain, int index) {
    final title = (domain['title'] ?? '').toString();
    final description = (domain['description'] ?? '').toString();
    final units = (domain['units'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    final resourceCount = units.fold<int>(
      0,
      (sum, unit) =>
          sum +
          (unit['resources'] as List<dynamic>? ?? const []).length,
    );

    final isOpen = _openDomains.contains(index) || _searchQuery.isNotEmpty;
    final tint = _domainTint(index);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: AcademiaPalette.surface,
        borderRadius: BorderRadius.circular(AcademiaPalette.rLg),
        border: Border.all(color: AcademiaPalette.border),
        boxShadow: AcademiaPalette.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AcademiaPalette.rLg),
            onTap: () => setState(() {
              if (_openDomains.contains(index)) {
                _openDomains.remove(index);
              } else {
                _openDomains.add(index);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_domainIcon(index), size: 19, color: tint),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AcademiaPalette.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${units.length} unité(s) · $resourceCount ressource(s)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AcademiaPalette.faint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right,
                        size: 20, color: AcademiaPalette.faint),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AcademiaMotion.fast,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !isOpen
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (description.isNotEmpty) ...[
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: AcademiaPalette.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        ...units.map(_unitBlock),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _unitBlock(Map<String, dynamic> unit) {
    final title = (unit['title'] ?? '').toString();
    final resources = (unit['resources'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    if (resources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 8),
          padding: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AcademiaPalette.border),
            ),
          ),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w800,
              color: AcademiaPalette.faint,
            ),
          ),
        ),
        ...resources.map(_resourceTile),
      ],
    );
  }

  Widget _resourceTile(Map<String, dynamic> resource) {
    final title = (resource['title'] ?? '').toString();
    final description = (resource['description'] ?? '').toString();
    final type = (resource['resource_type'] ?? '').toString().toLowerCase();

    late final IconData icon;
    late final Color color;
    late final String kind;
    if (type.contains('video')) {
      icon = Icons.play_arrow_rounded;
      color = AcademiaPalette.live;
      kind = 'Vidéo';
    } else if (type.contains('audio')) {
      icon = Icons.graphic_eq_rounded;
      color = AcademiaPalette.teal;
      kind = 'Audio';
    } else {
      icon = Icons.description_outlined;
      color = AcademiaPalette.blue;
      kind = 'Document';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          AcademiaPageRoute(
            builder: (_) => CourseResourceViewerScreen(resource: resource),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: AcademiaPalette.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AcademiaPalette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: AcademiaPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description.isEmpty ? kind : '$kind · $description',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AcademiaPalette.faint,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: AcademiaPalette.faint),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Utilitaires ──────────────────────────────────────────────────────

  static Color _domainTint(int index) {
    const tints = [
      AcademiaPalette.green600,
      AcademiaPalette.blue,
      AcademiaPalette.amber,
      AcademiaPalette.purple,
      AcademiaPalette.teal,
    ];
    return tints[index % tints.length];
  }

  static IconData _domainIcon(int index) {
    const icons = [
      Icons.functions_rounded,
      Icons.gavel_rounded,
      Icons.health_and_safety_outlined,
      Icons.terminal_rounded,
      Icons.public_rounded,
    ];
    return icons[index % icons.length];
  }

  static String _formatPrice(dynamic price) {
    if (price is! num) return price.toString();
    final isInt = price % 1 == 0;
    final raw = isInt ? price.toInt().toString() : price.toStringAsFixed(2);
    final buffer = StringBuffer();
    final digits = raw.split('.').first;
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return '$buffer FCFA';
  }

  Map<String, int> _countResourcesByType(List<Map<String, dynamic>> domains) {
    final counts = <String, int>{
      'all': 0,
      'video': 0,
      'audio': 0,
      'document': 0,
    };
    for (final domain in domains) {
      final units = (domain['units'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>();
      for (final unit in units) {
        final resources = (unit['resources'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>();
        for (final resource in resources) {
          counts['all'] = counts['all']! + 1;
          final key = _typeKey(
            (resource['resource_type'] ?? '').toString().toLowerCase(),
          );
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  static String _typeKey(String resourceType) {
    if (resourceType.contains('video')) return 'video';
    if (resourceType.contains('audio')) return 'audio';
    return 'document';
  }

  List<Map<String, dynamic>> _filterCourses(
    List<Map<String, dynamic>> courses,
  ) {
    if (_searchQuery.isEmpty) return courses;
    return courses.where((course) {
      final haystack = [
        course['title'],
        course['short_description'],
        course['category'],
        course['level'],
      ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');
      return haystack.contains(_searchQuery);
    }).toList(growable: false);
  }

  List<Map<String, dynamic>> _filterDomains(
    List<Map<String, dynamic>> domains,
  ) {
    if (_searchQuery.isEmpty && _typeFilter == 'all') return domains;

    final result = <Map<String, dynamic>>[];

    for (final domain in domains) {
      final domainText = [
        domain['title'],
        domain['description'],
      ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');

      final units = (domain['units'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>();

      final keptUnits = <Map<String, dynamic>>[];

      for (final unit in units) {
        final unitText = [
          unit['title'],
          unit['description'],
        ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');

        final resources = (unit['resources'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>();

        final keptResources = resources.where((resource) {
          final resourceType =
              (resource['resource_type'] ?? '').toString().toLowerCase();
          final matchesType =
              _typeFilter == 'all' || _typeKey(resourceType) == _typeFilter;

          if (!matchesType) return false;
          if (_searchQuery.isEmpty) return true;

          final resourceText = [
            resource['title'],
            resource['description'],
          ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');

          return resourceText.contains(_searchQuery) ||
              unitText.contains(_searchQuery) ||
              domainText.contains(_searchQuery);
        }).toList(growable: false);

        if (keptResources.isNotEmpty) {
          keptUnits.add({...unit, 'resources': keptResources});
        }
      }

      if (keptUnits.isNotEmpty) {
        result.add({...domain, 'units': keptUnits});
      }
    }

    return result;
  }
}
