import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'student_marketplace_order_detail_screen_v1.dart';
import '../../../widgets/marketplace/marketplace_shimmer.dart';

class StudentMarketplaceMyOrdersScreenV1 extends StatefulWidget {
  const StudentMarketplaceMyOrdersScreenV1({super.key});

  @override
  State<StudentMarketplaceMyOrdersScreenV1> createState() =>
      _StudentMarketplaceMyOrdersScreenV1State();
}

class _StudentMarketplaceMyOrdersScreenV1State
    extends State<StudentMarketplaceMyOrdersScreenV1> {
  bool _loading = false;
  String? _error;
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
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final response = await client.rpc(
        'app_student_list_my_marketplace_orders',
        params: {
          'p_limit': 50,
          'p_offset': 0,
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

      final data = response['items'];
      setState(() {
        _items = (data is List)
            ? data
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Mes commandes'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _loading
          ? const MarketplaceShimmerList()
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
              : _items.isEmpty
                  ? const Center(child: Text('Aucune commande.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final o = _items[index];
                          final id = o['id']?.toString() ?? '';
                          final status = o['status']?.toString() ?? '';
                          final currency = o['currency']?.toString();
                          final total = o['total_amount'];

                          return Card(
                            child: ListTile(
                              title: Text(
                                _formatMoney(total, currency),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text('Statut: $status'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: id.isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              StudentMarketplaceOrderDetailScreenV1(
                                            orderId: id,
                                          ),
                                        ),
                                      );
                                    },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
