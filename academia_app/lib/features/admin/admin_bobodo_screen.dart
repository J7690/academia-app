import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_bobodo_conversations_provider.dart';
import '../../providers/admin_bobodo_needs_provider.dart';
import '../../providers/admin_bobodo_unanswered_provider.dart';
import '../../utils/responsive.dart';

class AdminBobodoScreen extends StatelessWidget {
  const AdminBobodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: const [
          TabBar(
            isScrollable: true,
            indicator: BoxDecoration(
              color: Color(0xFF1EA75C),
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            indicatorPadding:
                EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            labelPadding: EdgeInsets.symmetric(horizontal: 16),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.black87,
            tabs: [
              Tab(text: 'Conversations'),
              Tab(text: 'Besoins détectés'),
              Tab(text: 'Questions non couvertes'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AdminBobodoConversationsTab(),
                _AdminBobodoNeedsTab(),
                _AdminBobodoUnansweredTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminBobodoConversationsTab extends StatefulWidget {
  const _AdminBobodoConversationsTab();

  @override
  State<_AdminBobodoConversationsTab> createState() => _AdminBobodoConversationsTabState();
}

class _AdminBobodoConversationsTabState extends State<_AdminBobodoConversationsTab> {
  String? _selectedStudentId;
  String? _selectedSessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBobodoConversationsProvider>().loadSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminBobodoConversationsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingSessions && provider.sessions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(provider.error!),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: provider.loadSessions,
                  child: const Text('Recharger'),
                ),
              ],
            ),
          );
        }

        final students = provider.distinctStudents;
        final sessions = provider.sessionsForStudent(_selectedStudentId);
        final messages = provider.messages;

        final studentsPane = _Pane(
          title: 'Étudiants',
          child: ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              final id = student['student_id'];
              final selected = id == _selectedStudentId;
              return ListTile(
                selected: selected,
                title: Text(student['student_full_name'] ?? ''),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  setState(() {
                    _selectedStudentId = id;
                    _selectedSessionId = null;
                  });
                },
              );
            },
          ),
        );

        final sessionsPane = _Pane(
          title: 'Sessions',
          onBack: () => setState(() => _selectedStudentId = null),
          child: sessions.isEmpty
              ? const Center(child: Text('Aucune session Bobodo.'))
              : ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final id = session['id']?.toString();
                    final selected = id == _selectedSessionId;
                    final title = session['title']?.toString();
                    final createdAt = session['created_at']?.toString();
                    return ListTile(
                      selected: selected,
                      title: Text(title?.isNotEmpty == true
                          ? title!
                          : 'Session ${createdAt ?? ''}'),
                      subtitle: createdAt != null ? Text(createdAt) : null,
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () {
                        if (id == null) return;
                        setState(() => _selectedSessionId = id);
                        provider.loadMessages(id);
                      },
                    );
                  },
                ),
        );

        final conversationPane = _Pane(
          title: 'Conversation',
          onBack: () => setState(() => _selectedSessionId = null),
          child: _selectedSessionId == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Sélectionnez un étudiant puis une session pour voir la conversation.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : provider.isLoadingMessages && messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                      ? const Center(child: Text('Aucun message dans cette session.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            final isStudent = msg['sender'] == 'student';
                            final content = msg['content']?.toString() ?? '';
                            final createdAt = msg['created_at']?.toString();
                            return Align(
                              alignment: isStudent
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: ConstrainedBox(
                                // Largeur de bulle relative : jamais figée.
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width *
                                      (context.isMobile ? 0.86 : 0.7),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isStudent
                                        ? Colors.white
                                        : const Color(0xFFE5F9E7),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(content),
                                      if (createdAt != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          createdAt,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            // Trois panneaux côte à côte : viable seulement à partir de la
            // largeur tablette. Sur téléphone, un seul panneau à la fois
            // (navigation par étapes) sinon chaque colonne devient illisible.
            if (constraints.maxWidth >= AppBreakpoints.tablet) {
              final studentsWidth =
                  (constraints.maxWidth * 0.18).clamp(200.0, 260.0);
              final sessionsWidth =
                  (constraints.maxWidth * 0.22).clamp(220.0, 320.0);
              return Row(
                children: [
                  SizedBox(width: studentsWidth, child: studentsPane),
                  const VerticalDivider(width: 1),
                  SizedBox(width: sessionsWidth, child: sessionsPane),
                  const VerticalDivider(width: 1),
                  Expanded(child: conversationPane),
                ],
              );
            }

            if (_selectedSessionId != null) return conversationPane;
            if (_selectedStudentId != null) return sessionsPane;
            return studentsPane;
          },
        );
      },
    );
  }
}

/// Panneau à en-tête avec titre et retour optionnel (utilisé en navigation
/// pas-à-pas sur téléphone, et côte à côte sur grand écran).
class _Pane extends StatelessWidget {
  const _Pane({required this.title, required this.child, this.onBack});

  final String title;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: onBack,
                ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );
  }
}

class _AdminBobodoNeedsTab extends StatefulWidget {
  const _AdminBobodoNeedsTab();

  @override
  State<_AdminBobodoNeedsTab> createState() => _AdminBobodoNeedsTabState();
}

class _AdminBobodoNeedsTabState extends State<_AdminBobodoNeedsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBobodoNeedsProvider>().loadNeeds();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminBobodoNeedsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.needs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.needs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(provider.error!),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => provider.loadNeeds(),
                  child: const Text('Recharger'),
                ),
              ],
            ),
          );
        }

        final needs = provider.needs;
        if (needs.isEmpty) {
          return const Center(
            child: Text('Aucun besoin détecté pour le moment.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: needs.length,
          itemBuilder: (context, index) {
            final need = needs[index];
            final studentName = need['student_full_name']?.toString() ?? '';
            final category = need['category']?.toString() ?? '';
            final summary = need['need_summary']?.toString() ?? '';
            final createdAt = need['created_at']?.toString();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(studentName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            createdAt,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (category.isNotEmpty)
                      Text('Catégorie : $category'),
                    const SizedBox(height: 8),
                    Text(summary),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminBobodoUnansweredTab extends StatefulWidget {
  const _AdminBobodoUnansweredTab();

  @override
  State<_AdminBobodoUnansweredTab> createState() => _AdminBobodoUnansweredTabState();
}

class _AdminBobodoUnansweredTabState extends State<_AdminBobodoUnansweredTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBobodoUnansweredProvider>().loadQuestions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminBobodoUnansweredProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.questions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.questions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(provider.error!),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => provider.loadQuestions(),
                  child: const Text('Recharger'),
                ),
              ],
            ),
          );
        }

        final questions = provider.questions;
        if (questions.isEmpty) {
          return const Center(
            child: Text('Aucune question non couverte pour le moment.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: questions.length,
          itemBuilder: (context, index) {
            final q = questions[index];
            final questionText = q['question_text']?.toString() ?? '';
            final category = q['category']?.toString() ?? '';
            final status = q['status']?.toString() ?? '';
            final createdAt = q['created_at']?.toString();
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (createdAt != null)
                      Text(
                        createdAt,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 4),
                    Text(questionText),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (category.isNotEmpty)
                          Chip(label: Text(category)),
                        if (status.isNotEmpty)
                          Chip(label: Text(status)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
