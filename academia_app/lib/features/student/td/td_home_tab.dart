import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/td_gamification_provider.dart';
import '../../../theme/td_theme.dart';
import '../../../widgets/bobodo_state.dart';
import '../../../widgets/bobodo_view.dart';

void _showRequestTeacherSheet(BuildContext context) {
  final subjectCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String? level;
  String? modality;

  const levels = ['L1', 'L2', 'L3', 'M1', 'M2', 'BTS', 'Terminale'];
  const modalities = ['Présentiel', 'En ligne', 'Les deux'];

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Demander un enseignant humain', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Un enseignant sera assigné pour vous accompagner', style: TextStyle(fontSize: 12, color: Color(0xFF757575))),
          const SizedBox(height: 16),
          TextField(
            controller: subjectCtrl,
            decoration: const InputDecoration(labelText: 'Matière souhaitée *', hintText: 'Ex: Mathématiques, Droit Civil...', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              value: level, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Niveau', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setS(() => level = v),
            )),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(
              value: modality, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Modalité', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: modalities.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setS(() => modality = v),
            )),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: descCtrl, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Détails (optionnel)', hintText: 'Décrivez vos besoins...', border: OutlineInputBorder(), alignLabelWithHint: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () async {
              final subject = subjectCtrl.text.trim();
              if (subject.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await Supabase.instance.client.rpc('app_td_student_create_request', params: {
                  'p_subject': subject,
                  if (level != null) 'p_level': level,
                  if (descCtrl.text.trim().isNotEmpty) 'p_description': descCtrl.text.trim(),
                  if (modality != null) 'p_preferred_modality': modality,
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Demande envoyée ! Un enseignant sera bientôt assigné.'),
                    backgroundColor: Color(0xFF059669),
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
                }
              }
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Envoyer la demande'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
        ]),
      ),
    ),
  );
}

/// Onglet Accueil — Dashboard gamifié (inspiré Duolingo + Brilliant)
class TdHomeTab extends StatelessWidget {
  const TdHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TdGamificationProvider>();

    if (p.homeLoading && p.totalXp == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: p.loadHome,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // ─── Streak + XP hero card ─────────────────────────────
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: TdTheme.gradientCard(TdTheme.studentTdGradient),
              child: Column(
                children: [
                  Row(
                    children: [
                      const BobodoView(state: BobodoState.success, size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.currentStreak > 0
                                  ? '🔥 ${p.currentStreak} jour${p.currentStreak > 1 ? 's' : ''} de suite !'
                                  : 'Commence ta série !',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Niveau ${p.level} • ${p.totalXp} XP',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TdTheme.streakBadge(p.currentStreak),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Daily goal progress
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Objectif du jour',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${p.dailyGoalEarned}/${p.dailyGoalTarget} XP',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 8,
                          child: LinearProgressIndicator(
                            value: p.dailyGoalTarget > 0
                                ? (p.dailyGoalEarned / p.dailyGoalTarget).clamp(0.0, 1.0)
                                : 0,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              p.dailyGoalCompleted ? const Color(0xFF22C55E) : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── KPI row ───────────────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 350),
            child: Row(
              children: [
                TdTheme.kpiCard(
                  icon: Icons.school,
                  value: '${p.activeEnrollments}',
                  label: 'TD actifs',
                  color: TdTheme.studentTdPrimary,
                ),
                const SizedBox(width: 10),
                TdTheme.kpiCard(
                  icon: Icons.bolt,
                  value: '${p.totalXp}',
                  label: 'XP total',
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 10),
                TdTheme.kpiCard(
                  icon: Icons.local_fire_department,
                  value: '${p.longestStreak}',
                  label: 'Record',
                  color: const Color(0xFFEF4444),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── Next session card ─────────────────────────────────
          if (p.nextSession != null)
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 350),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TdTheme.success.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(TdTheme.radiusLg),
                  border: Border.all(color: TdTheme.success.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: TdTheme.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event, color: TdTheme.success, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Prochaine séance',
                              style: TextStyle(fontSize: 11, color: TdTheme.textSecondary)),
                          Text(
                            p.nextSession!['program_title']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: TdTheme.textPrimary,
                            ),
                          ),
                          if (p.nextSession!['scheduled_at'] != null)
                            Text(
                              TdTheme.formatDateTime(p.nextSession!['scheduled_at'].toString()),
                              style: const TextStyle(fontSize: 12, color: TdTheme.success),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: TdTheme.success, size: 20),
                  ],
                ),
              ),
            ),
          if (p.nextSession != null) const SizedBox(height: 16),

          // ─── Quick actions ─────────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            duration: const Duration(milliseconds: 350),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Actions rapides',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TdTheme.textPrimary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Flexible(child: _QuickAction(
                      icon: Icons.explore,
                      label: 'Explorer',
                      color: TdTheme.studentTdPrimary,
                      onTap: () => DefaultTabController.of(context).animateTo(1),
                    )),
                    Flexible(child: _QuickAction(
                      icon: Icons.menu_book,
                      label: 'Mes TD',
                      color: TdTheme.success,
                      onTap: () => DefaultTabController.of(context).animateTo(2),
                    )),
                    Flexible(child: _QuickAction(
                      icon: Icons.leaderboard,
                      label: 'Classement',
                      color: const Color(0xFFF59E0B),
                      onTap: () => DefaultTabController.of(context).animateTo(4),
                    )),
                    Flexible(child: _QuickAction(
                      icon: Icons.bar_chart,
                      label: 'Stats',
                      color: const Color(0xFFEF4444),
                      onTap: () => DefaultTabController.of(context).animateTo(5),
                    )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Request a human teacher ─────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 350),
            duration: const Duration(milliseconds: 350),
            child: GestureDetector(
              onTap: () => _showRequestTeacherSheet(context),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)]),
                  borderRadius: BorderRadius.circular(TdTheme.radiusLg),
                  boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withAlpha(40), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.person_search, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Demander un enseignant', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Un prof humain pour ta matière', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ])),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Active enrollments preview ────────────────────────
          if (p.enrollments.isNotEmpty)
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              duration: const Duration(milliseconds: 350),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mes TD en cours',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: TdTheme.textPrimary)),
                      TextButton(
                        onPressed: () => DefaultTabController.of(context).animateTo(2),
                        child: const Text('Voir tout'),
                      ),
                    ],
                  ),
                  ...p.enrollments.where((e) => e['access_status'] == 'active').take(3).map((e) {
                    final fieldColor = TdTheme.colorFromHex(e['field_color']?.toString());
                    final pct = (e['progress_pct'] as int? ?? 0) / 100.0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: TdTheme.cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: fieldColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.menu_book, color: fieldColor, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e['program_title']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                    ),
                                    if (e['field_name'] != null)
                                      Text(
                                        e['field_name'].toString(),
                                        style: TextStyle(fontSize: 11, color: fieldColor),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '${(pct * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: fieldColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TdTheme.progressBar(value: pct, color: fieldColor),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(TdTheme.radiusMd),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
