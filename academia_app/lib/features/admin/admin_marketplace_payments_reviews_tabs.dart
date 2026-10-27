import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Onglets « Paiements » et « Avis » de la tour de contrôle marketplace
/// (27/10/2026). Les fonctions existaient en base sans aucun écran :
/// `app_admin_list_marketplace_payments`, `app_admin_moderate_review`, et
/// `app_admin_list_marketplace_reviews` (ajoutée le même jour).

String _fcfa(dynamic v) {
  final n = v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
  final s = n.round().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  return '$s FCFA';
}

String _date(dynamic v) {
  final d = DateTime.tryParse('${v ?? ''}')?.toLocal();
  if (d == null) return '';
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

Widget _pastille(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );

// ─── Paiements ─────────────────────────────────────────────────────────────

class AdminMarketplacePaymentsTab extends StatefulWidget {
  const AdminMarketplacePaymentsTab({super.key});

  @override
  State<AdminMarketplacePaymentsTab> createState() => _AdminMarketplacePaymentsTabState();
}

class _AdminMarketplacePaymentsTabState extends State<AdminMarketplacePaymentsTab> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  String? _status;
  int _total = 0;
  List<Map<String, dynamic>> _items = const [];

  // Statuts du séquestre (règles du 06/10, `marketplace_regles_metier.md`).
  static const _filtres = <(String?, String)>[
    (null, 'Tous'),
    ('pending', 'En attente'),
    ('captured', 'En séquestre'),
    ('released', 'Versés'),
    ('refunded', 'Remboursés'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _client.rpc('app_admin_list_marketplace_payments',
          params: {'p_status': _status, 'p_limit': 200, 'p_offset': 0});
      final data = res is Map ? Map<String, dynamic>.from(res) : const <String, dynamic>{};
      if (data['success'] != true) {
        setState(() => _error = 'Chargement impossible (${data['error'] ?? 'réponse vide'}).');
        return;
      }
      setState(() {
        _total = (data['total'] as num?)?.toInt() ?? 0;
        _items = ((data['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      setState(() => _error = 'Erreur réseau : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  (String, Color) _etat(String? s) => switch (s) {
        'pending' => ('En attente', const Color(0xFF6B7280)),
        'captured' => ('En séquestre', const Color(0xFF2563EB)),
        'released' => ('Versé au marchand', const Color(0xFF16A34A)),
        'refunded' => ('Remboursé', const Color(0xFFEA580C)),
        'cancelled' => ('Annulé', const Color(0xFF6B7280)),
        _ => (s ?? '—', const Color(0xFF6B7280)),
      };

  @override
  Widget build(BuildContext context) {
    final brut = _items.fold<num>(0, (a, e) => a + ((e['gross_amount'] as num?) ?? 0));
    final commission = _items.fold<num>(0, (a, e) => a + ((e['commission_amount'] as num?) ?? 0));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final f in _filtres)
              ChoiceChip(
                label: Text(f.$2),
                selected: _status == f.$1,
                onSelected: (_) {
                  setState(() => _status = f.$1);
                  _load();
                },
              ),
          ]),
          const SizedBox(height: 10),
          Text('$_total paiement(s) · brut ${_fcfa(brut)} · commission ${_fcfa(commission)}',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          if (_loading && _items.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.red)))
          else if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Aucun paiement marketplace pour ce filtre.')),
            )
          else
            for (final p in _items)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(p['merchant_name']?.toString() ?? 'Marchand',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      _pastille(_etat(p['status']?.toString()).$1, _etat(p['status']?.toString()).$2),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      'Brut ${_fcfa(p['gross_amount'])} · commission ${_fcfa(p['commission_amount'])} · '
                      'net marchand ${_fcfa(p['net_amount'])}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        _date(p['created_at']),
                        if ((p['payment_provider_ref'] ?? '').toString().isNotEmpty) 'Réf. ${p['payment_provider_ref']}',
                        if (p['escrow_released_at'] != null) 'versé le ${_date(p['escrow_released_at'])}',
                      ].where((e) => e.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                    ),
                  ]),
                ),
              ),
        ],
      ),
    );
  }
}

// ─── Avis ──────────────────────────────────────────────────────────────────

class AdminMarketplaceReviewsTab extends StatefulWidget {
  const AdminMarketplaceReviewsTab({super.key});

  @override
  State<AdminMarketplaceReviewsTab> createState() => _AdminMarketplaceReviewsTabState();
}

class _AdminMarketplaceReviewsTabState extends State<AdminMarketplaceReviewsTab> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  String _filtre = 'all';
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _client.rpc('app_admin_list_marketplace_reviews',
          params: {'p_filter': _filtre, 'p_limit': 200, 'p_offset': 0});
      final data = res is Map ? Map<String, dynamic>.from(res) : const <String, dynamic>{};
      if (data['success'] != true) {
        setState(() => _error = 'Chargement impossible (${data['error'] ?? 'réponse vide'}).');
        return;
      }
      setState(() {
        _items = ((data['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      setState(() => _error = 'Erreur réseau : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _basculer(Map<String, dynamic> avis) async {
    final visible = avis['is_active'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(visible ? 'Masquer cet avis ?' : 'Rétablir cet avis ?'),
        content: Text(visible
            ? 'Il ne sera plus visible sur l\'annonce, et la note de l\'annonce sera recalculée sans lui.'
            : 'Il redeviendra visible et comptera de nouveau dans la note de l\'annonce.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(visible ? 'Masquer' : 'Rétablir')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await _client.rpc('app_admin_moderate_review',
          params: {'p_review_id': avis['id'], 'p_is_active': !visible});
      final data = res is Map ? res : const {};
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(data['success'] == true
            ? (visible ? 'Avis masqué.' : 'Avis rétabli.')
            : 'Action refusée : ${data['error']}'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(spacing: 8, children: [
            for (final f in const [('all', 'Tous'), ('visible', 'Visibles'), ('hidden', 'Masqués')])
              ChoiceChip(
                label: Text(f.$2),
                selected: _filtre == f.$1,
                onSelected: (_) {
                  setState(() => _filtre = f.$1);
                  _load();
                },
              ),
          ]),
          const SizedBox(height: 8),
          if (_loading && _items.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.red)))
          else if (_items.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aucun avis pour ce filtre.')))
          else
            for (final a in _items)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      ...List.generate(
                        5,
                        (i) => Icon(i < ((a['rating'] as num?)?.toInt() ?? 0) ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 18, color: const Color(0xFFF59E0B)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(a['listing_title']?.toString() ?? 'Annonce',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      a['is_active'] == true
                          ? _pastille('Visible', const Color(0xFF16A34A))
                          : _pastille('Masqué', const Color(0xFFB91C1C)),
                    ]),
                    if ((a['title'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(a['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                    if ((a['content'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(a['content'].toString()),
                    ],
                    if ((a['seller_reply'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Réponse du marchand : ${a['seller_reply']}',
                          style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      [
                        a['buyer_name']?.toString() ?? '',
                        if ((a['merchant_name'] ?? '').toString().isNotEmpty) 'vendeur : ${a['merchant_name']}',
                        if (a['is_verified_purchase'] == true) 'achat vérifié',
                        _date(a['created_at']),
                      ].where((e) => e.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _basculer(a),
                        icon: Icon(a['is_active'] == true ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        label: Text(a['is_active'] == true ? 'Masquer' : 'Rétablir'),
                      ),
                    ),
                  ]),
                ),
              ),
        ],
      ),
    );
  }
}
