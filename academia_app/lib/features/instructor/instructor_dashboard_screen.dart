import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/instructor_online_courses_provider.dart';
import '../../providers/instructor_online_course_live_sessions_provider.dart';
import '../../providers/teacher_td_assignments_provider.dart';
import '../../providers/td_messages_provider.dart';
import '../../theme/td_theme.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';
import 'instructor_course_forum_screen.dart';
import '../live/livekit_room_screen.dart';
import 'teacher_td_assignments_screen.dart';
import 'teacher_prep_screen.dart';
import 'teacher_td_resources_screen.dart';
import '../../widgets/support_fab.dart';
import '../../services/push_trigger_service.dart';

class InstructorDashboardScreen extends StatefulWidget {
  const InstructorDashboardScreen({super.key});

  @override
  State<InstructorDashboardScreen> createState() => _InstructorDashboardScreenState();
}

class _InstructorDashboardScreenState extends State<InstructorDashboardScreen> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _ensureInstructorProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await context.read<InstructorOnlineCoursesProvider>().loadMyCourses();
        await context.read<InstructorOnlineCourseLiveSessionsProvider>().loadMySessions();
      } catch (_) {}
    });

    _pollingTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      if (!mounted) return;
      try {
        await context.read<InstructorOnlineCoursesProvider>().loadMyCourses();
        await context.read<InstructorOnlineCourseLiveSessionsProvider>().loadMySessions();
      } catch (_) {}
      PushTriggerService.instance.triggerPendingPush();
    });
  }

  Future<void> _ensureInstructorProfile() async {
    final client = Supabase.instance.client;
    try {
      await client.rpc('app_ci_ensure_instructor_profile');
    } catch (_) {}
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: TdTheme.scaffoldBg,
        floatingActionButton: const SupportFab(),
        appBar: AppBar(
          elevation: 0,
          centerTitle: false,
          title: const Text('Espace Enseignant',
              style: TextStyle(fontWeight: FontWeight.w600)),
          foregroundColor: Colors.white,
          flexibleSpace: Container(
            decoration: TdTheme.gradientHeader(TdTheme.instructorGradient),
          ),
          actions: [
            IconButton(
              onPressed: () async {
                await context.read<InstructorOnlineCoursesProvider>().loadMyCourses();
                await context.read<InstructorOnlineCourseLiveSessionsProvider>().loadMySessions();
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualiser',
            ),
            IconButton(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              tooltip: 'Se déconnecter',
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Accueil'),
              Tab(icon: Icon(Icons.assignment_outlined, size: 18), text: 'Mes TD'),
              Tab(icon: Icon(Icons.people_outlined, size: 18), text: 'Progression'),
              Tab(icon: Icon(Icons.school_outlined, size: 18), text: 'Prépa'),
              Tab(icon: Icon(Icons.play_lesson_outlined, size: 18), text: 'Cours'),
              Tab(icon: Icon(Icons.videocam_outlined, size: 18), text: 'Sessions'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _InstructorHomeTab(),
            TeacherTdAssignmentsScreen(),
            TeacherTdResourcesScreen(),
            TeacherPrepScreen(),
            _InstructorCoursesTab(),
            _InstructorLiveSessionsTab(),
          ],
        ),
      ),
    );
  }
}

class _InstructorHomeTab extends StatelessWidget {
  const _InstructorHomeTab();

  @override
  Widget build(BuildContext context) {
    return Consumer2<InstructorOnlineCoursesProvider,
        InstructorOnlineCourseLiveSessionsProvider>(
      builder: (context, coursesProvider, sessionsProvider, child) {
        final courses = coursesProvider.courses;
        final sessions = sessionsProvider.sessions;

        final publishedCount =
            courses.where((c) => c['is_published'] == true).length;
        final upcomingSessions = sessions.where((s) {
          final startAt = s['start_at']?.toString();
          if (startAt == null) return false;
          final dt = DateTime.tryParse(startAt);
          return dt != null && dt.isAfter(DateTime.now());
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            await coursesProvider.loadMyCourses();
            await sessionsProvider.loadMySessions();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Welcome header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: TdTheme.instructorGradient,
                  ),
                  borderRadius: BorderRadius.circular(TdTheme.radiusXl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.school, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bienvenue',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                              Text('Espace Enseignant',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Gérez vos cours, planifiez des sessions et suivez vos TD.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // KPI cards
              Row(
                children: [
                  TdTheme.kpiCard(
                    icon: Icons.play_lesson,
                    value: courses.length.toString(),
                    label: 'Cours',
                    color: TdTheme.instructorPrimary,
                  ),
                  const SizedBox(width: 10),
                  TdTheme.kpiCard(
                    icon: Icons.check_circle,
                    value: publishedCount.toString(),
                    label: 'Publiés',
                    color: TdTheme.success,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TdTheme.kpiCard(
                    icon: Icons.videocam,
                    value: upcomingSessions.length.toString(),
                    label: 'Sessions à venir',
                    color: TdTheme.info,
                  ),
                  const SizedBox(width: 10),
                  TdTheme.kpiCard(
                    icon: Icons.event,
                    value: sessions.length.toString(),
                    label: 'Total sessions',
                    color: TdTheme.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Upcoming sessions
              const Text('Prochaines sessions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (sessionsProvider.isLoading && sessions.isEmpty)
                const LoadingWidget(message: 'Chargement...')
              else if (upcomingSessions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: TdTheme.cardDecoration(),
                  child: const Row(
                    children: [
                      Icon(Icons.event_busy, color: TdTheme.textTertiary, size: 20),
                      SizedBox(width: 10),
                      Text('Aucune session à venir.',
                          style: TextStyle(fontSize: 13, color: TdTheme.textSecondary)),
                    ],
                  ),
                )
              else
                ...upcomingSessions.take(3).map((session) {
                  final title = (session['title'] ?? '').toString();
                  final courseTitle = (session['course_title'] ?? '').toString();
                  final startAt = session['start_at']?.toString() ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: TdTheme.cardDecoration(),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: TdTheme.instructorPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.videocam,
                              color: TdTheme.instructorPrimary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 13)),
                              if (courseTitle.isNotEmpty)
                                Text(courseTitle,
                                    style: const TextStyle(
                                        fontSize: 11, color: TdTheme.textSecondary)),
                              if (startAt.isNotEmpty)
                                Text(TdTheme.formatDateTime(startAt),
                                    style: const TextStyle(
                                        fontSize: 11, color: TdTheme.instructorPrimary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 20),

              // Recent courses
              const Text('Mes cours',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (coursesProvider.isLoading && courses.isEmpty)
                const LoadingWidget(message: 'Chargement...')
              else if (courses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: TdTheme.cardDecoration(),
                  child: const Row(
                    children: [
                      Icon(Icons.play_lesson, color: TdTheme.textTertiary, size: 20),
                      SizedBox(width: 10),
                      Text('Aucun cours configuré.',
                          style: TextStyle(fontSize: 13, color: TdTheme.textSecondary)),
                    ],
                  ),
                )
              else
                ...courses.take(4).map((course) {
                  final title = (course['title'] ?? '').toString();
                  final category = (course['category'] ?? '').toString();
                  final level = (course['level'] ?? '').toString();
                  final isPublished = course['is_published'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: TdTheme.cardDecoration(),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (isPublished ? TdTheme.success : TdTheme.warning)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isPublished ? Icons.check_circle : Icons.edit_note,
                            color: isPublished ? TdTheme.success : TdTheme.warning,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 13)),
                              if (category.isNotEmpty || level.isNotEmpty)
                                Text(
                                  [if (category.isNotEmpty) category, if (level.isNotEmpty) level]
                                      .join(' \u2022 '),
                                  style: const TextStyle(
                                      fontSize: 11, color: TdTheme.textSecondary),
                                ),
                            ],
                          ),
                        ),
                        TdTheme.statusBadge(
                          isPublished ? 'Publié' : 'Brouillon',
                          isPublished ? TdTheme.success : TdTheme.warning,
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _InstructorCoursesTab extends StatelessWidget {
  const _InstructorCoursesTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Consumer<InstructorOnlineCoursesProvider>(
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
                    onPressed: provider.loadMyCourses,
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                              IconButton(
                                icon: const Icon(Icons.forum_outlined),
                                tooltip: 'Forum du cours',
                                onPressed: courseId == null
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => InstructorCourseForumScreen(
                                              courseId: courseId,
                                              courseTitle: title,
                                            ),
                                          ),
                                        );
                                      },
                              ),
                            ],
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
          final provider =
              context.read<InstructorOnlineCoursesProvider>();
          _showCourseDialog(context, provider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un cours en ligne'),
      ),
    );
  }
}

Future<void> _showCourseDialog(
  BuildContext context,
  InstructorOnlineCoursesProvider provider, {
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
                    decoration: const InputDecoration(
                      labelText: 'Catégorie (optionnelle)',
                    ),
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

  final estimatedHours = int.tryParse(estimatedHoursController.text.trim());
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
    coverImageUrl: coverImageController.text.trim().isEmpty
        ? null
        : coverImageController.text.trim(),
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

class _InstructorLiveSessionsTab extends StatelessWidget {
  const _InstructorLiveSessionsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Consumer2<InstructorOnlineCourseLiveSessionsProvider,
          InstructorOnlineCoursesProvider>(
        builder: (context, sessionsProvider, coursesProvider, child) {
          if (sessionsProvider.isLoading && sessionsProvider.sessions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (sessionsProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(sessionsProvider.error!),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: sessionsProvider.loadMySessions,
                    child: const Text('Recharger'),
                  ),
                ],
              ),
            );
          }

          final sessions = sessionsProvider.sessions;

          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucune session live ou TD planifiée.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showSessionDialog(
                      context,
                      sessionsProvider,
                      coursesProvider,
                    ),
                    child: const Text('Planifier une première session'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final sessionId = session['id']?.toString();
              final title = (session['title'] ?? '').toString();
              final description = (session['description'] ?? '').toString();
              final courseTitle = (session['course_title'] ?? '').toString();
              final providerName = (session['provider'] ?? '').toString();
              final startAt = session['start_at']?.toString();
              final isActive = session['is_active'] == true;
              final status = (session['status'] ?? '').toString();

              String statusLabel;
              Color statusColor;

              switch (status) {
                case 'draft':
                  statusLabel = 'Brouillon';
                  statusColor = const Color(0xFF6B7280);
                  break;
                case 'pending_approval':
                  statusLabel = 'En attente validation admin';
                  statusColor = const Color(0xFFF59E0B);
                  break;
                case 'approved':
                  statusLabel = 'Approuvée';
                  statusColor = const Color(0xFF1EA75C);
                  break;
                case 'running':
                  statusLabel = 'En cours';
                  statusColor = const Color(0xFF2563EB);
                  break;
                case 'ended':
                  statusLabel = 'Terminée';
                  statusColor = const Color(0xFF6B7280);
                  break;
                case 'cancelled':
                  statusLabel = 'Annulée';
                  statusColor = const Color(0xFFEF4444);
                  break;
                case 'rejected':
                  statusLabel = 'Refusée';
                  statusColor = const Color(0xFFEF4444);
                  break;
                default:
                  statusLabel = isActive ? 'Active' : 'Inactivée';
                  statusColor = isActive
                      ? const Color(0xFF1EA75C)
                      : const Color(0xFFFF3B30);
                  break;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (courseTitle.isNotEmpty)
                              Text(
                                courseTitle,
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (description.isNotEmpty)
                              Text(
                                description,
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (providerName.isNotEmpty)
                              Text(
                                providerName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            if (startAt != null)
                              Text(
                                startAt,
                                style: const TextStyle(fontSize: 12),
                              ),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Modifier la session',
                            onPressed: () {
                              _showSessionDialog(
                                context,
                                sessionsProvider,
                                coursesProvider,
                                existing: session,
                              );
                            },
                          ),
                          if (sessionId != null && sessionId.isNotEmpty) ...[
                            if (status == 'draft')
                              TextButton(
                                onPressed: sessionsProvider.isSaving
                                    ? null
                                    : () async {
                                        final ok = await sessionsProvider
                                            .submitSession(sessionId);
                                        if (!context.mounted) return;
                                        if (!ok &&
                                            sessionsProvider.error != null) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                sessionsProvider.error!,
                                              ),
                                            ),
                                          );
                                        } else if (ok) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Session soumise à validation admin.',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                child: const Text('Soumettre'),
                              )
                            else if (status == 'approved')
                              TextButton(
                                onPressed: sessionsProvider.isSaving
                                    ? null
                                    : () async {
                                        final response = await sessionsProvider
                                            .startSession(sessionId);
                                        if (!context.mounted) return;
                                        if (response == null &&
                                            sessionsProvider.error != null) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                sessionsProvider.error!,
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        if (providerName
                                                .toLowerCase()
                                                .trim() ==
                                            'livekit') {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => LivekitRoomScreen(
                                                sessionId: sessionId,
                                              ),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Session démarrée (statut mis à jour).',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                child: const Text('Démarrer'),
                              ),
                          ],
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
          final sessionsProvider =
              context.read<InstructorOnlineCourseLiveSessionsProvider>();
          final coursesProvider =
              context.read<InstructorOnlineCoursesProvider>();
          _showSessionDialog(context, sessionsProvider, coursesProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Planifier une session'),
      ),
    );
  }
}

Future<void> _showSessionDialog(
  BuildContext context,
  InstructorOnlineCourseLiveSessionsProvider sessionsProvider,
  InstructorOnlineCoursesProvider coursesProvider, {
  Map<String, dynamic>? existing,
}) async {
  final courses = coursesProvider.courses;
  String? selectedCourseId = existing?['course_id']?.toString();
  final titleController =
      TextEditingController(text: existing?['title']?.toString() ?? '');
  final descriptionController = TextEditingController(
    text: existing?['description']?.toString() ?? '',
  );
  final providerController = TextEditingController(
    text: existing?['provider']?.toString() ?? 'zoom',
  );
  final joinUrlController = TextEditingController(
    text: existing?['join_url']?.toString() ?? '',
  );
  final startAtController = TextEditingController(
    text: existing?['start_at']?.toString() ?? '',
  );
  final endAtController = TextEditingController(
    text: existing?['end_at']?.toString() ?? '',
  );
  final replayUrlController = TextEditingController(
    text: existing?['replay_video_url']?.toString() ?? '',
  );
  bool isActive = existing == null
      ? true
      : existing['is_active'] == true;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(
              existing == null
                  ? 'Planifier une session live / TD'
                  : 'Modifier la session live / TD',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCourseId,
                    items: courses
                        .map((c) => DropdownMenuItem<String>(
                              value: c['id']?.toString(),
                              child: Text((c['title'] ?? '').toString()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedCourseId = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Cours en ligne',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre de la session',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description (optionnelle)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: providerController,
                    decoration: const InputDecoration(
                      labelText: 'Plateforme (Zoom, Meet, LiveKit, ...)',
                      hintText: 'Exemple : zoom, meet ou livekit',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: joinUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Lien Zoom / Meet de la réunion',
                      hintText: 'Collez ici le lien complet (https://...)',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pour Zoom ou Meet, créez la réunion puis collez ici le lien. '
                    'Pour LiveKit, laissez ce champ vide : la salle vidéo sera ouverte dans Academia.',
                    style: TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: startAtController,
                    decoration: const InputDecoration(
                      labelText: "Date/heure de début (ISO 8601)",
                      hintText: '2025-01-01T18:00:00Z',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: endAtController,
                    decoration: const InputDecoration(
                      labelText: 'Date/heure de fin (optionnelle)',
                      hintText: '2025-01-01T20:00:00Z',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: replayUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL du replay (optionnelle)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Active'),
                      const Spacer(),
                      Switch(
                        value: isActive,
                        onChanged: (v) {
                          setStateDialog(() {
                            isActive = v;
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

  if (selectedCourseId == null || selectedCourseId!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Veuillez sélectionner un cours en ligne.')),
    );
    return;
  }

  final title = titleController.text.trim();
  if (title.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Le titre de la session est obligatoire.')),
    );
    return;
  }

  final startAtText = startAtController.text.trim();
  if (startAtText.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('La date/heure de début est obligatoire.')),
    );
    return;
  }

  DateTime? startAt;
  DateTime? endAt;
  try {
    startAt = DateTime.parse(startAtText);
  } catch (_) {}

  if (startAt == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Format de date/heure de début invalide.')),
    );
    return;
  }

  final endAtText = endAtController.text.trim();
  if (endAtText.isNotEmpty) {
    try {
      endAt = DateTime.parse(endAtText);
    } catch (_) {}
  }

  await sessionsProvider.upsertSession(
    sessionId: existing?['id']?.toString(),
    courseId: selectedCourseId!,
    title: title,
    description: descriptionController.text.trim().isEmpty
        ? null
        : descriptionController.text.trim(),
    provider: providerController.text.trim().isEmpty
        ? null
        : providerController.text.trim(),
    joinUrl: joinUrlController.text.trim(),
    startAt: startAt,
    endAt: endAt,
    replayVideoUrl: replayUrlController.text.trim().isEmpty
        ? null
        : replayUrlController.text.trim(),
    isActive: isActive,
  );
}
