import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/home_formations_provider.dart';
import '../student_university_site_screen.dart';

class StudentHomeFormationsSection extends StatelessWidget {
  const StudentHomeFormationsSection({super.key});

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
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.red,
              ),
            ),
          );
        }

        if (formations.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Les formations disponibles',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A2540),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Découvre les filières proposées par nos universités partenaires.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: formations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final formation = formations[index];
                  final screenWidth = MediaQuery.of(context).size.width;
                  // Largeur de carte responsive : environ 75 % de l'écran,
                  // avec des bornes pour éviter des cartes trop petites ou trop larges.
                  double cardWidth = screenWidth * 0.75;
                  if (cardWidth < 220) {
                    cardWidth = 220;
                  } else if (cardWidth > 340) {
                    cardWidth = 340;
                  }

                  return SizedBox(
                    width: cardWidth,
                    child: _FormationCard(formation: formation),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FormationsLoadingSkeleton extends StatelessWidget {
  const _FormationsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 180,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 260,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final screenWidth = MediaQuery.of(context).size.width;
                double cardWidth = screenWidth * 0.7;
                if (cardWidth < 200) {
                  cardWidth = 200;
                } else if (cardWidth > 320) {
                  cardWidth = 320;
                }

                return Container(
                  width: cardWidth,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FormationCard extends StatelessWidget {
  final HomeFormation formation;

  const _FormationCard({required this.formation});

  @override
  Widget build(BuildContext context) {
    final degree = formation.degreeLevel;
    final locationParts = <String>[];
    if (formation.city != null && formation.city!.isNotEmpty) {
      locationParts.add(formation.city!);
    }
    if (formation.country != null && formation.country!.isNotEmpty) {
      locationParts.add(formation.country!);
    }
    final location = locationParts.join(', ');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE6F3FA),
            Color(0xFFDFF4FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 10),
            blurRadius: 24,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          final slug = formation.universitySlug;
          if (slug == null || slug.isEmpty) {
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StudentUniversitySiteScreen(
                universitySlug: slug,
                universityName: formation.universityName,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Color(0xFF0A2540),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formation.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0A2540),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Offerte par : ${formation.universityName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (degree != null || location.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (degree != null && degree.isNotEmpty)
                      Chip(
                        label: Text(
                          degree,
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (location.isNotEmpty)
                      Chip(
                        label: Text(
                          location,
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
