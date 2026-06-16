import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/admin_finance_provider.dart';
import '../../providers/admin_revenue_split_provider.dart';
import 'admin_revenue_split_screen.dart';

class AdminFinanceScreen extends StatelessWidget {
  const AdminFinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminFinanceProvider()..init(),
      child: const _FinanceBody(),
    );
  }
}

class _FinanceBody extends StatefulWidget {
  const _FinanceBody();

  @override
  State<_FinanceBody> createState() => _FinanceBodyState();
}

class _FinanceBodyState extends State<_FinanceBody> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            labelColor: const Color(0xFF1EA75C),
            unselectedLabelColor: const Color(0xFF6B7280),
            indicatorColor: const Color(0xFF1EA75C),
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: "Vue d'ensemble"),
              Tab(text: 'Flux'),
              Tab(text: 'Payouts'),
              Tab(text: 'Acteurs'),
              Tab(text: 'Configuration'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [
              _OverviewTab(),
              _LedgerTab(),
              _PayoutsTab(),
              _ActorsTab(),
              _ConfigTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// TAB 1: VUE D'ENSEMBLE
// ════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  String _fmt(dynamic v) {
    if (v == null) return '0';
    if (v is num) {
      if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
      if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
      return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminFinanceProvider>(
      builder: (context, p, _) {
        if (p.isLoading && p.overview == null) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final o = p.overview ?? {};
        return RefreshIndicator(
          onRefresh: () async {
            await p.loadOverview();
            await p.loadLiveFeed();
          },
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // ── Solde header ──
              _SoldeHeader(
                disponible: _fmt(o['total_payin'] != null && o['total_payout'] != null
                    ? (o['total_payin'] as num) - (o['total_payout'] as num) - ((o['pending_amount'] as num?) ?? 0)
                    : 0),
                enAttente: _fmt(o['pending_amount']),
                enCours: _fmt(o['processing_count']),
              ),
              const SizedBox(height: 12),

              // ── KPI row ──
              Row(children: [
                _KpiMini(label: 'Entrées mois', value: '+${_fmt(o['month_payin'])}', sub: '${_fmt(o['month_payin_count'])} tx', color: const Color(0xFF16A34A), icon: Icons.arrow_downward),
                const SizedBox(width: 8),
                _KpiMini(label: 'Sorties mois', value: '-${_fmt(o['month_payout'])}', sub: '${_fmt(o['month_payout_count'])} tx', color: const Color(0xFFDC2626), icon: Icons.arrow_upward),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _KpiMini(label: 'Taux succès', value: '${_fmt(o['payout_success_rate'])}%', sub: 'payout', color: const Color(0xFF2563EB), icon: Icons.check_circle_outline),
                const SizedBox(width: 8),
                _KpiMini(
                  label: 'Échecs payout',
                  value: '${_fmt(o['failed_month'])}',
                  sub: 'ce mois',
                  color: ((o['failed_month'] as num?) ?? 0) > 0 ? const Color(0xFFDC2626) : const Color(0xFF6B7280),
                  icon: Icons.warning_amber_rounded,
                ),
              ]),
              const SizedBox(height: 16),

              // ── Chart 30j ──
              const Text('Flux — 30 derniers jours', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SizedBox(height: 200, child: _BarChart30d(data: (o['chart_30d'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [])),
              const SizedBox(height: 16),

              // ── Donuts ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _DonutSection(title: 'Entrées par source', data: (o['by_reason'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [], labelKey: 'reason', valueKey: 'amount')),
                  const SizedBox(width: 12),
                  Expanded(child: _DonutSection(title: 'Sorties par acteur', data: (o['by_payout_actor'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [], labelKey: 'actor_type', valueKey: 'amount')),
                ],
              ),
              const SizedBox(height: 16),

              // ── Activité live ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Activité live', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Text('TEMPS RÉEL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...p.liveFeed.take(20).map((e) => _LiveTransactionCard(entry: e, isNew: p.newLedgerIds.contains(e['id']?.toString()))),
              if (p.liveFeed.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aucune transaction enregistrée.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9CA3AF))),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Solde Header ──
class _SoldeHeader extends StatelessWidget {
  final String disponible, enAttente, enCours;
  const _SoldeHeader({required this.disponible, required this.enAttente, required this.enCours});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SOLDE PLATEFORME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(
            children: [
              _SoldeItem(label: 'Disponible', value: '$disponible XOF', color: const Color(0xFF4ADE80)),
              const SizedBox(width: 16),
              _SoldeItem(label: 'En attente', value: '$enAttente XOF', color: const Color(0xFFFBBF24)),
              const SizedBox(width: 16),
              _SoldeItem(label: 'En cours', value: enCours, color: const Color(0xFF60A5FA)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoldeItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SoldeItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}

// ── KPI Mini ──
class _KpiMini extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  final IconData icon;
  const _KpiMini({required this.label, required this.value, required this.sub, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
                  Text('$label · $sub', style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bar Chart 30 days ──
class _BarChart30d extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _BarChart30d({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('Pas de données', style: TextStyle(color: Color(0xFF9CA3AF))));

    double maxY = 0;
    for (final d in data) {
      final pin = (d['pin'] as num?)?.toDouble() ?? 0;
      final pout = (d['pout'] as num?)?.toDouble() ?? 0;
      if (pin > maxY) maxY = pin;
      if (pout > maxY) maxY = pout;
    }
    if (maxY == 0) maxY = 1000;

    return BarChart(
      BarChartData(
        maxY: maxY * 1.1,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final d = data[group.x.toInt()];
              final dateStr = d['d']?.toString().substring(5, 10) ?? '';
              final val = rod.toY.toStringAsFixed(0);
              return BarTooltipItem('$dateStr\n$val XOF', const TextStyle(fontSize: 10, color: Colors.white));
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx % 5 != 0 || idx >= data.length) return const SizedBox.shrink();
                final d = data[idx]['d']?.toString() ?? '';
                return Text(d.length >= 10 ? d.substring(5, 10) : d, style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF)));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: List.generate(data.length, (i) {
          final pin = (data[i]['pin'] as num?)?.toDouble() ?? 0;
          final pout = (data[i]['pout'] as num?)?.toDouble() ?? 0;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(toY: pin, color: const Color(0xFF16A34A), width: 4, borderRadius: BorderRadius.circular(2)),
              BarChartRodData(toY: pout, color: const Color(0xFFDC2626), width: 4, borderRadius: BorderRadius.circular(2)),
            ],
            barsSpace: 1,
          );
        }),
      ),
    );
  }
}

// ── Donut Section ──
class _DonutSection extends StatelessWidget {
  final String title, labelKey, valueKey;
  final List<Map<String, dynamic>> data;
  const _DonutSection({required this.title, required this.data, required this.labelKey, required this.valueKey});

  static const _colors = [Color(0xFF2563EB), Color(0xFF16A34A), Color(0xFFEA580C), Color(0xFF7C3AED), Color(0xFFDB2777), Color(0xFF0891B2)];
  static const _reasonLabels = {
    'application_fee': 'Dossier',
    'registration_fee': 'Inscription',
    'tuition_deposit': 'Scolarité',
    'td_access': 'TD',
    'credit_purchase': 'Crédits',
    'marketplace_purchase': 'Marketplace',
    'subscription': 'Abonnement',
    'online_course': 'Cours en ligne',
    'instructor': 'Enseignant',
    'commercial': 'Commercial',
    'merchant': 'Marchand',
    'university': 'Université',
  };

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('—', style: TextStyle(color: Color(0xFF9CA3AF))),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 20,
              sections: List.generate(data.length, (i) {
                final val = (data[i][valueKey] as num?)?.toDouble() ?? 0;
                return PieChartSectionData(
                  value: val,
                  color: _colors[i % _colors.length],
                  radius: 25,
                  showTitle: false,
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 4),
        ...data.asMap().entries.map((e) {
          final lbl = _reasonLabels[e.value[labelKey]?.toString()] ?? e.value[labelKey]?.toString() ?? '?';
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: _colors[e.key % _colors.length], borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Expanded(child: Text(lbl, style: const TextStyle(fontSize: 10, color: Color(0xFF374151)), overflow: TextOverflow.ellipsis)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Live Transaction Card ──
class _LiveTransactionCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool isNew;
  const _LiveTransactionCard({required this.entry, this.isNew = false});

  @override
  Widget build(BuildContext context) {
    final direction = entry['direction']?.toString() ?? '';
    final isCredit = direction == 'credit';
    final type = entry['transaction_type']?.toString() ?? '';
    final amount = entry['amount'];
    final desc = entry['description']?.toString() ?? '';
    final actorName = entry['actor_name']?.toString();
    final counterpartType = entry['counterpart_type']?.toString() ?? '';
    final createdAt = entry['created_at']?.toString() ?? '';

    Color badgeColor;
    String badgeLabel;
    if (isCredit) {
      badgeColor = const Color(0xFF16A34A);
      badgeLabel = 'PAYIN';
    } else {
      switch (counterpartType) {
        case 'instructor': badgeColor = const Color(0xFF2563EB); break;
        case 'commercial': badgeColor = const Color(0xFFEA580C); break;
        case 'merchant': badgeColor = const Color(0xFF7C3AED); break;
        default: badgeColor = const Color(0xFFDC2626);
      }
      badgeLabel = 'PAYOUT';
    }

    String timeAgo = '';
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inSeconds < 60) {
        timeAgo = 'il y a ${diff.inSeconds}s';
      } else if (diff.inMinutes < 60) {
        timeAgo = 'il y a ${diff.inMinutes}min';
      } else if (diff.inHours < 24) {
        timeAgo = 'il y a ${diff.inHours}h';
      } else {
        timeAgo = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      timeAgo = createdAt;
    }

    String amtStr = '';
    if (amount != null) {
      final a = amount is num ? amount : num.tryParse(amount.toString()) ?? 0;
      amtStr = '${isCredit ? '+' : '-'}${a.toStringAsFixed(a.truncateToDouble() == a ? 0 : 0)} XOF';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isNew ? badgeColor.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isNew ? Border.all(color: badgeColor.withOpacity(0.3), width: 1.5) : null,
        boxShadow: [if (!isNew) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Icon
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: badgeColor, size: 16),
            ),
            const SizedBox(width: 10),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isNew) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(3)),
                          child: const Text('NOUVEAU', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
                        child: Text(badgeLabel, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: badgeColor)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(type, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  if (actorName != null && actorName.isNotEmpty)
                    Text('${isCredit ? '' : '→ '}$actorName', style: TextStyle(fontSize: 11, color: badgeColor, fontWeight: FontWeight.w500)),
                  if (desc.isNotEmpty)
                    Text(desc, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(timeAgo, style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            // Amount
            Text(amtStr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: badgeColor)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// TAB 2: FLUX (Ledger)
// ════════════════════════════════════════════════════════════════════
class _LedgerTab extends StatelessWidget {
  const _LedgerTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminFinanceProvider>(
      builder: (context, p, _) {
        return Column(
          children: [
            // Filters
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  DropdownButton<String?>(
                    value: p.feedDirectionFilter,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    hint: const Text('Tous', style: TextStyle(fontSize: 12)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tous', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'credit', child: Text('Entrées', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'debit', child: Text('Sorties', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (v) => p.setFeedDirection(v),
                  ),
                  const Spacer(),
                  Text('${p.liveFeedTotal} entrées', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.download, size: 18),
                    tooltip: 'Exporter CSV',
                    onPressed: () => _exportCsv(context, p),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Recharger',
                    onPressed: () => p.loadLiveFeed(),
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: p.liveFeed.isEmpty
                  ? const Center(child: Text('Aucune entrée.', style: TextStyle(color: Color(0xFF9CA3AF))))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: p.liveFeed.length,
                      itemBuilder: (context, i) => _LiveTransactionCard(
                        entry: p.liveFeed[i],
                        isNew: p.newLedgerIds.contains(p.liveFeed[i]['id']?.toString()),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportCsv(BuildContext context, AdminFinanceProvider p) async {
    try {
      final csv = p.exportLedgerCsv();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/academia_ledger_export.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: 'Export Grand Livre Academia');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur export: $e')));
    }
  }
}

// ════════════════════════════════════════════════════════════════════
// TAB 3: PAYOUTS
// ════════════════════════════════════════════════════════════════════
class _PayoutsTab extends StatelessWidget {
  const _PayoutsTab();

  String _fmt(dynamic v) {
    if (v == null) return '0';
    if (v is num) return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 0);
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminFinanceProvider>(
      builder: (context, p, _) {
        final kpi = p.payoutKpi;
        return Column(
          children: [
            // KPI header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  _PayoutKpiChip(label: 'Attente', count: _fmt(kpi['pending_count']), amount: _fmt(kpi['pending_amount']), color: const Color(0xFFCA8A04)),
                  const SizedBox(width: 6),
                  _PayoutKpiChip(label: 'En cours', count: _fmt(kpi['processing_count']), amount: '', color: const Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  _PayoutKpiChip(label: 'OK', count: _fmt(kpi['completed_count']), amount: _fmt(kpi['completed_amount']), color: const Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  _PayoutKpiChip(label: 'Échec', count: _fmt(kpi['failed_count']), amount: _fmt(kpi['failed_amount']), color: const Color(0xFFDC2626)),
                ],
              ),
            ),
            // Filters + trigger
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  DropdownButton<String?>(
                    value: p.payoutStatusFilter,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    hint: const Text('Tous', style: TextStyle(fontSize: 12)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tous', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'pending', child: Text('En attente', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'processing', child: Text('En cours', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'completed', child: Text('Complétés', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'failed', child: Text('Échoués', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (v) => p.setPayoutStatusFilter(v),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String?>(
                    value: p.payoutActorFilter,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    hint: const Text('Tous acteurs', style: TextStyle(fontSize: 12)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tous acteurs', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'commercial', child: Text('Commercial', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'instructor', child: Text('Enseignant', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'merchant', child: Text('Marchand', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (v) => p.setPayoutActorFilter(v),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await p.triggerPayouts(allPending: true);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ok ? 'Payouts déclenchés.' : p.error ?? 'Erreur')),
                      );
                    },
                    icon: const Icon(Icons.send, size: 14),
                    label: const Text('Verser', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1EA75C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: p.payouts.isEmpty
                  ? const Center(child: Text('Aucun payout.', style: TextStyle(color: Color(0xFF9CA3AF))))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: p.payouts.length,
                      itemBuilder: (context, i) {
                        final payout = p.payouts[i];
                        final isNew = p.newPayoutIds.contains(payout['id']?.toString());
                        return _PayoutCard(payout: payout, isNew: isNew, onRetry: () async {
                          final id = payout['id']?.toString();
                          if (id == null) return;
                          final ok = await p.triggerPayouts(ids: [id]);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? 'Retry lancé.' : p.error ?? 'Erreur')),
                          );
                        });
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PayoutKpiChip extends StatelessWidget {
  final String label, count, amount;
  final Color color;
  const _PayoutKpiChip({required this.label, required this.count, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
            if (amount.isNotEmpty) Text('$amount XOF', style: TextStyle(fontSize: 8, color: color)),
          ],
        ),
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  final Map<String, dynamic> payout;
  final bool isNew;
  final VoidCallback onRetry;
  const _PayoutCard({required this.payout, this.isNew = false, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final type = payout['beneficiary_type']?.toString() ?? '';
    final phone = payout['beneficiary_phone']?.toString() ?? '';
    final actorName = payout['actor_name']?.toString() ?? '';
    final amount = payout['amount'];
    final status = payout['status']?.toString() ?? '';
    final reason = payout['reason']?.toString() ?? '';
    final errorMsg = payout['error_message']?.toString() ?? '';
    final retryCount = payout['retry_count'] ?? 0;
    final createdAt = payout['created_at']?.toString() ?? '';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'pending': statusColor = const Color(0xFFCA8A04); statusLabel = 'En attente'; break;
      case 'processing': statusColor = const Color(0xFF2563EB); statusLabel = 'En cours'; break;
      case 'completed': statusColor = const Color(0xFF16A34A); statusLabel = 'Complété'; break;
      case 'failed': statusColor = const Color(0xFFDC2626); statusLabel = 'Échoué'; break;
      default: statusColor = const Color(0xFF6B7280); statusLabel = status;
    }

    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    switch (type) {
      case 'commercial': typeColor = const Color(0xFFEA580C); typeIcon = Icons.people; typeLabel = 'Commercial'; break;
      case 'instructor': typeColor = const Color(0xFF2563EB); typeIcon = Icons.school; typeLabel = 'Enseignant'; break;
      case 'merchant': typeColor = const Color(0xFF7C3AED); typeIcon = Icons.storefront; typeLabel = 'Marchand'; break;
      default: typeColor = const Color(0xFF6B7280); typeIcon = Icons.account_circle; typeLabel = type;
    }

    String dateStr = '';
    try {
      final dt = DateTime.parse(createdAt);
      dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      dateStr = createdAt;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isNew ? typeColor.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isNew ? Border.all(color: typeColor.withOpacity(0.3)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isNew) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(3)),
                    child: const Text('NOUVEAU', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(typeIcon, size: 16, color: typeColor),
                const SizedBox(width: 4),
                Text(typeLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: typeColor)),
                if (actorName.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Expanded(child: Text('· $actorName', style: const TextStyle(fontSize: 11, color: Color(0xFF374151)), overflow: TextOverflow.ellipsis)),
                ] else
                  const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${amount is num ? amount.toStringAsFixed(0) : amount} XOF', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                if (phone.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('→ $phone', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                ],
              ],
            ),
            Row(
              children: [
                Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                if (reason.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(reason, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                ],
                const Spacer(),
                if (status == 'failed')
                  GestureDetector(
                    onTap: onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: const Text('Retenter', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                    ),
                  ),
              ],
            ),
            if (errorMsg.isNotEmpty && errorMsg != 'null')
              Text('Erreur: $errorMsg', style: const TextStyle(fontSize: 10, color: Color(0xFFDC2626))),
            if (retryCount is int && retryCount > 0)
              Text('Tentatives: $retryCount', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// TAB 4: ACTEURS
// ════════════════════════════════════════════════════════════════════
class _ActorsTab extends StatelessWidget {
  const _ActorsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminFinanceProvider>(
      builder: (context, p, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  DropdownButton<String?>(
                    value: p.actorTypeFilter,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    hint: const Text('Tous', style: TextStyle(fontSize: 12)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tous', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'commercial', child: Text('Commerciaux', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'instructor', child: Text('Enseignants', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'merchant', child: Text('Marchands', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (v) => p.setActorTypeFilter(v),
                  ),
                  const Spacer(),
                  Text('${p.actorBalances.length} acteurs', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: () => p.loadActorBalances()),
                ],
              ),
            ),
            Expanded(
              child: p.actorBalances.isEmpty
                  ? const Center(child: Text('Aucun acteur.', style: TextStyle(color: Color(0xFF9CA3AF))))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: p.actorBalances.length,
                      itemBuilder: (context, i) => _ActorCard(
                        actor: p.actorBalances[i],
                        onTap: () => _showActorHistory(context, p, p.actorBalances[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showActorHistory(BuildContext context, AdminFinanceProvider p, Map<String, dynamic> actor) async {
    final actorId = actor['actor_id']?.toString();
    if (actorId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: p.loadActorHistory(actorId),
          builder: (ctx, snap) {
            final name = actor['display_name']?.toString() ?? actor['actor_type']?.toString() ?? '';
            if (snap.connectionState == ConnectionState.waiting) {
              return SizedBox(height: 300, child: Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [const CircularProgressIndicator(strokeWidth: 2), const SizedBox(height: 8), Text('Chargement historique $name...')],
              )));
            }
            final data = snap.data;
            final payouts = (data?['payouts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
            final ledger = (data?['ledger'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.3,
              expand: false,
              builder: (ctx, scroll) {
                return ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 12),
                    Text('Historique — $name', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if (payouts.isNotEmpty) ...[
                      const Text('Payouts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ...payouts.map((po) => _MiniHistoryRow(
                        label: '${po['reason'] ?? po['beneficiary_type']}',
                        amount: '${po['amount']} ${po['currency'] ?? 'XOF'}',
                        status: po['status']?.toString() ?? '',
                        date: po['created_at']?.toString() ?? '',
                      )),
                    ],
                    if (ledger.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Ledger', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ...ledger.map((le) => _MiniHistoryRow(
                        label: le['description']?.toString() ?? le['transaction_type']?.toString() ?? '',
                        amount: '${le['direction'] == 'credit' ? '+' : '-'}${le['amount']} ${le['currency'] ?? 'XOF'}',
                        status: le['direction']?.toString() ?? '',
                        date: le['created_at']?.toString() ?? '',
                      )),
                    ],
                    if (payouts.isEmpty && ledger.isEmpty)
                      const Padding(padding: EdgeInsets.all(24), child: Text('Aucun historique.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9CA3AF)))),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MiniHistoryRow extends StatelessWidget {
  final String label, amount, status, date;
  const _MiniHistoryRow({required this.label, required this.amount, required this.status, required this.date});

  @override
  Widget build(BuildContext context) {
    String dateStr = date;
    try {
      final dt = DateTime.parse(date);
      dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {}
    final isGreen = status == 'completed' || status == 'credit';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
          Text(amount, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isGreen ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
          const SizedBox(width: 8),
          Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}

class _ActorCard extends StatelessWidget {
  final Map<String, dynamic> actor;
  final VoidCallback onTap;
  const _ActorCard({required this.actor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = actor['actor_type']?.toString() ?? '';
    final name = actor['display_name']?.toString() ?? '';
    final available = actor['available_balance'] ?? 0;
    final totalEarned = actor['total_earned'] ?? 0;
    final totalWithdrawn = actor['total_withdrawn'] ?? 0;

    Color typeColor;
    IconData typeIcon;
    switch (type) {
      case 'commercial': typeColor = const Color(0xFFEA580C); typeIcon = Icons.people; break;
      case 'instructor': typeColor = const Color(0xFF2563EB); typeIcon = Icons.school; break;
      case 'merchant': typeColor = const Color(0xFF7C3AED); typeIcon = Icons.storefront; break;
      default: typeColor = const Color(0xFF6B7280); typeIcon = Icons.account_circle;
    }

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(typeIcon, color: typeColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? type : name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('Gagné: ${_f(totalEarned)}  Versé: ${_f(totalWithdrawn)}', style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${_f(available)} XOF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: typeColor)),
                  const Text('disponible', style: TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }

  String _f(dynamic v) {
    if (v == null) return '0';
    if (v is num) return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 0);
    return v.toString();
  }
}

// ════════════════════════════════════════════════════════════════════
// TAB 5: CONFIGURATION (réutilise l'existant)
// ════════════════════════════════════════════════════════════════════
class _ConfigTab extends StatelessWidget {
  const _ConfigTab();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminRevenueSplitProvider()..loadRules()..loadValidations(),
      child: const AdminRevenueSplitScreen(),
    );
  }
}
