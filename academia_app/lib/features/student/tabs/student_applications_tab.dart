import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_applications_provider.dart';
import '../../../providers/student_application_payments_provider.dart';
import '../../../widgets/bobodo_state.dart';
import '../../../widgets/bobodo_view.dart';
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

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final display = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      child: Center(
        child: Text(
          display,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
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
                    return FadeInUp(
                      duration: const Duration(milliseconds: 350),
                      delay: Duration(milliseconds: 50 * (index < 10 ? index : 0)),
                      child: _ApplicationCard(
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
          final Color statusColor = status == null
              ? _kApplicationsFilterSelectedLabelColor
              : _statusColor(status);
          final Color chipBackground = selected
              ? statusColor.withOpacity(0.12)
              : _kApplicationsFilterBackground;
          final Color borderColor = selected
              ? statusColor
              : (status == null
                  ? _kApplicationsFilterUnselectedBorderColor
                  : statusColor.withOpacity(0.5));
          final Color textColor = selected
              ? statusColor
              : (status == null
                  ? _kApplicationsFilterUnselectedLabelColor
                  : statusColor.withOpacity(0.9));
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
              selectedColor: chipBackground,
              backgroundColor: chipBackground,
              side: BorderSide(color: borderColor),
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
    return FadeInDown(
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEAF4FF), Color(0xFFFFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3275D0).withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3275D0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in,
                      color: Color(0xFF3275D0),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mes candidatures',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _kApplicationsFilterSelectedLabelColor,
                          ),
                        ),
                        SizedBox(height: 2),
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
                ],
              ),
              const SizedBox(height: 16),
              Consumer<StudentApplicationsProvider>(
                builder: (context, provider, _) {
                  final apps = provider.applications;
                  if (apps.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  int drafts = 0;
                  int submitted = 0;
                  int underReview = 0;
                  int accepted = 0;
                  int rejected = 0;
                  int canceled = 0;

                  for (final app in apps) {
                    final status = app['status']?.toString();
                    switch (status) {
                      case 'draft':
                        drafts++;
                        break;
                      case 'submitted':
                        submitted++;
                        break;
                      case 'under_review':
                        underReview++;
                        break;
                      case 'accepted':
                        accepted++;
                        break;
                      case 'rejected':
                        rejected++;
                        break;
                      case 'canceled':
                        canceled++;
                        break;
                      default:
                        break;
                    }
                  }

                  final bobodoState = _bobodoSummaryState(
                    drafts: drafts,
                    submitted: submitted,
                    underReview: underReview,
                    accepted: accepted,
                    rejected: rejected,
                    canceled: canceled,
                  );

                  final bobodoText = _bobodoSummaryText(
                    drafts: drafts,
                    submitted: submitted,
                    underReview: underReview,
                    accepted: accepted,
                    rejected: rejected,
                    canceled: canceled,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF3275D0).withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: BobodoView(
                                state: bobodoState,
                                size: 56,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                bobodoText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _kApplicationsFilterUnselectedLabelColor,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (drafts > 0)
                            _ApplicationsStatPill(
                              icon: Icons.edit_note,
                              color: _kApplicationsStatusDraftColor,
                              label: '$drafts brouillon${drafts > 1 ? 's' : ''}',
                            ),
                          if (submitted + underReview > 0)
                            _ApplicationsStatPill(
                              icon: Icons.timelapse,
                              color: _kApplicationsStatusSubmittedColor,
                              label:
                                  '${submitted + underReview} en cours',
                            ),
                          if (accepted > 0)
                            _ApplicationsStatPill(
                              icon: Icons.check_circle_outline,
                              color: _kApplicationsStatusAcceptedColor,
                              label:
                                  '$accepted acceptée${accepted > 1 ? 's' : ''}',
                            ),
                          if (rejected + canceled > 0)
                            _ApplicationsStatPill(
                              icon: Icons.cancel_outlined,
                              color: _kApplicationsStatusRejectedColor,
                              label:
                                  '${rejected + canceled} terminée${rejected + canceled > 1 ? 's' : ''}',
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicationsStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ApplicationsStatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
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
    if (status == 'accepted' && submittedAt.isNotEmpty) {
      mainDate = 'Acceptée le $submittedAt';
    } else if (status == 'under_review' && submittedAt.isNotEmpty) {
      mainDate = 'En étude depuis le $submittedAt';
    } else if (submittedAt.isNotEmpty) {
      mainDate = 'Soumise le $submittedAt';
    } else if (createdAt.isNotEmpty) {
      mainDate = 'Créée le $createdAt';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withOpacity(0.15),
                        statusColor.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.assignment_outlined,
                          color: statusColor,
                          size: 28,
                        ),
                      ),
                      if (hasUnread)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: _CountBadge(count: 1),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (programTitle.isNotEmpty)
                                  Text(
                                    degreeLevel.isNotEmpty
                                        ? '$programTitle · $degreeLevel'
                                        : programTitle,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _kApplicationsFilterSelectedLabelColor,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (universityName.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    universityName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _StatusBadge(status: status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              mainDate.isNotEmpty ? mainDate : 'Candidature $shortId',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

BobodoState _bobodoSummaryState({
  required int drafts,
  required int submitted,
  required int underReview,
  required int accepted,
  required int rejected,
  required int canceled,
}) {
  if (accepted > 0) {
    return BobodoState.success;
  }
  if (submitted + underReview > 0) {
    return BobodoState.thinking;
  }
  if (rejected + canceled > 0) {
    return BobodoState.warning;
  }
  return BobodoState.idle;
}

String _bobodoSummaryText({
  required int drafts,
  required int submitted,
  required int underReview,
  required int accepted,
  required int rejected,
  required int canceled,
}) {
  final int inProgress = submitted + underReview;
  final int finished = rejected + canceled;

  if (accepted > 0 && inProgress > 0) {
    return 'Tu as déjà au moins une admission et d\'autres dossiers en cours. On sécurise ce qui est gagné et on continue à avancer.';
  }
  if (accepted > 0) {
    return 'Bravo, tu as au moins une candidature acceptée 🎓. Considère-la comme ton badge \"Admission confirmée\" et vérifie les prochaines étapes.';
  }
  if (inProgress > 0) {
    return 'Tes candidatures sont en cours d\'étude. Quand ton dossier est complet et soumis, tu décroches le badge \"Dossier complet\".';
  }
  if (drafts > 0) {
    return 'Tu as des brouillons de candidatures. En les complétant, tu te rapproches du badge \"Dossier prêt\".';
  }
  if (finished > 0) {
    return 'Tes candidatures actuelles sont terminées. Tu peux explorer de nouveaux programmes si tu veux viser un nouveau badge.';
  }
  return 'Dès que tu crées une candidature, je t\'aide à suivre son avancement et tes badges ici.';
}
