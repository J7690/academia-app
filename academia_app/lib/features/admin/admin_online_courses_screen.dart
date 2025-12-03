import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_online_courses_provider.dart';
import '../../providers/admin_online_course_messages_provider.dart';

class AdminOnlineCoursesScreen extends StatefulWidget {
  const AdminOnlineCoursesScreen({super.key});

  @override
  State<AdminOnlineCoursesScreen> createState() => _AdminOnlineCoursesScreenState();
}

class _AdminOnlineCoursesScreenState extends State<AdminOnlineCoursesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminOnlineCoursesProvider>().loadOnlineCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: const Text('Cours en ligne - Admin'),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed:
                context.read<AdminOnlineCoursesProvider>().loadOnlineCourses,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recharger',
          ),
        ],
      ),
      body: Consumer<AdminOnlineCoursesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.courses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.error!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: provider.loadOnlineCourses,
                    child: const Text('Recharger'),
                  ),
                ],
              ),
            );
          }

          final courses = provider.courses;
          if (courses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucun cours en ligne configuré.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showCourseDialog(context, provider),
                    child: const Text('Créer un premier cours en ligne'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              final courseId = course['id']?.toString();
              final title = (course['title'] ?? '').toString();
              final shortDescription =
                  (course['short_description'] ?? '').toString();
              final category = (course['category'] ?? '').toString();
              final level = (course['level'] ?? '').toString();
              final language = (course['language'] ?? '').toString();
              final estimatedHours = course['estimated_hours'];
              final isPublished = course['is_published'] == true;

              final metaParts = <String>[];
              if (category.isNotEmpty) metaParts.add(category);
              if (level.isNotEmpty) metaParts.add(level);
              if (language.isNotEmpty) metaParts.add(language);
              if (estimatedHours is int && estimatedHours > 0) {
                metaParts.add('$estimatedHours h');
              }

              final dynamic rawPrice = course['price'];
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
              final contactSummary =
                  contactParts.isEmpty ? '' : contactParts.take(2).join(' • ');

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
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
                            const SizedBox(height: 4),
                            if (shortDescription.isNotEmpty)
                              Text(
                                shortDescription,
                                style: const TextStyle(fontSize: 13),
                              ),
                            if (metaParts.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                metaParts.join(' • '),
                                style: const TextStyle(
                                  fontSize: 12,
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
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Chip(
                            label: Text(
                              isPublished ? 'Publié' : 'Brouillon',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isPublished
                                    ? const Color(0xFF1EA75C)
                                    : const Color(0xFFFF3B30),
                              ),
                            ),
                            backgroundColor: isPublished
                                ? const Color(0xFFE5F9E7)
                                : const Color(0xFFFEE2E2),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Modifier le cours',
                            onPressed: () {
                              _showCourseDialog(
                                context,
                                provider,
                                existing: course,
                              );
                            },
                          ),
                          TextButton.icon(
                            onPressed: courseId == null
                                ? null
                                : () {
                                    _openEnrollmentsDialog(context, course);
                                  },
                            icon: const Icon(Icons.people_outline),
                            label: const Text('Inscriptions'),
                          ),
                          if (courseId != null)
                            Text(
                              courseId,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final provider = context.read<AdminOnlineCoursesProvider>();
          _showCourseDialog(context, provider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un cours en ligne'),
      ),
    );
  }

  Future<void> _showCourseDialog(
    BuildContext context,
    AdminOnlineCoursesProvider provider, {
    Map<String, dynamic>? existing,
  }) async {
    final titleController =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final shortDescController = TextEditingController(
      text: existing?['short_description']?.toString() ?? '',
    );
    final fullDescController = TextEditingController(
      text: existing?['full_description']?.toString() ?? '',
    );
    final categoryController =
        TextEditingController(text: existing?['category']?.toString() ?? '');
    final levelController =
        TextEditingController(text: existing?['level']?.toString() ?? '');
    final languageController =
        TextEditingController(text: existing?['language']?.toString() ?? '');
    final estimatedHoursController = TextEditingController(
      text: existing?['estimated_hours']?.toString() ?? '',
    );
    final coverImageController = TextEditingController(
      text: existing?['cover_image_url']?.toString() ?? '',
    );
    final priceController =
        TextEditingController(text: existing?['price']?.toString() ?? '');
    final contactPhoneController = TextEditingController(
      text: existing?['contact_phone']?.toString() ?? '',
    );
    final contactWhatsappController = TextEditingController(
      text: existing?['contact_whatsapp']?.toString() ?? '',
    );
    final contactEmailController = TextEditingController(
      text: existing?['contact_email']?.toString() ?? '',
    );
    final contactWebsiteController = TextEditingController(
      text: existing?['contact_website']?.toString() ?? '',
    );
    final contactNotesController = TextEditingController(
      text: existing?['contact_notes']?.toString() ?? '',
    );
    // Par défaut, un nouveau cours en ligne est publié, mais on conserve
    // l'état existant lorsqu'on édite un cours.
    bool isPublished = existing == null
        ? true
        : existing['is_published'] == true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Nouveau cours en ligne'
                    : 'Modifier le cours en ligne',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(labelText: 'Titre du cours'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: shortDescController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description courte',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: fullDescController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description détaillée',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: categoryController,
                      decoration:
                          const InputDecoration(labelText: 'Catégorie (optionnelle)'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: levelController,
                      decoration: const InputDecoration(
                        labelText: 'Niveau (débutant, avancé...)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: languageController,
                      decoration: const InputDecoration(
                        labelText: 'Langue (fr, en, ...)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: estimatedHoursController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Durée estimée (heures, optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: coverImageController,
                      decoration: const InputDecoration(
                        labelText: 'URL image de couverture (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prix (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contactPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contactWhatsappController,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contactEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Email de contact (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contactWebsiteController,
                      decoration: const InputDecoration(
                        labelText: 'Site ou lien d\'infos (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contactNotesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes / modalités (optionnel)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Publié'),
                        const Spacer(),
                        Switch(
                          value: isPublished,
                          onChanged: (v) {
                            setStateDialog(() {
                              isPublished = v;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final title = titleController.text.trim();
    if (title.isEmpty) return;

    final estimatedHours =
        int.tryParse(estimatedHoursController.text.trim());
    num? price;
    if (priceController.text.trim().isNotEmpty) {
      price = num.tryParse(priceController.text.trim());
    }

    await provider.upsertOnlineCourse(
      courseId: existing?['id']?.toString(),
      title: title,
      shortDescription: shortDescController.text.trim().isEmpty
          ? null
          : shortDescController.text.trim(),
      fullDescription: fullDescController.text.trim().isEmpty
          ? null
          : fullDescController.text.trim(),
      category: categoryController.text.trim().isEmpty
          ? null
          : categoryController.text.trim(),
      level: levelController.text.trim().isEmpty
          ? null
          : levelController.text.trim(),
      language: languageController.text.trim().isEmpty
          ? null
          : languageController.text.trim(),
      estimatedHours: estimatedHours,
      coverImageUrl: coverImageController.text.trim().isNotEmpty
          ? coverImageController.text.trim()
          : null,
      price: price,
      contactPhone: contactPhoneController.text.trim().isEmpty
          ? null
          : contactPhoneController.text.trim(),
      contactWhatsapp: contactWhatsappController.text.trim().isEmpty
          ? null
          : contactWhatsappController.text.trim(),
      contactEmail: contactEmailController.text.trim().isEmpty
          ? null
          : contactEmailController.text.trim(),
      contactWebsite: contactWebsiteController.text.trim().isEmpty
          ? null
          : contactWebsiteController.text.trim(),
      contactNotes: contactNotesController.text.trim().isEmpty
          ? null
          : contactNotesController.text.trim(),
      isPublished: isPublished,
    );
  }

  Future<void> _openEnrollmentMessagesSheet(
    BuildContext context,
    String enrollmentId,
    String studentName,
  ) async {
    final messagesProvider =
        context.read<AdminOnlineCourseMessagesProvider>();
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
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Messages avec l\'étudiant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (studentName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    studentName,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: Consumer<AdminOnlineCourseMessagesProvider>(
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
                              'Aucun message pour le moment. Utilisez le champ ci-dessous pour contacter l\'étudiant (organisation, accès, paiement, etc.).',
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

                          final isAdmin = senderRole == 'admin';
                          final alignment = isAdmin
                              ? Alignment.centerRight
                              : Alignment.centerLeft;
                          final color = isAdmin
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant;
                          final label = isAdmin ? 'Vous' : 'Étudiant';

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
                              'Écrire un message à l\'étudiant (organisation, accès, paiement, etc.)',
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
                        final ok = await messagesProvider.sendToStudent(
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

  Future<void> _openEnrollmentsDialog(
    BuildContext context,
    Map<String, dynamic> course,
  ) async {
    final provider = context.read<AdminOnlineCoursesProvider>();
    final courseId = course['id']?.toString() ?? '';
    final courseTitle = course['title']?.toString() ?? '';
    if (courseId.isEmpty) return;

    final enrollments = await provider.loadEnrollments(courseId);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Inscriptions au cours en ligne'),
          content: SizedBox(
            width: 500,
            child: enrollments.isEmpty
                ? const Text('Aucune inscription pour ce cours pour le moment.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: enrollments.length,
                    itemBuilder: (context, index) {
                      final r = enrollments[index];
                      final studentName =
                          r['student_full_name']?.toString() ?? '';
                      final enrollmentId =
                          r['enrollment_id']?.toString() ?? '';
                      final profilePhone =
                          (r['contact_phone'] ?? r['student_profile_phone'] ?? '')
                              .toString();
                      final email = r['student_email']?.toString() ?? '';
                      final accessType = r['access_type']?.toString() ?? '';
                      final paymentMethod =
                          r['payment_method']?.toString() ?? '';
                      final preferredChannel =
                          r['preferred_channel']?.toString() ?? '';
                      final wantsInvoice = r['wants_invoice'] == true;
                      final companyName =
                          r['company_name']?.toString() ?? '';
                      final createdAt = r['starts_at']?.toString() ?? '';

                      final lastMessageAtStr =
                          r['last_message_at']?.toString();
                      final lastReadAtStr =
                          r['admin_last_read_at']?.toString();
                      DateTime? lastMessageAt;
                      DateTime? lastReadAt;
                      if (lastMessageAtStr != null &&
                          lastMessageAtStr.isNotEmpty) {
                        lastMessageAt =
                            DateTime.tryParse(lastMessageAtStr);
                      }
                      if (lastReadAtStr != null && lastReadAtStr.isNotEmpty) {
                        lastReadAt = DateTime.tryParse(lastReadAtStr);
                      }
                      final hasNewMessages = lastMessageAt != null &&
                          (lastReadAt == null ||
                              lastMessageAt.isAfter(lastReadAt));

                      final details = <String>[
                        if (courseTitle.isNotEmpty) courseTitle,
                        if (accessType.isNotEmpty) 'Accès: $accessType',
                        if (profilePhone.isNotEmpty) 'Tel: $profilePhone',
                        if (email.isNotEmpty) 'Email: $email',
                        if (paymentMethod.isNotEmpty)
                          'Paiement: $paymentMethod',
                        if (preferredChannel.isNotEmpty)
                          'Canal: $preferredChannel',
                        if (wantsInvoice) 'Facture souhaitée',
                        if (companyName.isNotEmpty)
                          'Entreprise: $companyName',
                        if (createdAt.isNotEmpty) 'Inscrit le: $createdAt',
                      ];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                studentName.isNotEmpty
                                    ? studentName
                                    : 'Étudiant inconnu',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (details.isNotEmpty)
                                Text(
                                  details.join(' · '),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if ((r['notes']?.toString() ?? '')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  r['notes'].toString(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: enrollmentId.isEmpty
                                      ? null
                                      : () {
                                          _openEnrollmentMessagesSheet(
                                            context,
                                            enrollmentId,
                                            studentName,
                                          );
                                        },
                                  icon: const Icon(
                                    Icons.chat_bubble_outline,
                                  ),
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Messages'),
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
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }
}
