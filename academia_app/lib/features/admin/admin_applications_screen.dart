import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_applications_provider.dart';
import '../../providers/admin_application_payments_provider.dart';
import '../../utils/responsive.dart';
import 'admin_application_detail_screen.dart';
import 'admin_application_status.dart';

class AdminApplicationsScreen extends StatefulWidget {
  const AdminApplicationsScreen({super.key});

  @override
  State<AdminApplicationsScreen> createState() =>
      _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends State<AdminApplicationsScreen> {
  bool _onlyDiscountRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminApplicationsProvider>().loadApplications();
    });
  }

  Future<void> _openApplication(Map<String, dynamic> app) async {
    final appId = app['id']?.toString();
    if (appId != null && appId.isNotEmpty) {
      try {
        await context.read<AdminApplicationsProvider>().markApplicationSeen(appId);
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => AdminApplicationPaymentsProvider(),
          child: AdminApplicationDetailScreen(application: app),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminApplicationsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.applications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          provider.error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: provider.loadApplications,
                          child: const Text('Recharger'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        final allApplications = provider.applications;
        final applications = _onlyDiscountRequested
            ? allApplications
                .where((app) => app['discount_requested'] == true)
                .toList()
            : allApplications;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isCompact = width < AppBreakpoints.mobile;
            // Marges fluides : proportionnelles à la largeur réelle du
            // conteneur parent, jamais figées.
            final horizontalPadding = isCompact
                ? 12.0
                : math.min(32.0, math.max(16.0, width * 0.03));
            // Sur très grand écran, on limite la largeur de lecture.
            const maxContentWidth = 1100.0;

            final filterBar = Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                4,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Avec demande de réduction'),
                    selected: _onlyDiscountRequested,
                    onSelected: (selected) {
                      setState(() => _onlyDiscountRequested = selected);
                    },
                  ),
                  Chip(
                    avatar: const Icon(Icons.assignment, size: 16),
                    label: Text('${applications.length} candidature(s)'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            );

            Widget listArea;
            if (applications.isEmpty) {
              listArea = LayoutBuilder(
                builder: (context, innerConstraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: innerConstraints.maxHeight),
                      child: const Center(
                        child: Text(
                          'Aucune candidature pour le moment.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                },
              );
            } else {
              listArea = ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  8,
                  horizontalPadding,
                  // Marge basse généreuse : la dernière carte reste
                  // atteignable au-dessus des barres système / FAB.
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                itemCount: applications.length,
                itemBuilder: (context, index) {
                  return _AdminApplicationCard(
                    application: applications[index],
                    isCompact: isCompact,
                    onTap: () => _openApplication(applications[index]),
                  );
                },
              );
            }

            return Column(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: maxContentWidth),
                    child: filterBar,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: maxContentWidth),
                      child: RefreshIndicator(
                        onRefresh: provider.loadApplications,
                        child: listArea,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Carte de candidature entièrement fluide.
///
/// On n'utilise plus `ListTile` : ses contraintes internes fixes coupaient le
/// sous-titre et les puces sur téléphone. Ici tout se replie naturellement.
class _AdminApplicationCard extends StatelessWidget {
  const _AdminApplicationCard({
    required this.application,
    required this.isCompact,
    required this.onTap,
  });

  final Map<String, dynamic> application;
  final bool isCompact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = application;
    final theme = Theme.of(context);

    final requestedDegree =
        (app['requested_degree_level']?.toString() ?? '').trim();
    final requestedMode =
        (app['requested_study_mode']?.toString() ?? '').trim();
    final requestedSchedule =
        (app['requested_schedule']?.toString() ?? '').trim();
    final discountRequested = app['discount_requested'] == true;
    final hasPreferences = requestedDegree.isNotEmpty ||
        requestedMode.isNotEmpty ||
        requestedSchedule.isNotEmpty ||
        discountRequested;

    final status = app['status']?.toString() ?? '';
    final lastMessageAt = app['last_message_at']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ligne de tête : icône + titre + statut.
              // Sur écran étroit le statut passe à la ligne suivante.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AdminApplicationLeading(application: app),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      app['program_title']?.toString() ?? 'Programme inconnu',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: 8),
                    _AdminStatusBadge(status: status),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.account_balance,
                text: app['university_name']?.toString() ?? '',
              ),
              _InfoLine(
                icon: Icons.person_outline,
                text: app['student_full_name']?.toString() ?? '',
              ),
              if (lastMessageAt.isNotEmpty)
                _InfoLine(
                  icon: Icons.schedule,
                  text: 'Dernier message : $lastMessageAt',
                ),
              if (hasPreferences) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (requestedDegree.isNotEmpty)
                      _CompactChip(label: 'Niveau : $requestedDegree'),
                    if (requestedMode.isNotEmpty)
                      _CompactChip(label: 'Mode : $requestedMode'),
                    if (requestedSchedule.isNotEmpty)
                      _CompactChip(label: 'Horaires : $requestedSchedule'),
                    if (discountRequested)
                      const _CompactChip(label: 'Demande de réduction'),
                  ],
                ),
              ],
              if (isCompact) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _AdminStatusBadge(status: status),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactChip extends StatelessWidget {
  const _CompactChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
      ),
    );
  }
}

class _AdminApplicationLeading extends StatelessWidget {
  final Map<String, dynamic> application;

  const _AdminApplicationLeading({required this.application});

  @override
  Widget build(BuildContext context) {
    final hasUnread = application['has_unread_for_admin'] == true;
    final hasUnseen = application['has_unseen_for_admin'] == true;
    final hasNotification = hasUnread || hasUnseen;
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.assignment, size: 22),
          if (hasNotification)
            Positioned(
              right: -1,
              top: -1,
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
    );
  }
}

class _AdminStatusBadge extends StatelessWidget {
  final String status;

  const _AdminStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = adminStatusLabel(status);
    final color = adminStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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

