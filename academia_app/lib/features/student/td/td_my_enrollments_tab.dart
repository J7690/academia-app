import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';

import '../../../providers/td_gamification_provider.dart';
import '../../../theme/td_theme.dart';

/// Onglet Mes TD — Inscriptions actives + progression + messagerie
class TdMyEnrollmentsTab extends StatelessWidget {
  const TdMyEnrollmentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TdGamificationProvider>();

    if (p.enrollmentsLoading && p.enrollments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (p.enrollments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.school_outlined, size: 56, color: TdTheme.textTertiary.withOpacity(0.4)),
              const SizedBox(height: 12),
              const Text("Tu n'as pas encore de TD",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: TdTheme.textSecondary)),
              const SizedBox(height: 6),
              const Text('Explore le catalogue pour trouver un TD adapté à ton niveau.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: TdTheme.textTertiary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TdTheme.studentTdPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => DefaultTabController.of(context).animateTo(1),
                icon: const Icon(Icons.explore, size: 18),
                label: const Text('Explorer'),
              ),
            ],
          ),
        ),
      );
    }

    final active = p.enrollments.where((e) => e['access_status'] == 'active').toList();
    final pending = p.enrollments.where((e) => e['access_status'] != 'active' && e['access_status'] != 'completed').toList();
    final completed = p.enrollments.where((e) => e['access_status'] == 'completed').toList();

    return RefreshIndicator(
      onRefresh: p.loadEnrollments,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          if (active.isNotEmpty) ...[
            const Text('En cours', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TdTheme.textPrimary)),
            const SizedBox(height: 10),
            ...active.asMap().entries.map((e) => FadeInUp(
                  delay: Duration(milliseconds: 30 * e.key),
                  duration: const Duration(milliseconds: 300),
                  child: _EnrollmentCard(enrollment: e.value, isActive: true),
                )),
            const SizedBox(height: 16),
          ],
          if (pending.isNotEmpty) ...[
            const Text('En attente', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TdTheme.textSecondary)),
            const SizedBox(height: 10),
            ...pending.map((e) => _EnrollmentCard(enrollment: e, isActive: false)),
            const SizedBox(height: 16),
          ],
          if (completed.isNotEmpty) ...[
            const Text('Terminés', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TdTheme.textTertiary)),
            const SizedBox(height: 10),
            ...completed.map((e) => _EnrollmentCard(enrollment: e, isActive: false)),
          ],
        ],
      ),
    );
  }
}

class _EnrollmentCard extends StatelessWidget {
  final Map<String, dynamic> enrollment;
  final bool isActive;

  const _EnrollmentCard({required this.enrollment, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final title = enrollment['program_title']?.toString() ?? '';
    final fieldName = enrollment['field_name']?.toString() ?? '';
    final fieldColor = TdTheme.colorFromHex(enrollment['field_color']?.toString());
    final pct = (enrollment['progress_pct'] as int? ?? 0) / 100.0;
    final completedSessions = enrollment['completed_sessions'] as int? ?? 0;
    final totalSessions = enrollment['total_sessions'] as int? ?? 0;
    final unread = enrollment['unread_messages'] as int? ?? 0;
    final nextSession = enrollment['next_session'] as Map<String, dynamic>?;
    final status = enrollment['access_status']?.toString() ?? '';

    final (statusLabel, statusColor) = TdTheme.accessStatusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: TdTheme.cardDecoration(borderColor: isActive ? fieldColor.withOpacity(0.3) : null),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(TdTheme.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(TdTheme.radiusLg),
          onTap: () {
            // TODO: Navigate to enrollment detail / messages
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [fieldColor, fieldColor.withOpacity(0.7)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.menu_book, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (fieldName.isNotEmpty) ...[
                                TdTheme.disciplineChip(fieldName, color: fieldColor),
                                const SizedBox(width: 6),
                              ],
                              TdTheme.statusBadge(statusLabel, statusColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (unread > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: TdTheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text('$unread',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                if (isActive) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  totalSessions > 0
                                      ? 'Séance $completedSessions/$totalSessions'
                                      : 'Progression',
                                  style: const TextStyle(fontSize: 11, color: TdTheme.textSecondary),
                                ),
                                Text('${(pct * 100).toInt()}%',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fieldColor)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            TdTheme.progressBar(value: pct, color: fieldColor, height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (nextSession != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: TdTheme.success.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event, size: 14, color: TdTheme.success),
                          const SizedBox(width: 6),
                          Text(
                            'Prochaine: ${TdTheme.formatDateTime(nextSession['scheduled_at']?.toString() ?? '')}',
                            style: const TextStyle(fontSize: 11, color: TdTheme.success, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
