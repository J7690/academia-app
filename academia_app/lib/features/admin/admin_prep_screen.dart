import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../../services/td_service.dart';
import '../../theme/prep_theme.dart';

/// Écran admin — Gestion banques de questions, modération IA, badges, stats.
class AdminPrepScreen extends StatefulWidget {
  const AdminPrepScreen({super.key});

  @override
  State<AdminPrepScreen> createState() => _AdminPrepScreenState();
}

class _AdminPrepScreenState extends State<AdminPrepScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TdService _service = TdService();

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _aiConversations = [];
  Map<String, dynamic> _aiConfig = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.prepAdminGetStats(),
        _service.prepAdminListQuestions(limit: 50),
        _service.prepAdminListAiConversations(limit: 30),
        _service.prepGetAiConfig(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _questions = results[1] as List<Map<String, dynamic>>;
        _aiConversations = results[2] as List<Map<String, dynamic>>;
        _aiConfig = results[3] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrepTheme.scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Préparation — Admin',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [PrepTheme.xpPurple, PrepTheme.xpPurpleLight]),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard, size: 18), text: 'Dashboard'),
            Tab(icon: Icon(Icons.quiz, size: 18), text: 'Questions'),
            Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'IA Config'),
            Tab(icon: Icon(Icons.emoji_events, size: 18), text: 'Badges'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PrepTheme.xpPurple))
          : TabBarView(
              controller: _tabController,
              children: [
                _DashboardTab(stats: _stats, onRefresh: _loadData),
                _QuestionsAdminTab(
                  questions: _questions,
                  service: _service,
                  onRefresh: _loadData,
                ),
                _AiConfigTab(
                  config: _aiConfig,
                  conversations: _aiConversations,
                  service: _service,
                  onRefresh: _loadData,
                ),
                _BadgesTab(
                  badges: (_stats['badges_config'] as List<dynamic>?)
                          ?.map((b) => Map<String, dynamic>.from(b as Map))
                          .toList() ??
                      [],
                  service: _service,
                  onRefresh: _loadData,
                ),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 1: Dashboard — Stats globales
// ═══════════════════════════════════════════════════════════════════
class _DashboardTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  final VoidCallback onRefresh;

  const _DashboardTab({required this.stats, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: PrepTheme.xpPurple,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: PrepTheme.gradientBox([PrepTheme.xpPurple, PrepTheme.xpPurpleLight], radius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                      SizedBox(width: 10),
                      Text('Vue d\'ensemble',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatBadge('Questions', '${stats['total_questions'] ?? 0}', Icons.quiz),
                      _StatBadge('Banques', '${stats['total_banks'] ?? 0}', Icons.folder),
                      _StatBadge('Quiz passés', '${stats['total_quiz_attempts'] ?? 0}', Icons.check_circle),
                      _StatBadge('Étudiants', '${stats['total_students_active'] ?? 0}', Icons.people),
                      _StatBadge('Flashcards', '${stats['total_flashcard_decks'] ?? 0}', Icons.style),
                      _StatBadge('Sujets', '${stats['total_exam_papers'] ?? 0}', Icons.description),
                      _StatBadge('Conv. IA', '${stats['total_ai_conversations'] ?? 0}', Icons.auto_awesome),
                      _StatBadge('Msg IA', '${stats['total_ai_messages'] ?? 0}', Icons.message),
                    ],
                  ),
                  if (stats['avg_score'] != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.trending_up, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Score moyen: ${stats['avg_score']}%',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatBadge(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              Text(label,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 2: Questions Admin — Modération
// ═══════════════════════════════════════════════════════════════════
class _QuestionsAdminTab extends StatelessWidget {
  final List<Map<String, dynamic>> questions;
  final TdService service;
  final VoidCallback onRefresh;

  const _QuestionsAdminTab({required this.questions, required this.service, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        Text('${questions.length} question(s)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: PrepTheme.textPrimary)),
        const SizedBox(height: 10),
        if (questions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.quiz, size: 40, color: PrepTheme.textTertiary),
                SizedBox(height: 8),
                Text('Aucune question', style: TextStyle(color: PrepTheme.textTertiary)),
              ],
            ),
          )
        else
          ...questions.asMap().entries.map((e) {
            final q = e.value;
            final isActive = q['is_active'] == true;
            return FadeInUp(
              delay: Duration(milliseconds: 30 * e.key),
              duration: const Duration(milliseconds: 300),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: PrepTheme.cardBox(
                  borderColor: isActive ? null : PrepTheme.danger.withOpacity(0.3),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q['content']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isActive ? PrepTheme.textPrimary : PrepTheme.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (q['bank_title'] != null)
                                PrepTheme.chip(q['bank_title'].toString(), PrepTheme.primary),
                              if (q['subject'] != null)
                                PrepTheme.chip(q['subject'].toString(), PrepTheme.success),
                              PrepTheme.chip('Diff. ${q['difficulty'] ?? 1}', PrepTheme.accent),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isActive ? Icons.visibility : Icons.visibility_off,
                        color: isActive ? PrepTheme.success : PrepTheme.danger,
                        size: 20,
                      ),
                      onPressed: () async {
                        try {
                          await service.prepAdminToggleQuestion(
                            q['id'].toString(),
                            !isActive,
                          );
                          onRefresh();
                        } catch (err) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur: $err')),
                            );
                          }
                        }
                      },
                      tooltip: isActive ? 'Désactiver' : 'Activer',
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 3: AI Config — Configuration IA + Modération conversations
// ═══════════════════════════════════════════════════════════════════
class _AiConfigTab extends StatelessWidget {
  final Map<String, dynamic> config;
  final List<Map<String, dynamic>> conversations;
  final TdService service;
  final VoidCallback onRefresh;

  const _AiConfigTab({
    required this.config,
    required this.conversations,
    required this.service,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // ─── Config section ──────────────────────────────────────
        FadeInDown(
          duration: const Duration(milliseconds: 350),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: PrepTheme.cardBox(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.settings, color: PrepTheme.xpPurple, size: 20),
                    SizedBox(width: 10),
                    Text('Configuration IA',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                // OpenRouter status (shared with Bobodo — env var côté serveur)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PrepTheme.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: PrepTheme.success.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: PrepTheme.success, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('OpenRouter (même clé que Bobodo)',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PrepTheme.success)),
                            SizedBox(height: 2),
                            Text(
                              'Clé API côté serveur (env var Supabase). Aucune config nécessaire.',
                              style: TextStyle(fontSize: 11, color: PrepTheme.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20),
                _ConfigRow(
                  label: 'Messages max/jour',
                  value: config['max_messages_per_day']?.toString() ?? '50',
                  onEdit: () => _editConfig(context, 'max_messages_per_day', 'Messages max/jour',
                      config['max_messages_per_day']?.toString() ?? '50'),
                ),
                const Divider(height: 20),
                _ConfigRow(
                  label: 'Prompt système',
                  value: (config['system_prompt']?.toString() ?? '').length > 60
                      ? '${config['system_prompt'].toString().substring(0, 60)}…'
                      : config['system_prompt']?.toString() ?? '',
                  onEdit: () => _editConfig(context, 'system_prompt', 'Prompt système',
                      config['system_prompt']?.toString() ?? '', multiline: true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ─── Conversations IA ────────────────────────────────────
        FadeInUp(
          delay: const Duration(milliseconds: 100),
          duration: const Duration(milliseconds: 350),
          child: const Text('Conversations IA récentes',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: PrepTheme.textPrimary)),
        ),
        const SizedBox(height: 10),
        if (conversations.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.chat_bubble_outline, size: 40, color: PrepTheme.textTertiary),
                SizedBox(height: 8),
                Text('Aucune conversation IA', style: TextStyle(color: PrepTheme.textTertiary)),
              ],
            ),
          )
        else
          ...conversations.asMap().entries.map((e) {
            final conv = e.value;
            return FadeInUp(
              delay: Duration(milliseconds: 40 * e.key),
              duration: const Duration(milliseconds: 300),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: PrepTheme.cardBox(),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: PrepTheme.aiGradient),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conv['student_name']?.toString() ?? 'Étudiant',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${conv['message_count'] ?? 0} messages · ${conv['total_tokens_used'] ?? 0} tokens',
                            style: const TextStyle(fontSize: 11, color: PrepTheme.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    if (conv['subject'] != null)
                      PrepTheme.chip(conv['subject'].toString(), PrepTheme.xpPurple),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _editConfig(BuildContext context, String key, String label, String currentValue,
      {bool multiline = false}) {
    final ctrl = TextEditingController(text: currentValue);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Modifier: $label', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          maxLines: multiline ? 6 : 1,
          obscureText: key == 'gemini_api_key',
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: PrepTheme.xpPurple),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await service.prepUpdateAiConfig(key, ctrl.text.trim());
                onRefresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Configuration mise à jour ✓')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              }
            },
            child: const Text('Sauvegarder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isSecret;
  final VoidCallback onEdit;

  const _ConfigRow({
    required this.label,
    required this.value,
    this.isSecret = false,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PrepTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(
                isSecret
                    ? (value.isEmpty ? '(non configuré)' : '••••••••${value.length > 8 ? value.substring(value.length - 4) : ''}')
                    : (value.isEmpty ? '(non configuré)' : value),
                style: TextStyle(
                  fontSize: 13,
                  color: value.isEmpty ? PrepTheme.textTertiary : PrepTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 18, color: PrepTheme.xpPurple),
          onPressed: onEdit,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab 4: Badges — Gestion des badges
// ═══════════════════════════════════════════════════════════════════
class _BadgesTab extends StatelessWidget {
  final List<Map<String, dynamic>> badges;
  final TdService service;
  final VoidCallback onRefresh;

  const _BadgesTab({required this.badges, required this.service, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        FadeInDown(
          duration: const Duration(milliseconds: 350),
          child: GestureDetector(
            onTap: () => _showCreateBadgeDialog(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PrepTheme.accentSurface,
                borderRadius: BorderRadius.circular(PrepTheme.radiusMd),
                border: Border.all(color: PrepTheme.accent.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_circle, color: PrepTheme.accent, size: 22),
                  SizedBox(width: 10),
                  Text('Créer un badge',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: PrepTheme.accent)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (badges.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.emoji_events, size: 40, color: PrepTheme.textTertiary),
                SizedBox(height: 8),
                Text('Aucun badge configuré', style: TextStyle(color: PrepTheme.textTertiary)),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.3,
            ),
            itemCount: badges.length,
            itemBuilder: (context, index) {
              final badge = badges[index];
              return FadeInUp(
                delay: Duration(milliseconds: 40 * index),
                duration: const Duration(milliseconds: 350),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: PrepTheme.cardBox(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(badge['emoji']?.toString() ?? '🏅', style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        badge['title']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${badge['xp_reward'] ?? 0} XP · ${badge['condition_type'] ?? ''}: ${badge['condition_value'] ?? 0}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, color: PrepTheme.textTertiary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showCreateBadgeDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final emojiCtrl = TextEditingController();
    int xpReward = 0;
    String? conditionType;
    int conditionValue = 0;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nouveau badge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code unique *', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titre *', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: emojiCtrl, decoration: const InputDecoration(labelText: 'Emoji (ex: 🏆)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(labelText: 'XP Récompense', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => xpReward = int.tryParse(v) ?? 0,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: conditionType,
                  decoration: const InputDecoration(labelText: 'Type de condition', border: OutlineInputBorder()),
                  items: ['streak', 'correct_count', 'quiz_count', 'xp', 'perfect_score']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => conditionType = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(labelText: 'Valeur condition', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => conditionValue = int.tryParse(v) ?? 0,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: PrepTheme.accent),
              onPressed: () async {
                if (codeCtrl.text.trim().isEmpty || titleCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  await service.prepAdminUpsertBadge(
                    code: codeCtrl.text.trim(),
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    emoji: emojiCtrl.text.trim().isEmpty ? null : emojiCtrl.text.trim(),
                    xpReward: xpReward,
                    conditionType: conditionType,
                    conditionValue: conditionValue,
                  );
                  onRefresh();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                }
              },
              child: const Text('Créer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
