import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_applications_provider.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../student_application_detail_screen.dart';
import 'student_home_tab.dart';

class StudentApplicationsTab extends StatefulWidget {
  const StudentApplicationsTab({super.key});

  @override
  State<StudentApplicationsTab> createState() => _StudentApplicationsTabState();
}

class _StudentApplicationsTabState extends State<StudentApplicationsTab> {
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentApplicationsProvider>().loadApplications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentApplicationsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.applications.isEmpty) {
          return const LoadingWidget(message: 'Chargement de vos candidatures...');
        }

        if (provider.error != null) {
          return CustomErrorWidget(
            error: provider.error!,
            onRetry: () => provider.loadApplications(),
          );
        }

        final allApplications = provider.applications;

        if (allApplications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assignment_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('Vous n\'avez pas encore de candidature.'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: Text('Nouvelle candidature'),
                          ),
                          body: const StudentHomeTab(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle candidature'),
                ),
              ],
            ),
          );
        }

        // Appliquer le filtre de statut si sélectionné
        final applications = _statusFilter == null
            ? allApplications
            : allApplications
                .where((app) =>
                    (app['status']?.toString().toLowerCase() ?? '') ==
                    _statusFilter)
                .toList();

        return Column(
          children: [
            _StatusFilterBar(
              currentFilter: _statusFilter,
              onFilterChanged: (value) {
                setState(() {
                  _statusFilter = value;
                });
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: applications.length,
                itemBuilder: (context, index) {
                  final app = applications[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudentApplicationDetailScreen(
                            application: app,
                          ),
                        ),
                      );
                    },
                    child: _ApplicationCard(application: app),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  final String? currentFilter;
  final ValueChanged<String?> onFilterChanged;

  const _StatusFilterBar({
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    const statuses = <String?>[
      null, // Tous
      'draft',
      'submitted',
      'under_review',
      'accepted',
      'rejected',
      'canceled',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: statuses.map((status) {
          final selected = currentFilter == status;
          final label = status == null ? 'Tous' : _statusLabel(status);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => onFilterChanged(status),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> application;

  const _ApplicationCard({required this.application});

  @override
  Widget build(BuildContext context) {
    final status = application['status']?.toString() ?? '';
    final createdAt = application['created_at']?.toString() ?? '';
    final submittedAt = application['submitted_at']?.toString() ?? '';
    final hasUnread = application['has_unread_for_student'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Stack(
          children: [
            const Icon(Icons.assignment),
            if (hasUnread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text('Candidature ${application['id'] ?? ''}'),
            ),
            const SizedBox(width: 8),
            _StatusBadge(status: status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (submittedAt.isNotEmpty)
              Text('Soumise le: $submittedAt'),
            if (createdAt.isNotEmpty)
              Text('Créée le: $createdAt'),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = _statusLabel(status);
    final color = _statusColor(status, Theme.of(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

String _statusLabel(String? status) {
  switch (status) {
    case 'draft':
      return 'Brouillon';
    case 'submitted':
      return 'Soumise';
    case 'under_review':
      return 'En étude';
    case 'accepted':
      return 'Acceptée';
    case 'rejected':
      return 'Refusée';
    case 'canceled':
      return 'Annulée';
    default:
      return status ?? 'Inconnu';
  }
}

Color _statusColor(String? status, ThemeData theme) {
  switch (status) {
    case 'draft':
      return Colors.grey;
    case 'submitted':
      return theme.colorScheme.primary;
    case 'under_review':
      return Colors.orange;
    case 'accepted':
      return Colors.green;
    case 'rejected':
      return Colors.red;
    case 'canceled':
      return Colors.blueGrey;
    default:
      return Colors.grey;
  }
}
