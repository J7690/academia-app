import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';

import '../../../providers/td_gamification_provider.dart';
import '../../../theme/td_theme.dart';

/// Onglet Ressources — Vidéos, PDF, contenus interactifs par TD
class TdResourcesTab extends StatefulWidget {
  const TdResourcesTab({super.key});

  @override
  State<TdResourcesTab> createState() => _TdResourcesTabState();
}

class _TdResourcesTabState extends State<TdResourcesTab> {
  String? _selectedProgramId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TdGamificationProvider>().loadResources();
    });
  }

  void _filterByProgram(String? programId) {
    setState(() => _selectedProgramId = programId);
    context.read<TdGamificationProvider>().loadResources(programId: programId);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TdGamificationProvider>();
    final activeEnrollments = p.enrollments.where((e) => e['access_status'] == 'active').toList();

    return Column(
      children: [
        // ─── Program filter ──────────────────────────────────────
        if (activeEnrollments.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildFilterChip('Tout', _selectedProgramId == null, () => _filterByProgram(null)),
                ...activeEnrollments.map((e) {
                  final pid = e['program_id']?.toString();
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _buildFilterChip(
                      e['program_title']?.toString() ?? 'TD',
                      _selectedProgramId == pid,
                      () => _filterByProgram(pid),
                    ),
                  );
                }),
              ],
            ),
          ),

        // ─── Resources list ──────────────────────────────────────
        Expanded(
          child: p.resourcesLoading
              ? const Center(child: CircularProgressIndicator())
              : p.resources.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open, size: 56, color: TdTheme.textTertiary.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          const Text('Aucune ressource disponible',
                              style: TextStyle(fontSize: 14, color: TdTheme.textSecondary)),
                          const SizedBox(height: 4),
                          const Text('Les enseignants ajouteront des ressources bientôt.',
                              style: TextStyle(fontSize: 12, color: TdTheme.textTertiary)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => p.loadResources(programId: _selectedProgramId),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: p.resources.length,
                        itemBuilder: (context, index) {
                          return FadeInUp(
                            delay: Duration(milliseconds: 30 * index),
                            duration: const Duration(milliseconds: 300),
                            child: _ResourceCard(resource: p.resources[index]),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? TdTheme.studentTdPrimary : TdTheme.studentTdPrimary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? TdTheme.studentTdPrimary : TdTheme.studentTdPrimary.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : TdTheme.studentTdPrimary,
          ),
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final Map<String, dynamic> resource;

  const _ResourceCard({required this.resource});

  @override
  Widget build(BuildContext context) {
    final title = resource['title']?.toString() ?? '';
    final description = resource['description']?.toString() ?? '';
    final kind = resource['kind']?.toString() ?? 'document';
    final progress = resource['progress'] as Map<String, dynamic>?;
    final status = progress?['status']?.toString() ?? 'not_started';
    final pct = (progress?['progress_pct'] as int? ?? 0) / 100.0;
    final durationSec = resource['duration_seconds'] as int?;

    final (icon, color) = _kindInfo(kind);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: TdTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(TdTheme.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(TdTheme.radiusLg),
          onTap: () {
            // TODO: Open resource (video player, PDF viewer, etc.)
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (description.isNotEmpty)
                        Text(description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: TdTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          TdTheme.statusBadge(_kindLabel(kind), color),
                          if (durationSec != null) ...[
                            const SizedBox(width: 6),
                            Text(_formatDuration(durationSec),
                                style: const TextStyle(fontSize: 10, color: TdTheme.textTertiary)),
                          ],
                          if (status == 'completed') ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_circle, size: 14, color: TdTheme.success),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (status != 'not_started' && status != 'completed')
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: pct,
                          strokeWidth: 3,
                          backgroundColor: color.withOpacity(0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                        Text('${(pct * 100).toInt()}',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                      ],
                    ),
                  )
                else
                  Icon(
                    status == 'completed' ? Icons.check_circle : Icons.play_circle_outline,
                    color: status == 'completed' ? TdTheme.success : color,
                    size: 28,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (IconData, Color) _kindInfo(String kind) {
    switch (kind) {
      case 'video':
        return (Icons.play_circle_filled, const Color(0xFFEF4444));
      case 'pdf':
      case 'document':
        return (Icons.picture_as_pdf, const Color(0xFFEA580C));
      case 'audio':
        return (Icons.headphones, const Color(0xFF7C3AED));
      case 'link':
        return (Icons.link, const Color(0xFF0891B2));
      case 'exercise':
        return (Icons.edit_note, const Color(0xFF059669));
      default:
        return (Icons.insert_drive_file, TdTheme.studentTdPrimary);
    }
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'video':
        return 'Vidéo';
      case 'pdf':
        return 'PDF';
      case 'document':
        return 'Document';
      case 'audio':
        return 'Audio';
      case 'link':
        return 'Lien';
      case 'exercise':
        return 'Exercice';
      default:
        return kind;
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m >= 60) {
      return '${m ~/ 60}h${(m % 60).toString().padLeft(2, '0')}';
    }
    return '${m}m${s.toString().padLeft(2, '0')}';
  }
}
