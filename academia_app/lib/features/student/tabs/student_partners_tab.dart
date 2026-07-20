import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../student_university_site_screen.dart';
import '../../../providers/student_offers_provider.dart';
import '../../../providers/student_applications_provider.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../widgets/student_tab_hero.dart';

class StudentPartnersTab extends StatefulWidget {
  const StudentPartnersTab({super.key});

  @override
  State<StudentPartnersTab> createState() => _StudentPartnersTabState();
}

class _StudentPartnersTabState extends State<StudentPartnersTab> {
  String _searchUniversityQuery = '';
  String _searchProgramQuery = '';
  String? _selectedDegreeLevel;

  final TextEditingController _universitySearchController = TextEditingController();
  final TextEditingController _programSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final offersProvider = context.read<StudentOffersProvider>();
      offersProvider.loadPartnerUniversities();
      if (offersProvider.homeOffers.isEmpty) {
        offersProvider.loadHomeOffers();
      }
    });
  }

  @override
  void dispose() {
    _universitySearchController.dispose();
    _programSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentOffersProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.universities.isEmpty) {
          return const LoadingWidget(
            message: 'Chargement des universités partenaires...',
          );
        }

        if (provider.error != null && provider.universities.isEmpty) {
          return CustomErrorWidget(
            error: provider.error!,
            onRetry: () => provider.loadPartnerUniversities(),
          );
        }

        final universities = provider.universities;
        final offers = provider.homeOffers;

        if (universities.isEmpty) {
          return const Center(
            child: Text('Aucune université partenaire disponible.'),
          );
        }

        final allDegreeLevels = <String>{};
        for (final offer in offers) {
          final level = (offer['degree_level'] ?? '').toString().trim();
          if (level.isNotEmpty) {
            allDegreeLevels.add(level);
          }
        }
        final degreeLevels = allDegreeLevels.toList()..sort();
        final totalPrograms = offers.length;

        final filteredUniversities = universities.where((uni) {
          final name = (uni['name'] ?? '').toString();
          final city = (uni['city'] ?? '').toString();
          final country = (uni['country'] ?? '').toString();
          final combined = ('$name $city $country').toLowerCase();

          final queryUni = _searchUniversityQuery.trim().toLowerCase();
          if (queryUni.isNotEmpty && !combined.contains(queryUni)) {
            return false;
          }

          final id = uni['id']?.toString();
          if (id == null) return false;

          final uniPrograms = offers
              .where((offer) => offer['university_id']?.toString() == id)
              .toList(growable: false);

          final queryProgram = _searchProgramQuery.trim().toLowerCase();
          if (queryProgram.isNotEmpty) {
            final matchProgram = uniPrograms.any((p) {
              final title = (p['program_title'] ?? '').toString().toLowerCase();
              final description =
                  (p['program_description'] ?? '').toString().toLowerCase();
              return title.contains(queryProgram) || description.contains(queryProgram);
            });
            if (!matchProgram) {
              return false;
            }
          }

          if (_selectedDegreeLevel != null && _selectedDegreeLevel!.trim().isNotEmpty) {
            final matchLevel = uniPrograms.any((p) {
              final level = (p['degree_level'] ?? '').toString().toLowerCase();
              return level == _selectedDegreeLevel!.toLowerCase();
            });
            if (!matchLevel) {
              return false;
            }
          }

          return true;
        }).toList(growable: false);

        return Container(
          color: const Color(0xFFF3F4F6),
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero header unifié — même style que Candidatures /
                    // Accueil / TD / Concours. Le `Wrap` interne empêche tout
                    // overflow horizontal (fix du 1.6px sur petits écrans).
                    StudentTabHero(
                      icon: Icons.school_outlined,
                      accentColor: const Color(0xFF8B5CF6),
                      title: 'Universités partenaires',
                      subtitle:
                          'Recherchez par université, filière et niveau pour trouver la formation qui vous correspond.',
                      stats: [
                        StudentTabHeroStat(
                          icon: Icons.account_balance_outlined,
                          label:
                              '${universities.length} université${universities.length > 1 ? 's' : ''} partenaire${universities.length > 1 ? 's' : ''}',
                          color: const Color(0xFF0EA5E9),
                        ),
                        if (totalPrograms > 0)
                          StudentTabHeroStat(
                            icon: Icons.menu_book_outlined,
                            label:
                                '$totalPrograms programme${totalPrograms > 1 ? 's' : ''}',
                            color: const Color(0xFF4F46E5),
                          ),
                      ],
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      TextField(
                        controller: _universitySearchController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText:
                              'Rechercher une université (nom, ville, pays)...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchUniversityQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _programSearchController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.school_outlined),
                          hintText:
                              'Rechercher une filière ou un programme (ex: Informatique, Gestion...)',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchProgramQuery = value;
                          });
                        },
                      ),
                      if (degreeLevels.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: Text(
                                'Tous les niveaux',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _selectedDegreeLevel == null
                                      ? const Color(0xFF4F46E5)
                                      : const Color(0xFF374151),
                                ),
                              ),
                              selected: _selectedDegreeLevel == null,
                              onSelected: (_) {
                                setState(() {
                                  _selectedDegreeLevel = null;
                                });
                              },
                              selectedColor: const Color(0xFFEEF2FF),
                              checkmarkColor: const Color(0xFF4F46E5),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: _selectedDegreeLevel == null
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFFE5E7EB),
                              ),
                              shape: const StadiumBorder(),
                            ),
                            ...degreeLevels.map((level) {
                              final isSelected = _selectedDegreeLevel == level;
                              return FilterChip(
                                label: Text(
                                  level,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFF374151),
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    if (_selectedDegreeLevel == level) {
                                      _selectedDegreeLevel = null;
                                    } else {
                                      _selectedDegreeLevel = level;
                                    }
                                  });
                                },
                                selectedColor: const Color(0xFFEEF2FF),
                                checkmarkColor: const Color(0xFF4F46E5),
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF4F46E5)
                                      : const Color(0xFFE5E7EB),
                                ),
                                shape: const StadiumBorder(),
                              );
                            }).toList(),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchUniversityQuery = '';
                              _searchProgramQuery = '';
                              _selectedDegreeLevel = null;
                              _universitySearchController.clear();
                              _programSearchController.clear();
                            });
                          },
                          icon: const Icon(Icons.filter_alt_off),
                          label: const Text('Réinitialiser les filtres'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (filteredUniversities.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32.0),
                            child: Text(
                              'Aucune université ne correspond à vos critères.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        )
                      else
                        _buildUniversitiesGrid(filteredUniversities, offers),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildUniversitiesGrid(
    List<Map<String, dynamic>> universities,
    List<Map<String, dynamic>> offers,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        // Sur mobile : une seule colonne, hauteur libre (ListView) pour éviter tout overflow.
        if (maxWidth < 600) {
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: universities.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final uni = universities[index];
              final id = uni['id']?.toString();
              final uniPrograms = id == null
                  ? <Map<String, dynamic>>[]
                  : offers
                      .where((offer) =>
                          offer['university_id']?.toString() == id)
                      .toList(growable: false);
              return _UniversityCard(
                university: uni,
                programs: uniPrograms,
              );
            },
          );
        }

        // Sur écrans plus larges : grille avec cartes compactes.
        final isWide = maxWidth >= 900;
        final crossAxisCount = isWide ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isWide ? 1.8 : 1.4,
          ),
          itemCount: universities.length,
          itemBuilder: (context, index) {
            final uni = universities[index];
            final id = uni['id']?.toString();
            final uniPrograms = id == null
                ? <Map<String, dynamic>>[]
                : offers
                    .where((offer) => offer['university_id']?.toString() == id)
                    .toList(growable: false);
            return _UniversityCard(
              university: uni,
              programs: uniPrograms,
            );
          },
        );
      },
    );
  }
}

class _DegreeLevelTag extends StatelessWidget {
  final String text;

  const _DegreeLevelTag({required this.text});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF3275D0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _UniversityCard extends StatelessWidget {
  final Map<String, dynamic> university;
  final List<Map<String, dynamic>> programs;

  const _UniversityCard({required this.university, required this.programs});

  @override
  Widget build(BuildContext context) {
    final name = university['name']?.toString() ?? '';
    final city = university['city']?.toString() ?? '';
    final country = university['country']?.toString() ?? '';
    String? slug = university['slug']?.toString();
    if (slug == null || slug.trim().isEmpty) {
      for (final p in programs) {
        final fromOffer = (p['university_slug'] ?? '').toString().trim();
        if (fromOffer.isNotEmpty) {
          slug = fromOffer;
          break;
        }
      }
    }
    final locationText = [city, country]
        .where((e) => e.toString().trim().isNotEmpty)
        .join(', ');

    final degreeLevelsSet = <String>{};
    for (final p in programs) {
      final level = (p['degree_level'] ?? '').toString().trim();
      if (level.isNotEmpty) {
        degreeLevelsSet.add(level);
      }
    }
    final degreeLevels = degreeLevelsSet.toList()..sort();

    final topPrograms = programs.take(2).toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0x80F6A623),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A2540),
              ),
            ),
            if (locationText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                locationText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
            if (degreeLevels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: degreeLevels
                    .map((level) => _DegreeLevelTag(text: level))
                    .toList(),
              ),
            ],
            if (topPrograms.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Quelques formations',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              ...topPrograms.map((p) {
                final title = (p['program_title'] ?? '').toString();
                final level = (p['degree_level'] ?? '').toString();
                final text = level.isNotEmpty ? '$title · $level' : title;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF374151),
                    ),
                  ),
                );
              }).toList(),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: slug == null || slug.isEmpty
                      ? null
                      : () {
                          final universitySlug = slug!;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudentUniversitySiteScreen(
                                universitySlug: universitySlug,
                                universityName: name,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.public),
                  label: const Text('Voir le mini-site'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: programs.isEmpty
                      ? null
                      : () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) {
                              return SafeArea(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    top: 16,
                                    bottom: 16 +
                                        MediaQuery.of(context).viewInsets.bottom,
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Programmes proposés',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              icon: const Icon(Icons.close),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                        const SizedBox(height: 12),
                                        if (programs.isEmpty)
                                          const Text(
                                            'Aucun programme disponible pour cette université.',
                                          )
                                        else
                                          ...programs.map((p) {
                                            final title =
                                                (p['program_title'] ?? '')
                                                    .toString();
                                            final level =
                                                (p['degree_level'] ?? '')
                                                    .toString();
                                            final mode =
                                                (p['mode'] ?? '').toString();
                                            final meta = [
                                              level,
                                              mode,
                                            ]
                                                .where((e) =>
                                                    e.trim().isNotEmpty)
                                                .join(' · ');
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    title,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  if (meta.isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                        top: 2,
                                                      ),
                                                      child: Text(
                                                        meta,
                                                        style:
                                                            const TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Color(0xFF6B7280),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                  child: const Text('Voir les programmes'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
