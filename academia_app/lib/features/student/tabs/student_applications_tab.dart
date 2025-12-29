import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_applications_provider.dart';
import '../../../providers/student_application_payments_provider.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';
import '../student_application_detail_screen.dart';
import 'student_home_tab.dart';

const _kApplicationsPageBackground = Color(0xFFF4F7FB);

const _kApplicationsFilterSelectedLabelColor = Color(0xFF0A2540);
const _kApplicationsFilterUnselectedLabelColor = Color(0xFF374151);
const _kApplicationsFilterSelectedBackground = Color(0xFFE5F1FF);
const _kApplicationsFilterBackground = Colors.white;
const _kApplicationsFilterSelectedBorderColor = Color(0xFF3275D0);
const _kApplicationsFilterUnselectedBorderColor = Color(0xFFE5E7EB);

const _kApplicationsHeaderBackground = Color(0xFFEAF4FF);

const _kApplicationsStatusDraftColor = Color(0xFF9CA3AF);
const _kApplicationsStatusSubmittedColor = Color(0xFF3275D0);
const _kApplicationsStatusUnderReviewColor = Color(0xFFF6A623);
const _kApplicationsStatusAcceptedColor = Color(0xFF1B8F5A);
const _kApplicationsStatusRejectedColor = Color(0xFFE53935);
const _kApplicationsStatusCanceledColor = Color(0xFF6B7280);

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
    return Container(
      color: _kApplicationsPageBackground,
      child: Consumer<StudentApplicationsProvider>(
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
            return Column(
              children: [
                const _ApplicationsHeader(),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 56,
                            color: Color(0xFF9CA3AF),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucune candidature pour le moment',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _kApplicationsFilterSelectedLabelColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Dès que vous candidaterez à une formation, elle apparaîtra ici pour un suivi simple et clair.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: _kApplicationsFilterUnselectedLabelColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(
                                      title: const Text('Découvrir des formations'),
                                    ),
                                    body: const StudentHomeTab(),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.search),
                            label: const Text('Découvrir des opportunités'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
              const _ApplicationsHeader(),
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
                    return _ApplicationCard(
                      application: app,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider(
                              create: (_) => StudentApplicationPaymentsProvider(),
                              child: StudentApplicationDetailScreen(
                                application: app,
                              ),
                            ),
                          ),
                        );
                      },
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
          final iconData = _statusIcon(status);
          final textColor = selected
              ? _kApplicationsFilterSelectedLabelColor
              : _kApplicationsFilterUnselectedLabelColor;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconData != null) ...[
                    Icon(
                      iconData,
                      size: 14,
                      color: textColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              selected: selected,
              selectedColor: _kApplicationsFilterSelectedBackground,
              backgroundColor: _kApplicationsFilterBackground,
              side: BorderSide(
                color: selected
                    ? _kApplicationsFilterSelectedBorderColor
                    : _kApplicationsFilterUnselectedBorderColor,
              ),
              onSelected: (_) => onFilterChanged(status),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ApplicationsHeader extends StatelessWidget {
  const _ApplicationsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kApplicationsHeaderBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Mes candidatures',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _kApplicationsFilterSelectedLabelColor,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Suivez l\'évolution de vos demandes universitaires.',
              style: TextStyle(
                fontSize: 13,
                color: _kApplicationsFilterUnselectedLabelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> application;

  final VoidCallback? onTap;

  const _ApplicationCard({required this.application, this.onTap});

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

    final statusColor = _statusColor(status);

    String mainDate = '';
    if (submittedAt.isNotEmpty) {
      mainDate = 'Soumise le : $submittedAt';
    } else if (createdAt.isNotEmpty) {
      mainDate = 'Créée le : $createdAt';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.9),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                              if (programTitle.isNotEmpty)
                                Text(
                                  degreeLevel.isNotEmpty
                                      ? '$programTitle · $degreeLevel'
                                      : programTitle,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
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
                              if (shortId.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Candidature $shortId',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: status),
                      ],
                    ),
                    if (mainDate.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        mainDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
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
      return _kApplicationsStatusDraftColor;
    case 'submitted':
      return _kApplicationsStatusSubmittedColor;
    case 'under_review':
      return _kApplicationsStatusUnderReviewColor;
    case 'accepted':
      return _kApplicationsStatusAcceptedColor;
    case 'rejected':
      return _kApplicationsStatusRejectedColor;
    case 'canceled':
      return _kApplicationsStatusCanceledColor;
    default:
      return _kApplicationsStatusDraftColor;
  }
}

IconData? _statusIcon(String? status) {
  switch (status) {
    case null:
      return Icons.filter_alt_outlined;
    case 'draft':
      return Icons.edit_note;
    case 'submitted':
      return Icons.outbox;
    case 'under_review':
      return Icons.search;
    case 'accepted':
      return Icons.check_circle_outline;
    case 'rejected':
      return Icons.cancel_outlined;
    case 'canceled':
      return Icons.close;
    default:
      return Icons.help_outline;
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
