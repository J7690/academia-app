import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Écran admin « Audience » — parcours utilisateurs (T3).
///
/// Réservé aux administrateurs : la RPC `app_admin_audience_overview`
/// refuse tout autre rôle (`app.is_admin()`), et la table sous-jacente
/// est protégée par RLS admin-only.
class AdminAudienceScreen extends StatefulWidget {
  const AdminAudienceScreen({super.key});

  @override
  State<AdminAudienceScreen> createState() => _AdminAudienceScreenState();
}

class _AdminAudienceScreenState extends State<AdminAudienceScreen> {
  int _days = 7;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Supabase.instance.client
          .rpc('app_admin_audience_overview', params: {'p_days': _days});
      if (result is Map && result['success'] == true) {
        setState(() {
          _data = Map<String, dynamic>.from(result);
          _loading = false;
        });
      } else {
        setState(() {
          _error = (result is Map ? result['error'] : null)?.toString() ??
              'Réponse inattendue';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _periodChip(String label, int value) {
    final selected = _days == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _days = value);
        _load();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _periodChip("1j", 1),
              const SizedBox(width: 8),
              _periodChip('7j', 7),
              const SizedBox(width: 8),
              _periodChip('30j', 30),
              const SizedBox(width: 8),
              _periodChip('90j', 90),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    return _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Erreur : $_error',
                        textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildTotals(),
                      const SizedBox(height: 16),
                      _buildPlatforms(),
                      const SizedBox(height: 16),
                      _buildSection(
                        'Écrans les plus visités',
                        Icons.smartphone,
                        _listOf('top_screens'),
                        (e) => _barTile(
                          title: e['screen']?.toString() ?? '?',
                          subtitle:
                              '${e['visitors']} visiteurs · ${_fmtDuration(e['avg_duration'])}',
                          value: _asInt(e['views']),
                          maxValue: _maxOf('top_screens', 'views'),
                          trailing: '${e['views']} vues',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        'Contenus les plus consultés',
                        Icons.local_offer,
                        _listOf('top_entities'),
                        (e) => _barTile(
                          title:
                              '${e['entity_type']} · ${_shortId(e['entity_id'])}',
                          subtitle: '${e['visitors']} visiteurs',
                          value: _asInt(e['views']),
                          maxValue: _maxOf('top_entities', 'views'),
                          trailing: '${e['views']} vues',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        'Recherches les plus fréquentes',
                        Icons.search,
                        _listOf('top_searches'),
                        (e) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.search, size: 18),
                          title: Text('"${e['query']}"'),
                          trailing: Text('${e['searches']}×'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDaily(),
                    ],
                  ),
                );
  }

  // ---------- helpers ----------

  List<Map<String, dynamic>> _listOf(String key) {
    final raw = _data[key];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  int _maxOf(String key, String field) {
    final list = _listOf(key);
    int max = 1;
    for (final e in list) {
      final v = _asInt(e[field]);
      if (v > max) max = v;
    }
    return max;
  }

  String _shortId(dynamic id) {
    final s = id?.toString() ?? '';
    return s.length > 12 ? '${s.substring(0, 12)}…' : s;
  }

  String _fmtDuration(dynamic seconds) {
    final s = _asInt(seconds);
    if (s <= 0) return '—';
    if (s < 60) return '${s}s en moyenne';
    return '${(s / 60).toStringAsFixed(1)} min en moyenne';
  }

  Widget _buildTotals() {
    final totals = _data['totals'] is Map
        ? Map<String, dynamic>.from(_data['totals'])
        : const <String, dynamic>{};
    Widget card(String label, dynamic value, IconData icon, Color color) {
      return Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 6),
                Text('${value ?? 0}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text(label,
                    style: const TextStyle(fontSize: 11),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        card('Événements', totals['events'], Icons.timeline, Colors.blue),
        card('Visiteurs', totals['visitors'], Icons.people, Colors.green),
        card('Connectés', totals['logged_users'], Icons.verified_user,
            Colors.teal),
        card('Anonymes', totals['anonymous_visitors'], Icons.visibility_off,
            Colors.orange),
      ],
    );
  }

  Widget _buildPlatforms() {
    final platforms = _listOf('platforms');
    if (platforms.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          children: platforms
              .map((p) => Chip(
                    avatar: Icon(
                      p['platform'] == 'web'
                          ? Icons.language
                          : Icons.phone_android,
                      size: 16,
                    ),
                    label: Text('${p['platform']} : ${p['events']}'),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon,
      List<Map<String, dynamic>> items, Widget Function(Map<String, dynamic>) tile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const Divider(),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Aucune donnée sur la période',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ...items.map(tile),
          ],
        ),
      ),
    );
  }

  Widget _barTile({
    required String title,
    required String subtitle,
    required int value,
    required int maxValue,
    required String trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis)),
              Text(trailing, style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: maxValue > 0 ? value / maxValue : 0,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDaily() {
    final daily = _listOf('daily');
    if (daily.isEmpty) return const SizedBox.shrink();
    final maxV = daily.fold<int>(
        1, (m, e) => _asInt(e['events']) > m ? _asInt(e['events']) : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.show_chart, size: 18),
              SizedBox(width: 8),
              Text('Activité par jour',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const Divider(),
            SizedBox(
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: daily
                    .map((d) => Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Tooltip(
                              message:
                                  '${d['day']} : ${d['events']} évts, ${d['visitors']} visiteurs',
                              child: FractionallySizedBox(
                                heightFactor:
                                    (_asInt(d['events']) / maxV).clamp(0.03, 1),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade400,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(3)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
