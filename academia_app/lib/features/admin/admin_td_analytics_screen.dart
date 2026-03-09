import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../../services/td_service.dart';
import '../../theme/td_theme.dart';

/// Admin: TD Analytics dashboard + badges management
class AdminTdAnalyticsScreen extends StatefulWidget {
  const AdminTdAnalyticsScreen({super.key});

  @override
  State<AdminTdAnalyticsScreen> createState() => _AdminTdAnalyticsScreenState();
}

class _AdminTdAnalyticsScreenState extends State<AdminTdAnalyticsScreen> {
  final TdService _service = TdService();

  bool _loading = false;
  Map<String, dynamic> _analytics = {};
  List<Map<String, dynamic>> _badges = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.tdAdminGetAnalytics(),
        _service.tdAdminListBadges(),
      ]);
      _analytics = results[0];
      final badgeData = results[1];
      final list = badgeData['badges'];
      _badges = (list is List)
          ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } catch (e) {
      debugPrint('[AdminTdAnalytics] error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _analytics.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalStudents = _analytics['total_students'] as int? ?? 0;
    final activeEnrollments = _analytics['active_enrollments'] as int? ?? 0;
    final totalPrograms = _analytics['total_programs'] as int? ?? 0;
    final totalResources = _analytics['total_resources'] as int? ?? 0;
    final totalXp = _analytics['total_xp_distributed'] as int? ?? 0;
    final totalMessages = _analytics['total_messages'] as int? ?? 0;
    final pendingRequests = _analytics['pending_requests'] as int? ?? 0;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // ─── KPI Cards ─────────────────────────────────────────
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: TdTheme.gradientCard(TdTheme.adminTdGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text('Analytics TD',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _KpiChip(icon: Icons.people, label: 'Étudiants', value: '$totalStudents'),
                      _KpiChip(icon: Icons.school, label: 'Inscrits actifs', value: '$activeEnrollments'),
                      _KpiChip(icon: Icons.menu_book, label: 'Programmes', value: '$totalPrograms'),
                      _KpiChip(icon: Icons.folder, label: 'Ressources', value: '$totalResources'),
                      _KpiChip(icon: Icons.bolt, label: 'XP distribué', value: '$totalXp'),
                      _KpiChip(icon: Icons.chat, label: 'Messages', value: '$totalMessages'),
                      _KpiChip(
                        icon: Icons.pending_actions,
                        label: 'Demandes',
                        value: '$pendingRequests',
                        highlight: pendingRequests > 0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Recent XP activity ────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 350),
            child: _buildRecentXpSection(),
          ),
          const SizedBox(height: 20),

          // ─── Grant XP section ──────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            duration: const Duration(milliseconds: 350),
            child: _buildGrantXpSection(),
          ),
          const SizedBox(height: 20),

          // ─── Leaderboard view ──────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            duration: const Duration(milliseconds: 350),
            child: _buildLeaderboardSection(),
          ),
          const SizedBox(height: 20),

          // ─── Badges management ─────────────────────────────────
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            duration: const Duration(milliseconds: 350),
            child: _buildBadgesSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentXpSection() {
    final recentXp = _analytics['recent_xp'];
    final days = (recentXp is List)
        ? recentXp.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: TdTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: TdTheme.adminTdPrimary, size: 20),
              SizedBox(width: 8),
              Text('Activité XP (7 derniers jours)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TdTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          if (days.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('Aucune activité XP cette semaine.',
                    style: TextStyle(fontSize: 12, color: TdTheme.textTertiary)),
              ),
            )
          else
            ...days.map((d) {
              final date = d['date']?.toString() ?? '';
              final xp = d['total_xp'] as int? ?? 0;
              final students = d['unique_students'] as int? ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        date.length >= 10 ? date.substring(0, 10) : date,
                        style: const TextStyle(fontSize: 11, color: TdTheme.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: TdTheme.progressBar(
                        value: xp > 0 ? (xp / 500).clamp(0.0, 1.0) : 0,
                        color: TdTheme.adminTdPrimary,
                        height: 8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$xp XP',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: TdTheme.adminTdPrimary)),
                    const SizedBox(width: 6),
                    Text('($students étud.)',
                        style: const TextStyle(fontSize: 10, color: TdTheme.textTertiary)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBadgesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: TdTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: TdTheme.adminTdPrimary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Badges TD',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TdTheme.textPrimary)),
              ),
              TextButton.icon(
                onPressed: _showCreateBadgeDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Créer', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_badges.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('Aucun badge configuré.',
                    style: TextStyle(fontSize: 12, color: TdTheme.textTertiary)),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _badges.map((b) {
                final emoji = b['emoji']?.toString() ?? '🏆';
                final title = b['title']?.toString() ?? '';
                final earnedCount = b['earned_count'] as int? ?? 0;
                final isActive = b['is_active'] == true;
                return GestureDetector(
                  onTap: () => _showEditBadgeDialog(b),
                  child: Container(
                    width: 100,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isActive ? TdTheme.cardBg : TdTheme.divider.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(TdTheme.radiusMd),
                      border: Border.all(color: TdTheme.divider),
                    ),
                    child: Column(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isActive ? TdTheme.textPrimary : TdTheme.textTertiary,
                            )),
                        const SizedBox(height: 2),
                        Text('$earnedCount débloqué${earnedCount > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 9, color: TdTheme.textTertiary)),
                        if (!isActive)
                          const Text('(désactivé)',
                              style: TextStyle(fontSize: 8, color: TdTheme.error)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildGrantXpSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: TdTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Attribuer des XP',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TdTheme.textPrimary)),
              ),
              ElevatedButton.icon(
                onPressed: _showGrantXpDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Attribuer', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Attribue manuellement des XP à un étudiant (récompense, bonus, rattrapage).',
            style: TextStyle(fontSize: 12, color: TdTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardSection() {
    final topPrograms = _analytics['top_programs'];
    final programs = (topPrograms is List)
        ? topPrograms.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: TdTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.leaderboard, color: TdTheme.adminTdPrimary, size: 20),
              SizedBox(width: 8),
              Text('Top programmes TD',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TdTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          if (programs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('Aucun programme avec des inscriptions.',
                    style: TextStyle(fontSize: 12, color: TdTheme.textTertiary)),
              ),
            )
          else
            ...programs.take(5).toList().asMap().entries.map((e) {
              final i = e.key;
              final p = e.value;
              final title = p['title']?.toString() ?? '';
              final fieldName = p['field_name']?.toString() ?? '';
              final count = p['enrollment_count'] as int? ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: i < 3 ? TdTheme.adminTdPrimary.withOpacity(0.12) : TdTheme.divider,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: i < 3 ? TdTheme.adminTdPrimary : TdTheme.textTertiary,
                            )),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (fieldName.isNotEmpty)
                            Text(fieldName,
                                style: const TextStyle(fontSize: 10, color: TdTheme.textTertiary)),
                        ],
                      ),
                    ),
                    Text('$count inscrits',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: TdTheme.adminTdPrimary)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showGrantXpDialog() async {
    final studentIdCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '50');
    final reasonCtrl = TextEditingController(text: 'admin_grant');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Attribuer des XP'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: studentIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'ID étudiant (UUID) *',
                  border: OutlineInputBorder(),
                  hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant XP *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Raison',
                  border: OutlineInputBorder(),
                  hintText: 'admin_grant, bonus, rattrapage...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            child: const Text('Attribuer'),
          ),
        ],
      ),
    );

    if (result != true) return;
    final studentId = studentIdCtrl.text.trim();
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    if (studentId.isEmpty || amount <= 0) return;

    try {
      await _service.tdAdminGrantXp(
        studentId: studentId,
        amount: amount,
        reason: reasonCtrl.text.trim().isEmpty ? 'admin_grant' : reasonCtrl.text.trim(),
      );
      _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$amount XP attribués.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _showEditBadgeDialog(Map<String, dynamic> badge) async {
    final code = badge['code']?.toString() ?? '';
    final titleCtrl = TextEditingController(text: badge['title']?.toString() ?? '');
    final emojiCtrl = TextEditingController(text: badge['emoji']?.toString() ?? '🏆');
    final xpCtrl = TextEditingController(text: '${badge['xp_reward'] ?? 0}');
    bool isActive = badge['is_active'] == true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('Modifier badge « $code »'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titre *')),
                const SizedBox(height: 8),
                TextField(controller: emojiCtrl, decoration: const InputDecoration(labelText: 'Emoji')),
                const SizedBox(height: 8),
                TextField(
                  controller: xpCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'XP récompense'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: isActive,
                      onChanged: (v) => setStateDialog(() => isActive = v ?? true),
                    ),
                    const Text('Badge actif'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );

    if (result != true) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;

    try {
      await _service.tdAdminUpsertBadge(
        code: code,
        title: title,
        emoji: emojiCtrl.text.trim().isEmpty ? null : emojiCtrl.text.trim(),
        xpReward: int.tryParse(xpCtrl.text.trim()) ?? 0,
        isActive: isActive,
      );
      _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Badge mis à jour.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _showCreateBadgeDialog() async {
    final codeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '🏆');
    final xpCtrl = TextEditingController(text: '50');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Créer un badge TD'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code unique *')),
              const SizedBox(height: 8),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titre *')),
              const SizedBox(height: 8),
              TextField(controller: emojiCtrl, decoration: const InputDecoration(labelText: 'Emoji')),
              const SizedBox(height: 8),
              TextField(
                controller: xpCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'XP récompense'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer')),
        ],
      ),
    );

    if (result != true) return;
    final code = codeCtrl.text.trim();
    final title = titleCtrl.text.trim();
    if (code.isEmpty || title.isEmpty) return;

    try {
      await _service.tdAdminUpsertBadge(
        code: code,
        title: title,
        emoji: emojiCtrl.text.trim().isEmpty ? null : emojiCtrl.text.trim(),
        xpReward: int.tryParse(xpCtrl.text.trim()) ?? 0,
      );
      _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Badge créé.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
}

class _KpiChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _KpiChip({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text(label,
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
