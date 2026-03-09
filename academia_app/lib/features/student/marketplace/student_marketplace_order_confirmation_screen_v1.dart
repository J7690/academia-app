import 'package:flutter/material.dart';

class StudentMarketplaceOrderConfirmationScreenV1 extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const StudentMarketplaceOrderConfirmationScreenV1({
    super.key,
    required this.orders,
  });

  String _formatMoney(dynamic v, String? currency) {
    if (v is num) {
      final cur = (currency ?? '').trim();
      if (cur.isEmpty) return '${v.toStringAsFixed(0)} FCFA';
      return '${v.toStringAsFixed(0)} $cur';
    }
    return v?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    num globalTotal = 0;
    String? globalCurrency;
    for (final o in orders) {
      final amount = o['total_amount'];
      if (amount is num) {
        globalTotal += amount;
      }
      globalCurrency ??= o['currency']?.toString();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Commande confirmée'),
      ),
      body: orders.isEmpty
          ? const Center(child: Text('Commande créée.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Récapitulatif',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Text(
                          '${orders.length} commande(s)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _formatMoney(globalTotal, globalCurrency),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final o = orders[index - 1];
                final orderId = o['order_id']?.toString() ?? '';
                final merchantId = o['merchant_id']?.toString() ?? '';
                final currency = o['currency']?.toString();
                final total = o['total_amount'];

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Color(0xFF059669),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Commande créée',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (orderId.isNotEmpty)
                        Text(
                          'Order: $orderId',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      if (merchantId.isNotEmpty)
                        Text(
                          'Marchand: $merchantId',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatMoney(total, currency),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Retour'),
            ),
          ),
        ),
      ),
    );
  }
}
