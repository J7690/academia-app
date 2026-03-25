import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_td_enrollments_provider.dart';
import '../../providers/td_messages_provider.dart';
import '../../theme/td_theme.dart';
import 'admin_td_analytics_screen.dart';
import 'admin_td_catalog_screen.dart';
import 'admin_td_teachers_screen.dart';
import 'admin_td_student_requests_screen.dart';
import 'admin_td_local_groups_screen.dart';
import 'admin_td_upload_screen.dart';

class AdminTdScreen extends StatefulWidget {
  const AdminTdScreen({super.key});

  @override
  State<AdminTdScreen> createState() => _AdminTdScreenState();
}

class _AdminTdScreenState extends State<AdminTdScreen> {
  String? _selectedEnrollmentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminTdEnrollmentsProvider>().loadEnrollments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final enrollmentsProvider = context.watch<AdminTdEnrollmentsProvider>();
    final messagesProvider = context.watch<TdMessagesProvider>();
    final enrollments = enrollmentsProvider.enrollments;

    final messages = _selectedEnrollmentId == null
        ? const <Map<String, dynamic>>[]
        : messagesProvider.messagesFor(_selectedEnrollmentId!);

    return Container(
      color: TdTheme.scaffoldBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with violet gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: TdTheme.adminTdGradient),
                    borderRadius: BorderRadius.circular(TdTheme.radiusLg),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Module TD',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            Text('Paiements, affectations & suivi',
                                style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: null,
                        icon: Icon(Icons.refresh, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Navigation buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _NavChip(
                      icon: Icons.dashboard_customize_outlined,
                      label: 'Catalogue TD',
                      color: TdTheme.adminTdPrimary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AdminTdCatalogScreen()),
                      ),
                    ),
                    _NavChip(
                      icon: Icons.people_alt_outlined,
                      label: 'Enseignants',
                      color: TdTheme.instructorPrimary,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AdminTdTeachersScreen()),
                      ),
                    ),
                    _NavChip(
                      icon: Icons.help_outline,
                      label: 'Demandes',
                      color: TdTheme.warning,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AdminTdStudentRequestsScreen()),
                      ),
                    ),
                    _NavChip(
                      icon: Icons.analytics_outlined,
                      label: 'Analytics & Badges',
                      color: const Color(0xFFF59E0B),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AdminTdAnalyticsScreen()),
                      ),
                    ),
                    _NavChip(
                      icon: Icons.location_on,
                      label: 'Groupes Locaux',
                      color: const Color(0xFF0891B2),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AdminTdLocalGroupsScreen()),
                      ),
                    ),
                    _NavChip(
                      icon: Icons.upload_file,
                      label: 'Upload & IA TD',
                      color: const Color(0xFF7C3AED),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AdminTdUploadScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStatsRow(context, enrollments),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildEnrollmentAndMessages(
                    context,
                    enrollments,
                    messagesProvider,
                    messages,
                    isWide,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    List<Map<String, dynamic>> enrollments,
  ) {
    final total = enrollments.length;

    int pendingPayment = 0;
    int waitingAdmin = 0;
    int active = 0;

    for (final e in enrollments) {
      final status = (e['access_status'] ?? '').toString();
      if (status == 'pending_payment') {
        pendingPayment++;
      } else if (status == 'waiting_admin') {
        waitingAdmin++;
      } else if (status == 'active') {
        active++;
      }
    }

    // Si disponible, on privilégie les compteurs agrégés renvoyés par le backend.
    final dashboardCounts =
        context.read<AdminTdEnrollmentsProvider>().dashboardCounts;
    int? upcomingSessions;
    int? studentRequestsPending;
    if (dashboardCounts != null) {
      pendingPayment =
          (dashboardCounts['enrollments_pending_payment'] as int?) ?? pendingPayment;
      waitingAdmin =
          (dashboardCounts['enrollments_waiting_admin'] as int?) ?? waitingAdmin;
      active =
          (dashboardCounts['enrollments_active'] as int?) ?? active;
      upcomingSessions =
          dashboardCounts['upcoming_sessions'] as int?;
      studentRequestsPending =
          dashboardCounts['student_requests_pending'] as int?;
    }

    final cards = <Widget>[
      _StatCard(
        color: const Color(0xFFFFA726),
        title: 'En attente de paiement',
        value: pendingPayment.toString(),
      ),
      _StatCard(
        color: const Color(0xFF29B6F6),
        title: 'En attente admin',
        value: waitingAdmin.toString(),
      ),
      _StatCard(
        color: const Color(0xFF66BB6A),
        title: 'TD actifs',
        value: active.toString(),
      ),
      _StatCard(
        color: const Color(0xFFAB47BC),
        title: 'Total inscriptions',
        value: total.toString(),
      ),
    ];

    if (upcomingSessions != null) {
      cards.add(
        _StatCard(
          color: const Color(0xFF5C6BC0),
          title: 'Séances à venir',
          value: upcomingSessions.toString(),
        ),
      );
    }
    if (studentRequestsPending != null) {
      cards.add(
        _StatCard(
          color: const Color(0xFFEF6C00),
          title: 'Demandes TD en attente',
          value: studentRequestsPending.toString(),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cards
            .map(
              (c) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: c,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildEnrollmentAndMessages(
    BuildContext context,
    List<Map<String, dynamic>> enrollments,
    TdMessagesProvider messagesProvider,
    List<Map<String, dynamic>> messages,
    bool isWide,
  ) {
    final list = _buildEnrollmentList(enrollments, messagesProvider);

    if (!isWide) {
      return Column(
        children: [
          Expanded(child: list),
          const SizedBox(height: 16),
          _buildMessagesPanel(context, messagesProvider, messages),
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 3, child: list),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: _buildMessagesPanel(context, messagesProvider, messages)),
      ],
    );
  }

  Widget _buildEnrollmentList(
    List<Map<String, dynamic>> enrollments,
    TdMessagesProvider messagesProvider,
  ) {
    if (enrollments.isEmpty) {
      return const Center(
        child: Text('Aucune inscription TD pour le moment.'),
      );
    }

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: enrollments.length,
        separatorBuilder: (_, __) => const Divider(height: 16),
        itemBuilder: (context, index) {
          final e = enrollments[index];
          final enrollmentId = e['id']?.toString() ?? '';
          final studentEmail = e['student_email']?.toString() ?? '';
          final programTitle = e['program_title']?.toString() ?? 'Programme TD';
          final level = e['level']?.toString() ?? '';
          final accessScope = e['access_scope']?.toString() ?? '';
          final accessStatus = e['access_status']?.toString() ?? '';
          final assignmentStatus = e['assignment_status']?.toString() ?? '';
          final teacherName = e['teacher_name']?.toString();
          final paymentStatus = e['payment_status']?.toString() ?? '';
          final paymentRef = e['payment_reference']?.toString() ?? '';
          final amountDue = e['payment_amount_due'];
          final amountPaid = e['payment_amount_paid'];
          final studentNotes = e['student_notes']?.toString() ?? '';

          final isSelected = _selectedEnrollmentId == enrollmentId;

          Color statusColor;
          if (accessStatus == 'pending_payment') {
            statusColor = Colors.orange;
          } else if (accessStatus == 'waiting_admin') {
            statusColor = Colors.blue;
          } else if (accessStatus == 'active') {
            statusColor = Colors.green;
          } else {
            statusColor = Colors.grey;
          }

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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
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
                      _SmallInfoChip(
                        icon: Icons.person,
                        label: studentEmail,
                      ),
                      if (level.isNotEmpty)
                        _SmallInfoChip(
                          icon: Icons.school,
                          label: level,
                        ),
                      if (accessScope.isNotEmpty)
                        _SmallInfoChip(
                          icon: Icons.lock_open,
                          label: accessScope,
                        ),
                      if (teacherName != null && teacherName.isNotEmpty)
                        _SmallInfoChip(
                          icon: Icons.person_outline,
                          label: 'Ens. $teacherName',
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _SmallInfoChip(
                        icon: Icons.payments_outlined,
                        label:
                            'Paiement: ${paymentStatus.isEmpty ? '' : paymentStatus}',
                      ),
                      if (amountDue != null)
                        _SmallInfoChip(
                          icon: Icons.request_quote,
                          label: 'A payer: $amountDue',
                        ),
                      if (amountPaid != null)
                        _SmallInfoChip(
                          icon: Icons.check_circle_outline,
                          label: 'Pay: $amountPaid',
                        ),
                      if (paymentRef.isNotEmpty)
                        _SmallInfoChip(
                          icon: Icons.confirmation_number_outlined,
                          label: paymentRef,
                        ),
                    ],
                  ),
                  if (studentNotes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Notes étudiant: $studentNotes',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Affectation: $assignmentStatus',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: paymentStatus == 'confirmed'
                            ? () => _promptAssignTeacher(context, e)
                            : null,
                        icon: const Icon(Icons.person_search, size: 18),
                        label: const Text('Assigner un enseignant'),
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

  Future<void> _promptAssignTeacher(
    BuildContext context,
    Map<String, dynamic> enrollment,
  ) async {
    final provider = context.read<AdminTdEnrollmentsProvider>();
    final enrollmentId = enrollment['id']?.toString() ?? '';
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Assigner un enseignant TD'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pour cette premire version, saisissez l\'ID interne de l\'enseignant TD.\n'
                'Une interface de slection d die pourra tre ajoute ensuite.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'ID enseignant TD',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Assigner'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final teacherId = controller.text.trim();
    if (teacherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID enseignant TD requis.')),
      );
      return;
    }

    final ok = await provider.assignTeacher(
      enrollmentId: enrollmentId,
      tdTeacherId: teacherId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Enseignant TD assign avec succs.'
              : provider.error ?? 'Erreur lors de l\'assignation.',
        ),
      ),
    );
  }

  Widget _buildMessagesPanel(
    BuildContext context,
    TdMessagesProvider messagesProvider,
    List<Map<String, dynamic>> messages,
  ) {
    if (_selectedEnrollmentId == null) {
      return Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Slectionnez une inscription TD pour voir la messagerie associe.',
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
            title: Text('Messagerie TD (Admin  tudiant / Enseignant)'),
          ),
          const Divider(height: 1),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text('Aucun message pour cette inscription TD.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final m = messages[index];
                      final senderRole = m['sender_role']?.toString() ?? '';
                      final content = m['content']?.toString() ?? '';
                      final createdAt = m['created_at']?.toString() ?? '';

                      final isAdmin = senderRole == 'admin';
                      final align = isAdmin
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start;
                      final bgColor = isAdmin
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFE3F2FD);

                      return Align(
                        alignment: isAdmin
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
                                '$senderRole  $createdAt',
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
                      hintText: 'Rpondre en tant qu\'admin',
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
                      threadType: 'student_admin',
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

class _NavChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(TdTheme.radiusMd),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios, size: 10, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final Color color;
  final String title;
  final String value;

  const _StatCard({
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TdTheme.cardBg,
        borderRadius: BorderRadius.circular(TdTheme.radiusMd),
        border: Border.all(color: TdTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: TdTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SmallInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.only(right: 8),
      avatar: Icon(icon, size: 14),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}
