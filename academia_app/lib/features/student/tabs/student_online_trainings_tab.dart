import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/online_courses_catalog_provider.dart';
import '../../../providers/student_online_courses_provider.dart';
import '../../../providers/student_online_course_messages_provider.dart';
import '../online_course_detail_screen.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';

class StudentOnlineTrainingsTab extends StatefulWidget {
  const StudentOnlineTrainingsTab({super.key});

  @override
  State<StudentOnlineTrainingsTab> createState() => _StudentOnlineTrainingsTabState();
}

class _StudentOnlineTrainingsTabState extends State<StudentOnlineTrainingsTab> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
                  'Formations en ligne',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Catalogue de formations 100% en ligne : vidéos, audios, TD live et replays.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Rechercher une formation en ligne...',
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
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer2<OnlineCoursesCatalogProvider,
                StudentOnlineCoursesProvider>(
              builder: (context, catalogProvider, myCoursesProvider, child) {
                if (catalogProvider.isLoading &&
                    catalogProvider.courses.isEmpty &&
                    myCoursesProvider.isLoading &&
                    myCoursesProvider.myCourses.isEmpty) {
                  return const LoadingWidget(
                    message: 'Chargement des formations en ligne...',
                  );
                }

                final myCourses = myCoursesProvider.myCourses;
                final catalogCourses = _filterCatalog(
                  catalogProvider.courses,
                  _searchQuery,
                );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _buildMyOnlineCoursesSection(context, myCoursesProvider, myCourses),
                    const SizedBox(height: 16),
                    _buildCatalogSection(
                      context,
                      catalogProvider,
                      myCoursesProvider,
                      catalogCourses,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEnrollmentMessagesSheet(
    BuildContext context,
    String enrollmentId,
    String title,
  ) async {
    final messagesProvider =
        context.read<StudentOnlineCourseMessagesProvider>();
    await messagesProvider.loadMessages(enrollmentId);
    if (!mounted) return;

    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SizedBox(
            height: 380,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Messages sur la formation en ligne',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: Consumer<StudentOnlineCourseMessagesProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading && provider.messages.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (provider.error != null &&
                          provider.messages.isEmpty) {
                        return Center(child: Text(provider.error!));
                      }

                      final messages = provider.messages;
                      if (messages.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Aucun message pour le moment. Utilisez le champ ci-dessous pour poser vos questions (organisation, accès, paiement, etc.).',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final senderRole =
                              msg['sender_role']?.toString() ?? '';
                          final content =
                              msg['content']?.toString() ?? '';
                          final createdAt =
                              msg['created_at']?.toString() ?? '';

                          final isStudent = senderRole == 'student';
                          final alignment = isStudent
                              ? Alignment.centerRight
                              : Alignment.centerLeft;
                          final color = isStudent
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant;
                          final label =
                              isStudent ? 'Vous' : 'Nexium / Plateforme';

                          return Align(
                            alignment: alignment,
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(content),
                                  if (createdAt.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      createdAt,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText:
                              'Écrire un message (organisation, accès, paiement, etc.)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        final ok = await messagesProvider.sendMessage(
                          enrollmentId: enrollmentId,
                          content: text,
                        );
                        if (ok) {
                          controller.clear();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _filterCatalog(
    List<Map<String, dynamic>> courses,
    String search,
  ) {
    if (search.isEmpty) return courses;
    return courses.where((c) {
      final title = (c['title'] ?? '').toString().toLowerCase();
      final description = (c['short_description'] ?? '').toString().toLowerCase();
      final category = (c['category'] ?? '').toString().toLowerCase();
      final level = (c['level'] ?? '').toString().toLowerCase();
      return title.contains(search) ||
          description.contains(search) ||
          category.contains(search) ||
          level.contains(search);
    }).toList(growable: false);
  }

  Widget _buildMyOnlineCoursesSection(
    BuildContext context,
    StudentOnlineCoursesProvider myCoursesProvider,
    List<Map<String, dynamic>> myCourses,
  ) {
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
                  'Mes formations en ligne',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (myCoursesProvider.isLoading && myCourses.isEmpty)
                  const LinearProgressIndicator()
                else if (myCoursesProvider.error != null)
                  CustomErrorWidget(
                    error: myCoursesProvider.error!,
                    onRetry: myCoursesProvider.loadMyCourses,
                  )
                else if (myCourses.isEmpty)
                  const Text(
                    'Vous ne suivez encore aucune formation en ligne.',
                    style: TextStyle(fontSize: 13),
                  )
                else
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: myCourses.map((c) {
                      final title = (c['title'] ?? '').toString();
                      final courseId = (c['course_id'] ?? '').toString();
                      final enrollmentId = (c['enrollment_id'] ?? '').toString();
                      final accessType = (c['access_type'] ?? '').toString();

                      final lastMessageAtStr =
                          c['last_message_at']?.toString();
                      final lastReadAtStr =
                          c['student_last_read_at']?.toString();
                      DateTime? lastMessageAt;
                      DateTime? lastReadAt;
                      if (lastMessageAtStr != null && lastMessageAtStr.isNotEmpty) {
                        lastMessageAt = DateTime.tryParse(lastMessageAtStr);
                      }
                      if (lastReadAtStr != null && lastReadAtStr.isNotEmpty) {
                        lastReadAt = DateTime.tryParse(lastReadAtStr);
                      }
                      final hasNewMessages = lastMessageAt != null &&
                          (lastReadAt == null ||
                              lastMessageAt.isAfter(lastReadAt));

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
                                const SizedBox(height: 4),
                                Text(
                                  accessType.isNotEmpty
                                      ? 'Accès : $accessType'
                                      : 'Formation en ligne',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: enrollmentId.isEmpty
                                          ? null
                                          : () {
                                              _openEnrollmentMessagesSheet(
                                                context,
                                                enrollmentId,
                                                title,
                                              );
                                            },
                                      icon: const Icon(
                                        Icons.chat_bubble_outline,
                                        size: 18,
                                      ),
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Messages',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          if (hasNewMessages) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFFF3B30),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    ElevatedButton.icon(
                                      onPressed: courseId.isEmpty
                                          ? null
                                          : () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      OnlineCourseDetailScreen(
                                                    courseId: courseId,
                                                    initialTitle: title,
                                                    initiallyEnrolled: true,
                                                  ),
                                                ),
                                              );
                                            },
                                      icon: const Icon(
                                        Icons.play_circle_outline,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Ouvrir',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCatalogSection(
    BuildContext context,
    OnlineCoursesCatalogProvider catalogProvider,
    StudentOnlineCoursesProvider myCoursesProvider,
    List<Map<String, dynamic>> catalogCourses,
  ) {
    final enrolledCourseIds = myCoursesProvider.myCourses
        .map((c) => c['course_id']?.toString())
        .whereType<String>()
        .toSet();

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

        Widget catalogContent;
        if (catalogProvider.isLoading && catalogCourses.isEmpty) {
          catalogContent = const LinearProgressIndicator();
        } else if (catalogProvider.error != null) {
          catalogContent = Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              catalogProvider.error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          );
        } else if (catalogCourses.isEmpty) {
          catalogContent = const Text(
            'Aucune formation en ligne disponible pour le moment.',
            style: TextStyle(fontSize: 13),
          );
        } else {
          catalogContent = Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: catalogCourses.map((c) {
              final title = (c['title'] ?? '').toString();
              final shortDescription =
                  (c['short_description'] ?? '').toString();
              final level = (c['level'] ?? '').toString();
              final category = (c['category'] ?? '').toString();
              final courseId = (c['id'] ?? '').toString();

              final metaParts = <String>[];
              if (category.isNotEmpty) metaParts.add(category);
              if (level.isNotEmpty) metaParts.add(level);

              final dynamic rawPrice = c['price'];
              num? priceValue;
              if (rawPrice is num) {
                priceValue = rawPrice;
              }
              String? priceText;
              if (priceValue != null) {
                final bool isInt = priceValue % 1 == 0;
                final formatted =
                    isInt ? priceValue.toInt().toString() : priceValue.toString();
                priceText = '$formatted FCFA';
              }

              final contactPhone =
                  (c['contact_phone'] ?? '').toString().trim();
              final contactWhatsapp =
                  (c['contact_whatsapp'] ?? '').toString().trim();
              final contactEmail =
                  (c['contact_email'] ?? '').toString().trim();
              final contactWebsite =
                  (c['contact_website'] ?? '').toString().trim();

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
              final contactSummary =
                  contactParts.isEmpty ? '' : contactParts.take(2).join(' • ');

              final alreadyEnrolled = enrolledCourseIds.contains(courseId);

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
                            onPressed: () async {
                              if (courseId.isEmpty) return;
                              if (alreadyEnrolled) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => OnlineCourseDetailScreen(
                                      courseId: courseId,
                                      initialTitle: title,
                                      initiallyEnrolled: true,
                                    ),
                                  ),
                                );
                                return;
                              }
                              await _showEnrollConfirmationDialog(
                                context,
                                c,
                                myCoursesProvider,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                            child: Text(
                              alreadyEnrolled ? 'Accéder' : "S'inscrire",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }

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
                  'Catalogue des formations en ligne',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                catalogContent,
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEnrollConfirmationDialog(
    BuildContext context,
    Map<String, dynamic> course,
    StudentOnlineCoursesProvider myCoursesProvider,
  ) async {
    final title = (course['title'] ?? '').toString();
    final shortDescription =
        (course['short_description'] ?? '').toString();

    final dynamic rawPrice = course['price'];
    num? priceValue;
    if (rawPrice is num) {
      priceValue = rawPrice;
    }
    String priceText = 'Gratuit';
    if (priceValue != null) {
      final bool isInt = priceValue % 1 == 0;
      final formatted =
          isInt ? priceValue.toInt().toString() : priceValue.toString();
      priceText = '$formatted FCFA';
    }

    final contactPhone = (course['contact_phone'] ?? '').toString().trim();
    final contactWhatsapp =
        (course['contact_whatsapp'] ?? '').toString().trim();
    final contactEmail = (course['contact_email'] ?? '').toString().trim();
    final contactWebsite =
        (course['contact_website'] ?? '').toString().trim();
    final contactNotes =
        (course['contact_notes'] ?? '').toString().trim();

    final contactParts = <String>[];
    if (contactPhone.isNotEmpty) {
      contactParts.add('Téléphone : $contactPhone');
    }
    if (contactWhatsapp.isNotEmpty) {
      contactParts.add('WhatsApp : $contactWhatsapp');
    }
    if (contactEmail.isNotEmpty) {
      contactParts.add('Email : $contactEmail');
    }
    if (contactWebsite.isNotEmpty) {
      contactParts.add(contactWebsite);
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Confirmation d'inscription"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (shortDescription.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    shortDescription,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Tarif : $priceText',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2563EB),
                  ),
                ),
                if (contactParts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Contacts / infos pratiques :',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...contactParts.map(
                    (line) => Text(
                      line,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
                if (contactNotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    contactNotes,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: myCoursesProvider.isSaving
                  ? null
                  : () async {
                      final courseId = (course['id'] ?? '').toString();
                      if (courseId.isEmpty) {
                        Navigator.of(dialogContext).pop();
                        return;
                      }
                      final ok = await myCoursesProvider.enrollInCourse(
                        courseId: courseId,
                      );
                      if (!mounted) return;
                      Navigator.of(dialogContext).pop();
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Vous êtes maintenant inscrit à la formation.',
                            ),
                          ),
                        );
                      } else if (myCoursesProvider.error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(myCoursesProvider.error!),
                          ),
                        );
                      }
                    },
              child: const Text('Confirmer mon inscription'),
            ),
          ],
        );
      },
    );
  }
}
