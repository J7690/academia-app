import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_audience_screen.dart';

/// Écran admin pour visualiser les statistiques de navigation utilisateur.
/// Montre les top screens, top tabs, activité quotidienne.
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  bool _loading = true;
  int _periodDays = 7;
  Map<String, dynamic> _stats = {};

  /// Ce qui a empêché le chargement, s'il a échoué. Null si tout va bien.
  ///
  /// Sans ce champ, cet écran a menti pendant des mois : la RPC échouait à
  /// CHAQUE ouverture — elle n'existait que dans le schéma `app`, que PostgREST
  /// n'expose pas — l'exception partait dans un `debugPrint` invisible, et
  /// l'admin lisait un paisible « Aucune donnée ». Trois couches empilées
  /// (RPC injoignable, erreur avalée, table vide) dont une seule se voyait :
  /// la plus trompeuse. Corrigé le 04/09/2026.
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _erreur = null;
    });
    try {
      final result = await Supabase.instance.client.rpc(
        'app_admin_get_navigation_stats',
        params: {'p_days': _periodDays, 'p_limit': 20},
      );
      if (result is Map<String, dynamic>) {
        if (result['success'] == true) {
          _stats = result;
        } else {
          // Le serveur a répondu, mais il refuse : le dire, plutôt que de
          // laisser croire à une absence de trafic.
          _stats = {};
          _erreur = result['error'] == 'forbidden'
              ? 'Accès refusé : cet écran demande un compte administrateur.'
              : 'Le serveur a refusé la demande (${result['error']}).';
        }
      } else {
        _stats = {};
        _erreur = 'Réponse inattendue du serveur.';
      }
    } catch (e) {
      _stats = {};
      _erreur = 'Statistiques indisponibles : $e';
      debugPrint('[AdminAnalytics] Error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Affiche les données, ou dit pourquoi il n'y en a pas.
  ///
  /// « Aucune donnée » ne s'affiche plus que lorsque la requête a RÉUSSI et
  /// n'a effectivement rien trouvé. Une panne se distingue désormais d'un
  /// désert.
  Widget _legacyOrEmpty(Widget Function() builder) {
    if (_erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(height: 8),
              Text(
                _erreur!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    if (_stats.isEmpty) {
      return const Center(
        child: Text('Aucune donnée sur la période',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return builder();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Period selector + refresh
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _PeriodChip('7j', 7),
              const SizedBox(width: 8),
              _PeriodChip('14j', 14),
              const SizedBox(width: 8),
              _PeriodChip('30j', 30),
              const SizedBox(width: 8),
              _PeriodChip('90j', 90),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadStats,
              ),
            ],
          ),
        ),
        // Summary cards
        if (!_loading && _stats.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _StatCard('Utilisateurs', '${_stats['unique_users'] ?? 0}', Icons.people, Colors.blue),
                const SizedBox(width: 8),
                _StatCard('Événements', '${_stats['total_events'] ?? 0}', Icons.touch_app, Colors.green),
              ],
            ),
          ),
        const SizedBox(height: 12),
        // Content
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : DefaultTabController(
                      length: 4,
                      child: Column(
                        children: [
                          const TabBar(
                            labelColor: Colors.indigo,
                            unselectedLabelColor: Colors.grey,
                            isScrollable: true,
                            tabs: [
                              Tab(text: '📊 Audience'),
                              Tab(text: 'Top Écrans'),
                              Tab(text: 'Top Onglets'),
                              Tab(text: 'Activité'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                const AdminAudienceScreen(),
                                _legacyOrEmpty(_buildTopScreens),
                                _legacyOrEmpty(_buildTopTabs),
                                _legacyOrEmpty(_buildDailyActivity),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _PeriodChip(String label, int days) {
    final selected = _periodDays == days;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.black87)),
      selected: selected,
      selectedColor: Colors.indigo,
      onSelected: (_) {
        setState(() => _periodDays = days);
        _loadStats();
      },
    );
  }

  Widget _StatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopScreens() {
    final screens = (_stats['top_screens'] as List?) ?? [];
    if (screens.isEmpty) return const Center(child: Text('Aucune donnée'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: screens.length,
      itemBuilder: (context, index) {
        final s = screens[index] as Map<String, dynamic>;
        final name = s['screen_name']?.toString() ?? '?';
        final visits = s['visits'] ?? 0;
        final users = s['unique_users'] ?? 0;
        final avgDur = s['avg_duration_sec'] ?? 0;
        final maxVisits = (screens[0] as Map)['visits'] ?? 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.indigo))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  Text('$visits vues', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Text('$users u.', style: const TextStyle(fontSize: 11, color: Colors.blue)),
                  if (avgDur > 0) ...[
                    const SizedBox(width: 8),
                    Text('${avgDur}s', style: const TextStyle(fontSize: 11, color: Colors.orange)),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: maxVisits > 0 ? (visits as num) / (maxVisits as num) : 0,
                backgroundColor: Colors.grey[200],
                color: Colors.indigo,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopTabs() {
    final tabs = (_stats['top_tabs'] as List?) ?? [];
    if (tabs.isEmpty) return const Center(child: Text('Aucune donnée'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tabs.length,
      itemBuilder: (context, index) {
        final t = tabs[index] as Map<String, dynamic>;
        final screen = t['screen_name']?.toString() ?? '';
        final tabName = t['tab_name']?.toString() ?? 'tab_${t['tab_index']}';
        final visits = t['visits'] ?? 0;
        final users = t['unique_users'] ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.indigo.withValues(alpha: 0.1),
              child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.indigo)),
            ),
            title: Text(tabName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(screen, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$visits', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text('$users utilisateurs', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyActivity() {
    final days = (_stats['daily_activity'] as List?) ?? [];
    if (days.isEmpty) return const Center(child: Text('Aucune donnée'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final d = days[index] as Map<String, dynamic>;
        final day = d['day']?.toString() ?? '';
        final events = d['events'] ?? 0;
        final users = d['users'] ?? 0;
        final maxEvents = (days[0] as Map)['events'] ?? 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(width: 80, child: Text(day, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              Expanded(
                child: LinearProgressIndicator(
                  value: maxEvents > 0 ? (events as num) / (maxEvents as num) : 0,
                  backgroundColor: Colors.grey[200],
                  color: Colors.green,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 50, child: Text('$events ev.', style: const TextStyle(fontSize: 11))),
              SizedBox(width: 40, child: Text('$users u.', style: const TextStyle(fontSize: 11, color: Colors.blue))),
            ],
          ),
        );
      },
    );
  }
}
