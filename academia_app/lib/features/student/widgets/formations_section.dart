import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';

import '../../../providers/home_formations_provider.dart';
import '../student_university_site_screen.dart';

// Palette of rich gradients for formation cards (Cursa-inspired)
const _kCardGradients = <List<Color>>[
  [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
  [Color(0xFF1A2980), Color(0xFF26D0CE)],
  [Color(0xFF0B486B), Color(0xFFF56217)],
  [Color(0xFF2E7D32), Color(0xFF66BB6A)],
  [Color(0xFF4A148C), Color(0xFFAB47BC)],
  [Color(0xFFBF360C), Color(0xFFFF8A65)],
  [Color(0xFF00695C), Color(0xFF4DB6AC)],
  [Color(0xFF283593), Color(0xFF5C6BC0)],
];

class StudentHomeFormationsSection extends StatefulWidget {
  const StudentHomeFormationsSection({super.key});

  @override
  State<StudentHomeFormationsSection> createState() =>
      _StudentHomeFormationsSectionState();
}

class _StudentHomeFormationsSectionState
    extends State<StudentHomeFormationsSection> {
  static const _kMaxVisible = 6;
  String _activeFilter = 'Toutes';

  List<HomeFormation> _applyFilter(List<HomeFormation> all) {
    if (_activeFilter == 'Toutes') return all;
    if (_activeFilter == 'Licence') {
      return all
          .where((f) =>
              (f.degreeLevel ?? '').toLowerCase().contains('licence'))
          .toList(growable: false);
    }
    if (_activeFilter == 'Master') {
      return all
          .where((f) =>
              (f.degreeLevel ?? '').toLowerCase().contains('master'))
          .toList(growable: false);
    }
    // Filter by unique university names
    if (_activeFilter.startsWith('uni:')) {
      final uniName = _activeFilter.substring(4);
      return all
          .where((f) => f.universityName == uniName)
          .toList(growable: false);
    }
    // Filter by city
    if (_activeFilter.startsWith('city:')) {
      final city = _activeFilter.substring(5);
      return all
          .where((f) => f.city == city)
          .toList(growable: false);
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeFormationsProvider>(
      builder: (context, formationsProvider, child) {
        final formations = formationsProvider.formations;
        final isLoading = formationsProvider.isLoading;
        final error = formationsProvider.error;

        if (isLoading && formations.isEmpty) {
          return const _FormationsLoadingSkeleton();
        }

        if (error != null && formations.isEmpty) {
          return Text(
            error,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.red,
            ),
          );
        }

        if (formations.isEmpty) {
          return const SizedBox.shrink();
        }

        final filtered = _applyFilter(formations);
        final visible = filtered.take(_kMaxVisible).toList();
        final totalCount = filtered.length;
        final hasMore = totalCount > _kMaxVisible;

        // Build dynamic chip list
        final chips = <_FilterChipData>[
          _FilterChipData('Toutes', null, formations.length),
        ];
        // Degree chips
        final hasLicence = formations.any(
            (f) => (f.degreeLevel ?? '').toLowerCase().contains('licence'));
        final hasMaster = formations.any(
            (f) => (f.degreeLevel ?? '').toLowerCase().contains('master'));
        if (hasLicence) {
          chips.add(_FilterChipData(
            'Licence',
            null,
            formations
                .where((f) =>
                    (f.degreeLevel ?? '').toLowerCase().contains('licence'))
                .length,
          ));
        }
        if (hasMaster) {
          chips.add(_FilterChipData(
            'Master',
            null,
            formations
                .where((f) =>
                    (f.degreeLevel ?? '').toLowerCase().contains('master'))
                .length,
          ));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Formations disponibles',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF212121),
                    ),
                  ),
                ),
                if (hasMore)
                  Text(
                    '$totalCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Filter chips
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: chips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final chip = chips[index];
                  final isActive = _activeFilter == (chip.filterKey ?? chip.label);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _activeFilter = chip.filterKey ?? chip.label;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            chip.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? Colors.white
                                  : const Color(0xFF616161),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${chip.count}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isActive
                                  ? Colors.white.withOpacity(0.7)
                                  : const Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // Grid (max 6 cards)
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                final cardWidth = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: 10,
                  children: visible.asMap().entries.map((entry) {
                    return FadeInUp(
                      duration: const Duration(milliseconds: 500),
                      delay: Duration(milliseconds: 150 * entry.key),
                      child: SizedBox(
                        width: cardWidth,
                        child: _FormationCard(
                          formation: entry.value,
                          gradientIndex: entry.key,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            // "Voir tout" button
            if (hasMore) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _AllFormationsScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0F2027),
                        Color(0xFF203A43),
                        Color(0xFF2C5364),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withOpacity(0.15),
                        offset: const Offset(0, 3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Voir les $totalCount formations',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF66BB6A),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FilterChipData {
  final String label;
  final String? filterKey;
  final int count;
  const _FilterChipData(this.label, this.filterKey, this.count);
}

class _FormationsLoadingSkeleton extends StatelessWidget {
  const _FormationsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 180,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final cardWidth = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: 10,
              children: List.generate(4, (i) {
                return Container(
                  width: cardWidth,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

class _FormationCard extends StatefulWidget {
  final HomeFormation formation;
  final int gradientIndex;

  const _FormationCard({
    required this.formation,
    required this.gradientIndex,
  });

  @override
  State<_FormationCard> createState() => _FormationCardState();
}

class _FormationCardState extends State<_FormationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  void _onTap() {
    final slug = widget.formation.universitySlug;
    if (slug == null || slug.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentUniversitySiteScreen(
          universitySlug: slug,
          universityName: widget.formation.universityName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formation = widget.formation;
    final degree = formation.degreeLevel;
    final locationParts = <String>[];
    if (formation.city != null && formation.city!.isNotEmpty) {
      locationParts.add(formation.city!);
    }
    if (formation.country != null && formation.country!.isNotEmpty) {
      locationParts.add(formation.country!);
    }
    final location = locationParts.join(', ');

    final colors =
        _kCardGradients[widget.gradientIndex % _kCardGradients.length];

    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, child) {
        final scale = 1.0 - 0.03 * _scaleController.value;
        return Transform.scale(scale: scale, child: child);
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: _onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x28000000),
                offset: Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Decorative circle pattern
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                left: -10,
                bottom: -15,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // University icon
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Title
                    Text(
                      formation.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // University name
                    Text(
                      formation.universityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Badges
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (degree != null && degree.isNotEmpty)
                          _Badge(label: degree),
                        if (location.isNotEmpty)
                          _Badge(label: location),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen "All Formations" page with search + filters + full grid
// ---------------------------------------------------------------------------

class _AllFormationsScreen extends StatefulWidget {
  const _AllFormationsScreen();

  @override
  State<_AllFormationsScreen> createState() => _AllFormationsScreenState();
}

class _AllFormationsScreenState extends State<_AllFormationsScreen> {
  String _query = '';
  String _activeFilter = 'Toutes';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HomeFormation> _filter(List<HomeFormation> all) {
    var list = all;

    // Apply chip filter
    if (_activeFilter == 'Licence') {
      list = list
          .where(
              (f) => (f.degreeLevel ?? '').toLowerCase().contains('licence'))
          .toList(growable: false);
    } else if (_activeFilter == 'Master') {
      list = list
          .where(
              (f) => (f.degreeLevel ?? '').toLowerCase().contains('master'))
          .toList(growable: false);
    } else if (_activeFilter.startsWith('uni:')) {
      final uniName = _activeFilter.substring(4);
      list = list
          .where((f) => f.universityName == uniName)
          .toList(growable: false);
    } else if (_activeFilter.startsWith('city:')) {
      final city = _activeFilter.substring(5);
      list = list.where((f) => f.city == city).toList(growable: false);
    }

    // Apply text search
    if (_query.isNotEmpty) {
      final lq = _query.toLowerCase();
      list = list.where((f) {
        return f.title.toLowerCase().contains(lq) ||
            f.universityName.toLowerCase().contains(lq) ||
            (f.degreeLevel ?? '').toLowerCase().contains(lq) ||
            (f.city ?? '').toLowerCase().contains(lq);
      }).toList(growable: false);
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<HomeFormationsProvider>(
          builder: (context, provider, _) {
            final all = provider.formations;
            final filtered = _filter(all);

            // Build chips: Toutes, Licence, Master, then unique universities
            final chips = <_FilterChipData>[
              _FilterChipData('Toutes', null, all.length),
            ];
            final hasLicence = all.any((f) =>
                (f.degreeLevel ?? '').toLowerCase().contains('licence'));
            final hasMaster = all.any((f) =>
                (f.degreeLevel ?? '').toLowerCase().contains('master'));
            if (hasLicence) {
              chips.add(_FilterChipData(
                'Licence',
                null,
                all
                    .where((f) => (f.degreeLevel ?? '')
                        .toLowerCase()
                        .contains('licence'))
                    .length,
              ));
            }
            if (hasMaster) {
              chips.add(_FilterChipData(
                'Master',
                null,
                all
                    .where((f) => (f.degreeLevel ?? '')
                        .toLowerCase()
                        .contains('master'))
                    .length,
              ));
            }
            // Unique universities
            final uniNames = <String>{};
            for (final f in all) {
              if (f.universityName.isNotEmpty) {
                uniNames.add(f.universityName);
              }
            }
            for (final uni in uniNames) {
              chips.add(_FilterChipData(
                uni.length > 20 ? '${uni.substring(0, 18)}…' : uni,
                'uni:$uni',
                all.where((f) => f.universityName == uni).length,
              ));
            }
            // Unique cities
            final cities = <String>{};
            for (final f in all) {
              if (f.city != null && f.city!.isNotEmpty) {
                cities.add(f.city!);
              }
            }
            for (final city in cities) {
              chips.add(_FilterChipData(
                city,
                'city:$city',
                all.where((f) => f.city == city).length,
              ));
            }

            return Column(
              children: [
                // Header
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
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(21),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) =>
                                setState(() => _query = v.trim()),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Rechercher parmi ${all.length} formations...',
                              hintStyle: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9E9E9E),
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFF2E7D32),
                                size: 20,
                              ),
                              suffixIcon: _query.isNotEmpty
                                  ? IconButton(
                                      icon:
                                          const Icon(Icons.close, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _query = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Filter chips
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: chips.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final chip = chips[index];
                      final key = chip.filterKey ?? chip.label;
                      final isActive = _activeFilter == key;
                      return GestureDetector(
                        onTap: () => setState(() => _activeFilter = key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                chip.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? Colors.white
                                      : const Color(0xFF616161),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${chip.count}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isActive
                                      ? Colors.white.withOpacity(0.7)
                                      : const Color(0xFF9E9E9E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Results count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${filtered.length} formation${filtered.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF757575),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Grid
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off,
                                  size: 40, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              const Text(
                                'Aucune formation trouvée',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF757575),
                                ),
                              ),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            const spacing = 10.0;
                            final cardWidth =
                                (constraints.maxWidth - spacing - 32) / 2;
                            return SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              child: Wrap(
                                spacing: spacing,
                                runSpacing: 10,
                                children: filtered
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  return FadeInUp(
                                    duration: const Duration(milliseconds: 500),
                                    delay: Duration(milliseconds: 80 * entry.key),
                                    child: SizedBox(
                                      width: cardWidth,
                                      child: _FormationCard(
                                        formation: entry.value,
                                        gradientIndex: entry.key,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
