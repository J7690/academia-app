import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../live/livekit_room_screen.dart';
import '../../providers/online_course_detail_provider.dart';
import '../../providers/student_online_courses_provider.dart';
import '../../providers/online_course_live_sessions_provider.dart';
import '../../providers/online_course_forum_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/error_widget.dart';

class OnlineCourseDetailScreen extends StatefulWidget {
  final String courseId;
  final String initialTitle;
  final bool initiallyEnrolled;

  const OnlineCourseDetailScreen({
    super.key,
    required this.courseId,
    required this.initialTitle,
    this.initiallyEnrolled = false,
  });

  @override
  State<OnlineCourseDetailScreen> createState() => _OnlineCourseDetailScreenState();
}

class _OnlineCourseDetailScreenState extends State<OnlineCourseDetailScreen> {
  bool _enrolled = false;

  @override
  void initState() {
    super.initState();
    _enrolled = widget.initiallyEnrolled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<OnlineCourseDetailProvider>()
          .loadCourseDetail(widget.courseId);
      context
          .read<OnlineCourseLiveSessionsProvider>()
          .loadSessions(widget.courseId);
      context
          .read<OnlineCourseForumProvider>()
          .loadThreads(widget.courseId);
    });
  }

  Future<void> _showEnrollConfirmationDialog(
    BuildContext context,
    OnlineCourseDetailProvider detailProvider,
    StudentOnlineCoursesProvider studentProvider,
  ) async {
    final course = detailProvider.course;
    if (course == null) return;

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

    final result = await showDialog<bool>(
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
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: studentProvider.isSaving
                  ? null
                  : () async {
                      final ok = await studentProvider.enrollInCourse(
                        courseId: widget.courseId,
                      );
                      if (!mounted) return;
                      Navigator.of(dialogContext).pop(ok);
                    },
              child: const Text('Confirmer mon inscription'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    if (studentProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(studentProvider.error!),
        ),
      );
      return;
    }

    setState(() {
      _enrolled = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Inscription au cours en ligne réussie.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<OnlineCourseDetailProvider, StudentOnlineCoursesProvider>(
      builder: (context, detailProvider, studentProvider, child) {
        final course = detailProvider.course;
        final title = (course?['title'] ?? widget.initialTitle).toString();

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (!_enrolled)
                TextButton(
                  onPressed: detailProvider.isSaving || studentProvider.isSaving
                      ? null
                      : () async {
                          await _showEnrollConfirmationDialog(
                            context,
                            detailProvider,
                            studentProvider,
                          );
                        },
                  child: const Text(
                    "S'inscrire",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          body: _buildBody(context, detailProvider),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1EA75C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('Retour'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    OnlineCourseDetailProvider detailProvider,
  ) {
    final liveProvider = context.watch<OnlineCourseLiveSessionsProvider>();
    final forumProvider = context.watch<OnlineCourseForumProvider>();
    if (detailProvider.isLoading && detailProvider.course == null) {
      return const LoadingWidget(
        message: 'Chargement du cours en ligne...',
      );
    }

    if (detailProvider.error != null && detailProvider.course == null) {
      return CustomErrorWidget(
        error: detailProvider.error!,
        onRetry: () => detailProvider.loadCourseDetail(widget.courseId),
      );
    }

    final course = detailProvider.course;
    final sections = detailProvider.sections;

    if (course == null) {
      return const Center(
        child: Text('Cours en ligne introuvable.'),
      );
    }

    final shortDescription = (course['short_description'] ?? '').toString();
    final fullDescription = (course['full_description'] ?? '').toString();
    final level = (course['level'] ?? '').toString();
    final category = (course['category'] ?? '').toString();
    final estimatedHours = course['estimated_hours'];

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

    final metaParts = <String>[];
    if (category.isNotEmpty) metaParts.add(category);
    if (level.isNotEmpty) metaParts.add(level);
    if (estimatedHours is int && estimatedHours > 0) {
      metaParts.add('$estimatedHours h estimées');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (course['title'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (shortDescription.isNotEmpty)
                  Text(
                    shortDescription,
                    style: const TextStyle(fontSize: 14),
                  ),
                if (fullDescription.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    fullDescription,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
                if (metaParts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    metaParts.join(' • '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
                if (priceText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tarif : $priceText',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
                if (contactParts.isNotEmpty || contactNotes.isNotEmpty) ...[
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
                  if (contactNotes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      contactNotes,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLiveSessionsSection(context, liveProvider),
        const SizedBox(height: 16),
        _buildForumSection(context, forumProvider),
        const SizedBox(height: 16),
        const Text(
          'Contenu du cours',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (sections.isEmpty)
          const Text(
            'Aucune section disponible pour ce cours pour le moment.',
            style: TextStyle(fontSize: 13),
          )
        else
          ...sections.map((section) {
            final sectionTitle = (section['title'] ?? '').toString();
            final lessons = (section['lessons'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .toList(growable: false);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: const Color(0xFFF9FAFB),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                title: Text(
                  sectionTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  if (lessons.isEmpty)
                    const ListTile(
                      title: Text(
                        'Aucune leçon dans cette section.',
                        style: TextStyle(fontSize: 13),
                      ),
                    )
                  else
                    ...lessons.map((lesson) {
                      final lessonTitle = (lesson['title'] ?? '').toString();
                      final type = (lesson['lesson_type'] ?? '').toString();
                      final estimatedMinutes = lesson['estimated_minutes'];
                      final lessonId = (lesson['id'] ?? '').toString();

                      final subtitleParts = <String>[];
                      if (type.isNotEmpty) subtitleParts.add(type);
                      if (estimatedMinutes is int && estimatedMinutes > 0) {
                        subtitleParts.add('$estimatedMinutes min');
                      }

                      return ListTile(
                        title: Text(
                          lessonTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: subtitleParts.isEmpty
                            ? null
                            : Text(
                                subtitleParts.join(' • '),
                                style: const TextStyle(fontSize: 12),
                              ),
                        trailing: _enrolled
                            ? const Icon(Icons.check_circle_outline)
                            : const Icon(Icons.lock_outline),
                        onTap: !_enrolled || lessonId.isEmpty
                            ? null
                            : () async {
                                await detailProvider.updateLessonProgress(
                                  lessonId: lessonId,
                                  completed: true,
                                );
                                if (!mounted) return;
                                if (detailProvider.error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text(detailProvider.error!),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Leçon marquée comme terminée.',
                                      ),
                                    ),
                                  );
                                }
                              },
                      );
                    }).toList(),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildLiveSessionsSection(
    BuildContext context,
    OnlineCourseLiveSessionsProvider liveProvider,
  ) {
    final sessions = liveProvider.sessions;

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sessions en direct',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (liveProvider.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: LinearProgressIndicator(),
              ),
            if (sessions.isEmpty && !liveProvider.isLoading)
              const Text(
                'Aucune session live planifiée pour le moment.',
                style: TextStyle(fontSize: 13),
              )
            else
              ...sessions.map((s) {
                final title = (s['title'] ?? '').toString();
                final description = (s['description'] ?? '').toString();
                final provider = (s['provider'] ?? '').toString();
                final joinUrl = (s['join_url'] ?? '').toString();
                final replayUrl = (s['replay_video_url'] ?? '').toString();
                final startAt = s['start_at']?.toString() ?? '';
                final String? sessionId = s['id']?.toString();

                final metaParts = <String>[];
                if (provider.isNotEmpty) metaParts.add(provider);
                if (startAt.isNotEmpty) metaParts.add(startAt);

                final providerName = provider.toLowerCase().trim();
                final isLivekit =
                    providerName == 'livekit' && sessionId != null && sessionId.isNotEmpty;
                final urlToOpen =
                    !isLivekit && joinUrl.isNotEmpty ? joinUrl : replayUrl;

                Widget trailing;
                if (isLivekit) {
                  trailing = ElevatedButton(
                    onPressed: () {
                      if (sessionId == null || sessionId.isEmpty) {
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LivekitRoomScreen(
                            sessionId: sessionId,
                          ),
                        ),
                      );
                    },
                    child: const Text('Rejoindre'),
                  );
                } else if (urlToOpen.isEmpty) {
                  trailing = const Text(
                    'Lien de réunion non disponible',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  );
                } else {
                  trailing = ElevatedButton(
                    onPressed: () {
                      _openExternalUrl(urlToOpen);
                    },
                    child: Text(
                      joinUrl.isNotEmpty ? 'Rejoindre' : 'Voir le replay',
                    ),
                  );
                }

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    title.isNotEmpty ? title : 'Session en direct',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (description.isNotEmpty)
                        Text(
                          description,
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
                  trailing: isLivekit
                      ? ElevatedButton(
                          onPressed: () {
                            if (sessionId == null || sessionId.isEmpty) {
                              return;
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LivekitRoomScreen(
                                  sessionId: sessionId,
                                ),
                              ),
                            );
                          },
                          child: const Text('Rejoindre'),
                        )
                      : ElevatedButton(
                          onPressed: () {
                            final urlToOpen =
                                joinUrl.isNotEmpty ? joinUrl : replayUrl;
                            if (urlToOpen.isEmpty) return;
                            _openExternalUrl(urlToOpen);
                          },
                          child: Text(
                            joinUrl.isNotEmpty ? 'Rejoindre' : 'Voir le replay',
                          ),
                        ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildForumSection(
    BuildContext context,
    OnlineCourseForumProvider forumProvider,
  ) {
    final threads = forumProvider.threads;

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Forum du cours',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_enrolled)
                  TextButton.icon(
                    onPressed: forumProvider.isSending
                        ? null
                        : () {
                            _showCreateThreadDialog(context, forumProvider);
                          },
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('Nouveau sujet'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (forumProvider.isLoadingThreads)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: LinearProgressIndicator(),
              ),
            if (forumProvider.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  forumProvider.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            if (threads.isEmpty && !forumProvider.isLoadingThreads)
              const Text(
                'Aucun message pour ce cours pour le moment.',
                style: TextStyle(fontSize: 13),
              )
            else
              ...threads.map((t) {
                final title = (t['title'] ?? '').toString();
                final createdAt = (t['created_at'] ?? '').toString();

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: createdAt.isEmpty
                      ? null
                      : Text(
                          createdAt,
                          style: const TextStyle(fontSize: 11),
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final threadId = (t['id'] ?? '').toString();
                    if (threadId.isEmpty) return;
                    _showThreadMessagesBottomSheet(
                      context,
                      forumProvider,
                      threadId,
                      title,
                    );
                  },
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateThreadDialog(
    BuildContext context,
    OnlineCourseForumProvider forumProvider,
  ) async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouveau sujet de forum'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration:
                      const InputDecoration(labelText: 'Titre du sujet'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration:
                      const InputDecoration(labelText: 'Premier message'),
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
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final title = titleController.text.trim();
    final content = contentController.text.trim();
    if (title.isEmpty || content.isEmpty) return;

    final ok = await forumProvider.createThread(
      courseId: widget.courseId,
      title: title,
      content: content,
    );
    if (!mounted) return;
    if (!ok && forumProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(forumProvider.error!)),
      );
    }
  }

  Future<void> _showThreadMessagesBottomSheet(
    BuildContext context,
    OnlineCourseForumProvider forumProvider,
    String threadId,
    String threadTitle,
  ) async {
    await forumProvider.loadMessages(threadId);
    if (!mounted) return;

    final messageController = TextEditingController();

    // ignore: use_build_context_synchronously
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Consumer<OnlineCourseForumProvider>(
              builder: (context, p, child) {
                final messages = p.messages;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            threadTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (p.isLoadingMessages)
                      const LinearProgressIndicator(),
                    SizedBox(
                      height: 260,
                      child: ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final m = messages[index];
                          final content = (m['content'] ?? '').toString();
                          final senderRole =
                              (m['sender_role'] ?? '').toString();
                          final isMe = senderRole == 'student';
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                vertical: 2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                content,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: messageController,
                            decoration: const InputDecoration(
                              hintText: 'Écrire un message...',
                            ),
                            minLines: 1,
                            maxLines: 3,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: p.isSending
                              ? null
                              : () async {
                                  final text =
                                      messageController.text.trim();
                                  if (text.isEmpty) return;
                                  final ok = await p.sendMessage(
                                    threadId: threadId,
                                    content: text,
                                  );
                                  if (!ok && p.error != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(p.error!)),
                                    );
                                  } else {
                                    messageController.clear();
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
