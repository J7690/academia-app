import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'student_marketplace_add_review_screen.dart';

class StudentMarketplaceOrderDetailScreenV1 extends StatefulWidget {
  final String orderId;

  const StudentMarketplaceOrderDetailScreenV1({
    super.key,
    required this.orderId,
  });

  @override
  State<StudentMarketplaceOrderDetailScreenV1> createState() =>
      _StudentMarketplaceOrderDetailScreenV1State();
}

class _StudentMarketplaceOrderDetailScreenV1State
    extends State<StudentMarketplaceOrderDetailScreenV1> {
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = const [];

  String _formatMoney(dynamic v, String? currency) {
    if (v is num) {
      final cur = (currency ?? '').trim();
      if (cur.isEmpty) return '${v.toStringAsFixed(0)} FCFA';
      return '${v.toStringAsFixed(0)} $cur';
    }
    return v?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final id = widget.orderId.trim();
    if (id.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final response = await client.rpc(
        'app_student_get_marketplace_order_detail',
        params: {
          'p_order_id': id,
        },
      );

      if (response is! Map<String, dynamic>) {
        setState(() {
          _error = 'Réponse invalide du serveur.';
        });
        return;
      }

      if (response['success'] != true) {
        setState(() {
          _error = response['error']?.toString() ?? 'Erreur serveur.';
        });
        return;
      }

      final o = response['order'];
      final it = response['items'];

      setState(() {
        _order = o is Map ? Map<String, dynamic>.from(o) : null;
        _items = (it is List)
            ? it
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(growable: false)
            : <Map<String, dynamic>>[];
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final status = order?['status']?.toString() ?? '';
    final currency = order?['currency']?.toString();
    final total = order?['total_amount'];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Détail commande'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : order == null
                  ? const Center(child: Text('Commande introuvable.'))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Statut: $status',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Total: ${_formatMoney(total, currency)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Articles',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        if (_items.isEmpty)
                          const Text('Aucun article.')
                        else
                          ..._items.map((it) {
                            final title = it['title']?.toString() ?? '';
                            final qty = it['quantity']?.toString() ?? '';
                            final unit = it['unit_price'];
                            final cur = it['currency']?.toString();
                            final productId = it['product_id']?.toString();
                            final canReview = status == 'delivered' || status == 'completed';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text('x$qty'),
                                      const SizedBox(width: 12),
                                      Text(
                                        _formatMoney(unit, cur),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (canReview && productId != null && productId.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => StudentMarketplaceAddReviewScreen(
                                                listingId: productId,
                                                orderId: widget.orderId,
                                                listingTitle: title,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.rate_review_outlined, size: 18),
                                        label: const Text('Laisser un avis'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
    );
  }
}
