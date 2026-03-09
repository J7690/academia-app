import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/home_formations_provider.dart';
import '../../providers/student_short_trainings_provider.dart';
import '../../providers/online_courses_catalog_provider.dart';
import 'student_university_site_screen.dart';
import 'online_course_detail_screen.dart';

/// Unified search screen that searches across all student content:
/// formations, online courses, short trainings, universities, cities.
class StudentSearchScreen extends StatefulWidget {
  const StudentSearchScreen({super.key});

  @override
  State<StudentSearchScreen> createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Search header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        onChanged: (value) {
                          setState(() {
                            _query = value.trim();
                          });
                        },
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText:
                              'Formation, université, ville, cours...',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9E9E9E),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF2E7D32),
                            size: 20,
                          ),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _query = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Results
            Expanded(
              child: _query.isEmpty
                  ? _buildSuggestions()
                  : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        const Text(
          'Suggestions de recherche',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF757575),
          ),
        ),
        const SizedBox(height: 12),
        _SuggestionChip(
          icon: Icons.school_rounded,
          label: 'Formations universitaires',
          color: const Color(0xFF2E7D32),
          onTap: () => _setQuery('formation'),
        ),
        _SuggestionChip(
          icon: Icons.play_circle_outline,
          label: 'Cours en ligne',
          color: const Color(0xFF1565C0),
          onTap: () => _setQuery('cours'),
        ),
        _SuggestionChip(
          icon: Icons.bolt_outlined,
          label: 'Formations courtes',
          color: const Color(0xFFE65100),
          onTap: () => _setQuery('courte'),
        ),
        _SuggestionChip(
          icon: Icons.location_city,
          label: 'Rechercher par ville',
          color: const Color(0xFF6A1B9A),
          onTap: () => _setQuery(''),
        ),
        _SuggestionChip(
          icon: Icons.account_balance,
          label: 'Rechercher par université',
          color: const Color(0xFF00695C),
          onTap: () => _setQuery(''),
        ),
      ],
    );
  }

  void _setQuery(String q) {
    _searchController.text = q;
    setState(() {
      _query = q;
    });
    _focusNode.requestFocus();
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: q.length),
    );
  }

  Widget _buildResults() {
    final lowerQuery = _query.toLowerCase();

    return Consumer3<HomeFormationsProvider, StudentShortTrainingsProvider,
        OnlineCoursesCatalogProvider>(
      builder: (context, formationsProvider, shortTrainingsProvider,
          onlineCoursesProvider, _) {
        final sections = <Widget>[];

        // 1. Formations
        final formations = formationsProvider.formations.where((f) {
          return f.title.toLowerCase().contains(lowerQuery) ||
              f.universityName.toLowerCase().contains(lowerQuery) ||
              (f.degreeLevel ?? '').toLowerCase().contains(lowerQuery) ||
              (f.city ?? '').toLowerCase().contains(lowerQuery) ||
              (f.country ?? '').toLowerCase().contains(lowerQuery);
        }).toList(growable: false);

        if (formations.isNotEmpty) {
          sections.add(_ResultSection(
            title: 'Formations universitaires',
            icon: Icons.school_rounded,
            color: const Color(0xFF2E7D32),
            count: formations.length,
            children: formations.take(6).map((f) {
              return _ResultTile(
                title: f.title,
                subtitle: f.universityName,
                trailing: f.degreeLevel,
                icon: Icons.school_rounded,
                color: const Color(0xFF2E7D32),
                onTap: () {
                  final slug = f.universitySlug;
                  if (slug == null || slug.isEmpty) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudentUniversitySiteScreen(
                        universitySlug: slug,
                        universityName: f.universityName,
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ));
        }

        // 2. Online courses
        final courses = onlineCoursesProvider.courses.where((c) {
          final title = (c['title'] ?? '').toString().toLowerCase();
          final category = (c['category'] ?? '').toString().toLowerCase();
          final level = (c['level'] ?? '').toString().toLowerCase();
          return title.contains(lowerQuery) ||
              category.contains(lowerQuery) ||
              level.contains(lowerQuery);
        }).toList(growable: false);

        if (courses.isNotEmpty) {
          sections.add(_ResultSection(
            title: 'Cours en ligne',
            icon: Icons.play_circle_outline,
            color: const Color(0xFF1565C0),
            count: courses.length,
            children: courses.take(6).map((c) {
              final title = (c['title'] ?? '').toString();
              final category = (c['category'] ?? '').toString();
              final courseId = c['id']?.toString() ?? '';
              return _ResultTile(
                title: title,
                subtitle: category,
                icon: Icons.play_circle_outline,
                color: const Color(0xFF1565C0),
                onTap: () {
                  if (courseId.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OnlineCourseDetailScreen(
                          courseId: courseId,
                          initialTitle: title,
                        ),
                      ),
                    );
                  }
                },
              );
            }).toList(),
          ));
        }

        // 3. Short trainings
        final sessions = shortTrainingsProvider.publicSessions.where((s) {
          final title = (s['title'] ?? '').toString().toLowerCase();
          final category = (s['category'] ?? '').toString().toLowerCase();
          final location = (s['location'] ?? '').toString().toLowerCase();
          return title.contains(lowerQuery) ||
              category.contains(lowerQuery) ||
              location.contains(lowerQuery);
        }).toList(growable: false);

        if (sessions.isNotEmpty) {
          sections.add(_ResultSection(
            title: 'Formations courtes',
            icon: Icons.bolt_outlined,
            color: const Color(0xFFE65100),
            count: sessions.length,
            children: sessions.take(6).map((s) {
              final title = (s['title'] ?? '').toString();
              final category = (s['category'] ?? '').toString();
              return _ResultTile(
                title: title,
                subtitle: category,
                icon: Icons.bolt_outlined,
                color: const Color(0xFFE65100),
                onTap: () {},
              );
            }).toList(),
          ));
        }

        if (sections.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  'Aucun résultat pour "$_query"',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF757575),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Essaie avec un autre terme',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          children: sections,
        );
      },
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  final List<Widget> children;

  const _ResultSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailing;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ResultTile({
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF212121),
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF757575),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null && trailing!.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
