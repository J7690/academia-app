import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/online_courses_catalog_provider.dart';
import '../../../providers/student_online_courses_provider.dart';
import '../online_course_detail_screen.dart';

class StudentHomeOnlineCoursesSection extends StatelessWidget {
  const StudentHomeOnlineCoursesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<OnlineCoursesCatalogProvider, StudentOnlineCoursesProvider>(
      builder: (context, catalog, myCoursesProvider, child) {
        final catalogCourses = catalog.courses;
        final isLoadingCatalog = catalog.isLoading;
        final error = catalog.error;

        if (isLoadingCatalog && catalogCourses.isEmpty) {
          return const SizedBox(
            height: 80,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (error != null && catalogCourses.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Formations en ligne',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                error,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ],
          );
        }

        if (catalogCourses.isEmpty) {
          return const SizedBox.shrink();
        }

        final enrolledIds = myCoursesProvider.myCourses
            .map((c) => c['course_id']?.toString())
            .whereType<String>()
            .toSet();

        final displayCourses = catalogCourses.take(3).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 1100
                ? 3
                : width >= 700
                    ? 2
                    : 1;
            const spacing = 12.0;
            final cardWidth = crossAxisCount == 1
                ? width
                : (width - (crossAxisCount - 1) * spacing) / crossAxisCount;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Formations en ligne',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sélection de formations en ligne (vidéo, replays, TD).',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: displayCourses.map((course) {
                    final title = (course['title'] ?? '').toString();
                    final shortDescription =
                        (course['short_description'] ?? '').toString();
                    final level = (course['level'] ?? '').toString();
                    final category = (course['category'] ?? '').toString();
                    final courseId = (course['id'] ?? '').toString();

                    final metaParts = <String>[];
                    if (category.isNotEmpty) metaParts.add(category);
                    if (level.isNotEmpty) metaParts.add(level);

                    final dynamic rawPrice = course['price'];
                    num? priceValue;
                    if (rawPrice is num) {
                      priceValue = rawPrice;
                    }
                    String? priceText;
                    if (priceValue != null) {
                      final bool isInt = priceValue % 1 == 0;
                      final formatted = isInt
                          ? priceValue.toInt().toString()
                          : priceValue.toString();
                      priceText = '$formatted FCFA';
                    }

                    final contactPhone =
                        (course['contact_phone'] ?? '').toString().trim();
                    final contactWhatsapp =
                        (course['contact_whatsapp'] ?? '').toString().trim();
                    final contactEmail =
                        (course['contact_email'] ?? '').toString().trim();
                    final contactWebsite =
                        (course['contact_website'] ?? '').toString().trim();

                    final contactParts = <String>[];
                    if (contactPhone.isNotEmpty) {
                      contactParts.add('Tél: $contactPhone');
                    }
                    if (contactWhatsapp.isNotEmpty) {
                      contactParts.add('WhatsApp: $contactWhatsapp');
                    }
                    if (contactEmail.isNotEmpty) {
                      contactParts.add(contactEmail);
                    }
                    if (contactWebsite.isNotEmpty) {
                      contactParts.add(contactWebsite);
                    }
                    final contactSummary = contactParts.isEmpty
                        ? ''
                        : contactParts.take(2).join(' • ');

                    final alreadyEnrolled = enrolledIds.contains(courseId);

                    return SizedBox(
                      width: cardWidth,
                      child: Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (shortDescription.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  shortDescription,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              if (metaParts.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  metaParts.join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                              if (priceText != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Tarif : $priceText',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                              if (contactSummary.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Contacts : $contactSummary',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: courseId.isEmpty
                                      ? null
                                      : () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => OnlineCourseDetailScreen(
                                                courseId: courseId,
                                                initialTitle: title,
                                                initiallyEnrolled: alreadyEnrolled,
                                              ),
                                            ),
                                          );
                                        },
                                  child: Text(
                                    alreadyEnrolled ? 'Accéder' : 'Découvrir',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
