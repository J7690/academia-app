import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/instructor_online_course_forum_provider.dart';

class InstructorCourseForumScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const InstructorCourseForumScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<InstructorCourseForumScreen> createState() => _InstructorCourseForumScreenState();
}

class _InstructorCourseForumScreenState extends State<InstructorCourseForumScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InstructorOnlineCourseForumProvider>().loadThreads(widget.courseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: Text('Forum - ${widget.courseTitle}'),
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
      ),
      body: Consumer<InstructorOnlineCourseForumProvider>(
        builder: (context, forumProvider, child) {
          final threads = forumProvider.threads;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
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
              ),
              if (forumProvider.isLoadingThreads)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: LinearProgressIndicator(),
                ),
              if (forumProvider.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    forumProvider.error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              Expanded(
                child: threads.isEmpty && !forumProvider.isLoadingThreads
                    ? const Center(
                        child: Text(
                          'Aucun sujet de forum pour ce cours pour le moment.',
                          style: TextStyle(fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: threads.length,
                        itemBuilder: (context, index) {
                          final t = threads[index];
                          final title = (t['title'] ?? '').toString();
                          final createdAt = (t['created_at'] ?? '').toString();
                          final threadId = (t['id'] ?? '').toString();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
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
                              trailing: const Icon(Icons.chat_bubble_outline),
                              onTap: () {
                                if (threadId.isEmpty) return;
                                _showThreadMessagesBottomSheet(
                                  context,
                                  forumProvider,
                                  threadId,
                                  title,
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateThreadDialog(
    BuildContext context,
    InstructorOnlineCourseForumProvider forumProvider,
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
                  decoration: const InputDecoration(labelText: 'Titre du sujet'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Premier message'),
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
    InstructorOnlineCourseForumProvider forumProvider,
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
            child: Consumer<InstructorOnlineCourseForumProvider>(
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
                          final isInstructor = senderRole == 'instructor';
                          return Align(
                            alignment: isInstructor
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
                                color: isInstructor
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
                              hintText: 'Répondre au sujet...',
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
                                  final text = messageController.text.trim();
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
}
