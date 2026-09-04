import 'package:flutter/material.dart';

import '../../widgets/bouton_deconnexion.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/commercial_dashboard_provider.dart';
import '../../widgets/support_fab.dart';
import '../student/student_settings_screen.dart';
import '../../services/push_trigger_service.dart';
import '../../services/share_tracking_service.dart';
import '../../services/analytics_tracking_service.dart';

class CommercialDashboardScreen extends StatefulWidget {
  const CommercialDashboardScreen({super.key});

  @override
  State<CommercialDashboardScreen> createState() =>
      _CommercialDashboardScreenState();
}

class _CommercialDashboardScreenState extends State<CommercialDashboardScreen> {

  @override
  void initState() {
    super.initState();
    AnalyticsTrackingService.instance.init();
    AnalyticsTrackingService.instance.trackScreen('commercial_dashboard');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CommercialDashboardProvider>().loadDashboard();
      PushTriggerService.instance.triggerPendingPush();
    });
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0';
    if (amount is num) {
      return amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
    }
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommercialDashboardProvider>();
    final profile = provider.profile;
    final summary = provider.summary;

    Widget body;

    if (provider.isLoading && profile == null && summary == null) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 2));
    } else if (provider.error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(provider.error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed:
                    provider.isLoading ? null : () => provider.loadDashboard(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    } else if (profile == null || summary == null) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Aucune donnée commerciale disponible.',
              textAlign: TextAlign.center),
        ),
      );
    } else {
      body = _CommercialTabBody(
        profile: profile,
        summary: summary,
        referrals: provider.referrals,
        commissions: provider.commissions,
        prospectPayments: provider.prospectPayments,
        gamification: provider.gamification ?? {},
        leaderboard: provider.leaderboard,
        formatDate: _formatDate,
        formatAmount: _formatAmount,
        onShare: (link) => _showShareReferralDialog(context, link),
        onRefresh: () => provider.loadDashboard(),
        onClaimMilestone: (id) => provider.claimMilestone(id),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        floatingActionButton: const SupportFab(),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: const Text('Espace Commercial',
              style: TextStyle(fontWeight: FontWeight.w600)),
          foregroundColor: Colors.white,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualiser',
              onPressed: () => provider.loadDashboard(),
            ),
            // Hors du menu « Options » : la déconnexion se voit, elle ne se
            // cherche pas. Elle reste aussi dans les paramètres.
            const BoutonDeconnexion(),
            PopupMenuButton<_CommercialDashboardMenuAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Options',
              onSelected: (value) {
                switch (value) {
                  case _CommercialDashboardMenuAction.changePassword:
                    _showCommercialChangePasswordDialog(context);
                    break;
                  case _CommercialDashboardMenuAction.settings:
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StudentSettingsScreen(
                          showProfile: false,
                        ),
                      ),
                    );
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_CommercialDashboardMenuAction>(
                  value: _CommercialDashboardMenuAction.changePassword,
                  child: ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('Changer le mot de passe'),
                  ),
                ),
                PopupMenuItem<_CommercialDashboardMenuAction>(
                  value: _CommercialDashboardMenuAction.settings,
                  child: ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Paramètres'),
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined, size: 20), text: 'Accueil'),
              Tab(icon: Icon(Icons.people_outline, size: 20), text: 'Prospects'),
              Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 20), text: 'Finances'),
            ],
          ),
        ),
        body: body,
      ),
    );
  }

  Future<void> _showShareReferralDialog(
      BuildContext context, String link) async {
    final shareService = ShareTrackingService();
    final provider = context.read<CommercialDashboardProvider>();
    final profile = provider.profile;
    final refCode = profile?['ref_code']?.toString() ?? '';
    
    if (refCode.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code de parrainage non disponible.')),
      );
      return;
    }

    Future<void> launchShare(Uri uri) async {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Impossible d\'ouvrir l\'application.')),
        );
      }
    }

    Future<void> shareItem({
      required String shareSource,
      required String sharedItemType,
      String? sharedItemId,
      String? sharedItemTitle,
    }) async {
      final shareUrl = shareService.generateShareUrl(
        baseUrl: link,
        refCode: refCode,
        shareSource: shareSource,
        sharedItemType: sharedItemType,
        sharedItemId: sharedItemId,
        sharedItemTitle: sharedItemTitle,
      );
      
      final encodedLink = Uri.encodeComponent(shareUrl);
      final message = 'Rejoins Academia avec mon lien : $shareUrl';
      final encodedMessage = Uri.encodeComponent(message);

      switch (shareSource) {
        case 'whatsapp':
          await launchShare(Uri.parse('https://wa.me/?text=$encodedMessage'));
          break;
        case 'facebook':
          await launchShare(Uri.parse(
              'https://www.facebook.com/sharer/sharer.php?u=$encodedLink'));
          break;
        case 'twitter':
          await launchShare(Uri.parse(
              'https://twitter.com/intent/tweet?url=$encodedLink&text=$encodedMessage'));
          break;
        case 'linkedin':
          await launchShare(Uri.parse(
              'https://www.linkedin.com/sharing/share-offsite/?url=$encodedLink'));
          break;
        case 'telegram':
          await launchShare(Uri.parse(
              'https://t.me/share/url?url=$encodedLink&text=$encodedMessage'));
          break;
        case 'email':
          await launchShare(Uri.parse(
              'mailto:?subject=Rejoins Academia&body=$encodedMessage'));
          break;
        default:
          await launchShare(Uri.parse(shareUrl));
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Partager sur'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.chat, color: Colors.green),
                  title: const Text('WhatsApp'),
                  onTap: () async {
                    await shareItem(
                      shareSource: 'whatsapp',
                      sharedItemType: 'generic_landing',
                    );
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.facebook, color: Colors.blue),
                  title: const Text('Facebook'),
                  onTap: () async {
                    await shareItem(
                      shareSource: 'facebook',
                      sharedItemType: 'generic_landing',
                    );
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.purple),
                  title: const Text('Instagram'),
                  onTap: () async {
                    await shareItem(
                      shareSource: 'instagram',
                      sharedItemType: 'generic_landing',
                    );
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.alternate_email, color: Colors.blue),
                  title: const Text('Twitter / X'),
                  onTap: () async {
                    await shareItem(
                      shareSource: 'twitter',
                      sharedItemType: 'generic_landing',
                    );
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.work, color: Colors.blueAccent),
                  title: const Text('LinkedIn'),
                  onTap: () async {
                    await shareItem(
                      shareSource: 'linkedin',
                      sharedItemType: 'generic_landing',
                    );
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.send, color: Colors.blueAccent),
                  title: const Text('Telegram'),
                  onTap: () async {
                    await shareItem(
                      shareSource: 'telegram',
                      sharedItemType: 'generic_landing',
                    );
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: Colors.orange),
                  title: const Text('Email'),
                  onTap: () async {
                    await shareItem(
                      shareSource: 'email',
                      sharedItemType: 'generic_landing',
                    );
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sms, color: Colors.red),
                  title: const Text('SMS'),
                  onTap: () async {
                    await shareItem(
                      shareSource: 'sms',
                      sharedItemType: 'generic_landing',
                    );
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code, color: Colors.black),
                  title: const Text('Copier le lien'),
                  onTap: () async {
                    final shareUrl = shareService.generateShareUrl(
                      baseUrl: link,
                      refCode: refCode,
                      shareSource: 'direct_link',
                      sharedItemType: 'generic_landing',
                    );
                    await Clipboard.setData(ClipboardData(text: shareUrl));
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Lien copié dans le presse-papier')),
                      );
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab body — delegates to 3 tab views
// ---------------------------------------------------------------------------
class _CommercialTabBody extends StatelessWidget {
  final Map<String, dynamic> profile;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> referrals;
  final List<Map<String, dynamic>> commissions;
  final List<Map<String, dynamic>> prospectPayments;
  final Map<String, dynamic> gamification;
  final List<Map<String, dynamic>> leaderboard;
  final String Function(String) formatDate;
  final String Function(dynamic) formatAmount;
  final void Function(String) onShare;
  final VoidCallback onRefresh;
  final Future<bool> Function(String) onClaimMilestone;

  const _CommercialTabBody({
    required this.profile,
    required this.summary,
    required this.referrals,
    required this.commissions,
    required this.prospectPayments,
    required this.gamification,
    required this.leaderboard,
    required this.formatDate,
    required this.formatAmount,
    required this.onShare,
    required this.onRefresh,
    required this.onClaimMilestone,
  });

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: [
        _HomeTab(
          profile: profile,
          summary: summary,
          gamification: gamification,
          leaderboard: leaderboard,
          formatAmount: formatAmount,
          onShare: onShare,
        ),
        _ProspectsTab(
          referrals: referrals,
          formatDate: formatDate,
        ),
        _FinancesTab(
          summary: summary,
          commissions: commissions,
          prospectPayments: prospectPayments,
          gamification: gamification,
          leaderboard: leaderboard,
          formatDate: formatDate,
          formatAmount: formatAmount,
          onClaimMilestone: onClaimMilestone,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 1 — Accueil
// ---------------------------------------------------------------------------
class _HomeTab extends StatelessWidget {
  final Map<String, dynamic> profile;
  final Map<String, dynamic> summary;
  final Map<String, dynamic> gamification;
  final List<Map<String, dynamic>> leaderboard;
  final String Function(dynamic) formatAmount;
  final void Function(String) onShare;

  const _HomeTab({
    required this.profile,
    required this.summary,
    required this.gamification,
    required this.leaderboard,
    required this.formatAmount,
    required this.onShare,
  });

  static const _tierData = {
    'bronze':  ('Bronze',  Color(0xFFCD7F32), '\u{1F949}'),
    'silver':  ('Argent',  Color(0xFF9CA3AF), '\u{1F948}'),
    'gold':    ('Or',      Color(0xFFFBBF24), '\u{1F947}'),
    'diamond': ('Diamant', Color(0xFF60A5FA), '\u{1F48E}'),
  };

  @override
  Widget build(BuildContext context) {
    final refCode = (profile['ref_code'] ?? '').toString();
    final refLink = (profile['ref_link'] ?? '').toString();
    final currency = (summary['currency'] ?? 'XOF').toString();
    final prospectsCount = summary['prospects_count'] ?? 0;
    final prospectsWithApp = summary['prospects_with_application'] ?? 0;
    final paymentsConfirmed = summary['payments_confirmed_count'] ?? 0;
    final paymentsPending = summary['payments_pending_count'] ?? 0;
    final totalPending = summary['total_commission_pending'] ?? 0;
    final totalApproved = summary['total_commission_approved'] ?? 0;
    final totalPaid = summary['total_commission_paid'] ?? 0;

    final tier = (gamification['tier'] ?? 'bronze').toString();
    final tierInfo = _tierData[tier] ?? _tierData['bronze']!;
    final totalConfirmed = (gamification['total_confirmed_payments'] ?? 0);
    final nextTier = gamification['next_tier']?.toString();
    final nextThreshold = gamification['next_tier_threshold'];
    final maxCap = gamification['max_commissions_per_prospect'] ?? 3;

    double tierProgress = 0;
    if (nextThreshold != null && nextThreshold is num && nextThreshold > 0) {
      tierProgress = (totalConfirmed is num ? totalConfirmed.toDouble() : 0) / nextThreshold.toDouble();
      if (tierProgress > 1) tierProgress = 1;
    } else if (tier == 'diamond') {
      tierProgress = 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tier badge card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [tierInfo.$2.withOpacity(0.15), tierInfo.$2.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tierInfo.$2.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(tierInfo.$3, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rang ${tierInfo.$1}',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: tierInfo.$2)),
                          Text('$totalConfirmed commissions g\u00e9n\u00e9r\u00e9es',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text('Max $maxCap/prospect',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                    ),
                  ],
                ),
                if (nextTier != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: tierProgress,
                            minHeight: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(tierInfo.$2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$totalConfirmed / $nextThreshold',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tierInfo.$2),
                      ),
                    ],
                  ),
                  Text(
                    'Prochain rang : ${_tierData[nextTier]?.$1 ?? nextTier}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Referral link card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Votre lien de parrainage',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                if (refCode.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Code : $refCode',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                  ),
                if (refLink.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(refLink,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ActionChip(
                        icon: Icons.copy,
                        label: 'Copier',
                        onTap: () async {
                          await Clipboard.setData(
                              ClipboardData(text: refLink));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Lien copi\u00e9 !')),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        icon: Icons.share,
                        label: 'Partager',
                        onTap: () => onShare(refLink),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // KPI grid
          const Text('Vue d\'ensemble',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              _KpiCard(
                  icon: Icons.people,
                  label: 'Prospects',
                  value: prospectsCount.toString(),
                  color: const Color(0xFF2563EB)),
              const SizedBox(width: 10),
              _KpiCard(
                  icon: Icons.description,
                  label: 'Ont candidat\u00e9',
                  value: prospectsWithApp.toString(),
                  color: const Color(0xFF7C3AED)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _KpiCard(
                  icon: Icons.hourglass_top,
                  label: 'Paiements en cours',
                  value: paymentsPending.toString(),
                  color: const Color(0xFFEA580C)),
              const SizedBox(width: 10),
              _KpiCard(
                  icon: Icons.check_circle,
                  label: 'Paiements confirm\u00e9s',
                  value: paymentsConfirmed.toString(),
                  color: const Color(0xFF16A34A)),
            ],
          ),
          const SizedBox(height: 20),

          // Financial summary
          const Text('Solde commissions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                _FinanceRow(
                  label: 'En attente de validation',
                  amount: '${formatAmount(totalPending)} $currency',
                  color: const Color(0xFFEA580C),
                  icon: Icons.schedule,
                ),
                const Divider(height: 20),
                _FinanceRow(
                  label: 'Valid\u00e9es (\u00e0 recevoir)',
                  amount: '${formatAmount(totalApproved)} $currency',
                  color: const Color(0xFF2563EB),
                  icon: Icons.thumb_up_outlined,
                ),
                const Divider(height: 20),
                _FinanceRow(
                  label: 'D\u00e9j\u00e0 vers\u00e9es',
                  amount: '${formatAmount(totalPaid)} $currency',
                  color: const Color(0xFF16A34A),
                  icon: Icons.account_balance,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Leaderboard preview
          if (leaderboard.isNotEmpty) ...[
            const Text('Classement du mois',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < leaderboard.length && i < 5; i++)
                    _LeaderboardRow(
                      rank: (leaderboard[i]['rank'] ?? i + 1) as num,
                      tier: (leaderboard[i]['tier'] ?? 'bronze').toString(),
                      score: (leaderboard[i]['score'] ?? 0) as num,
                      isMe: leaderboard[i]['is_me'] == true,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TAB 2 — Prospects (anonymisés)
// ---------------------------------------------------------------------------
class _ProspectsTab extends StatelessWidget {
  final List<Map<String, dynamic>> referrals;
  final String Function(String) formatDate;

  const _ProspectsTab({required this.referrals, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    if (referrals.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 48, color: Color(0xFFD1D5DB)),
              SizedBox(height: 12),
              Text('Aucun prospect pour le moment',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              SizedBox(height: 4),
              Text('Partagez votre lien pour commencer !',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Les identifiants sont anonymes pour protéger la confidentialité des étudiants.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: referrals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final ref = referrals[index];
              final prospectId = (ref['prospect_id'] ?? 'PRO-???').toString();
              final status = (ref['prospect_status'] ?? '').toString();
              final attributedAt = (ref['attributed_at'] ?? '').toString();
              final source = (ref['source'] ?? '').toString();
              final appsCount = ref['applications_count'] ?? 0;

              return _ProspectCard(
                prospectId: prospectId,
                status: status,
                attributedAt: attributedAt.isNotEmpty
                    ? formatDate(attributedAt)
                    : '',
                source: source,
                applicationsCount: appsCount is int ? appsCount : 0,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProspectCard extends StatelessWidget {
  final String prospectId;
  final String status;
  final String attributedAt;
  final String source;
  final int applicationsCount;

  const _ProspectCard({
    required this.prospectId,
    required this.status,
    required this.attributedAt,
    required this.source,
    required this.applicationsCount,
  });

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor, statusIcon) = _statusInfo(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Avatar with prospect number
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                prospectId.replaceAll('PRO-', '#'),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: statusColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prospectId,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (attributedAt.isNotEmpty) ...[
                      Icon(Icons.calendar_today,
                          size: 11, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Text(attributedAt,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                      const SizedBox(width: 10),
                    ],
                    if (applicationsCount > 0) ...[
                      Icon(Icons.description_outlined,
                          size: 11, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Text('$applicationsCount candidature(s)',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(statusLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _statusInfo(String s) {
    switch (s) {
      case 'payment_confirmed':
        return ('Payé', const Color(0xFF16A34A), Icons.check_circle);
      case 'payment_declared':
        return ('Paiement déclaré', const Color(0xFF2563EB), Icons.hourglass_top);
      case 'has_application':
        return ('A candidaté', const Color(0xFF7C3AED), Icons.description);
      case 'registered_only':
      default:
        return ('Inscrit', const Color(0xFF6B7280), Icons.person_outline);
    }
  }
}

// ---------------------------------------------------------------------------
// TAB 3 — Finances
// ---------------------------------------------------------------------------
class _FinancesTab extends StatefulWidget {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> commissions;
  final List<Map<String, dynamic>> prospectPayments;
  final Map<String, dynamic> gamification;
  final List<Map<String, dynamic>> leaderboard;
  final String Function(String) formatDate;
  final String Function(dynamic) formatAmount;
  final Future<bool> Function(String) onClaimMilestone;

  const _FinancesTab({
    required this.summary,
    required this.commissions,
    required this.prospectPayments,
    required this.gamification,
    required this.leaderboard,
    required this.formatDate,
    required this.formatAmount,
    required this.onClaimMilestone,
  });

  @override
  State<_FinancesTab> createState() => _FinancesTabState();
}

class _FinancesTabState extends State<_FinancesTab>
    with SingleTickerProviderStateMixin {
  late TabController _subTabCtrl;

  @override
  void initState() {
    super.initState();
    _subTabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _subTabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = (widget.summary['currency'] ?? 'XOF').toString();
    final totalPending = widget.summary['total_commission_pending'] ?? 0;
    final totalApproved = widget.summary['total_commission_approved'] ?? 0;
    final totalPaid = widget.summary['total_commission_paid'] ?? 0;
    final totalDue = (totalPending is num ? totalPending : 0) +
        (totalApproved is num ? totalApproved : 0);

    return Column(
      children: [
        // Financial header
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text('Solde total dû par la plateforme',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                '${widget.formatAmount(totalDue)} $currency',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MiniStat(
                      label: 'En attente',
                      value: widget.formatAmount(totalPending),
                      currency: currency,
                      color: const Color(0xFFEA580C)),
                  Container(width: 1, height: 30, color: Colors.white24),
                  _MiniStat(
                      label: 'Validées',
                      value: widget.formatAmount(totalApproved),
                      currency: currency,
                      color: const Color(0xFF60A5FA)),
                  Container(width: 1, height: 30, color: Colors.white24),
                  _MiniStat(
                      label: 'Versées',
                      value: widget.formatAmount(totalPaid),
                      currency: currency,
                      color: const Color(0xFF4ADE80)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Auto-payout info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6EE7B7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.autorenew, color: Color(0xFF059669), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vos commissions validées sont automatiquement transférées vers votre compte LigdiCash.',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF065F46)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Sub-tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _subTabCtrl,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1)),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: const Color(0xFF111827),
            unselectedLabelColor: const Color(0xFF6B7280),
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            tabs: [
              Tab(text: 'Commissions (${widget.commissions.length})'),
              Tab(text: 'Paiements (${widget.prospectPayments.length})'),
              const Tab(text: 'Bonus & Classement'),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Sub-tab views
        Expanded(
          child: TabBarView(
            controller: _subTabCtrl,
            children: [
              _CommissionsList(
                commissions: widget.commissions,
                formatDate: widget.formatDate,
                formatAmount: widget.formatAmount,
              ),
              _ProspectPaymentsList(
                payments: widget.prospectPayments,
                formatDate: widget.formatDate,
                formatAmount: widget.formatAmount,
              ),
              _MilestonesAndLeaderboard(
                gamification: widget.gamification,
                leaderboard: widget.leaderboard,
                formatAmount: widget.formatAmount,
                onClaimMilestone: widget.onClaimMilestone,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String currency;
  final Color color;

  const _MiniStat(
      {required this.label,
      required this.value,
      required this.currency,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(currency,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}

class _CommissionsList extends StatelessWidget {
  final List<Map<String, dynamic>> commissions;
  final String Function(String) formatDate;
  final String Function(dynamic) formatAmount;

  const _CommissionsList(
      {required this.commissions,
      required this.formatDate,
      required this.formatAmount});

  @override
  Widget build(BuildContext context) {
    if (commissions.isEmpty) {
      return const Center(
        child: Text('Aucune commission pour le moment.',
            style: TextStyle(color: Color(0xFF6B7280))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: commissions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = commissions[index];
        final prospectId = (c['prospect_id'] ?? '').toString();
        final amount = c['commission_amount'] ?? 0;
        final currency = (c['currency'] ?? 'XOF').toString();
        final status = (c['status'] ?? '').toString();
        final createdAt = (c['created_at'] ?? '').toString();
        final paidAt = (c['paid_at'] ?? '').toString();

        final (statusLabel, statusColor) = _commissionStatus(status);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prospectId,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    if (createdAt.isNotEmpty)
                      Text('Créée le ${formatDate(createdAt)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                    if (paidAt.isNotEmpty && paidAt != 'null')
                      Text('Versée le ${formatDate(paidAt)}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF16A34A))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${formatAmount(amount)} $currency',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: statusColor)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  (String, Color) _commissionStatus(String s) {
    switch (s) {
      case 'pending':
        return ('En attente', const Color(0xFFEA580C));
      case 'approved':
        return ('Validée', const Color(0xFF2563EB));
      case 'paid':
        return ('Versée', const Color(0xFF16A34A));
      default:
        return (s, Colors.grey);
    }
  }
}

class _ProspectPaymentsList extends StatelessWidget {
  final List<Map<String, dynamic>> payments;
  final String Function(String) formatDate;
  final String Function(dynamic) formatAmount;

  const _ProspectPaymentsList(
      {required this.payments,
      required this.formatDate,
      required this.formatAmount});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const Center(
        child: Text('Aucun paiement prospect pour le moment.',
            style: TextStyle(color: Color(0xFF6B7280))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = payments[index];
        final prospectId = (p['prospect_id'] ?? '').toString();
        final reason = (p['payment_reason'] ?? '').toString();
        final amountRange = (p['amount_range'] ?? '').toString();
        final currency = (p['currency'] ?? 'XOF').toString();
        final status = (p['status'] ?? '').toString();
        final programName = (p['program_name'] ?? '').toString();
        final createdAt = (p['created_at'] ?? '').toString();
        final confirmedAt = (p['confirmed_at'] ?? '').toString();

        final (statusLabel, statusColor) = _paymentStatus(status);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.payment, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(prospectId,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        if (programName.isNotEmpty)
                          Text(programName,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _InfoChip(icon: Icons.receipt, text: _reasonLabel(reason)),
                  if (amountRange.isNotEmpty && amountRange != 'null') ...[
                    const SizedBox(width: 8),
                    _InfoChip(icon: Icons.account_balance_wallet, text: '$amountRange $currency'),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Spacer(),
                  if (createdAt.isNotEmpty)
                    Text(formatDate(createdAt),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400])),
                  if (confirmedAt.isNotEmpty && confirmedAt != 'null') ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle, size: 12, color: Colors.green[400]),
                    const SizedBox(width: 3),
                    Text(formatDate(confirmedAt),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF16A34A))),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  (String, Color) _paymentStatus(String s) {
    switch (s) {
      case 'confirmed':
        return ('Confirmé', const Color(0xFF16A34A));
      case 'declared_by_student':
        return ('Déclaré', const Color(0xFF2563EB));
      case 'under_verification':
        return ('En vérification', const Color(0xFFEA580C));
      case 'pending':
        return ('En attente', const Color(0xFF6B7280));
      case 'rejected':
        return ('Rejeté', Colors.red);
      default:
        return (s, Colors.grey);
    }
  }

  String _reasonLabel(String reason) {
    switch (reason) {
      case 'application_fee':
        return 'Frais de dossier';
      case 'registration_fee':
        return "Frais d'inscription";
      case 'tuition_deposit':
        return 'Acompte scolarité';
      case 'td_access':
        return 'Accès TD';
      case 'brokerage_fee':
        return 'Frais de courtage';
      default:
        return 'Paiement';
    }
  }

  String _channelLabel(String channel) {
    switch (channel) {
      case 'orange_money':
        return 'Orange Money';
      case 'moov_money':
        return 'Moov Money';
      case 'telecel_money':
        return 'Telecel Money';
      case 'cash':
        return 'Espèces';
      default:
        return channel;
    }
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceRow extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  const _FinanceRow(
      {required this.label,
      required this.amount,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
        ),
        Text(amount,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(text,
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final num rank;
  final String tier;
  final num score;
  final bool isMe;

  const _LeaderboardRow({
    required this.rank,
    required this.tier,
    required this.score,
    required this.isMe,
  });

  static const _tierEmoji = {
    'bronze': '\u{1F949}',
    'silver': '\u{1F948}',
    'gold': '\u{1F947}',
    'diamond': '\u{1F48E}',
  };

  @override
  Widget build(BuildContext context) {
    final emoji = _tierEmoji[tier] ?? '\u{1F949}';
    final bgColor = isMe ? const Color(0xFFEEF2FF) : Colors.transparent;
    final textWeight = isMe ? FontWeight.bold : FontWeight.normal;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${rank.toInt()}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: rank.toInt() <= 3
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFF6B7280)),
            ),
          ),
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMe ? 'Vous' : 'Commercial #${rank.toInt()}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: textWeight,
                  color: isMe
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF374151)),
            ),
          ),
          Text(
            '${score.toInt()} pts',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isMe
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _MilestonesAndLeaderboard extends StatelessWidget {
  final Map<String, dynamic> gamification;
  final List<Map<String, dynamic>> leaderboard;
  final String Function(dynamic) formatAmount;
  final Future<bool> Function(String) onClaimMilestone;

  const _MilestonesAndLeaderboard({
    required this.gamification,
    required this.leaderboard,
    required this.formatAmount,
    required this.onClaimMilestone,
  });

  @override
  Widget build(BuildContext context) {
    final milestones = gamification['milestones'];
    final milestoneList = (milestones is List)
        ? milestones.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Milestones
          const Text('Bonus de palier',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Atteignez ces objectifs pour d\u00e9bloquer des bonus.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          if (milestoneList.isEmpty)
            const Text('Aucun palier configur\u00e9.',
                style: TextStyle(color: Color(0xFF9CA3AF)))
          else
            ...milestoneList.map((m) {
              final threshold = m['threshold'] ?? 0;
              final bonus = m['bonus_amount'] ?? 0;
              final currency = (m['currency'] ?? 'XOF').toString();
              final label = (m['label'] ?? '').toString();
              final description = (m['description'] ?? '').toString();
              final reached = m['reached'] == true;
              final claimed = m['claimed'] == true;
              final claimStatus = (m['claim_status'] ?? '').toString();
              final milestoneId = (m['id'] ?? '').toString();

              Color cardColor;
              IconData cardIcon;
              String statusText;
              if (claimed && claimStatus == 'paid') {
                cardColor = const Color(0xFF16A34A);
                cardIcon = Icons.check_circle;
                statusText = 'Bonus vers\u00e9';
              } else if (claimed) {
                cardColor = const Color(0xFF2563EB);
                cardIcon = Icons.hourglass_top;
                statusText = 'R\u00e9clam\u00e9 — en attente';
              } else if (reached) {
                cardColor = const Color(0xFFFBBF24);
                cardIcon = Icons.star;
                statusText = 'Objectif atteint !';
              } else {
                cardColor = const Color(0xFF9CA3AF);
                cardIcon = Icons.lock_outline;
                statusText = 'Non atteint';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: reached
                          ? cardColor.withOpacity(0.4)
                          : const Color(0xFFE5E7EB)),
                  boxShadow: reached
                      ? [
                          BoxShadow(
                              color: cardColor.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(cardIcon, color: cardColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          if (description.isNotEmpty)
                            Text(description,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF6B7280))),
                          const SizedBox(height: 2),
                          Text(statusText,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cardColor)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${formatAmount(bonus)} $currency',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: cardColor)),
                        Text('$threshold commissions',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF9CA3AF))),
                        if (reached && !claimed) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () async {
                              final ok = await onClaimMilestone(milestoneId);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? 'Bonus r\u00e9clam\u00e9 avec succ\u00e8s !'
                                      : '\u00c9chec de la r\u00e9clamation.'),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('R\u00e9clamer',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 24),

          // Leaderboard
          const Text('Classement du mois',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Bas\u00e9 sur les commissions g\u00e9n\u00e9r\u00e9es ce mois-ci.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          if (leaderboard.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Pas encore de classement ce mois-ci.',
                    style: TextStyle(color: Color(0xFF9CA3AF))),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < leaderboard.length; i++)
                    _LeaderboardRow(
                      rank: (leaderboard[i]['rank'] ?? i + 1) as num,
                      tier: (leaderboard[i]['tier'] ?? 'bronze').toString(),
                      score: (leaderboard[i]['score'] ?? 0) as num,
                      isMe: leaderboard[i]['is_me'] == true,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _CommercialDashboardMenuAction {
  changePassword,
  settings,
}

Future<void> _showCommercialChangePasswordDialog(BuildContext context) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final email = user?.email;

  if (email == null || email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session expirée. Veuillez vous reconnecter.'),
      ),
    );
    return;
  }

  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final updated = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      String? errorMessage;
      bool isLoading = false;

      Future<void> submit() async {
        final current = currentPasswordController.text.trim();
        final next = newPasswordController.text.trim();
        final confirm = confirmPasswordController.text.trim();

        if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
          errorMessage = 'Merci de remplir tous les champs.';
          (dialogContext as Element).markNeedsBuild();
          return;
        }

        if (next.length < 8) {
          errorMessage = 'Le nouveau mot de passe doit contenir au moins 8 caractères.';
          (dialogContext as Element).markNeedsBuild();
          return;
        }

        if (next != confirm) {
          errorMessage = 'La confirmation ne correspond pas au nouveau mot de passe.';
          (dialogContext as Element).markNeedsBuild();
          return;
        }

        isLoading = true;
        errorMessage = null;
        (dialogContext as Element).markNeedsBuild();

        try {
          await client.auth.signInWithPassword(email: email, password: current);
        } on AuthException {
          isLoading = false;
          errorMessage = 'Mot de passe actuel incorrect.';
          (dialogContext as Element).markNeedsBuild();
          return;
        } catch (_) {
          isLoading = false;
          errorMessage = 'Erreur réseau. Veuillez réessayer.';
          (dialogContext as Element).markNeedsBuild();
          return;
        }

        try {
          await client.auth.updateUser(UserAttributes(password: next));
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop(true);
          }
        } on AuthException catch (e) {
          isLoading = false;
          errorMessage = e.message ?? 'Impossible de mettre à jour le mot de passe.';
          (dialogContext as Element).markNeedsBuild();
        } catch (_) {
          isLoading = false;
          errorMessage = 'Erreur inattendue. Veuillez réessayer.';
          (dialogContext as Element).markNeedsBuild();
        }
      }

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Changer le mot de passe'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe actuel',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nouveau mot de passe',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmer le nouveau mot de passe',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (errorMessage != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop(false);
                      },
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: isLoading ? null : submit,
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Mettre à jour'),
              ),
            ],
          );
        },
      );
    },
  );

  if (updated == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mot de passe mis à jour avec succès.'),
      ),
    );
  }
}
