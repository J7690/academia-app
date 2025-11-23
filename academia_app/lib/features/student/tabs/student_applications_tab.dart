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
            child: FilterChip(
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? const Color(0xFF006D3C) : const Color(0xFF374151),
                ),
              ),
              selected: selected,
              selectedColor: const Color(0xFFE5F9E7),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected
                    ? const Color(0xFF006D3C)
                    : const Color(0xFFE5E7EB),
              ),
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
    final id = application['id']?.toString() ?? '';
    final status = application['status']?.toString() ?? '';
    final createdAtRaw = application['created_at']?.toString();
    final submittedAtRaw = application['submitted_at']?.toString();
    final createdAt = _formatDate(createdAtRaw);
    final submittedAt = _formatDate(submittedAtRaw);
    final hasUnread = application['has_unread_for_student'] == true;

    final programTitle = application['program_title']?.toString() ?? '';
    final degreeLevel = application['degree_level']?.toString() ?? '';
    final universityName = application['university_name']?.toString() ?? '';

    String shortId = id;
    if (shortId.length > 8) {
      shortId = shortId.substring(0, 8);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    const Icon(Icons.assignment_outlined),
                    if (hasUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortId.isNotEmpty
                            ? 'Candidature $shortId'
                            : 'Candidature',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (programTitle.isNotEmpty || universityName.isNotEmpty)
                        const SizedBox(height: 4),
                      if (programTitle.isNotEmpty)
                        Text(
                          degreeLevel.isNotEmpty
                              ? '$programTitle · $degreeLevel'
                              : programTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (universityName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          universityName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      if (submittedAt.isNotEmpty)
                        Text(
                          'Soumise le : $submittedAt',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      if (createdAt.isNotEmpty)
                        Text(
                          'Créée le : $createdAt',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: status),
              ],
            ),
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
    final color = _statusColor(status);
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

Color _statusColor(String? status) {
  switch (status) {
    case 'draft':
      return const Color(0xFF9CA3AF);
    case 'submitted':
      return const Color(0xFF1EA75C);
    case 'under_review':
      return const Color(0xFFF59E0B);
    case 'accepted':
      return const Color(0xFFA3D65C);
    case 'rejected':
      return const Color(0xFFFF3B30);
    case 'canceled':
      return const Color(0xFF6B7280);
    default:
      return const Color(0xFF9CA3AF);
  }
}

String _formatDate(String? value) {
  if (value == null || value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final year = parsed.year.toString();
  return '$day/$month/$year';
}
