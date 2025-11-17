import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_application_messages_provider.dart';
import '../../providers/admin_applications_provider.dart';

class AdminApplicationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> application;

  const AdminApplicationDetailScreen({super.key, required this.application});

  @override
  State<AdminApplicationDetailScreen> createState() => _AdminApplicationDetailScreenState();
}

class _AdminApplicationDetailScreenState extends State<AdminApplicationDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  String _target = 'student';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appId = widget.application['id']?.toString();
      if (appId != null && appId.isNotEmpty) {
        context.read<AdminApplicationMessagesProvider>().loadMessages(appId);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    try {
      context.read<AdminApplicationsProvider>().loadApplications();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final studentName = app['student_full_name']?.toString() ?? '';
    final programTitle = app['program_title']?.toString() ?? '';
    final universityName = app['university_name']?.toString() ?? '';
    final status = app['status']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Candidature - Admin'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(programTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(universityName),
                const SizedBox(height: 4),
                Text('Étudiant : $studentName'),
                const SizedBox(height: 4),
                Text('Statut : $status'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<AdminApplicationMessagesProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return Center(child: Text('Erreur : ${provider.error}'));
                }

                final messages = provider.messages;
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Aucun message pour le moment. Utilisez le champ ci-dessous pour répondre à l\'étudiant ou contacter l\'université.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final senderRole = msg['sender_role']?.toString() ?? '';
                    final audience = msg['audience']?.toString() ?? '';
                    final content = msg['content']?.toString() ?? '';
                    final createdAtMsg = msg['created_at']?.toString() ?? '';

                    String label;
                    Alignment alignment;
                    Color color;

                    if (senderRole == 'student') {
                      label = 'Étudiant';
                      alignment = Alignment.centerLeft;
                      color = Colors.blue.withOpacity(0.1);
                    } else if (senderRole == 'university') {
                      label = 'Université';
                      alignment = Alignment.centerLeft;
                      color = Colors.green.withOpacity(0.1);
                    } else {
                      if (audience == 'student') {
                        label = 'Vous → Étudiant';
                      } else if (audience == 'university') {
                        label = 'Vous → Université';
                      } else {
                        label = 'Vous';
                      }
                      alignment = Alignment.centerRight;
                      color = Theme.of(context).colorScheme.primary.withOpacity(0.1);
                    }

                    return Align(
                      alignment: alignment,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(content),
                            if (createdAtMsg.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                createdAtMsg,
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _target,
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('→ Étudiant')),
                    DropdownMenuItem(value: 'university', child: Text('→ Université')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _target = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    final appId = widget.application['id']?.toString();
                    if (appId == null || appId.isEmpty) return;
                    final text = _messageController.text.trim();
                    if (text.isEmpty) return;

                    final provider = context.read<AdminApplicationMessagesProvider>();
                    bool ok;
                    if (_target == 'student') {
                      ok = await provider.sendToStudent(applicationId: appId, content: text);
                    } else {
                      ok = await provider.sendToUniversity(applicationId: appId, content: text);
                    }

                    if (!mounted) return;
                    if (ok) {
                      _messageController.clear();
                      try {
                        await context.read<AdminApplicationsProvider>().loadApplications();
                      } catch (_) {}
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            provider.error ?? 'Erreur lors de l\'envoi du message.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
