import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_td_student_requests_provider.dart';

class AdminTdStudentRequestsScreen extends StatefulWidget {
  const AdminTdStudentRequestsScreen({super.key});

  @override
  State<AdminTdStudentRequestsScreen> createState() => _AdminTdStudentRequestsScreenState();
}

class _AdminTdStudentRequestsScreenState extends State<AdminTdStudentRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminTdStudentRequestsProvider>().loadRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminTdStudentRequestsProvider>();
    final requests = provider.requests;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('TD - Demandes étudiants'),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadRequests(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final r = requests[index];
            final id = r['id']?.toString() ?? '';
            final subject = r['subject']?.toString() ?? '';
            final level = r['level']?.toString() ?? '';
            final status = r['status']?.toString() ?? '';
            final studentEmail = r['student_email']?.toString() ?? '';
            final fieldName = r['field_name']?.toString() ?? '';
            final description = r['description']?.toString() ?? '';
            final preferredModality = r['preferred_modality']?.toString() ?? '';
            final preferredSchedule = r['preferred_schedule']?.toString() ?? '';
            final createdProgramTitle = r['created_program_title']?.toString() ?? '';

            Color statusColor;
            if (status == 'pending') {
              statusColor = Colors.orange;
            } else if (status == 'in_review') {
              statusColor = Colors.blue;
            } else if (status == 'planned') {
              statusColor = Colors.purple;
            } else if (status == 'converted') {
              statusColor = Colors.green;
            } else if (status == 'rejected') {
              statusColor = Colors.red;
            } else {
              statusColor = Colors.grey;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject.isEmpty ? 'Demande TD' : subject,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            status.isEmpty ? 'Inconnu' : status,
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
                        if (studentEmail.isNotEmpty)
                          Text('Étudiant: $studentEmail'),
                        if (fieldName.isNotEmpty)
                          Text('Filière: $fieldName'),
                        if (level.isNotEmpty)
                          Text('Niveau: $level'),
                        if (preferredModality.isNotEmpty)
                          Text('Modalité: $preferredModality'),
                      ],
                    ),
                    if (preferredSchedule.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Créneaux: $preferredSchedule',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                    if (createdProgramTitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Programme lié: $createdProgramTitle',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: status == 'converted'
                            ? null
                            : () => _promptMarkConverted(context, provider, id),
                        icon: const Icon(Icons.link, size: 18),
                        label: const Text('Lier à un programme'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _promptMarkConverted(
    BuildContext context,
    AdminTdStudentRequestsProvider provider,
    String requestId,
  ) async {
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Lier la demande à un programme TD'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'ID programme TD',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final programId = controller.text.trim();
    if (programId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID programme TD requis.')),
      );
      return;
    }

    final ok = await provider.markRequestConverted(
      requestId: requestId,
      programId: programId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Demande TD marquée comme convertie.'
              : provider.error ?? 'Erreur lors de la mise à jour.',
        ),
      ),
    );
  }
}
