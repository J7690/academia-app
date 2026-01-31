import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/teacher_td_assignments_provider.dart';
import '../../providers/td_messages_provider.dart';

class TeacherTdAssignmentsScreen extends StatefulWidget {
  const TeacherTdAssignmentsScreen({super.key});

  @override
  State<TeacherTdAssignmentsScreen> createState() => _TeacherTdAssignmentsScreenState();
}

class _TeacherTdAssignmentsScreenState extends State<TeacherTdAssignmentsScreen> {
  String? _selectedEnrollmentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TeacherTdAssignmentsProvider>().loadAssignments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final assignmentsProvider = context.watch<TeacherTdAssignmentsProvider>();
    final messagesProvider = context.watch<TdMessagesProvider>();
    final assignments = assignmentsProvider.assignments;

    final messages = _selectedEnrollmentId == null
        ? const <Map<String, dynamic>>[]
        : messagesProvider.messagesFor(_selectedEnrollmentId!);

    final nextSessions = assignmentsProvider.nextSessions;
    DateTime? nextSessionAt;
    if (nextSessions.isNotEmpty) {
      for (final s in nextSessions) {
        final raw = s['scheduled_at'];
        if (raw == null) continue;
        final dt = DateTime.tryParse(raw.toString());
        if (dt == null) continue;
        if (nextSessionAt == null || dt.isBefore(nextSessionAt)) {
          nextSessionAt = dt;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes missions TD'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(assignments.length, nextSessions.length, nextSessionAt),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final list =
                      _buildAssignmentsList(assignments, messagesProvider);

                  if (!isWide) {
                    return Column(
                      children: [
                        Expanded(child: list),
                        const SizedBox(height: 16),
                        _buildMessagesPanel(messagesProvider, messages),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(flex: 3, child: list),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _buildMessagesPanel(
                          messagesProvider,
                          messages,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    int assignmentsCount,
    int upcomingSessionsCount,
    DateTime? nextSessionAt,
  ) {
    String nextLabel;
    if (nextSessionAt != null) {
      final d = nextSessionAt;
      final day = d.day.toString().padLeft(2, '0');
      final month = d.month.toString().padLeft(2, '0');
      final year = d.year.toString();
      final hour = d.hour.toString().padLeft(2, '0');
      final minute = d.minute.toString().padLeft(2, '0');
      nextLabel = 'Prochaine séance prévue le $day/$month/$year à $hour:$minute';
    } else {
      nextLabel =
          'Dès qu\'un admin programme une séance, elle apparaîtra dans ton planning.';
    }

    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu as $assignmentsCount mission(s) TD assignée(s).',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    upcomingSessionsCount > 0
                        ? '$upcomingSessionsCount séance(s) à venir.'
                        : 'Aucune séance planifiée pour le moment.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nextLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentsList(
    List<Map<String, dynamic>> assignments,
    TdMessagesProvider messagesProvider,
  ) {
    if (assignments.isEmpty) {
      return const Center(
        child: Text('Aucune mission TD pour le moment.'),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: assignments.length,
        separatorBuilder: (_, __) => const Divider(height: 16),
        itemBuilder: (context, index) {
          final a = assignments[index];
          final enrollmentId = a['id']?.toString() ?? '';
          final programTitle = a['program_title']?.toString() ?? 'Programme TD';
          final level = a['program_level']?.toString() ?? '';
          final accessScope = a['access_scope']?.toString() ?? '';
          final accessStatus = a['access_status']?.toString() ?? '';

          Color statusColor;
          if (accessStatus == 'pending_payment') {
            statusColor = Colors.orange;
          } else if (accessStatus == 'waiting_admin') {
            statusColor = Colors.blue;
          } else if (accessStatus == 'active') {
            statusColor = Colors.green;
          } else if (accessStatus == 'completed') {
            statusColor = Colors.grey;
          } else {
            statusColor = Colors.grey;
          }

          final isSelected = _selectedEnrollmentId == enrollmentId;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedEnrollmentId = enrollmentId;
              });
              if (enrollmentId.isNotEmpty) {
                messagesProvider.loadMessages(enrollmentId);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE3F2FD) : null,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          programTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          accessStatus,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        backgroundColor: statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (level.isNotEmpty)
                        Chip(
                          label: Text('Niveau: $level'),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (accessScope.isNotEmpty)
                        Chip(
                          label: Text('Accès: $accessScope'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessagesPanel(
    TdMessagesProvider messagesProvider,
    List<Map<String, dynamic>> messages,
  ) {
    if (_selectedEnrollmentId == null) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Sélectionnez une mission TD pour voir la messagerie associée.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final controller = TextEditingController();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListTile(
            title: Text('Messagerie avec l\'admin TD'),
          ),
          const Divider(height: 1),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text('Aucun message pour cette mission TD.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final m = messages[index];
                      final senderRole = m['sender_role']?.toString() ?? '';
                      final content = m['content']?.toString() ?? '';
                      final createdAt = m['created_at']?.toString() ?? '';

                      final isTeacher = senderRole == 'teacher';
                      final align = isTeacher
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start;
                      final bgColor = isTeacher
                          ? const Color(0xFFE3F2FD)
                          : const Color(0xFFE8F5E9);

                      return Align(
                        alignment: isTeacher
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: align,
                            children: [
                              Text(
                                content,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$senderRole · $createdAt',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message à l\'admin TD...',
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
                    final id = _selectedEnrollmentId;
                    if (id == null) return;

                    await messagesProvider.sendMessage(
                      enrollmentId: id,
                      threadType: 'teacher_admin',
                      content: text,
                    );
                    controller.clear();
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
